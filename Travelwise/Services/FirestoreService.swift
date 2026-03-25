import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

// MARK: - FirestoreService
//
// Architecture: SwiftData = source of truth, Firestore = backup.
//
// Reads:  Always from SwiftData (fast, offline-capable).
// Writes: SwiftData first, then mirror to Firestore in the background.
// Sync:   On login / foreground return, fetch Firestore changes and merge
//         into SwiftData using `updatedAt` for conflict resolution.

@Observable
final class FirestoreService {

    // MARK: Public state

    /// True while a background sync is running.
    var isSyncing = false
    /// Non-nil if the last sync attempt produced an error.
    var syncError: Error?

    /// UID of the user whose data is currently loaded in SwiftData.
    /// Used to detect account switches, including on app launch.
    private(set) var loadedUID: String?

    /// Serial task so only one sync runs at a time.
    private var syncTask: Task<Void, Never>?

    // MARK: Private

    // Not stored as a property so Firestore.firestore() is never called at
    // init time — only after FirebaseApp.configure() has run.
    private var db: Firestore { Firestore.firestore() }

    // MARK: - Firestore path helpers

    private func tripsCollection(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("trips")
    }

    private func expensesCollection(tripID: String, userID: String) -> CollectionReference {
        tripsCollection(for: userID).document(tripID).collection("expenses")
    }

    private var storageRef: StorageReference { Storage.storage().reference() }

    private func photoRef(expenseID: String, userID: String) -> StorageReference {
        storageRef.child("users/\(userID)/expenses/\(expenseID)/photo.jpg")
    }

    // MARK: - Firebase Storage photo helpers

    /// Uploads photo data to Storage and returns the download URL string.
    private func uploadPhoto(data: Data, expenseID: String, userID: String) async throws -> String {
        let ref = photoRef(expenseID: expenseID, userID: userID)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        let compressed = UIImage(data: data).flatMap { $0.jpegData(compressionQuality: 0.7) } ?? data
        _ = try await ref.putDataAsync(compressed, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    /// Downloads photo data from a Storage download URL string.
    private func downloadPhoto(from urlString: String) async throws -> Data {
        let ref = Storage.storage().reference(forURL: urlString)
        return try await ref.data(maxSize: 10 * 1024 * 1024)
    }

    /// Deletes a photo from Storage.
    /// Uses the stored download URL when available (guaranteed correct path);
    /// falls back to the reconstructed path-based reference otherwise.
    private func deletePhoto(expenseID: String, userID: String, photoURL: String? = nil) {
        let ref: StorageReference
        if let photoURL {
            ref = Storage.storage().reference(forURL: photoURL)
        } else {
            ref = photoRef(expenseID: expenseID, userID: userID)
        }
        ref.delete { error in
            if let error {
                print("[Storage] Failed to delete photo for \(expenseID): \(error)")
            }
        }
    }

    // MARK: - Mirror local writes to Firestore

    /// Call after inserting or updating a Trip in SwiftData.
    func saveTrip(_ trip: Trip) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let data = trip.toFirestoreData()
        tripsCollection(for: userID)
            .document(trip.firestoreID)
            .setData(data, merge: true) { error in
                if let error {
                    print("[Firestore] Failed to save trip \(trip.firestoreID): \(error)")
                }
            }
    }

    /// Call after deleting a Trip from SwiftData.
    /// Hard-deletes the trip document, all its expense documents, and any
    /// associated Storage photos so nothing can be re-synced back.
    func deleteTrip(firestoreID: String, expenseIDs: [String] = []) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let tripRef = tripsCollection(for: userID).document(firestoreID)
        let expCollection = expensesCollection(tripID: firestoreID, userID: userID)

        Task {
            do {
                // Delete every expense document in the subcollection.
                let snapshot = try await expCollection.getDocuments()
                for doc in snapshot.documents {
                    // Clean up Storage photo if present.
                    if let photoURL = doc.data()["photoURL"] as? String,
                       !photoURL.isEmpty {
                        deletePhoto(expenseID: doc.documentID, userID: userID)
                    }
                    try await doc.reference.delete()
                }
                // Hard-delete the trip document itself.
                try await tripRef.delete()
            } catch {
                print("[Firestore] Failed to delete trip \(firestoreID): \(error)")
            }
        }
    }

    /// Call after inserting or updating an Expense in SwiftData.
    func saveExpense(_ expense: Expense) {
        guard let userID = Auth.auth().currentUser?.uid,
              let trip = expense.trip else { return }
        let expenseID = expense.firestoreID
        let tripFID = trip.firestoreID
        let photoData = expense.photoData
        let existingPhotoURL = expense.photoURL

        Task {
            // Only upload if there is photo data and it hasn't been uploaded yet.
            var resolvedPhotoURL = existingPhotoURL
            if let photoData, existingPhotoURL == nil {
                do {
                    resolvedPhotoURL = try await uploadPhoto(
                        data: photoData,
                        expenseID: expenseID,
                        userID: userID
                    )
                    // Persist the URL back so we don't re-upload on next save.
                    await MainActor.run { expense.photoURL = resolvedPhotoURL }
                } catch {
                    print("[Storage] Failed to upload photo for \(expenseID): \(error)")
                }
            }

            var data = expense.toFirestoreData()
            if let url = resolvedPhotoURL { data["photoURL"] = url }

            do {
                try await expensesCollection(tripID: tripFID, userID: userID)
                    .document(expenseID)
                    .setData(data, merge: true)
            } catch {
                print("[Firestore] Failed to save expense \(expenseID): \(error)")
            }
        }
    }

    /// Call after deleting an Expense from SwiftData.
    /// Hard-deletes the expense document and its Storage photo.
    func deleteExpense(firestoreID: String, tripFirestoreID: String, photoURL: String? = nil) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        Task {
            do {
                try await expensesCollection(tripID: tripFirestoreID, userID: userID)
                    .document(firestoreID)
                    .delete()
                deletePhoto(expenseID: firestoreID, userID: userID, photoURL: photoURL)
            } catch {
                print("[Firestore] Failed to delete expense \(firestoreID): \(error)")
            }
        }
    }

    // MARK: - Clear local data on sign-out

    /// Deletes all Trip and Expense records from the local SwiftData store.
    /// Call this when the current user signs out so a subsequent login starts clean.
    @MainActor
    func clearLocalData(context: ModelContext) {
        do {
            // Fetch and delete individually so SwiftUI @Query observers and
            // the in-memory object graph are both updated correctly.
            // Expenses first to avoid cascade conflicts with the Trip relationship.
            let expenses = try context.fetch(FetchDescriptor<Expense>())
            for expense in expenses { context.delete(expense) }

            let trips = try context.fetch(FetchDescriptor<Trip>())
            for trip in trips { context.delete(trip) }

            try context.save()
            loadedUID = nil
            print("[Firestore] Local data cleared — \(trips.count) trips, \(expenses.count) expenses removed.")
        } catch {
            print("[Firestore] Failed to clear local data: \(error)")
        }
    }

    // MARK: - Background sync (Firestore → SwiftData merge)

    /// Cancels any in-flight sync then enqueues a new one.
    /// Pass `clearFirst: true` (login path) to wipe local data inside the
    /// same serial task — no gap between the clear and the Firestore fetch.
    @MainActor
    func syncFromFirestore(context: ModelContext, clearFirst: Bool = false, force: Bool = false) async {
        syncTask?.cancel()
        syncTask = Task { @MainActor in
            await performSync(context: context, clearFirst: clearFirst)
        }
        await syncTask?.value
    }

    @MainActor
    private func performSync(context: ModelContext, clearFirst: Bool) async {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        // Wipe existing data before fetching, in the same async frame.
        if clearFirst {
            clearLocalData(context: context)
        }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            let tripSnapshots = try await tripsCollection(for: userID).getDocuments()

            // If the user changed while we were awaiting the network, abort.
            guard Auth.auth().currentUser?.uid == userID else {
                print("[Firestore] User changed mid-sync — aborting.")
                return
            }

            for tripDoc in tripSnapshots.documents {
                guard !Task.isCancelled else { return }

                guard let remoteTrip = Trip.from(firestoreData: tripDoc.data(), id: tripDoc.documentID) else {
                    continue
                }

                let expenseSnapshots = try await expensesCollection(
                    tripID: tripDoc.documentID,
                    userID: userID
                ).getDocuments()

                let remoteExpenses: [Expense] = expenseSnapshots.documents.compactMap { doc in
                    Expense.from(firestoreData: doc.data(), id: doc.documentID)
                }

                try mergeTripIntoSwiftData(
                    remoteTrip: remoteTrip,
                    remoteExpenses: remoteExpenses,
                    context: context
                )
            }

            try context.save()
            loadedUID = userID
            print("[Firestore] Sync complete for \(userID).")
        } catch {
            if !Task.isCancelled {
                syncError = error
                print("[Firestore] Sync failed: \(error)")
            }
        }
    }

    // MARK: - Merge helpers

    @MainActor
    private func mergeTripIntoSwiftData(
        remoteTrip: Trip,
        remoteExpenses: [Expense],
        context: ModelContext
    ) throws {
        let fid = remoteTrip.firestoreID

        // Try to find an existing local trip with the same firestoreID.
        let descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { $0.firestoreID == fid }
        )
        let existing = try context.fetch(descriptor).first

        let localTrip: Trip
        if let existing {
            // Conflict resolution: remote wins if it is newer.
            if remoteTrip.updatedAt > existing.updatedAt {
                existing.name = remoteTrip.name
                existing.budget = remoteTrip.budget
                existing.currency = remoteTrip.currency
                existing.startDate = remoteTrip.startDate
                existing.endDate = remoteTrip.endDate
                existing.colorHex = remoteTrip.colorHex
                existing.categories = remoteTrip.categories
                existing.updatedAt = remoteTrip.updatedAt
            }
            localTrip = existing
        } else {
            // New trip from Firestore — insert into SwiftData.
            context.insert(remoteTrip)
            localTrip = remoteTrip
        }

        // Merge expenses.
        for remoteExpense in remoteExpenses {
            try mergeExpenseIntoSwiftData(
                remoteExpense: remoteExpense,
                localTrip: localTrip,
                context: context
            )
        }
    }

    @MainActor
    private func mergeExpenseIntoSwiftData(
        remoteExpense: Expense,
        localTrip: Trip,
        context: ModelContext
    ) throws {
        let fid = remoteExpense.firestoreID

        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.firestoreID == fid }
        )
        let existing = try context.fetch(descriptor).first

        if let existing {
            if remoteExpense.updatedAt > existing.updatedAt {
                existing.title = remoteExpense.title
                existing.amount = remoteExpense.amount
                existing.originalAmount = remoteExpense.originalAmount
                existing.splitPercent = remoteExpense.splitPercent
                existing.categoryName = remoteExpense.categoryName
                existing.note = remoteExpense.note
                existing.latitude = remoteExpense.latitude
                existing.longitude = remoteExpense.longitude
                existing.locationName = remoteExpense.locationName
                existing.updatedAt = remoteExpense.updatedAt
                // Sync photo URL; download image data if not already present locally.
                if let remoteURL = remoteExpense.photoURL, existing.photoURL != remoteURL {
                    existing.photoURL = remoteURL
                    if existing.photoData == nil {
                        Task {
                            if let data = try? await downloadPhoto(from: remoteURL) {
                                await MainActor.run { existing.photoData = data }
                            }
                        }
                    }
                }
            }
        } else {
            remoteExpense.trip = localTrip
            context.insert(remoteExpense)
            // Download photo for newly synced expense.
            if let remoteURL = remoteExpense.photoURL {
                Task {
                    if let data = try? await downloadPhoto(from: remoteURL) {
                        await MainActor.run { remoteExpense.photoData = data }
                    }
                }
            }
        }
    }

}

// MARK: - Trip Firestore serialization

extension Trip {

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "firestoreID": firestoreID,
            "name": name,
            "budget": budget,
            "currency": currency,
            "startDate": Timestamp(date: startDate),
            "colorHex": colorHex,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
        ]
        if let endDate {
            data["endDate"] = Timestamp(date: endDate)
        }
        // Encode categories as an array of dictionaries.
        data["categories"] = categories.map { cat -> [String: Any] in
            var d: [String: Any] = [
                "name": cat.name,
                "systemImage": cat.systemImage,
                "isCustom": cat.isCustom,
            ]
            if let limit = cat.budgetLimit { d["budgetLimit"] = limit }
            return d
        }
        return data
    }

    static func from(firestoreData data: [String: Any], id: String) -> Trip? {
        guard
            let name = data["name"] as? String,
            let budget = data["budget"] as? Double,
            let currency = data["currency"] as? String,
            let startTimestamp = data["startDate"] as? Timestamp,
            let colorHex = data["colorHex"] as? String,
            let createdTimestamp = data["createdAt"] as? Timestamp,
            let updatedTimestamp = data["updatedAt"] as? Timestamp
        else { return nil }

        let endDate = (data["endDate"] as? Timestamp)?.dateValue()

        let categories: [ExpenseCategory]
        if let rawCategories = data["categories"] as? [[String: Any]] {
            categories = rawCategories.compactMap { d -> ExpenseCategory? in
                guard
                    let name = d["name"] as? String,
                    let image = d["systemImage"] as? String,
                    let isCustom = d["isCustom"] as? Bool
                else { return nil }
                let limit = d["budgetLimit"] as? Double
                return isCustom
                    ? ExpenseCategory(customName: name, systemImage: image, budgetLimit: limit)
                    : ExpenseCategory(base: BaseCategory(rawValue: name) ?? .foodAndDrinks,
                                      budgetLimit: limit)
            }
        } else {
            categories = BaseCategory.allCases.map { ExpenseCategory(base: $0) }
        }

        return Trip(
            firestoreID: id,
            name: name,
            budget: budget,
            currency: currency,
            startDate: startTimestamp.dateValue(),
            endDate: endDate,
            colorHex: colorHex,
            categories: categories,
            createdAt: createdTimestamp.dateValue(),
            updatedAt: updatedTimestamp.dateValue()
        )
    }
}

// MARK: - Expense Firestore serialization

extension Expense {

    func toFirestoreData() -> [String: Any] {
        var data: [String: Any] = [
            "firestoreID": firestoreID,
            "title": title,
            "amount": amount,
            "originalAmount": originalAmount,
            "categoryName": categoryName,
            "note": note,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: updatedAt),
        ]
        if let split = splitPercent { data["splitPercent"] = split }
        if let tripFID = trip?.firestoreID { data["tripFirestoreID"] = tripFID }
        // photoData binary is stored in Firebase Storage; only the URL goes in Firestore.
        if let url = photoURL { data["photoURL"] = url }
        if let lat = latitude { data["latitude"] = lat }
        if let lon = longitude { data["longitude"] = lon }
        if let name = locationName { data["locationName"] = name }
        return data
    }

    static func from(firestoreData data: [String: Any], id: String) -> Expense? {
        guard
            let title = data["title"] as? String,
            let amount = data["amount"] as? Double,
            let originalAmount = data["originalAmount"] as? Double,
            let categoryName = data["categoryName"] as? String,
            let createdTimestamp = data["createdAt"] as? Timestamp,
            let updatedTimestamp = data["updatedAt"] as? Timestamp
        else { return nil }

        let note = data["note"] as? String ?? ""
        let splitPercent = data["splitPercent"] as? Double
        let photoURL = data["photoURL"] as? String
        let latitude = data["latitude"] as? Double
        let longitude = data["longitude"] as? Double
        let locationName = data["locationName"] as? String

        return Expense(
            firestoreID: id,
            title: title,
            amount: amount,
            originalAmount: originalAmount,
            splitPercent: splitPercent,
            categoryName: categoryName,
            note: note,
            photoURL: photoURL,
            latitude: latitude,
            longitude: longitude,
            locationName: locationName,
            createdAt: createdTimestamp.dateValue(),
            updatedAt: updatedTimestamp.dateValue()
        )
    }
}

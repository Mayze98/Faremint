import Foundation
import SwiftData
import FirebaseFirestore
import FirebaseAuth

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

    // MARK: Private

    private let db = Firestore.firestore()

    // MARK: - Firestore path helpers

    private func tripsCollection(for userID: String) -> CollectionReference {
        db.collection("users").document(userID).collection("trips")
    }

    private func expensesCollection(tripID: String, userID: String) -> CollectionReference {
        tripsCollection(for: userID).document(tripID).collection("expenses")
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
    func deleteTrip(firestoreID: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        // Mark as deleted rather than hard-delete so other devices can reconcile.
        tripsCollection(for: userID)
            .document(firestoreID)
            .setData(["deletedAt": Timestamp(date: .now)], merge: true) { error in
                if let error {
                    print("[Firestore] Failed to delete trip \(firestoreID): \(error)")
                }
            }
    }

    /// Call after inserting or updating an Expense in SwiftData.
    func saveExpense(_ expense: Expense) {
        guard let userID = Auth.auth().currentUser?.uid,
              let trip = expense.trip else { return }
        let data = expense.toFirestoreData()
        expensesCollection(tripID: trip.firestoreID, userID: userID)
            .document(expense.firestoreID)
            .setData(data, merge: true) { error in
                if let error {
                    print("[Firestore] Failed to save expense \(expense.firestoreID): \(error)")
                }
            }
    }

    /// Call after deleting an Expense from SwiftData.
    func deleteExpense(firestoreID: String, tripFirestoreID: String) {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        expensesCollection(tripID: tripFirestoreID, userID: userID)
            .document(firestoreID)
            .setData(["deletedAt": Timestamp(date: .now)], merge: true) { error in
                if let error {
                    print("[Firestore] Failed to delete expense \(firestoreID): \(error)")
                }
            }
    }

    // MARK: - Background sync (Firestore → SwiftData merge)

    /// Fetches all trips (and their expenses) from Firestore and merges them
    /// into the provided SwiftData context.  Uses `updatedAt` to resolve
    /// conflicts: the newer record wins.
    ///
    /// Call this after sign-in, on app foreground, or on a timer.
    @MainActor
    func syncFromFirestore(context: ModelContext) async {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil
        defer { isSyncing = false }

        do {
            // Fetch all non-deleted trips from Firestore.
            let tripSnapshots = try await tripsCollection(for: userID).getDocuments()

            for tripDoc in tripSnapshots.documents {
                let data = tripDoc.data()

                // Skip soft-deleted documents.
                if data["deletedAt"] != nil {
                    try deleteLocalTripIfPresent(firestoreID: tripDoc.documentID, context: context)
                    continue
                }

                guard let remoteTrip = Trip.from(firestoreData: data, id: tripDoc.documentID) else {
                    continue
                }

                // Fetch expenses for this trip.
                let expenseSnapshots = try await expensesCollection(
                    tripID: tripDoc.documentID,
                    userID: userID
                ).getDocuments()

                let remoteExpenses: [Expense] = expenseSnapshots.documents.compactMap { doc in
                    let eData = doc.data()
                    guard eData["deletedAt"] == nil else { return nil }
                    return Expense.from(firestoreData: eData, id: doc.documentID)
                }

                // Merge trip (and its expenses) into SwiftData.
                try mergeTripIntoSwiftData(
                    remoteTrip: remoteTrip,
                    remoteExpenses: remoteExpenses,
                    context: context
                )
            }

            try context.save()
            print("[Firestore] Sync complete.")
        } catch {
            syncError = error
            print("[Firestore] Sync failed: \(error)")
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
                existing.updatedAt = remoteExpense.updatedAt
                // Note: photoData is not synced via Firestore (too large for documents).
            }
        } else {
            remoteExpense.trip = localTrip
            context.insert(remoteExpense)
        }
    }

    @MainActor
    private func deleteLocalTripIfPresent(firestoreID: String, context: ModelContext) throws {
        let descriptor = FetchDescriptor<Trip>(
            predicate: #Predicate { $0.firestoreID == firestoreID }
        )
        if let local = try context.fetch(descriptor).first {
            context.delete(local)
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
        // photoData is intentionally excluded — too large for Firestore documents.
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

        return Expense(
            firestoreID: id,
            title: title,
            amount: amount,
            originalAmount: originalAmount,
            splitPercent: splitPercent,
            categoryName: categoryName,
            note: note,
            createdAt: createdTimestamp.dateValue(),
            updatedAt: updatedTimestamp.dateValue()
        )
    }
}

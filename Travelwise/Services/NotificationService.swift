import Foundation
import UserNotifications

// MARK: - AppStorage Key Constants

enum AppStorageKeys {
    static let budgetAlertsEnabled = "budgetAlertsEnabled"
    static let notifyAt80          = "notifyAt80Percent"
    static let notifyAt100         = "notifyAt100Percent"
}

// MARK: - NotificationService

@Observable
final class NotificationService: NSObject {

    override init() {
        super.init()
        // Register defaults so UserDefaults.bool(forKey:) returns the correct
        // value even before the NotificationsSettingsView has ever been rendered
        UserDefaults.standard.register(defaults: [
            AppStorageKeys.budgetAlertsEnabled: false,
            AppStorageKeys.notifyAt80:          true,
            AppStorageKeys.notifyAt100:         true
        ])
    }

    // MARK: - Authorization

    func requestAuthorization() {
        // Delegate must be set on the main thread before any notifications can be presented
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, error in
            if let error {
                print("[Notifications] Authorization error: \(error)")
            }
        }
    }

    // MARK: - Budget Threshold Checks

    /// Call this after any expense save or delete for the given trip.
    /// Pass `pendingAmount` and `pendingCategory` for a newly inserted expense whose
    /// amount may not yet be reflected in `trip.expenses` due to SwiftData propagation timing.
    func checkBudgetThresholds(for trip: Trip, pendingAmount: Double = 0, pendingCategory: String = "") {
        guard UserDefaults.standard.bool(forKey: AppStorageKeys.budgetAlertsEnabled) else { return }

        let notify80  = UserDefaults.standard.bool(forKey: AppStorageKeys.notifyAt80)
        let notify100 = UserDefaults.standard.bool(forKey: AppStorageKeys.notifyAt100)

        // Build category totals from persisted expenses
        var totals: [String: Double] = [:]
        for expense in trip.expenses {
            totals[expense.categoryName, default: 0] += expense.amount
        }
        // Add the pending expense that may not yet be in trip.expenses
        if !pendingCategory.isEmpty {
            totals[pendingCategory, default: 0] += pendingAmount
        }

        for category in trip.categories {
            guard let limit = category.budgetLimit, limit > 0 else { continue }
            let total   = totals[category.name] ?? 0
            let percent = (total / limit) * 100

            if notify80 {
                let key80 = notifiedKey(tripID: trip.firestoreID, categoryName: category.name, threshold: 80)
                if percent >= 80 && percent < 100 {
                    if !UserDefaults.standard.bool(forKey: key80) {
                        scheduleNotification(
                            title: "Budget Alert — \(category.name)",
                            body: "You've used 80% of your \(category.name) budget on \(trip.name).",
                            identifier: key80
                        )
                        UserDefaults.standard.set(true, forKey: key80)
                    }
                } else if percent < 80 {
                    UserDefaults.standard.removeObject(forKey: key80)
                }
            }

            if notify100 {
                let key100 = notifiedKey(tripID: trip.firestoreID, categoryName: category.name, threshold: 100)
                if percent >= 100 {
                    if !UserDefaults.standard.bool(forKey: key100) {
                        scheduleNotification(
                            title: "Budget Exceeded — \(category.name)",
                            body: "You've gone over your \(category.name) budget on \(trip.name).",
                            identifier: key100
                        )
                        UserDefaults.standard.set(true, forKey: key100)
                    }
                } else if percent < 100 {
                    UserDefaults.standard.removeObject(forKey: key100)
                }
            }
        }
    }

    // MARK: - Cleanup on Trip Delete

    /// Remove all stored threshold keys for a trip to avoid stale UserDefaults entries.
    func clearNotificationState(for trip: Trip) {
        for category in trip.categories {
            UserDefaults.standard.removeObject(
                forKey: notifiedKey(tripID: trip.firestoreID, categoryName: category.name, threshold: 80)
            )
            UserDefaults.standard.removeObject(
                forKey: notifiedKey(tripID: trip.firestoreID, categoryName: category.name, threshold: 100)
            )
        }
    }

    // MARK: - Private Helpers

    private func notifiedKey(tripID: String, categoryName: String, threshold: Int) -> String {
        "notified_\(tripID)_\(categoryName)_\(threshold)"
    }

    private func scheduleNotification(title: String, body: String, identifier: String) {
        let content   = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[Notifications] Failed to schedule: \(error)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Show notification banners even when the app is in the foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

import SwiftUI

struct NotificationsSettingsView: View {
    @AppStorage(AppStorageKeys.budgetAlertsEnabled) private var budgetAlertsEnabled = false
    @AppStorage(AppStorageKeys.notifyAt80)          private var notifyAt80 = true
    @AppStorage(AppStorageKeys.notifyAt100)         private var notifyAt100 = true

    var body: some View {
        List {
            Section {
                Toggle("Budget Alerts", isOn: $budgetAlertsEnabled)
            } footer: {
                Text("Receive a notification when category spending approaches or exceeds its budget limit.")
            }

            if budgetAlertsEnabled {
                Section("ALERT THRESHOLDS") {
                    Toggle("Notify at 80%", isOn: $notifyAt80)
                    Toggle("Notify at 100%", isOn: $notifyAt100)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        NotificationsSettingsView()
    }
}

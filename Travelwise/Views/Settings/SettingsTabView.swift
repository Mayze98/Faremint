import SwiftUI

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Settings")
                            .font(.largeTitle.weight(.bold))
                        Text("Manage your preferences")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Account section
                    SettingsSection(title: "ACCOUNT") {
                        NavigationLink {
                            ProfileView()
                        } label: {
                            SettingsRowView(
                                icon: "person.crop.circle",
                                iconColor: Theme.accentTeal,
                                title: "Profile",
                                subtitle: "Edit your personal information"
                            )
                        }
                        Divider()
                        NavigationLink {
                            Text("Notifications")
                        } label: {
                            SettingsRowView(
                                icon: "bell",
                                iconColor: Theme.accentTeal,
                                title: "Notifications",
                                subtitle: "Manage your alerts"
                            )
                        }
                    }

                    // Preferences section
                    SettingsSection(title: "PREFERENCES") {
                        NavigationLink {
                            CurrencyPickerView()
                        } label: {
                            SettingsRowView(
                                icon: "globe",
                                iconColor: .blue,
                                title: "Currency",
                                subtitle: "\(UserDefaults.standard.string(forKey: "currencyCode") ?? "USD") - \(CurrencyHelper.commonCurrencies.first { $0.code == (UserDefaults.standard.string(forKey: "currencyCode") ?? "USD") }?.name ?? "US Dollar")"
                            )
                        }
                        Divider()
                        NavigationLink {
                            Text("Export Data")
                        } label: {
                            SettingsRowView(
                                icon: "arrow.down.circle",
                                iconColor: .blue,
                                title: "Export Data",
                                subtitle: "Download your trips as CSV"
                            )
                        }
                    }

                    // Support section
                    SettingsSection(title: "SUPPORT") {
                        NavigationLink {
                            Text("Help & Support")
                        } label: {
                            SettingsRowView(
                                icon: "questionmark.circle",
                                iconColor: .green,
                                title: "Help & Support",
                                subtitle: "Get help with Travelwise"
                            )
                        }
                        Divider()
                        NavigationLink {
                            Text("Terms & Privacy")
                        } label: {
                            SettingsRowView(
                                icon: "doc.text",
                                iconColor: .green,
                                title: "Terms & Privacy",
                                subtitle: "Legal information"
                            )
                        }
                    }

                    // Version
                    Text("Travelwise v1.0.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.top)
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
        }
    }
}

#Preview {
    SettingsTabView()
}

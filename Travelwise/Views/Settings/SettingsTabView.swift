import SwiftUI
import SwiftData

struct SettingsTabView: View {
    @Environment(AuthService.self) private var authService
    @Query private var trips: [Trip]
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @State private var showingSignOutAlert = false

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
                        .tint(.primary)
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
                        .tint(.primary)
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
                                subtitle: "\(UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD") - \(CurrencyHelper.commonCurrencies.first { $0.code == (UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD") }?.name ?? "Canadian Dollar")"
                            )
                        }
                        .tint(.primary)
                        Divider()
                        if let url = CSVExporter.csvFileURL(for: trips) {
                            ShareLink(item: url, preview: SharePreview("Travelwise Export", image: Image(systemName: "doc.text"))) {
                                SettingsRowView(
                                    icon: "arrow.down.circle",
                                    iconColor: .blue,
                                    title: "Export Data",
                                    subtitle: "Download your trips as CSV"
                                )
                            }
                            .tint(.primary)
                        } else {
                            SettingsRowView(
                                icon: "arrow.down.circle",
                                iconColor: .blue,
                                title: "Export Data",
                                subtitle: "Download your trips as CSV"
                            )
                        }
                        Divider()
                        HStack(spacing: 14) {
                            Image(systemName: appearanceMode == 2 ? "moon.fill" : "sun.max.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 36, height: 36)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Appearance")
                                    .font(.subheadline.weight(.medium))
                                Text(appearanceMode == 0 ? "System" : appearanceMode == 1 ? "Light" : "Dark")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Picker("", selection: $appearanceMode) {
                                Image(systemName: "iphone").tag(0)
                                Image(systemName: "sun.max.fill").tag(1)
                                Image(systemName: "moon.fill").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                        .padding(.vertical, 8)
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
                        .tint(.primary)
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
                        .tint(.primary)
                    }

                    // Sign Out
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Sign Out")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal)

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
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    try? authService.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
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
        .environment(AuthService())
}

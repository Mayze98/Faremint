import SwiftUI
import SwiftData

struct SettingsTabView: View {
    @Environment(AuthService.self) private var authService
    @Environment(FirestoreService.self) private var firestoreService
    @Environment(\.modelContext) private var modelContext
    @Query private var trips: [Trip]
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var isDeletingAccount = false
    @State private var deleteAccountError: String?

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
                            NotificationsSettingsView()
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
                                subtitle: "\(currencyCode) - \(CurrencyHelper.commonCurrencies.first { $0.code == currencyCode }?.name ?? "Canadian Dollar")"
                            )
                        }
                        .tint(.primary)
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

                    // Export section
                    SettingsSection(title: "EXPORT DATA") {
                        let csvURL = CSVExporter.csvFileURL(for: trips)
                        let pdfURL = PDFExporter.pdfFileURL(for: trips, currencyCode: currencyCode)
                        if let url = csvURL {
                            ShareLink(item: url, preview: SharePreview("Faremint Export", image: Image(systemName: "doc.text"))) {
                                SettingsRowView(
                                    icon: "arrow.down.circle",
                                    iconColor: .blue,
                                    title: "Export CSV",
                                    subtitle: "Download your trips as CSV"
                                )
                            }
                            .tint(.primary)
                        } else {
                            SettingsRowView(
                                icon: "arrow.down.circle",
                                iconColor: .blue,
                                title: "Export CSV",
                                subtitle: "Download your trips as CSV"
                            )
                        }
                        if let url = pdfURL {
                            Divider()
                            ShareLink(item: url, preview: SharePreview("PDF Summary", image: Image(systemName: "doc.richtext"))) {
                                SettingsRowView(
                                    icon: "doc.richtext",
                                    iconColor: .orange,
                                    title: "Export PDF Summary",
                                    subtitle: "Trip summaries with category charts"
                                )
                            }
                            .tint(.primary)
                            Divider()
                            ShareLink(item: url, preview: SharePreview("Tax Report", image: Image(systemName: "doc.text.magnifyingglass"))) {
                                SettingsRowView(
                                    icon: "doc.text.magnifyingglass",
                                    iconColor: .green,
                                    title: "Export Tax Report",
                                    subtitle: "Chronological expense list for tax filing"
                                )
                            }
                            .tint(.primary)
                        }
                    }

                    // Sign Out & Delete Account
                    SettingsSection(title: "ACCOUNT ACTIONS") {
                        Button(role: .destructive) {
                            showingSignOutAlert = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .frame(width: 36, height: 36)
                                    .background(Color.orange.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sign Out")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("You can sign back in anytime")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 8)
                        }
                        .tint(.primary)

                        Divider()

                        Button(role: .destructive) {
                            showingDeleteAccountAlert = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 36, height: 36)
                                    .background(Color.red.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delete Account")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.red)
                                    Text("Permanently delete your account and data")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if isDeletingAccount {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .tint(.primary)
                        .disabled(isDeletingAccount)
                    }

                    // Version
                    Text("Faremint v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
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
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete My Account", role: .destructive) {
                    isDeletingAccount = true
                    Task {
                        do {
                            try await authService.deleteAccount(
                                firestoreService: firestoreService,
                                modelContext: modelContext
                            )
                        } catch {
                            deleteAccountError = AuthService.friendlyErrorMessage(for: error)
                        }
                        isDeletingAccount = false
                    }
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .alert("Unable to Delete Account", isPresented: .init(
                get: { deleteAccountError != nil },
                set: { if !$0 { deleteAccountError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deleteAccountError ?? "")
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

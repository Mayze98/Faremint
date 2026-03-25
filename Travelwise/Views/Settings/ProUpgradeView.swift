import SwiftUI
import StoreKit

struct ProUpgradeView: View {
    @Environment(StoreKitService.self) private var storeKit
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Hero
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Travelwise Pro")
                            .font(.title.weight(.bold))
                        Text("Unlock the full travel experience")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Feature list
                    VStack(spacing: 0) {
                        proFeatureRow(
                            icon: "map.fill", color: .blue,
                            title: "Expense Map",
                            subtitle: "See all your expenses pinned on a world map"
                        )
                        Divider().padding(.leading, 62)
                        proFeatureRow(
                            icon: "camera.fill", color: .purple,
                            title: "Photo Receipts",
                            subtitle: "Attach photos to every expense"
                        )
                        Divider().padding(.leading, 62)
                        proFeatureRow(
                            icon: "doc.richtext", color: .orange,
                            title: "Advanced Exports",
                            subtitle: "PDF summaries, category charts & tax reports"
                        )
                        Divider().padding(.leading, 62)
                        proFeatureRow(
                            icon: "arrow.triangle.branch", color: Theme.accentTeal,
                            title: "Smart Budget Rebalance",
                            subtitle: "Auto-adjust limits when overspending in a category"
                        )
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Price + CTA
                    VStack(spacing: 14) {
                        if let product = storeKit.proProduct {
                            Text("\(product.displayPrice) / month")
                                .font(.title2.weight(.bold))

                            Button {
                                Task { await storeKit.purchasePro() }
                            } label: {
                                Group {
                                    if storeKit.purchaseInProgress {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Subscribe Now")
                                            .font(.headline)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Theme.accentTeal, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                            }
                            .disabled(storeKit.purchaseInProgress)
                            .padding(.horizontal)
                        } else {
                            ProgressView("Loading…")
                                .padding()
                        }

                        Button("Restore Purchases") {
                            Task { await storeKit.restorePurchases() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        if let error = storeKit.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }

                    Text("Subscription auto-renews monthly. Cancel anytime in App Store settings.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func proFeatureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ProUpgradeView()
        .environment(StoreKitService())
}

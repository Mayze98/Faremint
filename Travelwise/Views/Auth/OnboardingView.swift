import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 20)

                    // Hero
                    VStack(spacing: 10) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.accentTeal)
                        Text("Welcome to Travelwise")
                            .font(.title.weight(.bold))
                        Text("Track expenses, stay on budget,\nand travel smarter.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // Features
                    VStack(spacing: 0) {
                        featureRow(
                            icon: "dollarsign.circle.fill", color: .green,
                            title: "Expense Tracking",
                            detail: "Log expenses in any currency with automatic conversion"
                        )
                        Divider().padding(.leading, 62)
                        featureRow(
                            icon: "chart.pie.fill", color: .orange,
                            title: "Spending Insights",
                            detail: "See where your money goes with charts and breakdowns"
                        )
                        Divider().padding(.leading, 62)
                        featureRow(
                            icon: "bell.badge.fill", color: .blue,
                            title: "Budget Alerts",
                            detail: "Get notified when you're close to your spending limit"
                        )
                        Divider().padding(.leading, 62)
                        featureRow(
                            icon: "map.fill", color: .purple,
                            title: "Expense Map",
                            detail: "Pin expenses on a world map",
                            isPro: true
                        )
                        Divider().padding(.leading, 62)
                        featureRow(
                            icon: "camera.fill", color: .pink,
                            title: "Photo Receipts",
                            detail: "Attach photos to every expense",
                            isPro: true
                        )
                        Divider().padding(.leading, 62)
                        featureRow(
                            icon: "doc.richtext", color: .indigo,
                            title: "PDF & CSV Exports",
                            detail: "Export trip summaries and tax reports",
                            isPro: true
                        )
                    }
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }
            }

            // CTA
            Button {
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.accentTeal, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .interactiveDismissDisabled()
    }

    private func featureRow(icon: String, color: Color, title: String, detail: String, isPro: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    if isPro {
                        Text("PRO")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.accentTeal, in: Capsule())
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

#Preview {
    OnboardingView()
}

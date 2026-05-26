import SwiftUI

struct ProFeatureOverlay: ViewModifier {
    @Environment(StoreKitService.self) private var storeKit
    @State private var showingPaywall = false
    let featureName: String

    func body(content: Content) -> some View {
        content
            .overlay {
                if !storeKit.isProUser {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("\(featureName)")
                                .font(.title3.weight(.bold))
                            Text("This is a Pro feature")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                showingPaywall = true
                            } label: {
                                Text("Upgrade to Pro")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 12)
                                    .background(Theme.accentTeal, in: Capsule())
                            }
                        }
                        .padding(32)
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                ProUpgradeView()
            }
    }
}

extension View {
    func proFeatureGate(_ featureName: String) -> some View {
        modifier(ProFeatureOverlay(featureName: featureName))
    }
}

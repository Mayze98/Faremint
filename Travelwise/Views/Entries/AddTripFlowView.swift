import SwiftUI
import SwiftData

struct AddTripFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currencyCode") private var currencyCode = "CAD"
    @Binding var isPresented: Bool

    @State private var viewModel: AddTripFlowViewModel

    init(isPresented: Binding<Bool>) {
        _isPresented = isPresented
        _viewModel = State(initialValue: AddTripFlowViewModel(
            currencyCode: UserDefaults.standard.string(forKey: "currencyCode") ?? "CAD"
        ))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if viewModel.goBack() {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    isPresented = false
                                }
                            }
                        }
                    } label: {
                        Image(systemName: viewModel.step > 0 ? "chevron.left" : "xmark")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 40, height: 40)
                    }

                    Spacer()

                    // Step indicator
                    HStack(spacing: 6) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(i <= viewModel.step ? Theme.accentTeal : Color(.systemGray4))
                                .frame(width: i == viewModel.step ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: viewModel.step)
                        }
                    }

                    Spacer()

                    // Invisible spacer to balance the back button
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                Spacer()

                // Step content
                Group {
                    switch viewModel.step {
                    case 0:
                        stepNameView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 1:
                        stepBudgetView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    case 2:
                        stepReviewView
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity.combined(with: .move(edge: .leading))
                            ))
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.35), value: viewModel.step)

                Spacer()

                // Bottom button
                Button {
                    handleNext()
                } label: {
                    Text(viewModel.step == 2 ? "Create Trip" : "Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(viewModel.nextButtonEnabled ? Theme.accentTeal : Color(.systemGray4), in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!viewModel.nextButtonEnabled)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Step Views

    private var stepNameView: some View {
        VStack(spacing: 24) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)

            Text("Where are you going?")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            TextField("e.g. Tokyo, Bali, Paris", text: $viewModel.name)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 32)

            // Color picker
            VStack(spacing: 12) {
                Text("Pick a color")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(Array(Theme.bubblePalette.enumerated()), id: \.offset) { index, hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 32, height: 32)
                            .overlay {
                                if index == viewModel.selectedColorIndex {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 2.5)
                                    Circle()
                                        .strokeBorder(Color(hex: hex).opacity(0.5), lineWidth: 1, antialiased: true)
                                        .frame(width: 40, height: 40)
                                }
                            }
                            .onTapGesture {
                                viewModel.selectedColorIndex = index
                            }
                    }
                }
            }

            // Date pickers
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.startDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                                .labelsHidden()
                                .colorMultiply(.clear)
                                .allowsHitTesting(true)
                        }
                }

                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 22)

                VStack(alignment: .leading, spacing: 6) {
                    Text("End")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(viewModel.endDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            DatePicker("", selection: $viewModel.endDate, displayedComponents: .date)
                                .labelsHidden()
                                .colorMultiply(.clear)
                                .allowsHitTesting(true)
                        }
                }
            }
            .padding(.horizontal, 32)
            .onChange(of: viewModel.startDate) { _, _ in
                viewModel.ensureEndDateAfterStart()
            }
        }
        .padding(.horizontal)
    }

    private var stepBudgetView: some View {
        VStack(spacing: 24) {
            Image(systemName: "banknote")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accentTeal)

            Text("What is your budget?")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)

            Text(viewModel.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 2) {
                Text(viewModel.currencySymbol)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("0", text: $viewModel.budget)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
    }

    private var stepReviewView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Review your budget")
                    .font(.title2.weight(.bold))

                Text("\(CurrencyHelper.format(viewModel.budgetValue, code: currencyCode)) for \(viewModel.name)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Allocation summary
            allocationSummary
                .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(BaseCategory.allCases) { category in
                        categoryRow(name: category.rawValue, icon: category.systemImage, color: Theme.colorForCategory(category.rawValue))
                        Divider().padding(.leading, 44)
                    }

                    ForEach(viewModel.customCategories) { category in
                        HStack(spacing: 12) {
                            Image(systemName: category.systemImage)
                                .foregroundStyle(.gray)
                                .frame(width: 28)
                            Text(category.name)
                                .font(.subheadline)
                            Spacer()
                            TextField("0", text: viewModel.categoryLimitBinding(for: category.name))
                                .keyboardType(.decimalPad)
                                .font(.subheadline.weight(.semibold))
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Button {
                                viewModel.removeCustomCategory(category)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        Divider().padding(.leading, 44)
                    }

                    // Add custom category
                    HStack(spacing: 12) {
                        Image(systemName: "tag.fill")
                            .foregroundStyle(.gray)
                            .frame(width: 28)
                        TextField("Add custom category", text: $viewModel.customCategoryName)
                            .font(.subheadline)
                        Button {
                            viewModel.addCustomCategory()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.accentTeal)
                        }
                        .disabled(viewModel.customCategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal)
    }

    // MARK: - Components

    private func categoryRow(name: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(name)
                .font(.subheadline)
            Spacer()
            TextField("0", text: viewModel.categoryLimitBinding(for: name))
                .keyboardType(.decimalPad)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var allocationSummary: some View {
        VStack(spacing: 6) {
            ProgressView(value: min(viewModel.totalCategoryLimits / max(viewModel.budgetValue, 1), 1.0))
                .tint(viewModel.remainingBudget < 0 ? .red : (viewModel.remainingBudget == 0 ? Theme.accentTeal : .orange))

            HStack {
                Text("Allocated: \(CurrencyHelper.format(viewModel.totalCategoryLimits, code: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if viewModel.remainingBudget > 0 {
                    Text("\(CurrencyHelper.format(viewModel.remainingBudget, code: currencyCode)) left")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if viewModel.remainingBudget < 0 {
                    Text("Over by \(CurrencyHelper.format(-viewModel.remainingBudget, code: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else {
                    Text("Fully allocated")
                        .font(.caption)
                        .foregroundStyle(Theme.accentTeal)
                }
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Logic

    private func handleNext() {
        withAnimation(.easeInOut(duration: 0.35)) {
            if viewModel.handleNext() {
                viewModel.saveTrip(modelContext: modelContext)
                isPresented = false
            }
        }
    }
}

#Preview {
    @Previewable @State var showing = true
    AddTripFlowView(isPresented: $showing)
        .modelContainer(SampleData.container)
}

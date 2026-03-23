import SwiftUI
import SwiftData

struct EntriesTabView: View {
    @Query(sort: \Trip.createdAt, order: .reverse) private var allTrips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = EntriesViewModel()
    @State private var showingPastTrips = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("My Trips")
                            .font(.largeTitle.weight(.bold))
                        Text("Your \(Calendar.current.component(.year, from: .now), format: .number.grouping(.never)) adventures")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !viewModel.trips(from: allTrips).isEmpty {
                        VStack(alignment: .trailing, spacing: 10) {
                            Button {
                                viewModel.toggleBubbleView()
                            } label: {
                                Image(systemName: viewModel.showingBubbles ? "list.bullet" : "circle.grid.3x3.fill")
                                    .font(.title3)
                                    .foregroundStyle(Theme.accentTeal)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.accentTeal.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                showingPastTrips = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                        .font(.caption.weight(.semibold))
                                    Text("Past Trips")
                                        .font(.caption.weight(.semibold))
                                }
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                if viewModel.trips(from: allTrips).isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "airplane.departure")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text("No trips yet")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("Tap + to create your first trip")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else if viewModel.showingBubbles {
                    VStack(spacing: 16) {
                        BubbleClusterView(trips: viewModel.currentYearTrips(from: allTrips)) { trip in
                            viewModel.selectFromBubble(trip)
                        }
                        .padding()
                    }
                } else if let current = viewModel.currentTrip(from: allTrips) {
                    // Trip selector chips + edit button
                    HStack(spacing: 0) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.trips(from: allTrips)) { trip in
                                    Button {
                                        viewModel.selectTrip(trip)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Color(hex: trip.colorHex))
                                                .frame(width: 10, height: 10)
                                            Text(trip.name)
                                                .font(.subheadline.weight(.medium))
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            viewModel.isSelected(trip, allTrips: allTrips)
                                                ? Color(hex: trip.colorHex).opacity(0.15)
                                                : Color(.systemGray6)
                                        )
                                        .foregroundStyle(
                                            viewModel.isSelected(trip, allTrips: allTrips)
                                                ? Color(hex: trip.colorHex)
                                                : .secondary
                                        )
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.leading)
                            .padding(.vertical, 12)
                        }

                        Button {
                            viewModel.showingEditTrip = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Theme.accentTeal)
                        }
                        .padding(.horizontal, 12)
                    }

                    // Inline trip detail
                    TripDetailInlineView(trip: current)
                }
            }
            .background(Color(.systemGroupedBackground))
            .overlay(alignment: .bottomTrailing) {
                Button {
                    viewModel.handleFABTap(allTrips: allTrips)
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Theme.accentTeal, in: Circle())
                        .shadow(color: Theme.accentTeal.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .overlay {
                if viewModel.showingAddTrip {
                    AddTripFlowView(isPresented: $viewModel.showingAddTrip)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .sheet(isPresented: $viewModel.showingAddExpense) {
                if let current = viewModel.currentTrip(from: allTrips) {
                    AddExpenseSheet(trip: current)
                }
            }
            .sheet(isPresented: $viewModel.showingEditTrip) {
                if let current = viewModel.currentTrip(from: allTrips) {
                    EditTripSheet(trip: current)
                }
            }
            .sheet(isPresented: $showingPastTrips) {
                PastTripsTabView()
            }
        }
    }
}

#Preview {
    EntriesTabView()
        .modelContainer(SampleData.container)
        .environment(FirestoreService())
}

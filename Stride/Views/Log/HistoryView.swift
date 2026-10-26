import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]
    @State private var filter: ActivityKind?

    private var filtered: [Workout] {
        workouts.filter { filter == nil || $0.kind == filter }
    }

    private var totalDistance: Double {
        filtered.reduce(0) { $0 + $1.distanceMeters }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summary
                    filterBar
                    if filtered.isEmpty {
                        ContentUnavailableView(
                            "No \(filter?.title.lowercased() ?? "workouts") yet",
                            systemImage: "list.bullet.rectangle",
                            description: Text("Finished walk, jog, and run sessions show up here.")
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout)
                                } label: {
                                    WorkoutRow(workout: workout, metric: model.settings.usesMetric)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Log")
        }
    }

    private var summary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(filtered.count)")
                    .font(.title.bold().monospacedDigit())
                Text("Sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.distance(totalDistance, metric: model.settings.usesMetric))
                    .font(.title.bold().monospacedDigit())
                Text("Total distance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", selected: filter == nil) { filter = nil }
                ForEach(ActivityKind.allCases) { kind in
                    filterChip(title: kind.title, selected: filter == kind) { filter = kind }
                }
            }
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
                .foregroundStyle(selected ? Color.black.opacity(0.85) : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

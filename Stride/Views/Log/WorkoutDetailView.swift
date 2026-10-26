import SwiftData
import SwiftUI

struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let workout: Workout
    @State private var confirmDelete = false

    private var metric: Bool { model.settings.usesMetric }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ActivityBadge(kind: workout.kind)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(workout.startDate.formatted(date: .complete, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if workout.route.isEmpty {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemFill))
                        .frame(height: 220)
                        .overlay {
                            ContentUnavailableView("No GPS route", systemImage: "map")
                        }
                } else {
                    WorkoutMapView(
                        coordinates: workout.route.map(\.coordinate),
                        tint: workout.kind.color,
                        showsStartFinish: true
                    )
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Distance", value: Formatters.distanceValue(workout.distanceMeters, metric: metric), unit: Formatters.distanceUnit(workout.distanceMeters, metric: metric))
                    MetricTile(title: "Time", value: Formatters.duration(workout.duration), unit: "")
                    MetricTile(title: "Pace", value: Formatters.pace(secondsPerMeter: workout.averagePaceSecondsPerMeter, metric: metric), unit: "")
                    MetricTile(title: "Steps", value: Formatters.steps(workout.steps), unit: "")
                    MetricTile(title: "Energy", value: Formatters.calories(workout.calories), unit: "kcal")
                }

                if !workout.splits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Splits")
                            .font(.headline)
                        ForEach(workout.splits) { split in
                            HStack {
                                Text("\(split.number)")
                                    .font(.headline.monospacedDigit())
                                    .frame(width: 28)
                                Text(Formatters.distance(split.distanceMeters, metric: metric))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(Formatters.duration(split.duration))
                                    .monospacedDigit()
                                Text(Formatters.pace(secondsPerMeter: split.paceSecondsPerMeter, metric: metric))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .font(.subheadline)
                            if split.id != workout.splits.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(workout.kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete", role: .destructive) { confirmDelete = true }
            }
        }
        .alert("Delete this workout?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                modelContext.delete(workout)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Workout.startDate, order: .reverse) private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    StepRingView(steps: model.health.todaySteps, goal: model.settings.dailyStepGoal)
                        .frame(maxWidth: 280)
                        .frame(maxWidth: .infinity)

                    if !model.health.isAvailable {
                        PermissionBanner(
                            title: "Apple Health unavailable",
                            detail: "Step totals need Health on this iPhone."
                        )
                    } else if !model.health.isAuthorized && model.health.todaySteps == 0 {
                        PermissionBanner(
                            title: "Connect Apple Health",
                            detail: model.health.lastError
                                ?? "Allow steps, distance, and workouts so Today stays accurate.",
                            isWorking: model.health.isRequesting
                        ) {
                            Task {
                                await model.health.requestAuthorization()
                                await model.refresh()
                            }
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricTile(
                            title: "Distance",
                            value: Formatters.distanceValue(model.health.todayDistanceMeters, metric: model.settings.usesMetric),
                            unit: Formatters.distanceUnit(model.health.todayDistanceMeters, metric: model.settings.usesMetric),
                            symbol: "point.bottomleft.forward.to.point.topright.scurvepath"
                        )
                        MetricTile(
                            title: "Energy",
                            value: Formatters.calories(model.health.todayCalories),
                            unit: "kcal",
                            symbol: "flame.fill"
                        )
                    }

                    WeeklyStepsChart(days: model.health.weeklySteps, goal: model.settings.dailyStepGoal)

                    recentSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await model.refresh() }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.headline)

            if workouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.run",
                    description: Text("Workouts will show up here once Move is back.")
                )
                .frame(minHeight: 140)
            } else {
                ForEach(workouts.prefix(3)) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRow(workout: workout, metric: model.settings.usesMetric)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct PermissionBanner: View {
    let title: String
    let detail: String
    var isWorking = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let action {
                Button(action: action) {
                    HStack {
                        if isWorking {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isWorking ? "Waiting for Health…" : "Allow access")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct WorkoutRow: View {
    let workout: Workout
    let metric: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: workout.kind.symbol)
                .font(.title2)
                .foregroundStyle(workout.kind.color)
                .frame(width: 44, height: 44)
                .background(workout.kind.color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.kind.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.distance(workout.distanceMeters, metric: metric))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(Formatters.duration(workout.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

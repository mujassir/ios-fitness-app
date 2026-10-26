import SwiftData
import SwiftUI

struct LiveWorkoutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var confirmFinish = false
    @State private var confirmDiscard = false

    private var session: WorkoutSessionManager { model.session }
    private var metric: Bool { model.settings.usesMetric }

    var body: some View {
        VStack(spacing: 0) {
            header
            metrics
            WorkoutMapView(
                coordinates: session.routePoints.map(\.coordinate),
                tint: session.kind.color,
                followsUser: true
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            controls
        }
        .background(Color(.systemBackground))
        .confirmationDialog("Finish this workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Save workout") {
                Task {
                    await session.finish(modelContext: modelContext)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                session.discard()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            ActivityBadge(kind: session.kind)
            Spacer()
            if session.isAutoPaused {
                Text("Auto-paused")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Text(Formatters.duration(session.elapsed))
                .font(.title2.weight(.bold).monospacedDigit())
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var metrics: some View {
        VStack(spacing: 6) {
            Text(Formatters.distanceValue(session.distanceMeters, metric: metric))
                .font(.system(size: 64, weight: .bold, design: .rounded).monospacedDigit())
            Text(Formatters.distanceUnit(session.distanceMeters, metric: metric).uppercased())
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                liveMetric("Pace", Formatters.pace(secondsPerMeter: session.currentPaceSecondsPerMeter, metric: metric))
                liveMetric("Steps", Formatters.steps(session.steps))
                liveMetric("kcal", Formatters.calories(session.calories))
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
    }

    private func liveMetric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button {
                confirmDiscard = true
            } label: {
                controlLabel("Discard", symbol: "xmark")
            }

            Button {
                if session.phase == .paused {
                    session.resume()
                } else {
                    session.pause()
                }
            } label: {
                Image(systemName: session.phase == .paused ? "play.fill" : "pause.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 84, height: 84)
                    .background(session.kind.color, in: Circle())
            }
            .accessibilityLabel(session.phase == .paused ? "Resume" : "Pause")

            Button {
                confirmFinish = true
            } label: {
                controlLabel("Finish", symbol: "flag.checkered")
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }

    private func controlLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 48, height: 48)
                .background(Color(.secondarySystemBackground), in: Circle())
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.primary)
    }
}

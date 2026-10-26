import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 24)

            Text("Stride")
                .font(.system(size: 42, weight: .bold, design: .rounded))
            Text("Walk, jog, and run — counted and mapped on iPhone.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 18) {
                OnboardingRow(
                    symbol: "shoeprints.fill",
                    title: "Daily steps",
                    detail: "Read today’s steps and walking distance from Apple Health."
                )
                OnboardingRow(
                    symbol: "map.fill",
                    title: "GPS workouts",
                    detail: "Start a walk, jog, or run and keep a live route, pace, and splits."
                )
                OnboardingRow(
                    symbol: "heart.fill",
                    title: "Saved to Health",
                    detail: "Finished sessions write back to Apple Health on this iPhone."
                )
            }
            .padding(24)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 36)

            Spacer()

            Button {
                Task {
                    isWorking = true
                    await model.completeOnboarding()
                    isWorking = false
                }
            } label: {
                HStack {
                    if isWorking {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Continue")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
            .disabled(isWorking)
        }
        .background(Color(.systemBackground))
    }
}

private struct OnboardingRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

import SwiftUI

struct StepRingView: View {
    let steps: Int
    let goal: Int

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.ringTrack, lineWidth: 18)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [Color.accentColor.opacity(0.4), Color.accentColor],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            VStack(spacing: 6) {
                Text(Formatters.steps(steps))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                Text("of \(Formatters.steps(goal)) steps")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(steps) steps of \(goal)")
    }
}

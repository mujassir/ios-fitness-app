import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily goal") {
                    Stepper(value: Bindable(model.settings).dailyStepGoal, in: 1_000...40_000, step: 500) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Step goal")
                            Text(Formatters.steps(model.settings.dailyStepGoal))
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }

                Section("Units") {
                    Picker("Distance", selection: Bindable(model.settings).unitSystem) {
                        ForEach(UnitSystem.allCases) { system in
                            Text(system.title).tag(system)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: Bindable(model.settings).weightKilograms, in: 30...200, step: 1) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Body weight")
                            Text(weightLabel)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Pace") {
                    Stepper(value: Bindable(model.settings).jogMinSpeedKmh, in: 2...10, step: 0.5) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Jog starts at")
                            Text(speedLabel(model.settings.jogMinSpeedKmh))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper(value: Bindable(model.settings).runMinSpeedKmh, in: 5...16, step: 0.5) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Run starts at")
                            Text(speedLabel(model.settings.runMinSpeedKmh))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("Walk is under \(speedLabel(model.settings.jogMinSpeedKmh)). Jog is \(speedLabel(model.settings.jogMinSpeedKmh))–\(speedLabel(model.settings.runMinSpeedKmh)). Run is faster than \(speedLabel(model.settings.runMinSpeedKmh)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Sessions") {
                    DisclosureGroup {
                        Stepper(value: Bindable(model.settings).walkMinSessionMinutes, in: 1...60, step: 1) {
                            LabeledContent("Min duration", value: "\(Int(model.settings.walkMinSessionMinutes)) min")
                        }
                        Stepper(value: Bindable(model.settings).walkMergeGapSeconds, in: 30...300, step: 15) {
                            LabeledContent("Join within", value: gapLabel(model.settings.walkMergeGapSeconds))
                        }
                    } label: {
                        sessionKindLabel(.walk, summary: "\(Int(model.settings.walkMinSessionMinutes)) min")
                    }

                    DisclosureGroup {
                        Stepper(value: Bindable(model.settings).jogMinSessionMinutes, in: 1...30, step: 1) {
                            LabeledContent("Min duration", value: "\(Int(model.settings.jogMinSessionMinutes)) min")
                        }
                        Stepper(value: Bindable(model.settings).jogMergeGapSeconds, in: 5...120, step: 5) {
                            LabeledContent("Join within", value: gapLabel(model.settings.jogMergeGapSeconds))
                        }
                    } label: {
                        sessionKindLabel(.jog, summary: "\(Int(model.settings.jogMinSessionMinutes)) min")
                    }

                    DisclosureGroup {
                        Stepper(value: Bindable(model.settings).runMinSessionMinutes, in: 1...30, step: 1) {
                            LabeledContent("Min duration", value: "\(Int(model.settings.runMinSessionMinutes)) min")
                        }
                        Stepper(value: Bindable(model.settings).runMergeGapSeconds, in: 5...60, step: 5) {
                            LabeledContent("Join within", value: gapLabel(model.settings.runMergeGapSeconds))
                        }
                    } label: {
                        sessionKindLabel(.run, summary: "\(Int(model.settings.runMinSessionMinutes)) min")
                    }

                    Text("Walk sessions are steady walks, not indoor wandering. Shorter or casual movement stays in the Walk tile only. Brief stops, walks, or jogs inside the join window are merged into the same session.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Workouts") {
                    Toggle("Auto-pause", isOn: Bindable(model.settings).autoPause)
                    Text("Pauses a session if you stand still for a few seconds, then resumes when you start moving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Apple Health") {
                    LabeledContent("Available") {
                        Text(model.health.isAvailable ? "Yes" : "No")
                    }
                    LabeledContent("Access") {
                        Text(model.health.isAuthorized ? "Allowed" : "Not granted")
                    }
                    Button {
                        Task {
                            await model.health.requestAuthorization()
                            await model.refresh()
                        }
                    } label: {
                        HStack {
                            Text(model.health.isRequesting ? "Waiting for Health…" : "Request Health access")
                            if model.health.isRequesting {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.health.isRequesting)
                    if let message = model.health.lastError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Stride")
                    LabeledContent("Platform", value: "iPhone")
                    Text("Tracks daily steps plus walk, jog, and run sessions with GPS, pace, and Apple Health.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("You")
        }
    }

    private func sessionKindLabel(_ kind: ActivityKind, summary: String) -> some View {
        HStack {
            Image(systemName: kind.symbol)
                .foregroundStyle(kind.color)
                .frame(width: 22)
            Text(kind.title)
            Spacer()
            Text(summary)
                .foregroundStyle(.secondary)
        }
    }

    private func speedLabel(_ kmh: Double) -> String {
        String(format: "%.1f km/h", kmh)
    }

    private func gapLabel(_ seconds: Double) -> String {
        if seconds >= 60 {
            return String(format: "%.0f min", seconds / 60)
        }
        return String(format: "%.0f sec", seconds)
    }

    private var weightLabel: String {
        if model.settings.usesMetric {
            return String(format: "%.0f kg", model.settings.weightKilograms)
        }
        let pounds = model.settings.weightKilograms * 2.20462
        return String(format: "%.0f lb", pounds)
    }
}

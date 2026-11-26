import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var goalPeriod: GoalPeriod = .daily

    var body: some View {
        NavigationStack {
            Form {
                Section {
                } header: {
                    ScreenTitle("You")
                        .textCase(nil)
                        .padding(.leading, -20)
                }
                Section {
                    ForEach(ActivityTab.allCases) { tab in
                        Toggle(isOn: Binding(
                            get: { model.settings.isTabEnabled(tab) },
                            set: { model.settings.setTab(tab, enabled: $0) }
                        )) {
                            Label {
                                Text(tab.title)
                            } icon: {
                                Image(systemName: tab.symbol)
                                    .foregroundStyle(tab.color)
                            }
                        }
                    }
                } header: {
                    Text("Tabs")
                } footer: {
                    Text("Summary and You are always shown. When the tabs don't all fit, swipe the tab bar to see the rest.")
                }

                Section {
                    CapsuleSegmentedPicker(
                        items: GoalPeriod.allCases,
                        selection: $goalPeriod,
                        title: \.title
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .accessibilityLabel("Goal period")

                    if showsStepGoal {
                        Stepper(
                            value: stepGoalBinding,
                            in: goalPeriod.stepRange,
                            step: goalPeriod.stepIncrement
                        ) {
                            goalLabel("Steps", Formatters.steps(model.settings.stepGoal(goalPeriod)), color: SummaryRings.stepsColor)
                        }
                    }
                    ForEach(enabledGoalKinds) { kind in
                        Stepper(
                            value: distanceGoalBinding(kind),
                            in: goalPeriod.distanceRangeKm,
                            step: goalPeriod.distanceIncrementKm
                        ) {
                            goalLabel(
                                goalTitle(kind),
                                goalDistance(model.settings.distanceGoalKm(for: kind, goalPeriod)),
                                color: kind.color
                            )
                        }
                    }
                    if model.settings.isTabEnabled(.energy) {
                        Stepper(
                            value: energyGoalBinding,
                            in: goalPeriod.energyRange,
                            step: goalPeriod.energyIncrement
                        ) {
                            goalLabel(
                                "Energy",
                                "\(Formatters.steps(model.settings.energyGoal(goalPeriod))) kcal",
                                color: SummaryRings.energyColor
                            )
                        }
                    }
                } header: {
                    Text("Goals")
                } footer: {
                    Text("Goals are shown for the tabs turned on above. Daily goals fill the rings in Daily view, weekly goals in Week view, and monthly goals in Month view.")
                }

                Section("Appearance") {
                    CapsuleSegmentedPicker(
                        items: AppAppearance.allCases,
                        selection: Bindable(model.settings).appearance,
                        title: \.title
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .accessibilityLabel("Appearance")
                }

                Section("Units") {
                    CapsuleSegmentedPicker(
                        items: UnitSystem.allCases,
                        selection: Bindable(model.settings).unitSystem,
                        title: \.title
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    .accessibilityLabel("Distance units")

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

                Section("Apple Health") {
                    LabeledContent("Available") {
                        Text(model.health.isAvailable ? "Yes" : "No")
                    }
                    LabeledContent("Access") {
                        Text(model.health.isAuthorized ? "Set up" : "Not set up")
                    }
                    Button {
                        if model.health.isAuthorized {
                            model.health.openHealthApp()
                        } else {
                            Task {
                                await model.health.requestAuthorization()
                                await model.refresh()
                            }
                        }
                    } label: {
                        HStack {
                            Text(healthButtonTitle)
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
                    LabeledContent("App", value: "RunCheck")
                    LabeledContent("Platform", value: "iPhone")
                    LabeledContent("Version", value: model.updates.currentVersion)
                    if let version = model.updates.availableVersion {
                        Button("Update to \(version)") { model.updates.openAppStore() }
                    } else {
                        Button("Check for Updates") {
                            Task { await model.updates.check(force: true) }
                        }
                    }
                    Link("Privacy Policy", destination: URL(string: "https://mujassir.com/runcheck/privacy/")!)
                    Link("Support", destination: URL(string: "https://mujassir.github.io/ios-fitness-app/support")!)
                    Text("Shows daily steps plus walk, jog, and run sessions from Apple Health.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("You")
            .toolbar(.hidden, for: .navigationBar)
            .contentMargins(.top, 8, for: .scrollContent)
            .clearsTabBar()
        }
    }

    private func goalLabel(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
        }
    }

    /// Goals follow the tabs that are turned on. Steps also shows when no
    /// tab is on, because Summary then falls back to a steps ring.
    private var showsStepGoal: Bool {
        model.settings.isTabEnabled(.stepper) || model.settings.enabledTabs.isEmpty
    }

    private var enabledGoalKinds: [ActivityKind] {
        ActivityTab.allCases.compactMap { tab in
            guard model.settings.isTabEnabled(tab), case .kind(let kind) = tab.focus else { return nil }
            return kind
        }
    }

    private var energyGoalBinding: Binding<Int> {
        Binding(
            get: { model.settings.energyGoal(goalPeriod) },
            set: { model.settings.setEnergyGoal($0, for: goalPeriod) }
        )
    }

    private var stepGoalBinding: Binding<Int> {
        Binding(
            get: { model.settings.stepGoal(goalPeriod) },
            set: { model.settings.setStepGoal($0, for: goalPeriod) }
        )
    }

    private func distanceGoalBinding(_ kind: ActivityKind) -> Binding<Double> {
        Binding(
            get: { model.settings.distanceGoalKm(for: kind, goalPeriod) },
            set: { model.settings.setDistanceGoalKm($0, for: kind, goalPeriod) }
        )
    }

    private func goalTitle(_ kind: ActivityKind) -> String {
        switch kind {
        case .run: "Running"
        case .jog: "Jogging"
        case .walk: "Walk"
        }
    }

    private func goalDistance(_ km: Double) -> String {
        Formatters.distance(km * 1000, metric: model.settings.usesMetric)
    }

    private var healthButtonTitle: String {
        if model.health.isRequesting { return "Waiting for Health…" }
        return model.health.isAuthorized ? "Manage access in Health" : "Allow Health access"
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

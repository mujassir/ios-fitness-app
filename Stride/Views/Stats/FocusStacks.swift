import SwiftUI

/// Running, Jogging or Walk tab: distance against the goal, that kind's
/// totals, and its sessions.
struct KindFocusStack: View {
    @Environment(AppModel.self) private var model
    let kind: ActivityKind
    let breakdown: ActivityStatsBreakdown
    let caption: String
    let goalPeriod: GoalPeriod
    /// Days in the period up to today; the by-day list shows when more than one.
    var days: [Date] = []

    private var stats: ActivityKindStats {
        breakdown.byKind[kind] ?? ActivityKindStats()
    }

    private var sessions: [HealthActivitySession] {
        breakdown.sessions.filter { $0.kind == kind }.sorted { $0.start > $1.start }
    }

    private var metric: Bool { model.settings.usesMetric }

    private var goalMeters: Double {
        model.settings.distanceGoalKm(for: kind, goalPeriod) * 1000
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HealthAccessBanner(isEmpty: breakdown.isEmpty)

            GoalRingView(
                progress: goalMeters > 0 ? stats.distanceMeters / goalMeters : 0,
                value: Formatters.distance(stats.distanceMeters, metric: metric),
                caption: "of \(Formatters.distance(goalMeters, metric: metric)) \(kind.title.lowercased()) goal",
                color: kind.color
            )
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Time",
                    value: Formatters.duration(stats.duration),
                    unit: "",
                    symbol: "clock.fill"
                )
                MetricTile(
                    title: "Pace",
                    value: Formatters.pace(secondsPerMeter: stats.averagePaceSecondsPerMeter, metric: metric),
                    unit: "",
                    symbol: "speedometer"
                )
                MetricTile(
                    title: "Energy",
                    value: Formatters.calories(stats.calories),
                    unit: "kcal",
                    symbol: "flame.fill"
                )
                MetricTile(
                    title: "Steps",
                    value: Formatters.steps(stats.steps),
                    unit: "steps",
                    symbol: "shoeprints.fill"
                )
            }

            if days.count > 1 {
                dayList
            }

            if !sessions.isEmpty {
                sessionList
            }
        }
    }

    /// Distance of this kind on each day, against the daily goal.
    private var dayList: some View {
        let dailyGoal = model.settings.distanceGoalKm(for: kind, .daily) * 1000
        let rows = days.sorted(by: >).map { day in
            let stats = model.health.stats(
                on: day,
                detection: model.settings.detection,
                weightKilograms: model.settings.weightKilograms
            )
            return (day, (stats.byKind[kind] ?? ActivityKindStats()).distanceMeters)
        }
        let maxValue = max(dailyGoal, rows.map(\.1).max() ?? 0)
        return VStack(alignment: .leading, spacing: 12) {
            Text("By each day")
                .font(.headline)

            ForEach(rows, id: \.0) { day, meters in
                HStack(spacing: 12) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 64, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(kind.color.opacity(meters >= dailyGoal ? 1 : 0.45))
                            .frame(width: max(4, proxy.size.width * meters / max(maxValue, 1)))
                    }
                    .frame(height: 10)
                    Text(Formatters.distance(meters, metric: metric))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 76, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day())): \(Formatters.distance(meters, metric: metric))")
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Text("\(sessions.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if sessions.isEmpty {
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session, metric: metric)
                    } label: {
                        HealthSessionRow(session: session, metric: metric)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyText: String {
        switch kind {
        case .walk:
            "No steady walks in this period. Moving around at home or in the office isn't listed as a session."
        case .jog:
            "No jogs in this period."
        case .run:
            "No runs in this period."
        }
    }
}

/// Steps tab: steps against the step goal, plus steps for each day.
struct StepsFocusStack: View {
    @Environment(AppModel.self) private var model
    let breakdown: ActivityStatsBreakdown
    let caption: String
    let days: [Date]
    let goalPeriod: GoalPeriod

    private var metric: Bool { model.settings.usesMetric }

    private var goal: Int { model.settings.stepGoal(goalPeriod) }

    var body: some View {
        let totals = breakdown.totals
        VStack(spacing: 20) {
            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HealthAccessBanner(isEmpty: breakdown.isEmpty)

            GoalRingView(
                progress: goal > 0 ? Double(totals.steps) / Double(goal) : 0,
                value: Formatters.steps(totals.steps),
                caption: "of \(Formatters.steps(goal)) steps",
                color: Palette.steps
            )
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Distance",
                    value: Formatters.distanceValue(totals.distanceMeters, metric: metric),
                    unit: Formatters.distanceUnit(totals.distanceMeters, metric: metric),
                    symbol: "point.bottomleft.forward.to.point.topright.scurvepath"
                )
                MetricTile(
                    title: "Energy",
                    value: Formatters.calories(totals.calories),
                    unit: "kcal",
                    symbol: "flame.fill"
                )
            }

            if days.count > 1 {
                dayList
            }
        }
    }

    private var dayList: some View {
        let goal = model.settings.dailyStepGoal
        let rows = days.sorted(by: >).map { ($0, model.health.metrics(on: $0).steps) }
        let maxSteps = max(goal, rows.map(\.1).max() ?? 0)
        return VStack(alignment: .leading, spacing: 12) {
            Text("By each day")
                .font(.headline)

            ForEach(rows, id: \.0) { day, steps in
                HStack(spacing: 12) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 64, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Palette.steps.opacity(steps >= goal ? 1 : 0.45))
                            .frame(width: max(4, proxy.size.width * Double(steps) / Double(max(maxSteps, 1))))
                    }
                    .frame(height: 10)
                    Text(Formatters.steps(steps))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .frame(width: 64, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day())): \(steps) steps")
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct GoalRingView: View {
    let progress: Double
    let value: String
    let caption: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Palette.ringTrack, lineWidth: 18)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.4), color], center: .center),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)

            VStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text(caption)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value), \(caption)")
    }
}

/// Summary tab: one ring per enabled tab (Running, Jogging, Walk, Steps, Energy),
/// outermost first, each filled against that tab's goal for the period.
struct SummaryRings: View {
    @Environment(AppModel.self) private var model
    let breakdown: ActivityStatsBreakdown
    let goalPeriod: GoalPeriod

    struct Ring: Identifiable {
        let id: ActivityTab
        let title: String
        let symbol: String
        let color: Color
        let progress: Double
        let detail: String
        /// False when there's nothing yet, so the ring is left out.
        let hasValue: Bool
    }

    static let stepsColor = Palette.steps
    static let energyColor = Palette.energy

    private var metric: Bool { model.settings.usesMetric }

    private var rings: [Ring] {
        let enabled = ActivityTab.allCases.filter { model.settings.isTabEnabled($0) }
        // With no activity tabs on, the ring still shows steps.
        let shown = enabled.isEmpty ? [ActivityTab.stepper] : enabled
        return shown
            .map { Self.ring(for: $0, settings: model.settings, breakdown: breakdown, goalPeriod: goalPeriod) }
            .filter(\.hasValue)
    }

    /// The modes shown as rings: the tabs that are on, or Steps when none are.
    static func shownTabs(_ settings: AppSettings) -> [ActivityTab] {
        let enabled = ActivityTab.allCases.filter { settings.isTabEnabled($0) }
        return enabled.isEmpty ? [ActivityTab.stepper] : enabled
    }

    /// One ring per mode for `breakdown`, filled against `goalPeriod`'s goal.
    static func ring(
        for tab: ActivityTab,
        settings: AppSettings,
        breakdown: ActivityStatsBreakdown,
        goalPeriod: GoalPeriod
    ) -> Ring {
        let metric = settings.usesMetric
        switch tab.focus {
        case .kind(let kind):
            let meters = (breakdown.byKind[kind] ?? ActivityKindStats()).distanceMeters
            let goal = settings.distanceGoalKm(for: kind, goalPeriod) * 1000
            return Ring(
                id: tab,
                title: tab.title,
                symbol: tab.symbol,
                color: kind.color,
                progress: goal > 0 ? meters / goal : 0,
                detail: "\(Formatters.distance(meters, metric: metric)) of \(Formatters.distance(goal, metric: metric))",
                hasValue: meters >= 1
            )
        case .energy:
            let kcal = breakdown.totals.calories
            let goal = settings.energyGoal(goalPeriod)
            return Ring(
                id: tab,
                title: tab.title,
                symbol: tab.symbol,
                color: Self.energyColor,
                progress: goal > 0 ? kcal / Double(goal) : 0,
                detail: "\(Formatters.calories(kcal)) of \(Formatters.steps(goal)) kcal",
                hasValue: kcal >= 0.5
            )
        case .steps, .summary:
            let steps = breakdown.totals.steps
            let goal = settings.stepGoal(goalPeriod)
            return Ring(
                id: tab,
                title: "Steps",
                symbol: tab.symbol,
                color: Self.stepsColor,
                progress: goal > 0 ? Double(steps) / Double(goal) : 0,
                detail: "\(Formatters.steps(steps)) of \(Formatters.steps(goal))",
                hasValue: steps > 0
            )
        }
    }

    var body: some View {
        let rings = rings
        if rings.isEmpty {
            HStack(spacing: 16) {
                Circle()
                    .stroke(Palette.ringTrack, lineWidth: 14)
                    .frame(width: 56, height: 56)
                Text(emptyText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            ringCard(rings)
        }
    }

    private var emptyText: String {
        switch goalPeriod {
        case .daily: "No activity yet for this day."
        case .weekly: "No activity yet for this week."
        case .monthly: "No activity yet this month."
        }
    }

    private func ringCard(_ rings: [Ring]) -> some View {
        HStack(spacing: 20) {
            ConcentricRings(rings: rings)
                .frame(width: 168, height: 168)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(rings) { ring in
                    HStack(spacing: 10) {
                        Image(systemName: ring.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ring.color)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ring.title)
                                .font(.subheadline.weight(.semibold))
                            Text(ring.detail)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(ring.title): \(ring.detail), \(Int(min(ring.progress, 9.99) * 100)) percent")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ConcentricRings: View {
    let rings: [SummaryRings.Ring]

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let count = CGFloat(max(rings.count, 1))
            // Thinner rings when there are more of them.
            let gap: CGFloat = 4
            let line = min(20, (size / 2 - gap * (count - 1)) / count * 0.9)
            ZStack {
                ForEach(Array(rings.enumerated()), id: \.element.id) { index, ring in
                    let inset = CGFloat(index) * (line + gap) + line / 2
                    let progress = min(max(ring.progress, 0), 1)
                    ZStack {
                        Circle()
                            .stroke(ring.color.opacity(0.18), lineWidth: line)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(ring.color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                    .padding(inset)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// Energy tab: active energy against the energy goal, plus energy for each day.
struct EnergyFocusStack: View {
    @Environment(AppModel.self) private var model
    let breakdown: ActivityStatsBreakdown
    let caption: String
    let days: [Date]
    let goalPeriod: GoalPeriod

    private var metric: Bool { model.settings.usesMetric }

    private var goal: Int { model.settings.energyGoal(goalPeriod) }

    var body: some View {
        let totals = breakdown.totals
        VStack(spacing: 20) {
            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HealthAccessBanner(isEmpty: breakdown.isEmpty)

            GoalRingView(
                progress: goal > 0 ? totals.calories / Double(goal) : 0,
                value: Formatters.calories(totals.calories),
                caption: "of \(Formatters.steps(goal)) kcal",
                color: SummaryRings.energyColor
            )
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Time",
                    value: Formatters.duration(totals.duration),
                    unit: "",
                    symbol: "clock.fill"
                )
                MetricTile(
                    title: "Steps",
                    value: Formatters.steps(totals.steps),
                    unit: "steps",
                    symbol: "shoeprints.fill"
                )
            }

            ForEach(ActivityKind.allCases) { kind in
                if let stats = breakdown.byKind[kind], stats.calories > 1 {
                    HStack {
                        Label(kind.title, systemImage: kind.symbol)
                            .foregroundStyle(kind.color)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Formatters.calories(stats.calories)) kcal")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .padding(16)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }

            if days.count > 1 {
                dayList
            }
        }
    }

    private var dayList: some View {
        let dailyGoal = Double(model.settings.energyGoal(.daily))
        let rows = days.sorted(by: >).map { ($0, model.health.metrics(on: $0).calories) }
        let maxValue = max(dailyGoal, rows.map(\.1).max() ?? 0)
        return VStack(alignment: .leading, spacing: 12) {
            Text("By each day")
                .font(.headline)

            ForEach(rows, id: \.0) { day, kcal in
                HStack(spacing: 12) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 64, alignment: .leading)
                    GeometryReader { proxy in
                        Capsule()
                            .fill(SummaryRings.energyColor.opacity(kcal >= dailyGoal ? 1 : 0.45))
                            .frame(width: max(4, proxy.size.width * kcal / max(maxValue, 1)))
                    }
                    .frame(height: 10)
                    Text(Formatters.calories(kcal))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .frame(width: 64, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day())): \(Formatters.calories(kcal)) kilocalories")
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// Summary's Week view: each day as small concentric rings, one per mode,
/// filled against that mode's daily goal.
struct DailyRingsList: View {
    @Environment(AppModel.self) private var model
    let days: [Date]

    var body: some View {
        let tabs = SummaryRings.shownTabs(model.settings)
        VStack(alignment: .leading, spacing: 12) {
            Text("By each day")
                .font(.headline)

            ForEach(days.sorted(by: >), id: \.self) { day in
                let breakdown = model.health.stats(
                    on: day,
                    detection: model.settings.detection,
                    weightKilograms: model.settings.weightKilograms
                )
                let rings = tabs.map {
                    SummaryRings.ring(for: $0, settings: model.settings, breakdown: breakdown, goalPeriod: .daily)
                }
                HStack(spacing: 14) {
                    Text(day.formatted(.dateTime.weekday(.abbreviated).day()))
                        .font(.subheadline.monospacedDigit())
                        .frame(width: 64, alignment: .leading)
                    ConcentricRings(rings: rings)
                        .frame(width: 44, height: 44)
                    HStack(spacing: 6) {
                        ForEach(rings) { ring in
                            Capsule()
                                .fill(ring.color.opacity(ring.hasValue ? 1 : 0.18))
                                .frame(width: 6, height: 6 + 18 * min(max(ring.progress, 0), 1))
                                .frame(height: 24, alignment: .bottom)
                        }
                    }
                    Spacer()
                    Text("\(Formatters.steps(breakdown.totals.steps)) steps")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(day.formatted(.dateTime.weekday(.wide).month().day())): "
                        + rings.map { "\($0.title) \($0.detail)" }.joined(separator: ", ")
                )
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

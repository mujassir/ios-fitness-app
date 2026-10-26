import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var model
    @State private var period: StatsPeriod = .today
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)
    @State private var weekOffset = 0

    private let pastWeekLimit = 52
    private var calendar: Calendar { StatsPeriod.sundayCalendar }

    private var displayedWeekStart: Date {
        weekStart(for: weekOffset)
    }

    private var weekdayDates: [Date] {
        StatsPeriod.daysInWeek(containing: displayedWeekStart)
    }

    private var breakdown: ActivityStatsBreakdown {
        switch period {
        case .today:
            model.health.stats(
                on: calendar.startOfDay(for: .now),
                detection: model.settings.detection,
                weightKilograms: model.settings.weightKilograms
            )
        case .week:
            model.health.stats(
                on: selectedDay,
                detection: model.settings.detection,
                weightKilograms: model.settings.weightKilograms
            )
        case .month:
            model.health.monthStats(
                detection: model.settings.detection,
                weightKilograms: model.settings.weightKilograms
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("Period", selection: $period) {
                        ForEach(StatsPeriod.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: period) { _, newValue in
                        if newValue == .today {
                            selectedDay = calendar.startOfDay(for: .now)
                        }
                    }

                    if period == .week {
                        weekdayPager
                    }

                    if period == .month {
                        monthWeekList
                    } else {
                        StatsBreakdownStack(
                            breakdown: breakdown,
                            caption: caption,
                            showHero: true,
                            isMonth: false
                        )
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await model.refresh() }
            .overlay {
                if model.health.isLoadingStats && model.health.dailyMetrics.isEmpty {
                    ProgressView("Reading Health…")
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var caption: String {
        switch period {
        case .today:
            calendar.startOfDay(for: .now).formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .week:
            selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .month:
            Date.now.formatted(.dateTime.month(.wide).year())
        }
    }

    private var monthWeekList: some View {
        let totals = breakdown.totals
        let weeks = model.health.weekSummaries(
            detection: model.settings.detection,
            weightKilograms: model.settings.weightKilograms
        ).sorted { $0.start > $1.start }

        return VStack(alignment: .leading, spacing: 16) {
            Text(Date.now.formatted(.dateTime.month(.wide).year()))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Distance",
                    value: Formatters.distanceValue(totals.distanceMeters, metric: model.settings.usesMetric),
                    unit: Formatters.distanceUnit(totals.distanceMeters, metric: model.settings.usesMetric),
                    symbol: "point.bottomleft.forward.to.point.topright.scurvepath"
                )
                MetricTile(
                    title: "Steps",
                    value: Formatters.steps(totals.steps),
                    unit: "steps",
                    symbol: "shoeprints.fill"
                )
                MetricTile(
                    title: "Energy",
                    value: Formatters.calories(totals.calories),
                    unit: "kcal",
                    symbol: "flame.fill"
                )
                MetricTile(
                    title: "Time",
                    value: Formatters.duration(totals.duration),
                    unit: "",
                    symbol: "clock.fill"
                )
            }

            ForEach(weeks) { week in
                Button {
                    open(week: week.start)
                } label: {
                    MonthWeekTile(summary: week, metric: model.settings.usesMetric)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func open(week start: Date) {
        let current = StatsPeriod.startOfWeek(containing: .now)
        let days = calendar.dateComponents([.day], from: start, to: current).day ?? 0
        weekOffset = max(-pastWeekLimit, min(0, -(days / 7)))
        period = .week
        alignSelectedDayToWeek()
        Task {
            await model.health.ensureCoverage(
                of: start,
                weightKilograms: model.settings.weightKilograms
            )
        }
    }

    private var weekRangeCaption: String {
        guard let first = weekdayDates.first, let last = weekdayDates.last else { return "This week" }
        if weekOffset == 0 {
            return "This week"
        }
        let format = Date.FormatStyle().month(.abbreviated).day()
        return "\(first.formatted(format)) – \(last.formatted(format))"
    }

    private var weekdayPager: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(weekRangeCaption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TabView(selection: $weekOffset) {
                ForEach(-pastWeekLimit...0, id: \.self) { offset in
                    WeekDayStrip(
                        dates: StatsPeriod.daysInWeek(containing: weekStart(for: offset)),
                        selectedDay: $selectedDay
                    )
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 64)
            .onChange(of: weekOffset) { _, _ in
                alignSelectedDayToWeek()
                Task {
                    await model.health.ensureCoverage(
                        of: displayedWeekStart,
                        weightKilograms: model.settings.weightKilograms
                    )
                }
            }
        }
        .accessibilityHint("Swipe left or right to change week")
    }

    private func weekStart(for offset: Int) -> Date {
        calendar.date(
            byAdding: .weekOfYear,
            value: offset,
            to: StatsPeriod.startOfWeek(containing: .now)
        ) ?? StatsPeriod.startOfWeek(containing: .now)
    }

    private func alignSelectedDayToWeek() {
        let days = weekdayDates
        let weekday = calendar.component(.weekday, from: selectedDay)
        if let match = days.first(where: { calendar.component(.weekday, from: $0) == weekday }),
           !StatsPeriod.isFutureDay(match) {
            selectedDay = match
            return
        }
        selectedDay = days.last { !StatsPeriod.isFutureDay($0) } ?? calendar.startOfDay(for: .now)
    }
}

private struct WeekDayStrip: View {
    let dates: [Date]
    @Binding var selectedDay: Date

    private var calendar: Calendar { StatsPeriod.sundayCalendar }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(dates, id: \.self) { date in
                let isFuture = StatsPeriod.isFutureDay(date)
                let isSelected = !isFuture && calendar.isDate(date, inSameDayAs: selectedDay)
                Button {
                    selectedDay = date
                } label: {
                    VStack(spacing: 4) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption.weight(.semibold))
                        Text(isFuture ? " " : date.formatted(.dateTime.day()))
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(
                        isFuture
                            ? Color.primary.opacity(0.28)
                            : isSelected ? Color.white : Color.primary
                    )
                    .background(
                        isSelected
                            ? Color.accentColor
                            : Color.primary.opacity(isFuture ? 0 : 0.06),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isFuture)
                .accessibilityLabel(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .accessibilityHidden(isFuture)
            }
        }
    }
}

private struct MonthWeekTile: View {
    let summary: WeekSummary
    let metric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(rangeLabel)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                labeledValue("Steps", Formatters.steps(summary.steps))
                Spacer()
                labeledValue(
                    "Distance",
                    Formatters.distance(summary.distanceMeters, metric: metric)
                )
                Spacer()
                labeledValue("Time", Formatters.duration(summary.duration))
            }

            if summary.sessionCount > 0 {
                Text(kindLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            } else if !summary.hasActivity {
                Text("No activity")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var rangeLabel: String {
        let format = Date.FormatStyle().month(.abbreviated).day()
        return "\(summary.start.formatted(format)) – \(summary.end.formatted(format))"
    }

    private var subtitle: String {
        let sessions = summary.sessionCount == 1 ? "1 session" : "\(summary.sessionCount) sessions"
        if summary.isCurrent {
            return summary.sessionCount > 0 ? "This week · \(sessions)" : "This week"
        }
        return sessions
    }

    private var kindLabel: String {
        ActivityKind.allCases.compactMap { kind in
            guard let count = summary.kindCounts[kind], count > 0 else { return nil }
            return "\(count) \(kind.title.lowercased())"
        }
        .joined(separator: " · ")
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

private struct StatsBreakdownStack: View {
    @Environment(AppModel.self) private var model
    let breakdown: ActivityStatsBreakdown
    let caption: String
    let showHero: Bool
    let isMonth: Bool

    private var kindsWithData: [ActivityKind] {
        ActivityKind.allCases.filter { kind in
            (breakdown.byKind[kind] ?? ActivityKindStats()).hasData
        }
    }

    private var hasRunSession: Bool {
        breakdown.sessions.contains { $0.kind == .run }
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !model.health.isAvailable {
                PermissionBanner(
                    title: "Apple Health unavailable",
                    detail: "Walk, jog, and run stats are read from Health on this iPhone."
                )
            } else if breakdown.isEmpty && model.health.todaySteps == 0 && !model.health.isAuthorized {
                PermissionBanner(
                    title: "Connect Apple Health",
                    detail: model.health.lastError
                        ?? "Allow Steps, Distance, Energy, and Workouts so Stats can fill in.",
                    isWorking: model.health.isRequesting
                ) {
                    Task {
                        await model.health.requestAuthorization()
                        await model.refresh()
                    }
                }
            }

            if showHero {
                dayHero
            }

            totalsCard

            if hasRunSession {
                recentList
            }

            ForEach(kindsWithData) { kind in
                KindStatsCard(
                    kind: kind,
                    stats: breakdown.byKind[kind] ?? ActivityKindStats(),
                    metric: model.settings.usesMetric
                )
            }

            if !hasRunSession {
                recentList
            }

            Text(paceFootnote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var paceFootnote: String {
        let walk = String(format: "%.0f", model.settings.jogMinSpeedKmh)
        let run = String(format: "%.0f", model.settings.runMinSpeedKmh)
        let walkMin = String(format: "%.0f", model.settings.walkMinSessionMinutes)
        let jogMin = String(format: "%.0f", model.settings.jogMinSessionMinutes)
        let runMin = String(format: "%.0f", model.settings.runMinSessionMinutes)
        return "Walk is under \(walk) km/h, jog is \(walk)–\(run) km/h, run is over \(run) km/h. Sessions list steady walks over \(walkMin) min — not indoor wandering — plus jogs over \(jogMin) min and runs over \(runMin) min. Casual movement still counts in the tiles when there is data."
    }

    private var dayHero: some View {
        VStack(spacing: 16) {
            StepRingView(steps: breakdown.day.steps, goal: model.settings.dailyStepGoal)
                .frame(maxWidth: 280)
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Distance",
                    value: Formatters.distanceValue(breakdown.day.distanceMeters, metric: model.settings.usesMetric),
                    unit: Formatters.distanceUnit(breakdown.day.distanceMeters, metric: model.settings.usesMetric),
                    symbol: "point.bottomleft.forward.to.point.topright.scurvepath"
                )
                MetricTile(
                    title: "Energy",
                    value: Formatters.calories(breakdown.day.calories),
                    unit: "kcal",
                    symbol: "flame.fill"
                )
            }
        }
    }

    private var totalsCard: some View {
        let totals = breakdown.totals
        return VStack(alignment: .leading, spacing: 14) {
            Text(isMonth ? "This month" : "Activity")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Steps",
                    value: Formatters.steps(totals.steps),
                    unit: "steps",
                    symbol: "shoeprints.fill"
                )
                MetricTile(
                    title: "Time",
                    value: Formatters.duration(totals.duration),
                    unit: "",
                    symbol: "clock.fill"
                )
                if isMonth {
                    MetricTile(
                        title: "Distance",
                        value: Formatters.distanceValue(totals.distanceMeters, metric: model.settings.usesMetric),
                        unit: Formatters.distanceUnit(totals.distanceMeters, metric: model.settings.usesMetric),
                        symbol: "point.bottomleft.forward.to.point.topright.scurvepath"
                    )
                    MetricTile(
                        title: "Energy",
                        value: Formatters.calories(totals.calories),
                        unit: "kcal",
                        symbol: "flame.fill"
                    )
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions")
                    .font(.headline)
                Spacer()
                Text("\(breakdown.sessions.count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if breakdown.sessions.isEmpty {
                Text(breakdown.day.hasActivity
                     ? "No disciplined walk, jog, or run to list. Moving around at home or in the office stays in the tiles, not as a session."
                     : "Nothing recorded in Apple Health for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(breakdown.sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session, metric: model.settings.usesMetric)
                    } label: {
                        HealthSessionRow(session: session, metric: model.settings.usesMetric)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct KindStatsCard: View {
    let kind: ActivityKind
    let stats: ActivityKindStats
    let metric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: kind.symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(kind.color)
                    .frame(width: 44, height: 44)
                    .background(kind.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(Formatters.distance(stats.distanceMeters, metric: metric))
                    .font(.title3.weight(.bold).monospacedDigit())
            }

            HStack {
                labeledValue("Time", Formatters.duration(stats.duration))
                Spacer()
                labeledValue("Pace", Formatters.pace(secondsPerMeter: stats.averagePaceSecondsPerMeter, metric: metric))
                Spacer()
                labeledValue("Energy", "\(Formatters.calories(stats.calories)) kcal")
            }
            .font(.subheadline.monospacedDigit())
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var subtitle: String {
        let sessionText = stats.count == 1 ? "1 session" : "\(stats.count) sessions"
        if stats.steps > 0 {
            return "\(sessionText) · \(Formatters.steps(stats.steps)) steps"
        }
        return sessionText
    }

    private func labeledValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

private struct HealthSessionRow: View {
    let session: HealthActivitySession
    let metric: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: session.kind.symbol)
                .font(.title3)
                .foregroundStyle(session.kind.color)
                .frame(width: 40, height: 40)
                .background(session.kind.color.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(session.kind.title)
                    .font(.headline)
                Text(session.start.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(Formatters.distance(session.distanceMeters, metric: metric))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                Text(Formatters.duration(session.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var model
    var focus: StatsFocus = .summary

    // Period and date live in AppModel so every tab shows the same Daily /
    // Week / Month choice and the same selected day or week.
    private var selection: StatsSelection { model.selection }
    @State private var scrollPosition = ScrollPosition(edge: .top)
    /// False until this page has scrolled to the shared position, so its
    /// starting offset of 0 doesn't overwrite the saved one.
    @State private var restoredScroll = false

    private var period: StatsPeriod {
        get { selection.period }
        nonmutating set { selection.period = newValue }
    }

    private var selectedDay: Date {
        get { selection.selectedDay }
        nonmutating set { selection.selectedDay = newValue }
    }

    private var weekOffset: Int {
        get { selection.weekOffset }
        nonmutating set { selection.weekOffset = newValue }
    }

    private var monthOffset: Int {
        get { selection.monthOffset }
        nonmutating set { selection.monthOffset = newValue }
    }

    private var selectedWeekStart: Date {
        get { selection.selectedWeekStart }
        nonmutating set { selection.selectedWeekStart = newValue }
    }

    private let pastWeekLimit = 52
    private let pastMonthLimit = 12
    private var calendar: Calendar { StatsPeriod.sundayCalendar }

    private var displayedWeekStart: Date {
        weekStart(for: weekOffset)
    }

    private var weekdayDates: [Date] {
        StatsPeriod.daysInWeek(containing: displayedWeekStart)
    }

    private var selectedWeekEnd: Date {
        calendar.date(byAdding: .weekOfYear, value: 1, to: selectedWeekStart)
            ?? selectedWeekStart.addingTimeInterval(7 * 24 * 3600)
    }

    private var breakdown: ActivityStatsBreakdown {
        switch period {
        case .daily:
            model.health.stats(
                on: selectedDay,
                detection: model.settings.detection,
                weightKilograms: model.settings.weightKilograms
            )
        case .week:
            model.health.rangeStats(
                from: selectedWeekStart,
                to: selectedWeekEnd,
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
                    ScreenTitle(focus.title)

                    CapsuleSegmentedPicker(
                        items: StatsPeriod.allCases,
                        selection: Bindable(selection).period,
                        title: \.title
                    )
                    .accessibilityLabel("Period")

                    switch period {
                    case .daily:
                        weekdayPager
                    case .week:
                        monthWeekPager
                    case .month:
                        EmptyView()
                    }

                    if !isReady {
                        PeriodLoadingCard(period: period)
                    } else {
                        switch period {
                    case .daily:
                        content(
                            caption: selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                            totalsTitle: "Activity",
                            days: [selectedDay]
                        )
                    case .week:
                        content(
                            caption: selectedWeekCaption,
                            totalsTitle: selectedWeekStart == StatsPeriod.startOfWeek(containing: .now)
                                ? "This week" : "Week",
                            days: StatsPeriod.daysInWeek(containing: selectedWeekStart)
                                .filter { !StatsPeriod.isFutureDay($0) }
                        )
                    case .month:
                        if focus == .summary {
                            monthWeekList
                        } else {
                            content(
                                caption: Date.now.formatted(.dateTime.month(.wide).year()),
                                totalsTitle: "This month",
                                days: daysThisMonth
                            )
                        }
                    }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 8)
            }
            .clearsTabBar()
            .scrollPosition($scrollPosition)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                guard restoredScroll else { return }
                selection.scrollOffset = max(0, offset)
            }
            .task {
                // Open where the last stats tab was scrolled to, once the
                // page has laid out its content.
                let target = selection.scrollOffset
                if target > 0 {
                    await Task.yield()
                    scrollPosition.scrollTo(y: target)
                    try? await Task.sleep(for: .milliseconds(50))
                }
                restoredScroll = true
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(focus.title)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await model.refresh() }
            .task(id: prepareID) {
                await model.health.prepare(
                    neededRanges,
                    detection: model.settings.detection,
                    weightKilograms: model.settings.weightKilograms
                )
            }
            .overlay {
                if model.health.isLoadingStats && model.health.dailyMetrics.isEmpty {
                    ProgressView("Reading Health…")
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    /// Date ranges the current view needs worked out before it can draw.
    private var neededRanges: [HealthKitService.DateRange] {
        let base: [HealthKitService.DateRange]
        switch period {
        case .daily:
            base = [HealthKitService.dayRange(selectedDay)]
        case .week:
            base = [HealthKitService.weekRange(selectedWeekStart)]
        case .month:
            base = focus == .summary ? HealthKitService.monthRanges() : [HealthKitService.monthRange()]
        }
        // Running, Jogging and Walk list each day in Week and Month; Summary
        // does in Week.
        let listsDays: Bool
        switch focus {
        case .kind: listsDays = period != .daily
        case .summary: listsDays = period == .week
        default: listsDays = false
        }
        guard listsDays else { return base }
        return base + periodDays.map(HealthKitService.dayRange)
    }

    private var periodDays: [Date] {
        switch period {
        case .daily: [selectedDay]
        case .week: StatsPeriod.daysInWeek(containing: selectedWeekStart).filter { !StatsPeriod.isFutureDay($0) }
        case .month: daysThisMonth
        }
    }

    private var isReady: Bool {
        model.health.isPrepared(
            neededRanges,
            detection: model.settings.detection,
            weightKilograms: model.settings.weightKilograms
        )
    }

    private struct PrepareID: Hashable {
        let period: StatsPeriod
        let day: Date
        let week: Date
        let detection: ActivityDetectionSettings
        let weight: Double
        let version: Int
    }

    private var prepareID: PrepareID {
        PrepareID(
            period: period,
            day: selectedDay,
            week: selectedWeekStart,
            detection: model.settings.detection,
            weight: model.settings.weightKilograms,
            version: model.health.preparedVersion
        )
    }

    /// The screen body for this tab's focus. `days` are the days in the
    /// period (up to today). Goals come from the period's own goal.
    @ViewBuilder
    private func content(caption: String, totalsTitle: String, days: [Date]) -> some View {
        switch focus {
        case .summary:
            StatsBreakdownStack(
                breakdown: breakdown,
                caption: caption,
                showHero: period == .daily,
                isMonth: period != .daily,
                goalPeriod: GoalPeriod(period),
                totalsTitle: totalsTitle,
                days: days
            )
        case .kind(let kind):
            KindFocusStack(
                kind: kind,
                breakdown: breakdown,
                caption: caption,
                goalPeriod: GoalPeriod(period),
                days: days
            )
        case .energy:
            EnergyFocusStack(
                breakdown: breakdown,
                caption: caption,
                days: days,
                goalPeriod: GoalPeriod(period)
            )
        case .steps:
            StepsFocusStack(
                breakdown: breakdown,
                caption: caption,
                days: days,
                goalPeriod: GoalPeriod(period)
            )
        }
    }

    private var daysThisMonth: [Date] {
        let cal = Calendar.current
        guard let month = cal.dateInterval(of: .month, for: .now) else { return [] }
        var days: [Date] = []
        var day = month.start
        while day < month.end, !StatsPeriod.isFutureDay(day) {
            days.append(day)
            day = cal.date(byAdding: .day, value: 1, to: day) ?? month.end
        }
        return days
    }

    private var selectedWeekCaption: String {
        let format = Date.FormatStyle().month(.abbreviated).day()
        let last = calendar.date(byAdding: .day, value: 6, to: selectedWeekStart) ?? selectedWeekStart
        return "\(selectedWeekStart.formatted(format)) – \(last.formatted(format))"
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

            HealthAccessBanner(isEmpty: breakdown.isEmpty)

            SummaryRings(breakdown: breakdown, goalPeriod: .monthly)

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

    /// From a Month tile: show that week in the Week tab.
    private func open(week start: Date) {
        monthOffset = 0
        selectedWeekStart = start
        period = .week
        ensureCoverage(of: start)
    }

    // MARK: - Daily: day strip, swipe for weeks

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

            TabView(selection: Bindable(selection).weekOffset) {
                ForEach(-pastWeekLimit...0, id: \.self) { offset in
                    WeekDayStrip(
                        tint: focus.color,
                        dates: StatsPeriod.daysInWeek(containing: weekStart(for: offset)),
                        selectedDay: Bindable(selection).selectedDay
                    )
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 64)
            .onChange(of: weekOffset) { _, _ in
                alignSelectedDayToWeek()
                ensureCoverage(of: displayedWeekStart)
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

    // MARK: - Week: week chips for a month, swipe for months

    private func monthStart(for offset: Int) -> Date {
        let current = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
        return Calendar.current.date(byAdding: .month, value: offset, to: current) ?? current
    }

    private var monthCaption: String {
        monthOffset == 0
            ? "This month"
            : monthStart(for: monthOffset).formatted(.dateTime.month(.wide).year())
    }

    private var monthWeekPager: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthCaption)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TabView(selection: Bindable(selection).monthOffset) {
                ForEach(-pastMonthLimit...0, id: \.self) { offset in
                    MonthWeekStrip(
                        tint: focus.color,
                        weekStarts: StatsPeriod.weekStarts(inMonthOf: monthStart(for: offset)),
                        selectedWeekStart: Bindable(selection).selectedWeekStart
                    )
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 64)
            .onChange(of: monthOffset) { _, _ in
                alignSelectedWeekToMonth()
            }
            .onChange(of: selectedWeekStart) { _, start in
                ensureCoverage(of: start)
            }
        }
        .accessibilityHint("Swipe left or right to change month")
    }

    /// Keeps the same week number when swiping months, or the last week
    /// available (the current week for this month).
    private func alignSelectedWeekToMonth() {
        let weeks = StatsPeriod.weekStarts(inMonthOf: monthStart(for: monthOffset))
        guard !weeks.contains(selectedWeekStart), let last = weeks.last else { return }
        let previous = monthOffset < 0 ? StatsPeriod.weekStarts(inMonthOf: monthStart(for: monthOffset + 1)) : []
        if let index = previous.firstIndex(of: selectedWeekStart), index < weeks.count {
            selectedWeekStart = weeks[index]
        } else {
            selectedWeekStart = last
        }
    }

    private func ensureCoverage(of date: Date) {
        Task {
            await model.health.ensureCoverage(
                of: date,
                weightKilograms: model.settings.weightKilograms
            )
        }
    }
}

private struct MonthWeekStrip: View {
    let tint: Color
    let weekStarts: [Date]
    @Binding var selectedWeekStart: Date

    private var calendar: Calendar { StatsPeriod.sundayCalendar }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(weekStarts.enumerated()), id: \.element) { index, start in
                let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
                let isSelected = start == selectedWeekStart
                Button {
                    selectedWeekStart = start
                } label: {
                    VStack(spacing: 4) {
                        Text("Week \(index + 1)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(start.formatted(.dateTime.day()))–\(end.formatted(.dateTime.day()))")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .background(
                        isSelected ? tint : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    "Week of \(start.formatted(.dateTime.month(.wide).day()))"
                )
            }
        }
    }
}

private struct WeekDayStrip: View {
    let tint: Color
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
                            ? tint
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

/// Shown at the top of every stats tab when Health can't be read.
struct HealthAccessBanner: View {
    @Environment(AppModel.self) private var model
    let isEmpty: Bool

    var body: some View {
        if !model.health.isAvailable {
            PermissionBanner(
                title: "Apple Health unavailable",
                detail: "Walk, jog, and run stats are read from Health on this iPhone."
            )
        } else if model.health.accessLikelyMissing {
            PermissionBanner(
                title: "No Health data",
                detail: "RunCheck can't read any steps or workouts. In Health, tap your profile, then Apps → RunCheck, and turn on all categories.",
                actionTitle: "Open Health"
            ) {
                model.health.openHealthApp()
            }
        } else if isEmpty && model.health.todaySteps == 0 && !model.health.isAuthorized {
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
    }
}

private struct StatsBreakdownStack: View {
    @Environment(AppModel.self) private var model
    let breakdown: ActivityStatsBreakdown
    let caption: String
    let showHero: Bool
    let isMonth: Bool
    var goalPeriod: GoalPeriod = .daily
    var totalsTitle: String = "Activity"
    /// Days of the week so far, for the Week view's By each day list.
    var days: [Date] = []

    private var kindsWithData: [ActivityKind] {
        ActivityKind.allCases.filter { kind in
            // A card only shows with at least one real session; a few minutes
            // of movement during the day don't earn one.
            (breakdown.byKind[kind] ?? ActivityKindStats()).count > 0
        }
    }


    var body: some View {
        VStack(spacing: 20) {
            Text(caption)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HealthAccessBanner(isEmpty: breakdown.isEmpty)

            if showHero {
                dayHero
            } else {
                SummaryRings(breakdown: breakdown, goalPeriod: goalPeriod)
            }

            totalsCard

            ForEach(kindsWithData) { kind in
                let sessions = breakdown.sessions.filter { $0.kind == kind }.sorted { $0.start > $1.start }
                NavigationLink {
                    // One session opens straight to its details; more open the list.
                    if sessions.count == 1, let only = sessions.first {
                        SessionDetailView(session: only, metric: model.settings.usesMetric)
                    } else {
                        KindSessionsView(
                            kind: kind,
                            caption: caption,
                            sessions: sessions,
                            metric: model.settings.usesMetric
                        )
                    }
                } label: {
                    KindStatsCard(
                        kind: kind,
                        stats: breakdown.byKind[kind] ?? ActivityKindStats(),
                        metric: model.settings.usesMetric
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if goalPeriod == .weekly && days.count > 1 {
                DailyRingsList(days: days)
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
            SummaryRings(breakdown: breakdown, goalPeriod: .daily)

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
            Text(totalsTitle)
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
                    if stats.count > 1 {
                        Text("\(stats.count) sessions")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(Formatters.distance(stats.distanceMeters, metric: metric))
                    .font(.title3.weight(.bold).monospacedDigit())
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack {
                labeledValue("Time", Formatters.duration(stats.duration))
                Spacer()
                labeledValue("Speed", Formatters.speed(averageSpeedKmh, metric: metric))
                Spacer()
                labeledValue("Energy", "\(Formatters.calories(stats.calories)) kcal")
            }
            .font(.subheadline.monospacedDigit())
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var averageSpeedKmh: Double? {
        guard stats.duration > 0, stats.distanceMeters > 1 else { return nil }
        return stats.distanceMeters / stats.duration * 3.6
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

struct HealthSessionRow: View {
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
                // Lists show one kind at a time, so the date says more than
                // repeating "Running" on every row.
                Text(session.start.formatted(.dateTime.day().month(.abbreviated)))
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

/// Shown while a period's stats are worked out. It waits a moment before
/// appearing so quick loads don't flash a spinner.
private struct PeriodLoadingCard: View {
    let period: StatsPeriod
    @State private var visible = false

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
        .frame(minHeight: 120)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .opacity(visible ? 1 : 0)
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeIn(duration: 0.15)) { visible = true }
        }
    }

    private var message: String {
        switch period {
        case .daily: "Loading this day…"
        case .week: "Loading this week…"
        case .month: "Loading this month…"
        }
    }
}

/// Opened from a Summary card: that kind's sessions for the selected period.
private struct KindSessionsView: View {
    let kind: ActivityKind
    let caption: String
    let sessions: [HealthActivitySession]
    let metric: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(caption)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(sessions) { session in
                        NavigationLink {
                            SessionDetailView(session: session, metric: metric)
                        } label: {
                            HealthSessionRow(session: session, metric: metric)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .clearsTabBar()
        .background(Color(.systemGroupedBackground))
        .navigationTitle(sessions.count == 1 ? "1 \(kind.title.lowercased()) session" : "\(sessions.count) \(kind.title.lowercased()) sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

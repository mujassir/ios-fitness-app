import Foundation
import HealthKit

enum StatsPeriod: String, CaseIterable, Identifiable {
    case daily
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "Daily"
        case .week: "Week"
        case .month: "Month"
        }
    }

    static var sundayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        calendar.timeZone = .current
        calendar.locale = .current
        return calendar
    }

    static func queryOrigin(now: Date = .now, calendar: Calendar = sundayCalendar) -> Date {
        let today = calendar.startOfDay(for: now)
        let month = Calendar.current.dateInterval(of: .month, for: now)?.start ?? today
        let monthWeek = startOfWeek(containing: month, calendar: calendar)
        let twelveWeeks = calendar.date(
            byAdding: .weekOfYear,
            value: -12,
            to: startOfWeek(containing: today, calendar: calendar)
        ) ?? today
        return min(monthWeek, twelveWeeks)
    }

    static func startOfWeek(containing date: Date, calendar: Calendar = sundayCalendar) -> Date {
        let day = calendar.startOfDay(for: date)
        return calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
    }

    static func daysInWeek(containing date: Date, calendar: Calendar = sundayCalendar) -> [Date] {
        let start = startOfWeek(containing: date, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func isFutureDay(_ date: Date, now: Date = .now, calendar: Calendar = sundayCalendar) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: now)
    }

    static func weekStarts(inMonthOf date: Date, now: Date = .now, calendar: Calendar = sundayCalendar) -> [Date] {
        guard let month = Calendar.current.dateInterval(of: .month, for: date) else { return [] }
        let today = calendar.startOfDay(for: now)
        var start = startOfWeek(containing: month.start, calendar: calendar)
        var result: [Date] = []
        while start < month.end {
            if start <= today {
                result.append(start)
            }
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { break }
            start = next
        }
        return result
    }
}

struct WeekSummary: Identifiable, Hashable {
    let start: Date
    let steps: Int
    let distanceMeters: Double
    let calories: Double
    let duration: TimeInterval
    let sessionCount: Int
    let kindCounts: [ActivityKind: Int]

    var id: Date { start }

    var end: Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: start) ?? start
    }

    var isCurrent: Bool {
        StatsPeriod.startOfWeek(containing: .now) == StatsPeriod.startOfWeek(containing: start)
    }

    var hasActivity: Bool {
        steps > 0 || distanceMeters > 1 || duration > 1 || sessionCount > 0
    }
}

struct HealthDaySummary: Identifiable, Hashable {
    var date: Date
    var steps: Int
    var distanceMeters: Double
    var calories: Double
    var exerciseSeconds: TimeInterval

    var id: Date { date }

    static func empty(on date: Date) -> HealthDaySummary {
        HealthDaySummary(
            date: Calendar.current.startOfDay(for: date),
            steps: 0,
            distanceMeters: 0,
            calories: 0,
            exerciseSeconds: 0
        )
    }

    var hasActivity: Bool {
        steps > 0 || distanceMeters > 0 || calories > 0 || exerciseSeconds > 0
    }
}

struct ActivityBin: Hashable {
    var start: Date
    var steps: Double
    var distanceMeters: Double
    var calories: Double
    var speedMetersPerSecond: Double?

    static let length: TimeInterval = 60

    var end: Date { start.addingTimeInterval(Self.length) }

    var resolvedSpeed: Double {
        if let speed = speedMetersPerSecond, speed > 0.4 {
            return speed
        }
        if distanceMeters > 1 {
            return distanceMeters / Self.length
        }
        if steps > 0 {
            return (steps * 0.76) / Self.length
        }
        return 0
    }

    var speedKmh: Double { resolvedSpeed * 3.6 }

    var isActive: Bool {
        steps >= 8 || distanceMeters >= 5 || (speedMetersPerSecond ?? 0) >= 0.6
    }

    func kind(using detection: ActivityDetectionSettings) -> ActivityKind? {
        guard isActive else { return nil }
        return detection.kind(fromSpeedKmh: speedKmh)
    }
}

struct SessionSample: Identifiable, Hashable {
    var start: Date
    var speedKmh: Double
    var steps: Double
    var distanceMeters: Double

    var id: Date { start }

    var paceSecondsPerMeter: Double? {
        guard speedKmh > 0.4 else { return nil }
        return 3.6 / speedKmh
    }

    var tempo: Double {
        steps / (ActivityBin.length / 60)
    }

    init(bin: ActivityBin) {
        start = bin.start
        speedKmh = bin.speedKmh
        steps = bin.steps
        distanceMeters = bin.distanceMeters
    }
}

struct HealthActivitySession: Identifiable, Hashable {
    enum Source: String, Hashable {
        case workout
        case steps
    }

    let id: UUID
    let kind: ActivityKind
    let start: Date
    let duration: TimeInterval
    let distanceMeters: Double
    let calories: Double
    let steps: Int
    let source: Source
    let samples: [SessionSample]

    var end: Date { start.addingTimeInterval(duration) }

    var movingSamples: [SessionSample] {
        samples.filter { $0.speedKmh >= 0.5 }
    }

    var averagePaceSecondsPerMeter: Double? {
        if let fromSamples = average(movingSamples.compactMap(\.paceSecondsPerMeter)) {
            return fromSamples
        }
        guard distanceMeters > 1, duration > 0 else { return nil }
        return duration / distanceMeters
    }

    var minPaceSecondsPerMeter: Double? {
        movingSamples.compactMap(\.paceSecondsPerMeter).min()
    }

    var maxPaceSecondsPerMeter: Double? {
        movingSamples.compactMap(\.paceSecondsPerMeter).max()
    }

    var averageSpeedKmh: Double? {
        if let fromSamples = average(movingSamples.map(\.speedKmh)) {
            return fromSamples
        }
        guard duration > 0, distanceMeters > 1 else { return nil }
        return (distanceMeters / duration) * 3.6
    }

    var minSpeedKmh: Double? {
        movingSamples.map(\.speedKmh).min()
    }

    var maxSpeedKmh: Double? {
        movingSamples.map(\.speedKmh).max()
    }

    var averageTempo: Double? {
        average(movingSamples.map(\.tempo).filter { $0 > 5 })
    }

    var minTempo: Double? {
        movingSamples.map(\.tempo).filter { $0 > 5 }.min()
    }

    var maxTempo: Double? {
        movingSamples.map(\.tempo).filter { $0 > 5 }.max()
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Outdoor-style walking: steady cadence and distance, not indoor wandering.
    func looksLikeDisciplinedWalk(minSpeedKmh: Double) -> Bool {
        guard kind == .walk else { return true }
        if source == .workout {
            return distanceMeters >= 200
        }

        let cadence = averageTempo ?? 0
        let speed = averageSpeedKmh ?? 0
        let expectedDistance = (minSpeedKmh / 3.6) * duration * 0.6
        let minDistance = max(400, expectedDistance)
        let activeSeconds = Double(samples.count) * ActivityBin.length
        let movingRatio = duration > 0 ? activeSeconds / duration : 0
        let walkingMinutes = movingSamples.filter { sample in
            sample.speedKmh >= minSpeedKmh || sample.tempo >= 80
        }.count
        let walkingShare = movingSamples.isEmpty
            ? 0
            : Double(walkingMinutes) / Double(movingSamples.count)

        return speed >= minSpeedKmh
            && cadence >= 80
            && distanceMeters >= minDistance
            && movingRatio >= 0.65
            && walkingShare >= 0.7
            && longestConsecutiveMinutes >= 4
    }

    private var longestConsecutiveMinutes: Int {
        let sorted = samples.sorted { $0.start < $1.start }
        guard let first = sorted.first else { return 0 }
        var best = 1
        var current = 1
        var previous = first.start
        for sample in sorted.dropFirst() {
            if sample.start.timeIntervalSince(previous) <= ActivityBin.length + 5 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
            previous = sample.start
        }
        return best
    }
}

struct ActivityKindStats: Equatable {
    var count = 0
    var duration: TimeInterval = 0
    var distanceMeters = 0.0
    var calories = 0.0
    var steps = 0

    var averagePaceSecondsPerMeter: Double? {
        guard distanceMeters > 1, duration > 0 else { return nil }
        return duration / distanceMeters
    }

    var hasData: Bool {
        steps > 0 || distanceMeters > 1 || duration > 1 || calories > 1
    }

    mutating func add(_ session: HealthActivitySession) {
        count += 1
        duration += session.duration
        distanceMeters += session.distanceMeters
        calories += session.calories
        steps += session.steps
    }

    mutating func merge(_ other: ActivityKindStats) {
        count += other.count
        duration += other.duration
        distanceMeters += other.distanceMeters
        calories += other.calories
        steps += other.steps
    }
}

struct ActivityStatsBreakdown {
    let titleDate: Date
    let day: HealthDaySummary
    let sessions: [HealthActivitySession]
    let byKind: [ActivityKind: ActivityKindStats]
    let isMonth: Bool
    let monthDays: [HealthDaySummary]

    var totals: ActivityKindStats {
        if isMonth {
            var totals = monthDays.reduce(into: ActivityKindStats()) { totals, day in
                totals.steps += day.steps
                totals.distanceMeters += day.distanceMeters
                totals.calories += day.calories
                totals.duration += day.exerciseSeconds
            }
            totals.count = sessions.count
            if totals.duration < 1 {
                totals.duration = sessions.reduce(0) { $0 + $1.duration }
            }
            return totals
        }
        var totals = ActivityKindStats()
        totals.steps = day.steps
        totals.distanceMeters = day.distanceMeters
        totals.calories = day.calories
        totals.duration = day.exerciseSeconds > 0
            ? day.exerciseSeconds
            : sessions.reduce(0) { $0 + $1.duration }
        totals.count = sessions.count
        return totals
    }

    var isEmpty: Bool {
        if isMonth {
            return monthDays.allSatisfy { !$0.hasActivity } && sessions.isEmpty
        }
        return !day.hasActivity && sessions.isEmpty
    }

    static func day(
        date: Date,
        metrics: HealthDaySummary,
        sessions: [HealthActivitySession],
        byKind: [ActivityKind: ActivityKindStats]
    ) -> ActivityStatsBreakdown {
        ActivityStatsBreakdown(
            titleDate: date,
            day: metrics,
            sessions: sessions.sorted { $0.start < $1.start },
            byKind: byKind,
            isMonth: false,
            monthDays: []
        )
    }

    static func month(
        sessions: [HealthActivitySession],
        days: [HealthDaySummary],
        byKind: [ActivityKind: ActivityKindStats]
    ) -> ActivityStatsBreakdown {
        ActivityStatsBreakdown(
            titleDate: Date.now,
            day: HealthDaySummary.empty(on: Date.now),
            sessions: sessions.sorted { $0.start < $1.start },
            byKind: byKind,
            isMonth: true,
            monthDays: days
        )
    }
}

struct ActivityDetectionResult {
    var listedSessions: [HealthActivitySession]
    var byKind: [ActivityKind: ActivityKindStats]
}

enum ActivitySessionBuilder {
    static func detect(
        bins: [ActivityBin],
        workouts: [HKWorkout],
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> ActivityDetectionResult {
        let workoutSessions = workouts.compactMap {
            session(from: $0, bins: bins, detection: detection, weightKilograms: weightKilograms)
        }
        let stepSessions = sessions(
            bins: bins,
            detection: detection,
            weightKilograms: weightKilograms
        )
        let uniqueStepSessions = stepSessions.filter { step in
            !workoutSessions.contains { workout in
                overlaps(step, workout)
            }
        }
        let allSessions = (workoutSessions + uniqueStepSessions).sorted { $0.start < $1.start }
        let listed = allSessions.filter { detection.isListable($0) }

        var byKind: [ActivityKind: ActivityKindStats] = [:]
        for kind in ActivityKind.allCases {
            byKind[kind] = ActivityKindStats()
        }
        for session in allSessions {
            var current = byKind[session.kind] ?? ActivityKindStats()
            current.add(session)
            byKind[session.kind] = current
        }
        for kind in ActivityKind.allCases {
            var stats = byKind[kind] ?? ActivityKindStats()
            stats.count = listed.filter { $0.kind == kind }.count
            byKind[kind] = stats
        }

        return ActivityDetectionResult(listedSessions: listed, byKind: byKind)
    }

    private static func overlaps(_ lhs: HealthActivitySession, _ rhs: HealthActivitySession) -> Bool {
        let lhsEnd = lhs.start.addingTimeInterval(lhs.duration)
        let rhsEnd = rhs.start.addingTimeInterval(rhs.duration)
        let start = max(lhs.start, rhs.start)
        let end = min(lhsEnd, rhsEnd)
        let overlap = end.timeIntervalSince(start)
        guard overlap > 0 else { return false }
        return overlap >= min(lhs.duration, rhs.duration) * 0.4
    }

    private static func session(
        from workout: HKWorkout,
        bins: [ActivityBin],
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> HealthActivitySession? {
        let distance = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?
            .sumQuantity()?
            .doubleValue(for: .meter()) ?? 0
        let duration = max(workout.duration, 1)
        guard let kind = ActivityKind.fromHealthWorkout(
            activityType: workout.workoutActivityType,
            distanceMeters: distance,
            duration: duration,
            detection: detection
        ) else {
            return nil
        }
        let calories = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
            ?? CalorieEstimator.kilocalories(
                kind: kind,
                duration: duration,
                weightKilograms: weightKilograms
            )
        let samples = bins
            .filter { $0.start >= workout.startDate && $0.start < workout.startDate.addingTimeInterval(duration) }
            .map(SessionSample.init(bin:))
        return HealthActivitySession(
            id: workout.uuid,
            kind: kind,
            start: workout.startDate,
            duration: duration,
            distanceMeters: distance,
            calories: calories,
            steps: Int(samples.reduce(0) { $0 + $1.steps }),
            source: .workout,
            samples: samples
        )
    }

    /// Longest stretch of slower movement a session absorbs, such as a walk
    /// break or an easy minute in the middle of a run.
    static let maxSlowerBreak: TimeInterval = 3 * 60

    /// Builds sessions from one-minute bins. Runs are built first, then jogs,
    /// then walks, and each bin belongs to one session only, so slower
    /// minutes inside a run don't also show up as a separate jog or walk.
    private static func sessions(
        bins: [ActivityBin],
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> [HealthActivitySession] {
        let classified = bins
            .sorted { $0.start < $1.start }
            .compactMap { bin -> (bin: ActivityBin, kind: ActivityKind)? in
                guard let kind = bin.kind(using: detection) else { return nil }
                return (bin, kind)
            }

        var consumed = Set<Int>()
        var result: [HealthActivitySession] = []

        for kind in [ActivityKind.run, .jog, .walk] {
            // Health data comes in one-minute bins, so a pause is never
            // shorter than a minute. Join gaps below that would split a run
            // at every missing minute.
            let idleTolerance = max(detection.mergeGap(for: kind), ActivityBin.length)
            var groups: [[Int]] = []
            var current: [Int] = []
            var lastAnchor: Int?

            for index in classified.indices where classified[index].kind == kind && !consumed.contains(index) {
                if let last = lastAnchor,
                   canJoin(
                       from: last,
                       to: index,
                       kind: kind,
                       classified: classified,
                       consumed: consumed,
                       idleTolerance: idleTolerance,
                       detection: detection
                   ) {
                    current.append(contentsOf: (last + 1)...index)
                } else {
                    if !current.isEmpty { groups.append(current) }
                    current = [index]
                }
                lastAnchor = index
            }
            if !current.isEmpty { groups.append(current) }

            for group in groups {
                consumed.formUnion(group)
                if let session = session(
                    fromBins: group.map { classified[$0].bin },
                    kind: kind,
                    weightKilograms: weightKilograms
                ) {
                    result.append(session)
                }
            }
        }
        return result
    }

    /// Whether two bins of the same kind belong to one session: nothing in
    /// between was claimed by a faster session, the movement in between is an
    /// allowed interruption (slower for runs and jogs, none for walks), no
    /// pause is longer than the join gap, and the slower stretch is short.
    private static func canJoin(
        from last: Int,
        to next: Int,
        kind: ActivityKind,
        classified: [(bin: ActivityBin, kind: ActivityKind)],
        consumed: Set<Int>,
        idleTolerance: TimeInterval,
        detection: ActivityDetectionSettings
    ) -> Bool {
        let between = (last + 1)..<next
        guard between.allSatisfy({ !consumed.contains($0) }) else { return false }
        guard between.allSatisfy({ detection.allowsInterruption(classified[$0].kind, for: kind) }) else {
            return false
        }
        var previousEnd = classified[last].bin.end
        for index in (last + 1)...next {
            let idle = classified[index].bin.start.timeIntervalSince(previousEnd)
            if idle > idleTolerance { return false }
            previousEnd = classified[index].bin.end
        }
        let span = classified[next].bin.start.timeIntervalSince(classified[last].bin.end)
        return span <= max(idleTolerance, maxSlowerBreak)
    }

    private static func session(
        fromBins bins: [ActivityBin],
        kind: ActivityKind,
        weightKilograms: Double
    ) -> HealthActivitySession? {
        guard let first = bins.first, let last = bins.last else { return nil }
        let steps = bins.reduce(0.0) { $0 + $1.steps }
        let distance = bins.reduce(0.0) { $0 + $1.distanceMeters }
        let caloriesFromHealth = bins.reduce(0.0) { $0 + $1.calories }
        let duration = last.end.timeIntervalSince(first.start)
        let calories = caloriesFromHealth > 1
            ? caloriesFromHealth
            : CalorieEstimator.kilocalories(
                kind: kind,
                duration: duration,
                weightKilograms: weightKilograms
            )
        let resolvedDistance = distance > 20 ? distance : steps * kind.strideMeters
        return HealthActivitySession(
            id: UUID(),
            kind: kind,
            start: first.start,
            duration: duration,
            distanceMeters: resolvedDistance,
            calories: calories,
            steps: Int(steps),
            source: .steps,
            samples: bins.map(SessionSample.init(bin:))
        )
    }
}

/// One kilometre (or mile) of a session.
struct SessionSplit: Identifiable, Hashable {
    let index: Int
    /// Full split length, or the leftover distance for the last one.
    let distanceMeters: Double
    let duration: TimeInterval
    let isPartial: Bool

    var id: Int { index }

    var speedKmh: Double {
        duration > 0 ? distanceMeters / duration * 3.6 : 0
    }
}

extension HealthActivitySession {
    /// Time and speed for each `unitMeters` of the session, worked out from
    /// its one-minute samples. A boundary inside a minute splits that minute
    /// in proportion. Sample distances are scaled to the session's distance
    /// so the splits add up to the total shown.
    func splits(unitMeters: Double) -> [SessionSplit] {
        let samples = self.samples.sorted { $0.start < $1.start }
        guard unitMeters > 0, !samples.isEmpty else { return [] }
        let length = ActivityBin.length
        let raw = samples.map { sample in
            sample.distanceMeters > 1 ? sample.distanceMeters : sample.speedKmh / 3.6 * length
        }
        let rawTotal = raw.reduce(0, +)
        guard rawTotal > 0 else { return [] }
        let scale = distanceMeters > 1 ? distanceMeters / rawTotal : 1

        var splits: [SessionSplit] = []
        var covered = 0.0            // distance so far
        var splitStart = samples[0].start
        var lastTime = samples[0].start

        for (sample, rawDistance) in zip(samples, raw) {
            let distance = rawDistance * scale
            guard distance > 0 else {
                lastTime = sample.start.addingTimeInterval(length)
                continue
            }
            var used = 0.0
            // Every boundary this minute crosses closes a split.
            while covered + (distance - used) >= Double(splits.count + 1) * unitMeters {
                let needed = Double(splits.count + 1) * unitMeters - covered
                used += needed
                covered += needed
                let crossing = sample.start.addingTimeInterval(length * used / distance)
                splits.append(SessionSplit(
                    index: splits.count + 1,
                    distanceMeters: unitMeters,
                    duration: crossing.timeIntervalSince(splitStart),
                    isPartial: false
                ))
                splitStart = crossing
            }
            covered += distance - used
            lastTime = sample.start.addingTimeInterval(length)
        }

        let leftover = covered - Double(splits.count) * unitMeters
        // Skip a sliver at the end (under 5% of a split) that would show a
        // misleading speed.
        if leftover > unitMeters * 0.05 {
            splits.append(SessionSplit(
                index: splits.count + 1,
                distanceMeters: leftover,
                duration: lastTime.timeIntervalSince(splitStart),
                isPartial: true
            ))
        }
        return splits
    }
}

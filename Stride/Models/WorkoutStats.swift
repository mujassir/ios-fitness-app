import Foundation
import HealthKit

enum StatsPeriod: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
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
        let stepSessions = ActivityKind.allCases.flatMap { kind in
            sessions(
                of: kind,
                bins: bins,
                detection: detection,
                weightKilograms: weightKilograms
            )
        }
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

    private static func sessions(
        of kind: ActivityKind,
        bins: [ActivityBin],
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> [HealthActivitySession] {
        let classified = bins
            .sorted { $0.start < $1.start }
            .compactMap { bin -> (ActivityBin, ActivityKind)? in
                guard let binKind = bin.kind(using: detection) else { return nil }
                return (bin, binKind)
            }

        let maxGap = detection.mergeGap(for: kind)
        var groups: [[ActivityBin]] = []
        var current: [ActivityBin] = []

        for (bin, binKind) in classified {
            guard binKind == kind else { continue }
            if let last = current.last {
                let gap = bin.start.timeIntervalSince(last.end)
                let between = classified.compactMap { item -> ActivityKind? in
                    let other = item.0
                    guard other.start >= last.end, other.start < bin.start else { return nil }
                    return item.1
                }
                let interruptionsOK = between.allSatisfy { detection.allowsInterruption($0, for: kind) }
                if gap <= maxGap && interruptionsOK {
                    current.append(bin)
                } else {
                    groups.append(current)
                    current = [bin]
                }
            } else {
                current = [bin]
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }

        return groups.compactMap { group in
            session(fromBins: group, kind: kind, weightKilograms: weightKilograms)
        }
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

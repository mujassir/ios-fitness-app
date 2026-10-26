import CoreLocation
import Foundation
import HealthKit
import UIKit

@Observable
@MainActor
final class HealthKitService {
    private let store = HKHealthStore()

    var todaySteps = 0
    var todayDistanceMeters = 0.0
    var todayCalories = 0.0
    var weeklySteps: [DailyStepCount] = []
    var dailyMetrics: [HealthDaySummary] = []
    private var rawBins: [ActivityBin] = []
    private var rawWorkouts: [HKWorkout] = []
    var isAuthorized = false
    var isRequesting = false
    var isLoadingStats = false
    var lastError: String?
    private var loadedFrom: Date = .distantFuture

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.walkingSpeed),
            HKQuantityType(.runningSpeed),
            HKObjectType.workoutType()
        ]
        types.insert(HKQuantityType(.appleExerciseTime))
        return types
    }

    private var shareTypes: Set<HKSampleType> {
        Set([
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned),
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ])
    }

    private var writeTypesToCheck: [HKObjectType] {
        [
            HKObjectType.workoutType(),
            HKQuantityType(.stepCount),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.activeEnergyBurned)
        ]
    }

    init() {
        refreshAuthorizationStatus()
    }

    func requestAuthorization() async {
        guard isAvailable else {
            lastError = "Apple Health is not available on this device."
            isAuthorized = false
            return
        }

        isRequesting = true
        defer { isRequesting = false }

        do {
            try await requestHealthAccess()
            refreshAuthorizationStatus()
            if isAuthorized {
                lastError = nil
            } else {
                lastError = "Turn on Steps, Distance, Walking Speed, Running Speed, Energy, and Workouts in Health, then tap Allow."
                openHealthApp()
            }
        } catch {
            isAuthorized = false
            lastError = readableHealthError(error)
        }
    }

    func refreshAuthorizationStatus() {
        isAuthorized = writeTypesToCheck.contains {
            store.authorizationStatus(for: $0) == .sharingAuthorized
        }
    }

    private func requestHealthAccess() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: shareTypes, read: readTypes) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func refreshToday() async {
        guard isAvailable else { return }
        let start = Calendar.current.startOfDay(for: .now)
        async let steps = sum(.stepCount, unit: .count(), from: start)
        async let distance = sum(.distanceWalkingRunning, unit: .meter(), from: start)
        async let energy = sum(.activeEnergyBurned, unit: .kilocalorie(), from: start)
        todaySteps = Int(await steps)
        todayDistanceMeters = await distance
        todayCalories = await energy
    }

    func refreshWeek() async {
        guard isAvailable else { return }
        weeklySteps = await dailySteps(days: 7)
    }

    func refreshWorkouts(weightKilograms _: Double = 70, covering: Date? = nil) async {
        guard isAvailable else { return }
        isLoadingStats = true
        defer { isLoadingStats = false }
        let origin = min(
            StatsPeriod.queryOrigin(),
            covering.map { StatsPeriod.startOfWeek(containing: $0) } ?? .distantFuture
        )
        async let samples = fetchWorkouts(from: origin)
        async let days = fetchDailyMetrics(from: origin)
        async let bins = fetchActivityBins(from: origin)
        rawWorkouts = await samples
        dailyMetrics = await days
        rawBins = await bins
        loadedFrom = origin
        if dailyMetrics.contains(where: { $0.hasActivity }) || !rawBins.isEmpty || !rawWorkouts.isEmpty {
            lastError = nil
        }
    }

    func ensureCoverage(of date: Date, weightKilograms: Double) async {
        let needed = StatsPeriod.startOfWeek(containing: date)
        guard needed < loadedFrom else { return }
        await refreshWorkouts(weightKilograms: weightKilograms, covering: needed)
    }

    func metrics(on date: Date) -> HealthDaySummary {
        let calendar = Calendar.current
        return dailyMetrics.first { calendar.isDate($0.date, inSameDayAs: date) }
            ?? HealthDaySummary.empty(on: date)
    }

    func stats(
        on date: Date,
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> ActivityStatsBreakdown {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let result = detect(
            bins: rawBins.filter { calendar.isDate($0.start, inSameDayAs: dayStart) },
            workouts: rawWorkouts.filter { calendar.isDate($0.startDate, inSameDayAs: dayStart) },
            detection: detection,
            weightKilograms: weightKilograms
        )
        return .day(
            date: dayStart,
            metrics: metrics(on: dayStart),
            sessions: result.listedSessions,
            byKind: result.byKind
        )
    }

    func monthStats(
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> ActivityStatsBreakdown {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: .now)?.start ?? calendar.startOfDay(for: .now)
        let result = detect(
            bins: rawBins.filter { $0.start >= monthStart },
            workouts: rawWorkouts.filter { $0.startDate >= monthStart },
            detection: detection,
            weightKilograms: weightKilograms
        )
        return .month(
            sessions: result.listedSessions,
            days: dailyMetrics.filter { $0.date >= monthStart },
            byKind: result.byKind
        )
    }

    func weekSummaries(
        inMonthOf date: Date = .now,
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> [WeekSummary] {
        let calendar = StatsPeriod.sundayCalendar
        return StatsPeriod.weekStarts(inMonthOf: date).map { start in
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start.addingTimeInterval(7 * 24 * 3600)
            let days = dailyMetrics.filter { $0.date >= start && $0.date < end }
            let result = detect(
                bins: rawBins.filter { $0.start >= start && $0.start < end },
                workouts: rawWorkouts.filter { $0.startDate >= start && $0.startDate < end },
                detection: detection,
                weightKilograms: weightKilograms
            )
            var duration = days.reduce(0.0) { $0 + $1.exerciseSeconds }
            if duration < 1 {
                duration = result.listedSessions.reduce(0) { $0 + $1.duration }
            }
            var kindCounts: [ActivityKind: Int] = [:]
            for session in result.listedSessions {
                kindCounts[session.kind, default: 0] += 1
            }
            return WeekSummary(
                start: start,
                steps: days.reduce(0) { $0 + $1.steps },
                distanceMeters: days.reduce(0) { $0 + $1.distanceMeters },
                calories: days.reduce(0) { $0 + $1.calories },
                duration: duration,
                sessionCount: result.listedSessions.count,
                kindCounts: kindCounts
            )
        }
    }

    private func detect(
        bins: [ActivityBin],
        workouts: [HKWorkout],
        detection: ActivityDetectionSettings,
        weightKilograms: Double
    ) -> ActivityDetectionResult {
        ActivitySessionBuilder.detect(
            bins: bins,
            workouts: workouts,
            detection: detection,
            weightKilograms: weightKilograms
        )
    }

    func startObserving() async {
        guard isAvailable else { return }
        let stepType = HKQuantityType(.stepCount)
        try? await store.enableBackgroundDelivery(for: stepType, frequency: .hourly)

        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                await self?.refreshToday()
                await self?.refreshWeek()
                await self?.refreshWorkouts()
            }
            completion()
        }
        store.execute(query)

        let workoutQuery = HKObserverQuery(sampleType: HKObjectType.workoutType(), predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                await self?.refreshWorkouts()
            }
            completion()
        }
        store.execute(workoutQuery)
    }

    func saveWorkout(
        kind: ActivityKind,
        start: Date,
        end: Date,
        duration: TimeInterval,
        distanceMeters: Double,
        calories: Double,
        locations: [CLLocation]
    ) async {
        guard isAvailable, isAuthorized else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = kind.healthKitActivityType
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: start)

            var samples: [HKSample] = []
            if distanceMeters > 0 {
                let quantity = HKQuantity(unit: .meter(), doubleValue: distanceMeters)
                samples.append(
                    HKQuantitySample(
                        type: HKQuantityType(.distanceWalkingRunning),
                        quantity: quantity,
                        start: start,
                        end: end
                    )
                )
            }
            if calories > 0 {
                let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
                samples.append(
                    HKQuantitySample(
                        type: HKQuantityType(.activeEnergyBurned),
                        quantity: quantity,
                        start: start,
                        end: end
                    )
                )
            }

            if !samples.isEmpty {
                try await builder.addSamples(samples)
            }

            try await builder.endCollection(at: end)
            guard let workout = try await builder.finishWorkout() else {
                throw HealthKitServiceError.saveFailed
            }

            if locations.count >= 2 {
                let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
                try await routeBuilder.insertRouteData(locations)
                _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func openHealthApp() {
        guard let url = URL(string: "x-apple-health://") else { return }
        UIApplication.shared.open(url)
    }

    private func readableHealthError(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("entitlement") {
            return "This install is missing the HealthKit capability. In Xcode choose Signing & Capabilities → + Capability → HealthKit, then run again."
        }
        return text
    }

    private func fetchWorkouts(from start: Date) async -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: .now,
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                continuation.resume(returning: samples as? [HKWorkout] ?? [])
            }
            store.execute(query)
        }
    }

    private func fetchDailyMetrics(from start: Date) async -> [HealthDaySummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        async let steps = dailySums(.stepCount, unit: .count(), from: start, to: end)
        async let distance = dailySums(.distanceWalkingRunning, unit: .meter(), from: start, to: end)
        async let energy = dailySums(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: end)
        async let exercise = dailySums(.appleExerciseTime, unit: .minute(), from: start, to: end)

        let stepMap = await steps
        let distanceMap = await distance
        let energyMap = await energy
        let exerciseMap = await exercise

        var days: [HealthDaySummary] = []
        var cursor = calendar.startOfDay(for: start)
        while cursor < end {
            days.append(
                HealthDaySummary(
                    date: cursor,
                    steps: Int(stepMap[cursor] ?? 0),
                    distanceMeters: distanceMap[cursor] ?? 0,
                    calories: energyMap[cursor] ?? 0,
                    exerciseSeconds: (exerciseMap[cursor] ?? 0) * 60
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    private func fetchActivityBins(from start: Date) async -> [ActivityBin] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? Date.now
        let speedUnit = HKUnit.meter().unitDivided(by: .second())

        async let steps = intervalValues(.stepCount, unit: .count(), options: .cumulativeSum, from: start, to: end)
        async let distance = intervalValues(.distanceWalkingRunning, unit: .meter(), options: .cumulativeSum, from: start, to: end)
        async let energy = intervalValues(.activeEnergyBurned, unit: .kilocalorie(), options: .cumulativeSum, from: start, to: end)
        async let walkSpeed = intervalValues(.walkingSpeed, unit: speedUnit, options: .discreteAverage, from: start, to: end)
        async let runSpeed = intervalValues(.runningSpeed, unit: speedUnit, options: .discreteAverage, from: start, to: end)

        let stepMap = await steps
        let distanceMap = await distance
        let energyMap = await energy
        let walkMap = await walkSpeed
        let runMap = await runSpeed

        let starts = Set(stepMap.keys)
            .union(distanceMap.keys)
            .union(energyMap.keys)
            .union(walkMap.keys)
            .union(runMap.keys)

        return starts.sorted().compactMap { startDate in
            let bin = ActivityBin(
                start: startDate,
                steps: stepMap[startDate] ?? 0,
                distanceMeters: distanceMap[startDate] ?? 0,
                calories: energyMap[startDate] ?? 0,
                speedMetersPerSecond: runMap[startDate] ?? walkMap[startDate]
            )
            return bin.isActive ? bin : nil
        }
    }

    private func intervalValues(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        options: HKStatisticsOptions,
        from start: Date,
        to end: Date
    ) async -> [Date: Double] {
        let type = HKQuantityType(identifier)
        var interval = DateComponents()
        interval.minute = 1
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let calendar = Calendar.current

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: options,
                anchorDate: calendar.startOfDay(for: start),
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                var result: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let value: Double
                    if options.contains(.cumulativeSum) {
                        value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    } else {
                        value = statistics.averageQuantity()?.doubleValue(for: unit) ?? 0
                    }
                    if value > 0 {
                        result[statistics.startDate] = value
                    }
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    private func dailySums(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date
    ) async -> [Date: Double] {
        let type = HKQuantityType(identifier)
        var interval = DateComponents()
        interval.day = 1
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let calendar = Calendar.current

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: start),
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                var result: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let day = calendar.startOfDay(for: statistics.startDate)
                    result[day] = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                }
                continuation.resume(returning: result)
            }
            store.execute(query)
        }
    }

    private func sum(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        from start: Date,
        to end: Date = .now
    ) async -> Double {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func dailySteps(days: Int) async -> [DailyStepCount] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: .now).addingTimeInterval(24 * 60 * 60)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: .now)) else {
            return []
        }

        let type = HKQuantityType(.stepCount)
        var interval = DateComponents()
        interval.day = 1
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: start,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                var result: [DailyStepCount] = []
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    let steps = Int(statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                    result.append(DailyStepCount(date: statistics.startDate, steps: steps))
                }
                continuation.resume(returning: result.sorted { $0.date < $1.date })
            }
            store.execute(query)
        }
    }
}

enum HealthKitServiceError: LocalizedError {
    case saveFailed

    var errorDescription: String? {
        "Could not save this workout to Apple Health."
    }
}

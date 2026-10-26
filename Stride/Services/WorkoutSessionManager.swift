import CoreLocation
import Foundation
import SwiftData
import UIKit

@Observable
@MainActor
final class WorkoutSessionManager {
    enum Phase: Equatable {
        case idle
        case running
        case paused
    }

    private(set) var phase: Phase = .idle
    private(set) var kind: ActivityKind = .run
    private(set) var startDate: Date?
    private(set) var elapsed: TimeInterval = 0
    private(set) var distanceMeters: Double = 0
    private(set) var steps = 0
    private(set) var calories: Double = 0
    private(set) var currentPaceSecondsPerMeter: Double?
    private(set) var locations: [CLLocation] = []
    private(set) var routePoints: [RoutePoint] = []
    private(set) var splits: [WorkoutSplit] = []
    private(set) var isAutoPaused = false
    var isLivePresented = false
    var errorMessage: String?

    var isActive: Bool { phase != .idle }

    var averagePaceSecondsPerMeter: Double? {
        guard distanceMeters > 1 else { return nil }
        return elapsed / distanceMeters
    }

    private let health: HealthKitService
    private let settings: AppSettings
    private let locationService = LocationService()
    private let pedometer = PedometerService()
    private var timer: Timer?
    private var pauseBegan: Date?
    private var pausedDuration: TimeInterval = 0
    private var lastAcceptedLocation: CLLocation?
    private var gpsDistance: Double = 0
    private var pedometerDistance: Double?
    private var stillSince: Date?
    private var nextSplitMeters: Double = 1_000
    private var lastSplitElapsed: TimeInterval = 0

    init(health: HealthKitService, settings: AppSettings) {
        self.health = health
        self.settings = settings
        locationService.onLocations = { [weak self] locations in
            Task { @MainActor in
                self?.ingest(locations)
            }
        }
    }

    func start(_ kind: ActivityKind) async {
        guard phase == .idle else {
            isLivePresented = true
            return
        }

        let status = await locationService.requestAuthorization()
        guard status == .authorizedAlways || status == .authorizedWhenInUse else {
            errorMessage = "Location access is needed to map your route and measure distance."
            return
        }

        resetMetrics()
        self.kind = kind
        startDate = .now
        phase = .running
        isLivePresented = true
        UIApplication.shared.isIdleTimerDisabled = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        locationService.start()
        let sessionStart = startDate ?? .now
        pedometer.start(from: sessionStart) { [weak self] steps, distance, pace in
            Task { @MainActor in
                self?.applyPedometer(steps: steps, distance: distance, pace: pace)
            }
        }
        startTimer()
    }

    func pause() {
        guard phase == .running else { return }
        phase = .paused
        isAutoPaused = false
        pauseBegan = .now
        locationService.stop()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func resume() {
        guard phase == .paused else { return }
        if let pauseBegan {
            pausedDuration += Date.now.timeIntervalSince(pauseBegan)
        }
        pauseBegan = nil
        isAutoPaused = false
        stillSince = nil
        phase = .running
        locationService.start()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    func discard() {
        stopHardware()
        resetMetrics()
        isLivePresented = false
    }

    @discardableResult
    func finish(modelContext: ModelContext) async -> Workout? {
        guard let startDate, phase != .idle else { return nil }
        if phase == .paused, let pauseBegan {
            pausedDuration += Date.now.timeIntervalSince(pauseBegan)
        }

        stopHardware()
        let end = Date.now
        let duration = max(end.timeIntervalSince(startDate) - pausedDuration, 1)
        let distance = resolvedDistance
        let calories = CalorieEstimator.kilocalories(
            kind: kind,
            duration: duration,
            weightKilograms: settings.weightKilograms
        )
        let steps = resolvedSteps(distance: distance)

        let workout = Workout(
            kind: kind,
            startDate: startDate,
            endDate: end,
            duration: duration,
            distanceMeters: distance,
            steps: steps,
            calories: calories,
            route: routePoints,
            splits: splits
        )
        modelContext.insert(workout)
        try? modelContext.save()

        await health.saveWorkout(
            kind: kind,
            start: startDate,
            end: end,
            duration: duration,
            distanceMeters: distance,
            calories: calories,
            locations: locations
        )
        await health.refreshToday()
        await health.refreshWeek()

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        resetMetrics()
        isLivePresented = false
        return workout
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tick() {
        guard let startDate, phase != .idle else { return }
        let pauseOffset = pausedDuration + (phase == .paused ? Date.now.timeIntervalSince(pauseBegan ?? .now) : 0)
        elapsed = max(Date.now.timeIntervalSince(startDate) - pauseOffset, 0)
        distanceMeters = resolvedDistance
        calories = CalorieEstimator.kilocalories(
            kind: kind,
            duration: elapsed,
            weightKilograms: settings.weightKilograms
        )
        if currentPaceSecondsPerMeter == nil {
            currentPaceSecondsPerMeter = averagePaceSecondsPerMeter
        }
        updateSplitsIfNeeded()
    }

    private func ingest(_ newLocations: [CLLocation]) {
        guard phase == .running else { return }
        for location in newLocations {
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 30 else { continue }

            if let lastAcceptedLocation {
                let delta = location.distance(from: lastAcceptedLocation)
                guard delta >= 1.5 else { continue }
                let interval = location.timestamp.timeIntervalSince(lastAcceptedLocation.timestamp)
                if interval > 0 {
                    let speed = delta / interval
                    guard speed <= 12 else { continue }
                    considerAutoPause(speed: speed)
                }
                if phase == .running {
                    gpsDistance += delta
                }
            }

            if phase == .running {
                lastAcceptedLocation = location
                locations.append(location)
                routePoints.append(RoutePoint(location: location))
            }
        }
        tick()
    }

    private func applyPedometer(steps: Int, distance: Double?, pace: Double?) {
        guard phase != .idle else { return }
        self.steps = steps
        pedometerDistance = distance
        if let pace, pace > 0 {
            currentPaceSecondsPerMeter = pace
        }
        if phase == .running {
            tick()
        }
    }

    private func considerAutoPause(speed: Double) {
        guard settings.autoPause else { return }
        if speed < 0.4 {
            if stillSince == nil { stillSince = .now }
            if let stillSince, Date.now.timeIntervalSince(stillSince) > 8, phase == .running {
                pause()
                isAutoPaused = true
            }
        } else if speed > 0.85, isAutoPaused, phase == .paused {
            resume()
        } else {
            stillSince = nil
        }
    }

    private func updateSplitsIfNeeded() {
        let splitLength = settings.usesMetric ? 1_000.0 : 1_609.344
        while distanceMeters >= nextSplitMeters {
            let splitDuration = elapsed - lastSplitElapsed
            splits.append(
                WorkoutSplit(
                    number: splits.count + 1,
                    distanceMeters: splitLength,
                    duration: max(splitDuration, 1)
                )
            )
            lastSplitElapsed = elapsed
            nextSplitMeters += splitLength
        }
    }

    private var resolvedDistance: Double {
        if gpsDistance > 5 { return gpsDistance }
        if let pedometerDistance, pedometerDistance > 0 { return pedometerDistance }
        return gpsDistance
    }

    private func resolvedSteps(distance: Double) -> Int {
        if steps > 0 { return steps }
        return Int((distance / kind.strideMeters).rounded())
    }

    private func stopHardware() {
        timer?.invalidate()
        timer = nil
        locationService.stop()
        pedometer.stop()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func resetMetrics() {
        phase = .idle
        startDate = nil
        elapsed = 0
        distanceMeters = 0
        steps = 0
        calories = 0
        currentPaceSecondsPerMeter = nil
        locations = []
        routePoints = []
        splits = []
        isAutoPaused = false
        pauseBegan = nil
        pausedDuration = 0
        lastAcceptedLocation = nil
        gpsDistance = 0
        pedometerDistance = nil
        stillSince = nil
        nextSplitMeters = settings.usesMetric ? 1_000 : 1_609.344
        lastSplitElapsed = 0
        errorMessage = nil
    }
}

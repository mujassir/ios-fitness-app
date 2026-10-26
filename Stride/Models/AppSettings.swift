import Foundation

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .metric: "Kilometers"
        case .imperial: "Miles"
        }
    }
}

@Observable
final class AppSettings {
    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let stepGoal = "dailyStepGoal"
        static let units = "unitSystem"
        static let weight = "weightKilograms"
        static let autoPause = "autoPause"
        static let jogMinSpeedKmh = "jogMinSpeedKmh"
        static let runMinSpeedKmh = "runMinSpeedKmh"
        static let walkMinSessionMinutes = "walkMinSessionMinutes"
        static let jogMinSessionMinutes = "jogMinSessionMinutes"
        static let runMinSessionMinutes = "runMinSessionMinutes"
        static let walkMergeGapSeconds = "walkMergeGapSeconds"
        static let jogMergeGapSeconds = "jogMergeGapSeconds"
        static let runMergeGapSeconds = "runMergeGapSeconds"
    }

    var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    var dailyStepGoal: Int {
        didSet { UserDefaults.standard.set(dailyStepGoal, forKey: Keys.stepGoal) }
    }

    var unitSystem: UnitSystem {
        didSet { UserDefaults.standard.set(unitSystem.rawValue, forKey: Keys.units) }
    }

    var usesMetric: Bool { unitSystem == .metric }

    var weightKilograms: Double {
        didSet { UserDefaults.standard.set(weightKilograms, forKey: Keys.weight) }
    }

    var autoPause: Bool {
        didSet { UserDefaults.standard.set(autoPause, forKey: Keys.autoPause) }
    }

    var jogMinSpeedKmh: Double {
        didSet {
            UserDefaults.standard.set(jogMinSpeedKmh, forKey: Keys.jogMinSpeedKmh)
            if jogMinSpeedKmh > runMinSpeedKmh {
                runMinSpeedKmh = jogMinSpeedKmh
            }
        }
    }

    var runMinSpeedKmh: Double {
        didSet {
            UserDefaults.standard.set(runMinSpeedKmh, forKey: Keys.runMinSpeedKmh)
            if runMinSpeedKmh < jogMinSpeedKmh {
                jogMinSpeedKmh = runMinSpeedKmh
            }
        }
    }

    var walkMinSessionMinutes: Double {
        didSet { UserDefaults.standard.set(walkMinSessionMinutes, forKey: Keys.walkMinSessionMinutes) }
    }

    var jogMinSessionMinutes: Double {
        didSet { UserDefaults.standard.set(jogMinSessionMinutes, forKey: Keys.jogMinSessionMinutes) }
    }

    var runMinSessionMinutes: Double {
        didSet { UserDefaults.standard.set(runMinSessionMinutes, forKey: Keys.runMinSessionMinutes) }
    }

    var walkMergeGapSeconds: Double {
        didSet { UserDefaults.standard.set(walkMergeGapSeconds, forKey: Keys.walkMergeGapSeconds) }
    }

    var jogMergeGapSeconds: Double {
        didSet { UserDefaults.standard.set(jogMergeGapSeconds, forKey: Keys.jogMergeGapSeconds) }
    }

    var runMergeGapSeconds: Double {
        didSet { UserDefaults.standard.set(runMergeGapSeconds, forKey: Keys.runMergeGapSeconds) }
    }

    var detection: ActivityDetectionSettings {
        ActivityDetectionSettings(
            jogMinSpeedKmh: jogMinSpeedKmh,
            runMinSpeedKmh: runMinSpeedKmh,
            walkMinSessionMinutes: walkMinSessionMinutes,
            jogMinSessionMinutes: jogMinSessionMinutes,
            runMinSessionMinutes: runMinSessionMinutes,
            walkMergeGapSeconds: walkMergeGapSeconds,
            jogMergeGapSeconds: jogMergeGapSeconds,
            runMergeGapSeconds: runMergeGapSeconds
        )
    }

    init() {
        let defaults = UserDefaults.standard
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        dailyStepGoal = (defaults.object(forKey: Keys.stepGoal) as? Int) ?? 10_000
        unitSystem = UnitSystem(rawValue: defaults.string(forKey: Keys.units) ?? "") ?? .metric
        weightKilograms = (defaults.object(forKey: Keys.weight) as? Double) ?? 70
        if defaults.object(forKey: Keys.autoPause) == nil {
            autoPause = true
        } else {
            autoPause = defaults.bool(forKey: Keys.autoPause)
        }
        jogMinSpeedKmh = (defaults.object(forKey: Keys.jogMinSpeedKmh) as? Double) ?? 5
        runMinSpeedKmh = (defaults.object(forKey: Keys.runMinSpeedKmh) as? Double) ?? 8
        walkMinSessionMinutes = (defaults.object(forKey: Keys.walkMinSessionMinutes) as? Double) ?? 10
        jogMinSessionMinutes = (defaults.object(forKey: Keys.jogMinSessionMinutes) as? Double) ?? 5
        runMinSessionMinutes = (defaults.object(forKey: Keys.runMinSessionMinutes) as? Double) ?? 5
        walkMergeGapSeconds = (defaults.object(forKey: Keys.walkMergeGapSeconds) as? Double) ?? 120
        jogMergeGapSeconds = (defaults.object(forKey: Keys.jogMergeGapSeconds) as? Double) ?? 30
        runMergeGapSeconds = (defaults.object(forKey: Keys.runMergeGapSeconds) as? Double) ?? 10
    }
}

struct ActivityDetectionSettings: Equatable {
    var jogMinSpeedKmh: Double
    var runMinSpeedKmh: Double
    var walkMinSessionMinutes: Double
    var jogMinSessionMinutes: Double
    var runMinSessionMinutes: Double
    var walkMergeGapSeconds: Double
    var jogMergeGapSeconds: Double
    var runMergeGapSeconds: Double

    func kind(fromSpeedKmh kmh: Double) -> ActivityKind {
        if kmh >= runMinSpeedKmh { return .run }
        if kmh >= jogMinSpeedKmh { return .jog }
        return .walk
    }

    func minSessionDuration(for kind: ActivityKind) -> TimeInterval {
        switch kind {
        case .walk: walkMinSessionMinutes * 60
        case .jog: jogMinSessionMinutes * 60
        case .run: runMinSessionMinutes * 60
        }
    }

    func mergeGap(for kind: ActivityKind) -> TimeInterval {
        switch kind {
        case .walk: walkMergeGapSeconds
        case .jog: jogMergeGapSeconds
        case .run: runMergeGapSeconds
        }
    }

    func allowsInterruption(_ interruption: ActivityKind?, for kind: ActivityKind) -> Bool {
        switch kind {
        case .walk:
            return interruption == nil
        case .jog:
            return interruption == nil || interruption == .walk
        case .run:
            return interruption == nil || interruption == .walk || interruption == .jog
        }
    }

    /// Slow indoor shuffling stays a walk for tiles, but sessions need a real walking pace.
    var walkSessionMinSpeedKmh: Double {
        min(3.2, max(2.8, jogMinSpeedKmh * 0.64))
    }

    func isListable(_ session: HealthActivitySession) -> Bool {
        guard session.duration >= minSessionDuration(for: session.kind) else { return false }
        if session.kind == .walk {
            return session.looksLikeDisciplinedWalk(minSpeedKmh: walkSessionMinSpeedKmh)
        }
        return true
    }
}

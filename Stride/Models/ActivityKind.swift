import HealthKit
import SwiftUI

enum ActivityKind: String, Codable, CaseIterable, Identifiable {
    case walk
    case jog
    case run

    var id: String { rawValue }

    var title: String {
        switch self {
        case .walk: "Walk"
        case .jog: "Jog"
        case .run: "Run"
        }
    }

    var subtitle: String {
        switch self {
        case .walk: "Easy outdoor pace"
        case .jog: "Steady light run"
        case .run: "Push for speed"
        }
    }

    var symbol: String {
        switch self {
        case .walk: "figure.walk"
        case .jog: "figure.walk.motion"
        case .run: "figure.run"
        }
    }

    var color: Color {
        switch self {
        case .walk: Palette.walk
        case .jog: Palette.jog
        case .run: Palette.run
        }
    }

    var healthKitActivityType: HKWorkoutActivityType {
        switch self {
        case .walk: .walking
        case .jog, .run: .running
        }
    }

    /// Apple Health has Walk and Run, not Jog. Easier-paced running is treated as Jog.
    static func fromHealthWorkout(
        activityType: HKWorkoutActivityType,
        distanceMeters: Double,
        duration: TimeInterval,
        detection: ActivityDetectionSettings
    ) -> ActivityKind? {
        if distanceMeters > 50, duration > 30 {
            return detection.kind(fromSpeedKmh: (distanceMeters / duration) * 3.6)
        }
        switch activityType {
        case .walking, .hiking, .wheelchairWalkPace:
            return .walk
        case .running, .trackAndField:
            return .run
        default:
            return nil
        }
    }

    var strideMeters: Double {
        switch self {
        case .walk: 0.76
        case .jog: 0.90
        case .run: 1.05
        }
    }

    var met: Double {
        switch self {
        case .walk: 3.8
        case .jog: 7.0
        case .run: 9.8
        }
    }
}

enum CalorieEstimator {
    static func kilocalories(
        kind: ActivityKind,
        duration: TimeInterval,
        weightKilograms: Double
    ) -> Double {
        let hours = max(duration / 3600, 1 / 3600)
        return kind.met * max(weightKilograms, 30) * hours
    }
}

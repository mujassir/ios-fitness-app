import Foundation
import SwiftData

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var distanceMeters: Double
    var steps: Int
    var calories: Double
    var routeData: Data?
    var splitsData: Data?

    init(
        id: UUID = UUID(),
        kind: ActivityKind,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        distanceMeters: Double,
        steps: Int,
        calories: Double,
        route: [RoutePoint] = [],
        splits: [WorkoutSplit] = []
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.steps = steps
        self.calories = calories
        self.routeData = try? JSONEncoder().encode(route)
        self.splitsData = try? JSONEncoder().encode(splits)
    }

    var kind: ActivityKind {
        get { ActivityKind(rawValue: kindRaw) ?? .walk }
        set { kindRaw = newValue.rawValue }
    }

    var route: [RoutePoint] {
        guard let routeData else { return [] }
        return (try? JSONDecoder().decode([RoutePoint].self, from: routeData)) ?? []
    }

    var splits: [WorkoutSplit] {
        guard let splitsData else { return [] }
        return (try? JSONDecoder().decode([WorkoutSplit].self, from: splitsData)) ?? []
    }

    var averagePaceSecondsPerMeter: Double? {
        guard distanceMeters > 1 else { return nil }
        return duration / distanceMeters
    }
}

extension Workout {
    static func previewSamples() -> [Workout] {
        let now = Date()
        return [
            Workout(
                kind: .run,
                startDate: now.addingTimeInterval(-86_400),
                endDate: now.addingTimeInterval(-86_400 + 2_145),
                duration: 2_145,
                distanceMeters: 5_240,
                steps: 6_410,
                calories: 412,
                splits: [
                    WorkoutSplit(number: 1, distanceMeters: 1_000, duration: 312),
                    WorkoutSplit(number: 2, distanceMeters: 1_000, duration: 328),
                    WorkoutSplit(number: 3, distanceMeters: 1_000, duration: 341),
                    WorkoutSplit(number: 4, distanceMeters: 1_000, duration: 355),
                    WorkoutSplit(number: 5, distanceMeters: 1_000, duration: 360)
                ]
            ),
            Workout(
                kind: .walk,
                startDate: now.addingTimeInterval(-172_800),
                endDate: now.addingTimeInterval(-172_800 + 3_420),
                duration: 3_420,
                distanceMeters: 4_180,
                steps: 5_520,
                calories: 186
            ),
            Workout(
                kind: .jog,
                startDate: now.addingTimeInterval(-345_600),
                endDate: now.addingTimeInterval(-345_600 + 1_740),
                duration: 1_740,
                distanceMeters: 3_210,
                steps: 3_880,
                calories: 268
            )
        ]
    }
}

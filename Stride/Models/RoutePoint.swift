import CoreLocation
import Foundation

struct RoutePoint: Codable, Hashable, Identifiable {
    var id: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var timestamp: Date
    var speed: Double

    init(id: UUID = UUID(), location: CLLocation) {
        self.id = id
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.altitude = location.altitude
        self.timestamp = location.timestamp
        self.speed = max(location.speed, 0)
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct WorkoutSplit: Codable, Hashable, Identifiable {
    var id: UUID
    var number: Int
    var distanceMeters: Double
    var duration: TimeInterval

    init(id: UUID = UUID(), number: Int, distanceMeters: Double, duration: TimeInterval) {
        self.id = id
        self.number = number
        self.distanceMeters = distanceMeters
        self.duration = duration
    }

    var paceSecondsPerMeter: Double? {
        guard distanceMeters > 0 else { return nil }
        return duration / distanceMeters
    }
}

struct DailyStepCount: Identifiable, Hashable {
    var date: Date
    var steps: Int

    var id: Date { date }
}

import SwiftUI

enum Palette {
    static let walk = Color("WalkColor")
    static let jog = Color("JogColor")
    static let run = Color("RunColor")
    static let ringTrack = Color.primary.opacity(0.08)
}

enum Formatters {
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func distanceValue(_ meters: Double, metric: Bool) -> String {
        if metric {
            if meters < 1000 {
                return String(format: "%.0f", meters)
            }
            return String(format: "%.2f", meters / 1000)
        }
        let miles = meters / 1609.344
        if miles < 0.1 {
            return String(format: "%.0f", meters * 3.28084)
        }
        return String(format: "%.2f", miles)
    }

    static func distanceUnit(_ meters: Double, metric: Bool) -> String {
        if metric {
            return meters < 1000 ? "m" : "km"
        }
        let miles = meters / 1609.344
        return miles < 0.1 ? "ft" : "mi"
    }

    static func distance(_ meters: Double, metric: Bool) -> String {
        "\(distanceValue(meters, metric: metric)) \(distanceUnit(meters, metric: metric))"
    }

    static func pace(secondsPerMeter: Double?, metric: Bool) -> String {
        guard let secondsPerMeter, secondsPerMeter.isFinite, secondsPerMeter > 0 else {
            return "—"
        }
        let seconds = metric ? secondsPerMeter * 1000 : secondsPerMeter * 1609.344
        guard seconds.isFinite, seconds > 0, seconds < 3600 else { return "—" }
        let minutes = Int(seconds) / 60
        let remainder = Int(seconds.rounded()) % 60
        let suffix = metric ? "/km" : "/mi"
        return String(format: "%d:%02d %@", minutes, remainder, suffix)
    }

    static func paceUnit(metric: Bool) -> String {
        metric ? "/km" : "/mi"
    }

    static func steps(_ count: Int) -> String {
        count.formatted()
    }

    static func calories(_ value: Double) -> String {
        String(format: "%.0f", max(0, value))
    }

    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    static func speed(_ kmh: Double?, metric: Bool) -> String {
        guard let kmh, kmh.isFinite, kmh > 0 else { return "—" }
        if metric {
            return String(format: "%.1f km/h", kmh)
        }
        return String(format: "%.1f mph", kmh * 0.621371)
    }

    static func speedUnit(metric: Bool) -> String {
        metric ? "km/h" : "mph"
    }

    static func tempo(_ stepsPerMinute: Double?) -> String {
        guard let stepsPerMinute, stepsPerMinute.isFinite, stepsPerMinute > 0 else { return "—" }
        return String(format: "%.0f spm", stepsPerMinute)
    }
}

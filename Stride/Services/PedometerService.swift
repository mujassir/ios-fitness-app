import CoreMotion
import Foundation

final class PedometerService {
    private let pedometer = CMPedometer()

    var isAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    static func requestAuthorization() -> CMAuthorizationStatus {
        CMPedometer.authorizationStatus()
    }

    func start(
        from date: Date,
        onUpdate: @escaping (Int, Double?, Double?) -> Void
    ) {
        guard isAvailable else { return }
        pedometer.startUpdates(from: date) { data, _ in
            guard let data else { return }
            let steps = data.numberOfSteps.intValue
            let distance = data.distance?.doubleValue
            let pace = data.currentPace?.doubleValue
            onUpdate(steps, distance, pace)
        }
    }

    func stop() {
        pedometer.stopUpdates()
    }
}

import Foundation
import SwiftData

@Observable
@MainActor
final class AppModel {
    let health: HealthKitService
    let session: WorkoutSessionManager
    let settings: AppSettings

    init() {
        let settings = AppSettings()
        let health = HealthKitService()
        self.settings = settings
        self.health = health
        self.session = WorkoutSessionManager(health: health, settings: settings)
    }

    func refresh() async {
        await health.refreshToday()
        await health.refreshWeek()
        await health.refreshWorkouts(weightKilograms: settings.weightKilograms)
    }

    func completeOnboarding() async {
        await health.requestAuthorization()
        _ = PedometerService.requestAuthorization()
        settings.hasCompletedOnboarding = true
        await refresh()
    }
}

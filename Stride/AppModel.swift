import Foundation

@Observable
@MainActor
final class AppModel {
    let health: HealthKitService
    let settings: AppSettings
    let updates = UpdateChecker()

    init() {
        let settings = AppSettings()
        let health = HealthKitService()
        self.settings = settings
        self.health = health
    }

    func refresh() async {
        await health.refreshToday()
        await health.refreshWeek()
        await health.refreshWorkouts(weightKilograms: settings.weightKilograms)
    }

    func completeOnboarding() async {
        await health.requestAuthorization()
        settings.hasCompletedOnboarding = true
        await refresh()
    }
}

import Foundation

@Observable
@MainActor
final class AppModel {
    let health: HealthKitService
    let settings: AppSettings
    let updates = UpdateChecker()
    let selection = StatsSelection()

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
        await prewarm()
    }

    /// Works out this week and month in the background so Week and Month open
    /// without a wait. Called after data loads and after settings that change
    /// the stats (pace, session lengths, body weight).
    func prewarm() async {
        await health.prepare(
            [HealthKitService.weekRange(StatsPeriod.startOfWeek(containing: .now))]
                + HealthKitService.monthRanges(),
            detection: settings.detection,
            weightKilograms: settings.weightKilograms
        )
    }

    func completeOnboarding() async {
        await health.requestAuthorization()
        settings.hasCompletedOnboarding = true
        await refresh()
    }
}

/// The Daily / Week / Month choice and the selected day or week, shared by
/// every stats tab so switching tabs keeps the same view.
@Observable
@MainActor
final class StatsSelection {
    var period: StatsPeriod = .daily
    var selectedDay = Calendar.current.startOfDay(for: .now)
    var weekOffset = 0
    var monthOffset = 0
    var selectedWeekStart = StatsPeriod.startOfWeek(containing: .now)
    /// How far the stats page is scrolled, so switching tabs keeps the place
    /// (for example from Energy by day to Steps by day).
    var scrollOffset: CGFloat = 0
}

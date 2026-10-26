import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            if model.settings.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Color.accentColor)
        .task {
            guard model.settings.hasCompletedOnboarding else { return }
            model.health.refreshAuthorizationStatus()
            await model.refresh()
            await model.health.startObserving()
        }
    }
}

struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            Tab("Stats", systemImage: "chart.bar.fill") {
                StatsView()
            }
            Tab("You", systemImage: "person.crop.circle") {
                SettingsView()
            }
        }
        .fullScreenCover(isPresented: Bindable(model.session).isLivePresented) {
            LiveWorkoutView()
                .interactiveDismissDisabled()
        }
    }
}

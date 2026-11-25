import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsAccessPrompt = false
    @State private var accessPromptDismissed = false
    @State private var wasInBackground = false

    var body: some View {
        @Bindable var updates = model.updates
        Group {
            if model.settings.hasCompletedOnboarding {
                MainTabView()
                    .alert("No Health data", isPresented: $showsAccessPrompt) {
                        Button("Open Health") { model.health.openHealthApp() }
                        Button("Try Again") {
                            Task { await checkHealthAccess(requestIfNeeded: true) }
                        }
                        Button("Not Now", role: .cancel) { accessPromptDismissed = true }
                    } message: {
                        Text("RunCheck can't read any steps or workouts. In Health, tap your profile, then Apps → RunCheck, and turn on all categories.")
                    }
            } else {
                OnboardingView()
            }
        }
        .tint(Color.accentColor)
        .task {
            guard model.settings.hasCompletedOnboarding else { return }
            await checkHealthAccess(requestIfNeeded: true)
            await model.updates.check()
            await model.health.startObserving()
        }
        .onChange(of: scenePhase) { _, phase in
            // Coming back from the Health app (or the background): reload, so
            // access turned on there shows up straight away.
            if phase == .background { wasInBackground = true }
            guard phase == .active, wasInBackground,
                  model.settings.hasCompletedOnboarding else { return }
            wasInBackground = false
            Task {
                await checkHealthAccess(requestIfNeeded: false)
                await model.updates.check()
            }
        }
        .alert("Update available", isPresented: $updates.showsPrompt) {
            Button("Update") { model.updates.openAppStore() }
            Button("Not Now", role: .cancel) { model.updates.skipAvailableVersion() }
        } message: {
            if let version = model.updates.availableVersion {
                Text("RunCheck \(version) is on the App Store. You have \(model.updates.currentVersion).")
            }
        }
    }

    /// Re-shows the Health sheet for unanswered types, reloads stats, and
    /// prompts when Health still returns nothing.
    private func checkHealthAccess(requestIfNeeded: Bool) async {
        if requestIfNeeded {
            await model.health.requestAuthorizationIfNeeded()
        } else {
            model.health.refreshAuthorizationStatus()
        }
        await model.refresh()
        if model.health.accessLikelyMissing {
            if !accessPromptDismissed { showsAccessPrompt = true }
        } else {
            showsAccessPrompt = false
            accessPromptDismissed = false
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
    }
}

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
    @State private var selection: AppTab = .summary

    private var tabs: [AppTab] {
        [.summary]
            + ActivityTab.allCases.filter { model.settings.isTabEnabled($0) }.map(AppTab.activity)
            + [.you]
    }

    var body: some View {
        ZStack {
            // Only the visible tab is built. Period and selected day live in
            // AppModel, so they carry over when switching tabs.
            screen(for: selection)
                .id(selection)
        }
        .overlay(alignment: .bottom) {
            // Floats over the content. Scrolling screens add their own bottom
            // margin (clearsTabBar) so their last card ends above it.
            ScrollingTabBar(tabs: tabs, selection: $selection)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            // Screens hide the navigation bar, so fill the status bar area
            // to keep scrolled content from showing behind the clock. A
            // colour background extends into the safe area on its own.
            Color.clear
                .frame(height: 0)
                .background(Color(.systemGroupedBackground))
        }
        .task(id: StatsSettingsKey(
            detection: model.settings.detection,
            weight: model.settings.weightKilograms
        )) {
            // Settings changed (or first appearance): wait for stepper taps to
            // settle, then recalculate Week and Month in the background.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await model.prewarm()
        }
        .onChange(of: tabs) { _, newTabs in
            if !newTabs.contains(selection) {
                selection = .you
            }
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .summary: StatsView(focus: .summary)
        case .activity(let activity): StatsView(focus: activity.focus)
        case .you: SettingsView()
        }
    }
}

private struct StatsSettingsKey: Hashable {
    let detection: ActivityDetectionSettings
    let weight: Double
}

enum AppTab: Hashable, Identifiable {
    case summary
    case activity(ActivityTab)
    case you

    var id: String {
        switch self {
        case .summary: "summary"
        case .activity(let tab): tab.rawValue
        case .you: "you"
        }
    }

    var title: String {
        switch self {
        case .summary: "Summary"
        case .activity(let tab): tab.title
        case .you: "You"
        }
    }

    var symbol: String {
        switch self {
        case .summary: "chart.bar.fill"
        case .activity(let tab): tab.symbol
        case .you: "person.crop.circle"
        }
    }

    var color: Color {
        switch self {
        case .activity(let tab): tab.color
        case .summary: .accentColor
        // You keeps the system's default look.
        case .you: .primary
        }
    }
}

/// A floating tab bar in the style of the system one. All tabs share the
/// width when they fit; with more tabs than fit, the bar scrolls sideways.
struct ScrollingTabBar: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab

    /// Narrowest a tab (and its highlight) may get before the bar scrolls.
    private let minItemWidth: CGFloat = 100
    /// Tabs on screen at once when the bar scrolls; the fraction peeks in
    /// at the edge to show there are more.
    private let visibleWhenScrolling: CGFloat = 3.3
    private let barHeight = CapsuleBarMetrics.height
    private let inset = CapsuleBarMetrics.inset
    private let gap = CapsuleBarMetrics.itemGap

    var body: some View {
        GeometryReader { proxy in
            let inner = proxy.size.width - (inset * 2 - gap)
            // Tabs share the width while each gets at least minItemWidth;
            // past that the bar scrolls, so the highlight never gets narrow
            // on smaller iPhones or with more tabs.
            let evenWidth = inner / CGFloat(max(tabs.count, 1))
            let scrolls = evenWidth < minItemWidth
            let itemWidth = scrolls ? inner / visibleWhenScrolling : evenWidth

            ScrollViewReader { reader in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(tabs) { tab in
                            item(tab, width: itemWidth)
                                .id(tab)
                        }
                    }
                    .padding(.horizontal, inset - gap / 2)
                    .frame(height: barHeight)
                }
                .frame(height: barHeight)
                .scrollDisabled(!scrolls)
                .scrollClipDisabled(false)
                .onChange(of: selection) { _, tab in
                    guard scrolls else { return }
                    withAnimation(.snappy) { reader.scrollTo(tab, anchor: .center) }
                }
            }
        }
        .frame(height: barHeight)
        .background(CapsuleBarBackground())
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func item(_ tab: AppTab, width: CGFloat) -> some View {
        let isSelected = tab == selection
        return Button {
            withAnimation(.snappy) { selection = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 24)
                    .foregroundStyle(tab.color)
                Text(tab.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(isSelected ? tab.color : Color.primary)
            }
            .frame(width: width - gap, height: CapsuleBarMetrics.highlightHeight)
            .background {
                if isSelected {
                    CapsuleHighlight()
                }
            }
            .frame(width: width)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

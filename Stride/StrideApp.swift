import SwiftUI
import UIKit

@main
struct StrideApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .onAppear { apply(model.settings.appearance) }
                .onChange(of: model.settings.appearance) { _, appearance in
                    apply(appearance)
                }
        }
    }

    /// Sets the look on the window rather than with `preferredColorScheme`,
    /// so alerts and sheets follow it too and going back to System works
    /// without relaunching.
    private func apply(_ appearance: AppAppearance) {
        let style: UIUserInterfaceStyle = switch appearance {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

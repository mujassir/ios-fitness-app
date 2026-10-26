import SwiftData
import SwiftUI

@main
struct StrideApp: App {
    @State private var model = AppModel()
    private let container: ModelContainer

    init() {
        let schema = Schema([Workout.self])
        let configuration = ModelConfiguration(
            "Stride",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Stride data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
        .modelContainer(container)
    }
}

import SwiftData
import SwiftUI

@main
struct BitefluxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var logger = EntryLogger()
    private let container: ModelContainer

    init() {
        FontRegistration.registerBundledFonts()
        do {
            container = try ModelContainer(for: FoodEntry.self)
        } catch {
            fatalError("Couldn't open the food log: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environment(logger)
                .tint(Ember.accent)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            // Anything Apple Health hasn't confirmed gets another go when the app comes back.
            Task { @MainActor in
                await logger.syncUnconfirmed(in: container.mainContext)
            }
        }
    }
}

import SwiftData
import SwiftUI

@main
struct BitefluxApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var logger = EntryLogger()
    private let container: ModelContainer

    /// The CloudKit container for iCloud sync of your log and library, like
    /// "iCloud.com.kevinvandijk.biteflux". Nil keeps everything on this phone. Turning it on needs
    /// the iCloud capability, which needs a paid Apple developer account; see the README.
    static let iCloudContainer: String? = nil

    init() {
        FontRegistration.registerBundledFonts()
        do {
            var configuration = ModelConfiguration(cloudKitDatabase: .none)
            if let iCloud = Self.iCloudContainer {
                configuration = ModelConfiguration(cloudKitDatabase: .private(iCloud))
            }
            container = try ModelContainer(for: FoodEntry.self, Product.self, configurations: configuration)
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

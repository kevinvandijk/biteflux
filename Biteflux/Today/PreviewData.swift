import BitefluxCore
import Foundation
import SwiftData

/// An in-memory food log for SwiftUI previews, with one entry in each sync state.
@MainActor
enum PreviewData {
    static func container() -> ModelContainer {
        FontRegistration.registerBundledFonts()
        let container = try! ModelContainer(
            for: FoodEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let meals: [Meal] = [.breakfast, .breakfast, .lunch, .lunch, .snacks, .snacks]
        let states: [SyncState] = [.inHealth, .inHealth, .inHealth, .inHealth, .waiting, .failed]
        for (index, food) in SampleFood.all.enumerated() {
            let entry = FoodEntry(
                name: food.name,
                brand: food.brand,
                portion: food.portion,
                grams: food.grams,
                meal: meals[index],
                eatenAt: .now,
                nutrients: food.nutrients
            )
            entry.syncState = states[index]
            if entry.syncState == .failed {
                entry.syncProblem = HealthStore.Problem.notAllowed.localizedDescription
            }
            container.mainContext.insert(entry)
        }
        return container
    }
}

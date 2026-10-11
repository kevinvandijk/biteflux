import BitefluxCore
import Foundation
import Observation
import SwiftData

/// Logs food: keeps it in Biteflux first, then writes it to Apple Health and reads it back.
///
/// An entry only counts as `inHealth` once Apple Health returns it. Before saving,
/// the logger looks for an earlier save of the same entry, so a retry never logs
/// the same food twice.
@MainActor
@Observable
final class EntryLogger {
    private let health: HealthStore
    private(set) var access: HealthStore.Access

    init(health: HealthStore = HealthStore()) {
        self.health = health
        self.access = health.access
    }

    func refreshAccess() {
        access = health.access
    }

    func requestAccess() async {
        try? await health.requestAccess()
        refreshAccess()
    }

    /// Keeps the entry in Biteflux, then writes it to Apple Health.
    func log(_ entry: FoodEntry, in context: ModelContext) async {
        context.insert(entry)
        try? context.save()
        await sync(entry, in: context)
    }

    /// Writes one entry to Apple Health and confirms it is there.
    func sync(_ entry: FoodEntry, in context: ModelContext) async {
        defer { try? context.save() }
        do {
            if health.access == .notAsked {
                try await health.requestAccess()
            }
            refreshAccess()

            if let savedID = entry.healthFoodID {
                // Saved earlier: only confirm it, never save it again.
                guard try await health.foodExists(withID: savedID) else { throw HealthStore.Problem.notReadBack }
            } else if let earlierID = try await health.foodID(forEntry: entry.entryID) {
                // Saved earlier, but the app stopped before it could note that.
                entry.healthFoodID = earlierID
            } else {
                let savedID = try await health.save(entry.healthFood)
                entry.healthFoodID = savedID
                guard try await health.foodExists(withID: savedID) else { throw HealthStore.Problem.notReadBack }
            }
            entry.syncState = .inHealth
            entry.syncProblem = nil
        } catch {
            entry.syncState = .failed
            entry.syncProblem = error.localizedDescription
        }
    }

    /// Retries every entry Apple Health hasn't confirmed, for example when the app comes back to the front.
    func syncUnconfirmed(in context: ModelContext) async {
        refreshAccess()
        let confirmed = SyncState.inHealth.rawValue
        let descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate<FoodEntry> { $0.syncStateRawValue != confirmed })
        guard let entries = try? context.fetch(descriptor) else { return }
        for entry in entries {
            await sync(entry, in: context)
        }
    }

    /// Removes the entry from Apple Health first, then from Biteflux.
    func delete(_ entry: FoodEntry, in context: ModelContext) async {
        // An entry that never reached Apple Health can go when Biteflux may not write there.
        if entry.healthFoodID != nil || health.access == .allowed {
            do {
                try await health.deleteFood(forEntry: entry.entryID)
            } catch {
                entry.syncProblem = "Couldn't remove it from Apple Health: \(error.localizedDescription)"
                try? context.save()
                return
            }
        }
        context.delete(entry)
        try? context.save()
    }
}

extension FoodEntry {
    var healthFood: HealthFood {
        HealthFood(entryID: entryID, name: name, meal: meal, eatenAt: eatenAt, nutrients: nutrients)
    }
}

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
    /// This install, as the writer of the entries it logs or changes.
    private let deviceID: String

    /// The save or delete running for each entry. Every `await` lets other work in, so
    /// without this two syncs of one entry could both find nothing in Apple Health and
    /// both save it, or a sync could save an entry that a delete just removed.
    @ObservationIgnored private var running: [UUID: Task<Void, Never>] = [:]

    /// Pass `nil` for the real Apple Health store. A default argument can't create it,
    /// because default arguments aren't evaluated on the main actor.
    init(health: HealthStore? = nil, deviceID: String? = nil) {
        let health = health ?? HealthStore()
        self.health = health
        self.access = health.access
        self.deviceID = deviceID ?? InstallID.current()
    }

    /// Whether this device writes the entry to Apple Health. An entry another device logged is
    /// that device's to write; Apple Health brings it here on its own.
    private func writesHere(_ entry: FoodEntry) -> Bool {
        entry.healthWriterID == nil || entry.healthWriterID == deviceID
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
        await sync(entry, in: context)
    }

    /// Writes one entry to Apple Health and confirms it is there.
    /// If the entry is already being saved or deleted, waits for that instead.
    func sync(_ entry: FoodEntry, in context: ModelContext) async {
        guard !entry.isDeleted, entry.modelContext != nil, writesHere(entry) else { return }
        if let other = running[entry.entryID] {
            await other.value
            return
        }
        await start(entry.entryID) { await self.write(entry, in: context) }.value
    }

    private func write(_ entry: FoodEntry, in context: ModelContext) async {
        if entry.healthWriterID == nil {
            entry.healthWriterID = deviceID
        }
        // Apple Health only gets food Biteflux has stored, so nothing there is left without its entry.
        do {
            try context.save()
        } catch {
            entry.syncState = .failed
            entry.syncProblem = "Couldn't keep it in Biteflux: \(error.localizedDescription)"
            return
        }

        defer { try? context.save() }
        do {
            if health.access == .notAsked {
                try await health.requestAccess()
            }
            refreshAccess()

            if entry.healthOutdated {
                // Apple Health can't edit a saved food, so the old one goes and the new values are saved fresh.
                if entry.healthFoodID != nil || health.access == .allowed {
                    try await health.deleteFood(forEntry: entry.entryID)
                }
                entry.healthFoodID = nil
                entry.healthOutdated = false
                try? context.save()
            }

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
    ///
    /// With `takingOver`, entries another device was meant to write become this device's, for when
    /// that device is gone, like an old phone. Only a tap on "Try again" asks for that, because
    /// if the other device is still around, both could write the same food.
    func syncUnconfirmed(in context: ModelContext, takingOver: Bool = false) async {
        refreshAccess()
        let confirmed = SyncState.inHealth.rawValue
        let descriptor = FetchDescriptor<FoodEntry>(predicate: #Predicate<FoodEntry> { $0.syncStateRawValue != confirmed })
        guard let entries = try? context.fetch(descriptor) else { return }
        for entry in entries {
            if takingOver, !entry.isDeleted, !writesHere(entry) {
                entry.healthWriterID = deviceID
                // The other device's Apple Health ID may never reach this one, so look the entry up
                // by its Biteflux ID instead, and save it only if Apple Health doesn't have it.
                entry.healthFoodID = nil
            }
            await sync(entry, in: context)
        }
    }

    /// Keeps a change to an entry in Biteflux, then replaces the entry in Apple Health with the
    /// new values. Waits for a save or delete of the same entry to finish first.
    func update(_ entry: FoodEntry, in context: ModelContext, change: (FoodEntry) -> Void) async {
        while let other = running[entry.entryID] {
            await other.value
        }
        guard !entry.isDeleted, entry.modelContext != nil else { return }
        change(entry)
        // Whoever changes an entry replaces it in Apple Health, so this device takes it over.
        entry.healthWriterID = deviceID
        entry.healthOutdated = true
        entry.syncState = .waiting
        entry.syncProblem = nil
        await start(entry.entryID) { await self.write(entry, in: context) }.value
    }

    /// Removes the entry from Apple Health first, then from Biteflux.
    /// Waits for a save of the same entry to finish, so the save can't bring it back.
    func delete(_ entry: FoodEntry, in context: ModelContext) async {
        while let other = running[entry.entryID] {
            await other.value
        }
        guard !entry.isDeleted, entry.modelContext != nil else { return }
        await start(entry.entryID) { await self.remove(entry, in: context) }.value
    }

    private func remove(_ entry: FoodEntry, in context: ModelContext) async {
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

    /// Starts `work` as the only work for this entry. Registering happens before any
    /// `await`, and the task clears its own slot before anyone waiting on it resumes.
    private func start(_ entryID: UUID, _ work: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let task = Task { @MainActor in
            await work()
            self.running[entryID] = nil
        }
        running[entryID] = task
        return task
    }
}

extension FoodEntry {
    var healthFood: HealthFood {
        HealthFood(entryID: entryID, name: name, meal: meal, eatenAt: eatenAt, nutrients: nutrients)
    }
}

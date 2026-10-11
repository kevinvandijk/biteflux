import BitefluxCore
import Foundation
import HealthKit

/// What Biteflux writes to Apple Health for one logged entry.
struct HealthFood {
    var entryID: UUID
    var name: String
    var meal: Meal
    var eatenAt: Date
    var nutrients: Nutrients
}

/// Saves logged food to Apple Health as food entries, reads them back and removes them.
///
/// Each entry becomes one HealthKit food correlation named after the product,
/// holding one sample per nutrient. Every object carries the Biteflux entry ID,
/// so an entry can be found again without ever saving it twice.
@MainActor
final class HealthStore {
    enum Access: Equatable {
        /// This device has no Apple Health, like some iPads.
        case unavailable
        case notAsked
        case allowed
        /// At least one nutrient type may not be written.
        case denied
    }

    enum Problem: LocalizedError {
        case unavailable
        case notAllowed
        case notReadBack

        var errorDescription: String? {
            switch self {
            case .unavailable: "Apple Health isn't available on this device."
            case .notAllowed: "Biteflux isn't allowed to save nutrition to Apple Health."
            case .notReadBack: "It was saved, but Biteflux couldn't read it back from Apple Health."
            }
        }
    }

    /// Biteflux's own metadata keys. HealthKit reserves keys that start with "HK".
    static let entryIDKey = "BitefluxEntryID"
    static let mealKey = "BitefluxMeal"

    private static let nutrientTypes: [HKQuantityTypeIdentifier] = [
        .dietaryEnergyConsumed,
        .dietaryProtein,
        .dietaryCarbohydrates,
        .dietarySugar,
        .dietaryFiber,
        .dietaryFatTotal,
        .dietaryFatSaturated,
        .dietarySodium,
    ]

    private let store = HKHealthStore()

    /// HealthKit grants access per nutrient; a food correlation can't be requested on its own.
    private var shareTypes: Set<HKSampleType> {
        Set(Self.nutrientTypes.map { HKQuantityType($0) as HKSampleType })
    }

    private var readTypes: Set<HKObjectType> {
        Set(Self.nutrientTypes.map { HKQuantityType($0) as HKObjectType })
    }

    var access: Access {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        let statuses = shareTypes.map { store.authorizationStatus(for: $0) }
        if statuses.allSatisfy({ $0 == .sharingAuthorized }) { return .allowed }
        if statuses.contains(.notDetermined) { return .notAsked }
        return .denied
    }

    /// Shows the Apple Health permission sheet for the nutrients Biteflux saves.
    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw Problem.unavailable }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Saves the food as one Apple Health food entry and returns that entry's ID.
    func save(_ food: HealthFood) async throws -> UUID {
        guard access == .allowed else { throw Problem.notAllowed }

        let metadata: [String: Any] = [
            HKMetadataKeyFoodType: food.name,
            Self.entryIDKey: food.entryID.uuidString,
            Self.mealKey: food.meal.rawValue,
        ]
        let nutrients = food.nutrients
        let values: [(HKQuantityTypeIdentifier, Double?, HKUnit)] = [
            (.dietaryEnergyConsumed, nutrients.energyKcal, .kilocalorie()),
            (.dietaryProtein, nutrients.proteinG, .gram()),
            (.dietaryCarbohydrates, nutrients.carbohydratesG, .gram()),
            (.dietarySugar, nutrients.sugarG, .gram()),
            (.dietaryFiber, nutrients.fiberG, .gram()),
            (.dietaryFatTotal, nutrients.fatG, .gram()),
            (.dietaryFatSaturated, nutrients.saturatedFatG, .gram()),
            (.dietarySodium, nutrients.sodiumMg, .gramUnit(with: .milli)),
        ]

        var samples = Set<HKSample>()
        for (identifier, value, unit) in values {
            guard let value else { continue }
            samples.insert(HKQuantitySample(
                type: HKQuantityType(identifier),
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: food.eatenAt,
                end: food.eatenAt,
                metadata: metadata
            ))
        }

        let correlation = HKCorrelation(
            type: HKCorrelationType(.food),
            start: food.eatenAt,
            end: food.eatenAt,
            objects: samples,
            metadata: metadata
        )
        try await store.save(correlation)
        return correlation.uuid
    }

    /// The Apple Health food entry saved for a Biteflux entry, if one exists.
    func foodID(forEntry entryID: UUID) async throws -> UUID? {
        try await foods(matching: Self.predicate(forEntry: entryID)).first?.uuid
    }

    /// Whether the Apple Health food entry with this ID can be read back.
    func foodExists(withID id: UUID) async throws -> Bool {
        let found = try await foods(matching: HKQuery.predicateForObject(with: id))
        return !found.isEmpty
    }

    /// Removes the food entry and its nutrient samples for a Biteflux entry.
    ///
    /// Deletes by the entry ID in the metadata, which only needs write access,
    /// so it also works when Biteflux may not read from Apple Health.
    func deleteFood(forEntry entryID: UUID) async throws {
        let predicate = Self.predicate(forEntry: entryID)
        _ = try await store.deleteObjects(of: HKCorrelationType(.food), predicate: predicate)
        for type in shareTypes {
            _ = try await store.deleteObjects(of: type, predicate: predicate)
        }
    }

    private static func predicate(forEntry entryID: UUID) -> NSPredicate {
        HKQuery.predicateForObjects(withMetadataKey: entryIDKey, allowedValues: [entryID.uuidString])
    }

    private func foods(matching predicate: NSPredicate) async throws -> [HKCorrelation] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKCorrelationType(.food),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples ?? []).compactMap { $0 as? HKCorrelation })
                }
            }
            store.execute(query)
        }
    }
}

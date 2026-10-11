import BitefluxCore
import SwiftUI

/// A made-up food for trying the Apple Health round trip before scanning exists.
struct SampleFood: Identifiable {
    var name: String
    var brand: String?
    var portion: String
    var grams: Double
    var per100g: Nutrients

    var id: String { name }

    var nutrients: Nutrients {
        per100g.per100g(forPortionOf: grams)
    }

    /// The foods from the B4 design, with typical values per 100 g. Not taken from real labels.
    static let all: [SampleFood] = [
        SampleFood(
            name: "Skyr Naturel", brand: "Arla", portion: "150 g", grams: 150,
            per100g: Nutrients(energyKcal: 63, proteinG: 11, carbohydratesG: 4, sugarG: 4, fatG: 0.2, saturatedFatG: 0.1, sodiumMg: 40)
        ),
        SampleFood(
            name: "Banaan", portion: "1 medium", grams: 118,
            per100g: Nutrients(energyKcal: 89, proteinG: 1.1, carbohydratesG: 22.8, sugarG: 12.2, fiberG: 2.6, fatG: 0.3, saturatedFatG: 0.1, sodiumMg: 1)
        ),
        SampleFood(
            name: "Volkoren brood", portion: "2 slices", grams: 70,
            per100g: Nutrients(energyKcal: 243, proteinG: 9.5, carbohydratesG: 39, sugarG: 3, fiberG: 7, fatG: 3, saturatedFatG: 0.6, sodiumMg: 400)
        ),
        SampleFood(
            name: "Jonge kaas", portion: "30 g", grams: 30,
            per100g: Nutrients(energyKcal: 360, proteinG: 24, carbohydratesG: 0, sugarG: 0, fatG: 29, saturatedFatG: 19, sodiumMg: 800)
        ),
        SampleFood(
            name: "Haverkoek pure chocolade", brand: "Bakkerij Vos", portion: "1 koek", grams: 25,
            per100g: Nutrients(energyKcal: 402, proteinG: 8.1, carbohydratesG: 49, sugarG: 21, fiberG: 4.2, fatG: 18, saturatedFatG: 7.5, sodiumMg: 180)
        ),
        SampleFood(
            name: "Appel", portion: "1 medium", grams: 182,
            per100g: Nutrients(energyKcal: 52, proteinG: 0.3, carbohydratesG: 14, sugarG: 10, fiberG: 2.4, fatG: 0.2, saturatedFatG: 0, sodiumMg: 1)
        ),
    ]
}

/// Lets you log a sample food to try saving to Apple Health. Scanning replaces this in step 3.
struct SampleFoodSheet: View {
    var onPick: (SampleFood) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Try Apple Health")
                    .font(Ember.serif(30))
                    .accessibilityAddTraits(.isHeader)
                Text("Scanning arrives in a later step. Pick a sample food and Biteflux saves it to Apple Health, then reads it back.")
                    .font(Ember.sans(14))
                    .foregroundStyle(Ember.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(SampleFood.all) { food in
                    Button {
                        onPick(food)
                        dismiss()
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: food.name)
                                    .font(Ember.sans(16, weight: .medium))
                                Text(verbatim: food.portion)
                                    .font(Ember.sans(13, relativeTo: .footnote))
                                    .foregroundStyle(Ember.secondaryText)
                            }
                            Spacer(minLength: 12)
                            Text(verbatim: "\(food.nutrients.energyKcal.wholeNumber) kcal")
                                .font(Ember.sans(15))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .foregroundStyle(Ember.text)
        .presentationDetents([.medium, .large])
        .presentationBackground(Ember.background)
    }
}

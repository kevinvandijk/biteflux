import BitefluxCore
import SwiftUI

/// One product: how much you ate, which meal, and its nutrients for that portion.
struct ProductView: View {
    var product: Product
    var onLog: (Product, Double, Meal) -> Void

    @State private var gramsText: String
    @State private var meal = Meal.suggested(at: .now)

    init(product: Product, onLog: @escaping (Product, Double, Meal) -> Void) {
        self.product = product
        self.onLog = onLog
        _gramsText = State(initialValue: (product.servingGrams ?? 100).inputText)
    }

    private var grams: Double? {
        DecimalInput.value(gramsText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var portion: Nutrients? {
        grams.map { product.per100g.per100g(forPortionOf: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: product.name)
                        .font(Ember.serif(30))
                        .accessibilityAddTraits(.isHeader)
                    if let brand = product.brand {
                        Text(verbatim: brand)
                            .font(Ember.sans(15))
                            .foregroundStyle(Ember.secondaryText)
                    }
                }
                if product.source == .openFoodFacts {
                    Text("From Open Food Facts, where anyone can add products. Check these values against the label before you log it.")
                        .font(Ember.sans(14))
                        .foregroundStyle(Ember.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                portionCard
                NutrientTable(per100g: product.per100g, portion: portion, grams: grams)
                logButton
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Ember.background)
        .foregroundStyle(Ember.text)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var portionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", text: $gramsText)
                    .keyboardType(.decimalPad)
                    .font(Ember.serif(34, relativeTo: .title))
                    .fixedSize()
                    .accessibilityLabel("Grams")
                Text("g")
                    .font(Ember.sans(17))
                    .foregroundStyle(Ember.secondaryText)
                Spacer(minLength: 12)
                if let portion {
                    Text(verbatim: "\(portion.energyKcal.wholeNumber) kcal")
                        .font(Ember.serif(34, relativeTo: .title))
                        .foregroundStyle(Ember.accent)
                }
            }
            HStack(spacing: 8) {
                if let servingGrams = product.servingGrams {
                    amountChip("\(product.servingName ?? "1 serving") · \(servingGrams.amount) g", grams: servingGrams)
                }
                amountChip("100 g", grams: 100)
            }
            Picker("Meal", selection: $meal) {
                ForEach(Meal.allCases) { meal in
                    Text(verbatim: meal.title).tag(meal)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func amountChip(_ title: String, grams: Double) -> some View {
        Button {
            gramsText = grams.inputText
        } label: {
            Text(verbatim: title)
                .font(Ember.sans(14, weight: .medium, relativeTo: .subheadline))
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(Ember.track, in: Capsule())
    }

    private var logButton: some View {
        Button {
            if let grams {
                onLog(product, grams, meal)
            }
        } label: {
            Text("Log it")
                .font(Ember.sans(17, weight: .bold, relativeTo: .headline))
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Ember.onAccent)
        .background(Ember.text, in: Capsule())
        .opacity(grams == nil ? 0.4 : 1)
        .disabled(grams == nil)
        .padding(.top, 4)
    }
}

/// The label's nutrients per 100 g next to the same values for your portion.
private struct NutrientTable: View {
    var per100g: Nutrients
    var portion: Nutrients?
    var grams: Double?

    private struct Line: Identifiable {
        var name: String
        var isPart: Bool
        var per100g: String
        var portion: String
        var id: String { name }
    }

    private var lines: [Line] {
        func line(_ name: String, isPart: Bool = false, unit: String = "g", decimals: Int = 1, _ value: (Nutrients) -> Double?) -> Line {
            func text(_ nutrients: Nutrients?) -> String {
                guard let nutrients, let amount = value(nutrients) else { return "–" }
                return "\(amount.formatted(.number.precision(.fractionLength(0...decimals)))) \(unit)"
            }
            return Line(name: name, isPart: isPart, per100g: text(per100g), portion: text(portion))
        }
        return [
            line("Energy", unit: "kcal", decimals: 0) { $0.energyKcal },
            line("Protein") { $0.proteinG },
            line("Carbohydrates") { $0.carbohydratesG },
            line("of which sugars", isPart: true) { $0.sugarG },
            line("Fat") { $0.fatG },
            line("of which saturated", isPart: true) { $0.saturatedFatG },
            line("Fiber") { $0.fiberG },
            // Biteflux keeps sodium, as Apple Health does; labels list salt, which is 400 mg of sodium per gram.
            line("Salt", decimals: 2) { $0.sodiumMg.map { $0 / 400 } },
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nutrition")
                    .font(Ember.sans(15, weight: .bold, relativeTo: .headline))
                Spacer(minLength: 8)
                Text("100 g")
                    .frame(minWidth: 76, alignment: .trailing)
                Text(verbatim: grams.map { "\($0.amount) g" } ?? "–")
                    .frame(minWidth: 76, alignment: .trailing)
            }
            .font(Ember.sans(13, relativeTo: .footnote))
            .foregroundStyle(Ember.secondaryText)

            ForEach(lines) { line in
                HStack {
                    Text(verbatim: line.name)
                        .padding(.leading, line.isPart ? 12 : 0)
                    Spacer(minLength: 8)
                    Text(verbatim: line.per100g)
                        .frame(minWidth: 76, alignment: .trailing)
                    Text(verbatim: line.portion)
                        .frame(minWidth: 76, alignment: .trailing)
                }
                .font(Ember.sans(14))
                .foregroundStyle(line.isPart ? Ember.secondaryText : Ember.rowText)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

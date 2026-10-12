import BitefluxCore
import SwiftUI

/// The B4 Match screen: the product that was found, a dial for how much you ate, the meal, and
/// one button to log it.
struct MatchView: View {
    var product: Product
    var onLog: (Product, Double, Meal) -> Void
    /// Opens the Create screen, for when this isn't the product you have.
    var onAddNew: () -> Void

    @State private var grams: Double
    @State private var meal = Meal.suggested(at: .now)
    @State private var typingAmount = false
    @State private var amountText = ""

    init(product: Product, onLog: @escaping (Product, Double, Meal) -> Void, onAddNew: @escaping () -> Void) {
        self.product = product
        self.onLog = onLog
        self.onAddNew = onAddNew
        _grams = State(initialValue: product.lastLoggedGrams ?? product.servingGrams ?? 100)
    }

    private var dial: GramDial {
        GramDial(servingGrams: product.servingGrams)
    }

    private var portion: Nutrients {
        product.per100g.per100g(forPortionOf: grams)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                if product.source == .openFoodFacts {
                    Text("Open Food Facts is filled in by anyone, so check these values against the label before you log it.")
                        .font(Ember.sans(14))
                        .foregroundStyle(Ember.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                GramDialView(
                    grams: $grams,
                    dial: dial,
                    kcal: portion.energyKcal,
                    macros: "P \(portion.proteinG.amount) · C \(portion.carbohydratesG.amount) · F \(portion.fatG.amount)",
                    onType: startTyping
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                FlowLayout(spacing: 8) {
                    ForEach(portionOptions) { option in
                        ChoiceChip(title: option.title, chosen: abs(grams - option.grams) < 0.05) {
                            grams = option.grams
                        }
                    }
                }
                MealPicker(meal: $meal)
                Button(action: onAddNew) {
                    Text("Not it? Add a new one")
                        .font(Ember.sans(14))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ember.secondaryText)
                NutrientTable(per100g: product.per100g, portion: portion, grams: grams)
                if product.source == .nevo {
                    Text(verbatim: NEVO.attribution + ".")
                        .font(Ember.sans(13, relativeTo: .footnote))
                        .foregroundStyle(Ember.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Ember.background)
        .foregroundStyle(Ember.text)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                PrimaryButton(title: "Log it to \(meal.title.lowercased())") {
                    onLog(product, grams, meal)
                }
            }
        }
        .alert("How many grams?", isPresented: $typingAmount) {
            TextField("Grams", text: $amountText)
                .keyboardType(.decimalPad)
            Button("Done") {
                if let value = DecimalInput.value(amountText), value > 0 {
                    grams = value
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(verbatim: foundText)
            } icon: {
                Image(systemName: "checkmark")
                    .fontWeight(.bold)
            }
            .font(Ember.sans(13, relativeTo: .footnote))
            .foregroundStyle(Ember.confirmed)
            Text(verbatim: product.name)
                .font(Ember.serif(36, relativeTo: .largeTitle))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: [product.brand, "\(product.per100g.energyKcal.wholeNumber) kcal per 100 g"].compactMap { $0 }.joined(separator: " · "))
                .font(Ember.sans(14))
                .foregroundStyle(Ember.secondaryText)
        }
    }

    private var foundText: String {
        // A product only gets a model context once it's in your library.
        if product.modelContext != nil {
            return "In your products"
        }
        switch product.source {
        case .openFoodFacts: return "Found it on Open Food Facts"
        case .nevo: return "Found it in NEVO, the Dutch food table"
        case .own: return "Ready to log"
        }
    }

    private struct PortionOption: Identifiable {
        var title: String
        var grams: Double
        var id: String { title }
    }

    /// 100 g, what you had last time, and the pack's own portion.
    private var portionOptions: [PortionOption] {
        let last = product.lastLoggedGrams
        func title(_ base: String, grams: Double) -> String {
            guard let last, abs(last - grams) < 0.05 else { return base }
            return "\(base), like last time"
        }
        var options: [PortionOption] = []
        if product.servingGrams.map({ abs($0 - 100) >= 0.05 }) ?? true {
            options.append(PortionOption(title: title("100 g", grams: 100), grams: 100))
        }
        if let last, abs(last - 100) >= 0.05, abs(last - (product.servingGrams ?? -1)) >= 0.05 {
            options.append(PortionOption(title: "\(last.amount) g, like last time", grams: last))
        }
        if let serving = product.servingGrams {
            options.append(PortionOption(title: title("\(product.servingName ?? "1 serving") · \(serving.amount) g", grams: serving), grams: serving))
        }
        return options
    }

    private func startTyping() {
        amountText = grams.inputText
        typingAmount = true
    }
}

/// The B4 gram dial: drag around the ring to change the amount, or tap the middle to type it.
struct GramDialView: View {
    @Binding var grams: Double
    var dial: GramDial
    var kcal: Double
    var macros: String
    var onType: () -> Void

    @State private var lastAngle: Double?
    @State private var unsnapped = 0.0

    private let size: CGFloat = 200
    private let ring: CGFloat = 16

    var body: some View {
        let radius = (size - ring) / 2
        let handle = dial.angle(for: grams) * .pi / 180
        ZStack {
            Circle()
                .stroke(Ember.track, lineWidth: ring)
            Circle()
                .trim(from: 0, to: dial.fill(for: grams))
                .stroke(Ember.accent, lineWidth: ring)
                .rotationEffect(.degrees(-90))
            Button(action: onType) {
                VStack(spacing: 2) {
                    Text(verbatim: "\(grams.amount) g")
                        .font(Ember.serif(46, relativeTo: .largeTitle))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(verbatim: "\(kcal.wholeNumber) kcal")
                        .font(Ember.sans(15))
                        .foregroundStyle(Ember.secondaryText)
                    Text(verbatim: macros)
                        .font(Ember.sans(12, relativeTo: .caption))
                        .foregroundStyle(Ember.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: size - 2 * ring - 12, height: size - 2 * ring - 12)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            Circle()
                .fill(Ember.text)
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Ember.background, lineWidth: 4))
                .offset(x: radius * sin(handle), y: -radius * cos(handle))
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let angle = GramDial.angle(
                        of: (x: Double(value.location.x), y: Double(value.location.y)),
                        around: (x: Double(size / 2), y: Double(size / 2))
                    )
                    if let lastAngle {
                        unsnapped = max(0, unsnapped + dial.grams(turningFrom: lastAngle, to: angle))
                        grams = dial.snapped(unsnapped)
                    } else {
                        unsnapped = grams
                    }
                    lastAngle = angle
                }
                .onEnded { _ in
                    lastAngle = nil
                }
        )
        .sensoryFeedback(.selection, trigger: grams)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Amount")
        .accessibilityValue("\(grams.amount) grams, \(kcal.wholeNumber) kcal")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: grams = dial.snapped(grams + dial.step)
            case .decrement: grams = dial.snapped(grams - dial.step)
            @unknown default: break
            }
        }
        .accessibilityAction(named: "Type an amount", onType)
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

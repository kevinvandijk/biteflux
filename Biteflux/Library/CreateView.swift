import BitefluxCore
import SwiftUI

/// What a new product starts with: whatever a barcode lookup or a label photo already gave.
struct ProductDraft: Hashable {
    var barcode = ""
    var name = ""
    var brand = ""
    var servingName = ""
    var servingGrams = ""
    // Per 100 g, as typed or as read from the label.
    var energy = ""
    var protein = ""
    var carbohydrates = ""
    var sugar = ""
    var fat = ""
    var saturatedFat = ""
    var fiber = ""
    var salt = ""
    /// Values the model could only partly read from the photo, highlighted for a check.
    var unsure: Set<LabelReader.Field> = []
    /// Why the form opened, shown above it.
    var note: String?

    init(barcode: String? = nil, note: String? = nil) {
        self.barcode = barcode ?? ""
        self.note = note
    }

    init(found: OpenFoodFacts.Product, note: String) {
        self.barcode = found.barcode
        self.name = found.name ?? ""
        self.brand = found.brand ?? ""
        self.servingName = found.servingName ?? ""
        self.servingGrams = found.servingGrams?.inputText ?? ""
        self.note = note
    }

    init(reading: LabelReader.Reading) {
        self.name = reading.name ?? ""
        self.brand = reading.brand ?? ""
        self.servingName = reading.servingName ?? ""
        self.servingGrams = reading.servingGrams?.inputText ?? ""
        self.energy = reading.energyKcal?.inputText ?? ""
        self.protein = reading.proteinG?.inputText ?? ""
        self.carbohydrates = reading.carbohydratesG?.inputText ?? ""
        self.sugar = reading.sugarG?.inputText ?? ""
        self.fat = reading.fatG?.inputText ?? ""
        self.saturatedFat = reading.saturatedFatG?.inputText ?? ""
        self.fiber = reading.fiberG?.inputText ?? ""
        self.salt = reading.saltG?.inputText ?? ""
        self.unsure = reading.unsure

        var note = reading.unsure.isEmpty
            ? "GPT Luna 6 read these values from your photo. Check them against the label before you save."
            : "GPT Luna 6 read these values from your photo. The highlighted ones were hard to read, so check them against the label."
        if reading.fromPortion, let grams = reading.servingGrams {
            note += " The label only lists values per portion of \(grams.amount) g, so these are worked out per 100 g."
        }
        if reading.perMillilitre {
            note += " The label gives values per 100 ml, which Biteflux uses as per 100 g."
        }
        if [reading.energyKcal, reading.proteinG, reading.carbohydratesG, reading.fatG].contains(where: { $0 == nil }) {
            note += " Add what the photo didn't show."
        }
        self.note = note
    }
}

/// The B4 Create screen: a new product from its label, checked, saved to your library and
/// logged in one go.
struct CreateView: View {
    /// What you ate of the new product, when you log it right away.
    struct Portion {
        var grams: Double
        var meal: Meal
    }

    var onSave: (Product, Portion?) -> Void

    @State private var draft: ProductDraft
    @State private var problem: String?
    /// Empty means one pack portion, or 100 g when the pack names none.
    @State private var eatenText = ""
    @State private var meal = Meal.suggested(at: .now)
    @State private var changingPortion = false
    @State private var editingField = LabelReader.Field.energy
    @State private var editingValue = false
    @State private var editText = ""

    init(draft: ProductDraft, onSave: @escaping (Product, Portion?) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: draft.note == nil ? "Add a product from its label" : "This one isn't in your library yet.")
                        .font(Ember.serif(30, relativeTo: .title))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: draft.note ?? "Copy the values per 100 g from the pack. Energy, protein, carbohydrates and fat are needed.")
                        .font(Ember.sans(15))
                        .foregroundStyle(Ember.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 4)
                PillField(caption: "Name", text: $draft.name, prompt: "Like Volkoren biscuit")
                PillField(caption: "Brand", text: $draft.brand, prompt: "Optional")
                PillField(caption: "Barcode", text: $draft.barcode, prompt: "Optional", keyboard: .numberPad)
                if let field = checkField {
                    checkCard(field)
                }
                Text("Per 100 g")
                    .font(Ember.sans(13, weight: .bold, relativeTo: .footnote))
                    .foregroundStyle(Ember.secondaryText)
                    .padding(.top, 4)
                FlowLayout(spacing: 8) {
                    ForEach(LabelReader.Field.shownOrder, id: \.self) { field in
                        valueChip(field)
                    }
                }
                portionLine
                if changingPortion {
                    portionEditor
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Ember.background)
        .foregroundStyle(Ember.text)
        .navigationTitle("New product")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomBar {
                if let problem {
                    Text(verbatim: problem)
                        .font(Ember.sans(14))
                        .foregroundStyle(Ember.failed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PrimaryButton(title: "Save and log it") {
                    save(logging: true)
                }
                Button {
                    save(logging: false)
                } label: {
                    Text("Only add it to your library")
                        .font(Ember.sans(14))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ember.secondaryText)
            }
        }
        .alert("\(editingField.title) per 100 g", isPresented: $editingValue) {
            TextField(editingField.unit, text: $editText)
                .keyboardType(.decimalPad)
            Button("Done", action: finishEditing)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("As the label lists it, in \(editingField.unit). Leave it empty if the label doesn't list it.")
        }
    }

    // MARK: Values

    /// The first value the model found hard to read, for the check card.
    private var checkField: LabelReader.Field? {
        LabelReader.Field.shownOrder.first { field in
            draft.unsure.contains(field) && !draft[keyPath: field.keyPath].isEmpty
        }
    }

    private func checkCard(_ field: LabelReader.Field) -> some View {
        let value = "\(draft[keyPath: field.keyPath]) \(field.unit)"
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: field.question(value))
                    .font(Ember.sans(17, weight: .bold, relativeTo: .headline))
                Text("That part of the label was hard to read.")
                    .font(Ember.sans(14))
                    .foregroundStyle(Ember.secondaryText)
            }
            HStack(spacing: 8) {
                Button {
                    draft.unsure.remove(field)
                } label: {
                    Text(verbatim: "Yes, \(value)")
                        .font(Ember.sans(14, weight: .bold, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ember.onAccent)
                .background(Ember.pending, in: Capsule())
                Button {
                    startEditing(field)
                } label: {
                    Text("Change it")
                        .font(Ember.sans(14, weight: .medium, relativeTo: .subheadline))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background(Ember.track, in: Capsule())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.pending.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Ember.pending.opacity(0.6)))
    }

    /// A value from the label as a chip: tap it to change it. One that was hard to read has a
    /// yellow outline until you've checked it.
    private func valueChip(_ field: LabelReader.Field) -> some View {
        let text = draft[keyPath: field.keyPath].trimmingCharacters(in: .whitespaces)
        let unsure = draft.unsure.contains(field)
        return Button {
            startEditing(field)
        } label: {
            Text(verbatim: field.chipText(text))
                .font(Ember.sans(14, weight: text.isEmpty ? .regular : .medium, relativeTo: .subheadline))
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(text.isEmpty ? (field.isNeeded ? Ember.accent : Ember.secondaryText) : Ember.text)
        .background(Ember.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(unsure ? Ember.pending : .clear, lineWidth: 2))
        .accessibilityHint(unsure ? "Hard to read on the label. Check it." : "Change it")
    }

    private func startEditing(_ field: LabelReader.Field) {
        editingField = field
        editText = draft[keyPath: field.keyPath]
        editingValue = true
    }

    private func finishEditing() {
        draft[keyPath: editingField.keyPath] = editText.trimmingCharacters(in: .whitespaces)
        draft.unsure.remove(editingField)
        problem = nil
    }

    // MARK: Portion

    private var servingGrams: Double? {
        DecimalInput.value(draft.servingGrams).flatMap { $0 > 0 ? $0 : nil }
    }

    private var eatenGrams: Double? {
        if eatenText.trimmingCharacters(in: .whitespaces).isEmpty {
            return servingGrams ?? 100
        }
        return DecimalInput.value(eatenText).flatMap { $0 > 0 ? $0 : nil }
    }

    /// "1 koek (25 g) to snacks, 101 kcal".
    private var portionText: String {
        guard let grams = eatenGrams else { return "Type the grams you ate" }
        let servingName = draft.servingName.trimmingCharacters(in: .whitespacesAndNewlines)
        var portion = "\(grams.amount) g"
        if let servingGrams, abs(grams - servingGrams) < 0.05, !servingName.isEmpty {
            portion = "\(servingName) (\(grams.amount) g)"
        }
        var text = "\(portion) to \(meal.title.lowercased())"
        if let energy = DecimalInput.value(draft.energy) {
            text += ", \((energy * grams / 100).wholeNumber) kcal"
        }
        return text
    }

    private var portionLine: some View {
        HStack(spacing: 12) {
            Text(verbatim: portionText)
                .font(Ember.sans(15, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button {
                withAnimation(.snappy) {
                    changingPortion.toggle()
                }
            } label: {
                Text(changingPortion ? "Done" : "Change")
                    .font(Ember.sans(14, weight: .bold, relativeTo: .subheadline))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(Ember.track, in: Capsule())
        }
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.top, 4)
    }

    private var portionEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            PillField(caption: "Grams you ate", text: $eatenText, prompt: (servingGrams ?? 100).inputText, keyboard: .decimalPad)
            MealPicker(meal: $meal)
            Text("One portion on the pack, for next time")
                .font(Ember.sans(13, weight: .bold, relativeTo: .footnote))
                .foregroundStyle(Ember.secondaryText)
                .padding(.top, 6)
            HStack(spacing: 8) {
                PillField(caption: "Name", text: $draft.servingName, prompt: "Like 1 koek")
                PillField(caption: "Weight in g", text: $draft.servingGrams, prompt: "Optional", keyboard: .decimalPad)
            }
        }
    }

    // MARK: Saving

    private func save(logging: Bool) {
        var unreadable: [String] = []
        func amount(_ text: String, _ name: String) -> Double? {
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            guard let value = DecimalInput.value(text) else {
                unreadable.append(name)
                return nil
            }
            return value
        }

        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let brand = draft.brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let energy = amount(draft.energy, "energy")
        let protein = amount(draft.protein, "protein")
        let carbohydrates = amount(draft.carbohydrates, "carbohydrates")
        let sugar = amount(draft.sugar, "sugars")
        let fat = amount(draft.fat, "fat")
        let saturatedFat = amount(draft.saturatedFat, "saturated fat")
        let fiber = amount(draft.fiber, "fiber")
        let salt = amount(draft.salt, "salt")
        let servingGrams = amount(draft.servingGrams, "portion weight")

        guard !name.isEmpty else {
            problem = "Give the product a name."
            return
        }
        guard unreadable.isEmpty else {
            problem = "Check the number for \(unreadable.joined(separator: ", "))."
            return
        }
        guard let energy, let protein, let carbohydrates, let fat else {
            problem = "Energy, protein, carbohydrates and fat are needed. Tap them to copy them from the label."
            return
        }
        var barcode: String?
        if !draft.barcode.trimmingCharacters(in: .whitespaces).isEmpty {
            guard let valid = Barcode.normalized(draft.barcode) else {
                problem = "That barcode isn't complete. Check the digits, or leave it empty."
                return
            }
            barcode = valid
        }
        var portion: Portion?
        if logging {
            guard let grams = eatenGrams else {
                problem = "Check the grams you ate."
                changingPortion = true
                return
            }
            portion = Portion(grams: grams, meal: meal)
        }
        let servingName = draft.servingName.trimmingCharacters(in: .whitespacesAndNewlines)

        onSave(Product(
            name: name,
            brand: brand.isEmpty ? nil : brand,
            barcode: barcode,
            source: .own,
            per100g: Nutrients(
                energyKcal: energy,
                proteinG: protein,
                carbohydratesG: carbohydrates,
                sugarG: sugar,
                fiberG: fiber,
                fatG: fat,
                saturatedFatG: saturatedFat,
                sodiumMg: salt.map(NutritionConversion.sodiumMilligrams(fromSaltGrams:))
            ),
            servingGrams: servingGrams.flatMap { $0 > 0 ? $0 : nil },
            servingName: servingGrams == nil || servingName.isEmpty ? nil : servingName
        ), portion)
    }
}

extension LabelReader.Field {
    /// The order the Create screen shows the values in, as most labels list them.
    static let shownOrder: [LabelReader.Field] = [.energy, .protein, .carbohydrates, .sugars, .fat, .saturatedFat, .fiber, .salt]

    var title: String {
        switch self {
        case .energy: "Energy"
        case .protein: "Protein"
        case .carbohydrates: "Carbohydrates"
        case .sugars: "Sugars"
        case .fat: "Fat"
        case .saturatedFat: "Saturated fat"
        case .fiber: "Fiber"
        case .salt: "Salt"
        }
    }

    var unit: String {
        self == .energy ? "kcal" : "g"
    }

    /// Energy, protein, carbohydrates and fat; a product can't be saved without them.
    var isNeeded: Bool {
        [.energy, .protein, .carbohydrates, .fat].contains(self)
    }

    var keyPath: WritableKeyPath<ProductDraft, String> {
        switch self {
        case .energy: \.energy
        case .protein: \.protein
        case .carbohydrates: \.carbohydrates
        case .sugars: \.sugar
        case .fat: \.fat
        case .saturatedFat: \.saturatedFat
        case .fiber: \.fiber
        case .salt: \.salt
        }
    }

    /// "402 kcal", "Protein 8.1 g", or "Add fiber" when there's no value yet.
    func chipText(_ value: String) -> String {
        if value.isEmpty {
            return "Add \(title.lowercased())"
        }
        return self == .energy ? "\(value) kcal" : "\(title) \(value) g"
    }

    /// "Is the fiber 4.2 g?"
    func question(_ value: String) -> String {
        let plural = self == .sugars || self == .carbohydrates
        return "\(plural ? "Are" : "Is") the \(title.lowercased()) \(value)?"
    }
}

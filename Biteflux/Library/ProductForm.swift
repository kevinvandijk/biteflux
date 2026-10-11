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
    /// Values Claude could only partly read from the photo, highlighted for a check.
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
            ? "Claude read these values from your photo. Check them against the label before you save."
            : "Claude read these values from your photo. The highlighted ones were hard to read, so check them against the label."
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

/// Adds a product to your library from its label, typed or read from a photo. Step 4 turns this
/// into the Create screen.
struct ProductForm: View {
    var onSave: (Product) -> Void

    @State private var draft: ProductDraft
    @State private var problem: String?

    init(draft: ProductDraft, onSave: @escaping (Product) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            if let note = draft.note {
                Section {
                    Text(verbatim: note)
                        .foregroundStyle(Ember.secondaryText)
                }
                .listRowBackground(Ember.surface)
            }
            Section("Product") {
                TextField("Name", text: $draft.name)
                TextField("Brand (optional)", text: $draft.brand)
                TextField("Barcode (optional)", text: $draft.barcode)
                    .keyboardType(.numberPad)
            }
            .listRowBackground(Ember.surface)
            Section {
                amountField("Energy", unit: "kcal", text: $draft.energy, field: .energy)
                amountField("Protein", unit: "g", text: $draft.protein, field: .protein)
                amountField("Carbohydrates", unit: "g", text: $draft.carbohydrates, field: .carbohydrates)
                amountField("of which sugars", unit: "g", text: $draft.sugar, field: .sugars)
                amountField("Fat", unit: "g", text: $draft.fat, field: .fat)
                amountField("of which saturated", unit: "g", text: $draft.saturatedFat, field: .saturatedFat)
                amountField("Fiber", unit: "g", text: $draft.fiber, field: .fiber)
                amountField("Salt", unit: "g", text: $draft.salt, field: .salt)
            } header: {
                Text("Per 100 g, from the label")
            } footer: {
                Text("Energy, protein, carbohydrates and fat are needed; leave out what the label doesn't list. Salt is saved to Apple Health as sodium.")
            }
            .listRowBackground(Ember.surface)
            Section {
                TextField("Name, like 1 koek", text: $draft.servingName)
                amountField("Weight", unit: "g", text: $draft.servingGrams)
            } header: {
                Text("One serving (optional)")
            }
            .listRowBackground(Ember.surface)
            if let problem {
                Section {
                    Text(verbatim: problem)
                        .foregroundStyle(Ember.failed)
                }
                .listRowBackground(Ember.surface)
            }
            Section {
                Button("Save product", action: save)
                    .font(Ember.sans(16, weight: .bold))
                    .foregroundStyle(Ember.accent)
            }
            .listRowBackground(Ember.surface)
        }
        .font(Ember.sans(16))
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Ember.background)
        .navigationTitle("New product")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A number row. A value Claude found hard to read shows in the accent colour until it's changed.
    private func amountField(_ name: String, unit: String, text: Binding<String>, field: LabelReader.Field? = nil) -> some View {
        let unsure = field.map { draft.unsure.contains($0) } ?? false
        return HStack {
            Text(verbatim: name)
            if unsure {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(Ember.accent)
                    .accessibilityLabel("Hard to read, check it")
            }
            TextField("–", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(unsure ? Ember.accent : Ember.text)
                .accessibilityLabel(name)
            Text(verbatim: unit)
                .foregroundStyle(Ember.secondaryText)
        }
        .onChange(of: text.wrappedValue) {
            if let field {
                draft.unsure.remove(field)
            }
        }
    }

    private func save() {
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
        let servingGrams = amount(draft.servingGrams, "serving weight")

        guard !name.isEmpty else {
            problem = "Give the product a name."
            return
        }
        guard unreadable.isEmpty else {
            problem = "Check the number for \(unreadable.joined(separator: ", "))."
            return
        }
        guard let energy, let protein, let carbohydrates, let fat else {
            problem = "Energy, protein, carbohydrates and fat are needed. Copy them from the label."
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
        ))
    }
}

import BitefluxCore
import SwiftUI

/// What a new product starts with: whatever a barcode lookup already knew.
struct ProductDraft: Hashable {
    var barcode = ""
    var name = ""
    var brand = ""
    var servingName = ""
    var servingGrams = ""
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
}

/// Adds a product to your library by copying its label. Step 4 turns this into the Create screen,
/// with the values read from a photo of the label.
struct ProductForm: View {
    var onSave: (Product) -> Void

    @State private var draft: ProductDraft
    @State private var energy = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var sugar = ""
    @State private var fat = ""
    @State private var saturatedFat = ""
    @State private var fiber = ""
    @State private var salt = ""
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
                amountField("Energy", unit: "kcal", text: $energy)
                amountField("Protein", unit: "g", text: $protein)
                amountField("Carbohydrates", unit: "g", text: $carbohydrates)
                amountField("of which sugars", unit: "g", text: $sugar)
                amountField("Fat", unit: "g", text: $fat)
                amountField("of which saturated", unit: "g", text: $saturatedFat)
                amountField("Fiber", unit: "g", text: $fiber)
                amountField("Salt", unit: "g", text: $salt)
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

    private func amountField(_ name: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(verbatim: name)
            TextField("–", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel(name)
            Text(verbatim: unit)
                .foregroundStyle(Ember.secondaryText)
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
        let energy = amount(self.energy, "energy")
        let protein = amount(self.protein, "protein")
        let carbohydrates = amount(self.carbohydrates, "carbohydrates")
        let sugar = amount(self.sugar, "sugars")
        let fat = amount(self.fat, "fat")
        let saturatedFat = amount(self.saturatedFat, "saturated fat")
        let fiber = amount(self.fiber, "fiber")
        let salt = amount(self.salt, "salt")
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

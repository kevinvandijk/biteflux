import BitefluxCore
import SwiftUI

/// One logged food: change how much you ate, the meal or the time, or delete it. Apple Health
/// gets the same change.
struct EntrySheet: View {
    var entry: FoodEntry
    /// The library product it was logged from, if it's still there; it names the portion.
    var product: Product?
    var onSave: (EntryChange) -> Void
    var onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var change: EntryChange
    @State private var typingAmount = false
    @State private var amountText = ""
    @State private var confirmingDelete = false

    init(entry: FoodEntry, product: Product?, onSave: @escaping (EntryChange) -> Void, onDelete: @escaping () -> Void) {
        self.entry = entry
        self.product = product
        self.onSave = onSave
        self.onDelete = onDelete
        _change = State(initialValue: entry.currentValues)
    }

    /// The entry's values for the amount on the dial.
    private var nutrients: Nutrients {
        entry.nutrients.rescaled(fromPortionOf: entry.grams, to: change.grams) ?? entry.nutrients
    }

    private var changed: Bool {
        let original = entry.currentValues
        return abs(change.grams - original.grams) >= 0.05 || change.meal != original.meal || change.eatenAt != original.eatenAt
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: entry.name)
                            .font(Ember.serif(32, relativeTo: .largeTitle))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if let brand = entry.brand {
                            Text(verbatim: brand)
                                .font(Ember.sans(14))
                                .foregroundStyle(Ember.secondaryText)
                        }
                    }
                    if entry.grams > 0 {
                        GramDialView(
                            grams: $change.grams,
                            dial: GramDial(servingGrams: product?.servingGrams ?? entry.grams),
                            kcal: nutrients.energyKcal,
                            macros: "P \(nutrients.proteinG.amount) · C \(nutrients.carbohydratesG.amount) · F \(nutrients.fatG.amount)",
                            onType: startTyping
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    } else {
                        Text(verbatim: "\(entry.energyKcal.wholeNumber) kcal. This entry has no weight, so only its meal and time can change.")
                            .font(Ember.sans(15))
                            .foregroundStyle(Ember.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    MealPicker(meal: $change.meal)
                    DatePicker("Eaten at", selection: $change.eatenAt, displayedComponents: [.date, .hourAndMinute])
                        .font(Ember.sans(15))
                        .padding(.leading, 18)
                        .padding(.trailing, 8)
                        .frame(minHeight: 54)
                        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    Text(verbatim: healthNote)
                        .font(Ember.sans(13, relativeTo: .footnote))
                        .foregroundStyle(entry.syncState == .failed ? Ember.failed : Ember.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .background(Ember.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                BottomBar {
                    PrimaryButton(title: "Save changes", enabled: changed) {
                        onSave(change)
                        dismiss()
                    }
                    Button {
                        confirmingDelete = true
                    } label: {
                        Text("Delete this entry")
                            .font(Ember.sans(14, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Ember.failed)
                }
            }
        }
        .foregroundStyle(Ember.text)
        .presentationBackground(Ember.background)
        .alert("How many grams?", isPresented: $typingAmount) {
            TextField("Grams", text: $amountText)
                .keyboardType(.decimalPad)
            Button("Done") {
                if let value = DecimalInput.value(amountText), value > 0 {
                    change.grams = value
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete \(entry.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("It's removed from Apple Health too.")
        }
    }

    private var healthNote: String {
        switch entry.syncState {
        case .inHealth:
            return "In Apple Health. A change replaces it there too."
        case .waiting:
            return "On its way to Apple Health. A change goes there too."
        case .failed:
            return "Not in Apple Health yet. \(entry.syncProblem ?? "")"
        }
    }

    private func startTyping() {
        amountText = change.grams.inputText
        typingAmount = true
    }
}

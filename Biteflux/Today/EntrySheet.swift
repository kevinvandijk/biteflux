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
    /// Saves the entry from this device, when the device that was meant to save it is gone.
    var onTakeOver: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(EntryLogger.self) private var logger
    @State private var change: EntryChange
    @State private var typingAmount = false
    @State private var amountText = ""
    @State private var confirmingDelete = false
    @State private var confirmingTakeOver = false

    init(
        entry: FoodEntry,
        product: Product?,
        onSave: @escaping (EntryChange) -> Void,
        onDelete: @escaping () -> Void,
        onTakeOver: @escaping () -> Void
    ) {
        self.entry = entry
        self.product = product
        self.onSave = onSave
        self.onDelete = onDelete
        self.onTakeOver = onTakeOver
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
                    if logger.canTakeOver(entry) {
                        Button {
                            confirmingTakeOver = true
                        } label: {
                            Text("Save it from this iPhone")
                                .font(Ember.sans(14, weight: .bold, relativeTo: .subheadline))
                                .padding(.horizontal, 20)
                                .frame(minHeight: 44)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .background(Ember.track, in: Capsule())
                    }
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
            Text(verbatim: logger.leavesToOtherDevice(entry)
                ? "It's removed from Apple Health too, the next time Biteflux is open on the device that saved it."
                : "It's removed from Apple Health too.")
        }
        .confirmationDialog("Save it from this iPhone?", isPresented: $confirmingTakeOver, titleVisibility: .visible) {
            Button("Save it from this iPhone") {
                onTakeOver()
                dismiss()
            }
        } message: {
            Text("Do this only if the other device is gone, like an old phone. If it's still in use and saves this food too, Apple Health counts it twice.")
        }
    }

    private var healthNote: String {
        if logger.leavesToOtherDevice(entry) {
            return entry.syncState == .inHealth
                ? "In Apple Health. Another of your devices saved it there, so a change goes there the next time Biteflux is open on that device."
                : "Another of your devices saves this to Apple Health, the next time Biteflux is open on it. If that device is gone, this iPhone can take over a day after it last tried."
        }
        if logger.canTakeOver(entry) {
            return "Another of your devices was saving this to Apple Health, but hasn't tried for over a day."
        }
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

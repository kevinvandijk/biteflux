import BitefluxCore
import SwiftUI

/// One meal on the Today screen: its total, its Apple Health status and its entries.
struct MealCard: View {
    var meal: Meal
    var entries: [FoodEntry]
    var onDelete: (FoodEntry) -> Void

    private var totalKcal: Double {
        entries.reduce(0) { $0 + $1.energyKcal }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "\(meal.title) · \(totalKcal.wholeNumber)")
                    .font(Ember.sans(16, weight: .bold, relativeTo: .headline))
                Spacer(minLength: 12)
                MealStatus(states: entries.map(\.syncState))
            }
            ForEach(entries) { entry in
                EntryRow(entry: entry)
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            onDelete(entry)
                        }
                    }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// The meal's status in plain words, as in the design.
private struct MealStatus: View {
    var states: [SyncState]

    var body: some View {
        if states.contains(.failed) {
            Text("Not all in Apple Health")
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.failed)
        } else if states.contains(.waiting) {
            Text("Saving to Apple Health")
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.pending)
        } else {
            Label("In Apple Health", systemImage: "checkmark")
                .labelStyle(StatusLabelStyle())
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.confirmed)
        }
    }
}

private struct StatusLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

/// One food in a meal, with a note when Apple Health doesn't have it yet.
private struct EntryRow: View {
    var entry: FoodEntry

    private var label: String {
        entry.portion.isEmpty ? entry.name : "\(entry.name), \(entry.portion)"
    }

    private var note: Text {
        switch entry.syncState {
        case .inHealth: Text(verbatim: "")
        case .waiting: Text(verbatim: " · saving").foregroundColor(Ember.pending)
        case .failed: Text(verbatim: " · not in Health").foregroundColor(Ember.failed)
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(Text(verbatim: label))\(note)")
            Spacer(minLength: 12)
            Text(verbatim: entry.energyKcal.wholeNumber)
        }
        .font(Ember.sans(14, relativeTo: .subheadline))
        .foregroundStyle(Ember.rowText)
        .accessibilityElement(children: .combine)
    }
}

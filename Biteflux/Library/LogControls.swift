import BitefluxCore
import SwiftUI

/// The four meals as B4 chips: the chosen one filled, the others on the card colour.
struct MealPicker: View {
    @Binding var meal: Meal

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(Meal.allCases) { option in
                let chosen = option == meal
                Button {
                    meal = option
                } label: {
                    Text(verbatim: option.title)
                        .font(Ember.sans(14, weight: chosen ? .bold : .regular, relativeTo: .subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(chosen ? Ember.onAccent : Ember.text)
                .background(chosen ? Ember.text : Ember.surface, in: Capsule())
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
    }
}

/// A rounded chip button, outlined in the accent colour when it's the current choice.
struct ChoiceChip: View {
    var title: String
    var chosen: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(Ember.sans(14, weight: chosen ? .medium : .regular, relativeTo: .subheadline))
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(Ember.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(chosen ? Ember.accent : .clear, lineWidth: 2))
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// A B4 text field: a small caption over the value, on a rounded card.
struct PillField: View {
    var caption: String
    @Binding var text: String
    var prompt: String = ""
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: caption)
                .font(Ember.sans(11, relativeTo: .caption2))
                .foregroundStyle(Ember.secondaryText)
            TextField(caption, text: $text, prompt: Text(verbatim: prompt).foregroundColor(Ember.secondaryText))
                .font(Ember.sans(16))
                .keyboardType(keyboard)
                .autocorrectionDisabled(keyboard != .default)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// The wide button at the bottom of Match and Create.
struct PrimaryButton: View {
    var title: String
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(Ember.sans(17, weight: .bold, relativeTo: .headline))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Ember.onAccent)
        .background(Ember.accent, in: Capsule())
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}

/// Keeps the bottom button above the content, on the screen's background.
struct BottomBar<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 8) {
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Ember.background)
    }
}

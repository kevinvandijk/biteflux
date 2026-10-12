import BitefluxCore
import SwiftUI

/// Sets the daily calorie goal the Today screen counts down from.
struct GoalSheet: View {
    @AppStorage("dailyGoalKcal") private var goalKcal = DailyGoal.standardKcal
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var started = false

    private var typed: Double? {
        DailyGoal.kcal(from: text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your daily goal")
                            .font(Ember.serif(32, relativeTo: .largeTitle))
                            .accessibilityAddTraits(.isHeader)
                        Text("Today counts down from this. It only changes the countdown; Apple Health keeps what you ate either way.")
                            .font(Ember.sans(15))
                            .foregroundStyle(Ember.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 4)
                    PillField(caption: "kcal per day", text: $text, prompt: goalKcal.inputText, keyboard: .numberPad)
                    FlowLayout(spacing: 8) {
                        ForEach(DailyGoal.suggestions, id: \.self) { kcal in
                            ChoiceChip(title: "\(kcal.wholeNumber) kcal", chosen: typed == kcal) {
                                text = kcal.inputText
                            }
                        }
                    }
                    if !text.isEmpty && typed == nil {
                        Text(verbatim: "Pick a goal between \(DailyGoal.range.lowerBound.wholeNumber) and \(DailyGoal.range.upperBound.wholeNumber) kcal.")
                            .font(Ember.sans(14))
                            .foregroundStyle(Ember.failed)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .background(Ember.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                BottomBar {
                    PrimaryButton(title: "Save goal", enabled: typed != nil) {
                        if let typed {
                            goalKcal = typed
                        }
                        dismiss()
                    }
                }
            }
        }
        .foregroundStyle(Ember.text)
        .presentationBackground(Ember.background)
        .onAppear {
            if !started {
                started = true
                text = goalKcal.inputText
            }
        }
    }
}

#Preview {
    GoalSheet()
        .preferredColorScheme(.dark)
}

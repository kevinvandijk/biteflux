import BitefluxCore
import SwiftData
import SwiftUI

/// Today's calories left, each meal with its Apple Health status, and the scan button.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(EntryLogger.self) private var logger
    @Query(sort: \FoodEntry.eatenAt) private var entries: [FoodEntry]
    @AppStorage("dailyGoalKcal") private var goalKcal = 2300.0
    @State private var choosingSample = false

    private var today: [FoodEntry] {
        entries.filter { Calendar.current.isDateInToday($0.eatenAt) }
    }

    private var summary: DaySummary {
        DaySummary(goalKcal: goalKcal, eaten: today.map(\.nutrients))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Ember.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    headline
                    healthBanner
                    if today.isEmpty {
                        emptyDay
                    } else {
                        ForEach(Meal.allCases) { meal in
                            let mealEntries = today.filter { $0.meal == meal }
                            if !mealEntries.isEmpty {
                                MealCard(meal: meal, entries: mealEntries, onDelete: delete)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }

            scanButton
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .foregroundStyle(Ember.text)
        .sheet(isPresented: $choosingSample) {
            SampleFoodSheet(onPick: log)
        }
    }

    private var header: some View {
        Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
            .font(Ember.sans(14, relativeTo: .subheadline))
            .foregroundStyle(Ember.secondaryText)
            .frame(minHeight: 44, alignment: .leading)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            headlineText
                .font(Ember.serif(34))
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: summaryLine)
                .font(Ember.sans(13, relativeTo: .footnote))
                .foregroundStyle(Ember.secondaryText)
            ProgressBar(progress: summary.progress)
        }
    }

    private var headlineText: Text {
        let remaining = summary.remainingKcal
        if remaining.rounded() >= 0 {
            let amount = Text(verbatim: remaining.wholeNumber).foregroundColor(Ember.accent)
            return Text("You've got \(amount) kcal left.")
        } else {
            let amount = Text(verbatim: (-remaining).wholeNumber).foregroundColor(Ember.accent)
            return Text("You're \(amount) kcal over.")
        }
    }

    private var summaryLine: String {
        let eaten = summary.eaten
        return "\(eaten.energyKcal.wholeNumber) eaten of \(goalKcal.wholeNumber) · "
            + "protein \(eaten.proteinG.wholeNumber) g · carbs \(eaten.carbohydratesG.wholeNumber) g · fat \(eaten.fatG.wholeNumber) g"
    }

    @ViewBuilder
    private var healthBanner: some View {
        let failed = today.filter { $0.syncState == .failed }
        if logger.access == .unavailable {
            HealthBanner(
                title: "Apple Health isn't available here.",
                message: "Your food stays in Biteflux."
            )
        } else if logger.access == .denied {
            HealthBanner(
                title: "Biteflux can't save to Apple Health.",
                message: "Turn on every nutrition type for Biteflux in Settings, Privacy & Security, Health, then come back."
            )
        } else if let first = failed.first {
            HealthBanner(
                title: failed.count == 1
                    ? "\(first.name) didn't make it to Apple Health."
                    : "\(failed.count) foods didn't make it to Apple Health.",
                message: first.syncProblem ?? "",
                actionTitle: "Try again",
                action: retry
            )
        } else if logger.access == .notAsked && !today.isEmpty {
            HealthBanner(
                title: "Apple Health is waiting.",
                message: "Allow Biteflux to save nutrition so today's food gets there.",
                actionTitle: "Allow Apple Health",
                action: allowHealth
            )
        }
    }

    private var emptyDay: some View {
        Text("Nothing logged yet today.")
            .font(Ember.sans(15))
            .foregroundStyle(Ember.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var scanButton: some View {
        Button {
            choosingSample = true
        } label: {
            Label("Scan something", systemImage: "viewfinder")
                .font(Ember.sans(17, weight: .bold, relativeTo: .headline))
                .frame(maxWidth: .infinity, minHeight: 60)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Ember.onAccent)
        .background(Ember.text, in: Capsule())
    }

    private func log(_ food: SampleFood) {
        let now = Date.now
        let entry = FoodEntry(
            name: food.name,
            brand: food.brand,
            portion: food.portion,
            grams: food.grams,
            meal: Meal.suggested(at: now),
            eatenAt: now,
            nutrients: food.nutrients
        )
        Task { await logger.log(entry, in: context) }
    }

    private func delete(_ entry: FoodEntry) {
        Task { await logger.delete(entry, in: context) }
    }

    private func retry() {
        Task { await logger.syncUnconfirmed(in: context) }
    }

    private func allowHealth() {
        Task {
            await logger.requestAccess()
            await logger.syncUnconfirmed(in: context)
        }
    }
}

private struct ProgressBar: View {
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Ember.track)
                Capsule().fill(Ember.accent).frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("Eaten today")
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }
}

#Preview {
    TodayView()
        .environment(EntryLogger())
        .modelContainer(PreviewData.container())
}

import BitefluxCore
import SwiftData
import SwiftUI

/// Today's calories left, each meal with its Apple Health status, and the scan button.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(EntryLogger.self) private var logger
    /// Food deleted here that another device still has to remove from Apple Health stays hidden.
    @Query(filter: #Predicate<FoodEntry> { $0.deletedAt == nil }, sort: \FoodEntry.eatenAt)
    private var entries: [FoodEntry]
    /// Those hidden deletions, which may still have to leave Apple Health.
    @Query(filter: #Predicate<FoodEntry> { $0.deletedAt != nil }) private var deletions: [FoodEntry]
    @Query private var products: [Product]
    @AppStorage("dailyGoalKcal") private var goalKcal = DailyGoal.standardKcal
    @State private var scanning = false
    /// What the Scan screen found, opened in the library once the camera has closed.
    @State private var afterScan: AddFoodRequest?
    @State private var addFood: AddFoodRequest?
    @State private var editing: FoodEntry?
    @State private var settingGoal = false
    @State private var showingSettings = false
    @State private var launched = false

    private var today: [FoodEntry] {
        entries.filter { Calendar.current.isDateInToday($0.eatenAt) }
    }

    /// A deletion this device may remove from Apple Health: its own, or one whose writer went quiet.
    private var hasDeletionToClear: Bool {
        deletions.contains { !logger.leavesToOtherDevice($0) }
    }

    private var summary: DaySummary {
        DaySummary(goalKcal: goalKcal, eaten: today.map(\.nutrients))
    }

    var body: some View {
        NavigationStack {
            dayScreen
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: $showingSettings) {
                    // Once Settings has gone, ask for anything that came up while it was open, as
                    // a sheet's onDismiss does. Its disappearance comes after the way back has
                    // finished, when Apple's permission sheet can show.
                    SettingsView()
                        .onDisappear(perform: askForHealthIfNeeded)
                }
        }
    }

    private var dayScreen: some View {
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
                                MealCard(meal: meal, entries: mealEntries, onEdit: { editing = $0 }, onDelete: delete)
                            }
                        }
                        nevoCredit
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
        .task {
            // Only at launch: when Today reappears later, a sheet may be on its way in.
            if !launched {
                launched = true
                askForHealthIfNeeded()
            }
        }
        .onChange(of: hasDeletionToClear) { _, has in
            // iCloud can bring in a deletion after Today has appeared, with no launch or closing
            // sheet to act on it. Only deletions are watched: a food you log changes `entries` while
            // the Add food sheet is still closing, when Apple's permission sheet can't show. A
            // deletion made here never starts this, as it always waits for another device.
            guard has else { return }
            logger.refreshAccess()
            if logger.access == .allowed {
                retry()
            } else {
                askForHealthIfNeeded()
            }
        }
        .fullScreenCover(isPresented: $scanning, onDismiss: afterScanning) {
            ScanView(remainingKcal: summary.remainingKcal) { start in
                afterScan = AddFoodRequest(start: start)
                scanning = false
            }
        }
        .sheet(item: $addFood, onDismiss: askForHealthIfNeeded) { request in
            AddFoodSheet(start: request.start, onLog: log)
        }
        .sheet(item: $editing, onDismiss: askForHealthIfNeeded) { entry in
            EntrySheet(
                entry: entry,
                product: products.first { $0.productID == entry.productID },
                onSave: { save($0, to: entry) },
                onDelete: { delete(entry) },
                onTakeOver: { takeOver(entry) }
            )
        }
        .sheet(isPresented: $settingGoal, onDismiss: askForHealthIfNeeded) {
            GoalSheet()
        }
    }

    private var header: some View {
        HStack {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(Ember.sans(14, relativeTo: .subheadline))
                .foregroundStyle(Ember.secondaryText)
            Spacer(minLength: 12)
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Ember.surface, in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(minHeight: 44)
    }

    /// Tap it to change the daily goal.
    private var headline: some View {
        Button {
            settingGoal = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                headlineText
                    .font(Ember.serif(34))
                    .multilineTextAlignment(.leading)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: summaryLine)
                    .font(Ember.sans(13, relativeTo: .footnote))
                    .foregroundStyle(Ember.secondaryText)
                    .multilineTextAlignment(.leading)
                ProgressBar(progress: summary.progress)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Change your daily goal")
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
        // Food another device saves is that device's to retry; its own screen says so.
        let failed = today.filter { $0.syncState == .failed && logger.writesHere($0) }
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

    /// RIVM asks for its source line wherever values worked out from NEVO are shown.
    @ViewBuilder
    private var nevoCredit: some View {
        let fromNEVO = today.filter { $0.productSource == .nevo }
        if !fromNEVO.isEmpty {
            Text(verbatim: (fromNEVO.count == today.count ? NEVO.attribution : NEVO.mixedAttribution) + ".")
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
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
            scanning = true
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

    private func log(_ entry: FoodEntry) {
        Task { await logger.log(entry, in: context) }
    }

    private func delete(_ entry: FoodEntry) {
        Task { await logger.delete(entry, in: context) }
    }

    /// Keeps the change, then replaces the entry in Apple Health.
    private func save(_ change: EntryChange, to entry: FoodEntry) {
        let product = products.first { $0.productID == entry.productID }
        Task { await logger.update(entry, in: context) { $0.apply(change, product: product) } }
    }

    /// Opens what the Scan screen found, or, when it found nothing, asks for Apple Health access if
    /// something came up while the camera was open.
    private func afterScanning() {
        addFood = afterScan
        afterScan = nil
        if addFood == nil {
            askForHealthIfNeeded()
        }
    }

    private func retry() {
        Task { await logger.syncUnconfirmed(in: context) }
    }

    /// Saves food here that another device was meant to save, once you've said that device is gone.
    private func takeOver(_ entry: FoodEntry) {
        Task { await logger.takeOver(entry, in: context) }
    }

    private func allowHealth() {
        Task {
            await logger.requestAccess()
            await logger.syncUnconfirmed(in: context)
        }
    }

    /// Asks for Apple Health access the first time food is waiting to go there, or a deleted food
    /// this device has to remove is waiting to leave it. Apple's permission sheet only shows once
    /// nothing else is on screen, so this runs at launch, after a sheet has closed and when iCloud
    /// brings in such a deletion, never while a sheet is opening or closing.
    private func askForHealthIfNeeded() {
        logger.refreshAccess()
        // Settings has sheets of its own that Today can't see, and its own button to allow access.
        guard logger.access == .notAsked, addFood == nil, editing == nil, !scanning, !settingGoal, !showingSettings,
              entries.contains(where: { $0.syncState != .inHealth }) || hasDeletionToClear else { return }
        allowHealth()
    }
}

private struct AddFoodRequest: Identifiable {
    let id = UUID()
    var start: AddFoodSheet.Start?
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

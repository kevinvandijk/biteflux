import BitefluxCore
import SwiftUI

/// The B4 Settings screen: Apple Health access, the daily goal, the OpenRouter key for reading
/// labels, and where the food data comes from.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(EntryLogger.self) private var logger
    @AppStorage("dailyGoalKcal") private var goalKcal = DailyGoal.standardKcal
    @State private var settingGoal = false
    @State private var addingKey = false
    @State private var confirmingKeyRemoval = false
    @State private var hasKey = APIKeyStore.key != nil
    @State private var hasNEVO = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings")
                    .font(Ember.serif(32, relativeTo: .largeTitle))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 4)
                healthCard
                goalRow
                keyCard
                dataCard
                sourcesCard
                Text(verbatim: versionText)
                    .font(Ember.sans(12, relativeTo: .caption))
                    .foregroundStyle(Ember.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(Ember.background)
        .foregroundStyle(Ember.text)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Ember.background, for: .navigationBar)
        .sheet(isPresented: $settingGoal) {
            GoalSheet()
        }
        .sheet(isPresented: $addingKey) {
            APIKeyForm {
                hasKey = APIKeyStore.key != nil
            }
        }
        .confirmationDialog("Remove the OpenRouter key?", isPresented: $confirmingKeyRemoval, titleVisibility: .visible) {
            Button("Remove key", role: .destructive) {
                APIKeyStore.remove()
                hasKey = APIKeyStore.key != nil
            }
        } message: {
            Text("Reading a label will ask for a key again.")
        }
        .task {
            logger.refreshAccess()
            hasNEVO = !(await NEVOTable.shared.foods()).isEmpty
        }
    }

    // MARK: Apple Health

    private var healthCard: some View {
        card {
            HStack(alignment: .firstTextBaseline) {
                Text("Apple Health")
                    .font(Ember.sans(16, weight: .bold, relativeTo: .headline))
                Spacer(minLength: 12)
                healthStatus
            }
            Text(verbatim: healthMessage)
                .font(Ember.sans(14))
                .foregroundStyle(Ember.rowText)
                .fixedSize(horizontal: false, vertical: true)
            if logger.access == .notAsked {
                smallButton("Allow Apple Health", filled: true) {
                    Task {
                        await logger.requestAccess()
                        await logger.syncUnconfirmed(in: context)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var healthStatus: some View {
        switch logger.access {
        case .allowed:
            Label("Allowed", systemImage: "checkmark")
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.confirmed)
        case .notAsked:
            Text("Not asked yet")
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.pending)
        case .denied:
            Text("Not allowed")
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.failed)
        case .unavailable:
            Text("Not on this device")
                .font(Ember.sans(12, relativeTo: .caption))
                .foregroundStyle(Ember.secondaryText)
        }
    }

    private var healthMessage: String {
        switch logger.access {
        case .allowed:
            "Every food you log is saved there with its nutrients, and changes and deletes follow."
        case .notAsked:
            "Allow Biteflux to save nutrition, so what you log gets there."
        case .denied:
            "Turn on every nutrition type for Biteflux in Settings, Privacy & Security, Health, then come back. Until then your food stays in Biteflux."
        case .unavailable:
            "This device has no Apple Health, so your food stays in Biteflux."
        }
    }

    // MARK: Daily goal

    private var goalRow: some View {
        Button {
            settingGoal = true
        } label: {
            HStack {
                Text("Daily goal")
                    .font(Ember.sans(16, weight: .bold, relativeTo: .headline))
                Spacer(minLength: 12)
                Text(verbatim: "\(goalKcal.wholeNumber) kcal")
                    .font(Ember.sans(15))
                    .foregroundStyle(Ember.rowText)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Ember.secondaryText)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Reading labels

    private var keyCard: some View {
        card {
            HStack(alignment: .firstTextBaseline) {
                Text("Reading labels")
                    .font(Ember.sans(16, weight: .bold, relativeTo: .headline))
                Spacer(minLength: 12)
                if hasKey {
                    Label("Key saved", systemImage: "checkmark")
                        .font(Ember.sans(12, relativeTo: .caption))
                        .foregroundStyle(Ember.confirmed)
                } else {
                    Text("No key yet")
                        .font(Ember.sans(12, relativeTo: .caption))
                        .foregroundStyle(Ember.secondaryText)
                }
            }
            Text("GPT Luna 6 reads label photos through OpenRouter, on your own key. The key stays in this iPhone's Keychain.")
                .font(Ember.sans(14))
                .foregroundStyle(Ember.rowText)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                smallButton(hasKey ? "Replace key" : "Add key", filled: !hasKey) {
                    addingKey = true
                }
                if hasKey {
                    smallButton("Remove", filled: false) {
                        confirmingKeyRemoval = true
                    }
                }
            }
        }
    }

    // MARK: Your data

    private var dataCard: some View {
        card {
            Text("Your data")
                .font(Ember.sans(16, weight: .bold, relativeTo: .headline))
            Text(verbatim: BitefluxApp.iCloudContainer == nil
                ? "Your food log and products stay on this iPhone. Apple Health keeps its own copy of what you ate."
                : "Your food log and products sync through your private iCloud. Apple Health keeps its own copy of what you ate.")
                .font(Ember.sans(14))
                .foregroundStyle(Ember.rowText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Sources

    private var sourcesCard: some View {
        card {
            Text("Where the food data comes from")
                .font(Ember.sans(16, weight: .bold, relativeTo: .headline))
            Text("Barcodes and product names are looked up on Open Food Facts, available under the Open Database License. Its values are added by anyone, so check them against the label.")
                .font(Ember.sans(14))
                .foregroundStyle(Ember.rowText)
                .fixedSize(horizontal: false, vertical: true)
            Link("Open Food Facts", destination: URL(string: "https://world.openfoodfacts.org")!)
                .font(Ember.sans(14, weight: .medium))
                .foregroundStyle(Ember.accent)
                .frame(minHeight: 44)
            if hasNEVO {
                Text(verbatim: "Unbranded foods come from the Dutch food table. \(NEVO.attribution).")
                    .font(Ember.sans(14))
                    .foregroundStyle(Ember.rowText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: Pieces

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Biteflux \(version) (\(build))"
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func smallButton(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .font(Ember.sans(14, weight: .bold, relativeTo: .subheadline))
                .padding(.horizontal, 20)
                .frame(minHeight: 44)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(filled ? Ember.onAccent : Ember.text)
        .background(filled ? Ember.accent : Ember.track, in: Capsule())
        .padding(.top, 4)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(EntryLogger())
    .modelContainer(PreviewData.container())
}

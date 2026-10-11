import BitefluxCore
import SwiftData
import SwiftUI

/// Your product library: look up a barcode on Open Food Facts, search what you've added and
/// the Dutch food table (NEVO), or add a product from its label, then log a portion.
/// Scanning arrives in step 3.
struct AddFoodSheet: View {
    var onLog: (FoodEntry) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var products: [Product]
    @State private var path: [Route] = []
    @State private var search = ""
    @State private var barcodeText = ""
    @State private var lookingUp = false
    @State private var lookupProblem: String?
    @State private var nevoFoods: [NEVO.Food] = []

    private let openFoodFacts = OpenFoodFactsClient()

    enum Route: Hashable {
        case product(Product)
        case newProduct(ProductDraft)
    }

    /// Products matching the search, the ones you logged most recently first.
    private var shown: [Product] {
        products
            .filter { SearchText.matches(search, in: [$0.name, $0.brand]) }
            .sorted { a, b in
                switch (a.lastLoggedAt, b.lastLoggedAt) {
                case let (aDate?, bDate?): aDate > bDate
                case (.some, nil): true
                case (nil, .some): false
                case (nil, nil): a.addedAt > b.addedAt
                }
            }
    }

    /// NEVO foods matching the search, leaving out the ones already listed from your library.
    private func nevoMatches(besides listed: [Product]) -> [NEVO.Food] {
        guard !search.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let listedCodes = Set(listed.filter { $0.source == .nevo }.compactMap(\.sourceCode))
        return NEVO.search(search, in: nevoFoods.filter { !listedCodes.contains($0.code) })
    }

    var body: some View {
        let shown = self.shown
        let nevoMatches = self.nevoMatches(besides: shown)
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add food")
                        .font(Ember.serif(30))
                        .accessibilityAddTraits(.isHeader)
                    barcodeCard
                    if !products.isEmpty || !nevoFoods.isEmpty {
                        searchField
                    }
                    if shown.isEmpty {
                        if nevoMatches.isEmpty {
                            emptyLibrary
                        }
                    } else {
                        if !nevoMatches.isEmpty {
                            sectionTitle("Your library")
                        }
                        ForEach(shown) { product in
                            row(product)
                        }
                    }
                    if !nevoMatches.isEmpty {
                        sectionTitle("Dutch food table (NEVO)")
                        ForEach(nevoMatches) { food in
                            nevoRow(food)
                        }
                        Text(verbatim: NEVO.attribution + ".")
                            .font(Ember.sans(12, relativeTo: .caption))
                            .foregroundStyle(Ember.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    newProductButton
                }
                .padding(20)
            }
            .task {
                nevoFoods = await NEVOTable.shared.foods()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Ember.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .product(product):
                    ProductView(product: product, onLog: log)
                case let .newProduct(draft):
                    ProductForm(draft: draft, onSave: saved)
                }
            }
        }
        .foregroundStyle(Ember.text)
        .presentationBackground(Ember.background)
    }

    private var barcodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Look up a barcode")
                .font(Ember.sans(15, weight: .bold, relativeTo: .headline))
            HStack(spacing: 10) {
                TextField("The number under the stripes", text: $barcodeText)
                    .keyboardType(.numberPad)
                    .font(Ember.sans(16))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Ember.track, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button(action: lookUp) {
                    ZStack {
                        Text("Look up").opacity(lookingUp ? 0 : 1)
                        if lookingUp {
                            ProgressView().tint(Ember.onAccent)
                        }
                    }
                    .font(Ember.sans(14, weight: .bold, relativeTo: .subheadline))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ember.onAccent)
                .background(Ember.accent, in: Capsule())
                .disabled(lookingUp || barcodeText.isEmpty)
            }
            if let lookupProblem {
                Text(verbatim: lookupProblem)
                    .font(Ember.sans(13, relativeTo: .footnote))
                    .foregroundStyle(Ember.failed)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var searchField: some View {
        TextField(searchPrompt, text: $search)
            .font(Ember.sans(16))
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Ember.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyLibrary: some View {
        Text(verbatim: emptyText)
            .font(Ember.sans(15))
            .foregroundStyle(Ember.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
    }

    private var searchPrompt: LocalizedStringKey {
        nevoFoods.isEmpty ? "Search your products" : "Search your products and NEVO"
    }

    private var emptyText: String {
        if products.isEmpty && search.trimmingCharacters(in: .whitespaces).isEmpty {
            return nevoFoods.isEmpty
                ? "Your library is empty. Look up a barcode or add a product from its label, and it stays here for next time."
                : "Your library is empty. Look up a barcode, search for a food, or add a product from its label. What you log stays here for next time."
        }
        return nevoFoods.isEmpty
            ? "Nothing in your library matches \u{201C}\(search)\u{201D}."
            : "Nothing in your library or NEVO matches \u{201C}\(search)\u{201D}."
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(verbatim: title)
            .font(Ember.sans(13, weight: .bold, relativeTo: .footnote))
            .foregroundStyle(Ember.secondaryText)
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)
    }

    private func row(_ product: Product) -> some View {
        Button {
            path.append(.product(product))
        } label: {
            rowLabel(
                name: product.name,
                detail: [product.brand, product.source == .nevo ? "NEVO" : nil, "per 100 g"],
                kcal: product.energyKcal
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from library", systemImage: "trash", role: .destructive) {
                remove(product)
            }
        }
    }

    /// A NEVO food opens like any product and joins your library when you log it.
    private func nevoRow(_ food: NEVO.Food) -> some View {
        Button {
            path.append(.product(Product(food)))
        } label: {
            rowLabel(name: food.dutchName, detail: [food.englishName, "per 100 g"], kcal: food.per100g.energyKcal)
        }
        .buttonStyle(.plain)
    }

    private func rowLabel(name: String, detail: [String?], kcal: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(Ember.sans(16, weight: .medium))
                Text(verbatim: detail.compactMap { $0 }.joined(separator: " · "))
                    .font(Ember.sans(13, relativeTo: .footnote))
                    .foregroundStyle(Ember.secondaryText)
            }
            Spacer(minLength: 12)
            Text(verbatim: "\(kcal.wholeNumber) kcal")
                .font(Ember.sans(15))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var newProductButton: some View {
        Button {
            path.append(.newProduct(ProductDraft()))
        } label: {
            Label("Add a product from its label", systemImage: "plus")
                .font(Ember.sans(15, weight: .bold, relativeTo: .subheadline))
                .frame(maxWidth: .infinity, minHeight: 50)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Ember.accent)
        .overlay(Capsule().strokeBorder(Ember.accent.opacity(0.5)))
        .padding(.top, 4)
    }

    /// Checks your library first, then asks Open Food Facts.
    private func lookUp() {
        guard !lookingUp else { return }
        guard let barcode = Barcode.normalized(barcodeText) else {
            lookupProblem = "That isn't a complete barcode. Check the digits under the stripes."
            return
        }
        lookupProblem = nil
        if let known = products.first(where: { $0.barcode == barcode }) {
            barcodeText = ""
            path.append(.product(known))
            return
        }

        lookingUp = true
        Task {
            defer { lookingUp = false }
            do {
                switch try await openFoodFacts.lookup(barcode: barcode) {
                case let .found(found):
                    if let product = Product(found) {
                        path.append(.product(product))
                    } else {
                        path.append(.newProduct(ProductDraft(
                            found: found,
                            note: "Open Food Facts knows this product but not all its nutrition. Copy the rest from the label."
                        )))
                    }
                case .notFound:
                    path.append(.newProduct(ProductDraft(
                        barcode: barcode,
                        note: "Open Food Facts doesn't know this barcode. Add the product from its label."
                    )))
                }
                barcodeText = ""
            } catch {
                lookupProblem = error.localizedDescription
            }
        }
    }

    /// A product from Open Food Facts or NEVO joins your library the first time you log it.
    private func log(_ product: Product, grams: Double, meal: Meal) {
        let kept = product.modelContext == nil ? keep(product) : product
        let now = Date.now
        kept.lastLoggedAt = now
        kept.timesLogged += 1
        onLog(kept.entry(grams: grams, meal: meal, eatenAt: now))
        dismiss()
    }

    private func saved(_ product: Product) {
        let kept = keep(product)
        try? context.save()
        path = [.product(kept)]
    }

    /// Adds a product to your library. When the library already has the same barcode or NEVO food,
    /// that product takes the new values instead, so a later search can't find two versions.
    private func keep(_ product: Product) -> Product {
        if let known = products.first(where: { $0.isSameFood(as: product) }) {
            known.takeValues(from: product)
            return known
        }
        context.insert(product)
        return product
    }

    /// Entries keep their own copy of the nutrients, so your log stays as it was.
    private func remove(_ product: Product) {
        context.delete(product)
        try? context.save()
    }
}

#Preview {
    AddFoodSheet(onLog: { _ in })
        .modelContainer(PreviewData.container())
        .preferredColorScheme(.dark)
}

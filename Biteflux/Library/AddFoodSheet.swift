import BitefluxCore
import SwiftData
import SwiftUI

/// Your product library: look up a barcode on Open Food Facts, search what you've added,
/// or add a product from its label, then log a portion. Scanning arrives in step 3.
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

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add food")
                        .font(Ember.serif(30))
                        .accessibilityAddTraits(.isHeader)
                    barcodeCard
                    if !products.isEmpty {
                        searchField
                    }
                    if shown.isEmpty {
                        emptyLibrary
                    } else {
                        ForEach(shown) { product in
                            row(product)
                        }
                    }
                    newProductButton
                }
                .padding(20)
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
        TextField("Search your products", text: $search)
            .font(Ember.sans(16))
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Ember.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var emptyLibrary: some View {
        Text(products.isEmpty
            ? "Your library is empty. Look up a barcode or add a product from its label, and it stays here for next time."
            : "Nothing in your library matches \u{201C}\(search)\u{201D}.")
            .font(Ember.sans(15))
            .foregroundStyle(Ember.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
    }

    private func row(_ product: Product) -> some View {
        Button {
            path.append(.product(product))
        } label: {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: product.name)
                        .font(Ember.sans(16, weight: .medium))
                    Text(verbatim: [product.brand, "per 100 g"].compactMap { $0 }.joined(separator: " · "))
                        .font(Ember.sans(13, relativeTo: .footnote))
                        .foregroundStyle(Ember.secondaryText)
                }
                Spacer(minLength: 12)
                Text(verbatim: "\(product.energyKcal.wholeNumber) kcal")
                    .font(Ember.sans(15))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ember.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Remove from library", systemImage: "trash", role: .destructive) {
                remove(product)
            }
        }
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

    /// A product from Open Food Facts joins your library the first time you log it.
    private func log(_ product: Product, grams: Double, meal: Meal) {
        if product.modelContext == nil {
            context.insert(product)
        }
        let now = Date.now
        product.lastLoggedAt = now
        product.timesLogged += 1
        onLog(product.entry(grams: grams, meal: meal, eatenAt: now))
        dismiss()
    }

    /// A barcode that is already in your library updates that product with what you just copied
    /// from the label, so a later lookup can't find two versions with different values.
    private func saved(_ product: Product) {
        var kept = product
        if let barcode = product.barcode, let known = products.first(where: { $0.barcode == barcode }) {
            known.takeValues(from: product)
            kept = known
        } else {
            context.insert(product)
        }
        try? context.save()
        path = [.product(kept)]
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

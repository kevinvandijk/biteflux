import SwiftUI

/// The warm alert card from the design, for food that isn't in Apple Health.
struct HealthBanner: View {
    var title: String
    var message: String
    var actionTitle: String?
    var action: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(Text(verbatim: title).font(Ember.sans(15, weight: .bold))) \(Text(verbatim: message))")
                .font(Ember.sans(15))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle {
                Button(action: action) {
                    Text(verbatim: actionTitle)
                        .font(Ember.sans(14, weight: .bold, relativeTo: .subheadline))
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Ember.onAccent)
                .background(Ember.accent, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ember.alertSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

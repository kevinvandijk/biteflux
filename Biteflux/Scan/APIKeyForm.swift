import SwiftUI

/// Asks for the Anthropic API key that label reading runs on.
struct APIKeyForm: View {
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Biteflux reads labels with Claude, Anthropic's AI model. Each photo costs a few cents or less on your own Anthropic account.")
                    Link("Get a key at console.anthropic.com", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                        .foregroundStyle(Ember.accent)
                }
                .listRowBackground(Ember.surface)
                Section {
                    SecureField("sk-ant-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("API key")
                } footer: {
                    Text("The key stays in this iPhone's Keychain and is only sent to Anthropic, with a label photo.")
                }
                .listRowBackground(Ember.surface)
                if let problem {
                    Section {
                        Text(verbatim: problem)
                            .foregroundStyle(Ember.failed)
                    }
                    .listRowBackground(Ember.surface)
                }
            }
            .font(Ember.sans(16))
            .foregroundStyle(Ember.text)
            .scrollContentBackground(.hidden)
            .background(Ember.background)
            .navigationTitle("Read labels with Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationBackground(Ember.background)
    }

    private func save() {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("sk-ant-") else {
            problem = "That doesn't look like an Anthropic API key. Keys start with sk-ant-."
            return
        }
        guard APIKeyStore.save(trimmed) else {
            problem = "The key couldn't be saved in the Keychain. Try again."
            return
        }
        dismiss()
        onSave()
    }
}

import SwiftUI

/// Asks for the OpenRouter key that label reading runs on.
struct APIKeyForm: View {
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Biteflux reads labels with GPT Luna 6, through OpenRouter. Each photo costs a fraction of a cent on your own OpenRouter account.")
                    Link("Get a key at openrouter.ai", destination: URL(string: "https://openrouter.ai/settings/keys")!)
                        .foregroundStyle(Ember.accent)
                }
                .listRowBackground(Ember.surface)
                Section {
                    SecureField("sk-or-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("OpenRouter key")
                } footer: {
                    Text("The key stays in this iPhone's Keychain and is only sent to OpenRouter, with a label photo.")
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
            .navigationTitle("Read labels")
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
        guard trimmed.hasPrefix("sk-or-") else {
            problem = "That doesn't look like an OpenRouter key. Keys start with sk-or-."
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

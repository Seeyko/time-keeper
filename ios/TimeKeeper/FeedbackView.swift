import SwiftUI

struct FeedbackView: View {
    enum Topic: String, CaseIterable, Identifiable {
        case problem = "Un souci"
        case idea = "Une idée"
        case kind = "Un mot doux"
        case other = "Autre chose"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var topic: Topic = .problem
    @State private var message = ""
    @State private var email = ""
    @State private var sending = false
    @State private var failed = false
    @State private var sent = false

    private var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending
    }

    var body: some View {
        Form {
            Section {
                Picker("C'est à propos de…", selection: $topic) {
                    ForEach(Topic.allCases) { Text($0.rawValue).tag($0) }
                }
                .sensoryFeedback(.selection, trigger: topic)
            }
            Section {
                TextField("Ton message", text: $message, axis: .vertical)
                    .lineLimit(5...12)
            }
            Section {
                TextField("Ton e-mail, pour te répondre", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } footer: {
                if failed {
                    Text("Pas envoyé. Réessaie dans un moment.")
                        .foregroundStyle(Theme.blocked)
                }
            }
        }
        .navigationTitle("Ton avis")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if sending {
                    ProgressView()
                } else {
                    Button("Envoyer") { send() }
                        .disabled(!canSend)
                }
            }
        }
        .sensoryFeedback(.success, trigger: sent)
        .sensoryFeedback(.error, trigger: failed) { _, now in now }
    }

    private func send() {
        sending = true
        failed = false
        Task {
            let ok = await Analytics.sendFeedback(topic: topic.rawValue, message: message, email: email)
            sending = false
            if ok {
                sent = true
                dismiss()
            } else {
                failed = true
            }
        }
    }
}

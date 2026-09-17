import SwiftUI

struct EditDeckSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: FlipItStore

    var deckId: UUID

    // Sprawdzamy, czy to pierwszy deck
    var isSystemDeck: Bool {
        store.decks.first?.id == deckId
    }

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var frontLabel: String = ""
    @State private var backLabel: String = ""

    @State private var frontLanguage: String = "en-US"
    @State private var backLanguage: String = "pl-PL"

    var body: some View {
        NavigationStack {
            Form {
                            Section(header: Text("Deck Info")) {
                                HStack {
                                    TextField("Deck Name", text: $name, axis: .vertical)
                                        .disabled(isSystemDeck)
                                        .foregroundStyle(isSystemDeck ? .secondary : .primary)
                                        .onChange(of: name) { if name.count > AppLimits.deckName { name = String(name.prefix(AppLimits.deckName)) } }
                                    Spacer()
                                    Text("\(name.count)/\(AppLimits.deckName)")
                                        .font(.caption)
                                        // ZMIANA KOLORU
                                        .foregroundStyle(name.count >= AppLimits.deckName ? .red.opacity(0.8) : .secondary)
                                }

                                if isSystemDeck {
                                     Text("You cannot rename the main deck.").font(.caption).foregroundStyle(.secondary)
                                }

                                HStack(alignment: .top) {
                                    TextField("Description", text: $description, axis: .vertical)
                                        .onChange(of: description) { if description.count > AppLimits.deckDescription { description = String(description.prefix(AppLimits.deckDescription)) } }
                                    Spacer()
                                    Text("\(description.count)/\(AppLimits.deckDescription)")
                                        .font(.caption)
                                        // ZMIANA KOLORU
                                        .foregroundStyle(description.count >= AppLimits.deckDescription ? .red.opacity(0.8) : .secondary)
                                        .padding(.top, 4)
                                }
                            }

                            Section(header: Text("Front Side")) {
                                HStack {
                                    TextField("Label", text: $frontLabel)
                                        .onChange(of: frontLabel) { if frontLabel.count > AppLimits.label { frontLabel = String(frontLabel.prefix(AppLimits.label)) } }
                                    Spacer()
                                    Text("\(frontLabel.count)/\(AppLimits.label)")
                                        .font(.caption)
                                        // ZMIANA KOLORU
                                        .foregroundStyle(frontLabel.count >= AppLimits.label ? .red.opacity(0.8) : .secondary)
                                }
                                Picker("", selection: $frontLanguage) {
                                    ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                                        Text(value).tag(key)
                                    }
                                }
                                .labelsHidden().pickerStyle(.menu)
                            }

                            Section(header: Text("Back Side")) {
                                HStack {
                                    TextField("Label", text: $backLabel)
                                        .onChange(of: backLabel) { if backLabel.count > AppLimits.label { backLabel = String(backLabel.prefix(AppLimits.label)) } }
                                    Spacer()
                                    Text("\(backLabel.count)/\(AppLimits.label)")
                                        .font(.caption)
                                        // ZMIANA KOLORU
                                        .foregroundStyle(backLabel.count >= AppLimits.label ? .red.opacity(0.8) : .secondary)
                                }
                                Picker("", selection: $backLanguage) {
                                    ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                                        Text(value).tag(key)
                                    }
                                }
                                .labelsHidden().pickerStyle(.menu)
                            }
                        }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateDeck(deckId: deckId, name: name, description: description, frontLabel: frontLabel, backLabel: backLabel,frontLanguage: frontLanguage,backLanguage: backLanguage)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let deck = store.decks.first(where: { $0.id == deckId }) {
                    name = deck.name
                    description = deck.description
                    frontLabel = deck.frontLabel
                    backLabel = deck.backLabel
                    frontLanguage = deck.frontLanguage
                    backLanguage = deck.backLanguage
                }
            }
        }
    }
}


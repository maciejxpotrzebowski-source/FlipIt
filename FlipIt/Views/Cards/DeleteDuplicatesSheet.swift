import SwiftUI

struct DeleteDuplicatesSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: FlipItStore
    var deck: Deck

    // Logika: Szukamy kart, które mają taki sam Front I taki sam Back
    var duplicatesInfo: (count: Int, ids: Set<UUID>) {
        var bestCards: [String: Flashcard] = [:]
        var allDuplicateIds = Set<UUID>()

        for card in deck.cards {
                let f = card.front.trimmingCharacters(in: .whitespaces).lowercased()
                let b = card.back.trimmingCharacters(in: .whitespaces).lowercased()
                let key = "\(f)|\(b)"

                if let existingBest = bestCards[key] {
                    // Znaleźliśmy duplikat. Sprawdzamy, która karta ma większy streak.
                    if card.streak > existingBest.streak {
                        // Nowa karta jest lepsza: stara idzie do usunięcia, nową zapamiętujemy
                        allDuplicateIds.insert(existingBest.id)
                        bestCards[key] = card
                    } else {
                        // Stara karta jest lepsza lub taka sama: nowa idzie do usunięcia
                        allDuplicateIds.insert(card.id)
                    }
                } else {
                    // Pierwszy raz widzimy tę treść, zapamiętujemy jako potencjalnie najlepszą
                    bestCards[key] = card
                }
            }
        return (allDuplicateIds.count, allDuplicateIds)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total cards")
                        Spacer()
                        Text("\(deck.cards.count)")
                            .fontWeight(.bold)
                    }

                    HStack {
                        Text("Duplicates found")
                        Spacer()
                        Text("\(duplicatesInfo.count)")
                            .foregroundStyle(duplicatesInfo.count > 0 ? .red : .green)
                            .fontWeight(.bold)
                    }

                    if duplicatesInfo.count > 0 {
                        Text("Duplicates have identical Front and Back sides.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No exact duplicates found.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                // USUNĄŁEM DOLNĄ SEKCJĘ Z PRZYCISKIEM
            }
            .navigationTitle("Clean Up Deck")
            .toolbar {
                // LEWA STRONA (CANCEL)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                // PRAWA STRONA (DELETE)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete") {
                        store.deleteCards(deckId: deck.id, cardIds: duplicatesInfo.ids)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .fontWeight(.bold)
                    .disabled(duplicatesInfo.count == 0)
                }
            }
        }
    }
}


import SwiftUI

struct ResetProgressSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: FlipItStore
    var deck: Deck

    // Obliczamy liczbę kart, które mają postęp (streak > 0)
    var cardsWithProgress: Int {
        deck.cards.filter { $0.streak > 0 }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Summary")) {
                    // 1. Wszystkie karty w talii
                    HStack {
                        Text("Total cards")
                        Spacer()
                        Text("\(deck.cards.count)")
                            .foregroundStyle(.secondary)
                    }

                    // 2. Tylko karty z niezerowym licznikiem (do zresetowania)
                    HStack {
                        Text("Cards to reset (Streak > 0)")
                        Spacer()
                        Text("\(cardsWithProgress)")
                            .fontWeight(.bold)
                            .foregroundStyle(cardsWithProgress > 0 ? .orange : .secondary)
                    }

                    Text("All cards will be marked as 'Unknown' and streaks will return to 0.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Reset Progress")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Reset") {
                        store.resetAllProgress(deckId: deck.id)
                        dismiss()
                    }
                    .foregroundStyle(.orange)
                    .fontWeight(.bold)
                    // Przycisk aktywny tylko wtedy, gdy jest co resetować
                    .disabled(cardsWithProgress == 0)
                }
            }
        }
    }
}


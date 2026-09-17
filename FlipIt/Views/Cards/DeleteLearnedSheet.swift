import SwiftUI

struct DeleteLearnedSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: FlipItStore
    var deck: Deck

    // ZMIANA: Używamy Double dla suwaka, domyślnie 3.0
    @State private var minStreakValue: Double = 3.0

    // Pomocnicza zmienna zamieniająca wartość suwaka na Int
    var minStreak: Int {
        Int(minStreakValue)
    }

    // Obliczamy na żywo, ile kart zostanie usuniętych
    var cardsToDeleteCount: Int {
        return deck.cards.filter { $0.streak >= minStreak }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Criteria"), footer: Text("Cards with a streak of \(minStreak) or higher will be deleted.")) {
                    VStack(spacing: 10) {
                        // Wyświetlanie aktualnie wybranej wartości
                        HStack {
                            Text("Minimum Streak")
                            Spacer()
                            Text("\(minStreak)")
                                .fontWeight(.bold)
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 30, alignment: .trailing)
                        }

                        // SUWAK OD 0 DO 10
                        Slider(value: $minStreakValue, in: 0...10, step: 1) {
                            Text("Streak")
                        } minimumValueLabel: {
                            Text("0").font(.caption).foregroundStyle(.secondary)
                        } maximumValueLabel: {
                            Text("10").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(header: Text("Summary")) {
                    HStack {
                        Text("Total cards")
                        Spacer()
                        Text("\(deck.cards.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Cards to delete")
                        Spacer()
                        Text("\(cardsToDeleteCount)")
                            .fontWeight(.bold)
                            .foregroundStyle(cardsToDeleteCount > 0 ? .red : .secondary)
                    }
                }
            }
            .navigationTitle("Delete Learned Cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete") {
                        // Przekazujemy wartość całkowitą (minStreak)
                        store.deleteLearnedCards(deckId: deck.id, minStreak: minStreak)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .fontWeight(.bold)
                    .disabled(cardsToDeleteCount == 0)
                }
            }
        }
    }
}


import SwiftUI

struct DeleteAllSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: FlipItStore
    var deck: Deck

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Summary")) {
                    HStack {
                        Text("Cards to delete")
                        Spacer()
                        Text("\(deck.cards.count)")
                            .fontWeight(.bold)
                            .foregroundStyle(.red)
                    }
                    Text("This action cannot be undone. All cards will be permanently removed.")
                        .font(.caption).foregroundStyle(.red)
                }
            }
            .navigationTitle("Delete All Cards")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete All") {
                        store.deleteAllCards(deckId: deck.id)
                        dismiss()
                    }
                    .foregroundStyle(.red)
                    .fontWeight(.bold)
                    .disabled(deck.cards.isEmpty)
                }
            }
        }
    }
}


import SwiftUI

struct ManageDecksView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: FlipItStore

    @State private var localDecks: [Deck]
    @State private var showDeleteAlert = false
    @State private var deckToDelete: Deck?

    init(store: FlipItStore) {
        self.store = store
        _localDecks = State(initialValue: store.decks)
    }

    var body: some View {
        NavigationStack {
            List {
                // Używamy Enumerated, żeby znać indeks
                ForEach(Array(localDecks.enumerated()), id: \.element.id) { index, deck in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center, spacing: 0) {

                            // 1. IKONA PO LEWEJ (KOSZ LUB PINEZKA)
                            if index == 0 {
                                // Dla pierwszego elementu: PINEZKA (nieaktywna)
                                Image(systemName: "pin.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 18))
                                    .frame(width: 44, height: 44)
                            } else {
                                // Dla reszty: KOSZ
                                Button(action: {
                                    deckToDelete = deck
                                    showDeleteAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                        .font(.system(size: 18))
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.borderless)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top) {
                                    Text(deck.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(deck.cards.filter { $0.isLearned }.count) / \(deck.cards.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(value: deck.progress)
                                    .tint(deck.progress == 1.0 ? .green : .blue)
                                    .scaleEffect(x: 1, y: 0.8, anchor: .center)

                                if !deck.description.isEmpty {
                                    Text(deck.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 8)
                            .padding(.leading, 8)
                            Spacer(minLength: 15)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 16))
                    }
                    // Blokada przesuwania w widoku ManageDecks
                    .moveDisabled(index == 0)
                }
                .onMove { indices, newOffset in
                    // Dodatkowe zabezpieczenie w widoku (choć model też to blokuje)
                    if indices.contains(0) || newOffset == 0 { return }
                    localDecks.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .navigationTitle("Manage Decks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.fontWeight(.bold) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.decks = localDecks
                        store.saveData()
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .alert("Delete Deck", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { deckToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete {
                        withAnimation { localDecks.removeAll(where: { $0.id == deck.id }) }
                    }
                    deckToDelete = nil
                }
            } message: {
                if let deck = deckToDelete { Text("Are you sure you want to delete '\(deck.name)'?") }
            }
        }
    }
}


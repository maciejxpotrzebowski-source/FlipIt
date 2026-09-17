import SwiftUI

struct DeckDetailView: View {
    @ObservedObject var store: FlipItStore
    let initialDeckId: UUID
    @State private var selectedDeckId: UUID
    @State private var showDeleteLearnedSheet = false
    @State private var showResetProgressSheet = false
    @State private var showDeleteAllSheet = false

    init(store: FlipItStore, deck: Deck) {
        self.store = store
        self.initialDeckId = deck.id
        self._selectedDeckId = State(initialValue: deck.id)
    }

    @Environment(\.dismiss) var dismiss

    @State private var showAddCard = false
    @State private var showEditDeck = false
    @State private var showImportSheet = false
    @State private var showDeleteDeckAlert = false
    @State private var showMoveCardsFromSheet = false
    @State private var showMoveCardsToSheet = false
    @State private var showDeleteDuplicates = false
    @State private var showGenerateSheet = false

    var activeDeck: Deck? {
        store.decks.first(where: { $0.id == selectedDeckId })
    }

    var sortedCards: [Flashcard] {
        guard let deck = activeDeck else { return [] }
        switch store.settings.sortOption {
        case .frontAZ: return deck.cards.sorted { $0.front.localizedCaseInsensitiveCompare($1.front) == .orderedAscending }
        case .frontZA: return deck.cards.sorted { $0.front.localizedCaseInsensitiveCompare($1.front) == .orderedDescending }
        case .backAZ: return deck.cards.sorted { $0.back.localizedCaseInsensitiveCompare($1.back) == .orderedAscending }
        case .backZA: return deck.cards.sorted { $0.back.localizedCaseInsensitiveCompare($1.back) == .orderedDescending }
        case .createdOldest: return deck.cards.sorted { $0.createdAt < $1.createdAt }
        case .createdNewest: return deck.cards.sorted { $0.createdAt > $1.createdAt }
        case .mostKnown: return deck.cards.sorted { $0.streak > $1.streak }
        case .mostUnknown: return deck.cards.sorted { $0.streak < $1.streak }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let deck = activeDeck {
                List {
                    // Sekcja Info
                    Section {
                        if !deck.description.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description").font(.caption).foregroundStyle(.secondary)
                                Text(deck.description).font(.body)
                            }.padding(.vertical, 2)
                        }
                        HStack {
                                                    VStack(alignment: .leading) {
                                                        Text("Front Label").font(.caption).foregroundStyle(.secondary)
                                                        // Wyświetlamy np. "Słówko (EN)"
                                                        Text("\(deck.frontLabel) (\(getLangCode(deck.frontLanguage)))")
                                                            .fontWeight(.medium)
                                                    }
                                                    Spacer()
                                                    Divider()
                                                    Spacer()
                                                    VStack(alignment: .trailing) {
                                                        Text("Back Label").font(.caption).foregroundStyle(.secondary)
                                                        // Wyświetlamy np. "Definicja (PL)"
                                                        Text("\(deck.backLabel) (\(getLangCode(deck.backLanguage)))")
                                                            .fontWeight(.medium)
                                                    }
                                                }.padding(.vertical, 2)
                    }

                    // Sekcja Kart
                    Section(header:
                        HStack {
                            Text("Flashcards")
                            Spacer()
                            Menu {
                                Picker("Sort By", selection: $store.settings.sortOption) {
                                    ForEach(CardSortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(shortSortName(store.settings.sortOption))
                                        .font(.caption).fontWeight(.medium)
                                    Image(systemName: "arrow.up.arrow.down").font(.caption)
                                }
                                .padding(.vertical, 4).padding(.horizontal, 8)
                                .background(Color.blue.opacity(0.1)).clipShape(Capsule())
                            }
                        }
                    ) {
                        if deck.cards.isEmpty {
                            Text("No cards yet. Add some!").foregroundStyle(.secondary)
                        } else {
                            ForEach(sortedCards) { card in
                                // Tutaj przekazujemy store. Nie potrzebujemy $store.
                                CardRowView(store: store, card: card, deck: deck)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Deck not found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(activeDeck?.name ?? "Deck")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: store.settings.sortOption) { store.saveData() }
        .toolbar {
            if activeDeck != nil {
                ToolbarItem(placement: .appTopBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            Button(action: { showEditDeck = true }) { Label("Edit Deck", systemImage: "pencil") }
                            Divider()
                            Button(action: { showResetProgressSheet = true }) {
                                Label("Reset All Progress", systemImage: "arrow.counterclockwise")
                            }

                            Button(action: { showDeleteLearnedSheet = true }) {
                                Label("Delete Learned Cards...", systemImage: "line.3.horizontal.decrease.circle")
                            }

                            Button(action: { showDeleteAllSheet = true }) {
                                Label("Delete All Cards", systemImage: "trash.slash")
                            }
                            Button(action: { showDeleteDuplicates = true }) {
                                                            Label("Delete Duplicates", systemImage: "doc.on.doc")
                                                        }
                            if store.decks.firstIndex(where: { $0.id == activeDeck?.id }) != 0 {


                                Divider()
                                    Button(role: .destructive, action: { showDeleteDeckAlert = true }) {
                                        Label("Delete Deck", systemImage: "trash")
                                    }
                                }
                        } label: {
                            Image(systemName: "gear").font(.system(size: 16, weight: .bold)).foregroundStyle(.blue)
                        }
                        Menu {
                            Button(action: { showAddCard = true }) { Label("New Card", systemImage: "rectangle.portrait.badge.plus") }
                            Divider()
                            Button(action: { showMoveCardsFromSheet = true }) {
                                                            Label("Move Cards From Here", systemImage: "arrow.up.right.square")
                                                        }
                            Button(action: { showMoveCardsToSheet = true }) {
                                                            Label("Move Cards To Here", systemImage: "arrow.down.left.square")
                                                        }
                            Divider()
                            Button(action: { showGenerateSheet = true }) {
                                Label("Generate (AI)", systemImage: "sparkles")
                            }
                            Button(action: { showImportSheet = true }) { Label("Import", systemImage: "square.and.arrow.down") }
                        } label: {
                            Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showImportSheet) { ImportView(store: store, initialDeckId: selectedDeckId).presentationDetents([.large]) }
        .sheet(isPresented: $showEditDeck) { if let deck = activeDeck { EditDeckSheet(store: store, deckId: deck.id).presentationDetents([.large]) } }
        .sheet(isPresented: $showAddCard) { if let deck = activeDeck { AddCardSheet(store: store, isPresented: $showAddCard, selectedDeckId: deck.id).presentationDetents([.large]) } }
        .sheet(isPresented: $showMoveCardsFromSheet) {
                    // "From Here": Źródło = current, Cel = (auto)
                    if let deck = activeDeck {
                        MoveCardsView(store: store, initialSourceId: deck.id, initialDestId: nil)
                            .presentationDetents([.large])
                    }
                }
        .sheet(isPresented: $showMoveCardsToSheet) {
                    // "To Here": Źródło = (auto), Cel = current
                    if let deck = activeDeck {
                        MoveCardsView(store: store, initialSourceId: nil, initialDestId: deck.id)
                            .presentationDetents([.large])
                    }
                }
        .sheet(isPresented: $showDeleteDuplicates) {
                    if let deck = activeDeck {
                        DeleteDuplicatesSheet(store: store, deck: deck)
                            .presentationDetents([.large])
                    }
                }
        .sheet(isPresented: $showGenerateSheet) {
                if let deck = activeDeck {
                    AIGenerateView(store: store, initialDeckId: deck.id)
                        .presentationDetents([.large])
                }
            }
        .sheet(isPresented: $showDeleteLearnedSheet) {
            if let deck = activeDeck {
                DeleteLearnedSheet(store: store, deck: deck)
                    .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showResetProgressSheet) {
            if let deck = activeDeck {
                ResetProgressSheet(store: store, deck: deck)
                    .presentationDetents([.large]) // Ten może być mniejszy
            }
        }
        .sheet(isPresented: $showDeleteAllSheet) {
            if let deck = activeDeck {
                DeleteAllSheet(store: store, deck: deck)
                    .presentationDetents([.large])
            }
        }
        .alert("Delete Deck", isPresented: $showDeleteDeckAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let deck = activeDeck {
                    store.deleteDeck(id: deck.id)
                    dismiss()
                }
            }
        } message: {
            if let deck = activeDeck { Text("Are you sure you want to delete the deck '\(deck.name)'? All cards will be lost.") }
        }
    }

    func shortSortName(_ option: CardSortOption) -> String {
        switch option {
        case .frontAZ: return "Front (A-Z)"
        case .frontZA: return "Front (Z-A)"
        case .backAZ: return "Back (A-Z)"
        case .backZA: return "Back (Z-A)"
        case .createdOldest: return "Oldest"
        case .createdNewest: return "Newest"
        case .mostKnown: return "Known"
        case .mostUnknown: return "Unknown"
        }
    }
}


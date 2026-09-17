import SwiftUI

struct MoveCardsView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    // Parametry wejściowe
    var initialSourceId: UUID?
    var initialDestId: UUID?

    @State private var sourceDeckId: UUID?
    @State private var destDeckId: UUID?

    // Opcje
    @State private var selectedCardIds: Set<UUID> = []
    @State private var swapFaces: Bool = false
    @State private var deleteFromSource: Bool = false
    @State private var skipDuplicates: Bool = false
    @State private var showNewDeckSheet = false

    // Inicjalizacja
    init(store: FlipItStore, initialSourceId: UUID? = nil, initialDestId: UUID? = nil) {
        self.store = store
        self.initialSourceId = initialSourceId
        self.initialDestId = initialDestId

        let firstAvailable = store.decks.first?.id
        let startSource = initialSourceId ?? firstAvailable
        var startDest = initialDestId ?? firstAvailable

        if startSource == startDest {
            startDest = store.decks.first(where: { $0.id != startSource })?.id ?? startSource
        }

        _sourceDeckId = State(initialValue: startSource)
        _destDeckId = State(initialValue: startDest)
    }

    // Helpery
    var sourceDeck: Deck? { store.decks.first(where: { $0.id == sourceDeckId }) }
    var destDeck: Deck? { store.decks.first(where: { $0.id == destDeckId }) }

    var cardsInSource: [Flashcard] { sourceDeck?.cards ?? [] }

    var currentDestName: String { destDeck?.name ?? "Select Deck" }
    var currentSourceName: String { sourceDeck?.name ?? "Select Deck" }

    var areAllSelected: Bool {
        !cardsInSource.isEmpty && selectedCardIds.count == cardsInSource.count
    }

    func isDuplicate(_ card: Flashcard) -> Bool {
        guard let dest = destDeck else { return false }
        let f = swapFaces ? card.back : card.front
        let b = swapFaces ? card.front : card.back
        return dest.cards.contains { existing in
            existing.front == f && existing.back == b
        }
    }

    // Liczba zaznaczonych duplikatów
    var duplicatesCount: Int {
        let selectedCards = cardsInSource.filter { selectedCardIds.contains($0.id) }
        return selectedCards.filter { isDuplicate($0) }.count
    }

    // NOWA ZMIENNA: Faktyczna liczba kart do przeniesienia
    var actualMoveCount: Int {
        if skipDuplicates {
            return selectedCardIds.count - duplicatesCount
        } else {
            return selectedCardIds.count
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                List {
                    // --- 1. DESTINATION DECK ---
                    Section(header: Text("Destination Deck")) {
                        HStack(alignment: .center) {
                            Menu {
                                Picker("Deck", selection: $destDeckId) {
                                    ForEach(store.decks) { deck in
                                        Text(deck.name).tag(Optional(deck.id))
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(currentDestName)
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundStyle(.blue).lineLimit(1)
                                        .frame(minWidth: 80, maxWidth: 150)

                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2).foregroundStyle(.blue)
                                }
                                .padding(.vertical, 6).padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.1)).clipShape(Capsule())
                            }

                            Spacer()

                            Button(action: { showNewDeckSheet = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.white).padding(6)
                                        .background(Color.blue).clipShape(Circle())
                                    Text("New Deck").font(.subheadline).fontWeight(.medium).foregroundStyle(.blue)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                    }

                    // --- 2. SOURCE DECK ---
                    Section(header:
                                HStack {
                        Text("Source Deck")
                        // Komunikat pojawia się tutaj
                        if destDeckId == sourceDeckId {
                            Spacer()
                            Text("Same as Destination")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .textCase(.none)
                        }
                    }) {
                        HStack(alignment: .center) {
                            Menu {
                                Picker("Source", selection: $sourceDeckId) {
                                    ForEach(store.decks) { deck in
                                        Text(deck.name).tag(Optional(deck.id))
                                    }
                                }
                                .onChange(of: sourceDeckId) {
                                    selectedCardIds.removeAll()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(currentSourceName)
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundStyle(.blue).lineLimit(1)
                                        .frame(minWidth: 80, maxWidth: 150)

                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2).foregroundStyle(.blue)
                                }
                                .padding(.vertical, 6).padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.1)).clipShape(Capsule())
                            }

                            Spacer()

                            if sourceDeck != nil {
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text("In deck: \(cardsInSource.count)")

                                        if duplicatesCount > 0 {
                                            Text("Duplicates: \(duplicatesCount)")
                                                .foregroundStyle(.orange)
                                        }

                                        // TUTAJ UŻYWAMY NOWEJ ZMIENNEJ actualMoveCount
                                        Text("To move: \(actualMoveCount)")
                                            .foregroundStyle(.green)
                                            .fontWeight(.bold)
                                    }
                                    .font(.system(size: 10))
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))

                        // Opcje
                        Toggle("Swap Front & Back", isOn: $swapFaces)
                        Toggle("Delete from source (Move)", isOn: $deleteFromSource)
                            .tint(.red)
                        Toggle("Skip Duplicates", isOn: $skipDuplicates)
                            .tint(.orange)
                    }

                    // --- 3. SEKCJA PUSTA ---
                    Section(header: Text("Select Cards")) {
                        if cardsInSource.isEmpty {
                            Text("No cards to select").foregroundStyle(.secondary)
                        }
                    }
                }
                .appInsetGroupedListStyle()
                .frame(height: 380)
                .scrollDisabled(true)

                // --- PODGLĄD LISTY (DÓŁ) ---
                VStack(alignment: .leading, spacing: 0) {

                    if cardsInSource.isEmpty {
                        VStack {
                            Spacer()
                            ContentUnavailableView("Source deck is empty", systemImage: "tray", description: Text("Select a different deck"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.appSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 0) {

                            // NAGŁÓWEK TABELI
                            HStack(alignment: .center) {
                                Image(systemName: areAllSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(areAllSelected ? .blue : .gray.opacity(0.3))
                                    .font(.system(size: 20))
                                    .onTapGesture {
                                        if areAllSelected { selectedCardIds.removeAll() }
                                        else { selectedCardIds = Set(cardsInSource.map { $0.id }) }
                                    }
                                    .padding(.trailing, 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(destDeck?.frontLabel ?? "Front") (\(getLangCode(destDeck?.frontLanguage ?? "")))")
                                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                                    let srcLabel = swapFaces ? (sourceDeck?.backLabel ?? "Back") : (sourceDeck?.frontLabel ?? "Front")
                                    let srcCode = getLangCode(swapFaces ? (sourceDeck?.backLanguage ?? "") : (sourceDeck?.frontLanguage ?? ""))

                                    Text("\(srcLabel) (\(srcCode))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Divider().frame(height: 32).padding(.horizontal, 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(destDeck?.backLabel ?? "Back") (\(getLangCode(destDeck?.backLanguage ?? "")))")
                                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                                    let srcLabel2 = swapFaces ? (sourceDeck?.frontLabel ?? "Front") : (sourceDeck?.backLabel ?? "Back")
                                    let srcCode2 = getLangCode(swapFaces ? (sourceDeck?.frontLanguage ?? "") : (sourceDeck?.backLanguage ?? ""))

                                    Text("\(srcLabel2) (\(srcCode2))")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                            // LISTA
                            List {
                                ForEach(cardsInSource) { card in
                                    let isSelected = selectedCardIds.contains(card.id)
                                    let isDup = isDuplicate(card)

                                    HStack(alignment: .center) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? .blue : .gray.opacity(0.3))
                                            .font(.system(size: 20))
                                            .onTapGesture {
                                                if isSelected { selectedCardIds.remove(card.id) }
                                                else { selectedCardIds.insert(card.id) }
                                            }

                                        HStack {
                                            Text(swapFaces ? card.back : card.front)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Divider()
                                                .frame(height: 18).padding(.horizontal, 9)
                                            Text(swapFaces ? card.front : card.back)
                                                .lineLimit(1)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle((isSelected && isDup) ? .orange : .primary)
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isSelected { selectedCardIds.remove(card.id) }
                                        else { selectedCardIds.insert(card.id) }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .environment(\.defaultMinListRowHeight, 30)
                        }
                        .background(Color.appSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .padding(.top, 10)
                .background(Color.appGroupedBackground)
            }
            .navigationTitle(deleteFromSource ? "Move Cards" : "Copy Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.fontWeight(.bold) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(deleteFromSource ? "Move" : "Copy") {
                        if let src = sourceDeckId, let dst = destDeckId {
                            store.transferCards(
                                from: src,
                                to: dst,
                                cardIds: selectedCardIds,
                                deleteFromSource: deleteFromSource,
                                swapFaces: swapFaces,
                                skipDuplicates: skipDuplicates
                            )
                            dismiss()
                        }
                    }
                    .disabled(selectedCardIds.isEmpty || sourceDeckId == nil || destDeckId == nil)
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showNewDeckSheet) {
                NewDeckSheet(store: store) { newId in self.destDeckId = newId }
                    .presentationDetents([.large])
            }
        }
    }
}


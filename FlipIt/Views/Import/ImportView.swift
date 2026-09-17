import SwiftUI
import UniformTypeIdentifiers

struct ImportDestinationSheet: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    // Callbacki decydujące co robić dalej
    var onSelectDeck: (UUID) -> Void
    var onCreateNew: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Create New")) {
                    Button(action: {
                        dismiss()
                        // Małe opóźnienie, żeby sheet zdążył się zamknąć przed otwarciem kolejnego
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onCreateNew()
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Create New Deck")
                                .fontWeight(.medium)
                        }
                    }
                }

                Section(header: Text("Add to Existing Deck")) {
                    if store.decks.isEmpty {
                        Text("No existing decks.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.decks) { deck in
                            Button(action: {
                                onSelectDeck(deck.id)
                                dismiss()
                            }) {
                                HStack {
                                    Text(deck.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(deck.cards.count) cards")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import to...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}


struct ImportView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedDeckId: UUID?
    @State private var swapFaces = false
    @State private var skipDuplicates = true
    @State private var showFileImporter = false
    @State private var showNewDeckSheet = false
    @State private var rawFileCards: [Flashcard] = []
    @State private var importedFileName: String? = nil

    // 1. POPRAWIONY INIT (Domyślnie wybiera pierwszy deck)
    init(store: FlipItStore, initialDeckId: UUID? = nil) {
        self.store = store
        let defaultSelection = initialDeckId ?? store.decks.first?.id
        self._selectedDeckId = State(initialValue: defaultSelection)
    }

    var selectedDeck: Deck? {
        guard let id = selectedDeckId else { return nil }
        return store.decks.first(where: { $0.id == id })
    }

    var currentDeckName: String {
        selectedDeck?.name ?? "Select Deck"
    }

    // Logika przetwarzania
    var processedFileCards: [Flashcard] {
        if swapFaces {
            return rawFileCards.map { Flashcard(front: $0.back, back: $0.front) }
        } else {
            return rawFileCards
        }
    }

    func isDuplicate(_ card: Flashcard) -> Bool {
            guard let deck = selectedDeck else { return false }
            return deck.cards.contains { existingCard in
                // 1. Przygotowanie tekstów (trimowanie spacji)
                let existingFront = existingCard.front.trimmingCharacters(in: .whitespaces)
                let existingBack = existingCard.back.trimmingCharacters(in: .whitespaces)

                let newFront = card.front.trimmingCharacters(in: .whitespaces)
                let newBack = card.back.trimmingCharacters(in: .whitespaces)

                // 2. Porównanie (case-insensitive) OBU stron jednocześnie (AND)
                return existingFront.localizedCaseInsensitiveCompare(newFront) == .orderedSame &&
                       existingBack.localizedCaseInsensitiveCompare(newBack) == .orderedSame
            }
        }

    var duplicatesCount: Int {
        return processedFileCards.filter { isDuplicate($0) }.count
    }

    var finalCardsToImport: [Flashcard] {
        if skipDuplicates {
            return processedFileCards.filter { !isDuplicate($0) }
        } else {
            return processedFileCards
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // --- GÓRNE USTAWIENIA (LISTA) ---
                List {
                    // SEKCJA 1: DOCELOWY DECK
                    Section(header: Text("Destination Deck")) {
                        HStack(alignment: .center) {
                            Menu {
                                Picker("Deck", selection: $selectedDeckId) {
                                    ForEach(store.decks) { deck in
                                        Text(deck.name).tag(Optional(deck.id))
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(currentDeckName)
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

                    // SEKCJA 2: ŹRÓDŁO I OPCJE
                    Section(header: Text("Source")) {
                        Button(action: { showFileImporter = true }) {
                            HStack {
                                Image(systemName: rawFileCards.isEmpty ? "doc.badge.plus" : "doc.text.fill")
                                    .foregroundStyle(rawFileCards.isEmpty ? .blue : .green)
                                Text(importedFileName ?? "Select File")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(rawFileCards.isEmpty ? .blue : .green)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                Spacer()
                                if !rawFileCards.isEmpty { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            }
                        }
                        Toggle("Swap Columns", isOn: $swapFaces)
                        Toggle("Skip Duplicates", isOn: $skipDuplicates)
                            .tint(.orange)
                    }

                    // SEKCJA 3: NAGŁÓWEK PREVIEW ZE STATYSTYKAMI (TO ZNIKNĘŁO, A TERAZ JEST)
                    Section(header:
                        HStack {
                            Text("Preview")
                            Spacer()
                            // Wyświetlamy statystyki tylko jeśli wczytano plik
                            if !rawFileCards.isEmpty {
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text("In file: \(rawFileCards.count)")
                                        if duplicatesCount > 0 {
                                            Text("Duplicates: \(duplicatesCount)")
                                                .foregroundStyle(.orange)
                                        }
                                        Text("To import: \(finalCardsToImport.count)")
                                            .foregroundStyle(.green)
                                            .fontWeight(.bold)
                                    }
                                    .font(.system(size: 10))
                                }
                                .padding(.trailing, 4)
                            }
                        }
                    ) {
                        // Pusta sekcja, służy tylko do wyświetlenia nagłówka w stylu Listy
                    }
                }
                .appInsetGroupedListStyle()
                .frame(height: 360) // Dopasowana wysokość, żeby zmieściły się opcje i nagłówek
                .scrollDisabled(true)

                // --- DOLNA CZĘŚĆ: PODGLĄD LISTY ---
                VStack(alignment: .leading, spacing: 0) {

                    if processedFileCards.isEmpty {
                        VStack {
                            Spacer()
                            ContentUnavailableView("No cards to display", systemImage: "doc.text.magnifyingglass", description: Text("Select a file to see preview"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.appSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 0) {

                            // NAGŁÓWKI KOLUMN Z JĘZYKAMI
                            HStack {
                                Text("\(selectedDeck?.frontLabel ?? "Front") (\(getLangCode(selectedDeck?.frontLanguage ?? "")))")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Divider().frame(height: 24).padding(.horizontal, 10)
                                Text("\(selectedDeck?.backLabel ?? "Back") (\(getLangCode(selectedDeck?.backLanguage ?? "")))")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.system(size: 16, design: .default))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                            // LISTA KART
                            List {
                                ForEach(processedFileCards) { card in
                                    let isDup = isDuplicate(card)

                                    HStack(alignment: .center) {
                                        Text(card.front)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Divider()
                                            .frame(height: 18).padding(.horizontal, 9)
                                        Text(card.back)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .font(.system(size: 12, design: .monospaced))
                                    // Pomarańczowy dla duplikatów
                                    .foregroundStyle(isDup ? .orange : .primary)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
            .navigationTitle("Import Cards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.fontWeight(.bold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        if let targetId = selectedDeckId {
                            // Importujemy tylko to co przeszło filtr
                            store.saveImportedCards(finalCardsToImport, to: targetId)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    // Blokada jeśli brak decku lub brak kart do importu
                    .disabled(selectedDeckId == nil || finalCardsToImport.isEmpty)
                }
            }
            .background(Color.appGroupedBackground)
            .sheet(isPresented: $showNewDeckSheet) {
                NewDeckSheet(store: store) { newId in self.selectedDeckId = newId }
                    .presentationDetents([.large])
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.json, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                    case .success(let urls):
                        if let url = urls.first {
                            self.importedFileName = url.lastPathComponent
                            self.rawFileCards = store.loadCardsFromURL(url)
                        }
                    case .failure(let error):
                        print("Error: \(error.localizedDescription)")
                    }
            }
        }
    }
}


import SwiftUI
import UniformTypeIdentifiers

// --- NOWY UNIWERSALNY WIDOK DODAWANIA KARTY ---
struct NewDeckSheet: View {
    @Environment(\.dismiss) var dismiss
    var store: FlipItStore

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var frontLabel: String = ""
    @State private var backLabel: String = ""

    // Zmienna sterująca wyświetlaniem alertu
    @State private var showDuplicateAlert = false

    // Callback do przekazania ID nowo utworzonego zestawu
    var onDeckCreated: ((UUID) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Deck Info")) {
                    TextField("Deck Name", text: $name)
                    TextField("Description (optional)", text: $description)
                }
                Section(header: Text("Card Labels")) {
                    TextField("Front Label (e.g. Word)", text: $frontLabel)
                    TextField("Back Label (e.g. Definition)", text: $backLabel)
                }
            }
            .navigationTitle("New Deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }
                    .fontWeight(.bold)}
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        checkForDuplicatesAndCreate()
                    }
                    .disabled(name.isEmpty)
                }
            }
            // Alert pytający o potwierdzenie
            .alert("Deck Already Exists", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Create Anyway") {
                    createDeck()
                }
            } message: {
                Text("A deck with the name \"\(name)\" already exists. Do you want to create it anyway?")
            }
        }
    }

    // Funkcja sprawdzająca duplikaty
    private func checkForDuplicatesAndCreate() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Sprawdzamy czy istnieje deck o tej samej nazwie (ignorując wielkość liter)
        let duplicateExists = store.decks.contains { existingDeck in
            existingDeck.name.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }

        if duplicateExists {
            showDuplicateAlert = true
        } else {
            createDeck()
        }
    }

    // Właściwa logika tworzenia (wywoływana od razu lub po potwierdzeniu alertu)
    private func createDeck() {
        store.addDeck(name: name, description: description, frontLabel: frontLabel, backLabel: backLabel)
        if let last = store.decks.last { onDeckCreated?(last.id) }
        dismiss()
    }
}

struct AddCardSheet: View {
    @ObservedObject var store: FlipItStore
    @Binding var isPresented: Bool

    @State private var selectedDeckId: UUID
    @State private var front = ""
    @State private var back = ""
    @State private var showNewDeckSheet = false
    @State private var showDuplicateAlert = false
    @State private var pendingAction: () -> Void = {}

    init(store: FlipItStore, isPresented: Binding<Bool>, selectedDeckId: UUID) {
        self.store = store
        self._isPresented = isPresented
        self._selectedDeckId = State(initialValue: selectedDeckId)
    }

    var selectedDeck: Deck? {
        store.decks.first(where: { $0.id == selectedDeckId })
    }

    var currentDeckName: String {
        selectedDeck?.name ?? "Select Deck"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Selected Deck")) {
                    HStack(alignment: .center) {
                        Menu {
                            Picker("Deck", selection: $selectedDeckId) {
                                ForEach(store.decks) { deck in
                                    Text(deck.name).tag(deck.id)
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

                Section(header: Text("New card")) {
                    TextField(selectedDeck?.frontLabel ?? "Front", text: $front)
                    TextField(selectedDeck?.backLabel ?? "Back", text: $back)
                }
            }
            .navigationTitle("Add Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    HStack {
                        Button("Add next") {
                            validateAndSave(isNext: true)
                        }
                        .disabled(front.isEmpty || back.isEmpty)

                        Button("Add") {
                            validateAndSave(isNext: false)
                        }
                        .fontWeight(.bold)
                        .disabled(front.isEmpty || back.isEmpty)
                    }
                }
            }
            // Alert potwierdzający dodanie duplikatu
            .alert("Duplicate Found", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Add Anyway") {
                    pendingAction()
                }
            } message: {
                Text("A card with the same front or back already exists in this deck. Do you want to add it anyway?")
            }
            .sheet(isPresented: $showNewDeckSheet) {
                NewDeckSheet(store: store) { newId in
                    self.selectedDeckId = newId
                }
                .presentationDetents([.large])
            }
        }
    }

    // Pomocnicza funkcja zapisu
    private func saveCurrentCard() {
        store.addCard(to: selectedDeckId, front: front, back: back)
    }

    private func validateAndSave(isNext: Bool) {
        let trimmedFront = front.trimmingCharacters(in: .whitespaces)
        let trimmedBack = back.trimmingCharacters(in: .whitespaces)

        // Sprawdzenie czy w wybranym decku istnieje już taki sam Front lub Back
        let isDuplicate = selectedDeck?.cards.contains { card in
            card.front.localizedCaseInsensitiveCompare(trimmedFront) == .orderedSame ||
            card.back.localizedCaseInsensitiveCompare(trimmedBack) == .orderedSame
        } ?? false

        let action = {
            saveCurrentCard()
            if isNext {
                front = ""
                back = ""
            } else {
                isPresented = false
            }
        }

        if isDuplicate {
            pendingAction = action
            showDuplicateAlert = true
        } else {
            action()
        }
    }
}

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
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))
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

// --- 1. HOME VIEW ---
struct HomeView: View {
    @StateObject var store = FlipItStore()

    // Obsługa widoków (Sheets)
    @State private var showAddCardSheet = false
    @State private var showSettings = false
    @State private var showNewDeckSheet = false
    @State private var showImportView = false
    @State private var showManageDecks = false
    @State private var showMoveCardsSheet = false
    // Kopia zapasowa
    @State private var originalDecks: [Deck] = []

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. TŁO (Szare)
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 10) {

                        // WŁAŚCIWA LISTA
                        List {
                            ForEach(Array(store.decks.enumerated()), id: \.element.id) { index, deck in
                                NavigationLink(destination: DeckDetailView(store: store, deck: deck)) {
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
                                }
                                .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground))
                                .listRowSeparatorTint(Color.gray.opacity(0.3))
                                .deleteDisabled(index == 0)
                                .moveDisabled(index == 0)
                            }
                            .onMove(perform: store.moveDeck)
                            .onDelete(perform: store.deleteDeck)
                        }
                        .listStyle(.plain)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        // Lista rośnie dynamicznie, ale zostawiamy miejsce na dole dla przycisku
                        .padding(.bottom, 16)
                    }
                }
            }
            // ZMIANA: Ukrywamy standardowy tytuł, żeby użyć naszego własnego (statycznego)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)


            // --- PRZYCISK START STUDYING ---
            .safeAreaInset(edge: .bottom) {
                if !showAddCardSheet && !showSettings && !showImportView {
                    NavigationLink(destination: StudySetupView(store: store)) {
                        Text("START STUDYING")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
                    }
                    .padding(.bottom, 10)
                }
            }

            // --- TOOLBAR (Przyciski zostają w systemowym pasku u góry) ---
            .toolbar {
                            // LEWA STRONA (TopBarLeading)
                ToolbarItem(placement: .topBarLeading) {
                            // W trybie normalnym pokazujemy tytuł aplikacji
                            Text(" FlipIt ")
                                .font(.system(size: 36, weight: .bold, design: .default))
                                .fontWeight(.bold)
                                .fixedSize(horizontal: true, vertical: false)
                    }
                .sharedBackgroundVisibility(.hidden)
                            // PRAWA STRONA (TopBarTrailing) - Główne menu
                            ToolbarItem(placement: .topBarTrailing) {
                                    HStack(spacing: 16) {
                                        // 1. ZĘBATKA (Niebieska) -> Settings / Manage Decks
                                        Menu {
                                            Button(action: { showSettings = true }) {
                                                Label("Settings", systemImage: "gear")
                                            }

                                            if !store.decks.isEmpty {
                                                Button(action: {
                                                    showManageDecks = true
                                                }) {
                                                    Label("Manage Decks", systemImage: "arrow.up.arrow.down")
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "gear")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.blue) // <--- Kolor niebieski
                                        }

                                        // 2. PLUS (Zielony) -> New Card / New Deck / Import
                                        Menu {
                                            Button(action: { showAddCardSheet = true }) {
                                                Label("New Card", systemImage: "rectangle.portrait.badge.plus")
                                            }
                                            Button(action: { showNewDeckSheet = true }) {
                                                Label("New Deck", systemImage: "folder.badge.plus")
                                            }
                                            Divider() // Separator dla czytelności

                                                                        // --- NOWA OPCJA: MOVE CARDS ---
                                                                        Button(action: { showMoveCardsSheet = true }) {
                                                                            Label("Move Cards", systemImage: "arrow.right.arrow.left.square")
                                                                        }

                                            Divider()
                                            Button(action: { showImportView = true }) {
                                                Label("Import", systemImage: "square.and.arrow.down")
                                            }
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.green) // <--- Kolor zielony
                                        }
                                    }
                            }
                        }
            .sheet(isPresented: $showImportView) { ImportView(store: store).presentationDetents([.large]) }
            .sheet(isPresented: $showAddCardSheet) {
                AddCardSheet(store: store, isPresented: $showAddCardSheet, selectedDeckId: store.decks.first?.id ?? UUID())
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showNewDeckSheet) {
                            NewDeckSheet(store: store) { _ in }
                                .presentationDetents([.large])
                        }
            .sheet(isPresented: $showSettings) { SettingsView(store: store) }
            .sheet(isPresented: $showManageDecks) { ManageDecksView(store: store) }
            .sheet(isPresented: $showMoveCardsSheet) {
                            MoveCardsView(store: store) // Bez parametrów = puste/domyślne
                                .presentationDetents([.large])
                        }
            .onOpenURL { url in
                            // Sprawdzamy, czy widget przysłał nam prośbę o dodanie karty
                            if url.absoluteString == "flipit://add_card" {
                                // Otwieramy arkusz dodawania karty
                                showAddCardSheet = true
                            }
                        }
        }
    }
}

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

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Deck Info")) {
                    // BLOKADA EDYCJI NAZWY
                    TextField("Deck Name", text: $name, axis: .vertical)
                        .disabled(isSystemDeck)
                        .foregroundStyle(isSystemDeck ? .secondary : .primary)

                    if isSystemDeck {
                        Text("You cannot rename the main deck.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    TextField("Description", text: $description, axis: .vertical)
                }
                Section(header: Text("Card Labels")) {
                    TextField("Front Label", text: $frontLabel, axis: .vertical)
                    TextField("Back Label", text: $backLabel, axis: .vertical)
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateDeck(deckId: deckId, name: name, description: description, frontLabel: frontLabel, backLabel: backLabel)
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
                }
            }
        }
    }
}

// --- 2. DECK PREVIEW & EDIT ---

struct CardRowView: View {
    // ZMIANA: Zwykła zmienna, nie @ObservedObject.
    // Naprawia błąd "Cannot call value of non-function type"
    var store: FlipItStore

    let card: Flashcard
    let deck: Deck

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var tempFront = ""
    @State private var tempBack = ""

    var body: some View {
        HStack {
            Image(systemName: card.isLearned ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(card.isLearned ? .green : .red)
                .font(.system(size: 20))

            VStack(alignment: .leading) {
                Text(card.front).font(.headline)
                Text(card.back).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 15) {
                // Przycisk Edycji
                Button(action: {
                    tempFront = card.front
                    tempBack = card.back
                    showEditSheet = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.blue)
                        .font(.system(size: 20))
                }
                .buttonStyle(BorderlessButtonStyle())

                // Przycisk Usuwania
                Button(action: {
                    if store.settings.confirmDelete {
                        showDeleteConfirmation = true
                    } else {
                        deleteCardNow()
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.system(size: 20))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                    TextField(deck.frontLabel, text: $tempFront)
                    TextField(deck.backLabel, text: $tempBack)
                }
                .navigationTitle("Edit Card")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showEditSheet = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.updateCardContent(deckId: deck.id, cardId: card.id, front: tempFront, back: tempBack)
                            showEditSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Delete Card", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                 deleteCardNow()
            }
        } message: { Text("Are you sure you want to delete this card?") }
    }

    // Funkcja pomocnicza
    private func deleteCardNow() {
        withAnimation {
            store.deleteCard(deckId: deck.id, cardId: card.id)
        }
    }
}

// --- ODCHUDZONY GŁÓWNY WIDOK ---
struct DeckDetailView: View {
    @ObservedObject var store: FlipItStore
    let initialDeckId: UUID
    @State private var selectedDeckId: UUID

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
                                Text(deck.frontLabel).fontWeight(.medium)
                            }
                            Spacer()
                            Divider()
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Back Label").font(.caption).foregroundStyle(.secondary)
                                Text(deck.backLabel).fontWeight(.medium)
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
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Menu {
                            Button(action: { showEditDeck = true }) { Label("Edit Deck", systemImage: "pencil") }
                            if store.decks.firstIndex(where: { $0.id == activeDeck?.id }) != 0 {
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
struct SettingsView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    // Teraz operujemy bezpośrednio na store.settings, aby zmiany były natychmiastowe
    // i od razu widoczne w całej aplikacji/widgetach po zapisie.

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("General")) {
                    Toggle("Confirm Flashcards' Deletion", isOn: $store.settings.confirmDelete)
                }

                // --- NOWA SEKCJA WIDGET ---
                Section(header: Text("Widget")) {
                    Toggle("Colorful Buttons", isOn: $store.settings.widgetColorfulButtons)

                    Toggle("Inactivity Reminder (Color)", isOn: $store.settings.widgetInactivityColor)

                    if store.settings.widgetInactivityColor {
                        Text("When enabled, the widget background will turn red if you haven't studied for a few days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.saveData() // Zapisujemy zmiany
                        dismiss()
                    }
                }
            }
        }
    }
}

// --- 4. STUDY SETUP ---

struct StudySetupView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    // Używamy store.settings bezpośrednio, aby Widget widział te zmiany
    @State private var startSession = false

    var areAllSelected: Bool {
        !store.decks.isEmpty && store.settings.usedDeckIDs.count == store.decks.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- 1. WYBÓR TALII ---
            List {
                Section(header: HStack {
                    Text("SELECT DECKS")
                    Spacer()
                    if !store.decks.isEmpty {
                        Button(action: toggleAllDecks) {
                            Text(areAllSelected ? "Deselect All" : "Select All")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(areAllSelected ? .red : .green)
                        }
                    }
                }) {}
            }
            .listStyle(.insetGrouped).scrollDisabled(true).frame(height: 40)

            // --- 2. LISTA TALII ---
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        if store.decks.isEmpty {
                            Text("No decks available").foregroundStyle(.secondary).padding()
                        } else {
                            ForEach(store.decks) { deck in
                                deckRow(deck: deck)
                                Divider().padding(.leading, 50)
                            }
                        }
                    }
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            }
            Spacer(minLength: 16)

            // --- 3. OPCJE (BEZPOŚREDNIO DO STORE) ---
            VStack(spacing: 0) {
                List {
                    Section(header: Text("OPTIONS")) {
                        // Podpięte pod store.settings!
                        Toggle("Only Unlearned Cards", isOn: $store.settings.onlyUnlearned)
                            .onChange(of: store.settings.onlyUnlearned) { store.saveData() }

                        HStack {
                            Text("Card Side")
                            Spacer()
                            Picker("Card Side", selection: $store.settings.studySide) {
                                ForEach(StudySideOption.allCases, id: \.self) { option in Text(option.rawValue).tag(option) }
                            }
                            .labelsHidden().tint(.secondary)
                            .onChange(of: store.settings.studySide) { store.saveData() }
                        }

                        HStack {
                            Text("Learning Pace")
                            Spacer()
                            Picker("Learning Pace", selection: $store.settings.learningFactorValue) {
                                ForEach(LearningFactor.allCases, id: \.self) { factor in
                                    Text(factor.label).tag(factor.rawValue)
                                }
                            }
                            .labelsHidden().tint(.secondary)
                            .onChange(of: store.settings.learningFactorValue) { store.saveData() }
                        }
                    }
                }
                .listStyle(.insetGrouped).scrollDisabled(true).frame(height: 230)

                Button(action: {
                    store.saveData() // Upewniamy się, że wszystko zapisane przed startem
                    startSession = true
                }) {
                    Text("START SESSION")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(store.settings.usedDeckIDs.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(12)
                }
                .disabled(store.settings.usedDeckIDs.isEmpty)
                .padding(.horizontal, 16).padding(.bottom, 10)
            }
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationTitle("Study Setup")
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationDestination(isPresented: $startSession) {
            // Przekazujemy parametry, choć StudySessionView mogłoby też brać je ze store
            StudySessionView(
                store: store,
                selectedDeckIds: Array(store.settings.usedDeckIDs),
                onlyUnlearned: store.settings.onlyUnlearned,
                studySide: store.settings.studySide,
                learningFactor: LearningFactor(rawValue: store.settings.learningFactorValue) ?? .standard
            )
        }
    }

    // Helpery
    private func toggleAllDecks() {
        withAnimation {
            if areAllSelected { store.settings.usedDeckIDs.removeAll() }
            else { store.settings.usedDeckIDs = Set(store.decks.map { $0.id }) }
            store.saveData()
        }
    }

    private func deckRow(deck: Deck) -> some View {
        HStack(spacing: 12) {
            Image(systemName: store.settings.usedDeckIDs.contains(deck.id) ? "checkmark.square.fill" : "square")
                .foregroundStyle(store.settings.usedDeckIDs.contains(deck.id) ? .blue : .gray.opacity(0.3))
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(deck.name).font(.headline)
                    Spacer()
                    Text("\(deck.cards.filter { $0.isLearned }.count) / \(deck.cards.count)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: deck.progress).tint(deck.progress == 1.0 ? .green : .blue)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if store.settings.usedDeckIDs.contains(deck.id) { store.settings.usedDeckIDs.remove(deck.id) }
            else { store.settings.usedDeckIDs.insert(deck.id) }
            store.saveData()
        }
    }
}

// --- 5. STUDY SESSION (THE CORE) ---

struct StudySessionView: View {
    @ObservedObject var store: FlipItStore
    var selectedDeckIds: [UUID]
    var onlyUnlearned: Bool
    var studySide: StudySideOption

    // NOWE POLE: Otrzymujemy współczynnik z widoku konfiguracji
    var learningFactor: LearningFactor

    // ... reszta zmiennych stanu bez zmian ...
    @State private var activePool: [(card: Flashcard, deckId: UUID)] = []
    @State private var currentItem: (card: Flashcard, deckId: UUID)?
    @State private var isFrontFirst: Bool = true
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var initialLoadDone = false
    @State private var sessionReviewCount = 0
    @State private var sessionKnownCount = 0

    // ... body pozostaje bez zmian ...
    // (Pamiętaj tylko, aby upewnić się, że body używa nowego layoutu statystyk, który zrobiliśmy w poprzednim kroku)

    var body: some View {
        // ... (Kod widoku jest taki sam jak w poprzedniej odpowiedzi) ...
        // ... (Wklej tutaj ciało widoku z poprzedniego kroku, jeśli nie masz go pod ręką) ...
        VStack {
             if activePool.isEmpty && currentItem == nil {
                if initialLoadDone {
                    VStack(spacing: 20) {
                        Text("🎉")
                            .font(.system(size: 80))
                        Text("No cards available!")
                            .font(.title)
                            .fontWeight(.bold)
                        Text("Check your deck selection.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView("Loading...")
                }
            } else if let item = currentItem {

                // --- TOP STATS ---
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session Known: \(sessionKnownCount)")
                        Text("Reviewed: \(sessionReviewCount)")
                    }
                    .font(.caption)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Cards in deck: \(activePool.count)")
                        Text("Total Known: \(activePool.filter { $0.card.isLearned }.count)")
                    }
                    .font(.caption)
                }
                .padding()

                // --- CARD AREA ---
                ZStack {
                    let startText = isFrontFirst ? item.card.front : item.card.back
                    let endText = isFrontFirst ? item.card.back : item.card.front

                    ZStack {
                        CardView(text: endText, backgroundColor: .white)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            .opacity(isFlipped ? 1 : 0)
                        CardView(text: startText, backgroundColor: .white)
                            .opacity(isFlipped ? 0 : 1)
                    }
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.green)
                        .opacity(dragOffset.width > 0 ? abs(dragOffset.width) / 400.0 : 0)
                        .allowsHitTesting(false)

                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.red)
                        .opacity(dragOffset.width < 0 ? abs(dragOffset.width) / 400.0 : 0)
                        .allowsHitTesting(false)
                }
                .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                .offset(x: dragOffset.width, y: dragOffset.height * 0.4)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in dragOffset = gesture.translation }
                        .onEnded { gesture in
                            if gesture.translation.width > 100 { swipeRight() }
                            else if gesture.translation.width < -100 { swipeLeft() }
                            else { withAnimation(.spring()) { dragOffset = .zero } }
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isFlipped.toggle() }
                }
                .padding()
                Spacer()

                // --- CONTROLS ---
                HStack(spacing: 30) {
                    Button(action: swipeLeft) {
                        Image(systemName: "xmark").font(.system(size: 30, weight: .bold))
                            .frame(width: 70, height: 70).background(Color.red.opacity(0.9)).foregroundStyle(.white).clipShape(Circle())
                    }
                    Button(action: { withAnimation { isFlipped.toggle() } }) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 25, weight: .bold))
                            .frame(width: 60, height: 60).background(Color.blue).foregroundStyle(.white).clipShape(Circle())
                    }
                    Button(action: swipeRight) {
                        Image(systemName: "checkmark").font(.system(size: 30, weight: .bold))
                            .frame(width: 70, height: 70).background(Color.green.opacity(0.9)).foregroundStyle(.white).clipShape(Circle())
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Study")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            loadPool()
            pickNextCard()
        }
    }

    // --- LOGIC ---

    // Funkcja loadPool bez zmian...
    func loadPool() {
        var newPool: [(card: Flashcard, deckId: UUID)] = []
        for deck in store.decks where selectedDeckIds.contains(deck.id) {
            for card in deck.cards {
                if onlyUnlearned && card.isLearned { continue }
                newPool.append((card, deck.id))
            }
        }
        activePool = newPool
        initialLoadDone = true
    }

    // --- UPDATED ALGORITHM ---
    func pickNextCard() {
        if activePool.isEmpty {
            currentItem = nil
            return
        }

        // ZMIANA: Używamy lokalnej zmiennej przekazanej z StudySetupView
        let x = learningFactor.rawValue

        // ... Reszta logiki ważonej bez zmian ...
        let weightedItems = activePool.map { item -> (item: (card: Flashcard, deckId: UUID), weight: Double) in
            let n = Double(item.card.streak)
            let weight = 1.0 / (1.0 + (n * x))
            return (item, weight)
        }

        let totalWeight = weightedItems.reduce(0) { $0 + $1.weight }
        let randomValue = Double.random(in: 0..<totalWeight)

        var cursor = 0.0
        var selectedItem: (card: Flashcard, deckId: UUID)? = nil

        for element in weightedItems {
            cursor += element.weight
            if cursor >= randomValue {
                selectedItem = element.item
                break
            }
        }

        if selectedItem == nil { selectedItem = activePool.first }

        if let found = selectedItem {
            currentItem = found
            switch studySide {
            case .front: isFrontFirst = true
            case .back: isFrontFirst = false
            case .random: isFrontFirst = Bool.random()
            }
            isFlipped = false
            dragOffset = .zero
        }
    }

    // ... Reszta funkcji (updateCurrentCard, swipeRight, swipeLeft) bez zmian ...
    func updateCurrentCard(isKnown: Bool) {
        guard let item = currentItem else { return }

        if let index = activePool.firstIndex(where: { $0.card.id == item.card.id }) {
            var updatedCard = activePool[index].card
            if isKnown { updatedCard.streak += 1 } else { updatedCard.streak = 0 }
            updatedCard.isLearned = (updatedCard.streak > 0)
            activePool[index].card = updatedCard
            store.updateStreak(deckId: item.deckId, cardId: item.card.id, newStreak: updatedCard.streak)
        }
    }

    func swipeRight() {
        withAnimation(.easeOut(duration: 0.5)) { dragOffset.width = 1000 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            updateCurrentCard(isKnown: true)
            sessionReviewCount += 1
            sessionKnownCount += 1
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isFlipped = false; dragOffset = .zero }
            withAnimation { pickNextCard() }
        }
    }

    func swipeLeft() {
        withAnimation(.easeOut(duration: 0.5)) { dragOffset.width = -1000 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            updateCurrentCard(isKnown: false)
            sessionReviewCount += 1
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isFlipped = false; dragOffset = .zero }
            withAnimation { pickNextCard() }
        }
    }
}

// --- CARD COMPONENT ---

struct CardView: View {
    var text: String
    var backgroundColor: Color
    
    var body: some View {
        ZStack {
            // Tło karty
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // Tekst na karcie
            Text(text)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding()
                .foregroundStyle(.black) // <--- ZMIANA: Wymuszamy czarny kolor tekstu
                .minimumScaleFactor(0.5) // Zmniejszy tekst, jeśli jest za długi
        }
        .frame(height: 400)
    }
}

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
                    Section(header: Text("Source Deck")) {
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
                .listStyle(.insetGrouped)
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
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
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
                                    Text(destDeck?.frontLabel ?? "Front")
                                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                                    Text(swapFaces ? (sourceDeck?.backLabel ?? "Back") : (sourceDeck?.frontLabel ?? "Front"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Divider().frame(height: 32).padding(.horizontal, 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destDeck?.backLabel ?? "Back")
                                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                                    Text(swapFaces ? (sourceDeck?.frontLabel ?? "Front") : (sourceDeck?.backLabel ?? "Back"))
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
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .padding(.top, 10)
                .background(Color(uiColor: .systemGroupedBackground))
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
                    .disabled(selectedCardIds.isEmpty || sourceDeckId == nil || destDeckId == nil || sourceDeckId == destDeckId)
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

struct ImportView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedDeckId: UUID?
    @State private var swapFaces = false
    @State private var showFileImporter = false
    @State private var showNewDeckSheet = false
    @State private var rawFileCards: [Flashcard] = []
    @State private var importedFileName: String? = nil

    init(store: FlipItStore, initialDeckId: UUID? = nil) {
        self.store = store
        self._selectedDeckId = State(initialValue: initialDeckId)
    }

    var selectedDeck: Deck? {
        guard let id = selectedDeckId else { return nil }
        return store.decks.first(where: { $0.id == id })
    }

    var currentDeckName: String {
        selectedDeck?.name ?? "Select Deck"
    }

    var cardsToImport: [Flashcard] {
        let preparedCards = swapFaces
            ? rawFileCards.map { Flashcard(front: $0.back, back: $0.front) }
            : rawFileCards
        guard let deck = selectedDeck else { return preparedCards }
        return preparedCards.filter { newCard in
            !deck.cards.contains { existingCard in
                existingCard.front.localizedCaseInsensitiveCompare(newCard.front) == .orderedSame &&
                existingCard.back.localizedCaseInsensitiveCompare(newCard.back) == .orderedSame
            }
        }
    }

    var duplicatesCount: Int {
        return rawFileCards.count - cardsToImport.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) { // Zmieniamy Form na VStack

                // --- GÓRNE USTAWIENIA (Jako lista o stałym rozmiarze) ---
                List {
                    Section(header: Text("Destination Deck")) {
                        HStack(alignment: .center) {
                            Menu {
                                Picker("Deck", selection: $selectedDeckId) {
                                    ForEach(store.decks) { deck in
                                        Text(deck.name).tag(deck.id)
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
                    }

                    Section(header:
                        HStack {
                            Text("Preview")
                                // System automatycznie formatuje nagłówek,
                                // ale upewniamy się co do wielkości liter przycisku

                            Spacer()

                        if !rawFileCards.isEmpty {
                                    // Mała tabela statystyk po prawej stronie
                                    VStack(alignment: .trailing, spacing: 2) {

                                        HStack(spacing: 8) {
                                            Text("In file: \(rawFileCards.count)")
                                            if duplicatesCount > 0 {
                                                Text("Duplicates: \(duplicatesCount)")
                                                    .foregroundStyle(.orange)
                                            }
                                            Text("To import: \(cardsToImport.count)")
                                                .foregroundStyle(.green)
                                                .fontWeight(.bold)
                                        }
                                        .font(.system(size: 10))
                                    }
                                    .padding(.trailing, 4)
                                }
                        }
                    ) {
                    }

                }
                .listStyle(.insetGrouped)
                .frame(height: 312) // Ograniczamy wysokość sekcji ustawień
                .scrollDisabled(true)

                VStack(alignment: .leading, spacing: 0) {

                    if cardsToImport.isEmpty {
                        VStack {
                            Spacer()
                            ContentUnavailableView("No cards to display", systemImage: "doc.text.magnifyingglass", description: Text("Select a file to see preview"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    } else {
                        // Tabela podglądu zachowująca się jak List w HomeView
                        VStack(spacing: 0) {
                            // Nagłówek tabeli
                            HStack {
                                Text(selectedDeck?.frontLabel ?? "Front")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Divider().frame(height: 24).padding(.horizontal, 10)
                                Text(selectedDeck?.backLabel ?? "Back")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.system(size: 16, design: .default))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)

                            List {
                                ForEach(cardsToImport) { card in
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
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                }
                            }
                            .listStyle(.plain) // Czysty wygląd bez marginesów Formy
                            .environment(\.defaultMinListRowHeight, 30)
                        }
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
                .padding(.top, 10)
                .background(Color(uiColor: .systemGroupedBackground))
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
                            store.saveImportedCards(cardsToImport, to: targetId)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(selectedDeckId == nil || cardsToImport.isEmpty)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
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
                            // Pobieramy nazwę pliku z URL
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
// Helper to make text readable on dark/light mode if needed,
// though standard .primary works fine.


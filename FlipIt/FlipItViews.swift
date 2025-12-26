import SwiftUI

// --- 1. HOME VIEW ---

struct HomeView: View {
    @StateObject var store = FlipItStore()
    @State private var showAddDeckAlert = false
    @State private var newDeckName = ""
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(store.decks) { deck in
                    NavigationLink(destination: DeckDetailView(store: store, deck: deck)) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(deck.name)
                                    .font(.headline)
                                Spacer()
                                Text("\(deck.cards.filter { $0.isLearned }.count) / \(deck.cards.count)")
                                    .font(.subheadline) // Trochę większa czcionka dla czytelności
                                    .foregroundStyle(.secondary)
                            }
                            
                            ProgressView(value: deck.progress)
                                .tint(deck.progress == 1.0 ? .green : .blue)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    if store.settings.confirmDelete {
                        // In a real app, you'd trigger a confirmation dialog here.
                        // SwiftUI swipe-to-delete + alert is tricky, so we rely on standard behavior for now
                        // or simply delete immediately if confirmed.
                        store.deleteDeck(at: indexSet)
                    } else {
                        store.deleteDeck(at: indexSet)
                    }
                }
            }
            .navigationTitle("FlipIt")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddDeckAlert = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // Footer Button
            .safeAreaInset(edge: .bottom) {
                NavigationLink(destination: StudySetupView(store: store)) {
                    Text("START STUDYING")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.bottom, 10)
            }
            .alert("New Deck", isPresented: $showAddDeckAlert) {
                TextField("Deck Name", text: $newDeckName)
                Button("Cancel", role: .cancel) { }
                Button("Add") {
                    if !newDeckName.isEmpty {
                        store.addDeck(name: newDeckName)
                        newDeckName = ""
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(store: store)
            }
        }
    }
}

// --- 2. DECK PREVIEW & EDIT ---

struct DeckDetailView: View {
    @ObservedObject var store: FlipItStore
    var deck: Deck
    
    // Stany do obsługi okienek
    @State private var showAddCard = false
    @State private var editingCard: Flashcard? // Przechowuje fiszkę, którą właśnie edytujemy
    
    @State private var cardToDelete: Flashcard? // Zapamiętuje, którą fiszkę chcemy usunąć
    @State private var showDeleteConfirmation = false // Steruje widocznością alertu
    
    // Zmienne tymczasowe dla formularzy
    @State private var tempFront = ""
    @State private var tempBack = ""
    
    @State private var showDuplicateAlert = false
    @State private var duplicateMessage = ""
    @State private var isSavingNext = false // Zapamiętuje, czy kliknięto "Add Next"
    
    var body: some View {
        List {
            if deck.cards.isEmpty {
                Text("No cards yet. Add some!")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(deck.cards) { card in
                    HStack {
                        // Kropka statusu
                        Image(systemName: card.isLearned ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(card.isLearned ? .green : .red)
                            .font(.system(size: 20))
                        
                        // Treść fiszki
                        VStack(alignment: .leading) {
                            Text(card.front)
                                .font(.headline)
                            Text(card.back)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // --- PRZYCISKI AKCJI ---
                        HStack(spacing: 15) {
                            // Edycja (Ołówek lub Dwie Strzałki)
                            Button(action: {
                                // Przygotuj dane do edycji
                                tempFront = card.front
                                tempBack = card.back
                                editingCard = card
                            }) {
                                Image(systemName: "pencil") // Możesz zmienić na "arrow.triangle.2.circlepath"
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(BorderlessButtonStyle()) // Ważne, żeby kliknięcie nie łapało całego wiersza
                            
                            // Usuwanie (Śmietnik)
                            Button(action: {
                                if store.settings.confirmDelete {
                                    // 1. Jeśli w ustawieniach jest potwierdzanie -> Pokaż alert
                                    cardToDelete = card
                                    showDeleteConfirmation = true
                                } else {
                                    // 2. Jeśli nie ma potwierdzania -> Usuń od razu
                                    withAnimation {
                                        store.deleteCard(deckId: deck.id, cardId: card.id)
                                    }
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
                }
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            Button(action: {
                tempFront = ""
                tempBack = ""
                showAddCard = true
            }) {
                Image(systemName: "plus")
            }
        }
        
        // --- SHEET 1: DODAWANIE ---
        .sheet(isPresented: $showAddCard) {
            NavigationStack {
                Form {
                    TextField("Front (Concept)", text: $tempFront)
                        .submitLabel(.next)
                    
                    TextField("Back (Definition)", text: $tempBack)
                        .submitLabel(.done)
                }
                .navigationTitle("Add Card")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showAddCard = false }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        HStack(spacing: 20) {
                            // PRZYCISK 1: Add Next
                            Button("Add Next") {
                                checkAndSave(isNext: true)
                            }
                            
                            // PRZYCISK 2: Save
                            Button("Save") {
                                checkAndSave(isNext: false)
                            }
                            .fontWeight(.bold)
                        }
                    }
                }
                // ALERT DUPLIKATU (podpięty wewnątrz sheet)
                .alert("Duplicate Found", isPresented: $showDuplicateAlert) {
                    Button("Cancel", role: .cancel) { } // Anuluj -> zostań w edycji
                    Button("Add Anyway") {
                        performSave() // Dodaj mimo to
                    }
                } message: {
                    Text("A card with similar content already exists:\n\n'\(duplicateMessage)'\n\nDo you want to add it anyway?")
                }
            }
            .presentationDetents([.medium])
        }
        
        // --- SHEET 2: EDYCJA ---
        .sheet(item: $editingCard) { card in
            NavigationStack {
                Form {
                    TextField("Front", text: $tempFront)
                    TextField("Back", text: $tempBack)
                }
                .navigationTitle("Edit Card")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editingCard = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.updateCardContent(deckId: deck.id, cardId: card.id, front: tempFront, back: tempBack)
                            editingCard = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        
        .alert("Delete Card", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                cardToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let card = cardToDelete {
                    withAnimation {
                        store.deleteCard(deckId: deck.id, cardId: card.id)
                    }
                }
                cardToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this card?")
        }
    }
    func performSave() {
        // 1. Zapisz fiszkę
        store.addCard(to: deck.id, front: tempFront, back: tempBack)
        
        // 2. Obsłuż zachowanie po zapisie
        if isSavingNext {
            // Jeśli to było "Add Next": wyczyść pola, nie zamykaj okna
            tempFront = ""
            tempBack = ""
        } else {
            // Jeśli to było zwykłe "Save": zamknij okno
            showAddCard = false
        }
    }

    // Funkcja sprawdzająca duplikaty przed zapisem
    func checkAndSave(isNext: Bool) {
        // Walidacja pustych pól
        guard !tempFront.isEmpty, !tempBack.isEmpty else { return }
        
        isSavingNext = isNext // Zapamiętaj intencję użytkownika
        
        // Sprawdź czy istnieje fiszka z takim samym Frontem LUB Tyłem
        if let duplicate = deck.cards.first(where: { $0.front == tempFront || $0.back == tempBack }) {
            // Znaleziono duplikat! Przygotuj komunikat
            duplicateMessage = "\(duplicate.front) - \(duplicate.back)"
            showDuplicateAlert = true
        } else {
            // Brak duplikatu, zapisz od razu
            performSave()
        }
    }
}

// --- 3. SETTINGS VIEW ---

struct SettingsView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("General")) {
                    Toggle("Confirm Deletion", isOn: $store.settings.confirmDelete)
                }
                
                Section(header: Text("Study Algorithm"), footer: Text("How many turns until an unknown card reappears.")) {
                    Stepper("Retry Frequency: \(store.settings.retryFrequency)", value: $store.settings.retryFrequency, in: 1...10)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") {
                    store.saveData() // Save settings
                    dismiss()
                }
            }
        }
    }
}

// --- 4. STUDY SETUP ---

struct StudySetupView: View {
    @ObservedObject var store: FlipItStore
    
    // 1. @AppStorage automatycznie zapisuje prostą wartość Boolean w pamięci telefonu
    @AppStorage("last_onlyUnlearned") private var onlyUnlearned = false
    
    // 2. Dla Zbioru (Set) musimy użyć zwykłego @State i ręcznie go zapisać/wczytać
    @State private var selectedDecks: Set<UUID> = []
    
    @State private var startSession = false
    
    var body: some View {
        Form {
            Section(header: Text("Select Decks")) {
                ForEach(store.decks) { deck in
                    HStack {
                        Image(systemName: selectedDecks.contains(deck.id) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(.blue)
                        Text(deck.name)
                        Spacer()
                        Text("\(deck.cards.filter { $0.isLearned }.count) / \(deck.cards.count)")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedDecks.contains(deck.id) {
                            selectedDecks.remove(deck.id)
                        } else {
                            selectedDecks.insert(deck.id)
                        }
                    }
                }
            }
            
            Section {
                // To pole dzięki @AppStorage zapamięta stan samo
                Toggle("Only Unlearned Cards", isOn: $onlyUnlearned)
            }
            
            Section {
                Button("START SESSION") {
                    if !selectedDecks.isEmpty {
                        saveSelectedDecks() // <--- Zapisujemy wybór przed startem
                        startSession = true
                    }
                }
                .disabled(selectedDecks.isEmpty)
                .listRowBackground(selectedDecks.isEmpty ? Color.gray.opacity(0.2) : Color.green)
                .foregroundStyle(selectedDecks.isEmpty ? .gray : .white)
                .font(.headline)
            }
        }
        .navigationTitle("Study Setup")
        .onAppear {
            loadSelectedDecks() // <--- Wczytujemy wybór przy wejściu
        }
        .navigationDestination(isPresented: $startSession) {
            StudySessionView(store: store,
                             selectedDeckIds: Array(selectedDecks),
                             onlyUnlearned: onlyUnlearned)
        }
    }
    func saveSelectedDecks() {
            // Zamieniamy Zbiór UUID na dane (JSON) i zapisujemy w UserDefaults
            if let encoded = try? JSONEncoder().encode(selectedDecks) {
                UserDefaults.standard.set(encoded, forKey: "last_selectedDecks")
            }
        }
        
        func loadSelectedDecks() {
            // Pobieramy dane z UserDefaults
            if let data = UserDefaults.standard.data(forKey: "last_selectedDecks"),
               let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
                
                // WAŻNE: Filtrujemy ID. Jeśli usunąłeś jakiś zestaw w międzyczasie,
                // nie chcemy próbować uczyć się z nieistniejącego zestawu.
                let existingIDs = Set(store.decks.map { $0.id })
                self.selectedDecks = decoded.intersection(existingIDs)
            }
        }
    }

// --- 5. STUDY SESSION (THE CORE) ---

struct StudySessionView: View {
    @ObservedObject var store: FlipItStore
    var selectedDeckIds: [UUID]
    var onlyUnlearned: Bool
    
    // Internal State
    @State private var sessionQueue: [(card: Flashcard, deckId: UUID)] = []
    @State private var isFlipped = false
    @State private var isSessionActive = true
    @State private var initialLoadDone = false
    
    // Stats
    @State private var learnedCount = 0
    @State private var totalCount = 0
    
    var body: some View {
        VStack {
            if !isSessionActive {
                VStack(spacing: 20) {
                    Text("Session Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("You've gone through all cards.")
                    Button("Finish") {
                        // Pop back logic handled by navigation stack usually,
                        // but here we can just show empty state
                    }
                }
            } else if sessionQueue.isEmpty {
                 if initialLoadDone {
                     VStack {
                         Text("🎉")
                             .font(.system(size: 80))
                         Text("All cards mastered!")
                             .font(.title)
                             .padding()
                     }
                 } else {
                     ProgressView()
                 }
            } else {
                // --- TOP STATS ---
                HStack {
                    Text("Mastered: \(learnedCount) / \(totalCount)")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }
                .padding()
                
                // --- CARD AREA ---
                ZStack {
                    let current = sessionQueue[0].card
                    
                    // Back (Definition)
                    CardView(text: current.back, backgroundColor: .white)
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    
                    // Front (Concept)
                    CardView(text: current.front, backgroundColor: .white)
                        .opacity(isFlipped ? 0 : 1)
                }
                .rotation3DEffect(
                    .degrees(isFlipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
                        isFlipped.toggle()
                    }
                }
                .padding()
                
                Spacer()
                
                // --- CONTROLS ---
                HStack(spacing: 30) {
                    // Unknown (Red X)
                    Button(action: markUnknown) {
                        Image(systemName: "xmark")
                            .font(.system(size: 30, weight: .bold))
                            .frame(width: 70, height: 70)
                            .background(Color.red.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    
                    // Flip (Blue Arrows)
                    Button(action: {
                        withAnimation { isFlipped.toggle() }
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 25, weight: .bold))
                            .frame(width: 60, height: 60)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Circle())
                    }
                    
                    // Known (Green Check)
                    Button(action: markKnown) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                            .frame(width: 70, height: 70)
                            .background(Color.green.opacity(0.9))
                            .foregroundStyle(.white)
                            .clipShape(Circle())
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
            loadSession()
        }
    }
    
    // --- LOGIC ---
    
    func loadSession() {
        var pool: [(card: Flashcard, deckId: UUID)] = []
        
        for deck in store.decks where selectedDeckIds.contains(deck.id) {
            for card in deck.cards {
                if onlyUnlearned && card.isLearned { continue }
                pool.append((card, deck.id))
            }
        }
        
        pool.shuffle()
        sessionQueue = pool
        totalCount = pool.count
        
        // Calculate initial stats based on current pool
        learnedCount = pool.filter { $0.card.isLearned }.count
        
        initialLoadDone = true
    }
    
    func markKnown() {
            guard !sessionQueue.isEmpty else { return }
            let currentItem = sessionQueue[0]
            
            // POPRAWKA: Zwiększ licznik tylko jeśli karta wcześniej NIE była nauczona.
            // Jeśli była już "zielona", to nie dodajemy punktu drugi raz.
            if !currentItem.card.isLearned {
                 learnedCount += 1
            }
            
            // Aktualizujemy bazę danych
            store.updateCardStatus(deckId: currentItem.deckId, cardId: currentItem.card.id, isLearned: true)
            
            // Usuwamy z kolejki (bo już umiemy)
            withAnimation {
                isFlipped = false
                sessionQueue.removeFirst()
            }
        }
        
        func markUnknown() {
            guard !sessionQueue.isEmpty else { return }
            
            // Pobieramy element jako zmienną (var), żeby móc zaktualizować jej lokalny stan
            var currentItem = sessionQueue[0]
            
            // POPRAWKA: Jeśli karta była wcześniej uznana za nauczoną, musimy zmniejszyć licznik.
            if currentItem.card.isLearned {
                learnedCount -= 1
            }

            // Aktualizujemy bazę danych
            store.updateCardStatus(deckId: currentItem.deckId, cardId: currentItem.card.id, isLearned: false)
            
            // Ważne: Aktualizujemy stan lokalnej kopii karty w kolejce na 'false'.
            // Dzięki temu, jeśli ta karta wróci za 3 tury i znowu klikniemy X, licznik nie spadnie ponownie.
            currentItem.card.isLearned = false
            
            // Algorytm powtórek (Spaced Repetition)
            withAnimation {
                isFlipped = false
                sessionQueue.removeFirst()
                
                // Wstawiamy z powrotem do kolejki z nowym statusem (isLearned = false)
                let offset = store.settings.retryFrequency
                let insertIndex = min(offset, sessionQueue.count)
                sessionQueue.insert(currentItem, at: insertIndex)
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

// Helper to make text readable on dark/light mode if needed,
// though standard .primary works fine.

import SwiftUI

struct AIGenerateView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedDeckId: UUID?
    @State private var showNewDeckSheet = false

    // Zmienne stanu dla AI (zawiera wyłącznie unikalne karty, duplikaty są usuwane automatycznie)
    @State private var generatedCards: [Flashcard] = []

    // Opcje generowania wybrane przez użytkownika
    @State private var cardCount: Int = 100
    @State private var selectedLevel: String = "B1"
    @State private var pendingLevel: String = "B1"
    @State private var showLevelChangeAlert: Bool = false
    @State private var additionalRemarks: String = ""

    @State private var isGenerating = false

    // Obsługa błędów i potwierdzeń
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDiscardAlert = false

    init(store: FlipItStore, initialDeckId: UUID? = nil) {
        self.store = store
        let defaultSelection = initialDeckId ?? store.decks.first?.id
        self._selectedDeckId = State(initialValue: defaultSelection)
        let initialDeck = store.decks.first(where: { $0.id == defaultSelection })
        let deckLevel = (initialDeck?.difficultyLevel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? initialDeck!.difficultyLevel!
            : "B1"
        self._selectedLevel = State(initialValue: deckLevel)
        self._pendingLevel = State(initialValue: deckLevel)
    }

    var selectedDeck: Deck? {
        guard let id = selectedDeckId else { return nil }
        return store.decks.first(where: { $0.id == id })
    }

    var currentDeckName: String {
        selectedDeck?.name ?? "Select Deck"
    }

    func getLangCode(_ code: String) -> String {
        return String(code.prefix(2)).uppercased()
    }

    var availableLevels: [String] {
        var base = ["A1", "A2", "B1", "B2", "C1", "C2", "General"]
        if let deckLevel = selectedDeck?.difficultyLevel,
           !deckLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !base.contains(where: { $0.caseInsensitiveCompare(deckLevel) == .orderedSame }) {
            base.insert(deckLevel, at: 0)
        }
        return base
    }

    func syncSettingsWithSelectedDeck() {
        guard let deck = selectedDeck else { return }
        let deckLevel = (deck.difficultyLevel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? deck.difficultyLevel!
            : "B1"
        selectedLevel = deckLevel
        pendingLevel = deckLevel
    }

    private var levelBinding: Binding<String> {
        Binding(
            get: { selectedLevel },
            set: { newLevel in
                if let deckLevel = selectedDeck?.difficultyLevel,
                   !deckLevel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   newLevel.caseInsensitiveCompare(deckLevel) != .orderedSame {
                    pendingLevel = newLevel
                    showLevelChangeAlert = true
                } else {
                    selectedLevel = newLevel
                }
            }
        )
    }

    @ObservedObject var authManager: AuthManager = .shared
    @State private var showAuthSheet: Bool = false

    var body: some View {
        NavigationStack {
            if !authManager.isAuthenticated {
                authRequiredView
            } else if !store.settings.isPremiumUser {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.yellow)
                            .padding(.top, 24)

                        VStack(spacing: 8) {
                            Text("FlipIt Pro Required")
                                .font(.title2.bold())
                                .fixedSize(horizontal: false, vertical: true)
                            Text("AI flashcard generation is available exclusively for FlipIt Pro users.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 24)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Label("Unlimited AI flashcard generation", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Label("Custom topic, level & vocabulary prompts", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                            Label("Instant dual-language deck population", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .font(.subheadline)
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.appSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)

                        Button(action: {
                            store.settings.isPremiumUser = true
                            store.saveData()
                        }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Unlock FlipIt Pro")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
                .background(Color.appGroupedBackground)
                .navigationTitle("AI Generate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }.fontWeight(.bold)
                    }
                }
            } else {
                List {
                    // SEKCJA 1: TALIA DOCELOWA
                    Section("Destination Deck") {
                        HStack(alignment: .center) {
                            Menu {
                                Picker("Deck", selection: $selectedDeckId) {
                                    ForEach(store.decks) { deck in
                                        Text(deck.name).tag(Optional(deck.id))
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(LocalizedStringKey(currentDeckName))
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundStyle(.blue).lineLimit(1)
                                        .frame(minWidth: 80, maxWidth: 160)

                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.caption2).foregroundStyle(.blue)
                                }
                                .padding(.vertical, 6).padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.1)).clipShape(Capsule())
                            }
                            .onChange(of: selectedDeckId) { syncSettingsWithSelectedDeck() }

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
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                    }

                    // SEKCJA 2: USTAWIENIA GENEROWANIA (zamiast wpisywania tekstu)
                    Section {
                        // Liczba fiszek (tylko obramowane pole tekstowe, zwykły kolor czcionki)
                        HStack {
                            Text("Number of Cards")
                            Spacer()
                            TextField("100", value: $cardCount, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .font(.body)
                                .foregroundStyle(Color.primary)
                                .frame(width: 68, height: 32)
                                .background(Color.appGroupedBackground.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                                )
                        }

                        // Poziom języka (domyślnie z talii; zmiana wywołuje alert)
                        Picker("Language Level", selection: levelBinding) {
                            ForEach(availableLevels, id: \.self) { level in
                                Text(LocalizedStringKey(level)).tag(level)
                            }
                        }

                        // Dodatkowe uwagi
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Additional Remarks")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("Optional (e.g. travel vocabulary, irregular verbs)", text: $additionalRemarks, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    } header: {
                        HStack {
                            Text("Instructions")

                            Spacer()

                            // PRZYCISK GENERUJ: automatycznie dopasowuje szerokość bez zawijania tekstu
                            Button(action: generateWithAI) {
                                HStack(spacing: 5) {
                                    if isGenerating {
                                        ProgressView()
                                            .controlSize(.mini)
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(isGenerating ? "Generating..." : "Generate")
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                }
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 14)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                            .disabled(isGenerating || selectedDeckId == nil || cardCount <= 0)
                            .opacity((isGenerating || selectedDeckId == nil || cardCount <= 0) ? 0.6 : 1.0)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    // SEKCJA 3: PODGLĄD WYGENEROWANYCH KART
                    Section {
                        if generatedCards.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary.opacity(0.6))
                                Text("No cards generated")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Review instructions above and tap Generate")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .listRowBackground(Color.appSecondaryGroupedBackground)
                        } else {
                            // Nagłówek kolumn
                            HStack {
                                Text("\(selectedDeck?.frontLabel ?? "Front") (\(getLangCode(selectedDeck?.frontLanguage ?? "")))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Divider()
                                    .frame(height: 18)
                                    .padding(.horizontal, 8)

                                Text("\(selectedDeck?.backLabel ?? "Back") (\(getLangCode(selectedDeck?.backLanguage ?? "")))")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.appSecondaryGroupedBackground.opacity(0.85))

                            // Lista unikalnych kart
                            ForEach(generatedCards) { card in
                                HStack(alignment: .center) {
                                    Text(card.front)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Divider()
                                        .frame(height: 18)
                                        .padding(.horizontal, 8)

                                    Text(card.back)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(Color.primary)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                    } header: {
                        HStack {
                            Text("Preview")
                            Spacer()
                            if !generatedCards.isEmpty {
                                Text("Generated: \(generatedCards.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .appInsetGroupedListStyle()
                .navigationTitle("AI Generate")
                .navigationBarTitleDisplayMode(.large)
                .onAppear {
                    syncSettingsWithSelectedDeck()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            if !generatedCards.isEmpty {
                                showDiscardAlert = true
                            } else {
                                dismiss()
                            }
                        }
                        .fontWeight(.bold)
                        .disabled(isGenerating)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            if let targetId = selectedDeckId {
                                store.saveImportedCards(generatedCards, to: targetId)
                                dismiss()
                            }
                        }
                        .fontWeight(.bold)
                        .disabled(selectedDeckId == nil || generatedCards.isEmpty || isGenerating)
                    }
                }
                .interactiveDismissDisabled(!generatedCards.isEmpty || isGenerating)
                .sheet(isPresented: $showNewDeckSheet) {
                    NewDeckSheet(store: store) { newId in
                        self.selectedDeckId = newId
                        syncSettingsWithSelectedDeck()
                    }
                    .presentationDetents([.large])
                }
                .alert("AI Error", isPresented: $showError) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(errorMessage)
                }
                .alert("Discard Generated Cards?", isPresented: $showDiscardAlert) {
                    Button("Keep Editing", role: .cancel) { }
                    Button("Discard", role: .destructive) {
                        dismiss()
                    }
                } message: {
                    Text("The generated cards have not been saved to your deck yet. Are you sure you want to discard them?")
                }
                .alert(LocalizedStringKey("Change Language Level"), isPresented: $showLevelChangeAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Change") {
                        selectedLevel = pendingLevel
                    }
                } message: {
                    Text(String(
                        format: NSLocalizedString("This deck is labeled as '%@', but you selected '%@'. Are you sure you want to generate flashcards at a different level?", comment: ""),
                        selectedDeck?.difficultyLevel ?? "",
                        pendingLevel
                    ))
                }
            }
        }
    }

    // --- 2. LOGIKA GENEROWANIA (ŁĄCZENIE USER PROMPT Z SYSTEM PROMPT ORAZ ZAPOBIEGANIE DUPLIKATOM) ---
    func generateWithAI() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        guard let deck = selectedDeck else { return }

        isGenerating = true
        generatedCards = []

        // 1. Niejawne doklejenie konfiguracji, tytułu, opisu, etykiet, poziomu i reguł
        var promptLines: [String] = [
            "Topic/Context: \(deck.name)",
            deck.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? ""
                : "Description: \(deck.description.trimmingCharacters(in: .whitespacesAndNewlines))",
            "Number of flashcards: around \(max(cardCount, 1)) pairs",
            "Level: \(selectedLevel)",
            "Side 1 (\(deck.frontLabel)): \(deck.frontLanguage)",
            "Side 2 (\(deck.backLabel)): \(deck.backLanguage)",
            "Length & conciseness rule: Keep entries as short and concise as possible wherever extra detail is not needed. ABSOLUTE HARD LIMIT: maximum \(AppLimits.cardContent) characters per side. Under no circumstances exceed \(AppLimits.cardContent) characters.",
            "Casing rule: Use lowercase letters unless it is a proper noun, acronym, or language capitalization rule."
        ]

        let trimmedRemarks = additionalRemarks.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedRemarks.isEmpty {
            promptLines.append("Additional remarks: \(trimmedRemarks)")
        } else {
            promptLines.append("Additional remarks: none")
        }

        let basePrompt = promptLines.filter { !$0.isEmpty }.joined(separator: "\n")

        // 2. Przekazanie modelowi pełnej listy wszystkich istniejących fiszek (par) z talii bez żadnego limitu ilości
        var existingCardsRule = ""
        if !deck.cards.isEmpty {
            let allPairs = deck.cards
                .map { card -> String in
                    let front = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
                    let back = card.back.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !front.isEmpty && !back.isEmpty {
                        return "\(front) = \(back)"
                    } else if !front.isEmpty {
                        return front
                    } else {
                        return back
                    }
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")

            if !allPairs.isEmpty {
                existingCardsRule = """

                --------------------------------------------------
                EXISTING FLASHCARDS IN THIS DECK (DO NOT REPEAT):
                \(allPairs)

                CRITICAL: Do NOT generate or repeat any of the pairs, words, concepts, or close synonyms listed above. All generated flashcards MUST be strictly new and unique!
                """
            }
        }

        // 3. Techniczne wymogi formatu wyjściowego
        let technicalSuffix = """

        --------------------------------------------------
        STRICT OUTPUT FORMAT RULES:
        1. Produce valid CSV data only.
        2. Separator: semicolon (;).
        3. Format: Side1;Side2 (each pair in a new line)
        4. Do NOT output headers.
        5. Do NOT use markdown code blocks (```).
        6. Do NOT write any introduction or explanation. Just raw data.
        """

        let finalPrompt = basePrompt + existingCardsRule + technicalSuffix

        Task {
            do {
                let service = GeminiService(model: store.settings.geminiModel)
                let csvString = try await service.generateFlashcards(from: finalPrompt)

                await MainActor.run {
                    let parsedCards = store.parseCSV(content: csvString)

                    // Automatyczne usuwanie duplikatów:
                    // 1) z kartami już znajdującymi się w talii docelowej
                    // 2) wewnętrznych powtórzeń w wygenerowanym pakiecie
                    var seenFronts = Set<String>()
                    if let deck = selectedDeck {
                        for c in deck.cards {
                            seenFronts.insert(c.front.normalizedCardKey)
                        }
                    }

                    var uniqueCleanCards: [Flashcard] = []
                    for card in parsedCards {
                        // Twardy limit 400 znaków na stronę: fiszki przekraczające limit są od razu odrzucane (traktowane jak duplikaty)
                        let frontText = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
                        let backText = card.back.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard frontText.count <= AppLimits.cardContent && backText.count <= AppLimits.cardContent else {
                            continue
                        }

                        let key = card.front.normalizedCardKey
                        guard !key.isEmpty else { continue }
                        if !seenFronts.contains(key) {
                            seenFronts.insert(key)
                            uniqueCleanCards.append(card)
                        }
                    }

                    self.generatedCards = uniqueCleanCards
                    self.isGenerating = false

                    if self.generatedCards.isEmpty {
                        self.errorMessage = NSLocalizedString("AI returned empty data or invalid format.", comment: "")
                        self.showError = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                    self.isGenerating = false
                }
            }
        }
    }

    private var authRequiredView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.blue)
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    Text("Sign In Required")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("AI flashcard generation requires a FlipIt account. Sign in to generate flashcards and sync them with your cloud library.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Label("Generate cards with AI", systemImage: "sparkles")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Auto-sync cards to your account", systemImage: "icloud.fill")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Share custom decks in Community", systemImage: "person.2.fill")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSecondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                Button(action: {
                    showAuthSheet = true
                }) {
                    HStack {
                        Image(systemName: "person.fill.badge.plus")
                        Text("Sign In to FlipIt")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appGroupedBackground)
        .navigationTitle("AI Generate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.fontWeight(.bold)
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthPromptSheet(authManager: authManager, canSkip: false)
        }
    }
}

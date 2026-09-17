import SwiftUI

struct AIGenerateView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    @State private var selectedDeckId: UUID?
    @State private var swapFaces = false
    @State private var skipDuplicates = true
    @State private var showNewDeckSheet = false

    // Zmienne stanu dla AI
    @State private var generatedCards: [Flashcard] = []

    // To jest tekst widoczny dla użytkownika (edytowalny)
    @State private var promptText: String = ""
    @State private var isGenerating = false

    // Obsługa błędów
    @State private var showError = false
    @State private var errorMessage = ""

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

    func getLangCode(_ code: String) -> String {
        return String(code.prefix(2)).uppercased()
    }

    var processedCards: [Flashcard] {
        if swapFaces {
            return generatedCards.map { Flashcard(front: $0.back, back: $0.front) }
        } else {
            return generatedCards
        }
    }

    func isDuplicate(_ card: Flashcard) -> Bool {
        guard let deck = selectedDeck else { return false }
        return deck.cards.contains { existingCard in
            let existingFront = existingCard.front.trimmingCharacters(in: .whitespaces)
            let existingBack = existingCard.back.trimmingCharacters(in: .whitespaces)
            let newFront = card.front.trimmingCharacters(in: .whitespaces)
            let newBack = card.back.trimmingCharacters(in: .whitespaces)

            return existingFront.localizedCaseInsensitiveCompare(newFront) == .orderedSame &&
                   existingBack.localizedCaseInsensitiveCompare(newBack) == .orderedSame
        }
    }

    var duplicatesCount: Int {
        return processedCards.filter { isDuplicate($0) }.count
    }

    var finalCardsToImport: [Flashcard] {
        return processedCards.filter { !isDuplicate($0) }
    }

    // 1. BUDOWANIE CZYTELNEGO PROMPTU DLA UŻYTKOWNIKA
    func updateDefaultPrompt() {
        guard let deck = selectedDeck else { return }

        promptText = """
        Topic/Context: \(deck.name) (\(deck.description))
        Number of flashcards: around 100 pairs
        Level: B1
        Side 1 (\(deck.frontLabel)): \(deck.frontLanguage)
        Side 2 (\(deck.backLabel)): \(deck.backLanguage)
        Remarks: Use max \(AppLimits.label) letters per side. Nouns. Apply lowercase unless it's a proper noun.
        Additional remarks: no
        """
    }

    var body: some View {
        NavigationStack {
            if !store.settings.isPremiumUser {
                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "crown.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow)

                    VStack(spacing: 8) {
                        Text("FlipIt Pro Required")
                            .font(.title2.bold())
                        Text("AI flashcard generation is powered by Google Gemini and is available exclusively for FlipIt Pro users.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Label("Unlimited AI flashcard generation", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.primary)
                        Label("Custom topic, level & vocabulary prompts", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.primary)
                        Label("Instant dual-language deck population", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.primary)
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

                    Spacer()
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
                VStack(spacing: 0) {

                    // --- CZĘŚĆ GÓRNA: USTAWIENIA (NIERUCHOMA) ---
                    List {
                        // SEKCJA 1: WYBÓR TALII
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
                            .onChange(of: selectedDeckId) { updateDefaultPrompt() }

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

                    // SEKCJA 2: INSTRUKCJE (User Prompt)
                    Section(header:
                        HStack {
                            Text("Instructions")
                            Spacer()

                            // --- PRZYCISK GENERATE ---
                            Button(action: generateWithAI) {
                                HStack(spacing: 4) {
                                    if isGenerating {
                                        ProgressView().controlSize(.mini)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(isGenerating ? "Generating..." : "Generate")
                                        .fontWeight(.bold)
                                }
                                .font(.caption)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                            }
                            .disabled(isGenerating || promptText.isEmpty)
                            .opacity((isGenerating || promptText.isEmpty) ? 0.6 : 1.0)
                        }
                    ) {
                        TextEditor(text: $promptText)
                            .frame(height: 90) // Nieco wyższy, bo więcej linii
                            .font(.system(size: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )

                        Toggle("Swap Columns", isOn: $swapFaces)
                    }

                    // SEKCJA 3: NAGŁÓWEK PREVIEW
                    Section(header:
                        HStack {
                            Text("Preview")
                            Spacer()
                            if !generatedCards.isEmpty {
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(spacing: 8) {
                                        Text("Generated: \(generatedCards.count)")
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
                    ) { }
                }
                .appInsetGroupedListStyle()
                .frame(height: 370) // Stała wysokość panelu górnego
                .scrollDisabled(true)

                // --- CZĘŚĆ DOLNA: LISTA KART ---
                VStack(alignment: .leading, spacing: 0) {
                    if generatedCards.isEmpty {
                        VStack {
                            Spacer()
                            ContentUnavailableView("No cards generated", systemImage: "sparkles", description: Text("Review instructions above and tap Generate"))
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.appSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 0) {
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

                            List {
                                ForEach(processedCards) { card in
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
            .navigationTitle("AI Generate")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if promptText.isEmpty { updateDefaultPrompt() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.fontWeight(.bold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let targetId = selectedDeckId {
                            store.saveImportedCards(finalCardsToImport, to: targetId)
                            dismiss()
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(selectedDeckId == nil || finalCardsToImport.isEmpty)
                }
            }
            .sheet(isPresented: $showNewDeckSheet) {
                NewDeckSheet(store: store) { newId in self.selectedDeckId = newId }
                    .presentationDetents([.large])
            }
            .alert("AI Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            }
        }
    }

    // --- 2. LOGIKA GENEROWANIA (ŁĄCZENIE USER PROMPT Z SYSTEM PROMPT) ---
    func generateWithAI() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif

        isGenerating = true
        generatedCards = []

        // Tutaj doklejamy techniczne wymogi, których użytkownik nie musi widzieć/edytować
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

        // Łączymy to co napisał user z wymogami technicznymi
        let finalPrompt = promptText + technicalSuffix

        Task {
            do {
                let service = GeminiService()
                let csvString = try await service.generateFlashcards(from: finalPrompt)

                await MainActor.run {
                    self.generatedCards = store.parseCSV(content: csvString)
                    self.isGenerating = false

                    if self.generatedCards.isEmpty {
                        self.errorMessage = "AI returned empty data or invalid format."
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
}


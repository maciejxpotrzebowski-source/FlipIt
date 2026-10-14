import SwiftUI

struct DeckDetailView: View {
    @ObservedObject var store: FlipItStore
    let deckId: UUID
    @State private var showResetProgressConfirm = false

    init(store: FlipItStore, deck: Deck) {
        self.store = store
        self.deckId = deck.id
    }

    @Environment(\.dismiss) var dismiss

    @State private var originalDeckSnapshot: Deck? = nil
    @State private var isPressingInfoCard = false

    @State private var showAddCard = false
    @State private var showEditDeck = false
    @State private var showImportSheet = false
    @State private var showDeleteDeckAlert = false
    @State private var showGenerateSheet = false
    @State private var showPublishSheet = false
    @State private var showDiscardConfirmAlert = false
    @State private var showSaveBeforePublishAlert = false

    // Community Sync & Author Management
    @State private var updateAvailable = false
    @State private var remoteDeck: SharedDeck? = nil
    @State private var showSyncSheet = false
    @State private var isUpdatingOnMarket = false
    @State private var showDeleteFromMarketAlert = false
    @State private var showDeleteFromMarketSuccessAlert = false
    @State private var showUpdateSuccessAlert = false
    @State private var marketActionErrorMessage: String? = nil
    @State private var showMarketErrorAlert = false
    @State private var showUpToDateAlert = false
    @State private var showDeletePublishedDeckDialog = false

    var activeDeck: Deck? {
        store.decks.first(where: { $0.id == deckId })
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

    private var hasUnsavedChanges: Bool {
        guard let original = originalDeckSnapshot, let current = activeDeck else { return false }
        // Sprawdzamy wyłącznie realne zmiany w zawartości (karty, nazwa, opis, etykiety, języki, poziom)
        // Publikacja w Community i metadane giełdowe nie są lokalną edycją wymagającą odrzucenia/zapisu
        return original.name != current.name ||
            original.description != current.description ||
            original.frontLabel != current.frontLabel ||
            original.backLabel != current.backLabel ||
            original.frontLanguage != current.frontLanguage ||
            original.backLanguage != current.backLanguage ||
            original.difficultyLevel != current.difficultyLevel ||
            original.cards != current.cards
    }

    var body: some View {
        ZStack {
            Color.appGroupedBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                if let deck = activeDeck {
                    // STAŁY GÓRNY PASEK (zgodny z HomeView)
                    HStack(alignment: .center) {
                        Text("Deck Manager")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 16) {
                            // ZĘBATKA -> Bezpośrednio do edycji decku
                            Button(action: {
                                #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                #endif
                                showEditDeck = true
                            }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.blue)
                            }
                            .accessibilityLabel("Edit Deck")

                            // PLUS -> Menu dodawania i opcji
                            Menu {
                                Button(action: { showAddCard = true }) {
                                    Label("New Card", systemImage: "rectangle.portrait.badge.plus")
                                }
                                Button(action: { showGenerateSheet = true }) {
                                    Label("Generate Flashcards (AI)", systemImage: "sparkles")
                                }
                                Button(action: { showImportSheet = true }) {
                                    Label("Import from file", systemImage: "square.and.arrow.down")
                                }

                                Divider()

                                Button(action: { showResetProgressConfirm = true }) {
                                    Label("Reset All Progress", systemImage: "arrow.counterclockwise")
                                }

                                if store.decks.firstIndex(where: { $0.id == deck.id }) != 0 {
                                    Button(role: .destructive, action: {
                                        if deck.isMarketAuthor && deck.shareCode != nil {
                                            showDeletePublishedDeckDialog = true
                                        } else {
                                            showDeleteDeckAlert = true
                                        }
                                    }) {
                                        Label("Delete Deck", systemImage: "trash")
                                    }
                                }

                                Divider()

                                // Giełda / Community
                                if let code = deck.shareCode {
                                    Button(action: {
                                        #if canImport(UIKit)
                                        UIPasteboard.general.string = code
                                        let generator = UINotificationFeedbackGenerator()
                                        generator.notificationOccurred(.success)
                                        #endif
                                    }) {
                                        let formatted = code.count == 8
                                            ? "\(code.prefix(4))-\(code.suffix(4))"
                                            : code
                                        Label(String(format: NSLocalizedString("Copy Community Code: %@", comment: ""), formatted), systemImage: "globe")
                                    }

                                    if deck.isMarketAuthor {
                                        Button(action: {
                                            if hasUnsavedChanges {
                                                showSaveBeforePublishAlert = true
                                            } else {
                                                Task {
                                                    await updateDeckOnMarket(deck: deck)
                                                }
                                            }
                                        }) {
                                            Label(isUpdatingOnMarket ? "Updating in Community..." : "Update in Community", systemImage: "arrow.clockwise.icloud")
                                        }
                                        .disabled(isUpdatingOnMarket)

                                        Button(action: {
                                            Task {
                                                await toggleMarketVisibility(deck: deck)
                                            }
                                        }) {
                                            Label(
                                                deck.isMarketPublic ? "Make Private (Unlisted)" : "Make Public in Community",
                                                systemImage: deck.isMarketPublic ? "person.2" : "globe"
                                            )
                                        }

                                        Button(role: .destructive, action: {
                                            showDeleteFromMarketAlert = true
                                        }) {
                                            Label("Delete from Community", systemImage: "trash")
                                        }
                                    } else {
                                        Button(action: {
                                            Task {
                                                await checkForUpdates(code: code, manual: true)
                                            }
                                        }) {
                                            Label(updateAvailable ? "Update Available!" : "Check for Updates", systemImage: updateAvailable ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.triangle.2.circlepath")
                                        }
                                    }
                                } else {
                                    Button(action: {
                                        if hasUnsavedChanges {
                                            showSaveBeforePublishAlert = true
                                        } else {
                                            showPublishSheet = true
                                        }
                                    }) {
                                        Label("Share in Community", systemImage: "globe.badge.chevron.backward")
                                    }
                                }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color.green)
                            }
                            .accessibilityLabel("Add")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .background(Color.appGroupedBackground)

                    List {
                        // Sekcja Info
                        Section {
                            VStack(alignment: .leading, spacing: 6) {
                                // Nazwa talii, poziom trudności oraz ikona pochodzenia z marketu
                                HStack(alignment: .center, spacing: 8) {
                                    Text(deck.name)
                                        .font(.title2)
                                        .bold()
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(2)

                                    if let level = deck.difficultyLevel, !level.isEmpty {
                                        Text(level)
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color.purple.opacity(0.15))
                                            .foregroundStyle(Color.purple)
                                            .clipShape(Capsule())
                                    }

                                    MarketOriginBadgeView(marketType: deck.marketType)

                                    if deck.hasPendingMarketUpdate {
                                        Text("Update available")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(Color.marketUpdateYellowOrange)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.marketUpdateYellowOrange.opacity(0.12))
                                            .clipShape(Capsule())
                                    }

                                    Spacer()
                                }
                                .padding(.bottom, 2)

                                if !deck.description.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Description").font(.caption).foregroundStyle(.secondary)
                                        Text(deck.description).font(.body)
                                    }.padding(.vertical, 2)
                                }
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Front Label").font(.caption).foregroundStyle(.secondary)
                                        Text("\(deck.frontLabel) (\(getLangCode(deck.frontLanguage)))")
                                            .fontWeight(.medium)
                                    }
                                    Spacer()
                                    Divider()
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text("Back Label").font(.caption).foregroundStyle(.secondary)
                                        Text("\(deck.backLabel) (\(getLangCode(deck.backLanguage)))")
                                            .fontWeight(.medium)
                                    }
                                }.padding(.vertical, 2)

                                if isPressingInfoCard {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.caption2)
                                        Text("Hold 2s to edit deck...")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundStyle(Color.blue)
                                    .transition(.opacity)
                                }
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onLongPressGesture(minimumDuration: 2.0, pressing: { isPressing in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    self.isPressingInfoCard = isPressing
                                }
                                if isPressing {
                                    #if canImport(UIKit)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                }
                            }, perform: {
                                #if canImport(UIKit)
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.success)
                                #endif
                                showEditDeck = true
                            })
                        }

                        // Baner aktualizacji ze społeczności
                        if updateAvailable, let remote = remoteDeck {
                            Section {
                                Button(action: { showSyncSheet = true }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(Color.marketUpdateYellowOrange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Community Update Available")
                                                .font(.subheadline)
                                                .bold()
                                                .foregroundStyle(Color.primary)
                                            Text("The author has published updates or new cards.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text("Review")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.marketUpdateYellowOrange)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // Sekcja Kart
                        Section(header:
                            HStack {
                                Text("Flashcards")
                                Spacer()
                                Menu {
                                    Picker("Sort By", selection: $store.settings.sortOption) {
                                        ForEach(CardSortOption.allCases, id: \.self) { option in
                                            Text(LocalizedStringKey(option.rawValue)).tag(option)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(LocalizedStringKey(shortSortName(store.settings.sortOption)))
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
                                    CardRowView(store: store, card: card, deck: deck)
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                } else {
                    ContentUnavailableView("Deck not found", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .hideNavigationBarCompat()
        .safeAreaInset(edge: .bottom) {
            bottomActionBar
        }
        .onAppear {
            if originalDeckSnapshot == nil, let deck = activeDeck {
                originalDeckSnapshot = deck
            }
        }
        .onChange(of: store.settings.sortOption) { store.saveData() }
        .sheet(isPresented: $showImportSheet) { ImportView(store: store, initialDeckId: deckId).presentationDetents([.large]) }
        .sheet(isPresented: $showEditDeck) { if let deck = activeDeck { EditDeckSheet(store: store, deckId: deck.id).presentationDetents([.large]) } }
        .sheet(isPresented: $showAddCard) { if let deck = activeDeck { AddCardSheet(store: store, isPresented: $showAddCard, selectedDeckId: deck.id).presentationDetents([.large]) } }
        .sheet(isPresented: $showGenerateSheet) {
            if let deck = activeDeck {
                AIGenerateView(store: store, initialDeckId: deck.id)
                    .presentationDetents([.large])
            }
        }
        .confirmationDialog(
            "Reset Progress?",
            isPresented: $showResetProgressConfirm,
            titleVisibility: .visible
        ) {
            Button("Reset All Progress", role: .destructive) {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                #endif
                store.resetAllProgress(deckId: deckId)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("All flashcards in this deck will return to Box 0 with streaks reset to zero. This cannot be undone.")
        }
        .sheet(isPresented: $showPublishSheet) {
            if let deck = activeDeck {
                NavigationStack {
                    PublishDeckSheet(store: store, deck: deck) { publishedDeck in
                        if var snapshot = originalDeckSnapshot {
                            snapshot.shareCode = publishedDeck.shareCode
                            snapshot.isMarketAuthor = true
                            snapshot.isMarketPublic = publishedDeck.isPublic
                            originalDeckSnapshot = snapshot
                        }
                    }
                }
                .presentationDetents([.large])
            }
        }
        .sheet(isPresented: $showSyncSheet) {
            if let deck = activeDeck, let remote = remoteDeck {
                DeckSyncSheet(store: store, deck: deck, remoteDeck: remote)
                    .presentationDetents([.large])
            }
        }
        .task {
            if let deck = activeDeck, let code = deck.shareCode, !deck.isMarketAuthor {
                await checkForUpdates(code: code, manual: false)
            }
        }
        .alert("Save Changes First?", isPresented: $showSaveBeforePublishAlert) {
            Button("Save and Publish") {
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                store.saveData()
                originalDeckSnapshot = activeDeck
                if let deck = activeDeck {
                    if deck.shareCode == nil {
                        showPublishSheet = true
                    } else {
                        Task {
                            await updateDeckOnMarket(deck: deck)
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You have unsaved changes in this deck. Would you like to save them before publishing to Community?")
        }
        .alert("Discard Changes?", isPresented: $showDiscardConfirmAlert) {
            Button("Keep Editing", role: .cancel) { }
            Button("Discard Changes", role: .destructive) {
                if let original = originalDeckSnapshot,
                   let idx = store.decks.firstIndex(where: { $0.id == deckId }) {
                    var restored = original
                    // WAŻNE: Publikacja w Community / shareCode nie mogą zostać zresetowane przy cofnięciu zmian!
                    if let currentCode = store.decks[idx].shareCode {
                        restored.shareCode = currentCode
                        restored.isMarketAuthor = store.decks[idx].isMarketAuthor
                        restored.isMarketPublic = store.decks[idx].isMarketPublic
                    }
                    store.decks[idx] = restored
                    store.saveData()
                    originalDeckSnapshot = restored
                }
                dismiss()
            }
        } message: {
            Text("Any modifications made to cards or deck settings during this session will be reverted.")
        }
        .alert("Delete from Community", isPresented: $showDeleteFromMarketAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let code = activeDeck?.shareCode {
                    Task {
                        await deletePermanentlyFromMarket(code: code)
                    }
                }
            }
        } message: {
            Text("This will completely delete this deck from the Community cloud. Users will no longer be able to find or update it.")
        }
        .alert("Community Updated", isPresented: $showUpdateSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your deck has been updated in the Community. New downloaders and existing users checking for updates will receive this version.")
        }
        .alert("Deleted from Community", isPresented: $showDeleteFromMarketSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your deck has been permanently deleted from the Community cloud.")
        }
        .alert("Up to Date", isPresented: $showUpToDateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("You already have the latest version of this deck!")
        }
        .alert("Community Error", isPresented: $showMarketErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(marketActionErrorMessage ?? "An unknown error occurred.")
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
        .confirmationDialog(
            "Delete Published Deck?",
            isPresented: $showDeletePublishedDeckDialog,
            titleVisibility: .visible
        ) {
            Button("Delete from Community & Device", role: .destructive) {
                if let deck = activeDeck, let code = deck.shareCode {
                    Task {
                        try? await SupabaseManager.shared.deleteFromMarket(shareCode: code)
                    }
                    store.deleteDeck(id: deck.id)
                    dismiss()
                }
            }
            Button("Keep in Community as Archived") {
                if let deck = activeDeck, let code = deck.shareCode {
                    Task {
                        try? await SupabaseManager.shared.markDeckAsArchived(shareCode: code)
                    }
                    store.deleteDeck(id: deck.id)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let deck = activeDeck {
                Text("The deck '\(deck.name)' is published in Community. Do you want to permanently delete it from Community as well, or leave it available for others as an archived deck?")
            }
        }
    }

    // MARK: - Bottom Action Bar (Decline & Save)

    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                if hasUnsavedChanges {
                    showDiscardConfirmAlert = true
                } else {
                    dismiss()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                    Text("Decline")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button(action: {
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                store.saveData()
                dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                    Text("Save")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.blue.opacity(0.25), radius: 6, x: 0, y: 3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
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

    // MARK: - Market Sync & Management

    private func checkForUpdates(code: String, manual: Bool) async {
        do {
            if let remote = try await SupabaseManager.shared.fetchByCode(code) {
                await MainActor.run {
                    self.remoteDeck = remote
                    if let deck = activeDeck, let diff = store.calculateSyncDiff(deckId: deck.id, remoteDeck: remote) {
                        let remoteVersion = remote.updatedAt ?? remote.createdAt ?? "\(remote.cardsCount)"
                        let isNewVersion = deck.lastDismissedUpdateDate != remoteVersion
                        self.updateAvailable = diff.hasChanges && (manual || isNewVersion)
                        
                        let shouldFlag = diff.hasChanges && isNewVersion
                        if let index = store.decks.firstIndex(where: { $0.id == deck.id }) {
                            if store.decks[index].hasPendingMarketUpdate != shouldFlag {
                                store.decks[index].hasPendingMarketUpdate = shouldFlag
                                store.saveData()
                            }
                        }
                        
                        if manual {
                            if diff.hasChanges {
                                self.showSyncSheet = true
                            } else {
                                self.showUpToDateAlert = true
                            }
                        }
                    }
                }
            }
        } catch {
            #if DEBUG
            print("Check for updates error: \(error)")
            #endif
        }
    }

    private func updateDeckOnMarket(deck: Deck) async {
        guard let code = deck.shareCode else { return }
        isUpdatingOnMarket = true

        let cardPairs = deck.cards.map { ($0.front, $0.back) }
        let analysis = await GeminiService().analyzeDeck(
            title: deck.name,
            description: deck.description,
            frontLanguage: deck.frontLanguage,
            backLanguage: deck.backLanguage,
            sampleCards: cardPairs,
            existingLevel: deck.difficultyLevel
        )

        let sharedCards = deck.cards.map { SharedCard(front: $0.front, back: $0.back) }
        let upload = MarketDeckUpload(
            title: deck.name,
            description: deck.description,
            frontLabel: deck.frontLabel,
            backLabel: deck.backLabel,
            frontLanguage: deck.frontLanguage,
            backLanguage: deck.backLanguage,
            cardsCount: deck.cards.count,
            cardsPayload: sharedCards,
            isPublic: deck.isMarketPublic,
            authorName: "Author",
            tags: analysis.tags,
            difficultyLevel: analysis.level
        )

        do {
            try await SupabaseManager.shared.updateMarketDeck(shareCode: code, upload: upload)
            await MainActor.run {
                self.isUpdatingOnMarket = false
                self.showUpdateSuccessAlert = true
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            await MainActor.run {
                self.isUpdatingOnMarket = false
                self.marketActionErrorMessage = error.localizedDescription
                self.showMarketErrorAlert = true
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }

    private func toggleMarketVisibility(deck: Deck) async {
        guard let code = deck.shareCode else { return }
        let newVisibility = !deck.isMarketPublic
        do {
            try await SupabaseManager.shared.setMarketVisibility(shareCode: code, isPublic: newVisibility)
            await MainActor.run {
                store.setDeckMarketVisibility(deckId: deck.id, isPublic: newVisibility)
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            await MainActor.run {
                self.marketActionErrorMessage = error.localizedDescription
                self.showMarketErrorAlert = true
            }
        }
    }

    private func deletePermanentlyFromMarket(code: String) async {
        do {
            try await SupabaseManager.shared.deleteFromMarket(shareCode: code)
            await MainActor.run {
                if let deck = activeDeck {
                    store.removeDeckShareCode(deckId: deck.id)
                    if var snapshot = originalDeckSnapshot {
                        snapshot.shareCode = nil
                        snapshot.isMarketAuthor = false
                        snapshot.isMarketPublic = true
                        originalDeckSnapshot = snapshot
                    }
                }
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                self.showDeleteFromMarketSuccessAlert = true
            }
        } catch {
            await MainActor.run {
                self.marketActionErrorMessage = error.localizedDescription
                self.showMarketErrorAlert = true
            }
        }
    }
}


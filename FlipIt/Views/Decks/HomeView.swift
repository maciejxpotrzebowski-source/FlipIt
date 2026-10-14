import SwiftUI

struct HomeView: View {
    @ObservedObject var store: FlipItStore

    init(store: FlipItStore) {
        self.store = store
    }

    // Obsługa arkuszy (Sheets)
    @State private var showAddCardSheet = false
    @State private var showSettings = false
    @State private var showNewDeckSheet = false
    @State private var showImportView = false
    @State private var showGenerateView = false
    @State private var showMarketView = false
    @State private var showAuthPrompt = false
    @State private var showUsernameSetup = false
    @State private var hasCheckedAuthOnLaunch = false
    
    @ObservedObject var authManager: AuthManager = .shared

    // Nawigacja
    @State private var selectedDeckForDetail: Deck? = nil
    @State private var navigateToDetail = false
    @State private var showStudySession = false

    // Tryb zarządzania taliami na miejscu (inline edit mode)
    @State private var isManagingDecks = false
    @State private var editableDecks: [Deck] = []
    @State private var draggingDeckId: UUID? = nil
    @State private var dragVisualOffset: CGFloat = 0
    @State private var lastTouchY: CGFloat = 0
    @State private var pressingDeckId: UUID? = nil
    @State private var deckToDelete: Deck? = nil
    @State private var showDeleteAlert = false
    @State private var showDeletePublishedDeckDialog = false

    // Auto-scroll podczas przeciągania talii przy krawędziach ekranu
    @State private var autoScrollTimer: Timer? = nil
    @State private var autoScrollDirection: AutoScrollDirection? = nil

    private enum AutoScrollDirection {
        case up, down
    }

    @Environment(\.scenePhase) var scenePhase

    var currentDecks: [Deck] {
        isManagingDecks ? editableDecks : store.decks
    }

    var areAllSelected: Bool {
        !store.decks.isEmpty && store.settings.usedDeckIDs.count == store.decks.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Tło semantyczne zgodne z Apple HIG
                Color.appGroupedBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // 1. STAŁY GÓRNY PASEK (Nieruchomy, czysty napis FlipIt bez obwódek, ikony po prawej)
                    HStack(alignment: .center) {
                        Text("FlipIt")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.primary)

                        Spacer()

                        if !isManagingDecks {
                            HStack(spacing: 16) {
                                // ZĘBATKA -> Bezpośrednio do Ustawień
                                Button(action: {
                                    #if canImport(UIKit)
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    #endif
                                    showSettings = true
                                }) {
                                    Image(systemName: "gearshape.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.blue)
                                }
                                .accessibilityLabel("Settings")

                                // PLUS -> Menu dodawania
                                Menu {
                                    Button(action: { showAddCardSheet = true }) {
                                        Label("New Card", systemImage: "rectangle.portrait.badge.plus")
                                    }
                                    Button(action: { showNewDeckSheet = true }) {
                                        Label("New Deck", systemImage: "folder.badge.plus")
                                    }
                                    Divider()
                                    Button(action: { showMarketView = true }) {
                                        Label("Explore Decks", systemImage: "globe")
                                    }
                                    Button(action: { showGenerateView = true }) {
                                        Label("Generate Flashcards (AI)", systemImage: "sparkles")
                                    }
                                    Button(action: { showImportView = true }) {
                                        Label("Import from file", systemImage: "square.and.arrow.down")
                                    }
                                    Divider()
                                    Button(action: {
                                        editableDecks = store.decks
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                             isManagingDecks = true
                                        }
                                    }) {
                                        Label("Manage Decks", systemImage: "arrow.up.arrow.down")
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color.green)
                                }
                                .accessibilityLabel("Add")
                            }
                        } else {
                            // Informacja o aktywnym trybie organizacji talii
                            Text("Reorder & Delete")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.orange)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
                    .background(Color.appGroupedBackground)

                    if currentDecks.isEmpty {
                        // Stan pusty
                        ContentUnavailableView(
                            "No decks available",
                            systemImage: "rectangle.stack.badge.plus",
                            description: Text("Tap the menu above to create your first deck.")
                        )
                        .padding(.top, 60)
                        Spacer()
                    } else {
                        // Przycisk Zaznacz/Odznacz wszystko (wyłącznie poza trybem edycji)
                        if !isManagingDecks {
                            HStack {
                                Spacer()

                                Button(action: toggleSelectAll) {
                                    Text(areAllSelected ? "Deselect All" : "Select All")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(areAllSelected ? Color.secondary : Color.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                        }

                        // Płynna lista talii z czytnikiem przewijania
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(Array(currentDecks.enumerated()), id: \.element.id) { index, deck in
                                        deckCard(deck: deck, index: index, scrollProxy: scrollProxy)
                                            .id(deck.id)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 6)
                                .padding(.bottom, 100) // Miejsce na dolny pasek akcji
                            }
                        }
                    }
                }
            }
            #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            // PRZYPIĘTY DOLNY PASEK AKCJI (START STUDYING LUB ODRZUĆ / ZAPISZ)
            .safeAreaInset(edge: .bottom) {
                if !currentDecks.isEmpty {
                    bottomActionBar
                }
            }
            // NAWIGACJA
            .navigationDestination(isPresented: $navigateToDetail) {
                if let deck = selectedDeckForDetail {
                    DeckDetailView(store: store, deck: deck)
                }
            }
            .navigationDestination(isPresented: $showStudySession) {
                StudySessionView(
                    store: store,
                    selectedDeckIds: Array(store.settings.usedDeckIDs),
                    studySide: store.settings.studySide
                )
            }
            // ARKUSZE
            .sheet(isPresented: $showImportView) { ImportView(store: store).presentationDetents([.large]) }
            .sheet(isPresented: $showAddCardSheet) {
                AddCardSheet(store: store, isPresented: $showAddCardSheet, selectedDeckId: store.decks.first?.id ?? UUID())
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showNewDeckSheet) {
                NewDeckSheet(store: store) { newDeckId in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if let newDeck = store.decks.first(where: { $0.id == newDeckId }) {
                            selectedDeckForDetail = newDeck
                            navigateToDetail = true
                        }
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showSettings) { SettingsView(store: store) }
            .sheet(isPresented: $showGenerateView) {
                AIGenerateView(store: store)
            }
            .sheet(isPresented: $showMarketView) {
                DeckMarketView(store: store)
            }
            .sheet(isPresented: $showAuthPrompt) {
                AuthPromptSheet(authManager: authManager, canSkip: true)
            }
            .sheet(isPresented: $showUsernameSetup) {
                UsernameSetupSheet(authManager: authManager)
            }
            .onChange(of: authManager.needsUsernameSetup) { _, needsSetup in
                if needsSetup && authManager.isAuthenticated {
                    showUsernameSetup = true
                }
            }
            .alert("Delete Deck", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { deckToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let deck = deckToDelete {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            editableDecks.removeAll(where: { $0.id == deck.id })
                        }
                    }
                    deckToDelete = nil
                }
            } message: {
                if let deck = deckToDelete {
                    Text("Are you sure you want to delete '\(deck.name)'? Changes will be applied when you tap Save Changes.")
                }
            }
            .confirmationDialog(
                "Delete Published Deck?",
                isPresented: $showDeletePublishedDeckDialog,
                titleVisibility: .visible
            ) {
                Button("Delete from Community & Device", role: .destructive) {
                    if let deck = deckToDelete, let code = deck.shareCode {
                        Task {
                            try? await SupabaseManager.shared.deleteFromMarket(shareCode: code)
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            editableDecks.removeAll(where: { $0.id == deck.id })
                        }
                    }
                    deckToDelete = nil
                }
                Button("Keep in Community as Archived") {
                    if let deck = deckToDelete, let code = deck.shareCode {
                        Task {
                            try? await SupabaseManager.shared.markDeckAsArchived(shareCode: code)
                        }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            editableDecks.removeAll(where: { $0.id == deck.id })
                        }
                    }
                    deckToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    deckToDelete = nil
                }
            } message: {
                if let deck = deckToDelete {
                    Text("The deck '\(deck.name)' is published in Community. Do you want to permanently delete it from Community as well, or leave it available for others as an archived deck?")
                }
            }
            .onOpenURL { url in
                if url.absoluteString == "flipit://add_card" {
                    showAddCardSheet = true
                } else if url.scheme == "flipit" {
                    Task {
                        await authManager.handleOpenURL(url)
                    }
                }
            }
        }
        .environment(\.locale, Locale(identifier: store.settings.appLanguage.rawValue))
        .onAppear {
            if store.settings.usedDeckIDs.isEmpty && !store.decks.isEmpty {
                store.settings.usedDeckIDs = Set(store.decks.map { $0.id })
                store.saveData()
            }
            checkAuthOnAppOpen()
            Task {
                await store.checkMarketUpdatesForImportedDecks()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active {
                store.reloadData()
                if oldPhase == .background {
                    hasCheckedAuthOnLaunch = false
                    checkAuthOnAppOpen()
                }
                Task {
                    await store.checkMarketUpdatesForImportedDecks()
                }
            }
        }
        .onDisappear {
            stopAutoScroll()
        }
    }

    private func checkAuthOnAppOpen() {
        guard !hasCheckedAuthOnLaunch else { return }
        guard !showSettings && !showMarketView && !showGenerateView && !showAddCardSheet && !showNewDeckSheet else { return }
        
        hasCheckedAuthOnLaunch = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard !self.showSettings && !self.showMarketView && !self.showGenerateView else { return }
            if !self.authManager.isAuthenticated {
                self.showAuthPrompt = true
            } else if self.authManager.needsUsernameSetup {
                self.showUsernameSetup = true
            }
        }
    }

    // MARK: - Deck Card Component (Układ 3 linii)

    @ViewBuilder
    private func deckCard(deck: Deck, index: Int, scrollProxy: ScrollViewProxy) -> some View {
        let isSelected = store.settings.usedDeckIDs.contains(deck.id)
        let isPressingThis = pressingDeckId == deck.id
        let isDraggingThis = draggingDeckId == deck.id

        HStack(alignment: .center, spacing: 14) {

            // LEWA STRONA: Checkbox w trybie normalnym LUB Śmietnik/Pinezka w trybie edycji
            if !isManagingDecks {
                Button {
                    #if canImport(UIKit)
                    UISelectionFeedbackGenerator().selectionChanged()
                    #endif
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        if isSelected {
                            store.settings.usedDeckIDs.remove(deck.id)
                        } else {
                            store.settings.usedDeckIDs.insert(deck.id)
                        }
                        store.saveData()
                    }
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.35))
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                // Tryb zarządzania: Indeks 0 jest chroniony pinezką, reszta ma śmietnik
                if index == 0 {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary.opacity(0.45))
                        .frame(width: 36, height: 36)
                } else {
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        deckToDelete = deck
                        if deck.isMarketAuthor && deck.shareCode != nil {
                            showDeletePublishedDeckDialog = true
                        } else {
                            showDeleteAlert = true
                        }
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // ŚRODEK (3 LINIE)
            VStack(alignment: .leading, spacing: 6) {

                // --- LINIA 1: NAZWA DECKU + POZIOM + IKONA MARKETU PO PRAWEJ STRONIE NAZWY ---
                HStack(alignment: .center, spacing: 6) {
                    Text(deck.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let level = deck.difficultyLevel, !level.isEmpty {
                        Text(level)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.purple)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    MarketOriginBadgeView(marketType: deck.marketType)

                    if deck.hasPendingMarketUpdate {
                        Text("Update available")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.marketUpdateYellowOrange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.marketUpdateYellowOrange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                // --- LINIA 2: TYLKO OPIS ---
                if !deck.description.isEmpty {
                    Text(deck.description)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }

                // --- LINIA 3: SZEROKI PASEK POSTĘPU DOCHODZĄCY DO JĘZYKÓW I LICZBY FISZEK ---
                HStack(alignment: .center, spacing: 8) {
                    // Pasek postępu rozciągający się na całą dostępną szerokość
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 6)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: deck.isMastered
                                            ? [Color.blue, Color.cyan]
                                            : [Color.blue.opacity(0.9), Color.blue.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geo.size.width * CGFloat(deck.leitnerProgress), 0), height: 6)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deck.leitnerProgress)
                        }
                    }
                    .frame(height: 6)
                    .allowsHitTesting(false)

                    // Mały niebieski ptaszek przy 100% opanowaniu materiału (Box 4)
                    if deck.isMastered {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.blue)
                    }

                    // Języki talii
                    HStack(spacing: 3) {
                        Text(getLangCode(deck.frontLanguage))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7, weight: .bold))
                        Text(getLangCode(deck.backLanguage))
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(Capsule())

                    // Liczba fiszek
                    HStack(spacing: 3) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                            .font(.system(size: 10))
                        Text("\(deck.cards.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.secondary)
                }

                // Podpowiedź przy przytrzymywaniu
                if isPressingThis && !isManagingDecks {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.caption2)
                        Text("Hold 2s for Reorder & Delete...")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(Color.blue)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // PRAWA STRONA: Chevron w trybie normalnym LUB Pomarańczowa ikona przeciągania w trybie edycji
            if !isManagingDecks {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 36)
            } else if index > 0 {
                // Pomarańczowa ikona przeciągania (zgodna z napisem Reorder & Delete)
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.orange)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        dragGesture(for: deck, at: index, scrollProxy: scrollProxy)
                    )
            }
        }
        .padding(14)
        .background(Color.appSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isDraggingThis
                        ? Color.orange
                        : (isPressingThis ? Color.blue.opacity(0.6) : Color.primary.opacity(0.04)),
                    lineWidth: isDraggingThis ? 2.5 : (isPressingThis ? 2 : 1)
                )
        )
        .shadow(
            color: isDraggingThis ? Color.orange.opacity(0.25) : Color.black.opacity(0.04),
            radius: isDraggingThis ? 14 : 6,
            x: 0,
            y: isDraggingThis ? 6 : 2
        )
        .scaleEffect(isDraggingThis ? 1.02 : (isPressingThis ? 0.97 : 1.0))
        .offset(y: isDraggingThis ? dragVisualOffset : 0)
        .zIndex(isDraggingThis ? 100 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isManagingDecks {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                selectedDeckForDetail = deck
                navigateToDetail = true
            }
        }
        .onLongPressGesture(minimumDuration: 2.0, pressing: { isPressing in
            if !isManagingDecks {
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.pressingDeckId = isPressing ? deck.id : nil
                }
                if isPressing {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                }
            }
        }, perform: {
            if !isManagingDecks {
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                editableDecks = store.decks
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isManagingDecks = true
                    pressingDeckId = nil
                }
            }
        })
    }

    // MARK: - Auto-Scroll & Drag Gesture dla płynnego przestawiania talii

    private func dragGesture(for deck: Deck, at index: Int, scrollProxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                guard isManagingDecks && index != 0 else { return }

                let currentTouchY = value.location.y

                // Inicjalizacja przeciągania
                if draggingDeckId == nil {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    withAnimation(.easeInOut(duration: 0.18)) {
                        draggingDeckId = deck.id
                    }
                    dragVisualOffset = 0
                    lastTouchY = currentTouchY
                    return
                }

                let deltaY = currentTouchY - lastTouchY
                lastTouchY = currentTouchY

                #if canImport(UIKit)
                let screenHeight: CGFloat = (UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)?
                    .screen.bounds.height ?? 800
                #else
                let screenHeight: CGFloat = 800
                #endif
                let topEdge: CGFloat = 200
                let bottomEdge: CGFloat = screenHeight - 110

                // 1. Sprawdzanie strefy automatycznego przewijania przy krawędziach ekranu
                if currentTouchY < topEdge {
                    startAutoScroll(direction: .up, scrollProxy: scrollProxy, deckId: deck.id)
                } else if currentTouchY > bottomEdge {
                    startAutoScroll(direction: .down, scrollProxy: scrollProxy, deckId: deck.id)
                } else {
                    // Poza krawędziami: zatrzymaj autoscroll jeśli trwał
                    if autoScrollDirection != nil {
                        stopAutoScroll()
                        dragVisualOffset = 0
                    }

                    // 2. Płynne przestawianie oparte na delcie
                    guard let currentIndex = editableDecks.firstIndex(where: { $0.id == deck.id }) else { return }

                    dragVisualOffset += deltaY

                    let rowHeight: CGFloat = 88.0
                    let swapThreshold: CGFloat = rowHeight * 0.45

                    // Przesunięcie w dół
                    if dragVisualOffset > swapThreshold {
                        let targetIndex = currentIndex + 1
                        if targetIndex < editableDecks.count {
                            #if canImport(UIKit)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                editableDecks.swapAt(currentIndex, targetIndex)
                            }
                            dragVisualOffset -= rowHeight
                        } else {
                            dragVisualOffset = min(dragVisualOffset, 25)
                        }
                    }
                    // Przesunięcie w górę
                    else if dragVisualOffset < -swapThreshold {
                        let targetIndex = currentIndex - 1
                        if targetIndex >= 1 { // Indeks 0 jest zablokowany!
                            #if canImport(UIKit)
                            UISelectionFeedbackGenerator().selectionChanged()
                            #endif
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                editableDecks.swapAt(currentIndex, targetIndex)
                            }
                            dragVisualOffset += rowHeight
                        } else {
                            dragVisualOffset = max(dragVisualOffset, -25)
                        }
                    }
                }
            }
            .onEnded { _ in
                stopAutoScroll()
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    draggingDeckId = nil
                    dragVisualOffset = 0
                }
            }
    }

    private func startAutoScroll(direction: AutoScrollDirection, scrollProxy: ScrollViewProxy, deckId: UUID) {
        guard autoScrollDirection != direction else { return }
        stopAutoScroll()
        autoScrollDirection = direction

        // Uruchom natychmiast pierwszy cykl: przewiń -> poczekaj na odsłonięcie -> zamień
        executeScrollAndSwapCycle(direction: direction, scrollProxy: scrollProxy, deckId: deckId)

        // Cykliczny timer w trybie .common wykonujący kolejne kroki
        let timer = Timer(timeInterval: 0.48, repeats: true) { _ in
            DispatchQueue.main.async {
                executeScrollAndSwapCycle(direction: direction, scrollProxy: scrollProxy, deckId: deckId)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoScrollTimer = timer
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
        autoScrollDirection = nil
    }

    private func executeScrollAndSwapCycle(direction: AutoScrollDirection, scrollProxy: ScrollViewProxy, deckId: UUID) {
        guard isManagingDecks,
              let currentIndex = editableDecks.firstIndex(where: { $0.id == deckId }) else {
            stopAutoScroll()
            return
        }

        switch direction {
        case .down:
            let targetIndex = currentIndex + 1
            guard targetIndex < editableDecks.count else {
                stopAutoScroll()
                return
            }
            let nextDeckId = editableDecks[targetIndex].id

            // Krok 1: Przewiń listę w dół, aby kolejna fiszka była w pełni widoczna
            withAnimation(.easeInOut(duration: 0.24)) {
                scrollProxy.scrollTo(nextDeckId, anchor: .bottom)
            }

            // Krok 2: Dopiero gdy kolejna fiszka jest w pełni widoczna, przeskocz za nią
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                guard self.isManagingDecks,
                      self.autoScrollDirection == .down,
                      self.draggingDeckId == deckId,
                      let current = self.editableDecks.firstIndex(where: { $0.id == deckId }),
                      current + 1 < self.editableDecks.count else { return }

                #if canImport(UIKit)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif

                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    self.editableDecks.swapAt(current, current + 1)
                }
                self.dragVisualOffset = 0
            }

        case .up:
            let targetIndex = currentIndex - 1
            guard targetIndex >= 1 else { // Indeks 0 jest zablokowany (Moje fiszki)
                stopAutoScroll()
                return
            }
            let prevDeckId = editableDecks[targetIndex].id

            // Krok 1: Przewiń listę w górę, aby poprzednia fiszka była w pełni widoczna
            withAnimation(.easeInOut(duration: 0.24)) {
                scrollProxy.scrollTo(prevDeckId, anchor: .top)
            }

            // Krok 2: Dopiero gdy poprzednia fiszka jest w pełni widoczna, przeskocz nad nią
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                guard self.isManagingDecks,
                      self.autoScrollDirection == .up,
                      self.draggingDeckId == deckId,
                      let current = self.editableDecks.firstIndex(where: { $0.id == deckId }),
                      current - 1 >= 1 else { return }

                #if canImport(UIKit)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif

                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    self.editableDecks.swapAt(current, current - 1)
                }
                self.dragVisualOffset = 0
            }
        }
    }

    // MARK: - Bottom Action Bar (Dynamiczny: Start Studying lub Odrzuć/Zapisz)

    private var bottomActionBar: some View {
        Group {
            if !isManagingDecks {
                // TRYB STANDARDOWY: Przycisk START STUDYING
                let selectedDeckCount = store.settings.usedDeckIDs.count
                let totalCardsInSelected = store.decks
                    .filter { store.settings.usedDeckIDs.contains($0.id) }
                    .reduce(0) { $0 + $1.cards.count }
                let canStudy = selectedDeckCount > 0 && totalCardsInSelected > 0

                VStack(spacing: 0) {
                    Button(action: {
                        if canStudy {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            showStudySession = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))

                            Text(studyButtonTitle(selectedDeckCount: selectedDeckCount, totalCards: totalCardsInSelected))
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            canStudy
                                ? LinearGradient(colors: [Color.green, Color.green.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: canStudy ? Color.green.opacity(0.3) : Color.clear, radius: 8, x: 0, y: 4)
                    }
                    .disabled(!canStudy)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
            } else {
                // TRYB ZARZĄDZANIA: Przyciski Odrzuć oraz Zapisz zmiany (ukrywane podczas przeciągania)
                if draggingDeckId == nil {
                    HStack(spacing: 12) {
                        Button(action: {
                            stopAutoScroll()
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                editableDecks = store.decks
                                draggingDeckId = nil
                                dragVisualOffset = 0
                                isManagingDecks = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Discard")
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
                            stopAutoScroll()
                            #if canImport(UIKit)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                store.decks = editableDecks
                                let remainingIds = Set(editableDecks.map { $0.id })
                                store.settings.usedDeckIDs = store.settings.usedDeckIDs.intersection(remainingIds)
                                store.saveData()
                                draggingDeckId = nil
                                dragVisualOffset = 0
                                isManagingDecks = false
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Save Changes")
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(
            Group {
                if !isManagingDecks || draggingDeckId == nil {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        )
        .animation(.easeInOut(duration: 0.22), value: draggingDeckId == nil)
    }

    private func studyButtonTitle(selectedDeckCount: Int, totalCards: Int) -> LocalizedStringKey {
        if selectedDeckCount == 0 {
            return "SELECT DECKS TO STUDY"
        } else if totalCards == 0 {
            return "SELECTED DECKS ARE EMPTY"
        } else {
            return "START STUDYING"
        }
    }

    private func toggleSelectAll() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if areAllSelected {
                store.settings.usedDeckIDs.removeAll()
            } else {
                store.settings.usedDeckIDs = Set(store.decks.map { $0.id })
            }
            store.saveData()
        }
    }

}


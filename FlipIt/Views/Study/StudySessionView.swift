import SwiftUI

struct StudySessionView: View {
    @ObservedObject var store: FlipItStore
    var selectedDeckIds: [UUID]
    var studySide: StudySideOption

    init(
        store: FlipItStore,
        selectedDeckIds: [UUID],
        studySide: StudySideOption = .front
    ) {
        self.store = store
        self.selectedDeckIds = selectedDeckIds
        self.studySide = studySide
    }

    // ... reszta zmiennych stanu bez zmian ...
    @State private var activePool: [(card: Flashcard, deckId: UUID)] = []
    @State private var currentItem: (card: Flashcard, deckId: UUID)?
    @State private var isFrontFirst: Bool = true
    @State private var isFlipped = false
    @State private var dragOffset: CGSize = .zero
    @State private var initialLoadDone = false
    @State private var sessionReviewCount = 0
    @State private var sessionKnownCount = 0

    // Adaptive Learning State (Silent Continuous DDA Engine)
    @State private var consecutiveFailures = 0
    @State private var consecutiveSuccesses = 0
    @State private var isInRescueMode = false
    @State private var isInChallengeMode = false
    @State private var currentReason: AdaptiveCardSelector.SelectionReason = .normalDue

    // Haptic Feedback State for Card Dragging
    @State private var hasTriggeredDragStartHaptic = false
    @State private var hasTriggeredThresholdHaptic = false

    var body: some View {
        VStack {
            if activePool.isEmpty && currentItem == nil {
                if initialLoadDone {
                    ContentUnavailableView(
                        "No cards available!",
                        systemImage: "checkmark.seal.fill",
                        description: Text("All caught up! Check your deck selection or add new cards.")
                    )
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
                        Text("Cards in pool: \(activePool.count)")
                        Text("Mastered: \(activePool.filter { $0.card.isLearned }.count)")
                    }
                    .font(.caption)
                }
                .padding(.horizontal)
                .padding(.top, 4)

                // --- CARD AREA ---
                ZStack {
                    let startText = isFrontFirst ? item.card.front : item.card.back
                    let endText = isFrontFirst ? item.card.back : item.card.front

                    let currentDeck = store.decks.first(where: { $0.id == item.deckId })
                    let frontLang = currentDeck?.frontLanguage ?? "en-US"
                    let backLang = currentDeck?.backLanguage ?? "pl-PL"
                    let frontLbl = currentDeck?.frontLabel ?? "Front"
                    let backLbl = currentDeck?.backLabel ?? "Back"

                    let startLabel = isFrontFirst ? frontLbl : backLbl
                    let endLabel = isFrontFirst ? backLbl : frontLbl

                    let startLang = isFrontFirst ? frontLang : backLang
                    let endLang = isFrontFirst ? backLang : frontLang

                    ZStack {
                        // TYŁ KARTY (po obrocie)
                        CardView(text: endText, label: endLabel, language: endLang)
                            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            .opacity(isFlipped ? 1 : 0)

                        // PRZÓD KARTY
                        CardView(text: startText, label: startLabel, language: startLang)
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
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .identity
                ))
                .rotationEffect(.degrees(Double(dragOffset.width / 20)))
                .offset(x: dragOffset.width, y: dragOffset.height * 0.4)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            dragOffset = gesture.translation

                            #if canImport(UIKit)
                            let translationX = gesture.translation.width

                            // Krótka haptyka przy rozpoczęciu przesuwania fiszki w lewo lub w prawo
                            if !hasTriggeredDragStartHaptic && abs(translationX) > 10 {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                hasTriggeredDragStartHaptic = true
                            } else if hasTriggeredDragStartHaptic && abs(translationX) < 5 {
                                hasTriggeredDragStartHaptic = false
                            }

                            // Haptyczny przeskok przy osiągnięciu progu decyzji (100 px)
                            if !hasTriggeredThresholdHaptic && abs(translationX) >= 100 {
                                UISelectionFeedbackGenerator().selectionChanged()
                                hasTriggeredThresholdHaptic = true
                            } else if hasTriggeredThresholdHaptic && abs(translationX) < 85 {
                                hasTriggeredThresholdHaptic = false
                            }
                            #endif
                        }
                        .onEnded { gesture in
                            #if canImport(UIKit)
                            hasTriggeredDragStartHaptic = false
                            hasTriggeredThresholdHaptic = false
                            #endif

                            if gesture.translation.width > 100 { swipeRight() }
                            else if gesture.translation.width < -100 { swipeLeft() }
                            else { withAnimation(.spring()) { dragOffset = .zero } }
                        }
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: AnimationConfig.flipDuration)) {
                        isFlipped.toggle()
                    }
                }
                .padding()
                Spacer()

                // --- CONTROLS ---
                HStack(spacing: 30) {
                    Button(action: swipeLeft) {
                        Image(systemName: "xmark").font(.system(size: 30, weight: .bold))
                            .frame(width: 70, height: 70).background(Color.red.opacity(0.9)).foregroundStyle(.white).clipShape(Circle())
                    }
                    .accessibilityLabel("Still learning")

                    Button(action: { withAnimation { isFlipped.toggle() } }) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 25, weight: .bold))
                            .frame(width: 60, height: 60).background(Color.blue).foregroundStyle(.white).clipShape(Circle())
                    }
                    .accessibilityLabel("Flip card")

                    Button(action: swipeRight) {
                        Image(systemName: "checkmark").font(.system(size: 30, weight: .bold))
                            .frame(width: 70, height: 70).background(Color.green.opacity(0.9)).foregroundStyle(.white).clipShape(Circle())
                    }
                    .accessibilityLabel("Know")
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

    func loadPool() {
        var newPool: [(card: Flashcard, deckId: UUID)] = []
        for deck in store.decks where selectedDeckIds.contains(deck.id) {
            for card in deck.cards {
                newPool.append((card, deck.id))
            }
        }
        activePool = newPool
        initialLoadDone = true
    }

    // --- ADAPTIVE CARD SELECTION ---
    func pickNextCard() {
        if activePool.isEmpty {
            currentItem = nil
            return
        }

        // Używamy inteligentnego AdaptiveCardSelector z dynamicznym balansem trudności (DDA)
        if let result = AdaptiveCardSelector.selectNextCard(
            from: activePool,
            isInRescueMode: isInRescueMode,
            isInChallengeMode: isInChallengeMode,
            currentCardId: currentItem?.card.id,
            preferredSide: studySide
        ) {
            currentItem = (result.card, result.deckId)
            currentReason = result.reason
            isFrontFirst = !result.reverseSide
            isFlipped = false
            dragOffset = .zero
        } else {
            currentItem = activePool.first
            currentReason = .normalDue
            isFrontFirst = true
            isFlipped = false
            dragOffset = .zero
        }
    }

    func updateCurrentCard(isKnown: Bool) {
        guard let item = currentItem else { return }

        let wasMorale = (currentReason == .moraleRescue)
        let wasChallenge = (currentReason == .challengeLeech || currentReason == .challengeNew)

        // Aktualizacja serii i stanów DDA (Dynamic Difficulty Adjustment)
        if isKnown {
            consecutiveSuccesses += 1
            consecutiveFailures = 0
            // Sukces kończy tryb ratunkowy morale
            isInRescueMode = false
            // Seria >= 3 sukcesów lub udana odpowiedź w trybie wyzwania kontynuuje trudniejsze fiszki
            if consecutiveSuccesses >= 3 || isInChallengeMode {
                isInChallengeMode = true
            }
        } else {
            consecutiveFailures += 1
            consecutiveSuccesses = 0
            // Błąd natychmiast przerywa tryb wyzwania
            isInChallengeMode = false
            // Błędy (>= 2) lub błąd podczas trwającego trybu ratunkowego utrzymują łatwiejsze fiszki aż do poprawnej odpowiedzi
            if consecutiveFailures >= 2 || isInRescueMode {
                isInRescueMode = true
            }
        }

        if let index = activePool.firstIndex(where: { $0.card.id == item.card.id }) {
            var updatedCard = activePool[index].card
            let now = Date()
            let oldBox = updatedCard.box

            if isKnown {
                updatedCard.streak += 1
                updatedCard.correctCount += 1
                updatedCard.box = min(oldBox + 1, 4)
            } else {
                updatedCard.streak = 0
                updatedCard.incorrectCount += 1
                // Łagodna kara (cofnięcie o 1 pudełko)
                updatedCard.box = max(oldBox - 1, 0)
            }

            updatedCard.lastReviewDate = now
            updatedCard.nextReviewDate = now.addingTimeInterval(Flashcard.leitnerInterval(for: updatedCard.box))
            activePool[index].card = updatedCard

            store.updateStreak(
                deckId: item.deckId,
                cardId: item.card.id,
                newStreak: updatedCard.streak,
                isKnown: isKnown,
                wasMoraleBooster: wasMorale,
                wasChallenge: wasChallenge
            )
        }
    }

    func swipeRight() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.easeOut(duration: AnimationConfig.flyInDuration)) {
            dragOffset.width = 1000
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConfig.nextCardDelay) {
            updateCurrentCard(isKnown: true)
            sessionReviewCount += 1
            sessionKnownCount += 1
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isFlipped = false; dragOffset = .zero }
            withAnimation(.easeOut(duration: AnimationConfig.flyInDuration)) { pickNextCard() }
        }
    }

    func swipeLeft() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        withAnimation(.easeOut(duration: AnimationConfig.flyInDuration)) { dragOffset.width = -1000 }
        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationConfig.nextCardDelay) {
            updateCurrentCard(isKnown: false)
            sessionReviewCount += 1
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { isFlipped = false; dragOffset = .zero }
            withAnimation(.easeOut(duration: AnimationConfig.flyInDuration)) { pickNextCard() }
        }
    }
}


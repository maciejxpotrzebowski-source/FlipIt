import SwiftUI

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

    // Adaptive Learning State (Casino Morale & Challenge Engine)
    @State private var consecutiveFailures = 0
    @State private var consecutiveSuccesses = 0
    @State private var currentReason: AdaptiveCardSelector.SelectionReason = .normalDue

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

                // --- TOP STATS & ADAPTIVE BADGE ---
                VStack(spacing: 8) {
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

                    // Adaptive Morale / Challenge Badge
                    if let badge = currentReason.displayBadge {
                        HStack {
                            Text(badge)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(currentReason == .moraleRescue ? Color.orange.opacity(0.18) : Color.purple.opacity(0.18))
                                .foregroundStyle(currentReason == .moraleRescue ? Color.orange : Color.purple)
                                .clipShape(Capsule())
                        }
                    }
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
                        .onChanged { gesture in dragOffset = gesture.translation }
                        .onEnded { gesture in
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

    // --- ADAPTIVE CARD SELECTION ---
    func pickNextCard() {
        if activePool.isEmpty {
            currentItem = nil
            return
        }

        // Używamy inteligentnego AdaptiveCardSelector z mechaniką Morale i Challenge
        if let result = AdaptiveCardSelector.selectNextCard(
            from: activePool,
            consecutiveFailures: consecutiveFailures,
            consecutiveSuccesses: consecutiveSuccesses,
            preferredSide: studySide
        ) {
            currentItem = (result.card, result.deckId)
            currentReason = result.reason
            isFrontFirst = !result.reverseSide
            isFlipped = false
            dragOffset = .zero

            // Zmniejsz licznik serii sukcesów po zaserwowaniu wyzwania, by nie bombardować trudnymi kartami
            if result.reason == .challengeLeech || result.reason == .challengeNew {
                consecutiveSuccesses = 0
            }
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

        // Aktualizacja serii dla mechaniki kasyna / morale / wyzwania
        if isKnown {
            consecutiveSuccesses += 1
            consecutiveFailures = 0
        } else {
            consecutiveFailures += 1
            consecutiveSuccesses = 0
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


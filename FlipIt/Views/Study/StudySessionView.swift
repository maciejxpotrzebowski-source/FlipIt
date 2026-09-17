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
                                            CardView(text: endText, label: endLabel, language: endLang, backgroundColor: .white)
                                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                                                .opacity(isFlipped ? 1 : 0)

                                            // PRZÓD KARTY
                                            CardView(text: startText, label: startLabel, language: startLang, backgroundColor: .white)
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
                                    insertion: .move(edge: .trailing), // Nowa wjeżdża z prawej
                                    removal: .identity // Stara nie animuje się systemowo (bo my ją wyrzucamy gestem)
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
                    //withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { isFlipped.toggle() }
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


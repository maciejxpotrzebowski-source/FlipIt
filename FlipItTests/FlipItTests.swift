//
//  FlipItTests.swift
//  FlipItTests
//

import Testing
import Foundation
@testable import FlipIt

@Suite("FlipIt Core Unit Tests")
struct FlipItTests {

    @Test("CSV parsing handles comma separated lines")
    @MainActor
    func testCSVCommaSeparated() {
        let store = FlipItStore()
        let csv = """
        Apple,Jabłko
        Banana,Banan
        Orange,Pomarańcza
        """
        let cards = store.parseCSV(content: csv)
        #expect(cards.count == 3)
        #expect(cards[0].front == "Apple")
        #expect(cards[0].back == "Jabłko")
        #expect(cards[1].front == "Banana")
        #expect(cards[1].back == "Banan")
        #expect(cards[2].front == "Orange")
        #expect(cards[2].back == "Pomarańcza")
    }

    @Test("CSV parsing handles semicolon delimiter and skips header")
    @MainActor
    func testCSVSemicolonAndHeader() {
        let store = FlipItStore()
        let csv = """
        Front;Back
        Dog;Pies
        Cat;Kot
        
        Sun;Słońce
        """
        let cards = store.parseCSV(content: csv)
        #expect(cards.count == 3)
        #expect(cards[0].front == "Dog")
        #expect(cards[0].back == "Pies")
        #expect(cards[1].front == "Cat")
        #expect(cards[1].back == "Kot")
        #expect(cards[2].front == "Sun")
        #expect(cards[2].back == "Słońce")
    }

    @Test("CSV parsing joins extra columns into back side")
    @MainActor
    func testCSVMultipleColumns() {
        let store = FlipItStore()
        let csv = "To run;Biegać;Pędzić"
        let cards = store.parseCSV(content: csv)
        #expect(cards.count == 1)
        #expect(cards[0].front == "To run")
        #expect(cards[0].back == "Biegać;Pędzić")
    }

    @Test("Flashcard streak and isLearned updates correctly")
    @MainActor
    func testStreakAndLearnedUpdates() {
        var card = Flashcard(front: "Hello", back: "Cześć")
        #expect(card.streak == 0)
        #expect(card.isLearned == false)

        // Simulate positive answer
        card.streak += 1
        card.isLearned = (card.streak > 0)
        #expect(card.streak == 1)
        #expect(card.isLearned == true)

        // Increment again
        card.streak += 1
        #expect(card.streak == 2)
        #expect(card.isLearned == true)

        // Reset on failure
        card.streak = 0
        card.isLearned = (card.streak > 0)
        #expect(card.streak == 0)
        #expect(card.isLearned == false)
    }

    @Test("Deck progress calculation reflects learned cards")
    func testDeckProgress() {
        let card1 = Flashcard(front: "1", back: "1", isLearned: true, streak: 1)
        let card2 = Flashcard(front: "2", back: "2", isLearned: false, streak: 0)
        let card3 = Flashcard(front: "3", back: "3", isLearned: true, streak: 3)
        let card4 = Flashcard(front: "4", back: "4", isLearned: false, streak: 0)

        let deck = Deck(name: "Test Deck", cards: [card1, card2, card3, card4])
        #expect(deck.progress == 0.5)

        let emptyDeck = Deck(name: "Empty Deck", cards: [])
        #expect(emptyDeck.progress == 0.0)
    }

    @Test("Card transfer respects skipDuplicates, swapFaces, and deleteFromSource")
    @MainActor
    func testCardTransferLogic() {
        let store = FlipItStore()
        let sourceDeckId = UUID()
        let destDeckId = UUID()

        let card1 = Flashcard(front: "House", back: "Dom")
        let card2 = Flashcard(front: "Tree", back: "Drzewo")
        let existingCardInDest = Flashcard(front: "House", back: "Dom")

        let sourceDeck = Deck(id: sourceDeckId, name: "Source", cards: [card1, card2])
        let destDeck = Deck(id: destDeckId, name: "Dest", cards: [existingCardInDest])

        store.decks = [sourceDeck, destDeck]

        // Transfer card1 and card2 with skipDuplicates: true, swapFaces: false, deleteFromSource: true
        let selectedIds: Set<UUID> = [card1.id, card2.id]
        store.transferCards(
            from: sourceDeckId,
            to: destDeckId,
            cardIds: selectedIds,
            deleteFromSource: true,
            swapFaces: false,
            skipDuplicates: true
        )

        let updatedSource = store.decks.first(where: { $0.id == sourceDeckId })!
        let updatedDest = store.decks.first(where: { $0.id == destDeckId })!

        // Selected cards should be removed from source
        #expect(updatedSource.cards.isEmpty)

        // Dest should have existing "House" plus new "Tree" (duplicate "House" was skipped)
        #expect(updatedDest.cards.count == 2)
        #expect(updatedDest.cards.contains(where: { $0.front == "Tree" && $0.back == "Drzewo" }))
    }

    @Test("Deck decoding backward compatibility handles missing optional fields")
    func testDeckDecodingCompatibility() throws {
        let legacyJSON = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "name": "Legacy Deck",
            "cards": [
                {
                    "id": "22222222-2222-2222-2222-222222222222",
                    "front": "One",
                    "back": "Jeden"
                }
            ]
        }
        """.data(using: .utf8)!

        let deck = try JSONDecoder().decode(Deck.self, from: legacyJSON)
        #expect(deck.name == "Legacy Deck")
        #expect(deck.description == "")
        #expect(deck.frontLabel == "Front")
        #expect(deck.backLabel == "Back")
        #expect(deck.frontLanguage == "en-US")
        #expect(deck.backLanguage == "pl-PL")
        #expect(deck.cards.count == 1)
        #expect(deck.cards[0].streak == 0)
        #expect(deck.cards[0].isLearned == false)
    }

    @Test("AppSettings decoding backward compatibility provides safe defaults")
    func testAppSettingsDecodingCompatibility() throws {
        let legacySettingsJSON = """
        {
            "confirmDelete": true,
            "isDarkMode": false
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: legacySettingsJSON)
        #expect(settings.confirmDelete == true)
        #expect(settings.isDarkMode == false)
        #expect(settings.sortOption == .frontAZ)
        #expect(settings.studySide == .front)
        #expect(settings.onlyUnlearned == false)
        #expect(settings.learningFactorValue == 1.0)
        #expect(settings.widgetColorfulButtons == true)
        #expect(settings.widgetInactivityColor == true)
        #expect(settings.isPremiumUser == false)
        #expect(settings.defaultFrontLanguage == "en-US")
        #expect(settings.defaultBackLanguage == "pl-PL")
    }

    @Test("AppLanguage systemDefault returns either polish or english")
    func testAppLanguageSystemDefault() {
        let lang = AppLanguage.systemDefault
        #expect(lang == .polish || lang == .english)
    }

    @Test("Leitner transitions advance box on success and apply soft penalty on error")
    @MainActor
    func testLeitnerTransitionsAndSoftPenalty() {
        let store = FlipItStore()
        let deckId = UUID()
        let card = Flashcard(front: "Sun", back: "Słońce", box: 2, nextReviewDate: Date())
        let deck = Deck(id: deckId, name: "Leitner Test", cards: [card])
        store.decks = [deck]

        // 1. Success from box 2 -> box 3
        store.updateStreak(deckId: deckId, cardId: card.id, newStreak: 1, isKnown: true)
        let updatedCard1 = store.decks.first?.cards.first
        #expect(updatedCard1?.box == 3)
        #expect(updatedCard1?.correctCount == 1)
        #expect(updatedCard1?.isLearned == false)

        // 2. Success from box 3 -> box 4 (Mastered!)
        store.updateStreak(deckId: deckId, cardId: card.id, newStreak: 2, isKnown: true)
        let updatedCard2 = store.decks.first?.cards.first
        #expect(updatedCard2?.box == 4)
        #expect(updatedCard2?.isLearned == true)

        // 3. Error on box 4 -> soft penalty drops to box 3 (NOT 0!)
        store.updateStreak(deckId: deckId, cardId: card.id, newStreak: 0, isKnown: false)
        let updatedCard3 = store.decks.first?.cards.first
        #expect(updatedCard3?.box == 3)
        #expect(updatedCard3?.incorrectCount == 1)
        #expect(updatedCard3?.isLearned == false)
    }

    @Test("AdaptiveCardSelector triggers Morale Rescue after 3 consecutive failures")
    func testAdaptiveSelectorMoraleRescue() {
        let deckId = UUID()
        let hardCard = Flashcard(front: "Difficult", back: "Trudne", box: 0, correctCount: 1, incorrectCount: 5)
        let easyCard = Flashcard(front: "Easy", back: "Łatwe", box: 3, correctCount: 10, incorrectCount: 1)

        let pool = [(card: hardCard, deckId: deckId), (card: easyCard, deckId: deckId)]

        // 2 failures -> normal mode
        let result2Fails = AdaptiveCardSelector.selectNextCard(
            from: pool,
            consecutiveFailures: 2,
            consecutiveSuccesses: 0,
            preferredSide: .front
        )
        #expect(result2Fails?.reason != .moraleRescue)

        // 3 failures -> Morale Rescue triggered! Must pick easyCard
        let result3Fails = AdaptiveCardSelector.selectNextCard(
            from: pool,
            consecutiveFailures: 3,
            consecutiveSuccesses: 0,
            preferredSide: .front
        )
        #expect(result3Fails?.reason == .moraleRescue)
        #expect(result3Fails?.card.front == "Easy")
    }

    @Test("AdaptiveCardSelector triggers Challenge Engine after 5 consecutive successes")
    func testAdaptiveSelectorChallengeEngine() {
        let deckId = UUID()
        let normalCard = Flashcard(front: "Normal", back: "Normalne", box: 2, correctCount: 5, incorrectCount: 1)
        let leechCard = Flashcard(front: "Leech", back: "Trudny orzech", box: 1, correctCount: 2, incorrectCount: 4)

        let pool = [(card: normalCard, deckId: deckId), (card: leechCard, deckId: deckId)]

        // 4 successes -> normal mode
        let result4Wins = AdaptiveCardSelector.selectNextCard(
            from: pool,
            consecutiveFailures: 0,
            consecutiveSuccesses: 4,
            preferredSide: .front
        )
        #expect(result4Wins?.reason != .challengeLeech)

        // 5 successes -> Challenge Engine triggered! Must pick leechCard
        let result5Wins = AdaptiveCardSelector.selectNextCard(
            from: pool,
            consecutiveFailures: 0,
            consecutiveSuccesses: 5,
            preferredSide: .front
        )
        #expect(result5Wins?.reason == .challengeLeech)
        #expect(result5Wins?.card.front == "Leech")
    }

    @Test("StudyTelemetry logs events and supports export and clear")
    func testStudyTelemetryLogging() {
        StudyTelemetryManager.shared.clearEvents()
        #expect(StudyTelemetryManager.shared.eventsCount() == 0)

        StudyTelemetryManager.shared.logEvent(StudyTelemetryEvent(
            eventType: "review",
            isKnown: true,
            boxBefore: 1,
            boxAfter: 2,
            consecutiveStreak: 3
        ))
        #expect(StudyTelemetryManager.shared.eventsCount() == 1)

        let json = StudyTelemetryManager.shared.exportJSON()
        #expect(json.contains("\"eventType\":\"review\""))
        #expect(json.contains("\"isKnown\":true"))

        StudyTelemetryManager.shared.clearEvents()
        #expect(StudyTelemetryManager.shared.eventsCount() == 0)
    }
}

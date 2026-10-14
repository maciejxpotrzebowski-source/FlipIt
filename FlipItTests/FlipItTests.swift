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

        // Normal mode
        let resultNormal = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: false,
            isInChallengeMode: false,
            preferredSide: .front
        )
        #expect(resultNormal?.reason != .moraleRescue)

        // Morale Rescue triggered! Must pick easyCard
        let resultRescue = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: true,
            isInChallengeMode: false,
            preferredSide: .front
        )
        #expect(resultRescue?.reason == .moraleRescue)
        #expect(resultRescue?.card.front == "Easy")
    }

    @Test("AdaptiveCardSelector triggers Challenge Engine after consecutive successes")
    func testAdaptiveSelectorChallengeEngine() {
        let deckId = UUID()
        let normalCard = Flashcard(front: "Normal", back: "Normalne", box: 2, lastReviewDate: Date(), correctCount: 5, incorrectCount: 1)
        let leechCard = Flashcard(front: "Leech", back: "Trudny orzech", box: 1, lastReviewDate: Date(), correctCount: 2, incorrectCount: 4)

        let pool = [(card: normalCard, deckId: deckId), (card: leechCard, deckId: deckId)]

        // Normal mode
        let resultNormal = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: false,
            isInChallengeMode: false,
            preferredSide: .front
        )
        #expect(resultNormal?.reason != .challengeLeech)

        // Challenge Engine triggered! Must pick leechCard
        let resultChallenge = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: false,
            isInChallengeMode: true,
            preferredSide: .front
        )
        #expect(resultChallenge?.reason == .challengeLeech)
        #expect(resultChallenge?.card.front == "Leech")
    }

    @Test("AdaptiveCardSelector maintains continuous Rescue Mode across failures until success")
    func testAdaptiveSelectorContinuousRescueMode() {
        let deckId = UUID()
        let hardCard1 = Flashcard(front: "Hard1", back: "T1", box: 0, correctCount: 0, incorrectCount: 4)
        let hardCard2 = Flashcard(front: "Hard2", back: "T2", box: 0, correctCount: 1, incorrectCount: 5)
        let easyCard1 = Flashcard(front: "Easy1", back: "Ł1", box: 3, correctCount: 8, incorrectCount: 1)
        let easyCard2 = Flashcard(front: "Easy2", back: "Ł2", box: 2, correctCount: 6, incorrectCount: 1)

        let pool = [
            (card: hardCard1, deckId: deckId),
            (card: hardCard2, deckId: deckId),
            (card: easyCard1, deckId: deckId),
            (card: easyCard2, deckId: deckId)
        ]

        // 1. Initial selection in rescue mode
        let result1 = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: true,
            isInChallengeMode: false,
            currentCardId: nil,
            preferredSide: .front
        )
        #expect(result1?.reason == .moraleRescue)
        #expect(result1?.card.box ?? 0 >= 2)

        // 2. Following selection with failure (still in rescue mode, excluding current card)
        let result2 = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: true,
            isInChallengeMode: false,
            currentCardId: result1?.card.id,
            preferredSide: .front
        )
        #expect(result2?.reason == .moraleRescue)
        #expect(result2?.card.id != result1?.card.id)
        #expect(result2?.card.box ?? 0 >= 2)
    }

    @Test("AdaptiveCardSelector maintains continuous Challenge Mode across successes until error")
    func testAdaptiveSelectorContinuousChallengeMode() {
        let deckId = UUID()
        let easyCard = Flashcard(front: "Easy", back: "Łatwe", box: 4, lastReviewDate: Date(), correctCount: 10, incorrectCount: 0)
        let leechCard1 = Flashcard(front: "Leech1", back: "T1", box: 1, lastReviewDate: Date(), correctCount: 2, incorrectCount: 4)
        let leechCard2 = Flashcard(front: "Leech2", back: "T2", box: 0, lastReviewDate: Date(), correctCount: 1, incorrectCount: 5)

        let pool = [
            (card: easyCard, deckId: deckId),
            (card: leechCard1, deckId: deckId),
            (card: leechCard2, deckId: deckId)
        ]

        // 1. Initial selection in challenge mode
        let result1 = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: false,
            isInChallengeMode: true,
            currentCardId: nil,
            preferredSide: .front
        )
        #expect(result1?.reason == .challengeLeech || result1?.reason == .challengeNew)
        #expect(result1?.card.front.starts(with: "Leech") == true)

        // 2. Continuous challenge: after answering correctly, challenge mode continues and avoids repeating the same card
        let result2 = AdaptiveCardSelector.selectNextCard(
            from: pool,
            isInRescueMode: false,
            isInChallengeMode: true,
            currentCardId: result1?.card.id,
            preferredSide: .front
        )
        #expect(result2?.reason == .challengeLeech || result2?.reason == .challengeNew)
        #expect(result2?.card.id != result1?.card.id)
        #expect(result2?.card.front.starts(with: "Leech") == true)
    }

    @Test("AdaptiveCardSelector reasons have no visible badges (silent adaptation)")
    func testSilentBadges() {
        #expect(AdaptiveCardSelector.SelectionReason.moraleRescue.displayBadge == nil)
        #expect(AdaptiveCardSelector.SelectionReason.challengeLeech.displayBadge == nil)
        #expect(AdaptiveCardSelector.SelectionReason.challengeNew.displayBadge == nil)
        #expect(AdaptiveCardSelector.SelectionReason.normalDue.displayBadge == nil)
        #expect(AdaptiveCardSelector.SelectionReason.standardPractice.displayBadge == nil)
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

    @Test("calculateSyncDiff categorizes all 5 sync diff categories properly")
    @MainActor
    func testCalculateSyncDiffAllFiveCategories() {
        let store = FlipItStore()
        let deckId = UUID()

        // 1. Base market cards (original state of author's deck when downloaded)
        let baseCards = [
            SharedCard(front: "Dog", back: "Pies"),
            SharedCard(front: "Cat", back: "Kot"),
            SharedCard(front: "Bird", back: "Ptak"),
            SharedCard(front: "Fish", back: "Ryba")
        ]

        // 2. Local deck cards
        let localDog = Flashcard(front: "Dog", back: "Pies") // unchanged
        let localCat = Flashcard(front: "Cat", back: "Kot") // user untouched, author updated
        let localBird = Flashcard(front: "Bird", back: "Ptaszysko") // user modified
        let localFish = Flashcard(front: "Fish", back: "Ryba") // author deleted
        let localFox = Flashcard(front: "Fox", back: "Lis") // user added

        let localDeck = Deck(
            id: deckId,
            name: "Animal Vocab",
            cards: [localDog, localCat, localBird, localFish, localFox],
            shareCode: "ANML1234",
            isMarketAuthor: false,
            syncedMarketCards: baseCards
        )
        store.decks = [localDeck]

        // 3. Remote deck published by author
        let remotePayload = [
            SharedCard(front: "Dog", back: "Pies"), // unchanged
            SharedCard(front: "Cat", back: "Kotek"), // authorUpdated
            SharedCard(front: "Bird", back: "Ptaszek"), // userModified (conflict)
            SharedCard(front: "Horse", back: "Koń") // authorAdded
            // "Fish" is omitted by author -> authorDeleted
        ]

        let remoteDeck = SharedDeck(
            shareCode: "ANML1234",
            title: "Animal Vocab",
            cardsCount: 4,
            cardsPayload: remotePayload
        )

        // 4. Calculate diff
        guard let diff = store.calculateSyncDiff(deckId: deckId, remoteDeck: remoteDeck) else {
            Issue.record("Failed to calculate sync diff")
            return
        }

        // 5. Verify all 5 categories
        // Category 1: authorAdded
        #expect(diff.addedCards.count == 1)
        #expect(diff.addedCards.first?.front == "Horse")
        #expect(diff.addedCards.first?.newBack == "Koń")
        #expect(diff.addedCards.first?.changeType == .authorAdded)
        #expect(diff.addedCards.first?.isSelected == true)

        // Category 2: authorUpdated
        #expect(diff.authorUpdatedCards.count == 1)
        #expect(diff.authorUpdatedCards.first?.front == "Cat")
        #expect(diff.authorUpdatedCards.first?.newBack == "Kotek")
        #expect(diff.authorUpdatedCards.first?.oldBack == "Kot")
        #expect(diff.authorUpdatedCards.first?.changeType == .authorUpdated)
        #expect(diff.authorUpdatedCards.first?.isSelected == true)

        // Category 3: userModified (conflict)
        #expect(diff.userModifiedCards.count == 1)
        #expect(diff.userModifiedCards.first?.front == "Bird")
        #expect(diff.userModifiedCards.first?.newBack == "Ptaszek")
        #expect(diff.userModifiedCards.first?.oldBack == "Ptaszysko")
        #expect(diff.userModifiedCards.first?.changeType == .userModified)
        #expect(diff.userModifiedCards.first?.isSelected == false)

        // Category 4: authorDeleted
        #expect(diff.deletedCards.count == 1)
        #expect(diff.deletedCards.first?.front == "Fish")
        #expect(diff.deletedCards.first?.changeType == .authorDeleted)
        #expect(diff.deletedCards.first?.isSelected == false)

        // Category 5: userAdded
        #expect(diff.userAddedCardsCount == 1)
        #expect(diff.unchangedCount == 1)
    }

    @Test("applyCustomSync preserves Leitner progress and stats during updates")
    @MainActor
    func testSyncPreservesLeitnerProgressAndStats() {
        let store = FlipItStore()
        let deckId = UUID()
        let reviewDate = Date(timeIntervalSince1970: 1800000000)

        let baseCards = [
            SharedCard(front: "Cat", back: "Kot"),
            SharedCard(front: "Fish", back: "Ryba")
        ]

        var catCard = Flashcard(front: "Cat", back: "Kot")
        catCard.box = 3
        catCard.streak = 5
        catCard.isLearned = false
        catCard.nextReviewDate = reviewDate
        catCard.correctCount = 12
        catCard.incorrectCount = 2

        let localDeck = Deck(
            id: deckId,
            name: "Animals",
            cards: [catCard],
            shareCode: "ANML9999",
            isMarketAuthor: false,
            syncedMarketCards: baseCards
        )
        store.decks = [localDeck]

        let remotePayload = [
            SharedCard(front: "Cat", back: "Kotek"),
            SharedCard(front: "Horse", back: "Koń")
        ]

        let remoteDeck = SharedDeck(
            shareCode: "ANML9999",
            title: "Animals Updated",
            cardsCount: 2,
            cardsPayload: remotePayload
        )

        let authorUpdated = [
            FlipItStore.SyncCardItem(front: "Cat", newBack: "Kotek", oldBack: "Kot", changeType: .authorUpdated, isSelected: true)
        ]
        let added = [
            FlipItStore.SyncCardItem(front: "Horse", newBack: "Koń", oldBack: nil, changeType: .authorAdded, isSelected: true)
        ]

        store.applyCustomSync(
            deckId: deckId,
            remoteDeck: remoteDeck,
            userModifiedItems: [],
            authorUpdatedItems: authorUpdated,
            addedItems: added,
            deletedItems: []
        )

        let updatedDeck = store.decks.first(where: { $0.id == deckId })!
        let updatedCat = updatedDeck.cards.first(where: { $0.front == "Cat" })!

        // Back is updated
        #expect(updatedCat.back == "Kotek")

        // Leitner progress & metrics are strictly preserved!
        #expect(updatedCat.box == 3)
        #expect(updatedCat.streak == 5)
        #expect(updatedCat.isLearned == false)
        #expect(updatedCat.nextReviewDate == reviewDate)
        #expect(updatedCat.correctCount == 12)
        #expect(updatedCat.incorrectCount == 2)

        // New card starts at initial box 0
        let newHorse = updatedDeck.cards.first(where: { $0.front == "Horse" })!
        #expect(newHorse.back == "Koń")
        #expect(newHorse.box == 0)
        #expect(newHorse.streak == 0)
        #expect(newHorse.isLearned == false)
    }
}

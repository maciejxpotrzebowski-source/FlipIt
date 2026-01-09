import AppIntents
import WidgetKit
import SwiftUI

// --- INTENT OZNACZANIA KARTY (X lub V) ---
struct MarkCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Mark Card"
    static var description: IntentDescription = "Marks the card and draws a new one."

    @Parameter(title: "Card ID") var cardID: String
    @Parameter(title: "Is Known") var isKnown: Bool

    init() {}

    init(cardID: UUID, isKnown: Bool) {
        self.cardID = cardID.uuidString
        self.isKnown = isKnown
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let store = FlipItStore()

            // 1. Oznaczamy, że widget był użyty (reset koloru czerwonego)
            store.bumpWidgetInteraction()

            // 2. Logika aktualizacji postępu (streak)
            store.updateStreakAfterWidgetAction(cardIdString: cardID, isKnown: isKnown)

            // 3. Usuwamy zapisaną kartę -> losowanie nowej
            UserDefaults(suiteName: APP_GROUP_ID)?.removeObject(forKey: "WidgetState")

            store.saveData()
        }
        return .result()
    }
}

// --- INTENT ODWRACANIA KARTY (ŚRODKOWY PRZYCISK) ---
struct FlipCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Flip Card"

    @Parameter(title: "Card ID") var cardID: String
    @Parameter(title: "Flip State") var flipState: Bool

    init() {}

    init(cardID: UUID, flipState: Bool) {
        self.cardID = cardID.uuidString
        self.flipState = flipState
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let store = FlipItStore()

            // 1. Oznaczamy użycie
            store.bumpWidgetInteraction()

            if let uuid = UUID(uuidString: cardID) {
                // 2. Zapisujemy stan obrotu
                store.saveWidgetState(cardId: uuid, isFlipped: flipState)
            }
            // Tu wystarczy reload, bo bumpWidgetInteraction() zapisał już datę w Settings
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

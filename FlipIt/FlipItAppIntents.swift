import AppIntents
import WidgetKit
import SwiftUI
import AVFoundation

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
        let cId = cardID
        let known = isKnown
        await MainActor.run {
            let store = FlipItStore()

            // 1. Oznaczamy, że widget był użyty (reset koloru nieaktywności)
            store.bumpWidgetInteraction()

            // 2. Usuwamy stan obrotu, aby kolejna karta pojawiła się przodem
            UserDefaults(suiteName: APP_GROUP_ID)?.removeObject(forKey: "WidgetState")

            // 3. Aktualizacja postępu (streak/box/leitner) — wewnętrznie wykonuje pojedynczy saveData() i przeładowanie widżetu
            store.updateStreakAfterWidgetAction(cardIdString: cId, isKnown: known)
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
        let cId = cardID
        let state = flipState
        await MainActor.run {
            // Szybki, natychmiastowy zapis w pamięci współdzielonej bez narzutu ładowania całej bazy talii z dysku
            if let defaults = UserDefaults(suiteName: APP_GROUP_ID) {
                if let uuid = UUID(uuidString: cId) {
                    let widgetState = FlipItStore.WidgetState(currentCardId: uuid, isFlipped: state)
                    if let data = try? JSONEncoder().encode(widgetState) {
                        defaults.set(data, forKey: "WidgetState")
                    }
                }

                // Aktualizacja daty użycia widżetu w ustawieniach
                if let settingsData = defaults.data(forKey: "AppSettings"),
                   var settings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
                    settings.lastWidgetInteractionDate = Date()
                    if let updatedData = try? JSONEncoder().encode(settings) {
                        defaults.set(updatedData, forKey: "AppSettings")
                    }
                }
            }

            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }
}

private final class IntentSpeechCoordinator {
    static let shared = IntentSpeechCoordinator()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(text: String, language: String) {
        #if canImport(UIKit)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}

struct SpeakCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Speak Card"
    static var openAppWhenRun: Bool = true // Wymagane, aby dźwięk zadziałał pewnie

    @Parameter(title: "Text") var text: String
    @Parameter(title: "Language") var language: String

    init() {}
    init(text: String, language: String) {
        self.text = text
        self.language = language
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentSpeechCoordinator.shared.speak(text: text, language: language)
        return .result()
    }
}

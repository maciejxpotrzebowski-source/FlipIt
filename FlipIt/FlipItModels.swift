import Foundation
import SwiftUI
import Combine
import AppIntents
import WidgetKit

// --- STAŁA GRUPY ---
let APP_GROUP_ID = "group.com.maciek.FlipIt"

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    static var appGroupedBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }

    static var appSecondaryGroupedBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.white
        #endif
    }
}

extension View {
    @ViewBuilder
    func appInsetGroupedListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.inset)
        #endif
    }

    @ViewBuilder
    func appNavigationLinkPickerStyle() -> some View {
        #if os(iOS)
        self.pickerStyle(.navigationLink)
        #else
        self.pickerStyle(.menu)
        #endif
    }
}

extension ToolbarItemPlacement {
    static var appTopBarLeading: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .navigation
        #endif
    }

    static var appTopBarTrailing: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .primaryAction
        #endif
    }
}

#if !os(iOS)
public enum NavigationBarItemTitleDisplayModePlaceholder {
    case automatic, inline, large
}

extension View {
    public func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItemTitleDisplayModePlaceholder) -> some View {
        self
    }
}
#endif

struct AppLimits {
    static let deckName = 40
    static let deckDescription = 300
    static let label = 30
    static let cardContent = 400
    static let widgetContent = 40
}

enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case polish = "pl"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .polish: return "Polski"
        }
    }

    static var systemDefault: AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        if preferred.lowercased().starts(with: "pl") {
            return .polish
        }
        return .english
    }
}

let availableLanguages: [String: String] = [
    "en-US": "English (US)",
    "en-GB": "English (UK)",
    "pl-PL": "Polish",
    "de-DE": "German",
    "es-ES": "Spanish",
    "fr-FR": "French",
    "it-IT": "Italian",
    "pt-BR": "Portuguese (Brazil)",
    "pt-PT": "Portuguese (Portugal)",
    "ru-RU": "Russian",
    "uk-UA": "Ukrainian",
    "nl-NL": "Dutch",
    "tr-TR": "Turkish",
    "sv-SE": "Swedish",
    "da-DK": "Danish",
    "nb-NO": "Norwegian",
    "fi-FI": "Finnish",
    "hr-HR": "Croatian",
    "cs-CZ": "Czech",
    "sk-SK": "Slovak",
    "hu-HU": "Hungarian",
    "ro-RO": "Romanian",
    "el-GR": "Greek",
    "ja-JP": "Japanese",
    "zh-CN": "Chinese (Simplified)",
    "zh-TW": "Chinese (Traditional)",
    "ko-KR": "Korean",
    "vi-VN": "Vietnamese",
    "hi-IN": "Hindi",
    "id-ID": "Indonesian",
    "th-TH": "Thai",
    "ar-SA": "Arabic",
    "he-IL": "Hebrew"
]

func getLangCode(_ code: String) -> String {
    return String(code.prefix(2)).uppercased()
}

// --- DATA MODELS ---
struct AnimationConfig {
    // Szybkość obracania karty (im mniejsza liczba, tym szybciej)
    static let flipDuration: Double = 0.4//czas potrzebny do odwrócenia karty, kiedy się na nią naciśnie.

    // Opóźnienie po przesunięciu karty, zanim pojawi się następna (tzw. czas na "oddech")
    static let nextCardDelay: Double = 0.2//opoznienie przed pojawieniem się nowej karty

    // Szybkość wlatywania nowej karty od dołu
    static let flyInDuration: Double = 0.5//czas potrzebny na pojawienie sie nowej karty po przeswipowaniu wczesniejszej
}

struct Flashcard: Identifiable, Codable, Equatable {
    var id = UUID()
    var front: String
    var back: String
    var isLearned: Bool = false
    var streak: Int = 0
    var createdAt: Date = Date()

    init(id: UUID = UUID(), front: String, back: String, isLearned: Bool = false, streak: Int = 0, createdAt: Date = Date()) {
        self.id = id
        self.front = front
        self.back = back
        self.isLearned = isLearned
        self.streak = streak
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        front = try container.decode(String.self, forKey: .front)
        back = try container.decode(String.self, forKey: .back)
        isLearned = try container.decodeIfPresent(Bool.self, forKey: .isLearned) ?? false
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

enum LearningFactor: Double, Codable, CaseIterable {
    case veryFrequent = 0.25
    case frequent = 0.5
    case standard = 1.0
    case rare = 2.0
    case veryRare = 4.0

    var label: String {
        switch self {
        case .veryFrequent: return "Very Frequent"
        case .frequent:     return "Frequent"
        case .standard:     return "Standard"
        case .rare:         return "Rare"
        case .veryRare:     return "Very Rare"
        }
    }
}

struct Deck: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var description: String = ""
    var frontLabel: String = "Front"
    var backLabel: String = "Back"

    // NOWE POLA JĘZYKOWE (Dodane)
    var frontLanguage: String = "en-US"
    var backLanguage: String = "pl-PL"

    var cards: [Flashcard]

    var progress: Double {
        if cards.isEmpty { return 0.0 }
        let learnedCount = cards.filter { $0.isLearned }.count
        return Double(learnedCount) / Double(cards.count)
    }

    // Zaktualizowany inicjalizator
    init(id: UUID = UUID(), name: String, description: String = "", frontLabel: String = "Front", backLabel: String = "Back", frontLanguage: String = "en-US", backLanguage: String = "pl-PL", cards: [Flashcard]) {
        self.id = id
        self.name = name
        self.description = description
        self.frontLabel = frontLabel
        self.backLabel = backLabel
        self.frontLanguage = frontLanguage
        self.backLanguage = backLanguage
        self.cards = cards
    }

    // Zaktualizowane dekodowanie (dla kompatybilności wstecznej)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cards = try container.decode([Flashcard].self, forKey: .cards)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        frontLabel = try container.decodeIfPresent(String.self, forKey: .frontLabel) ?? "Front"
        backLabel = try container.decodeIfPresent(String.self, forKey: .backLabel) ?? "Back"

        // Dekodowanie z wartością domyślną dla starszych danych
        frontLanguage = try container.decodeIfPresent(String.self, forKey: .frontLanguage) ?? "en-US"
        backLanguage = try container.decodeIfPresent(String.self, forKey: .backLanguage) ?? "pl-PL"
    }
}
enum CardSortOption: String, Codable, CaseIterable {
    case frontAZ = "Front (A-Z)"
    case frontZA = "Front (Z-A)"
    case backAZ = "Back (A-Z)"
    case backZA = "Back (Z-A)"
    case createdOldest = "Oldest First"
    case createdNewest = "Newest First"
    case mostKnown = "Known First"
    case mostUnknown = "Unknown First"
}

enum StudySideOption: String, Codable, CaseIterable {
    case front = "Front First"
    case back = "Back First"
    case random = "Random Mix"
}

struct AppSettings: Codable {
    var confirmDelete: Bool = true
    var sortOption: CardSortOption = .frontAZ
    var studySide: StudySideOption = .front
    var onlyUnlearned: Bool = false
    var learningFactorValue: Double = 1.0
    var usedDeckIDs: Set<UUID> = []
    var isDarkMode: Bool = false

    // --- NOWE OPCJE DLA WIDGETU ---
    var widgetColorfulButtons: Bool = true
    var widgetInactivityColor: Bool = true
    var lastWidgetInteractionDate: Date = Date() // Data ostatniego kliknięcia
    var appLanguage: AppLanguage = .systemDefault
    // Domyślne języki dla nowych talii (np. użytkownik uczy się głównie Hiszpańskiego)
    var defaultFrontLanguage: String = "en-US"
    var defaultBackLanguage: String = "pl-PL"
    var isPremiumUser: Bool = false

    init(
        confirmDelete: Bool = true,
        sortOption: CardSortOption = .frontAZ,
        studySide: StudySideOption = .front,
        onlyUnlearned: Bool = false,
        learningFactorValue: Double = 1.0,
        usedDeckIDs: Set<UUID> = [],
        isDarkMode: Bool = false,
        widgetColorfulButtons: Bool = true,
        widgetInactivityColor: Bool = true,
        lastWidgetInteractionDate: Date = Date(),
        appLanguage: AppLanguage = .systemDefault,
        defaultFrontLanguage: String = "en-US",
        defaultBackLanguage: String = "pl-PL",
        isPremiumUser: Bool = false
    ) {
        self.confirmDelete = confirmDelete
        self.sortOption = sortOption
        self.studySide = studySide
        self.onlyUnlearned = onlyUnlearned
        self.learningFactorValue = learningFactorValue
        self.usedDeckIDs = usedDeckIDs
        self.isDarkMode = isDarkMode
        self.widgetColorfulButtons = widgetColorfulButtons
        self.widgetInactivityColor = widgetInactivityColor
        self.lastWidgetInteractionDate = lastWidgetInteractionDate
        self.appLanguage = appLanguage
        self.defaultFrontLanguage = defaultFrontLanguage
        self.defaultBackLanguage = defaultBackLanguage
        self.isPremiumUser = isPremiumUser
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        confirmDelete = try container.decodeIfPresent(Bool.self, forKey: .confirmDelete) ?? true
        sortOption = try container.decodeIfPresent(CardSortOption.self, forKey: .sortOption) ?? .frontAZ
        studySide = try container.decodeIfPresent(StudySideOption.self, forKey: .studySide) ?? .front
        onlyUnlearned = try container.decodeIfPresent(Bool.self, forKey: .onlyUnlearned) ?? false
        learningFactorValue = try container.decodeIfPresent(Double.self, forKey: .learningFactorValue) ?? 1.0
        usedDeckIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .usedDeckIDs) ?? []
        isDarkMode = try container.decodeIfPresent(Bool.self, forKey: .isDarkMode) ?? false
        widgetColorfulButtons = try container.decodeIfPresent(Bool.self, forKey: .widgetColorfulButtons) ?? true
        widgetInactivityColor = try container.decodeIfPresent(Bool.self, forKey: .widgetInactivityColor) ?? true
        lastWidgetInteractionDate = try container.decodeIfPresent(Date.self, forKey: .lastWidgetInteractionDate) ?? Date()
        appLanguage = try container.decodeIfPresent(AppLanguage.self, forKey: .appLanguage) ?? .systemDefault
        defaultFrontLanguage = try container.decodeIfPresent(String.self, forKey: .defaultFrontLanguage) ?? "en-US"
        defaultBackLanguage = try container.decodeIfPresent(String.self, forKey: .defaultBackLanguage) ?? "pl-PL"
        isPremiumUser = try container.decodeIfPresent(Bool.self, forKey: .isPremiumUser) ?? false
    }
}

// --- VIEW MODEL (STORE) ---

@MainActor
class FlipItStore: ObservableObject {
    @Published var decks: [Deck] = []
    @Published var settings: AppSettings = AppSettings()

    private let fileName = "flipit_data.json"

    init() {
        loadData()
        if decks.isEmpty {
            decks.append(Deck(name: "My flashcards", description: "My primary deck", cards: [
                Flashcard(front: "Cat", back: "Kot"),
                Flashcard(front: "Dog", back: "Pies"),
                Flashcard(front: "Apple", back: "Jabłko")
            ]))
            saveData()
        }
        #if canImport(UIKit)
        let foregroundNotification: Notification.Name? = UIApplication.willEnterForegroundNotification
        #elseif canImport(AppKit)
        let foregroundNotification: Notification.Name? = NSApplication.willBecomeActiveNotification
        #else
        let foregroundNotification: Notification.Name? = nil
        #endif

        if let notificationName = foregroundNotification {
            NotificationCenter.default.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    self.reloadData()
                }
            }
        }
    }

    // MARK: - Persistence

    func getDocumentsDirectory() -> URL {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_ID) {
            return url
        }
        print("CRITICAL: App Group not found. Using local documents.")
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func deleteAllCards(deckId: UUID) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].cards.removeAll()
            saveData()
        }
    }

    func deleteLearnedCards(deckId: UUID, minStreak: Int) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].cards.removeAll { $0.streak >= minStreak }
            saveData()
        }
    }

    func resetAllProgress(deckId: UUID) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            for i in 0..<decks[index].cards.count {
                decks[index].cards[i].streak = 0
                decks[index].cards[i].isLearned = false
            }
            saveData()
        }
    }

    func saveData() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(decks)
            try data.write(to: url)

            if let settingsData = try? JSONEncoder().encode(settings) {
                UserDefaults(suiteName: APP_GROUP_ID)?.set(settingsData, forKey: "AppSettings")
            }
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            print("Save failed: \(error.localizedDescription)")
        }
    }

    func loadData() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([Deck].self, from: data) {
                self.decks = decoded
            }
        }
        if let settingsData = UserDefaults(suiteName: APP_GROUP_ID)?.data(forKey: "AppSettings"),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            self.settings = decodedSettings
        }
    }

    // --- WIDGET HELPER ---

    struct WidgetState: Codable {
        var currentCardId: UUID?
        var isFlipped: Bool
    }

    func saveWidgetState(cardId: UUID, isFlipped: Bool) {
        let state = WidgetState(currentCardId: cardId, isFlipped: isFlipped)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults(suiteName: APP_GROUP_ID)?.set(data, forKey: "WidgetState")
        }
    }

    func loadWidgetState() -> WidgetState? {
        guard let data = UserDefaults(suiteName: APP_GROUP_ID)?.data(forKey: "WidgetState") else { return nil }
        return try? JSONDecoder().decode(WidgetState.self, from: data)
    }

    func cleanupWidgetStateIfNeeded() {
        if let widgetState = loadWidgetState(), let cardId = widgetState.currentCardId {
            let allCardIds = Set(decks.flatMap { $0.cards.map { $0.id } })
            if !allCardIds.contains(cardId) {
                UserDefaults(suiteName: APP_GROUP_ID)?.removeObject(forKey: "WidgetState")
            }
        }
    }

    // NOWA FUNKCJA: Aktualizuje datę ostatniego użycia widgetu
    func bumpWidgetInteraction() {
        settings.lastWidgetInteractionDate = Date()
        // Zapisujemy same ustawienia do Shared Defaults (szybki zapis bez całej bazy)
        if let settingsData = try? JSONEncoder().encode(settings) {
            UserDefaults(suiteName: APP_GROUP_ID)?.set(settingsData, forKey: "AppSettings")
        }
        // Pełny save też można wywołać, ale przy intentach i tak go robimy na końcu
    }

    func updateStreakAfterWidgetAction(cardIdString: String, isKnown: Bool) {
        for (dIndex, deck) in decks.enumerated() {
            if let cIndex = deck.cards.firstIndex(where: { $0.id.uuidString == cardIdString }) {
                if isKnown {
                    decks[dIndex].cards[cIndex].streak += 1
                } else {
                    decks[dIndex].cards[cIndex].streak = 0
                }
                decks[dIndex].cards[cIndex].isLearned = (decks[dIndex].cards[cIndex].streak > 0)
                saveData()
                break
            }
        }
    }

    // --- ACTIONS (CRUD) ---

    func addDeck(name: String, description: String, frontLabel: String, backLabel: String, frontLanguage: String, backLanguage: String) {
            let finalFront = frontLabel.isEmpty ? "Front" : frontLabel
            let finalBack = backLabel.isEmpty ? "Back" : backLabel

            // Tworzymy deck z językami
            let newDeck = Deck(
                name: name,
                description: description,
                frontLabel: finalFront,
                backLabel: finalBack,
                frontLanguage: frontLanguage,
                backLanguage: backLanguage, // Przekazujemy języki
                cards: []
            )
        if decks.isEmpty {
                decks.append(newDeck)
            } else {
                decks.insert(newDeck, at: 1)
            }
            saveData()
        }

    func deleteDeck(at offsets: IndexSet) {
        if offsets.contains(0) { return }
        let deletedIDs = offsets.map { decks[$0].id }
        decks.remove(atOffsets: offsets)
        for id in deletedIDs {
            settings.usedDeckIDs.remove(id)
        }
        cleanupWidgetStateIfNeeded()
        saveData()
    }

    func addCard(to deckId: UUID, front: String, back: String) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].cards.append(Flashcard(front: front, back: back))
            saveData()
        }
    }

    func updateCardStatus(deckId: UUID, cardId: UUID, isLearned: Bool) {
        if let dIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cIndex = decks[dIndex].cards.firstIndex(where: { $0.id == cardId }) {
            decks[dIndex].cards[cIndex].isLearned = isLearned
            saveData()
        }
    }

    func updateDeck(deckId: UUID, name: String, description: String, frontLabel: String, backLabel: String, frontLanguage: String, backLanguage: String) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            var finalName = name
            if index == 0 {
                finalName = decks[index].name
            }
            decks[index].name = finalName
            decks[index].description = description
            decks[index].frontLabel = frontLabel
            decks[index].backLabel = backLabel
            // Aktualizacja języków
            decks[index].frontLanguage = frontLanguage
            decks[index].backLanguage = backLanguage
            saveData()
        }
    }

    func deleteDeck(id: UUID) {
        if let index = decks.firstIndex(where: { $0.id == id }) {
            if index == 0 { return } // Blokada dla pierwszego elementu
            decks.remove(at: index)
            settings.usedDeckIDs.remove(id)
            cleanupWidgetStateIfNeeded()
            saveData()
        }
    }

    func moveDeck(from source: IndexSet, to destination: Int) {
        if source.contains(0) { return }
        if destination == 0 { return }
        decks.move(fromOffsets: source, toOffset: destination)
        saveData()
    }

    func transferCards(from sourceId: UUID, to destId: UUID, cardIds: Set<UUID>, deleteFromSource: Bool, swapFaces: Bool, skipDuplicates: Bool) {
        guard let sourceIndex = decks.firstIndex(where: { $0.id == sourceId }),
              let destIndex = decks.firstIndex(where: { $0.id == destId }) else { return }

        // 1. Wyciągamy karty zaznaczone przez użytkownika
        let cardsToProcess = decks[sourceIndex].cards.filter { cardIds.contains($0.id) }

        var cardsToAdd: [Flashcard] = []

        // 2. Przetwarzamy każdą kartę (sprawdzamy duplikaty)
        for card in cardsToProcess {
            let finalFront = swapFaces ? card.back : card.front
            let finalBack = swapFaces ? card.front : card.back

            // Sprawdzamy czy karta już istnieje w talii docelowej
            let isDuplicate = decks[destIndex].cards.contains { existing in
                existing.front == finalFront && existing.back == finalBack
            }

            // Jeśli mamy pominąć duplikaty I karta jest duplikatem -> NIE dodajemy do listy "do dodania"
            if skipDuplicates && isDuplicate {
                continue
            }

            // W przeciwnym razie tworzymy nową kartę
            let newCard = Flashcard(front: finalFront, back: finalBack, isLearned: false, streak: 0)
            cardsToAdd.append(newCard)
        }

        // 3. Dodajemy (tylko te, które przeszły filtr) do celu
        decks[destIndex].cards.append(contentsOf: cardsToAdd)

        // 4. Jeśli wybrano opcję "Przenieś" (Delete form source), usuwamy WSZYSTKIE zaznaczone oryginały
        // (Nawet te, które nie zostały dodane do celu bo były duplikatami - zgodnie z Twoim życzeniem "w źródle ma je usunąć")
        if deleteFromSource {
            decks[sourceIndex].cards.removeAll { cardIds.contains($0.id) }
        }

        saveData()
    }

    func deleteCard(deckId: UUID, cardId: UUID) {
        if let dIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cIndex = decks[dIndex].cards.firstIndex(where: { $0.id == cardId }) {
            decks[dIndex].cards.remove(at: cIndex)
            saveData()
        }
    }

    func updateCardContent(deckId: UUID, cardId: UUID, front: String, back: String) {
        if let dIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cIndex = decks[dIndex].cards.firstIndex(where: { $0.id == cardId }) {
            decks[dIndex].cards[cIndex].front = front
            decks[dIndex].cards[cIndex].back = back
            saveData()
        }
    }

    func updateStreak(deckId: UUID, cardId: UUID, newStreak: Int) {
        if let dIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cIndex = decks[dIndex].cards.firstIndex(where: { $0.id == cardId }) {
            decks[dIndex].cards[cIndex].streak = newStreak
            decks[dIndex].cards[cIndex].isLearned = (newStreak > 0)
            saveData()
        }
    }

    // --- IMPORT LOGIC ---

    func loadCardsFromURL(_ url: URL) -> [Flashcard] {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }

            do {
                let data = try Data(contentsOf: url)
                var loadedCards: [Flashcard] = []

                if url.pathExtension.lowercased() == "json" {
                    loadedCards = try parseJSON(data: data)
                } else {
                    if let content = decodeText(from: data) {
                        loadedCards = parseCSV(content: content)
                    }
                }

                // UŻYCIE GLOBALNEGO LIMITU
                let limit = AppLimits.cardContent

                let processedCards = loadedCards.map { card -> Flashcard in
                    var newFront = card.front
                    var newBack = card.back

                    if newFront.count > limit {
                        newFront = String(newFront.prefix(limit)) + "..."
                    }
                    if newBack.count > limit {
                        newBack = String(newBack.prefix(limit)) + "..."
                    }
                    return Flashcard(front: newFront, back: newBack)
                }

                var uniqueCards: [Flashcard] = []
                var seen = Set<String>()
                for card in processedCards {
                    let key = "\(card.front.trimmingCharacters(in: .whitespaces).lowercased())|\(card.back.trimmingCharacters(in: .whitespaces).lowercased())"
                    if !seen.contains(key) {
                        seen.insert(key)
                        uniqueCards.append(card)
                    }
                }
                return uniqueCards
            } catch {
                print("Import load error: \(error.localizedDescription)")
                return []
            }
        }

    func deleteCards(deckId: UUID, cardIds: Set<UUID>) {
            if let dIndex = decks.firstIndex(where: { $0.id == deckId }) {
                // Usuwamy wszystkie karty, których ID znajduje się w zestawie cardIds
                decks[dIndex].cards.removeAll { cardIds.contains($0.id) }
                saveData()
            }
        }

    func reloadData() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)

        // 1. Ładowanie talii i kart
        if let data = try? Data(contentsOf: url) {
            if let decoded = try? JSONDecoder().decode([Deck].self, from: data) {
                // Musimy to zrobić na głównym wątku, aby UI zareagowało
                self.decks = decoded
            }
        }

        // 2. Ładowanie ustawień (tu są dane o postępie z widgetu)
        if let settingsData = UserDefaults(suiteName: APP_GROUP_ID)?.data(forKey: "AppSettings"),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            self.settings = decodedSettings
        }
    }

    func saveImportedCards(_ newCards: [Flashcard], to deckId: UUID) {
        if !newCards.isEmpty {
            DispatchQueue.main.async {
                if let index = self.decks.firstIndex(where: { $0.id == deckId }) {
                    let cardsToSave = newCards.map { Flashcard(front: $0.front, back: $0.back) }
                    self.decks[index].cards.append(contentsOf: cardsToSave)
                    self.saveData()
                }
            }
        }
    }

    private func parseJSON(data: Data) throws -> [Flashcard] {
        return try JSONDecoder().decode([Flashcard].self, from: data)
    }

    func parseCSV(content: String) -> [Flashcard] {
        var cards: [Flashcard] = []
        let normalizedContent = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        let rows = normalizedContent.components(separatedBy: "\n")
        for row in rows {
            if row.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let semicolonCount = row.filter { $0 == ";" }.count
            let commaCount = row.filter { $0 == "," }.count
            let separator = semicolonCount > commaCount ? ";" : ","

            let columns = row.components(separatedBy: separator)
            if columns.count >= 2 {
                let front = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let back = columns.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                if front.lowercased() == "front" && back.lowercased() == "back" { continue }
                if !front.isEmpty && !back.isEmpty {
                    cards.append(Flashcard(front: front, back: back))
                }
            }
        }
        return cards
    }

    private func decodeText(from data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        let cp1250 = String.Encoding(rawValue: 2147484898)
        if let text = String(data: data, encoding: cp1250) { return text }
        if let text = String(data: data, encoding: .isoLatin2) { return text }
        if let text = String(data: data, encoding: .ascii) { return text }
        return nil
    }
}

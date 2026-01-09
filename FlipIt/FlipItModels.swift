import Foundation
import SwiftUI
import Combine
import AppIntents
import WidgetKit

// --- STAŁA GRUPY ---
let APP_GROUP_ID = "group.com.maciek.FlipIt"

// --- DATA MODELS ---

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
    var cards: [Flashcard]

    var progress: Double {
        if cards.isEmpty { return 0.0 }
        let learnedCount = cards.filter { $0.isLearned }.count
        return Double(learnedCount) / Double(cards.count)
    }

    init(id: UUID = UUID(), name: String, description: String = "", frontLabel: String = "Front", backLabel: String = "Back", cards: [Flashcard]) {
        self.id = id
        self.name = name
        self.description = description
        self.frontLabel = frontLabel
        self.backLabel = backLabel
        self.cards = cards
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        cards = try container.decode([Flashcard].self, forKey: .cards)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        frontLabel = try container.decodeIfPresent(String.self, forKey: .frontLabel) ?? "Front"
        backLabel = try container.decodeIfPresent(String.self, forKey: .backLabel) ?? "Back"
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
            decks.append(Deck(name: "My fleshcards", description: "My primary deck", cards: [
                Flashcard(front: "Cat", back: "Kot"),
                Flashcard(front: "Dog", back: "Pies"),
                Flashcard(front: "Apple", back: "Jabłko")
            ]))
            saveData()
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
            }
        }
    }

    // --- ACTIONS (CRUD) ---

    func addDeck(name: String, description: String, frontLabel: String, backLabel: String) {
        let finalFront = frontLabel.isEmpty ? "Front" : frontLabel
        let finalBack = backLabel.isEmpty ? "Back" : backLabel
        let newDeck = Deck(name: name, description: description, frontLabel: finalFront, backLabel: finalBack, cards: [])
        decks.append(newDeck)
        saveData()
    }

    func deleteDeck(at offsets: IndexSet) {
            if offsets.contains(0) { return }
            decks.remove(atOffsets: offsets)
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

    func updateDeck(deckId: UUID, name: String, description: String, frontLabel: String, backLabel: String) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            var finalName = name
                        if index == 0 {
                            finalName = decks[index].name // Przywracamy starą nazwę
                        }
            decks[index].name = finalName
            decks[index].description = description
            decks[index].frontLabel = frontLabel
            decks[index].backLabel = backLabel
            saveData()
        }
    }

    func deleteDeck(id: UUID) {
            if let index = decks.firstIndex(where: { $0.id == id }) {
                if index == 0 { return } // Blokada dla pierwszego elementu
                decks.remove(at: index)
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

            var uniqueCards: [Flashcard] = []
            var seen = Set<String>()
            for card in loadedCards {
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

    private func parseCSV(content: String) -> [Flashcard] {
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

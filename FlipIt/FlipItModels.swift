import Foundation
import SwiftUI
import Combine

// --- DATA MODELS ---

struct Flashcard: Identifiable, Codable, Equatable {
    var id = UUID()
    var front: String
    var back: String
    var isLearned: Bool = false
}

struct Deck: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var cards: [Flashcard]
    
    var progress: Double {
        if cards.isEmpty { return 0.0 }
        let learnedCount = cards.filter { $0.isLearned }.count
        return Double(learnedCount) / Double(cards.count)
    }
}

struct AppSettings: Codable {
    var confirmDelete: Bool = true
    var retryFrequency: Int = 3 // Cards reappear after 3 turns if unknown
}

// --- VIEW MODEL (STORE) ---

class FlipItStore: ObservableObject {
    @Published var decks: [Deck] = []
    @Published var settings: AppSettings = AppSettings()
    
    private let fileName = "flipit_data.json"
    
    init() {
        loadData()
        if decks.isEmpty {
            // Demo data
            decks.append(Deck(name: "English - Demo", cards: [
                Flashcard(front: "Cat", back: "Kot"),
                Flashcard(front: "Dog", back: "Pies"),
                Flashcard(front: "Apple", back: "Jabłko")
            ]))
        }
    }
    
    // MARK: - Persistence
    
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
    
    func saveData() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(decks)
            // We are saving decks, for settings we could use UserDefaults or same file
            // For simplicity, let's save settings separately or just mock them here,
            // but in a real app, I'd wrap everything in a Root object.
            // Let's stick to saving Decks to JSON and Settings to UserDefaults.
            try data.write(to: url)
            
            if let settingsData = try? JSONEncoder().encode(settings) {
                UserDefaults.standard.set(settingsData, forKey: "AppSettings")
            }
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
        
        if let settingsData = UserDefaults.standard.data(forKey: "AppSettings"),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            self.settings = decodedSettings
        }
    }
    
    // MARK: - Actions
    
    func addDeck(name: String) {
        let newDeck = Deck(name: name, cards: [])
        decks.append(newDeck)
        saveData()
    }
    
    func deleteDeck(at offsets: IndexSet) {
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
}

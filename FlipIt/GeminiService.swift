import Foundation
import GoogleGenerativeAI

class GeminiService {
    // ZMIANA: Usuwamy hardcodowany klucz. Teraz pobieramy go bezpiecznie z managera.
    // Dzięki temu klucz nie widnieje w kodzie źródłowym.
    private var apiKey: String {
        return APIKeyManager.geminiKey
    }

    let modelName: String

    init(model: GeminiModelOption? = nil) {
        if let model = model {
            self.modelName = model.rawValue
        } else if let settingsData = UserDefaults(suiteName: APP_GROUP_ID)?.data(forKey: "AppSettings"),
                  let settings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            self.modelName = settings.geminiModel.rawValue
        } else {
            self.modelName = GeminiModelOption.flash35Lite.rawValue
        }
    }

    private lazy var model = GenerativeModel(name: modelName, apiKey: apiKey)

    func generateFlashcards(from prompt: String) async throws -> String {
        // Sprawdzenie bezpieczeństwa - jeśli klucz jest pusty, rzuć błąd
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key is missing in Info.plist"])
        }

        do {
            let response = try await model.generateContent(prompt)

            guard let text = response.text else {
                throw NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
            }

            return cleanResponse(text)
        } catch {
            // Automatyczny fallback do sprawdzonego, superszybkiego Gemini 3.5 Flash-Lite
            if modelName != GeminiModelOption.flash35Lite.rawValue {
                #if DEBUG
                print("⚠️ Model \(modelName) failed (\(error.localizedDescription)). Retrying with fallback: Gemini 3.5 Flash-Lite...")
                #endif
                let fallbackModel = GenerativeModel(name: GeminiModelOption.flash35Lite.rawValue, apiKey: apiKey)
                if let fallbackResponse = try? await fallbackModel.generateContent(prompt),
                   let text = fallbackResponse.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return cleanResponse(text)
                }
            }

            let friendlyMessage = friendlyErrorMessage(for: error)
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: friendlyMessage])
        }
    }

    private func friendlyErrorMessage(for error: Error) -> String {
        let desc = error.localizedDescription
        if desc.contains("GenerateContentError") || desc.contains("503") || desc.contains("high demand") || desc.contains("UNAVAILABLE") {
            return NSLocalizedString("AI service is temporarily busy. Please try again in a moment.", comment: "")
        } else if desc.contains("quota") || desc.contains("429") || desc.contains("RESOURCE_EXHAUSTED") {
            return NSLocalizedString("Daily AI limit reached. Please try again tomorrow or switch models.", comment: "")
        }
        return desc
    }

    // Funkcja czyszcząca: usuwa ```csv i ``` jeśli AI doda formatowanie markdown
    private func cleanResponse(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Usuń znaczniki bloku kodu na początku
        if cleaned.hasPrefix("```csv") {
            cleaned = String(cleaned.dropFirst(6))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }

        // Usuń znaczniki bloku kodu na końcu
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Auto Tagging & Level Classification

    func analyzeDeck(
        title: String,
        description: String,
        frontLanguage: String,
        backLanguage: String,
        sampleCards: [(front: String, back: String)],
        existingLevel: String? = nil,
        existingTags: [String] = []
    ) async -> DeckAnalysisResult {
        guard !apiKey.isEmpty else {
            return fallbackAnalysis(title: title, existingLevel: existingLevel, existingTags: existingTags)
        }

        // Przekazujemy wszystkie karty z talii bez sztucznych limitów
        let cardsSample = sampleCards.map { "\($0.front) = \($0.back)" }.joined(separator: "\n")
        let existingLevelStr = (existingLevel != nil && !existingLevel!.isEmpty) ? existingLevel! : "None"
        let existingTagsStr = existingTags.isEmpty ? "None" : existingTags.joined(separator: ", ")

        let prompt = """
        Analyze this flashcard deck and return a STRICT JSON object with two fields:
        1. "tags": An array of 3 to 5 concise, lowercase topic/theme tags (in Polish or English, no hashtags, e.g. ["angielski", "podroze", "matura"]).
        2. "level": If this is a language learning deck, identify the CEFR level: "A1", "A2", "B1", "B2", "C1", or "C2". If not a language deck or not applicable, return "General".

        CURRENT USER INPUT:
        - User-assigned level: "\(existingLevelStr)"
        - User-assigned tags: "\(existingTagsStr)"

        RULES & PREFERENCES:
        - PREFERENCE: If the user has already provided a level and/or tags, PREFER TO KEEP THEM UNCHANGED.
        - Level: You have the right to override the user's level ONLY if it is clearly inaccurate based on the flashcard content. If the user's level is reasonable or valid, KEEP IT. If user-assigned level is "None", determine the accurate CEFR level.
        - Tags: You have the right to add or remove tags, but prefer keeping user's tags unless clearly wrong. If user provided tags, preserve valid ones and add 1-2 complementary tags if needed (total 3-5). If none provided, generate 3-5 appropriate tags.

        Deck title: "\(title)"
        Deck description: "\(description)"
        Languages: \(frontLanguage) -> \(backLanguage)
        Sample cards:
        \(cardsSample)

        Respond with JSON ONLY, no markdown, no backticks, no other text:
        {"tags": ["tag1", "tag2", "tag3"], "level": "B2"}
        """

        do {
            let response = try await model.generateContent(prompt)
            guard let text = response.text else { return fallbackAnalysis(title: title, existingLevel: existingLevel, existingTags: existingTags) }
            let cleaned = cleanJSONResponse(text)
            if let data = cleaned.data(using: .utf8),
               let result = try? JSONDecoder().decode(DeckAnalysisResult.self, from: data) {
                return result
            }
        } catch {
            #if DEBUG
            print("Gemini deck analysis error: \(error.localizedDescription)")
            #endif
        }

        return fallbackAnalysis(title: title, existingLevel: existingLevel, existingTags: existingTags)
    }

    private func cleanJSONResponse(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fallbackAnalysis(title: String, existingLevel: String? = nil, existingTags: [String] = []) -> DeckAnalysisResult {
        let level = (existingLevel != nil && !existingLevel!.isEmpty) ? existingLevel! : "General"
        if !existingTags.isEmpty {
            return DeckAnalysisResult(tags: existingTags, level: level)
        }
        let words = title.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 }
        let tags = Array(words.prefix(3))
        return DeckAnalysisResult(tags: tags.isEmpty ? ["fiszki"] : tags, level: level)
    }
}

struct DeckAnalysisResult: Codable, Sendable {
    let tags: [String]
    let level: String
}

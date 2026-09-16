import Foundation
import GoogleGenerativeAI

class GeminiService {
    // ZMIANA: Usuwamy hardcodowany klucz. Teraz pobieramy go bezpiecznie z managera.
    // Dzięki temu klucz nie widnieje w kodzie źródłowym.
    private var apiKey: String {
        return APIKeyManager.geminiKey
    }

    // Używamy modelu flash, bo jest szybki i wystarczający do tego zadania
    // ZMIANA: Przekazujemy apiKey z naszej nowej właściwości computed property
    private lazy var model = GenerativeModel(name: "models/gemini-flash-lite-latest", apiKey: apiKey)

    func generateFlashcards(from prompt: String) async throws -> String {
        // Sprawdzenie bezpieczeństwa - jeśli klucz jest pusty, rzuć błąd
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GeminiService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key is missing in Info.plist"])
        }

        let response = try await model.generateContent(prompt)

        guard let text = response.text else {
            throw NSError(domain: "GeminiService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
        }

        return cleanResponse(text)
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
}

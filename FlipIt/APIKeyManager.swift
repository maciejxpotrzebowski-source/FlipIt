import Foundation

enum APIKeyManager {
    static var geminiKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "GeminiApiKey") as? String, !key.isEmpty {
            return key.trimmingCharacters(in: .init(charactersIn: "\" \t\n\r"))
        }

        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let dictionary = NSDictionary(contentsOfFile: path),
           let key = dictionary["GeminiApiKey"] as? String, !key.isEmpty {
            return key.trimmingCharacters(in: .init(charactersIn: "\" \t\n\r"))
        }

        #if DEBUG
        print("⚠️ BŁĄD: Nie znaleziono klucza API 'GeminiApiKey' w Info.plist / bundle")
        #endif
        return ""
    }
}

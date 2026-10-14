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

    /// Żółtopomarańczowy odcień dla powiadomień o aktualizacjach talii z giełdy
    static var marketUpdateYellowOrange: Color {
        return Color(red: 1.0, green: 0.65, blue: 0.0)
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

extension String {
    /// Czyści i normalizuje kod udostępniania (usuwa myślniki, spacje, zamienia na wielkie litery)
    var normalizedShareCode: String {
        self.replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }

    /// Normalizuje klucz fiszki do porównywania duplikatów i synchronizacji
    var normalizedCardKey: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}



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

let availableCEFRLevels: [String] = ["A1", "A2", "B1", "B2", "C1", "C2"]

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
    var streak: Int = 0
    var createdAt: Date = Date()

    // --- Leitner Box System (0 - 4) ---
    var box: Int = 0                    // Pudełko Leitnera (0 = nowa/natychmiast, 1 = 1d, 2 = 3d, 3 = 7d, 4 = 21d)
    var nextReviewDate: Date = Date()   // Kiedy powtórzyć
    var lastReviewDate: Date? = nil     // Kiedy ostatnio widziana
    var correctCount: Int = 0           // Łączna liczba poprawnych
    var incorrectCount: Int = 0         // Łączna liczba błędnych

    // isLearned jest obliczane z poziomu pudełka Leitnera (pudełko 4 = trwale nauczona)
    var isLearned: Bool {
        get { box >= 4 }
        set {
            if newValue {
                box = max(box, 4)
            } else {
                if box >= 4 { box = 3 }
            }
        }
    }

    /// Interwał w sekundach dla danego pudełka Leitnera
    static func leitnerInterval(for box: Int) -> TimeInterval {
        switch box {
        case 0: return 0                    // Natychmiast
        case 1: return 1 * 86400            // 1 dzień
        case 2: return 3 * 86400            // 3 dni
        case 3: return 7 * 86400            // 7 dni
        case 4: return 21 * 86400           // 21 dni
        default: return 30 * 86400
        }
    }

    /// Historyczna skuteczność karty (0.0 do 1.0)
    var accuracyRatio: Double {
        let total = correctCount + incorrectCount
        if total == 0 { return 0.5 }
        return Double(correctCount) / Double(total)
    }

    /// Czy karta jest tzw. "pijawką" (częste pomyłki, trudna do zapamiętania)
    var isLeech: Bool {
        return incorrectCount >= 2 && accuracyRatio < 0.6
    }

    init(
        id: UUID = UUID(),
        front: String,
        back: String,
        isLearned: Bool = false,
        streak: Int = 0,
        createdAt: Date = Date(),
        box: Int = 0,
        nextReviewDate: Date = Date(),
        lastReviewDate: Date? = nil,
        correctCount: Int = 0,
        incorrectCount: Int = 0
    ) {
        self.id = id
        self.front = front
        self.back = back
        self.streak = streak
        self.createdAt = createdAt
        // Jeśli przekazano isLearned=true bez określonego boxu, ustawiamy box=4 dla kompatybilności wstecznej
        if isLearned && box == 0 {
            self.box = 4
        } else {
            self.box = box
        }
        self.nextReviewDate = nextReviewDate
        self.lastReviewDate = lastReviewDate
        self.correctCount = correctCount
        self.incorrectCount = incorrectCount
    }

    private enum CodingKeys: String, CodingKey {
        case id, front, back, streak, createdAt, box, nextReviewDate, lastReviewDate, correctCount, incorrectCount, isLearned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        front = try container.decode(String.self, forKey: .front)
        back = try container.decode(String.self, forKey: .back)
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        box = try container.decodeIfPresent(Int.self, forKey: .box) ?? 0
        nextReviewDate = try container.decodeIfPresent(Date.self, forKey: .nextReviewDate) ?? Date()
        lastReviewDate = try container.decodeIfPresent(Date.self, forKey: .lastReviewDate)
        correctCount = try container.decodeIfPresent(Int.self, forKey: .correctCount) ?? 0
        incorrectCount = try container.decodeIfPresent(Int.self, forKey: .incorrectCount) ?? 0

        // Migracja ze starszych wersji: jeśli isLearned było true, lub streak > 0 a brak box
        if box == 0 {
            let legacyIsLearned = try container.decodeIfPresent(Bool.self, forKey: .isLearned) ?? false
            if legacyIsLearned {
                box = 4
            } else if streak > 0 {
                box = min(streak, 3)
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(front, forKey: .front)
        try container.encode(back, forKey: .back)
        try container.encode(streak, forKey: .streak)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(box, forKey: .box)
        try container.encode(nextReviewDate, forKey: .nextReviewDate)
        try container.encodeIfPresent(lastReviewDate, forKey: .lastReviewDate)
        try container.encode(correctCount, forKey: .correctCount)
        try container.encode(incorrectCount, forKey: .incorrectCount)
        try container.encode(isLearned, forKey: .isLearned)
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

    /// Kod giełdowy (8-znakowy) — ustawiony jeśli deck pochodzi z Giełdy Decków
    var shareCode: String?

    /// Czy użytkownik tego urządzenia jest autorem opublikowanego decku
    var isMarketAuthor: Bool = false

    /// Czy deck jest publiczny na giełdzie, czy prywatny (dostępny tylko dla znajomych z kodem)
    var isMarketPublic: Bool = true

    /// Wersja pobranego/opublikowanego decku
    var marketVersion: Int = 1

    /// Czy deck ma oczekującą aktualizację z giełdy (opublikowaną przez autora)
    var hasPendingMarketUpdate: Bool = false

    /// Ostatnio zsynchronizowany lub odrzucony identyfikator wersji (updated_at)
    var lastDismissedUpdateDate: String? = nil

    /// Poziom językowy talii (np. A1, A2, B1, B2, C1, C2)
    var difficultyLevel: String? = nil

    /// Snapshot kart pobranych z giełdy (do precyzyjnego diffu 3-stronnego)
    var syncedMarketCards: [SharedCard]? = nil

    var progress: Double {
        if cards.isEmpty { return 0.0 }
        let learnedCount = cards.filter { $0.isLearned }.count
        return Double(learnedCount) / Double(cards.count)
    }

    /// Postęp ważony koszykami Leitnera (Box 0 = 0%, Box 1 = 25%, Box 2 = 50%, Box 3 = 75%, Box 4 = 100%)
    var leitnerProgress: Double {
        if cards.isEmpty { return 0.0 }
        let totalScore = cards.reduce(0) { $0 + min(max($1.box, 0), 4) }
        let maxScore = cards.count * 4
        return Double(totalScore) / Double(maxScore)
    }

    /// Czy 100% fiszek znajduje się w najwyższym koszyku (Box 4)
    var isMastered: Bool {
        !cards.isEmpty && cards.allSatisfy { $0.box >= 4 }
    }

    /// Kod giełdowy sformatowany jako XXXX-XXXX
    var formattedCode: String {
        guard let code = shareCode else { return "" }
        if code.count == 8 {
            let idx = code.index(code.startIndex, offsetBy: 4)
            return "\(code[..<idx])-\(code[idx...])"
        }
        return code
    }

    // Zaktualizowany inicjalizator
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        frontLabel: String = "Front",
        backLabel: String = "Back",
        frontLanguage: String = "en-US",
        backLanguage: String = "pl-PL",
        cards: [Flashcard],
        shareCode: String? = nil,
        isMarketAuthor: Bool = false,
        isMarketPublic: Bool = true,
        marketVersion: Int = 1,
        hasPendingMarketUpdate: Bool = false,
        lastDismissedUpdateDate: String? = nil,
        difficultyLevel: String? = nil,
        syncedMarketCards: [SharedCard]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.frontLabel = frontLabel
        self.backLabel = backLabel
        self.frontLanguage = frontLanguage
        self.backLanguage = backLanguage
        self.cards = cards
        self.shareCode = shareCode
        self.isMarketAuthor = isMarketAuthor
        self.isMarketPublic = isMarketPublic
        self.marketVersion = marketVersion
        self.hasPendingMarketUpdate = hasPendingMarketUpdate
        self.lastDismissedUpdateDate = lastDismissedUpdateDate
        self.difficultyLevel = difficultyLevel
        self.syncedMarketCards = syncedMarketCards
    }

    // Zaktualizowane dekodowanie (dla kompatybilności wstecznej)
    nonisolated init(from decoder: Decoder) throws {
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

        // Kod giełdowy (opcjonalny, nil dla lokalnych decków)
        shareCode = try container.decodeIfPresent(String.self, forKey: .shareCode)
        isMarketAuthor = try container.decodeIfPresent(Bool.self, forKey: .isMarketAuthor) ?? (shareCode != nil)
        isMarketPublic = try container.decodeIfPresent(Bool.self, forKey: .isMarketPublic) ?? true
        marketVersion = try container.decodeIfPresent(Int.self, forKey: .marketVersion) ?? 1
        hasPendingMarketUpdate = try container.decodeIfPresent(Bool.self, forKey: .hasPendingMarketUpdate) ?? false
        lastDismissedUpdateDate = try container.decodeIfPresent(String.self, forKey: .lastDismissedUpdateDate)
        difficultyLevel = try container.decodeIfPresent(String.self, forKey: .difficultyLevel)
        syncedMarketCards = try container.decodeIfPresent([SharedCard].self, forKey: .syncedMarketCards)
    }

    /// Sprawdza, czy talia zawiera już fiszkę o takich samych wartościach awersu i rewersu
    func containsCard(front: String, back: String) -> Bool {
        let trimmedFront = front.trimmingCharacters(in: .whitespaces)
        let trimmedBack = back.trimmingCharacters(in: .whitespaces)
        return cards.contains { existing in
            existing.front.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedFront) == .orderedSame &&
            existing.back.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedBack) == .orderedSame
        }
    }

    func containsCard(_ card: Flashcard) -> Bool {
        containsCard(front: card.front, back: card.back)
    }
}

// 5 Stanów Pochodzenia Talii
enum DeckMarketType: Equatable {
    case localPrivate                     // 1. Prywatna talia użytkownika (brak ikony)
    case ownPublic                        // 2. Własna talia udostępniona publicznie na giełdzie
    case ownPrivate                       // 3. Własna talia udostępniona prywatnie (znajomi z kodem)
    case importedPublic(hasUpdate: Bool)  // 4. Talia zaimportowana z giełdy publicznej
    case importedPrivate(hasUpdate: Bool) // 5. Talia zaimportowana prywatnie (od znajomego)
}

extension Deck {
    var marketType: DeckMarketType {
        guard shareCode != nil else {
            return .localPrivate
        }
        if isMarketAuthor {
            return isMarketPublic ? .ownPublic : .ownPrivate
        } else {
            return isMarketPublic
                ? .importedPublic(hasUpdate: hasPendingMarketUpdate)
                : .importedPrivate(hasUpdate: hasPendingMarketUpdate)
        }
    }
}

// --- SHARED MARKET MODELS ---

struct SharedCard: Codable, Sendable, Equatable {
    let front: String
    let back: String
}

struct SharedDeck: Codable, Identifiable, Sendable {
    let id: UUID
    let shareCode: String
    let title: String
    let description: String
    let frontLabel: String
    let backLabel: String
    let frontLanguage: String
    let backLanguage: String
    let cardsCount: Int
    let cardsPayload: [SharedCard]
    let isOfficial: Bool
    let isPublic: Bool
    let authorName: String
    let tags: [String]
    let difficultyLevel: String?
    let downloadsCount: Int
    let totalReviewsReported: Int
    let totalUsersReported: Int
    let returnUsersReported: Int?
    let createdAt: String?
    let updatedAt: String?
    let authorId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id
        case shareCode = "share_code"
        case title
        case description
        case frontLabel = "front_label"
        case backLabel = "back_label"
        case frontLanguage = "front_language"
        case backLanguage = "back_language"
        case cardsCount = "cards_count"
        case cardsPayload = "cards_payload"
        case isOfficial = "is_official"
        case isPublic = "is_public"
        case authorName = "author_name"
        case tags
        case difficultyLevel = "difficulty_level"
        case downloadsCount = "downloads_count"
        case totalReviewsReported = "total_reviews_reported"
        case totalUsersReported = "total_users_reported"
        case returnUsersReported = "return_users_reported"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorId = "author_id"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        shareCode = try c.decode(String.self, forKey: .shareCode)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        frontLabel = try c.decodeIfPresent(String.self, forKey: .frontLabel) ?? "Front"
        backLabel = try c.decodeIfPresent(String.self, forKey: .backLabel) ?? "Back"
        frontLanguage = try c.decodeIfPresent(String.self, forKey: .frontLanguage) ?? "en-US"
        backLanguage = try c.decodeIfPresent(String.self, forKey: .backLanguage) ?? "pl-PL"
        cardsCount = try c.decodeIfPresent(Int.self, forKey: .cardsCount) ?? 0
        cardsPayload = try c.decodeIfPresent([SharedCard].self, forKey: .cardsPayload) ?? []
        isOfficial = try c.decodeIfPresent(Bool.self, forKey: .isOfficial) ?? false
        isPublic = try c.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName) ?? "Anonymous"
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        difficultyLevel = try c.decodeIfPresent(String.self, forKey: .difficultyLevel)
        downloadsCount = try c.decodeIfPresent(Int.self, forKey: .downloadsCount) ?? 0
        totalReviewsReported = try c.decodeIfPresent(Int.self, forKey: .totalReviewsReported) ?? 0
        totalUsersReported = try c.decodeIfPresent(Int.self, forKey: .totalUsersReported) ?? 0
        returnUsersReported = try c.decodeIfPresent(Int.self, forKey: .returnUsersReported) ?? 0
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt)
        authorId = try c.decodeIfPresent(UUID.self, forKey: .authorId)
    }
    
    init(
        id: UUID = UUID(),
        shareCode: String,
        title: String,
        description: String = "",
        frontLabel: String = "Front",
        backLabel: String = "Back",
        frontLanguage: String = "en-US",
        backLanguage: String = "pl-PL",
        cardsCount: Int = 0,
        cardsPayload: [SharedCard] = [],
        isOfficial: Bool = false,
        isPublic: Bool = true,
        authorName: String = "Anonymous",
        tags: [String] = [],
        difficultyLevel: String? = nil,
        downloadsCount: Int = 0,
        totalReviewsReported: Int = 0,
        totalUsersReported: Int = 0,
        returnUsersReported: Int? = 0,
        createdAt: String? = nil,
        updatedAt: String? = nil,
        authorId: UUID? = nil
    ) {
        self.id = id
        self.shareCode = shareCode
        self.title = title
        self.description = description
        self.frontLabel = frontLabel
        self.backLabel = backLabel
        self.frontLanguage = frontLanguage
        self.backLanguage = backLanguage
        self.cardsCount = cardsCount
        self.cardsPayload = cardsPayload
        self.isOfficial = isOfficial
        self.isPublic = isPublic
        self.authorName = authorName
        self.tags = tags
        self.difficultyLevel = difficultyLevel
        self.downloadsCount = downloadsCount
        self.totalReviewsReported = totalReviewsReported
        self.totalUsersReported = totalUsersReported
        self.returnUsersReported = returnUsersReported
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.authorId = authorId
    }
    
    var avgReviewsPerUser: Double {
        guard totalUsersReported > 0 else { return 0 }
        return Double(totalReviewsReported) / Double(totalUsersReported)
    }

    /// Wskaźnik powracalności (odsetek osób, które uczyły się w więcej niż 1 dniu)
    var returnRatePercentage: Int? {
        guard let returns = returnUsersReported, returns > 0, totalUsersReported > 0 else { return nil }
        let rate = Double(returns) / Double(max(downloadsCount, returns))
        return min(max(Int(rate * 100), 1), 100)
    }

    /// Poziom języka do wyświetlenia (np. B2, A1)
    var displayLevel: String? {
        guard let level = difficultyLevel, !level.isEmpty, level.lowercased() != "general" else { return nil }
        return level.uppercased()
    }
    
    /// Czy talia została oznaczona jako archiwalna przez autora
    var isArchived: Bool {
        tags.contains("archived")
    }
    
    /// Kod sformatowany jako XXXX-XXXX
    var formattedCode: String {
        if shareCode.count == 8 {
            let idx = shareCode.index(shareCode.startIndex, offsetBy: 4)
            return "\(shareCode[..<idx])-\(shareCode[idx...])"
        }
        return shareCode
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

enum GeminiModelOption: String, Codable, CaseIterable, Identifiable {
    case flash3 = "models/gemini-3-flash-preview"
    case flash31Lite = "models/gemini-3.1-flash-lite"
    case flash35Lite = "models/gemini-3.5-flash-lite"
    case flash38 = "models/gemini-3.8-flash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash3:
            return "AI 3 Flash"
        case .flash31Lite:
            return "AI 3.1 Flash-Lite (Recommended)"
        case .flash35Lite:
            return "AI 3.5 Flash-Lite"
        case .flash38:
            return "AI 3.8 Flash"
        }
    }

    var speedBadge: String {
        switch self {
        case .flash31Lite, .flash35Lite:
            return "Ultra Fast (~1.5s)"
        case .flash3, .flash38:
            return "Fast (~2.5s)"
        }
    }

    var dailyLimitText: String {
        "1,500 req/day (Free Tier)"
    }

    var badgeColor: Color {
        switch self {
        case .flash3:
            return .purple
        case .flash31Lite:
            return .blue
        case .flash35Lite:
            return .green
        case .flash38:
            return .orange
        }
    }

    var estimatedTime100Cards: String {
        switch self {
        case .flash31Lite, .flash35Lite:
            return "~1.5 – 2.5s"
        case .flash3, .flash38:
            return "~2.5 – 4.0s"
        }
    }
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
    var analyticsEnabled: Bool = false // Anonimowa telemetria uczenia
    var geminiModel: GeminiModelOption = .flash31Lite

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
        isPremiumUser: Bool = false,
        analyticsEnabled: Bool = false,
        geminiModel: GeminiModelOption = .flash31Lite
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
        self.analyticsEnabled = analyticsEnabled
        self.geminiModel = geminiModel
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
        if let raw = try? container.decodeIfPresent(String.self, forKey: .geminiModel),
           let model = GeminiModelOption(rawValue: raw) {
            geminiModel = model
        } else {
            geminiModel = .flash31Lite
        }
    }
}

// --- STUDY TELEMETRY & ANALYTICS ---

struct StudyTelemetryEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var eventType: String // "review", "widget_review", "morale_rescue", "challenge_boost"
    var isKnown: Bool?
    var boxBefore: Int?
    var boxAfter: Int?
    var consecutiveStreak: Int?
    var wasMoraleBooster: Bool = false
    var wasChallenge: Bool = false
    var responseTimeSeconds: Double?
}

class StudyTelemetryManager {
    static let shared = StudyTelemetryManager()
    private let fileName = "study_telemetry.json"
    private let maxEvents = 2000

    private func getFileURL() -> URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_ID) {
            return groupURL.appendingPathComponent(fileName)
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
    }

    private func getFallbackURL() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
    }

    func logEvent(_ event: StudyTelemetryEvent) {
        var events = loadEvents()
        events.append(event)
        if events.count > maxEvents {
            events = Array(events.suffix(maxEvents))
        }
        saveEvents(events)
    }

    func loadEvents() -> [StudyTelemetryEvent] {
        let url = getFileURL()
        if let data = try? Data(contentsOf: url),
           let events = try? JSONDecoder().decode([StudyTelemetryEvent].self, from: data) {
            return events
        }
        let fallbackURL = getFallbackURL()
        if let data = try? Data(contentsOf: fallbackURL),
           let events = try? JSONDecoder().decode([StudyTelemetryEvent].self, from: data) {
            return events
        }
        return []
    }

    private func saveEvents(_ events: [StudyTelemetryEvent]) {
        let url = getFileURL()
        if let data = try? JSONEncoder().encode(events) {
            do {
                try data.write(to: url, options: .atomic)
            } catch {
                // Gdy zapis do App Group nie powiedzie się (np. testy jednostkowe bez profilu), zapisz do katalogu dokumentów
                let fallbackURL = getFallbackURL()
                try? data.write(to: fallbackURL, options: .atomic)
            }
        }
    }

    func clearEvents() {
        let url = getFileURL()
        try? FileManager.default.removeItem(at: url)
        let fallbackURL = getFallbackURL()
        try? FileManager.default.removeItem(at: fallbackURL)
    }

    func exportJSON() -> String {
        let events = loadEvents()
        if let data = try? JSONEncoder().encode(events), let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "[]"
    }

    func eventsCount() -> Int {
        return loadEvents().count
    }
}

// --- ADAPTIVE LEARNING CONTROLLER (LEITNER + CASINO MORALE & CHALLENGE ENGINE) ---

struct AdaptiveCardSelector {
    enum SelectionReason: String, Codable {
        case normalDue
        case moraleRescue
        case challengeLeech
        case challengeNew
        case standardPractice

        var displayBadge: String? {
            // Etykiety UI usunięte na prośbę użytkownika: adaptacja działa całkowicie w tle
            return nil
        }
    }

    struct SelectionResult {
        let card: Flashcard
        let deckId: UUID
        let reason: SelectionReason
        let reverseSide: Bool
    }

    static func selectNextCard(
        from pool: [(card: Flashcard, deckId: UUID)],
        isInRescueMode: Bool,
        isInChallengeMode: Bool,
        currentCardId: UUID? = nil,
        preferredSide: StudySideOption
    ) -> SelectionResult? {
        guard !pool.isEmpty else { return nil }

        let now = Date()
        let availablePool = (pool.count > 1 && currentCardId != nil)
            ? pool.filter { $0.card.id != currentCardId }
            : pool

        // 1. TRYB WSPOMAGAJĄCY (MORALE RESCUE): łatwiejsze pytania aż do pierwszej poprawnej odpowiedzi
        if isInRescueMode {
            // Kandydaci łatwiejsi: wyższe pudełka (Box 2, 3, 4), wysoki wskaźnik poprawności lub stabilny streak
            let easyCandidates = availablePool.filter {
                $0.card.box >= 2 || $0.card.accuracyRatio >= 0.70 || $0.card.streak >= 2
            }

            if let chosen = easyCandidates.randomElement() {
                return SelectionResult(card: chosen.card, deckId: chosen.deckId, reason: .moraleRescue, reverseSide: false)
            }

            // Fallback: karta o najwyższym pudełku i dokładności w puli
            if let best = availablePool.max(by: {
                if $0.card.box != $1.card.box { return $0.card.box < $1.card.box }
                return $0.card.accuracyRatio < $1.card.accuracyRatio
            }) {
                return SelectionResult(card: best.card, deckId: best.deckId, reason: .moraleRescue, reverseSide: false)
            }
        }

        // 2. TRYB WYZWANIA (CHALLENGE FLOW): trudniejsze pytania po serii sukcesów, kontynuowane tak długo jak użytkownik odpowiada poprawnie
        if isInChallengeMode {
            // Kandydaci trudniejsi: pijawki, Box 0-1, karty nowe/nieprzejrzane, niższa skuteczność (< 70%)
            let harderCandidates = availablePool.filter {
                $0.card.isLeech ||
                $0.card.box <= 1 ||
                $0.card.lastReviewDate == nil ||
                $0.card.accuracyRatio < 0.70
            }

            if let chosen = harderCandidates.randomElement() {
                let reason: SelectionReason = chosen.card.isLeech ? .challengeLeech : .challengeNew
                return SelectionResult(card: chosen.card, deckId: chosen.deckId, reason: reason, reverseSide: false)
            }

            // Jeśli wszystkie karty są już opanowane: odwrócenie strony lub najniższe dostępne pudełko
            if let chosen = availablePool.min(by: { $0.card.box < $1.card.box }) {
                return SelectionResult(card: chosen.card, deckId: chosen.deckId, reason: .challengeLeech, reverseSide: true)
            }
        }

        // 3. STANDARD LEITNER: Karty przeterminowane (Due Cards) posortowane według najniższego pudełka
        let dueCards = availablePool.filter { $0.card.nextReviewDate <= now }
        let candidatePool = dueCards.isEmpty ? availablePool : dueCards

        let sorted = candidatePool.sorted { a, b in
            if a.card.box != b.card.box { return a.card.box < b.card.box }
            return a.card.nextReviewDate < b.card.nextReviewDate
        }

        guard let chosen = sorted.first ?? availablePool.first else {
            return nil
        }

        let isReversed: Bool
        switch preferredSide {
        case .front: isReversed = false
        case .back: isReversed = true
        case .random: isReversed = Bool.random()
        }

        return SelectionResult(
            card: chosen.card,
            deckId: chosen.deckId,
            reason: dueCards.isEmpty ? .standardPractice : .normalDue,
            reverseSide: isReversed
        )
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
            let initialDeck = Deck(name: "My flashcards", description: "My primary deck", cards: [
                Flashcard(front: "Cat", back: "Kot"),
                Flashcard(front: "Dog", back: "Pies"),
                Flashcard(front: "Apple", back: "Jabłko")
            ])
            decks.append(initialDeck)
            settings.usedDeckIDs.insert(initialDeck.id)
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
            ) { [weak self] _ in
                self?.reloadData()
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

    func resetAllProgress(deckId: UUID) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            let now = Date()
            for i in 0..<decks[index].cards.count {
                decks[index].cards[i].streak = 0
                decks[index].cards[i].box = 0
                decks[index].cards[i].nextReviewDate = now
                decks[index].cards[i].lastReviewDate = nil
                decks[index].cards[i].correctCount = 0
                decks[index].cards[i].incorrectCount = 0
            }
            saveData()
        }
    }

    /// Przywraca stan początkowy danych lokalnych (czysta instalacja: jedna domyślna talia, domyślne ustawienia)
    func resetToInitialState() {
        let initialDeck = Deck(name: "My flashcards", description: "My primary deck", cards: [
            Flashcard(front: "Cat", back: "Kot"),
            Flashcard(front: "Dog", back: "Pies"),
            Flashcard(front: "Apple", back: "Jabłko")
        ])
        self.decks = [initialDeck]
        var freshSettings = AppSettings()
        freshSettings.usedDeckIDs = [initialDeck.id]
        // Zachowujemy wybrany język aplikacji, aby nie resetować preferencji interfejsu
        freshSettings.appLanguage = self.settings.appLanguage
        self.settings = freshSettings
        saveData()
        StudyTelemetryManager.shared.clearEvents()
    }

    func saveData() {
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        do {
            let data = try JSONEncoder().encode(decks)
            try data.write(to: url, options: [.atomic])

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
                let now = Date()
                let oldBox = decks[dIndex].cards[cIndex].box
                let newBox: Int

                if isKnown {
                    decks[dIndex].cards[cIndex].streak += 1
                    decks[dIndex].cards[cIndex].correctCount += 1
                    newBox = min(oldBox + 1, 4)
                } else {
                    decks[dIndex].cards[cIndex].streak = 0
                    decks[dIndex].cards[cIndex].incorrectCount += 1
                    // Łagodna kara: cofnięcie o 1 pudełko zamiast do 0
                    newBox = max(oldBox - 1, 0)
                }
                decks[dIndex].cards[cIndex].box = newBox
                decks[dIndex].cards[cIndex].lastReviewDate = now
                decks[dIndex].cards[cIndex].nextReviewDate = now.addingTimeInterval(Flashcard.leitnerInterval(for: newBox))
                saveData()

                if settings.analyticsEnabled {
                    StudyTelemetryManager.shared.logEvent(StudyTelemetryEvent(
                        eventType: "widget_review",
                        isKnown: isKnown,
                        boxBefore: oldBox,
                        boxAfter: newBox,
                        consecutiveStreak: decks[dIndex].cards[cIndex].streak
                    ))
                }
                break
            }
        }
    }

    // --- DECK MARKET ---

    /// Importuje talię z Giełdy Decków jako nową lokalną talię (wszystkie karty od box 0)
    func importMarketDeck(from sharedDeck: SharedDeck) {
        let freshCards = sharedDeck.cardsPayload.map { shared in
            Flashcard(front: shared.front, back: shared.back)
        }
        let newDeck = Deck(
            name: sharedDeck.title,
            description: sharedDeck.description,
            frontLabel: sharedDeck.frontLabel,
            backLabel: sharedDeck.backLabel,
            frontLanguage: sharedDeck.frontLanguage,
            backLanguage: sharedDeck.backLanguage,
            cards: freshCards,
            shareCode: sharedDeck.shareCode,
            isMarketAuthor: false,
            isMarketPublic: sharedDeck.isPublic,
            marketVersion: 1,
            hasPendingMarketUpdate: false,
            lastDismissedUpdateDate: sharedDeck.updatedAt ?? sharedDeck.createdAt,
            difficultyLevel: sharedDeck.difficultyLevel,
            syncedMarketCards: sharedDeck.cardsPayload
        )
        if decks.isEmpty {
            decks.append(newDeck)
        } else {
            decks.insert(newDeck, at: 1)
        }
        settings.usedDeckIDs.insert(newDeck.id)
        saveData()
    }

    /// Aktualizuje kod giełdowy lokalnej talii (po publikacji na Giełdzie Decków)
    func updateDeckShareCode(deckId: UUID, shareCode: String, isMarketAuthor: Bool = true, isMarketPublic: Bool = true) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].shareCode = shareCode
            decks[index].isMarketAuthor = isMarketAuthor
            decks[index].isMarketPublic = isMarketPublic
            saveData()
        }
    }

    /// Zmienia widoczność publiczną/prywatną talii na Giełdzie
    func setDeckMarketVisibility(deckId: UUID, isPublic: Bool) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].isMarketPublic = isPublic
            saveData()
        }
    }

    /// Wycofuje talię z publicznej giełdy (zachowuje shareCode, zmienia isMarketPublic na false)
    func unpublishDeckFromMarket(deckId: UUID) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].isMarketPublic = false
            saveData()
        }
    }

    /// Usuwa powiązanie giełdowe decku (po wycofaniu z rynku przez autora)
    func removeDeckShareCode(deckId: UUID) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].shareCode = nil
            decks[index].isMarketAuthor = false
            decks[index].isMarketPublic = false
            saveData()
        }
    }

    struct SyncCardItem: Identifiable, Equatable {
        var id = UUID()
        let front: String
        let newBack: String
        let oldBack: String?
        let changeType: SyncChangeType
        var isSelected: Bool

        enum SyncChangeType: Equatable {
            case userModified   // Żółty: Zmodyfikowana przez użytkownika, autor też zmienił. Domyślnie odznaczona (isSelected = false)
            case authorUpdated  // Niebieski: Zaktualizowana przez autora, użytkownik nie dotykał. Domyślnie zaznaczona (isSelected = true)
            case authorAdded    // Zielony: Nowa fiszka od autora. Domyślnie zaznaczona (isSelected = true)
            case authorDeleted  // Czerwony: Usunięta przez autora. Domyślnie odznaczona (isSelected = false)
        }
    }

    struct SyncDiffResult {
        var userModifiedCards: [SyncCardItem]
        var authorUpdatedCards: [SyncCardItem]
        var addedCards: [SyncCardItem]
        var deletedCards: [SyncCardItem]
        var unchangedCount: Int
        var userAddedCardsCount: Int

        var totalChangesCount: Int {
            userModifiedCards.count + authorUpdatedCards.count + addedCards.count + deletedCards.count
        }

        var hasChanges: Bool {
            totalChangesCount > 0
        }
    }

    func calculateSyncDiff(deckId: UUID, remoteDeck: SharedDeck) -> SyncDiffResult? {
        guard let localDeck = decks.first(where: { $0.id == deckId }) else { return nil }

        var userModified: [SyncCardItem] = []
        var authorUpdated: [SyncCardItem] = []
        var added: [SyncCardItem] = []
        var deleted: [SyncCardItem] = []
        var unchanged = 0
        var userAdded = 0

        let baseCards = localDeck.syncedMarketCards
        let baseByFront: [String: [SharedCard]] = Dictionary(grouping: baseCards ?? []) {
            $0.front.normalizedCardKey
        }

        let remoteByFront = Dictionary(grouping: remoteDeck.cardsPayload) {
            $0.front.normalizedCardKey
        }

        let localByFront = Dictionary(grouping: localDeck.cards) {
            $0.front.normalizedCardKey
        }

        // 1. Sprawdzamy karty z serwera (Remote)
        for remoteCard in remoteDeck.cardsPayload {
            let key = remoteCard.front.normalizedCardKey
            let matchingLocals = localByFront[key]
            let baseCard = baseByFront[key]?.first

            if let local = matchingLocals?.first {
                let remoteBackClean = remoteCard.back.trimmingCharacters(in: .whitespacesAndNewlines)
                let localBackClean = local.back.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseBackClean = baseCard?.back.trimmingCharacters(in: .whitespacesAndNewlines)

                if remoteBackClean == localBackClean {
                    // Brak różnicy między wersją z serwera a lokalną
                    unchanged += 1
                } else {
                    // Wersja z serwera różni się od wersji lokalnej
                    let remoteChangedFromBase: Bool
                    let userChangedFromBase: Bool

                    if let baseBackClean = baseBackClean {
                        remoteChangedFromBase = (remoteBackClean != baseBackClean)
                        userChangedFromBase = (localBackClean != baseBackClean)
                    } else {
                        // Jeśli brak bazy (legacy deck)
                        remoteChangedFromBase = true
                        userChangedFromBase = false
                    }

                    if remoteChangedFromBase && userChangedFromBase {
                        // Użytkownik zmodyfikował tę fiszkę u siebie, a autor też ją zaktualizował
                        // Żółty, domyślnie ODZNACZONY (isSelected = false), aby chronić edycję użytkownika
                        userModified.append(SyncCardItem(
                            front: remoteCard.front,
                            newBack: remoteCard.back,
                            oldBack: local.back,
                            changeType: .userModified,
                            isSelected: false
                        ))
                    } else if remoteChangedFromBase {
                        // Autor wprowadził zmiany, użytkownik nie modyfikował fiszki
                        // Niebieski, domyślnie ZAZNACZONY (isSelected = true)
                        authorUpdated.append(SyncCardItem(
                            front: remoteCard.front,
                            newBack: remoteCard.back,
                            oldBack: local.back,
                            changeType: .authorUpdated,
                            isSelected: true
                        ))
                    } else {
                        // Tylko użytkownik zmienił fiszkę lokalnie, autor nic nie zmienił
                        // Nie jest to zmiana autora!
                        unchanged += 1
                    }
                }
            } else {
                // Nowa karta dodana przez autora
                // Zielony, domyślnie ZAZNACZONY (isSelected = true)
                added.append(SyncCardItem(
                    front: remoteCard.front,
                    newBack: remoteCard.back,
                    oldBack: nil,
                    changeType: .authorAdded,
                    isSelected: true
                ))
            }
        }

        // 2. Sprawdzamy lokalne karty, których nie ma na serwerze
        for localCard in localDeck.cards {
            let key = localCard.front.normalizedCardKey
            if remoteByFront[key] == nil {
                if baseCards != nil, baseByFront[key] != nil {
                    // Karta BYŁA pierwotnie w talii autora, ale autor ją usunął z giełdy
                    // Czerwony, usunięta przez autora, domyślnie ODZNACZONA (isSelected = false), aby nie usuwać bez zgody
                    deleted.append(SyncCardItem(
                        front: localCard.front,
                        newBack: "",
                        oldBack: localCard.back,
                        changeType: .authorDeleted,
                        isSelected: false
                    ))
                } else {
                    // Karta dodana przez samego użytkownika lokalnie!
                    // NIE jest to usunięcie autora - zachowujemy ją w 100% nienaruszoną
                    userAdded += 1
                }
            }
        }

        return SyncDiffResult(
            userModifiedCards: userModified,
            authorUpdatedCards: authorUpdated,
            addedCards: added,
            deletedCards: deleted,
            unchangedCount: unchanged,
            userAddedCardsCount: userAdded
        )
    }

    func applyCustomSync(
        deckId: UUID,
        remoteDeck: SharedDeck,
        userModifiedItems: [SyncCardItem],
        authorUpdatedItems: [SyncCardItem],
        addedItems: [SyncCardItem],
        deletedItems: [SyncCardItem]
    ) {
        guard let index = decks.firstIndex(where: { $0.id == deckId }) else { return }

        // 1. Zastosowanie nowo dodanych fiszek od autora (zaznaczonych)
        for item in addedItems where item.isSelected {
            let key = item.front.normalizedCardKey
            if !decks[index].cards.contains(where: { $0.front.normalizedCardKey == key }) {
                let newCard = Flashcard(front: item.front, back: item.newBack)
                decks[index].cards.append(newCard)
            }
        }

        // 2. Zastosowanie aktualizacji autora (zaznaczonych, niebieskich)
        let authorMap = Dictionary(uniqueKeysWithValues:
            authorUpdatedItems.filter { $0.isSelected }.map { ($0.front.normalizedCardKey, $0.newBack) }
        )
        for i in 0..<decks[index].cards.count {
            let key = decks[index].cards[i].front.normalizedCardKey
            if let newBack = authorMap[key] {
                decks[index].cards[i].back = newBack
            }
        }

        // 3. Zastosowanie nadpisania edycji użytkownika (zaznaczonych, żółtych)
        let userModMap = Dictionary(uniqueKeysWithValues:
            userModifiedItems.filter { $0.isSelected }.map { ($0.front.normalizedCardKey, $0.newBack) }
        )
        for i in 0..<decks[index].cards.count {
            let key = decks[index].cards[i].front.normalizedCardKey
            if let newBack = userModMap[key] {
                decks[index].cards[i].back = newBack
            }
        }

        // 4. Usunięcie fiszek skasowanych przez autora (jeśli użytkownik zaznaczył do usunięcia, czerwonych)
        let deletions = Set(deletedItems.filter { $0.isSelected }.map { $0.front.normalizedCardKey })
        if !deletions.isEmpty {
            decks[index].cards.removeAll { card in
                deletions.contains(card.front.normalizedCardKey)
            }
        }

        // 5. Aktualizacja metadanych talii
        if !remoteDeck.title.isEmpty {
            decks[index].name = remoteDeck.title
        }
        if !remoteDeck.description.isEmpty {
            decks[index].description = remoteDeck.description
        }
        decks[index].isMarketPublic = remoteDeck.isPublic
        decks[index].marketVersion += 1
        decks[index].hasPendingMarketUpdate = false
        decks[index].lastDismissedUpdateDate = remoteDeck.updatedAt ?? remoteDeck.createdAt ?? "\(remoteDeck.cardsCount)"
        decks[index].syncedMarketCards = remoteDeck.cardsPayload

        saveData()
    }

    func smartSyncDeck(deckId: UUID, remoteDeck: SharedDeck, keepDeletedCards: Bool) {
        guard let diff = calculateSyncDiff(deckId: deckId, remoteDeck: remoteDeck) else { return }
        var deleted = diff.deletedCards
        if !keepDeletedCards {
            for i in 0..<deleted.count {
                deleted[i].isSelected = true
            }
        }
        applyCustomSync(
            deckId: deckId,
            remoteDeck: remoteDeck,
            userModifiedItems: diff.userModifiedCards,
            authorUpdatedItems: diff.authorUpdatedCards,
            addedItems: diff.addedCards,
            deletedItems: deleted
        )
    }

    /// Odrzuca oczekującą aktualizację talii (użytkownik decyduje się pozostać przy obecnej wersji)
    func dismissMarketUpdate(deckId: UUID, remoteVersion: String) {
        if let index = decks.firstIndex(where: { $0.id == deckId }) {
            decks[index].hasPendingMarketUpdate = false
            decks[index].lastDismissedUpdateDate = remoteVersion
            saveData()
        }
    }

    // --- ACTIONS (CRUD) ---

    @discardableResult
    func addDeck(name: String, description: String, frontLabel: String, backLabel: String, frontLanguage: String, backLanguage: String, difficultyLevel: String? = nil) -> Deck {
        let finalFront = frontLabel.isEmpty ? "Front" : frontLabel
        let finalBack = backLabel.isEmpty ? "Back" : backLabel

        // Tworzymy deck z językami i poziomem
        let newDeck = Deck(
            name: name,
            description: description,
            frontLabel: finalFront,
            backLabel: finalBack,
            frontLanguage: frontLanguage,
            backLanguage: backLanguage, // Przekazujemy języki
            cards: [],
            difficultyLevel: difficultyLevel
        )
        if decks.isEmpty {
            decks.append(newDeck)
        } else {
            decks.insert(newDeck, at: 1)
        }
        settings.usedDeckIDs.insert(newDeck.id)
        saveData()
        return newDeck
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

    func updateDeck(deckId: UUID, name: String, description: String, frontLabel: String, backLabel: String, frontLanguage: String, backLanguage: String, difficultyLevel: String? = nil) {
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
            decks[index].difficultyLevel = difficultyLevel
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

    func updateStreak(deckId: UUID, cardId: UUID, newStreak: Int, isKnown: Bool = true, wasMoraleBooster: Bool = false, wasChallenge: Bool = false) {
        if let dIndex = decks.firstIndex(where: { $0.id == deckId }),
           let cIndex = decks[dIndex].cards.firstIndex(where: { $0.id == cardId }) {
            let now = Date()
            let oldBox = decks[dIndex].cards[cIndex].box
            decks[dIndex].cards[cIndex].streak = newStreak
            decks[dIndex].cards[cIndex].lastReviewDate = now

            let newBox: Int
            if isKnown {
                decks[dIndex].cards[cIndex].correctCount += 1
                newBox = min(oldBox + 1, 4)
            } else {
                decks[dIndex].cards[cIndex].incorrectCount += 1
                // Łagodna kara: cofnięcie o 1 pudełko
                newBox = max(oldBox - 1, 0)
            }
            decks[dIndex].cards[cIndex].box = newBox
            decks[dIndex].cards[cIndex].nextReviewDate = now.addingTimeInterval(Flashcard.leitnerInterval(for: newBox))
            saveData()

            if settings.analyticsEnabled {
                StudyTelemetryManager.shared.logEvent(StudyTelemetryEvent(
                    eventType: "review",
                    isKnown: isKnown,
                    boxBefore: oldBox,
                    boxAfter: newBox,
                    consecutiveStreak: newStreak,
                    wasMoraleBooster: wasMoraleBooster,
                    wasChallenge: wasChallenge
                ))
            }

            // Automatyczne anonimowe raportowanie powtórek dla talii z Giełdy
            if let shareCode = decks[dIndex].shareCode {
                reportMarketUsage(deckId: deckId, shareCode: shareCode)
            }
        }
    }

    /// Opcjonalny callback do raportowania statystyk giełdowych (podpinany w aplikacji głównej)
    var onMarketReviewReport: ((_ shareCode: String, _ count: Int, _ isReturnUser: Bool) -> Void)?

    private var marketReviewBuffers: [String: Int] = [:]

    private func reportMarketUsage(deckId: UUID, shareCode: String) {
        marketReviewBuffers[shareCode, default: 0] += 1
        
        // Wysyłamy w paczkach co 5 powtórek, by nie obciążać sieci
        if marketReviewBuffers[shareCode, default: 0] >= 5 {
            let count = marketReviewBuffers[shareCode, default: 0]
            marketReviewBuffers[shareCode] = 0
            
            // Wskaźnik powracalności: czy użytkownik wrócił do nauki po min. 24h?
            let firstStudyKey = "market_first_study_\(shareCode)"
            let returnReportedKey = "market_return_reported_\(shareCode)"
            
            var isReturn = false
            let now = Date()
            if let firstDate = UserDefaults.standard.object(forKey: firstStudyKey) as? Date {
                let alreadyReported = UserDefaults.standard.bool(forKey: returnReportedKey)
                if !alreadyReported && now.timeIntervalSince(firstDate) >= 86400 {
                    isReturn = true
                    UserDefaults.standard.set(true, forKey: returnReportedKey)
                }
            } else {
                UserDefaults.standard.set(now, forKey: firstStudyKey)
            }
            
            onMarketReviewReport?(shareCode, count, isReturn)
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

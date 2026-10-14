import Foundation
import Supabase

enum SupabaseConfig {
    static var url: URL {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String {
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            if let parsedURL = URL(string: trimmed), let host = parsedURL.host, !host.isEmpty {
                return parsedURL
            }
        }
        // Bezpieczny fallback z poprawnym hostem (omija błąd komentarza // w xcconfig)
        return URL(string: "https://bnrsqcqlmhuvazrjlbcl.supabase.co")!
    }
    
    static var anonKey: String {
        if let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
            let trimmed = key.trimmingCharacters(in: .init(charactersIn: "\" \t\n\r"))
            if !trimmed.isEmpty && !trimmed.contains("$(") {
                return trimmed
            }
        }
        // Bezpieczny fallback dla klucza publicznego
        return "sb_publishable_pIbQh7SXbuUA1hfOqJ901g_Djvzj2U0"
    }
}

struct MarketDeckUpload: Encodable, Sendable {
    let title: String
    let description: String
    let frontLabel: String
    let backLabel: String
    let frontLanguage: String
    let backLanguage: String
    let cardsCount: Int
    let cardsPayload: [SharedCard]
    let isPublic: Bool
    let authorName: String
    let tags: [String]
    let difficultyLevel: String
    let authorId: UUID?
    
    init(
        title: String,
        description: String,
        frontLabel: String,
        backLabel: String,
        frontLanguage: String,
        backLanguage: String,
        cardsCount: Int,
        cardsPayload: [SharedCard],
        isPublic: Bool,
        authorName: String,
        tags: [String],
        difficultyLevel: String,
        authorId: UUID? = nil
    ) {
        self.title = title
        self.description = description
        self.frontLabel = frontLabel
        self.backLabel = backLabel
        self.frontLanguage = frontLanguage
        self.backLanguage = backLanguage
        self.cardsCount = cardsCount
        self.cardsPayload = cardsPayload
        self.isPublic = isPublic
        self.authorName = authorName
        self.tags = tags
        self.difficultyLevel = difficultyLevel
        self.authorId = authorId
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case description
        case frontLabel = "front_label"
        case backLabel = "back_label"
        case frontLanguage = "front_language"
        case backLanguage = "back_language"
        case cardsCount = "cards_count"
        case cardsPayload = "cards_payload"
        case isPublic = "is_public"
        case authorName = "author_name"
        case tags
        case difficultyLevel = "difficulty_level"
        case authorId = "author_id"
    }
}

enum MarketSortOption: String, CaseIterable, Identifiable, Sendable {
    case downloads = "Downloads"
    case retention = "Retention"
    case newest = "Newest"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .downloads: return "Most Downloaded"
        case .retention: return "Best Retention"
        case .newest: return "Newest"
        }
    }
    
    var systemImage: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .retention: return "flame"
        case .newest: return "sparkles"
        }
    }
}

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    var isConfigured: Bool {
        let key = SupabaseConfig.anonKey
        let url = SupabaseConfig.url
        return !key.isEmpty && url.absoluteString != "https://example.supabase.co"
    }
    
    static let summaryColumns = "id, share_code, title, description, front_label, back_label, front_language, back_language, cards_count, is_official, is_public, author_name, tags, difficulty_level, downloads_count, total_reviews_reported, total_users_reported, return_users_reported, created_at, updated_at"
    
    private init() {
        self.client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }
    
    func publishDeck(_ deck: MarketDeckUpload) async throws -> SharedDeck {
        guard deck.authorId != nil else {
            throw AuthError.notAuthenticated
        }
        let response: SharedDeck = try await client.from("shared_decks")
            .insert(deck)
            .select()
            .single()
            .execute()
            .value
        
        return response
    }
    
    func fetchFullDeck(id: UUID) async throws -> SharedDeck {
        let response: SharedDeck = try await client.from("shared_decks")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        return response
    }
    
    func fetchByCode(_ code: String) async throws -> SharedDeck? {
        let sanitizedCode = code.normalizedShareCode
        
        // Wymóg: dokładnie 8 znaków (żadnego zgadywania ani wyszukiwania po niepełnym kodzie)
        guard sanitizedCode.count == 8 else { return nil }
        
        struct CodeParams: Encodable {
            let lookup_code: String
        }
        
        // 1. Bezpieczna funkcja RPC (zwraca talię tylko przy dokładnym 8-znakowym kodzie, w tym prywatne)
        if let rpcResult: [SharedDeck] = try? await client.rpc("fetch_deck_by_code", params: CodeParams(lookup_code: sanitizedCode))
            .execute()
            .value, let first = rpcResult.first {
            return first
        }
        
        // 2. Bezpośrednie zapytanie jako fallback
        do {
            let response: SharedDeck = try await client.from("shared_decks")
                .select()
                .eq("share_code", value: sanitizedCode)
                .single()
                .execute()
                .value
            return response
        } catch {
            return nil
        }
    }
    
    func fetchOfficialDecks(
        level: String? = nil,
        language: String? = nil,
        sortBy: MarketSortOption = .downloads
    ) async throws -> [SharedDeck] {
        var query = client.from("shared_decks")
            .select(SupabaseManager.summaryColumns)
            .eq("is_official", value: true)
        
        if let lvl = level, !lvl.isEmpty, lvl != "All" {
            query = query.eq("difficulty_level", value: lvl)
        }
        
        if let lang = language, !lang.isEmpty, lang != "All" {
            query = query.ilike("front_language", pattern: "%\(lang)%")
        }
        
        let sortColumn: String
        switch sortBy {
        case .downloads:
            sortColumn = "downloads_count"
        case .retention:
            sortColumn = "return_users_reported"
        case .newest:
            sortColumn = "created_at"
        }
        
        let response: [SharedDeck] = try await query
            .order(sortColumn, ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchCommunityDecks(
        searchQuery: String? = nil,
        level: String? = nil,
        language: String? = nil,
        sortBy: MarketSortOption = .downloads,
        page: Int,
        pageSize: Int
    ) async throws -> [SharedDeck] {
        let from = max(page, 0) * pageSize
        let to = from + pageSize - 1
        
        var query = client.from("shared_decks")
            .select(SupabaseManager.summaryColumns)
            .eq("is_public", value: true)
            .eq("is_official", value: false)
        
        if let queryText = searchQuery, !queryText.isEmpty {
            query = query.ilike("title", pattern: "%\(queryText)%")
        }
        
        if let lvl = level, !lvl.isEmpty, lvl != "All" {
            query = query.eq("difficulty_level", value: lvl)
        }
        
        if let lang = language, !lang.isEmpty, lang != "All" {
            query = query.ilike("front_language", pattern: "%\(lang)%")
        }
        
        let sortColumn: String
        switch sortBy {
        case .downloads:
            sortColumn = "downloads_count"
        case .retention:
            sortColumn = "return_users_reported"
        case .newest:
            sortColumn = "created_at"
        }
        
        let response: [SharedDeck] = try await query
            .order(sortColumn, ascending: false)
            .range(from: from, to: to)
            .execute()
            .value
        
        return response
    }
    
    func incrementDownloads(deckId: UUID) async throws {
        struct IncrementParams: Encodable {
            let deck_id: UUID
        }
        
        try await client.rpc("increment_downloads", params: IncrementParams(deck_id: deckId))
            .execute()
    }
    
    func reportUsageStats(shareCode: String, reviewsCount: Int, isReturnUser: Bool = false) async throws {
        struct UsageParams: Encodable {
            let p_share_code: String
            let p_reviews_count: Int
            let p_is_return_user: Bool
        }
        
        try await client.rpc("report_usage_stats", params: UsageParams(p_share_code: shareCode, p_reviews_count: reviewsCount, p_is_return_user: isReturnUser))
            .execute()
    }
    
    @discardableResult
    func updateMarketDeck(shareCode: String, upload: MarketDeckUpload) async throws -> SharedDeck {
        guard upload.authorId != nil else {
            throw AuthError.notAuthenticated
        }
        let sanitizedCode = shareCode.normalizedShareCode
        let response: SharedDeck = try await client.from("shared_decks")
            .update(upload)
            .eq("share_code", value: sanitizedCode)
            .select()
            .single()
            .execute()
            .value
        return response
    }
    
    func removeFromMarket(shareCode: String) async throws {
        let sanitizedCode = shareCode.normalizedShareCode
        struct UnpublishRPCParams: Encodable {
            let target_code: String
        }
        try await client.rpc("unpublish_deck", params: UnpublishRPCParams(target_code: sanitizedCode)).execute()
    }
    
    func setMarketVisibility(shareCode: String, isPublic: Bool) async throws {
        let sanitizedCode = shareCode.normalizedShareCode
        struct VisibilityRPCParams: Encodable {
            let target_code: String
            let p_is_public: Bool
        }
        try await client.rpc("set_deck_visibility", params: VisibilityRPCParams(target_code: sanitizedCode, p_is_public: isPublic)).execute()
    }
    
    func deleteFromMarket(shareCode: String) async throws {
        let sanitizedCode = shareCode.normalizedShareCode
        struct DeleteRPCParams: Encodable {
            let target_code: String
        }
        try await client.rpc("delete_deck", params: DeleteRPCParams(target_code: sanitizedCode)).execute()
    }
    
    func markDeckAsArchived(shareCode: String) async throws {
        let sanitizedCode = shareCode.normalizedShareCode
        struct ArchiveRPCParams: Encodable {
            let target_code: String
        }
        try await client.rpc("archive_deck", params: ArchiveRPCParams(target_code: sanitizedCode)).execute()
    }
}

// MARK: - FlipItStore Market Updates Extension (Main App Target Only)

extension FlipItStore {
    /// Sprawdza w tle czy autorzy zaimportowanych talii opublikowali nowe wersje
    /// Domyślnie wykonuje się raz dziennie (np. przy pierwszym uruchomieniu). Flaga `force = true` wymusza natychmiastowe sprawdzenie.
    @MainActor
    func checkMarketUpdatesForImportedDecks(force: Bool = false) async {
        let importedDecks = decks.filter { $0.shareCode != nil && !$0.isMarketAuthor }
        guard !importedDecks.isEmpty else { return }

        // Sprawdzanie raz dziennie przy automatycznym wywołaniu
        if !force {
            let lastTimestamp = UserDefaults.standard.double(forKey: "lastMarketUpdateCheckTimestamp")
            if lastTimestamp > 0 {
                let lastDate = Date(timeIntervalSince1970: lastTimestamp)
                if Calendar.current.isDateInToday(lastDate) {
                    #if DEBUG
                    print("checkMarketUpdatesForImportedDecks: already checked today, skipping.")
                    #endif
                    return
                }
            }
        }

        var anyChanged = false
        for deck in importedDecks {
            guard let code = deck.shareCode else { continue }
            do {
                if let remote = try await SupabaseManager.shared.fetchByCode(code) {
                    let remoteVersion = remote.updatedAt ?? remote.createdAt ?? "\(remote.cardsCount)"
                    let diff = calculateSyncDiff(deckId: deck.id, remoteDeck: remote)
                    let hasChanges = diff?.hasChanges ?? false

                    if let index = decks.firstIndex(where: { $0.id == deck.id }) {
                        let isNewVersion = decks[index].lastDismissedUpdateDate != remoteVersion
                        let shouldFlag = hasChanges && isNewVersion
                        if decks[index].hasPendingMarketUpdate != shouldFlag {
                            decks[index].hasPendingMarketUpdate = shouldFlag
                            anyChanged = true
                        }
                    }
                }
            } catch {
                #if DEBUG
                print("Failed checking market updates for \(deck.name): \(error)")
                #endif
            }
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastMarketUpdateCheckTimestamp")
        if anyChanged {
            saveData()
        }
    }
}

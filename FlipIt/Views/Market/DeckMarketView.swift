import SwiftUI

struct MarketLanguageOption: Identifiable, Hashable {
    let id: String
    let name: String
    let flag: String
}

let marketLanguages: [MarketLanguageOption] = [
    MarketLanguageOption(id: "All", name: "All Languages", flag: "🌐"),
    MarketLanguageOption(id: "en", name: "English", flag: "🇬🇧"),
    MarketLanguageOption(id: "pl", name: "Polish", flag: "🇵🇱"),
    MarketLanguageOption(id: "es", name: "Spanish", flag: "🇪🇸"),
    MarketLanguageOption(id: "de", name: "German", flag: "🇩🇪"),
    MarketLanguageOption(id: "fr", name: "French", flag: "🇫🇷"),
    MarketLanguageOption(id: "it", name: "Italian", flag: "🇮🇹"),
    MarketLanguageOption(id: "ja", name: "Japanese", flag: "🇯🇵"),
    MarketLanguageOption(id: "zh", name: "Chinese", flag: "🇨🇳"),
    MarketLanguageOption(id: "ko", name: "Korean", flag: "🇰🇷"),
    MarketLanguageOption(id: "ru", name: "Russian", flag: "🇷🇺"),
    MarketLanguageOption(id: "uk", name: "Ukrainian", flag: "🇺🇦")
]

func flagEmoji(for languageCode: String) -> String {
    let code = languageCode.lowercased()
    if code.hasPrefix("en") { return "🇬🇧" }
    if code.hasPrefix("pl") { return "🇵🇱" }
    if code.hasPrefix("de") { return "🇩🇪" }
    if code.hasPrefix("es") { return "🇪🇸" }
    if code.hasPrefix("fr") { return "🇫🇷" }
    if code.hasPrefix("it") { return "🇮🇹" }
    if code.hasPrefix("pt") { return "🇵🇹" }
    if code.hasPrefix("ja") { return "🇯🇵" }
    if code.hasPrefix("zh") { return "🇨🇳" }
    if code.hasPrefix("ko") { return "🇰🇷" }
    if code.hasPrefix("ru") { return "🇷🇺" }
    if code.hasPrefix("uk") { return "🇺🇦" }
    return "🌐"
}

let marketCEFRLevels = ["All", "A1", "A2", "B1", "B2", "C1", "C2"]

enum MarketTab: Hashable {
    case official
    case community
    case myDecks
}

enum DeckMarketUserRelation: Equatable {
    case myDeck(localDeck: Deck)
    case downloaded(localDeck: Deck, hasUpdate: Bool)
    case notDownloaded
}

struct DeckMarketView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    @State private var selectedTab: MarketTab = .official
    
    // Filtry i sortowanie
    @State private var selectedLevel: String = "All"
    @State private var selectedLanguage: String = "All"
    @State private var selectedSort: MarketSortOption = .downloads
    
    @State private var officialDecks: [SharedDeck] = []
    @State private var communityDecks: [SharedDeck] = []
    @State private var codeSearchResult: SharedDeck? = nil
    
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var currentPage = 0
    @State private var hasMorePages = true
    @State private var errorMessage: String? = nil
    
    @State private var showImportConfirmation = false
    @State private var deckToImport: SharedDeck? = nil
    
    @State private var showCodeSearchResult = false
    
    // Live Search & Preview
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @State private var previewDeck: SharedDeck? = nil
    @State private var showPreviewSheet = false
    @State private var isDownloadingDeckId: UUID? = nil
    
    // Zarządzanie moimi deckami i nawigacja
    @State private var selectedDeckForDetail: Deck? = nil
    @State private var navigateToDeckDetail: Bool = false
    @State private var syncSheetLocalDeck: Deck? = nil
    @State private var syncSheetRemoteDeck: SharedDeck? = nil
    @State private var showSyncSheet: Bool = false
    
    // Alerty statusu operacji
    @State private var showUpToDateAlert: Bool = false
    @State private var showUpdateSuccessAlert: Bool = false
    @State private var showRemoveSuccessAlert: Bool = false
    @State private var deckToRemoveFromMarket: Deck? = nil
    @State private var showRemoveConfirmAlert: Bool = false
    @State private var deckToDeletePermanently: Deck? = nil
    @State private var showDeletePermanentlyConfirmAlert: Bool = false
    
    // Wskaźniki postępu dla poszczególnych decków
    @State private var updatingDeckId: UUID? = nil
    @State private var isCheckingUpdatesDeckId: UUID? = nil
    
    private var isFiltered: Bool {
        selectedLevel != "All" || selectedLanguage != "All" || selectedSort != .downloads
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appGroupedBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 1. STAŁY GÓRNY PASEK (Community na poziomie przycisku Done/Cancel, bez obwódek)
                    HStack(alignment: .center) {
                        Text("Community")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(Color.primary)
                        
                        Spacer()
                        
                        Button("Done") {
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            #endif
                            dismiss()
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.blue)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 6)
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search title, tags, or share code", text: $searchText)
                            .submitLabel(.search)
                            .onSubmit {
                                performSearch()
                            }
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                showCodeSearchResult = false
                                codeSearchResult = nil
                                if selectedTab == .community {
                                    Task {
                                        await loadCommunityDecks(reset: true)
                                    }
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(8)
                    .background(Color.appSecondaryGroupedBackground)
                    .cornerRadius(10)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    
                    if showCodeSearchResult {
                        // Show single code search result
                        if isLoading {
                            Spacer()
                            ProgressView("Searching by code...")
                            Spacer()
                        } else if let deck = codeSearchResult {
                            ScrollView {
                                VStack {
                                    Text("Found by Share Code")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal)
                                        .padding(.top)
                                    
                                    DeckMarketRowView(
                                        deck: deck,
                                        relation: userRelation(for: deck),
                                        isDownloading: isDownloadingDeckId == deck.id,
                                        onSelect: {
                                            previewDeck = deck
                                            showPreviewSheet = true
                                        },
                                        onDownload: {
                                            prepareImport(deck: deck)
                                        },
                                        onManage: { localDeck in
                                            handleManage(localDeck: localDeck)
                                        },
                                        onSync: { localDeck, sharedDeck in
                                            handleSync(localDeck: localDeck, remoteSummary: sharedDeck)
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        } else {
                            Spacer()
                            ContentUnavailableView(
                                "No Deck Found",
                                systemImage: "magnifyingglass",
                                description: Text("We couldn't find a deck with the code '\(searchText)'.")
                            )
                            Spacer()
                        }
                    } else {
                        // Tabs
                        Picker("Tabs", selection: $selectedTab) {
                            Text("Official").tag(MarketTab.official)
                            Text("Community").tag(MarketTab.community)
                            Text("My Decks").tag(MarketTab.myDecks)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .onChange(of: selectedTab) { _, newValue in
                            Task {
                                if newValue == .community {
                                    if communityDecks.isEmpty {
                                        await loadCommunityDecks(reset: true)
                                    }
                                } else if newValue == .official {
                                    if officialDecks.isEmpty {
                                        await loadOfficialDecks(forceRefresh: true)
                                    }
                                } else if newValue == .myDecks {
                                    await store.checkMarketUpdatesForImportedDecks(force: true)
                                }
                            }
                        }
                        
                        // Pasek filtrów i sortowania (tylko dla zakładek przeglądania)
                        if selectedTab != .myDecks {
                            filterBar
                        }
                        
                        // List
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                if selectedTab == .myDecks {
                                    myDecksView
                                } else if isLoading && officialDecks.isEmpty && communityDecks.isEmpty {
                                    ProgressView("Loading decks...")
                                        .padding(.top, 50)
                                } else {
                                    if selectedTab == .official {
                                        if officialDecks.isEmpty {
                                            if isFiltered {
                                                VStack(spacing: 12) {
                                                    ContentUnavailableView(
                                                        "No Matching Decks",
                                                        systemImage: "line.3.horizontal.decrease.circle",
                                                        description: Text("No official decks match the selected filters.")
                                                    )
                                                    Button("Reset Filters") {
                                                        resetFilters()
                                                    }
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundStyle(Color.accentColor)
                                                    .clipShape(Capsule())
                                                }
                                                .padding(.top, 40)
                                            } else {
                                                ContentUnavailableView(
                                                    "No Official Decks",
                                                    systemImage: "checkmark.seal.fill",
                                                    description: Text("There are currently no official decks available.")
                                                )
                                                .padding(.top, 50)
                                            }
                                        } else {
                                            ForEach(officialDecks, id: \.id) { deck in
                                                DeckMarketRowView(
                                                    deck: deck,
                                                    relation: userRelation(for: deck),
                                                    isDownloading: isDownloadingDeckId == deck.id,
                                                    onSelect: {
                                                        previewDeck = deck
                                                        showPreviewSheet = true
                                                    },
                                                    onDownload: {
                                                        prepareImport(deck: deck)
                                                    },
                                                    onManage: { localDeck in
                                                        handleManage(localDeck: localDeck)
                                                    },
                                                    onSync: { localDeck, sharedDeck in
                                                        handleSync(localDeck: localDeck, remoteSummary: sharedDeck)
                                                    }
                                                )
                                            }
                                        }
                                    } else {
                                        if communityDecks.isEmpty {
                                            if isFiltered {
                                                VStack(spacing: 12) {
                                                    ContentUnavailableView(
                                                        "No Matching Decks",
                                                        systemImage: "line.3.horizontal.decrease.circle",
                                                        description: Text("No community decks match your search and filter criteria.")
                                                    )
                                                    Button("Reset Filters") {
                                                        resetFilters()
                                                    }
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .padding(.horizontal, 16)
                                                    .padding(.vertical, 8)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundStyle(Color.accentColor)
                                                    .clipShape(Capsule())
                                                }
                                                .padding(.top, 40)
                                            } else {
                                                ContentUnavailableView(
                                                    "No Community Decks",
                                                    systemImage: "person.3.fill",
                                                    description: Text(searchText.isEmpty ? "Be the first to share a deck!" : "No decks matching '\(searchText)'.")
                                                )
                                                .padding(.top, 50)
                                            }
                                        } else {
                                            ForEach(communityDecks, id: \.id) { deck in
                                                DeckMarketRowView(
                                                    deck: deck,
                                                    relation: userRelation(for: deck),
                                                    isDownloading: isDownloadingDeckId == deck.id,
                                                    onSelect: {
                                                        previewDeck = deck
                                                        showPreviewSheet = true
                                                    },
                                                    onDownload: {
                                                        prepareImport(deck: deck)
                                                    },
                                                    onManage: { localDeck in
                                                        handleManage(localDeck: localDeck)
                                                    },
                                                    onSync: { localDeck, sharedDeck in
                                                        handleSync(localDeck: localDeck, remoteSummary: sharedDeck)
                                                    }
                                                )
                                                .onAppear {
                                                    if deck.id == communityDecks.last?.id {
                                                        Task {
                                                            await loadMoreCommunityDecks()
                                                        }
                                                    }
                                                }
                                            }
                                            
                                            if isLoadingMore {
                                                ProgressView()
                                                    .padding()
                                            } else if !hasMorePages && !communityDecks.isEmpty {
                                                Text("No more decks")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .padding()
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .hideNavigationBarCompat()
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $navigateToDeckDetail) {
                if let deck = selectedDeckForDetail {
                    DeckDetailView(store: store, deck: deck)
                }
            }
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        handleLiveSearch(query: newValue)
                    }
                }
            }
            .sheet(isPresented: $showPreviewSheet) {
                if let deck = previewDeck {
                    CommunityDeckPreviewSheet(
                        deckSummary: deck,
                        relation: userRelation(for: deck),
                        onImport: { fullDeck in
                            showPreviewSheet = false
                            importDeck(fullDeck)
                        },
                        onManage: { localDeck in
                            showPreviewSheet = false
                            handleManage(localDeck: localDeck)
                        },
                        onSync: { localDeck, remoteDeck in
                            showPreviewSheet = false
                            handleSync(localDeck: localDeck, remoteSummary: remoteDeck)
                        }
                    )
                    .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showSyncSheet) {
                if let local = syncSheetLocalDeck, let remote = syncSheetRemoteDeck {
                    DeckSyncSheet(store: store, deck: local, remoteDeck: remote)
                        .presentationDetents([.large])
                }
            }
            .task {
                await loadOfficialDecks()
            }
            .alert("Import Deck", isPresented: $showImportConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Import") {
                    if let deck = deckToImport {
                        importDeck(deck)
                    }
                }
            } message: {
                if let deck = deckToImport {
                    Text("Import '\(deck.title)'? This will create a new deck with \(deck.cardsCount) cards.")
                }
            }
            .alert("Up to Date", isPresented: $showUpToDateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You already have the latest version of this deck.")
            }
            .alert("Deck Updated", isPresented: $showUpdateSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your changes have been published to Community!")
            }
            .alert("Unpublish from Community", isPresented: $showRemoveConfirmAlert) {
                Button("Cancel", role: .cancel) { deckToRemoveFromMarket = nil }
                Button("Unpublish", role: .destructive) {
                    if let deck = deckToRemoveFromMarket {
                        Task {
                            await removeDeckFromMarket(deck: deck)
                        }
                    }
                }
            } message: {
                if let deck = deckToRemoveFromMarket {
                    Text("Are you sure you want to unpublish '\(deck.name)' from Community? It will become private (unlisted). You can make it public again at any time.")
                }
            }
            .alert("Delete from Community", isPresented: $showDeletePermanentlyConfirmAlert) {
                Button("Cancel", role: .cancel) { deckToDeletePermanently = nil }
                Button("Delete", role: .destructive) {
                    if let deck = deckToDeletePermanently {
                        Task {
                            await deleteDeckPermanently(deck: deck)
                        }
                    }
                    deckToDeletePermanently = nil
                }
            } message: {
                Text("This will completely delete this deck from the Community cloud. Users will no longer be able to find or update it.")
            }
            .alert("Deleted from Community", isPresented: $showRemoveSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your deck has been permanently deleted from the Community cloud.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }
    
    // MARK: - Search Logic
    
    private func isShareCode(_ text: String) -> Bool {
        let cleaned = text.normalizedShareCode
        guard cleaned.count == 8 else { return false }
        let alphanumeric = CharacterSet.alphanumerics
        return cleaned.unicodeScalars.allSatisfy { alphanumeric.contains($0) }
    }
    
    private func handleLiveSearch(query: String) {
        if selectedTab == .myDecks {
            return
        }
        
        if query.isEmpty {
            showCodeSearchResult = false
            codeSearchResult = nil
            if selectedTab == .community {
                Task {
                    await loadCommunityDecks(reset: true)
                }
            }
        } else if isShareCode(query) {
            showCodeSearchResult = true
            Task {
                await searchByCode()
            }
        } else {
            showCodeSearchResult = false
            if selectedTab != .community {
                selectedTab = .community
            }
            Task {
                await loadCommunityDecks(reset: true)
            }
        }
    }
    
    private func performSearch() {
        handleLiveSearch(query: searchText)
    }
    
    private func searchByCode() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let cleanedCode = searchText.normalizedShareCode
            if let deck = try await SupabaseManager.shared.fetchByCode(cleanedCode) {
                codeSearchResult = deck
            } else {
                codeSearchResult = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            codeSearchResult = nil
        }
        
        isLoading = false
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Sort Menu
                Menu {
                    ForEach(MarketSortOption.allCases) { option in
                        Button(action: {
                            selectedSort = option
                            applyFilters()
                        }) {
                            HStack {
                                Text(LocalizedStringKey(option.title))
                                Spacer()
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectedSort.systemImage)
                        Text(LocalizedStringKey(selectedSort.title))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedSort != .downloads ? Color.accentColor.opacity(0.15) : Color.appSecondaryGroupedBackground)
                    .foregroundColor(selectedSort != .downloads ? Color.accentColor : .primary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedSort != .downloads ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Level Filter Menu
                Menu {
                    ForEach(marketCEFRLevels, id: \.self) { level in
                        Button(action: {
                            selectedLevel = level
                            applyFilters()
                        }) {
                            HStack {
                                Text(level == "All" ? "All Levels" : "Level \(level)")
                                Spacer()
                                if selectedLevel == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chart.bar")
                        Text(selectedLevel == "All" ? "Level" : "Level \(selectedLevel)")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedLevel != "All" ? Color.purple.opacity(0.15) : Color.appSecondaryGroupedBackground)
                    .foregroundColor(selectedLevel != "All" ? Color.purple : .primary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedLevel != "All" ? Color.purple : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Language Filter Menu
                Menu {
                    ForEach(marketLanguages) { lang in
                        Button(action: {
                            selectedLanguage = lang.id
                            applyFilters()
                        }) {
                            HStack {
                                Text("\(lang.flag) \(NSLocalizedString(lang.name, comment: ""))")
                                Spacer()
                                if selectedLanguage == lang.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    let currentLang = marketLanguages.first(where: { $0.id == selectedLanguage })
                    let currentLangName = currentLang != nil ? NSLocalizedString(currentLang!.name, comment: "") : selectedLanguage
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text(selectedLanguage == "All" ? NSLocalizedString("Language", comment: "") : "\(currentLang?.flag ?? "") \(currentLangName)")
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(selectedLanguage != "All" ? Color.blue.opacity(0.15) : Color.appSecondaryGroupedBackground)
                    .foregroundColor(selectedLanguage != "All" ? Color.blue : .primary)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(selectedLanguage != "All" ? Color.blue : Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Reset Filters Button
                if isFiltered {
                    Button(action: {
                        resetFilters()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Reset")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
    
    private func resetFilters() {
        selectedSort = .downloads
        selectedLevel = "All"
        selectedLanguage = "All"
        applyFilters()
    }
    
    private func applyFilters() {
        Task {
            if selectedTab == .community {
                await loadCommunityDecks(reset: true)
            } else {
                await loadOfficialDecks(forceRefresh: true)
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadOfficialDecks(forceRefresh: Bool = false) async {
        if !forceRefresh && !officialDecks.isEmpty { return }
        isLoading = true
        do {
            officialDecks = try await SupabaseManager.shared.fetchOfficialDecks(
                level: selectedLevel == "All" ? nil : selectedLevel,
                language: selectedLanguage == "All" ? nil : selectedLanguage,
                sortBy: selectedSort
            )
        } catch {
            errorMessage = "Failed to load official decks: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func loadCommunityDecks(reset: Bool = false) async {
        if reset {
            currentPage = 0
            hasMorePages = true
            communityDecks = []
            isLoading = true
        }
        
        guard hasMorePages, !isLoadingMore else { return }
        
        if !reset {
            isLoadingMore = true
        }
        
        do {
            let decks = try await SupabaseManager.shared.fetchCommunityDecks(
                searchQuery: searchText.isEmpty ? nil : searchText,
                level: selectedLevel == "All" ? nil : selectedLevel,
                language: selectedLanguage == "All" ? nil : selectedLanguage,
                sortBy: selectedSort,
                page: currentPage,
                pageSize: 20
            )
            
            if reset {
                communityDecks = decks
            } else {
                communityDecks.append(contentsOf: decks)
            }
            
            currentPage += 1
            hasMorePages = decks.count == 20
        } catch {
            errorMessage = "Failed to load community decks: \(error.localizedDescription)"
        }
        
        if reset {
            isLoading = false
        } else {
            isLoadingMore = false
        }
    }
    
    private func loadMoreCommunityDecks() async {
        await loadCommunityDecks(reset: false)
    }
    
    // MARK: - Import Logic
    
    private func prepareImport(deck: SharedDeck) {
        if deck.cardsPayload.isEmpty && deck.cardsCount > 0 {
            isDownloadingDeckId = deck.id
            Task {
                do {
                    let full = try await SupabaseManager.shared.fetchFullDeck(id: deck.id)
                    await MainActor.run {
                        self.isDownloadingDeckId = nil
                        self.deckToImport = full
                        self.showImportConfirmation = true
                    }
                } catch {
                    await MainActor.run {
                        self.isDownloadingDeckId = nil
                        self.errorMessage = "Failed to load deck data: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            deckToImport = deck
            showImportConfirmation = true
        }
    }
    
    private func importDeck(_ sharedDeck: SharedDeck) {
        store.importMarketDeck(from: sharedDeck)
        
        // Zwiększ licznik pobrań w tle
        Task {
            do {
                try await SupabaseManager.shared.incrementDownloads(deckId: sharedDeck.id)
            } catch {
                print("Failed to increment downloads: \(error)")
            }
        }
        
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        
        deckToImport = nil
    }
    
    // MARK: - User Relation & Management Logic
    
    private func userRelation(for sharedDeck: SharedDeck) -> DeckMarketUserRelation {
        let cleanSharedCode = sharedDeck.shareCode.normalizedShareCode
        
        // 1. Własny opublikowany deck
        if let local = store.decks.first(where: {
            ($0.shareCode?.normalizedShareCode ?? "") == cleanSharedCode && $0.isMarketAuthor
        }) {
            return .myDeck(localDeck: local)
        }
        
        // 2. Zaimportowany deck
        if let local = store.decks.first(where: {
            ($0.shareCode?.normalizedShareCode ?? "") == cleanSharedCode && !$0.isMarketAuthor
        }) {
            let remoteVersion = sharedDeck.updatedAt ?? sharedDeck.createdAt ?? "\(sharedDeck.cardsCount)"
            let hasUpdate = local.hasPendingMarketUpdate || (local.lastDismissedUpdateDate != remoteVersion)
            return .downloaded(localDeck: local, hasUpdate: hasUpdate)
        }
        
        return .notDownloaded
    }
    
    private func handleManage(localDeck: Deck) {
        selectedDeckForDetail = localDeck
        navigateToDeckDetail = true
    }
    
    private func handleSync(localDeck: Deck, remoteSummary: SharedDeck) {
        if remoteSummary.cardsPayload.isEmpty && remoteSummary.cardsCount > 0 {
            isDownloadingDeckId = remoteSummary.id
            Task {
                do {
                    let full = try await SupabaseManager.shared.fetchFullDeck(id: remoteSummary.id)
                    await MainActor.run {
                        self.isDownloadingDeckId = nil
                        self.syncSheetLocalDeck = localDeck
                        self.syncSheetRemoteDeck = full
                        self.showSyncSheet = true
                    }
                } catch {
                    await MainActor.run {
                        self.isDownloadingDeckId = nil
                        self.errorMessage = "Failed to load deck for sync: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            self.syncSheetLocalDeck = localDeck
            self.syncSheetRemoteDeck = remoteSummary
            self.showSyncSheet = true
        }
    }
    
    private func checkForUpdates(for deck: Deck) async {
        guard let code = deck.shareCode else { return }
        isCheckingUpdatesDeckId = deck.id
        defer { isCheckingUpdatesDeckId = nil }
        
        do {
            if let remote = try await SupabaseManager.shared.fetchByCode(code) {
                let remoteVersion = remote.updatedAt ?? remote.createdAt ?? "\(remote.cardsCount)"
                let diff = store.calculateSyncDiff(deckId: deck.id, remoteDeck: remote)
                let hasChanges = diff?.hasChanges ?? false
                
                await MainActor.run {
                    if let index = store.decks.firstIndex(where: { $0.id == deck.id }) {
                        if hasChanges && store.decks[index].lastDismissedUpdateDate != remoteVersion {
                            store.decks[index].hasPendingMarketUpdate = true
                            self.syncSheetLocalDeck = store.decks[index]
                            self.syncSheetRemoteDeck = remote
                            self.showSyncSheet = true
                        } else {
                            store.decks[index].hasPendingMarketUpdate = false
                            self.showUpToDateAlert = true
                            #if canImport(UIKit)
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                        }
                        store.saveData()
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Could not check for updates: \(error.localizedDescription)"
            }
        }
    }
    
    private func updateDeckOnMarket(deck: Deck) async {
        guard let code = deck.shareCode else { return }
        updatingDeckId = deck.id
        defer { updatingDeckId = nil }
        
        let cardPairs = deck.cards.map { ($0.front, $0.back) }
        let analysis = await GeminiService().analyzeDeck(
            title: deck.name,
            description: deck.description,
            frontLanguage: deck.frontLanguage,
            backLanguage: deck.backLanguage,
            sampleCards: cardPairs,
            existingLevel: deck.difficultyLevel
        )
        
        let sharedCards = deck.cards.map { SharedCard(front: $0.front, back: $0.back) }
        let upload = MarketDeckUpload(
            title: deck.name,
            description: deck.description,
            frontLabel: deck.frontLabel,
            backLabel: deck.backLabel,
            frontLanguage: deck.frontLanguage,
            backLanguage: deck.backLanguage,
            cardsCount: deck.cards.count,
            cardsPayload: sharedCards,
            isPublic: deck.isMarketPublic,
            authorName: AuthManager.shared.username ?? "Author",
            tags: analysis.tags,
            difficultyLevel: analysis.level,
            authorId: AuthManager.shared.currentUserId
        )
        
        do {
            try await SupabaseManager.shared.updateMarketDeck(shareCode: code, upload: upload)
            await MainActor.run {
                self.showUpdateSuccessAlert = true
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update deck: \(error.localizedDescription)"
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }
    
    private func removeDeckFromMarket(deck: Deck) async {
        guard let code = deck.shareCode else { return }
        do {
            try await SupabaseManager.shared.removeFromMarket(shareCode: code)
            await MainActor.run {
                store.unpublishDeckFromMarket(deckId: deck.id)
                self.showRemoveSuccessAlert = true
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to unpublish deck: \(error.localizedDescription)"
            }
        }
    }
    
    private func toggleMarketVisibility(deck: Deck) async {
        guard let code = deck.shareCode else { return }
        let newVis = !deck.isMarketPublic
        do {
            try await SupabaseManager.shared.setMarketVisibility(shareCode: code, isPublic: newVis)
            await MainActor.run {
                store.setDeckMarketVisibility(deckId: deck.id, isPublic: newVis)
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update visibility: \(error.localizedDescription)"
            }
        }
    }
    
    private func deleteDeckPermanently(deck: Deck) async {
        guard let code = deck.shareCode else { return }
        do {
            try await SupabaseManager.shared.deleteFromMarket(shareCode: code)
            await MainActor.run {
                store.removeDeckShareCode(deckId: deck.id)
                self.showRemoveSuccessAlert = true
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to permanently delete deck: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - My Decks Tab View
    
    private var publishedDecks: [Deck] {
        let list = store.decks.filter { $0.shareCode != nil && $0.isMarketAuthor }
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty { return list }
        let q = searchText.lowercased()
        return list.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            ($0.shareCode?.lowercased().contains(q) ?? false)
        }
    }
    
    private var downloadedDecks: [Deck] {
        let list = store.decks.filter { $0.shareCode != nil && !$0.isMarketAuthor }
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty { return list }
        let q = searchText.lowercased()
        return list.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            ($0.shareCode?.lowercased().contains(q) ?? false)
        }
    }
    
    @ViewBuilder
    private var myDecksView: some View {
        if publishedDecks.isEmpty && downloadedDecks.isEmpty {
            ContentUnavailableView(
                "No Community Decks",
                systemImage: "folder.badge.person.crop",
                description: Text(searchText.isEmpty
                    ? "You haven't shared or downloaded any decks from Community yet."
                    : "No decks matching '\(searchText)'.")
            )
            .padding(.top, 50)
        } else {
            if !publishedDecks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Shared by Me")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(publishedDecks.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.15))
                            .foregroundStyle(Color.blue)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 4)
                    
                    ForEach(publishedDecks) { deck in
                        MyCommunityDeckRowView(
                            deck: deck,
                            isUpdating: updatingDeckId == deck.id,
                            isCheckingUpdates: isCheckingUpdatesDeckId == deck.id,
                            onSelect: {
                                handleManage(localDeck: deck)
                            },
                            onUpdateInCommunity: {
                                Task {
                                    await updateDeckOnMarket(deck: deck)
                                }
                            },
                            onRemoveFromCommunity: { },
                            onCheckForUpdates: {
                                Task {
                                    await checkForUpdates(for: deck)
                                }
                            },
                            onSyncUpdate: {
                                Task {
                                    await checkForUpdates(for: deck)
                                }
                            },
                            onToggleVisibility: {
                                Task {
                                    await toggleMarketVisibility(deck: deck)
                                }
                            },
                            onDeletePermanently: {
                                deckToDeletePermanently = deck
                                showDeletePermanentlyConfirmAlert = true
                            }
                        )
                    }
                }
            }
            
            if !downloadedDecks.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Downloaded from Community")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(downloadedDecks.count)")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(Color.green)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, publishedDecks.isEmpty ? 0 : 12)
                    
                    ForEach(downloadedDecks) { deck in
                        MyCommunityDeckRowView(
                            deck: deck,
                            isUpdating: updatingDeckId == deck.id,
                            isCheckingUpdates: isCheckingUpdatesDeckId == deck.id,
                            onSelect: {
                                handleManage(localDeck: deck)
                            },
                            onUpdateInCommunity: { },
                            onRemoveFromCommunity: {
                                store.removeDeckShareCode(deckId: deck.id)
                            },
                            onCheckForUpdates: {
                                Task {
                                    await checkForUpdates(for: deck)
                                }
                            },
                            onSyncUpdate: {
                                Task {
                                    await checkForUpdates(for: deck)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

import SwiftUI

struct EditDeckSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var store: FlipItStore

    var deckId: UUID

    // Sprawdzamy, czy to pierwszy deck
    var isSystemDeck: Bool {
        store.decks.first?.id == deckId
    }

    var currentDeck: Deck? {
        store.decks.first(where: { $0.id == deckId })
    }

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var frontLabel: String = ""
    @State private var backLabel: String = ""

    @State private var frontLanguage: String = "en-US"
    @State private var backLanguage: String = "pl-PL"
    @State private var difficultyLevel: String = ""
    @State private var isMarketPublic: Bool = true

    // Tracking original values for changes check
    @State private var initialName: String = ""
    @State private var initialDescription: String = ""
    @State private var initialFrontLabel: String = ""
    @State private var initialBackLabel: String = ""
    @State private var initialFrontLanguage: String = "en-US"
    @State private var initialBackLanguage: String = "pl-PL"
    @State private var initialDifficultyLevel: String = ""
    @State private var initialMarketPublic: Bool = true
    @State private var isInitialized: Bool = false

    // Community Management State
    @State private var showPublishSheet = false
    @State private var isUpdatingOnMarket = false
    @State private var showUpdateSuccessAlert = false
    @State private var showSaveBeforePublishAlert = false
    @State private var showDeletePermanentlyAlert = false
    @State private var showDeletePermanentlySuccessAlert = false
    @State private var isCheckingUpdates = false
    @State private var showUpToDateAlert = false
    @State private var showSyncSheet = false
    @State private var syncRemoteDeck: SharedDeck? = nil
    @State private var showUnlinkAlert = false
    @State private var showMarketErrorAlert = false
    @State private var marketActionErrorMessage: String? = nil
    @State private var showCopiedToast = false

    // Discard Confirmation
    @State private var showDiscardConfirmAlert = false

    var hasChanges: Bool {
        guard isInitialized else { return false }
        return name != initialName ||
            description != initialDescription ||
            frontLabel != initialFrontLabel ||
            backLabel != initialBackLabel ||
            frontLanguage != initialFrontLanguage ||
            backLanguage != initialBackLanguage ||
            difficultyLevel != initialDifficultyLevel ||
            isMarketPublic != initialMarketPublic
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Deck Info")) {
                    HStack {
                        TextField("Deck Name", text: $name, axis: .vertical)
                            .disabled(isSystemDeck)
                            .foregroundStyle(isSystemDeck ? .secondary : .primary)
                            .onChange(of: name) { if name.count > AppLimits.deckName { name = String(name.prefix(AppLimits.deckName)) } }
                        Spacer()
                        Text("\(name.count)/\(AppLimits.deckName)")
                            .font(.caption)
                            .foregroundStyle(name.count >= AppLimits.deckName ? .red.opacity(0.8) : .secondary)
                    }

                    if isSystemDeck {
                        Text("You cannot rename the main deck.").font(.caption).foregroundStyle(.secondary)
                    }

                    HStack(alignment: .top) {
                        TextField("Description", text: $description, axis: .vertical)
                            .onChange(of: description) { if description.count > AppLimits.deckDescription { description = String(description.prefix(AppLimits.deckDescription)) } }
                        Spacer()
                        Text("\(description.count)/\(AppLimits.deckDescription)")
                            .font(.caption)
                            .foregroundStyle(description.count >= AppLimits.deckDescription ? .red.opacity(0.8) : .secondary)
                            .padding(.top, 4)
                    }

                    Picker("Level", selection: $difficultyLevel) {
                        Text("None").tag("")
                        ForEach(availableCEFRLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(header: Text("Front Side")) {
                    HStack {
                        TextField("Label", text: $frontLabel)
                            .onChange(of: frontLabel) { if frontLabel.count > AppLimits.label { frontLabel = String(frontLabel.prefix(AppLimits.label)) } }
                        Spacer()
                        Text("\(frontLabel.count)/\(AppLimits.label)")
                            .font(.caption)
                            .foregroundStyle(frontLabel.count >= AppLimits.label ? .red.opacity(0.8) : .secondary)
                    }
                    Picker("", selection: $frontLanguage) {
                        ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                            Text(LocalizedStringKey(value)).tag(key)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu)
                }

                Section(header: Text("Back Side")) {
                    HStack {
                        TextField("Label", text: $backLabel)
                            .onChange(of: backLabel) { if backLabel.count > AppLimits.label { backLabel = String(backLabel.prefix(AppLimits.label)) } }
                        Spacer()
                        Text("\(backLabel.count)/\(AppLimits.label)")
                            .font(.caption)
                            .foregroundStyle(backLabel.count >= AppLimits.label ? .red.opacity(0.8) : .secondary)
                    }
                    Picker("", selection: $backLanguage) {
                        ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                            Text(LocalizedStringKey(value)).tag(key)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu)
                }

                if let deck = currentDeck {
                    communitySection(for: deck)
                }
            }
            .navigationTitle("Edit Deck")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(hasChanges || isUpdatingOnMarket || isCheckingUpdates)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showDiscardConfirmAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.isEmpty || isUpdatingOnMarket || isCheckingUpdates)
                }
            }
            .onAppear {
                if !isInitialized, let deck = store.decks.first(where: { $0.id == deckId }) {
                    name = deck.name
                    description = deck.description
                    frontLabel = deck.frontLabel
                    backLabel = deck.backLabel
                    frontLanguage = deck.frontLanguage
                    backLanguage = deck.backLanguage
                    difficultyLevel = deck.difficultyLevel ?? ""
                    isMarketPublic = deck.isMarketPublic

                    initialName = deck.name
                    initialDescription = deck.description
                    initialFrontLabel = deck.frontLabel
                    initialBackLabel = deck.backLabel
                    initialFrontLanguage = deck.frontLanguage
                    initialBackLanguage = deck.backLanguage
                    initialDifficultyLevel = deck.difficultyLevel ?? ""
                    initialMarketPublic = deck.isMarketPublic
                    isInitialized = true
                }
            }
            .sheet(isPresented: $showPublishSheet) {
                if let deck = currentDeck {
                    NavigationStack {
                        PublishDeckSheet(store: store, deck: deck) { publishedDeck in
                            isMarketPublic = publishedDeck.isPublic
                            initialMarketPublic = publishedDeck.isPublic
                        }
                    }
                    .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showSyncSheet) {
                if let deck = currentDeck, let remote = syncRemoteDeck {
                    DeckSyncSheet(store: store, deck: deck, remoteDeck: remote)
                        .presentationDetents([.large])
                }
            }
            .alert("Save Changes First?", isPresented: $showSaveBeforePublishAlert) {
                Button("Save and Publish") {
                    saveChanges()
                    if let deck = currentDeck {
                        if deck.shareCode == nil {
                            showPublishSheet = true
                        } else {
                            Task {
                                await updateDeckOnMarket(deck: deck)
                            }
                        }
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("You have unsaved changes in this deck. Would you like to save them before publishing to Community?")
            }
            .alert("Discard Changes?", isPresented: $showDiscardConfirmAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard Changes", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .alert("Delete from Community", isPresented: $showDeletePermanentlyAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let code = currentDeck?.shareCode {
                        Task {
                            await deletePermanentlyFromMarket(code: code)
                        }
                    }
                }
            } message: {
                Text("This will completely delete this deck from the Community cloud. Users will no longer be able to find or update it.")
            }
            .alert("Unlink from Community", isPresented: $showUnlinkAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Unlink", role: .destructive) {
                    store.removeDeckShareCode(deckId: deckId)
                }
            } message: {
                Text("This deck will become a standalone local deck. You will no longer receive updates from the original author.")
            }
            .alert("Community Updated", isPresented: $showUpdateSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your deck has been updated in the Community. New downloaders and existing users checking for updates will receive this version.")
            }
            .alert("Deleted from Community", isPresented: $showDeletePermanentlySuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your deck has been permanently deleted from the Community cloud.")
            }
            .alert("Up to Date", isPresented: $showUpToDateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("You already have the latest version of this deck!")
            }
            .alert("Community Error", isPresented: $showMarketErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(marketActionErrorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Community Section

    @ViewBuilder
    private func communitySection(for deck: Deck) -> some View {
        Section(header: Text("Community")) {
            if deck.shareCode == nil {
                // UNPUBLISHED DECK
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 24))
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Share on Community")
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Share this deck with other users around the world.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)

                    Button(action: {
                        if hasChanges {
                            showSaveBeforePublishAlert = true
                        } else {
                            showPublishSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Publish to Community")
                        }
                        .fontWeight(.semibold)
                    }
                }
            } else if deck.isMarketAuthor {
                // AUTHOR OF PUBLISHED DECK
                HStack {
                    Label("Share Code", systemImage: "number")
                    Spacer()
                    if let code = deck.shareCode {
                        Text(deck.formattedCode)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Button(action: {
                            UIPasteboard.general.string = code
                            showCopiedToast = true
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                showCopiedToast = false
                            }
                        }) {
                            Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(showCopiedToast ? .green : .blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(isOn: $isMarketPublic) {
                    HStack(spacing: 12) {
                        Image(systemName: isMarketPublic ? "globe" : "person.2")
                            .font(.system(size: 20))
                            .foregroundColor(isMarketPublic ? .blue : .purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isMarketPublic ? "Public" : "Private (Code Only)")
                                .font(.body)
                            Text(isMarketPublic ? "Visible in Community search for everyone." : "Only accessible by entering the 8-character share code.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button(action: {
                    if hasChanges {
                        showSaveBeforePublishAlert = true
                    } else {
                        Task {
                            await updateDeckOnMarket(deck: deck)
                        }
                    }
                }) {
                    HStack {
                        if isUpdatingOnMarket {
                            ProgressView()
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text(isUpdatingOnMarket ? "Updating..." : "Update in Community")
                    }
                }
                .disabled(isUpdatingOnMarket)

                Button(role: .destructive, action: {
                    showDeletePermanentlyAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete from Community")
                    }
                    .foregroundStyle(.red)
                }
            } else {
                // DOWNLOADED DECK (NOT AUTHOR)
                HStack {
                    Label("Share Code", systemImage: "number")
                    Spacer()
                    if let code = deck.shareCode {
                        Text(deck.formattedCode)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                        Button(action: {
                            UIPasteboard.general.string = code
                            showCopiedToast = true
                            #if canImport(UIKit)
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            #endif
                            Task {
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                showCopiedToast = false
                            }
                        }) {
                            Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(showCopiedToast ? .green : .blue)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: {
                    if let code = deck.shareCode {
                        Task {
                            await checkForUpdates(code: code)
                        }
                    }
                }) {
                    HStack {
                        if isCheckingUpdates {
                            ProgressView()
                                .padding(.trailing, 4)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(isCheckingUpdates ? "Checking..." : "Check for Updates")
                    }
                }
                .disabled(isCheckingUpdates)

                Button(role: .destructive, action: {
                    showUnlinkAlert = true
                }) {
                    Label("Unlink from Community", systemImage: "link.badge.plus")
                }
            }
        }
    }

    // MARK: - Community Operations

    private func updateDeckOnMarket(deck: Deck) async {
        guard let code = deck.shareCode else { return }
        isUpdatingOnMarket = true

        let cardPairs = deck.cards.map { ($0.front, $0.back) }
        let analysis = await GeminiService().analyzeDeck(
            title: name,
            description: description,
            frontLanguage: frontLanguage,
            backLanguage: backLanguage,
            sampleCards: cardPairs,
            existingLevel: difficultyLevel.isEmpty ? nil : difficultyLevel
        )

        let sharedCards = deck.cards.map { SharedCard(front: $0.front, back: $0.back) }
        let upload = MarketDeckUpload(
            title: name,
            description: description,
            frontLabel: frontLabel,
            backLabel: backLabel,
            frontLanguage: frontLanguage,
            backLanguage: backLanguage,
            cardsCount: deck.cards.count,
            cardsPayload: sharedCards,
            isPublic: isMarketPublic,
            authorName: "Author",
            tags: analysis.tags,
            difficultyLevel: analysis.level
        )

        do {
            try await SupabaseManager.shared.updateMarketDeck(shareCode: code, upload: upload)
            await MainActor.run {
                self.isUpdatingOnMarket = false
                self.showUpdateSuccessAlert = true
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
            }
        } catch {
            await MainActor.run {
                self.isUpdatingOnMarket = false
                self.marketActionErrorMessage = error.localizedDescription
                self.showMarketErrorAlert = true
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
                #endif
            }
        }
    }

    private func saveChanges() {
        store.updateDeck(
            deckId: deckId,
            name: name,
            description: description,
            frontLabel: frontLabel,
            backLabel: backLabel,
            frontLanguage: frontLanguage,
            backLanguage: backLanguage,
            difficultyLevel: difficultyLevel.isEmpty ? nil : difficultyLevel
        )
        if let deck = store.decks.first(where: { $0.id == deckId }),
           deck.isMarketAuthor,
           let code = deck.shareCode,
           deck.isMarketPublic != isMarketPublic {
            store.setDeckMarketVisibility(deckId: deckId, isPublic: isMarketPublic)
            Task {
                try? await SupabaseManager.shared.setMarketVisibility(shareCode: code, isPublic: isMarketPublic)
            }
        }
        initialName = name
        initialDescription = description
        initialFrontLabel = frontLabel
        initialBackLabel = backLabel
        initialFrontLanguage = frontLanguage
        initialBackLanguage = backLanguage
        initialDifficultyLevel = difficultyLevel
        initialMarketPublic = isMarketPublic
    }

    private func deletePermanentlyFromMarket(code: String) async {
        do {
            try await SupabaseManager.shared.deleteFromMarket(shareCode: code)
            await MainActor.run {
                store.removeDeckShareCode(deckId: deckId)
                #if canImport(UIKit)
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
                #endif
                self.showDeletePermanentlySuccessAlert = true
            }
        } catch {
            await MainActor.run {
                self.marketActionErrorMessage = error.localizedDescription
                self.showMarketErrorAlert = true
            }
        }
    }

    private func checkForUpdates(code: String) async {
        isCheckingUpdates = true
        do {
            if let remote = try await SupabaseManager.shared.fetchByCode(code) {
                await MainActor.run {
                    self.isCheckingUpdates = false
                    self.syncRemoteDeck = remote
                    if let diff = store.calculateSyncDiff(deckId: deckId, remoteDeck: remote) {
                        if diff.hasChanges {
                            self.showSyncSheet = true
                        } else {
                            self.showUpToDateAlert = true
                        }
                    } else {
                        self.showUpToDateAlert = true
                    }
                }
            } else {
                await MainActor.run {
                    self.isCheckingUpdates = false
                    self.marketActionErrorMessage = "Deck not found on Community."
                    self.showMarketErrorAlert = true
                }
            }
        } catch {
            await MainActor.run {
                self.isCheckingUpdates = false
                self.marketActionErrorMessage = error.localizedDescription
                self.showMarketErrorAlert = true
            }
        }
    }
}

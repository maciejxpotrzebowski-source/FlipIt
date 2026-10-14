import SwiftUI

struct PublishDeckSheet: View {
    @ObservedObject var store: FlipItStore
    let deck: Deck
    var onPublished: ((SharedDeck) -> Void)? = nil
    
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject var authManager: AuthManager = .shared
    
    @State private var authorName: String = ""
    @State private var isPublic: Bool = true
    @State private var isPublishing: Bool = false
    @State private var publishingStatus: String = "Publishing..."
    @State private var publishedDeck: SharedDeck? = nil
    @State private var errorMessage: String? = nil
    @State private var showError: Bool = false
    @State private var showAuthSheet: Bool = false
    
    var body: some View {
        NavigationStack {
            Group {
                if !authManager.isAuthenticated {
                    authRequiredView
                } else if let shared = publishedDeck {
                    successView(sharedDeck: shared)
                } else {
                    publishForm
                }
            }
            .navigationTitle(
                LocalizedStringKey(
                    publishedDeck == nil
                        ? ((deck.shareCode != nil && deck.isMarketAuthor) ? "Update Community Deck" : "Publish Deck")
                        : "Deck Published!"
                )
            )
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isPublishing)
            .toolbar {
                if publishedDeck == nil {
                    ToolbarItem(placement: .platformTrailing) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .disabled(isPublishing)
                    }
                }
            }
            .alert("Error Publishing Deck", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
            .onAppear {
                if deck.isMarketAuthor && deck.shareCode != nil {
                    isPublic = deck.isMarketPublic
                }
                if authorName.isEmpty, let username = authManager.username {
                    authorName = username
                }
            }
        }
    }
    
    private var publishForm: some View {
        Form {
            Section("Deck Info") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(deck.name)
                        .font(.headline)
                        .bold()
                    
                    if !deck.description.isEmpty {
                        Text(deck.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "rectangle.stack")
                        Text("\(deck.cards.count) flashcards")
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    
                    if !deck.frontLanguage.isEmpty || !deck.backLanguage.isEmpty {
                        HStack {
                            Image(systemName: "globe")
                            Text("\(deck.frontLanguage) → \(deck.backLanguage)")
                        }
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    }

                    if let level = deck.difficultyLevel, !level.isEmpty {
                        HStack {
                            Image(systemName: "graduationcap.fill")
                            Text("Level: \(level)")
                        }
                        .font(.footnote)
                        .foregroundColor(.purple)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section {
                if let username = authManager.username, !username.isEmpty {
                    HStack {
                        Text("Handle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("@\(username)")
                            .font(.headline)
                            .foregroundStyle(Color.blue)
                    }
                }
                TextField("Display name (optional)", text: $authorName)
            } header: {
                Text("Author")
            } footer: {
                Text(authManager.username != nil ? "Your deck will be published under your account." : "Leave empty for 'Anonymous'")
            }
            
            Section {
                Toggle("Public", isOn: $isPublic)
            } header: {
                Text("Visibility")
            } footer: {
                Text(isPublic ? "Public = visible on market for everyone." : "Private = only accessible via 8-character code.")
            }
            
            Section {
                Button(action: {
                    Task {
                        await publishDeck()
                    }
                }) {
                    HStack {
                        Spacer()
                        if isPublishing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text(publishingStatus)
                                    .font(.subheadline)
                                    .bold()
                            }
                        } else {
                            Text(LocalizedStringKey((deck.shareCode != nil && deck.isMarketAuthor) ? "Update in Community" : "Publish to Community"))
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(deck.cards.isEmpty || isPublishing)
                .listRowBackground(deck.cards.isEmpty || isPublishing ? Color.secondary.opacity(0.2) : Color.green)
                .foregroundColor(deck.cards.isEmpty || isPublishing ? .secondary : .white)
            }
        }
    }
    
    private func successView(sharedDeck: SharedDeck) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(.green)
            
            Text("Deck Published!")
                .font(.title)
                .bold()
            
            VStack(spacing: 8) {
                Text(sharedDeck.formattedCode)
                    .font(.system(size: 40, design: .monospaced))
                    .bold()
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                
                Button(action: {
                    UIPasteboard.general.string = sharedDeck.shareCode
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Code")
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(20)
                }

                // AI Tags & CEFR Level
                if let level = sharedDeck.displayLevel {
                    Text("CEFR Level: \(level)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(Color.purple)
                        .clipShape(Capsule())
                        .padding(.top, 4)
                }

                if !sharedDeck.tags.isEmpty {
                    Text(sharedDeck.tags.map { "#\($0)" }.joined(separator: "  "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            
            Text("Share this code with others")
                .font(.headline)
            
            Text(isPublic ? "Your deck is now visible on the Deck Market" : "Others can find your deck by entering this code")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
    
    private func publishDeck() async {
        isPublishing = true
        errorMessage = nil
        publishingStatus = "Publishing..."
        
        defer {
            isPublishing = false
        }
        
        let author = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalAuthor = author.isEmpty ? "Anonymous" : author
        
        // Tagi oraz poziom CEFR generowane w tle
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
            isPublic: isPublic,
            authorName: finalAuthor,
            tags: analysis.tags,
            difficultyLevel: analysis.level,
            authorId: authManager.currentUserId
        )
        
        do {
            let result: SharedDeck
            if let existingCode = deck.shareCode, deck.isMarketAuthor {
                result = try await SupabaseManager.shared.updateMarketDeck(shareCode: existingCode, upload: upload)
            } else {
                result = try await SupabaseManager.shared.publishDeck(upload)
            }
            
            await MainActor.run {
                self.publishedDeck = result
                store.updateDeckShareCode(deckId: deck.id, shareCode: result.shareCode, isMarketAuthor: true, isMarketPublic: isPublic)
                onPublished?(result)
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
    
    private var authRequiredView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.blue)
                    .padding(.top, 24)
                
                VStack(spacing: 8) {
                    Text("Sign In to Publish Decks")
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Publishing decks to the Community requires a FlipIt account so others can discover your decks under your @username.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                }
                
                VStack(alignment: .leading, spacing: 14) {
                    Label("Publish under your unique @username", systemImage: "at")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Edit and update decks after sharing", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Label("Community downloads & retention stats", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSecondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)
                
                Button(action: {
                    showAuthSheet = true
                }) {
                    HStack {
                        Image(systemName: "person.fill.badge.plus")
                        Text("Sign In to FlipIt")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(Color.appGroupedBackground)
        .sheet(isPresented: $showAuthSheet) {
            AuthPromptSheet(authManager: authManager, canSkip: false)
        }
    }
}

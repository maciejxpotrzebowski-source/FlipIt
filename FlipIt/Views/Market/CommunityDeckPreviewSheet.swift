import SwiftUI

struct CommunityDeckPreviewSheet: View {
    let deckSummary: SharedDeck
    let relation: DeckMarketUserRelation
    let onImport: (SharedDeck) -> Void
    let onManage: (Deck) -> Void
    let onSync: (Deck, SharedDeck) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var fullDeck: SharedDeck? = nil
    @State private var isLoadingCards = false
    @State private var errorMessage: String? = nil

    var currentDeck: SharedDeck {
        fullDeck ?? deckSummary
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appGroupedBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Karta nagłówka
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(currentDeck.title)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundStyle(Color.primary)

                                            if let level = currentDeck.displayLevel {
                                                Text(level)
                                                    .font(.caption)
                                                    .fontWeight(.bold)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 3)
                                                    .background(Color.purple.opacity(0.15))
                                                    .foregroundStyle(Color.purple)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                        }

                                        if !currentDeck.authorName.isEmpty {
                                            Text("by \(currentDeck.authorName)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    Spacer()

                                    if currentDeck.isOfficial {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.seal.fill")
                                            Text("Official")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(8)
                                    } else if currentDeck.isArchived {
                                        HStack(spacing: 4) {
                                            Image(systemName: "archivebox.fill")
                                            Text("Archived")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(Color.orange)
                                        .cornerRadius(8)
                                    }
                                }

                                if !currentDeck.description.isEmpty {
                                    Text(currentDeck.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                // Tagi AI
                                if !currentDeck.tags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(currentDeck.tags, id: \.self) { tag in
                                                Text("#\(tag)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.primary.opacity(0.06))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }

                                Divider()

                                // Wiersz statystyk
                                HStack(spacing: 16) {
                                    if !currentDeck.frontLanguage.isEmpty {
                                        Text("\(flagEmoji(for: currentDeck.frontLanguage)) → \(flagEmoji(for: currentDeck.backLanguage))")
                                            .font(.caption)
                                    }

                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text")
                                        Text("\(currentDeck.cardsCount) cards")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.down.circle")
                                        Text("\(currentDeck.downloadsCount) downloads")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                    if let returnRate = currentDeck.returnRatePercentage {
                                        HStack(spacing: 2) {
                                            Image(systemName: "flame.fill")
                                                .foregroundStyle(.orange)
                                            Text("\(returnRate)% return")
                                        }
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    }
                                }

                                if !currentDeck.shareCode.isEmpty {
                                    HStack(spacing: 8) {
                                        Text("Code: \(currentDeck.formattedCode)")
                                            .font(.caption.monospaced())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.primary.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))

                                        Button(action: {
                                            #if canImport(UIKit)
                                            UIPasteboard.general.string = currentDeck.shareCode
                                            let generator = UINotificationFeedbackGenerator()
                                            generator.notificationOccurred(.success)
                                            #endif
                                        }) {
                                            Image(systemName: "doc.on.doc")
                                                .font(.caption)
                                                .foregroundStyle(Color.blue)
                                                .frame(minWidth: 28, minHeight: 28)
                                        }
                                        .accessibilityLabel("Copy share code")
                                    }
                                }
                            }
                            .padding(16)
                            .background(Color.appSecondaryGroupedBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                            if currentDeck.isArchived {
                                HStack(spacing: 10) {
                                    Image(systemName: "archivebox.fill")
                                        .font(.title3)
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Archived Community Deck")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.orange)
                                        Text("The author removed this deck from their device. It remains available for download, but will not receive future updates.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            // Status Banner based on user relation
                            switch relation {
                            case .myDeck:
                                HStack(spacing: 10) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Your Published Deck")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.blue)
                                        Text("You are the author of this deck. You can manage and update it directly from your library.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            case .downloaded(let localDeck, let hasUpdate):
                                if hasUpdate {
                                    HStack(spacing: 10) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.title3)
                                            .foregroundColor(.marketUpdateYellowOrange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Update Available")
                                                .font(.subheadline.bold())
                                                .foregroundColor(.marketUpdateYellowOrange)
                                            Text("The author published changes to this deck. Tap 'Sync Update' below to review.")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.marketUpdateYellowOrange.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    HStack(spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.green)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Already in Your Library")
                                                .font(.subheadline.bold())
                                                .foregroundColor(.primary)
                                            Text("You already have this deck downloaded and up to date.")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }

                            case .notDownloaded:
                                EmptyView()
                            }

                            // Nagłówek sekcji fiszek
                            HStack {
                                Text("Flashcards Preview")
                                    .font(.headline)
                                    .fontWeight(.bold)

                                Spacer()

                                Text("\(currentDeck.cardsPayload.count) of \(currentDeck.cardsCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)

                            // Lista fiszek w zestawie
                            if isLoadingCards {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        ProgressView()
                                        Text("Loading flashcards...")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 40)
                                    Spacer()
                                }
                            } else if let error = errorMessage {
                                VStack(spacing: 12) {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                    Button("Retry") {
                                        loadCards()
                                    }
                                    .font(.caption.bold())
                                }
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                            } else if currentDeck.cardsPayload.isEmpty {
                                ContentUnavailableView(
                                    "No cards",
                                    systemImage: "rectangle.stack.badge.minus",
                                    description: Text("This deck contains no flashcards.")
                                )
                                .padding(.vertical, 30)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(Array(currentDeck.cardsPayload.enumerated()), id: \.offset) { index, card in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("\(index + 1)")
                                                .font(.caption2.bold())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 22, alignment: .leading)
                                                .padding(.top, 2)

                                            VStack(alignment: .leading, spacing: 4) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(currentDeck.frontLabel)
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundStyle(Color.secondary)
                                                    Text(card.front)
                                                        .font(.body)
                                                        .fontWeight(.medium)
                                                        .foregroundStyle(Color.primary)
                                                }

                                                if !card.back.isEmpty {
                                                    Divider().padding(.vertical, 2)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(currentDeck.backLabel)
                                                            .font(.system(size: 10, weight: .semibold))
                                                            .foregroundStyle(Color.secondary)
                                                        Text(card.back)
                                                            .font(.subheadline)
                                                            .foregroundStyle(.secondary)
                                                    }
                                                }
                                            }
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color.appSecondaryGroupedBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }

                    // Pinned Bottom Action Bar
                    VStack(spacing: 0) {
                        switch relation {
                        case .myDeck(let localDeck):
                            Button(action: {
                                onManage(localDeck)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Manage Deck in Library")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                            }

                        case .downloaded(let localDeck, let hasUpdate):
                            if hasUpdate {
                                Button(action: {
                                    onSync(localDeck, currentDeck)
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Sync Update")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.marketUpdateYellowOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .shadow(color: Color.marketUpdateYellowOrange.opacity(0.3), radius: 6, x: 0, y: 3)
                                }
                            } else {
                                HStack(spacing: 12) {
                                    Button(action: {
                                        onManage(localDeck)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "slider.horizontal.3")
                                            Text("Open in Library")
                                        }
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(Color.blue.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }

                                    Button(action: {
                                        onImport(currentDeck)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.down.circle")
                                            Text("Re-import Copy")
                                        }
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(Color.secondary.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    }
                                }
                            }

                        case .notDownloaded:
                            Button(action: {
                                onImport(currentDeck)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("Import Deck (\(currentDeck.cardsCount) cards)")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    LinearGradient(
                                        colors: [Color.green, Color.green.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.green.opacity(0.3), radius: 6, x: 0, y: 3)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea(edges: .bottom)
                    )
                }
            }
            .navigationTitle("Deck Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                loadCards()
            }
        }
    }

    private func loadCards() {
        if !deckSummary.cardsPayload.isEmpty {
            return
        }
        isLoadingCards = true
        errorMessage = nil
        Task {
            do {
                let full = try await SupabaseManager.shared.fetchFullDeck(id: deckSummary.id)
                await MainActor.run {
                    self.fullDeck = full
                    self.isLoadingCards = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load cards: \(error.localizedDescription)"
                    self.isLoadingCards = false
                }
            }
        }
    }
}

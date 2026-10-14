import SwiftUI

struct DeckMarketRowView: View {
    let deck: SharedDeck
    let relation: DeckMarketUserRelation
    var isDownloading: Bool = false
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onManage: (Deck) -> Void
    let onSync: (Deck, SharedDeck) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(deck.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(2)

                        if let level = deck.displayLevel {
                            Text(level)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .foregroundStyle(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    if !deck.description.isEmpty {
                        Text(deck.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if deck.isOfficial {
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
                } else if deck.isArchived {
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
            
            // AI Tags
            if !deck.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(deck.tags.prefix(4), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            
            HStack(spacing: 16) {
                // Languages
                if !deck.frontLanguage.isEmpty {
                    Text("\(flagEmoji(for: deck.frontLanguage)) → \(flagEmoji(for: deck.backLanguage))")
                        .font(.caption)
                }
                
                // Cards count
                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                    Text("\(deck.cardsCount) cards")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Downloads
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                    Text("\(deck.downloadsCount) downloads")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            HStack(spacing: 8) {
                if !deck.shareCode.isEmpty {
                    Text(deck.formattedCode)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }

                if let returnRate = deck.returnRatePercentage {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(returnRate)% return")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 2) {
                    Image(systemName: "brain")
                        .foregroundStyle(.purple)
                    if deck.avgReviewsPerUser > 0 {
                        Text(String(format: NSLocalizedString("Avg. %.1f rev.", comment: ""), deck.avgReviewsPerUser))
                    } else {
                        Text("New")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                
                Spacer()
                
                switch relation {
                case .myDeck(let localDeck):
                    Button(action: {
                        onManage(localDeck)
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: "person.crop.circle.fill")
                            Text("Your Deck")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }

                case .downloaded(let localDeck, let hasUpdate):
                    if hasUpdate {
                        Button(action: {
                            onSync(localDeck, deck)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync")
                                    .fontWeight(.semibold)
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Color.marketUpdateYellowOrange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Downloaded")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.secondary.opacity(0.12))
                        .foregroundColor(.secondary)
                        .cornerRadius(8)
                    }

                case .notDownloaded:
                    Button(action: onDownload) {
                        HStack(spacing: 4) {
                            if isDownloading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text("Download")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(isDownloading)
                }
            }
        }
        .padding()
        .background(Color.appSecondaryGroupedBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

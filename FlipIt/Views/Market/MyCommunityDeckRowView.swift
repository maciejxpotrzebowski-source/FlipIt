import SwiftUI

struct MyCommunityDeckRowView: View {
    let deck: Deck
    var isUpdating: Bool = false
    var isCheckingUpdates: Bool = false
    let onSelect: () -> Void
    let onUpdateInCommunity: () -> Void
    let onRemoveFromCommunity: () -> Void
    let onCheckForUpdates: () -> Void
    let onSyncUpdate: () -> Void
    var onToggleVisibility: (() -> Void)? = nil
    var onDeletePermanently: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Title + Level + Origin Badge
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(deck.name)
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(2)

                        if let level = deck.difficultyLevel, !level.isEmpty {
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

                // Badge
                if deck.isMarketAuthor {
                    HStack(spacing: 4) {
                        Image(systemName: deck.isMarketPublic ? "globe" : "person.2")
                        Text(deck.isMarketPublic ? "Public" : "Private")
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(Color.blue)
                    .clipShape(Capsule())
                } else {
                    if deck.hasPendingMarketUpdate {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Update Available")
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.marketUpdateYellowOrange.opacity(0.15))
                        .foregroundColor(Color.marketUpdateYellowOrange)
                        .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Up to Date")
                        }
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(Color.green)
                        .clipShape(Capsule())
                    }
                }
            }

            // Languages & Card count
            HStack(spacing: 16) {
                if !deck.frontLanguage.isEmpty {
                    Text("\(flagEmoji(for: deck.frontLanguage)) → \(flagEmoji(for: deck.backLanguage))")
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    Image(systemName: "doc.text")
                    Text("\(deck.cards.count) cards")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                if let code = deck.shareCode {
                    let formatted = code.count == 8 ? "\(code.prefix(4))-\(code.suffix(4))" : code
                    HStack(spacing: 4) {
                        Text(formatted)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)

                        Button(action: {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = code
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption2)
                                .foregroundColor(.blue)
                                .frame(minWidth: 28, minHeight: 28)
                        }
                        .accessibilityLabel("Copy share code")
                    }
                }

                Spacer()
            }

            Divider()

            // Bottom Actions Bar
            HStack(spacing: 10) {
                if deck.isMarketAuthor {
                    if deck.isMarketPublic {
                        // Przycisk aktualizacji na giełdzie
                        Button(action: onUpdateInCommunity) {
                            HStack(spacing: 5) {
                                if isUpdating {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "arrow.clockwise.icloud")
                                }
                                Text(isUpdating ? "Updating..." : "Update in Community")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isUpdating)
                    } else {
                        // Przycisk wznawiania publikacji (gdy jest wycofana / prywatna)
                        Button(action: {
                            onToggleVisibility?()
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "globe")
                                Text("Publish to Community")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                } else {
                    if deck.hasPendingMarketUpdate {
                        // Przycisk synchronizacji aktualizacji
                        Button(action: onSyncUpdate) {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Sync Update")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.marketUpdateYellowOrange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    } else {
                        // Sprawdź czy są aktualizacje
                        Button(action: onCheckForUpdates) {
                            HStack(spacing: 5) {
                                if isCheckingUpdates {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text("Check Updates")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundColor(Color.accentColor)
                            .cornerRadius(8)
                        }
                        .disabled(isCheckingUpdates)
                    }
                }

                Spacer()

                // Przycisk zarządzania (przejście do edycji talii / Deck Manager)
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Manage")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                }

                // Menu dodatkowych opcji (np. usunięcie z community)
                Menu {
                    if let code = deck.shareCode {
                        Button(action: {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = code
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                            #endif
                        }) {
                            Label(String(format: NSLocalizedString("Copy Code (%@)", comment: ""), code), systemImage: "doc.on.doc")
                        }
                    }

                    Button(action: onSelect) {
                        Label("Open in Deck Manager", systemImage: "slider.horizontal.3")
                    }

                    if deck.isMarketAuthor {
                        if let onToggle = onToggleVisibility {
                            Button(action: onToggle) {
                                Label(
                                    deck.isMarketPublic ? "Make Private (Unlisted)" : "Make Public in Community",
                                    systemImage: deck.isMarketPublic ? "person.2" : "globe"
                                )
                            }
                        }
                    }

                    Divider()

                    if deck.isMarketAuthor {
                        if let onDelete = onDeletePermanently {
                            Button(role: .destructive, action: onDelete) {
                                Label("Delete from Community", systemImage: "trash")
                            }
                        }
                    } else {
                        Button(role: .destructive, action: onRemoveFromCommunity) {
                            Label("Unlink from Community", systemImage: "link.badge.plus")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
        }
        .padding(14)
        .background(Color.appSecondaryGroupedBackground)
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}

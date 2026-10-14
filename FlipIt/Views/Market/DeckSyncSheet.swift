import SwiftUI

struct DeckSyncSheet: View {
    @ObservedObject var store: FlipItStore
    let deck: Deck
    let remoteDeck: SharedDeck

    @Environment(\.dismiss) var dismiss

    enum SyncFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case userModified = "Edited"
        case authorUpdated = "Updated"
        case added = "New"
        case deleted = "Removed"

        var id: String { rawValue }
    }

    @State private var userModifiedItems: [FlipItStore.SyncCardItem] = []
    @State private var authorUpdatedItems: [FlipItStore.SyncCardItem] = []
    @State private var addedItems: [FlipItStore.SyncCardItem] = []
    @State private var deletedItems: [FlipItStore.SyncCardItem] = []
    @State private var unchangedCount: Int = 0
    @State private var userAddedCardsCount: Int = 0
    @State private var selectedFilter: SyncFilter = .all
    @State private var isSyncing: Bool = false
    @State private var isLoaded: Bool = false

    private var totalChangesCount: Int {
        userModifiedItems.count + authorUpdatedItems.count + addedItems.count + deletedItems.count
    }

    private var selectedChangesCount: Int {
        userModifiedItems.filter { $0.isSelected }.count +
        authorUpdatedItems.filter { $0.isSelected }.count +
        addedItems.filter { $0.isSelected }.count +
        deletedItems.filter { $0.isSelected }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Header
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 56, height: 56)
                            .foregroundStyle(Color.marketUpdateYellowOrange)

                        Text("Community Update Available")
                            .font(.title2)
                            .bold()
                            .fixedSize(horizontal: false, vertical: true)

                        Text("The author has published an update for '\(deck.name)'. Your study progress and Leitner boxes are completely safe.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Review the changes below before updating.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                // Filtry zmian (Pigułki z liczbą zmian)
                if totalChangesCount > 0 {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterPill(
                                    title: "All (\(totalChangesCount))",
                                    filter: .all,
                                    color: Color.primary
                                )

                                if !userModifiedItems.isEmpty {
                                    filterPill(
                                        title: "Edited (\(userModifiedItems.count))",
                                        filter: .userModified,
                                        color: Color.marketUpdateYellowOrange
                                    )
                                }

                                if !authorUpdatedItems.isEmpty {
                                    filterPill(
                                        title: "Updated (\(authorUpdatedItems.count))",
                                        filter: .authorUpdated,
                                        color: Color.blue
                                    )
                                }

                                if !addedItems.isEmpty {
                                    filterPill(
                                        title: "New (\(addedItems.count))",
                                        filter: .added,
                                        color: Color.green
                                    )
                                }

                                if !deletedItems.isEmpty {
                                    filterPill(
                                        title: "Removed (\(deletedItems.count))",
                                        filter: .deleted,
                                        color: Color.red
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                // Bezpieczne fiszki dodane przez użytkownika
                if userAddedCardsCount > 0 {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundStyle(Color.green)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Custom flashcards added by you are preserved (\(userAddedCardsCount))")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // SEKCJA 1: ŻÓŁTA — Fiszki edytowane przez użytkownika (domyślnie odznaczone)
                if !userModifiedItems.isEmpty && (selectedFilter == .all || selectedFilter == .userModified) {
                    Section {
                        ForEach($userModifiedItems) { $item in
                            syncRow(
                                item: $item,
                                accentColor: Color.marketUpdateYellowOrange,
                                previousVersion: item.oldBack,
                                isUserVersion: true
                            )
                        }
                    } header: {
                        sectionHeader(
                            title: "Cards edited by you (\(userModifiedItems.count))",
                            icon: "exclamationmark.triangle.fill",
                            color: Color.marketUpdateYellowOrange,
                            items: $userModifiedItems
                        )
                    } footer: {
                        Text("Default: unchecked to protect your changes. Check to overwrite.")
                            .font(.caption)
                    }
                }

                // SEKCJA 2: NIEBIESKA — Aktualizacje autora (domyślnie zaznaczone)
                if !authorUpdatedItems.isEmpty && (selectedFilter == .all || selectedFilter == .authorUpdated) {
                    Section {
                        ForEach($authorUpdatedItems) { $item in
                            syncRow(
                                item: $item,
                                accentColor: Color.blue,
                                previousVersion: item.oldBack,
                                isUserVersion: false
                            )
                        }
                    } header: {
                        sectionHeader(
                            title: "Author updates (\(authorUpdatedItems.count))",
                            icon: "pencil.circle.fill",
                            color: Color.blue,
                            items: $authorUpdatedItems
                        )
                    } footer: {
                        Text("Default: checked to receive author improvements.")
                            .font(.caption)
                    }
                }

                // SEKCJA 3: ZIELONA — Nowe fiszki dodane przez autora (domyślnie zaznaczone)
                if !addedItems.isEmpty && (selectedFilter == .all || selectedFilter == .added) {
                    Section {
                        ForEach($addedItems) { $item in
                            syncRow(
                                item: $item,
                                accentColor: Color.green,
                                badgeText: "New card from author"
                            )
                        }
                    } header: {
                        sectionHeader(
                            title: "New flashcards (\(addedItems.count))",
                            icon: "plus.circle.fill",
                            color: Color.green,
                            items: $addedItems
                        )
                    } footer: {
                        Text("Default: checked to add to your deck.")
                            .font(.caption)
                    }
                }

                // SEKCJA 4: CZERWONA — Fiszki usunięte przez autora (domyślnie odznaczone)
                if !deletedItems.isEmpty && (selectedFilter == .all || selectedFilter == .deleted) {
                    Section {
                        ForEach($deletedItems) { $item in
                            syncRow(
                                item: $item,
                                accentColor: Color.red,
                                badgeText: "Removed from community deck"
                            )
                        }
                    } header: {
                        sectionHeader(
                            title: "Removed by author (\(deletedItems.count))",
                            icon: "trash.circle.fill",
                            color: Color.red,
                            items: $deletedItems
                        )
                    } footer: {
                        Text("Default: unchecked to keep cards in your deck. Check to remove.")
                            .font(.caption)
                    }
                }

                // Karty bez zmian
                if unchangedCount > 0 {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.secondary)
                                .font(.title3)

                            Text("\(unchangedCount) cards unchanged")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Przyciski akcji
                Section {
                    Button(action: applySync) {
                        HStack {
                            Spacer()
                            if isSyncing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Apply Selected Changes (\(selectedChangesCount))")
                                    .bold()
                            }
                            Spacer()
                        }
                    }
                    .disabled(isSyncing)
                    .listRowBackground(Color.blue)
                    .foregroundColor(.white)
                }

                Section {
                    Button(role: .destructive, action: dismissUpdate) {
                        HStack {
                            Spacer()
                            Text("Dismiss Update (Keep Current Version)")
                                .font(.subheadline)
                            Spacer()
                        }
                    }
                    .disabled(isSyncing)
                } footer: {
                    Text("The update indicator will disappear until the author publishes a newer version.")
                }
            }
            .navigationTitle("Deck Update")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSyncing)
                }
            }
            .onAppear {
                loadDiff()
            }
        }
    }

    // MARK: - Subviews & Helpers

    @ViewBuilder
    private func filterPill(title: LocalizedStringKey, filter: SyncFilter, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(selectedFilter == filter ? .bold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    selectedFilter == filter
                        ? color.opacity(0.18)
                        : Color.appSecondaryGroupedBackground
                )
                .foregroundStyle(selectedFilter == filter ? color : Color.secondary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(selectedFilter == filter ? color : Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sectionHeader(
        title: LocalizedStringKey,
        icon: String,
        color: Color,
        items: Binding<[FlipItStore.SyncCardItem]>
    ) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Spacer()

            let allSelected = items.wrappedValue.allSatisfy { $0.isSelected }
            Button(allSelected ? "Deselect All" : "Select All") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    let newValue = !allSelected
                    for i in 0..<items.wrappedValue.count {
                        items.wrappedValue[i].isSelected = newValue
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(Color.blue)
        }
    }

    @ViewBuilder
    private func syncRow(
        item: Binding<FlipItStore.SyncCardItem>,
        accentColor: Color,
        previousVersion: String? = nil,
        isUserVersion: Bool = false,
        badgeText: LocalizedStringKey? = nil
    ) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                item.wrappedValue.isSelected.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                // Checkbox
                Image(systemName: item.wrappedValue.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.wrappedValue.isSelected ? accentColor : Color.secondary.opacity(0.4))

                // Treść fiszki
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.wrappedValue.front)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primary)

                    if !item.wrappedValue.newBack.isEmpty {
                        Text(item.wrappedValue.newBack)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                    }

                    if let oldBack = previousVersion, !oldBack.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 11))
                            if isUserVersion {
                                Text("Your version: \(oldBack)")
                                    .font(.caption)
                            } else {
                                Text("Previous version: \(oldBack)")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let badge = badgeText {
                        HStack(spacing: 4) {
                            Image(systemName: item.wrappedValue.changeType == .authorDeleted ? "trash" : "plus")
                                .font(.system(size: 11))
                            Text(badge)
                                .font(.caption)
                        }
                        .foregroundStyle(accentColor.opacity(0.85))
                    }
                }

                Spacer()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadDiff() {
        guard !isLoaded else { return }
        if let diff = store.calculateSyncDiff(deckId: deck.id, remoteDeck: remoteDeck) {
            userModifiedItems = diff.userModifiedCards
            authorUpdatedItems = diff.authorUpdatedCards
            addedItems = diff.addedCards
            deletedItems = diff.deletedCards
            unchangedCount = diff.unchangedCount
            userAddedCardsCount = diff.userAddedCardsCount
            isLoaded = true
        }
    }

    private func applySync() {
        isSyncing = true
        store.applyCustomSync(
            deckId: deck.id,
            remoteDeck: remoteDeck,
            userModifiedItems: userModifiedItems,
            authorUpdatedItems: authorUpdatedItems,
            addedItems: addedItems,
            deletedItems: deletedItems
        )

        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isSyncing = false
            dismiss()
        }
    }

    private func dismissUpdate() {
        let version = remoteDeck.updatedAt ?? remoteDeck.createdAt ?? "\(remoteDeck.cardsCount)"
        store.dismissMarketUpdate(deckId: deck.id, remoteVersion: version)
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        dismiss()
    }
}

import SwiftUI

struct HomeView: View {
    @ObservedObject var store: FlipItStore

    init(store: FlipItStore) {
        self.store = store
    }

    // Obsługa widoków (Sheets)
    @State private var showAddCardSheet = false
    @State private var showSettings = false
    @State private var showNewDeckSheet = false
    @State private var showImportView = false
    @State private var showManageDecks = false
    @State private var showMoveCardsSheet = false
    @State private var showGenerateView = false
    @Environment(\.scenePhase) var scenePhase
    // Kopia zapasowa
    @State private var originalDecks: [Deck] = []

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. TŁO (Szare)
                Color.appGroupedBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(spacing: 10) {

                        // WŁAŚCIWA LISTA
                        List {
                            ForEach(Array(store.decks.enumerated()), id: \.element.id) { index, deck in
                                NavigationLink(destination: DeckDetailView(store: store, deck: deck)) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .top) {
                                            Text(deck.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text("\(deck.cards.filter { $0.isLearned }.count) / \(deck.cards.count)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }

                                        ProgressView(value: deck.progress)
                                            .tint(deck.progress == 1.0 ? .green : .blue)
                                            .scaleEffect(x: 1, y: 0.8, anchor: .center)

                                        if !deck.description.isEmpty {
                                            Text(deck.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                }
                                .listRowBackground(Color.appSecondaryGroupedBackground)
                                .listRowSeparatorTint(Color.gray.opacity(0.3))
                                .deleteDisabled(index == 0)
                                .moveDisabled(index == 0)
                            }
                            .onMove(perform: store.moveDeck)
                        }
                        .listStyle(.plain)
                        .background(Color.appSecondaryGroupedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 16)
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        // Lista rośnie dynamicznie, ale zostawiamy miejsce na dole dla przycisku
                        .padding(.bottom, 16)
                    }
                }
            }
            .navigationTitle("FlipIt")
            .navigationBarTitleDisplayMode(.large)


            // --- PRZYCISK START STUDYING ---
            .safeAreaInset(edge: .bottom) {
                if !showAddCardSheet && !showSettings && !showImportView {
                    NavigationLink(destination: StudySetupView(store: store)) {
                        Text("START STUDYING")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
                    }
                    .padding(.bottom, 10)
                }
            }

            // --- TOOLBAR (Przyciski zostają w systemowym pasku u góry) ---
            .toolbar {
                // PRAWA STRONA (TopBarTrailing) - Główne menu
                ToolbarItem(placement: .appTopBarTrailing) {
                                    HStack(spacing: 16) {
                                        // 1. ZĘBATKA (Niebieska) -> Settings / Manage Decks
                                        Menu {
                                            Button(action: { showSettings = true }) {
                                                Label("Settings", systemImage: "gear")
                                            }

                                            if !store.decks.isEmpty {
                                                Button(action: {
                                                    showManageDecks = true
                                                }) {
                                                    Label("Manage Decks", systemImage: "arrow.up.arrow.down")
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "gear")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.blue) // <--- Kolor niebieski
                                        }

                                        // 2. PLUS (Zielony) -> New Card / New Deck / Import
                                        Menu {
                                            Button(action: { showAddCardSheet = true }) {
                                                Label("New Card", systemImage: "rectangle.portrait.badge.plus")
                                            }
                                            Button(action: { showNewDeckSheet = true }) {
                                                Label("New Deck", systemImage: "folder.badge.plus")
                                            }
                                            Divider() // Separator dla czytelności

                                                                        // --- NOWA OPCJA: MOVE CARDS ---
                                            Button(action: { showMoveCardsSheet = true }) {
                                                Label("Move Cards", systemImage: "arrow.right.arrow.left.square")
                                            }
                                            Divider()
                                            Button(action: { showGenerateView = true }) {
                                                Label("Generate (AI)", systemImage: "sparkles")
                                            }

                                            Button(action: { showImportView = true }) {
                                                Label("Import", systemImage: "square.and.arrow.down")
                                            }
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundStyle(.green) // <--- Kolor zielony
                                        }
                                    }
                            }
                        }
            .sheet(isPresented: $showImportView) { ImportView(store: store).presentationDetents([.large]) }
            .sheet(isPresented: $showAddCardSheet) {
                AddCardSheet(store: store, isPresented: $showAddCardSheet, selectedDeckId: store.decks.first?.id ?? UUID())
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showNewDeckSheet) {
                            NewDeckSheet(store: store) { _ in }
                                .presentationDetents([.large])
                        }
            .sheet(isPresented: $showSettings) { SettingsView(store: store) }
            .sheet(isPresented: $showManageDecks) { ManageDecksView(store: store) }
            .sheet(isPresented: $showMoveCardsSheet) {
                            MoveCardsView(store: store) // Bez parametrów = puste/domyślne
                                .presentationDetents([.large])
                        }
            .sheet(isPresented: $showGenerateView) {
                    AIGenerateView(store: store)
                }
            .onOpenURL { url in
                            // Sprawdzamy, czy widget przysłał nam prośbę o dodanie karty
                            if url.absoluteString == "flipit://add_card" {
                                // Otwieramy arkusz dodawania karty
                                showAddCardSheet = true
                            }
                        }
        }
        .environment(\.locale, Locale(identifier: store.settings.appLanguage.rawValue))
        .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        store.reloadData()
                    }
                }
    }
}


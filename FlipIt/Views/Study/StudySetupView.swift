import SwiftUI

struct StudySetupView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    // Używamy store.settings bezpośrednio, aby Widget widział te zmiany
    @State private var startSession = false

    var areAllSelected: Bool {
        !store.decks.isEmpty && store.settings.usedDeckIDs.count == store.decks.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // --- 1. WYBÓR TALII ---
            List {
                Section(header: HStack {
                    Text("SELECT DECKS")
                    Spacer()
                    if !store.decks.isEmpty {
                        Button(action: toggleAllDecks) {
                            Text(areAllSelected ? "Deselect All" : "Select All")
                                .font(.caption).fontWeight(.bold)
                                .foregroundStyle(areAllSelected ? .red : .green)
                        }
                    }
                }) {}
            }
            .appInsetGroupedListStyle().scrollDisabled(true).frame(height: 40)

            // --- 2. LISTA TALII ---
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        if store.decks.isEmpty {
                            Text("No decks available").foregroundStyle(.secondary).padding()
                        } else {
                            ForEach(store.decks) { deck in
                                deckRow(deck: deck)
                                Divider().padding(.leading, 50)
                            }
                        }
                    }
                }
                .background(Color.appSecondaryGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
            }
            Spacer(minLength: 16)

            // --- 3. OPCJE (BEZPOŚREDNIO DO STORE) ---
            VStack(spacing: 0) {
                List {
                    Section(header: Text("OPTIONS")) {
                        // Podpięte pod store.settings!
                        Toggle("Only Unlearned Cards", isOn: $store.settings.onlyUnlearned)
                            .onChange(of: store.settings.onlyUnlearned) { store.saveData() }

                        HStack {
                            Text("Card Side")
                            Spacer()
                            Picker("Card Side", selection: $store.settings.studySide) {
                                ForEach(StudySideOption.allCases, id: \.self) { option in Text(option.rawValue).tag(option) }
                            }
                            .labelsHidden().tint(.secondary)
                            .onChange(of: store.settings.studySide) { store.saveData() }
                        }

                        HStack {
                            Text("Learning Pace")
                            Spacer()
                            Picker("Learning Pace", selection: $store.settings.learningFactorValue) {
                                ForEach(LearningFactor.allCases, id: \.self) { factor in
                                    Text(factor.label).tag(factor.rawValue)
                                }
                            }
                            .labelsHidden().tint(.secondary)
                            .onChange(of: store.settings.learningFactorValue) { store.saveData() }
                        }
                    }
                }
                .appInsetGroupedListStyle().scrollDisabled(true).frame(height: 230)

                Button(action: {
                    store.saveData() // Upewniamy się, że wszystko zapisane przed startem
                    startSession = true
                }) {
                    Text("START SESSION")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(store.settings.usedDeckIDs.isEmpty ? Color.gray : Color.green)
                        .cornerRadius(12)
                }
                .disabled(store.settings.usedDeckIDs.isEmpty)
                .padding(.horizontal, 16).padding(.bottom, 10)
            }
            .background(Color.appGroupedBackground)
        }
        .navigationTitle("Study Setup")
        .background(Color.appGroupedBackground)
        .navigationDestination(isPresented: $startSession) {
            // Przekazujemy parametry, choć StudySessionView mogłoby też brać je ze store
            StudySessionView(
                store: store,
                selectedDeckIds: Array(store.settings.usedDeckIDs),
                onlyUnlearned: store.settings.onlyUnlearned,
                studySide: store.settings.studySide,
                learningFactor: LearningFactor(rawValue: store.settings.learningFactorValue) ?? .standard
            )
        }
    }

    // Helpery
    private func toggleAllDecks() {
        withAnimation {
            if areAllSelected { store.settings.usedDeckIDs.removeAll() }
            else { store.settings.usedDeckIDs = Set(store.decks.map { $0.id }) }
            store.saveData()
        }
    }

    private func deckRow(deck: Deck) -> some View {
        HStack(spacing: 12) {
            Image(systemName: store.settings.usedDeckIDs.contains(deck.id) ? "checkmark.square.fill" : "square")
                .foregroundStyle(store.settings.usedDeckIDs.contains(deck.id) ? .blue : .gray.opacity(0.3))
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(deck.name).font(.headline)
                    Spacer()
                    Text("\(deck.cards.filter { $0.isLearned }.count) / \(deck.cards.count)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                ProgressView(value: deck.progress).tint(deck.progress == 1.0 ? .green : .blue)
            }
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture {
            if store.settings.usedDeckIDs.contains(deck.id) { store.settings.usedDeckIDs.remove(deck.id) }
            else { store.settings.usedDeckIDs.insert(deck.id) }
            store.saveData()
        }
    }
}


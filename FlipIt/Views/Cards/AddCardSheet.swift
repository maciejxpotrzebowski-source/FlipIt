import SwiftUI

struct AddCardSheet: View {
    @ObservedObject var store: FlipItStore
    @Binding var isPresented: Bool

    @State private var selectedDeckId: UUID
    @State private var front = ""
    @State private var back = ""
    @State private var showNewDeckSheet = false
    @State private var showDuplicateAlert = false
    @State private var pendingAction: () -> Void = {}

    init(store: FlipItStore, isPresented: Binding<Bool>, selectedDeckId: UUID) {
        self.store = store
        self._isPresented = isPresented
        self._selectedDeckId = State(initialValue: selectedDeckId)
    }

    var selectedDeck: Deck? {
        store.decks.first(where: { $0.id == selectedDeckId })
    }

    var currentDeckName: String {
        selectedDeck?.name ?? "Select Deck"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Selected Deck")) {
                    HStack(alignment: .center) {
                        Menu {
                            Picker("Deck", selection: $selectedDeckId) {
                                ForEach(store.decks) { deck in
                                    Text(deck.name).tag(deck.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(currentDeckName)
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.blue).lineLimit(1)
                                    .frame(minWidth: 80, maxWidth: 150)

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2).foregroundStyle(.blue)
                            }
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1)).clipShape(Capsule())
                        }

                        Spacer()

                        Button(action: { showNewDeckSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white).padding(6)
                                    .background(Color.blue).clipShape(Circle())
                                Text("New Deck").font(.subheadline).fontWeight(.medium).foregroundStyle(.blue)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
                }

                // --- SEKCJA FRONT ---
                // JEDNA SEKCJA DLA OBU STRON
                                Section(header:
                                    HStack {
                                        Text("New Card")
                                        Spacer()
                                        // Wyświetl ostrzeżenie, jeśli Front LUB Back jest za długi
                                    if front.count > AppLimits.widgetContent || back.count > AppLimits.widgetContent {
                                            Text("Card may be not displayed on the widget correctly")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                                .textCase(.none)
                                        }
                                    }
                                ) {
                                    // FRONT
                                    HStack(alignment: .top) {
                                        TextField(selectedDeck?.frontLabel ?? "Front", text: $front, axis: .vertical)
                                            .onChange(of: front) { if front.count > AppLimits.cardContent { front = String(front.prefix(AppLimits.cardContent)) } }
                                        Spacer()
                                        Text("\(front.count)/\(AppLimits.cardContent)")
                                            .font(.caption)
                                            .padding(.top, 4)
                                            .foregroundStyle(front.count >= AppLimits.cardContent ? .red.opacity(0.8) : (front.count > 40 ? .orange : .secondary))
                                    }

                                    // BACK
                                    HStack(alignment: .top) {
                                        TextField(selectedDeck?.backLabel ?? "Back", text: $back, axis: .vertical)
                                            .onChange(of: back) { if back.count > AppLimits.cardContent { back = String(back.prefix(AppLimits.cardContent)) } }
                                        Spacer()
                                        Text("\(back.count)/\(AppLimits.cardContent)")
                                            .font(.caption)
                                            .padding(.top, 4)
                                            .foregroundStyle(back.count >= AppLimits.cardContent ? .red.opacity(0.8) : (back.count > 40 ? .orange : .secondary))
                                    }
                                }
            }
            .navigationTitle("Add Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    HStack {
                        Button("Add next") {
                            validateAndSave(isNext: true)
                        }
                        .disabled(front.isEmpty || back.isEmpty)

                        Button("Add") {
                            validateAndSave(isNext: false)
                        }
                        .fontWeight(.bold)
                        .disabled(front.isEmpty || back.isEmpty)
                    }
                }
            }
            // Alert potwierdzający dodanie duplikatu
            .alert("Duplicate Found", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Add Anyway") {
                    pendingAction()
                }
            } message: {
                Text("A card with the same front or back already exists in this deck. Do you want to add it anyway?")
            }
            .sheet(isPresented: $showNewDeckSheet) {
                NewDeckSheet(store: store) { newId in
                    self.selectedDeckId = newId
                }
                .presentationDetents([.large])
            }
        }
    }

    // Pomocnicza funkcja zapisu
    private func saveCurrentCard() {
        store.addCard(to: selectedDeckId, front: front, back: back)
    }

    private func validateAndSave(isNext: Bool) {
        let trimmedFront = front.trimmingCharacters(in: .whitespaces)
        let trimmedBack = back.trimmingCharacters(in: .whitespaces)

        // Sprawdzenie czy w wybranym decku istnieje już taki sam Front lub Back
        let isDuplicate = selectedDeck?.cards.contains { card in
            card.front.localizedCaseInsensitiveCompare(trimmedFront) == .orderedSame ||
            card.back.localizedCaseInsensitiveCompare(trimmedBack) == .orderedSame
        } ?? false

        let action = {
            saveCurrentCard()
            if isNext {
                front = ""
                back = ""
            } else {
                isPresented = false
            }
        }

        if isDuplicate {
            pendingAction = action
            showDuplicateAlert = true
        } else {
            action()
        }
    }
}


import SwiftUI

struct CardRowView: View {
    // ZMIANA: Zwykła zmienna, nie @ObservedObject.
    // Naprawia błąd "Cannot call value of non-function type"
    var store: FlipItStore

    let card: Flashcard
    let deck: Deck

    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false
    @State private var showDiscardCardAlert = false
    @State private var tempFront = ""
    @State private var tempBack = ""

    private var hasCardChanges: Bool {
        tempFront != card.front || tempBack != card.back
    }

    private var badgeColor: Color {
        if card.isLearned {
            return .green
        } else if card.box >= 2 {
            return .blue
        } else if card.box == 1 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 32, height: 32)

                if card.isLearned {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(badgeColor)
                } else {
                    Text("\(card.streak)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(badgeColor)
                }
            }
            .frame(width: 40)

            VStack(alignment: .leading) {
                Text(card.front).font(.headline)
                Text(card.back).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()

            HStack(spacing: 15) {
                // Przycisk Edycji
                Button(action: {
                    tempFront = card.front
                    tempBack = card.back
                    showEditSheet = true
                }) {
                    Image(systemName: "pencil")
                        .foregroundStyle(.blue)
                        .font(.system(size: 20))
                }
                .buttonStyle(BorderlessButtonStyle())

                // Przycisk Usuwania
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                        .font(.system(size: 20))
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showEditSheet) {
            NavigationStack {
                Form {
                                    Section(header:
                                        HStack {
                                            Text("Card Content")
                                            Spacer()
                                            // Sprawdzamy oba pola naraz
                                        if tempFront.count > AppLimits.widgetContent || tempBack.count > AppLimits.widgetContent {
                                                Text("Card may be not displayed on the widget correctly")
                                                    .font(.caption2)
                                                    .foregroundStyle(.orange)
                                                    .textCase(.none)
                                            }
                                        }
                                    ) {
                                        // FRONT
                                        HStack(alignment: .top) {
                                            TextField(deck.frontLabel, text: $tempFront, axis: .vertical)
                                                .onChange(of: tempFront) { if tempFront.count > AppLimits.cardContent { tempFront = String(tempFront.prefix(AppLimits.cardContent)) } }
                                            Spacer()
                                            Text("\(tempFront.count)/\(AppLimits.cardContent)")
                                                .font(.caption)
                                                .padding(.top, 4)
                                                .foregroundStyle(tempFront.count >= AppLimits.cardContent ? .red.opacity(0.8) : (tempFront.count > 40 ? .orange : .secondary))
                                        }

                                        // BACK
                                        HStack(alignment: .top) {
                                            TextField(deck.backLabel, text: $tempBack, axis: .vertical)
                                                .onChange(of: tempBack) { if tempBack.count > AppLimits.cardContent { tempBack = String(tempBack.prefix(AppLimits.cardContent)) } }
                                            Spacer()
                                            Text("\(tempBack.count)/\(AppLimits.cardContent)")
                                                .font(.caption)
                                                .padding(.top, 4)
                                                .foregroundStyle(tempBack.count >= AppLimits.cardContent ? .red.opacity(0.8) : (tempBack.count > 40 ? .orange : .secondary))
                                        }
                                    }
                                }
                .navigationTitle("Edit Card")
                .interactiveDismissDisabled(hasCardChanges)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            if hasCardChanges {
                                showDiscardCardAlert = true
                            } else {
                                showEditSheet = false
                            }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.updateCardContent(deckId: deck.id, cardId: card.id, front: tempFront, back: tempBack)
                            showEditSheet = false
                        }
                    }
                }
                .alert("Discard Changes?", isPresented: $showDiscardCardAlert) {
                    Button("Keep Editing", role: .cancel) { }
                    Button("Discard Changes", role: .destructive) {
                        showEditSheet = false
                    }
                } message: {
                    Text("You have unsaved changes. Are you sure you want to discard them?")
                }
            }
            .presentationDetents([.medium])
        }
        .alert("Delete Card", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                 deleteCardNow()
            }
        } message: { Text("Are you sure you want to delete this card?") }
    }

    // Funkcja pomocnicza
    private func deleteCardNow() {
        withAnimation {
            store.deleteCard(deckId: deck.id, cardId: card.id)
        }
    }
}


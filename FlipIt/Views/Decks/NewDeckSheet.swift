import SwiftUI

struct NewDeckSheet: View {
    @Environment(\.dismiss) var dismiss
    var store: FlipItStore

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var frontLabel: String = ""
    @State private var backLabel: String = ""

    @State private var frontLanguage: String
    @State private var backLanguage: String
    @State private var difficultyLevel: String = ""
    @State private var showDuplicateAlert = false
    @State private var showDiscardAlert = false

    var hasUnsavedContent: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Callback do przekazania ID nowo utworzonego zestawu
    var onDeckCreated: ((UUID) -> Void)?

    init(store: FlipItStore, onDeckCreated: ((UUID) -> Void)? = nil) {
            self.store = store
            self.onDeckCreated = onDeckCreated
            _frontLanguage = State(initialValue: store.settings.defaultFrontLanguage)
            _backLanguage = State(initialValue: store.settings.defaultBackLanguage)
        }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Deck Info")) {
                    HStack {
                                            TextField("Deck Name", text: $name)
                                                .onChange(of: name) { if name.count > AppLimits.deckName { name = String(name.prefix(AppLimits.deckName)) } }
                                            Spacer()
                                            Text("\(name.count)/\(AppLimits.deckName)")
                                                .font(.caption)
                                                .foregroundStyle(name.count >= AppLimits.deckName ? .red.opacity(0.8) : .secondary)
                                        }
                    HStack(alignment: .top) {
                                            TextField("Description (optional)", text: $description, axis: .vertical)
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
                                            TextField("Label (e.g. Word)", text: $frontLabel)
                                                .onChange(of: frontLabel) { if frontLabel.count > AppLimits.label { frontLabel = String(frontLabel.prefix(AppLimits.label)) } }
                                            Spacer()
                                            Text("\(frontLabel.count)/\(AppLimits.label)")
                                                .font(.caption)
                                                .foregroundStyle(frontLabel.count >= AppLimits.label ? .red.opacity(0.8) : .secondary)
                                        }
                                    // Picker przesunięty do lewej, bez etykiety
                                    Picker("", selection: $frontLanguage) {
                                        ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                                            Text(LocalizedStringKey(value)).tag(key)
                                        }
                                    }
                                    .labelsHidden() // Ukrywa label "Language"
                                    .pickerStyle(.menu)
                                }
                Section(header: Text("Back Side")) {
                    HStack {
                                            TextField("Label (e.g. Definition)", text: $backLabel)
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
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                }
            }
            .navigationTitle("New Deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasUnsavedContent {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        checkForDuplicatesAndCreate()
                    }
                    .fontWeight(.bold)
                    .disabled(name.isEmpty)
                }
            }
            .interactiveDismissDisabled(hasUnsavedContent)
            // Alert pytający o potwierdzenie
            .alert("Deck Already Exists", isPresented: $showDuplicateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Create Anyway") {
                    createDeck()
                }
            } message: {
                Text("A deck with the name \"\(name)\" already exists. Do you want to create it anyway?")
            }
            .alert("Discard New Deck?", isPresented: $showDiscardAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) {
                    dismiss()
                }
            } message: {
                Text("The new deck has not been created. Are you sure you want to discard it?")
            }
        }
    }

    // Funkcja sprawdzająca duplikaty
    private func checkForDuplicatesAndCreate() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Sprawdzamy czy istnieje deck o tej samej nazwie (ignorując wielkość liter)
        let duplicateExists = store.decks.contains { existingDeck in
            existingDeck.name.trimmingCharacters(in: .whitespaces).localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }

        if duplicateExists {
            showDuplicateAlert = true
        } else {
            createDeck()
        }
    }

    // Właściwa logika tworzenia (wywoływana od razu lub po potwierdzeniu alertu)
    private func createDeck() {
        let createdDeck = store.addDeck(
            name: name,
            description: description,
            frontLabel: frontLabel,
            backLabel: backLabel,
            frontLanguage: frontLanguage,
            backLanguage: backLanguage,
            difficultyLevel: difficultyLevel.isEmpty ? nil : difficultyLevel
        )
        onDeckCreated?(createdDeck.id)
        dismiss()
    }
}


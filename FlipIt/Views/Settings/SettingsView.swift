import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    // Teraz operujemy bezpośrednio na store.settings, aby zmiany były natychmiastowe
    // i od razu widoczne w całej aplikacji/widgetach po zapisie.

    var body: some View {
        NavigationStack {
            Form {

                Section(header: Text("Default Languages")) {
                                    // 1. Język Aplikacji
                                    Picker("App Language", selection: $store.settings.appLanguage) {
                                        ForEach(AppLanguage.allCases, id: \.self) { lang in
                                            Text(lang.displayName).tag(lang)
                                        }
                                    }

                                    // 2. Domyślny język Frontu (dla nowych talii)
                                    Picker("Default Front Language", selection: $store.settings.defaultFrontLanguage) {
                                        ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                                            Text(value).tag(key)
                                        }
                                    }
                                    .appNavigationLinkPickerStyle()

                                    // 3. Domyślny język Tyłu (dla nowych talii)
                                    Picker("Default Back Language", selection: $store.settings.defaultBackLanguage) {
                                        ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                                            Text(value).tag(key)
                                        }
                                    }
                                    .appNavigationLinkPickerStyle()
                                }

                // --- NOWA SEKCJA WIDGET ---
                Section(header: Text("Widget")) {
                    Toggle("Colorful Buttons", isOn: $store.settings.widgetColorfulButtons)

                    Toggle("Inactivity Reminder (Color)", isOn: $store.settings.widgetInactivityColor)

                    if store.settings.widgetInactivityColor {
                        Text("When enabled, the widget background will turn red if you haven't studied for a few days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // --- SEKCJA PRO ---
                Section(header: Text("FlipIt Pro")) {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("FlipIt Pro Status")
                                    .font(.body)
                                Text(store.settings.isPremiumUser ? "Active (AI flashcards unlocked)" : "Free tier")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: store.settings.isPremiumUser ? "crown.fill" : "crown")
                                .foregroundStyle(store.settings.isPremiumUser ? .yellow : .secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $store.settings.isPremiumUser)
                            .labelsHidden()
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.saveData() // Zapisujemy zmiany
                        dismiss()
                    }
                }
            }
        }
    }
}


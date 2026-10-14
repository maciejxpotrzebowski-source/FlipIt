import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: FlipItStore
    @Environment(\.dismiss) var dismiss

    @State private var telemetryEventCount: Int = StudyTelemetryManager.shared.eventsCount()
    @State private var showClearTelemetryAlert: Bool = false
    @State private var originalSettings: AppSettings? = nil
    @State private var showAuthSheet: Bool = false
    @State private var showChangeUsernameSheet: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                UserProfileSection(
                    store: store,
                    onOpenAuth: { showAuthSheet = true },
                    onOpenChangeUsername: { showChangeUsernameSheet = true }
                )

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
                            Text(LocalizedStringKey(value)).tag(key)
                        }
                    }
                    .appNavigationLinkPickerStyle()

                    // 3. Domyślny język Tyłu (dla nowych talii)
                    Picker("Default Back Language", selection: $store.settings.defaultBackLanguage) {
                        ForEach(availableLanguages.sorted(by: { $0.value < $1.value }), id: \.key) { key, value in
                            Text(LocalizedStringKey(value)).tag(key)
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
                Section(
                    header: Text("FlipIt Pro"),
                    footer: Text("Choose the AI model for flashcard generation and deck analysis.")
                ) {
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
                                .foregroundStyle(store.settings.isPremiumUser ? Color.yellow : Color.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $store.settings.isPremiumUser)
                            .labelsHidden()
                    }

                    Picker("AI Model", selection: $store.settings.geminiModel) {
                        ForEach(GeminiModelOption.allCases) { model in
                            Text(LocalizedStringKey(model.displayName)).tag(model)
                        }
                    }
                    .appNavigationLinkPickerStyle()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Speed & Limit")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(LocalizedStringKey(store.settings.geminiModel.speedBadge))
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(store.settings.geminiModel.badgeColor.opacity(0.15))
                                .foregroundStyle(store.settings.geminiModel.badgeColor)
                                .clipShape(Capsule())
                        }
                        HStack {
                            Text("Free Daily Limit:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey(store.settings.geminiModel.dailyLimitText))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Est. 100 Cards:")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(LocalizedStringKey(store.settings.geminiModel.estimatedTime100Cards))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(.vertical, 2)
                }

                // --- SEKCJA UCZENIE I TELEMETRIA ---
                Section(
                    header: Text("Learning & Telemetry"),
                    footer: Text("Help calibrate FlipIt's adaptive algorithms. When enabled, strictly anonymous metrics (reaction times, streaks, difficulty transitions) are recorded. Flashcard text is NEVER collected.")
                ) {
                    Toggle("Improve Learning Algorithms", isOn: $store.settings.analyticsEnabled)

                    if store.settings.analyticsEnabled {
                        HStack {
                            Text("Recorded Events")
                            Spacer()
                            Text("\(telemetryEventCount)")
                                .foregroundStyle(.secondary)
                        }

                        if telemetryEventCount > 0 {
                            ShareLink(
                                item: StudyTelemetryManager.shared.exportJSON(),
                                preview: SharePreview("FlipIt Study Telemetry", image: Image(systemName: "chart.xyaxis.line"))
                            ) {
                                Label("Export Anonymous Logs", systemImage: "square.and.arrow.up")
                            }

                            Button(role: .destructive, action: { showClearTelemetryAlert = true }) {
                                Label("Clear Telemetry Logs", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .interactiveDismissDisabled(true)
            .onAppear {
                if originalSettings == nil {
                    originalSettings = store.settings
                }
            }
            .alert("Clear Telemetry Data", isPresented: $showClearTelemetryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    StudyTelemetryManager.shared.clearEvents()
                    telemetryEventCount = 0
                }
            } message: {
                Text("Are you sure you want to delete all locally recorded learning telemetry?")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let original = originalSettings {
                            store.settings = original
                        }
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.saveData() // Zapisujemy zmiany
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthPromptSheet(authManager: AuthManager.shared, canSkip: false)
            }
            .sheet(isPresented: $showChangeUsernameSheet) {
                ChangeUsernameSheet(authManager: AuthManager.shared)
            }
        }
    }
}

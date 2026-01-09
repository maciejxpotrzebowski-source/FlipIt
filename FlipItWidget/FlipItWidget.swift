//
//  FlipItWidget.swift
//  FlipItWidget
//

import WidgetKit
import SwiftUI
import AppIntents

struct SimpleEntry: TimelineEntry {
    let date: Date
    let card: Flashcard
    let isFlipped: Bool // Dodajemy stan widoku do Entry
}

struct Provider: AppIntentTimelineProvider {
    typealias Intent = EmptyWidgetConfigurationIntent

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), card: Flashcard(front: "Apple", back: "Jabłko"), isFlipped: false)
    }

    func snapshot(for configuration: Intent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), card: Flashcard(front: "Apple", back: "Jabłko"), isFlipped: false)
    }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SimpleEntry> {
        let entry = await MainActor.run {
            let store = FlipItStore()
            let settings = store.settings

            // 1. Przygotuj pulę kart zgodnie z ustawieniami
            let activeDecks = store.decks.filter { settings.usedDeckIDs.contains($0.id) }
            var candidateCards = activeDecks.flatMap { $0.cards }

            if settings.onlyUnlearned {
                candidateCards = candidateCards.filter { !$0.isLearned }
            }

            if candidateCards.isEmpty {
                // Fallback, gdy brak kart
                let msg = store.decks.isEmpty ? "Add Decks" : "All Learned!"
                return SimpleEntry(date: Date(), card: Flashcard(front: msg, back: "Check App"), isFlipped: false)
            }

            // 2. SPRAWDZAMY STAN ZAPISANY PRZEZ "FLIP CARD INTENT"
            let savedState = store.loadWidgetState()

            // Zmienne na wynik
            var finalCard: Flashcard
            var finalIsFlipped: Bool

            // CZY MAMY ZAPISANĄ KARTĘ I CZY ONA NADAL ISTNIEJE W PULI?
            if let state = savedState,
               let foundCard = candidateCards.first(where: { $0.id == state.currentCardId }) {

                // TAK -> Użytkownik kliknął FLIP. Pokazujemy TĘ SAMĄ kartę.
                finalCard = foundCard
                finalIsFlipped = state.isFlipped

            } else {
                // NIE -> Użytkownik kliknął MARK (state usunięty) lub to start. LOSUJEMY NOWĄ.

                // Algorytm losowania (ważony)
                let factor = settings.learningFactorValue
                let weightedItems = candidateCards.map { card -> (card: Flashcard, weight: Double) in
                    (card, 1.0 / (1.0 + (Double(card.streak) * factor)))
                }
                let totalWeight = weightedItems.reduce(0) { $0 + $1.weight }
                let randomVal = Double.random(in: 0..<totalWeight)
                var cursor = 0.0
                finalCard = candidateCards.first!

                for item in weightedItems {
                    cursor += item.weight
                    if cursor >= randomVal {
                        finalCard = item.card
                        break
                    }
                }

                // Ustal stronę początkową (dla nowej karty)
                switch settings.studySide {
                case .front: finalIsFlipped = false
                case .back: finalIsFlipped = true
                case .random: finalIsFlipped = Bool.random()
                }

                // ZAPISUJEMY NOWĄ KARTĘ DO STANU
                // Żeby kolejne kliknięcie "Flip" wiedziało, co obracać.
                store.saveWidgetState(cardId: finalCard.id, isFlipped: finalIsFlipped)
            }

            return SimpleEntry(date: Date(), card: finalCard, isFlipped: finalIsFlipped)
        }

        return Timeline(entries: [entry], policy: .never)
    }
}
// ... (EmptyWidgetConfigurationIntent bez zmian) ...
struct EmptyWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description: LocalizedStringResource = "FlipIt Widget Configuration"
}

struct FlipItWidgetEntryView : View {
    var entry: Provider.Entry

    // Obliczamy kolor tła na podstawie bezczynności
    var backgroundColor: Color {
        // Musimy pobrać ustawienia ze sklepu (można by je przekazywać w Entry, ale tu odczytamy bezpośrednio)
        // W prawdziwej produkcji lepiej przekazać settings w SimpleEntry.
        // Tutaj dla uproszczenia zrobimy szybki odczyt, bo to View.
        // UWAGA: View w Widgetcie jest statyczne, więc lepiej by było mieć to w Entry.
        // Zróbmy to "po bożemu": Pobierzemy to w Providerze i przekażemy w Entry,
        // ale żeby nie zmieniać definicji Entry (SimpleEntry),
        // zrobimy tutaj "szybki hack" - odczytamy settings z UserDefaults bezpośrednio.

        let defaults = UserDefaults(suiteName: "group.com.maciek.FlipIt")
        if let data = defaults?.data(forKey: "AppSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {

            if !settings.widgetInactivityColor {
                return Color(uiColor: .secondarySystemGroupedBackground)
            }

            // Obliczamy różnicę dni
            let calendar = Calendar.current
            // Używamy .day, żeby liczył dni kalendarzowe, nie pełne 24h
            let days = calendar.dateComponents([.day], from: settings.lastWidgetInteractionDate, to: Date()).day ?? 0

            if days >= 3 { return Color.red.opacity(0.4) } // Mocno czerwony
            if days == 2 { return Color.red.opacity(0.2) } // Średnio
            if days == 1 { return Color.red.opacity(0.08) } // Lekko
        }

        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    // Sprawdzamy czy przyciski mają być kolorowe
    var useColorfulButtons: Bool {
        let defaults = UserDefaults(suiteName: "group.com.maciek.FlipIt")
        if let data = defaults?.data(forKey: "AppSettings"),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings.widgetColorfulButtons
        }
        return true
    }

    var body: some View {
        VStack(spacing: 0) {

            // --- 1. OBSZAR KARTY ---
            Link(destination: URL(string: "flipit://add_card")!) {
                ZStack {
                    // Warstwa A: Informacja
                    VStack {
                        Text("Tap to add new card")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.7))
                            .padding(.top, 8)
                        Spacer()
                    }

                    // Warstwa B: Treść
                    Text(entry.isFlipped ? entry.card.back : entry.card.front)
                        .font(.system(size: 16, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .foregroundStyle(Color.primary)
                        .id(entry.card.id.uuidString + (entry.isFlipped ? "_back" : "_front"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // TU APLIKUJEMY LOGIKĘ KOLORU TŁA
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(10)

            // --- 2. PASEK PRZYCISKÓW ---
            HStack(spacing: 20) {
                // Przycisk X
                Button(intent: MarkCardIntent(cardID: entry.card.id, isKnown: false)) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 34, height: 34)
                        // Logika koloru przycisków
                        .foregroundStyle(useColorfulButtons ? .red : .gray)
                }
                .buttonStyle(.plain)

                // Przycisk FLIP
                Button(intent: FlipCardIntent(cardID: entry.card.id, flipState: !entry.isFlipped)) {
                     Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .resizable()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(useColorfulButtons ? .blue : .gray)
                }
                .buttonStyle(.plain)

                // Przycisk V
                Button(intent: MarkCardIntent(cardID: entry.card.id, isKnown: true)) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(useColorfulButtons ? .green : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 12)
        }
        .containerBackground(Color(uiColor: .systemGroupedBackground), for: .widget)
    }
}

struct FlipItWidget: Widget {
    let kind: String = "FlipItWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: EmptyWidgetConfigurationIntent.self, provider: Provider()) { entry in
            FlipItWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FlipIt Study")
        .description("Study your cards directly from the home screen.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled() // Opcjonalnie, dla lepszego wyglądu
    }
}

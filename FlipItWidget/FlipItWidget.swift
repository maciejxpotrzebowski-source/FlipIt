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
    let frontLabel: String
    let backLabel: String
    let frontLang: String
    let backLang: String
    let useColorfulButtons: Bool
    let inactivityLevel: Int
}

struct Provider: AppIntentTimelineProvider {
    typealias Intent = EmptyWidgetConfigurationIntent

    func placeholderEntry() -> SimpleEntry {
            SimpleEntry(
                date: Date(),
                card: Flashcard(front: "Apple", back: "Jabłko"),
                isFlipped: false,
                frontLabel: "Front", backLabel: "Back",
                frontLang: "en-US", backLang: "pl-PL",
                useColorfulButtons: true,
                inactivityLevel: 0
            )
        }
    func placeholder(in context: Context) -> SimpleEntry { placeholderEntry() }

    func snapshot(for configuration: Intent, in context: Context) async -> SimpleEntry { placeholderEntry() }

    func timeline(for configuration: Intent, in context: Context) async -> Timeline<SimpleEntry> {
            let entry = await MainActor.run {
                let store = FlipItStore()
                let settings = store.settings
                var inactivityLvl = 0
                if settings.widgetInactivityColor {
                                let days = Calendar.current.dateComponents([.day], from: settings.lastWidgetInteractionDate, to: Date()).day ?? 0
                                if days >= 3 { inactivityLvl = 3 }
                                else if days == 2 { inactivityLvl = 2 }
                                else if days == 1 { inactivityLvl = 1 }
                            }
                let useColors = settings.widgetColorfulButtons

                let activeDecks = store.decks.filter { settings.usedDeckIDs.contains($0.id) }
                let totalCardsInActiveDecks = activeDecks.reduce(0) { $0 + $1.cards.count }

                var candidates: [(card: Flashcard, deck: Deck)] = []

                for deck in activeDecks {
                    for card in deck.cards {
                        // Filtracja: tylko nieumiane (jeśli włączona opcja)
                        if settings.onlyUnlearned && card.isLearned { continue }
                        candidates.append((card, deck))
                    }
                }

                var finalCard: Flashcard
                var fLabel = "Front"; var bLabel = "Back"
                var fLang = "en-US"; var bLang = "pl-PL"
                var finalIsFlipped = false

                if activeDecks.isEmpty {
                    finalCard = Flashcard(front: "Select Decks", back: "Configure in App")
                } else if totalCardsInActiveDecks == 0 {
                    finalCard = Flashcard(front: "Deck is Empty", back: "Add Cards in App")
                } else if candidates.isEmpty {
                    finalCard = Flashcard(front: "All Learned!", back: "Great job!")
                } else {
                    let savedState = store.loadWidgetState()

                    // Szukamy w naszej liście par (karta + deck)
                    if let state = savedState,
                       let foundPair = candidates.first(where: { $0.card.id == state.currentCardId }) {

                        // A. ZNALEZIONO ZAPISANĄ KARTĘ
                        finalCard = foundPair.card
                        finalIsFlipped = state.isFlipped

                        // Pobieramy dane z decka BEZPOŚREDNIO z pary
                        fLabel = foundPair.deck.frontLabel
                        bLabel = foundPair.deck.backLabel
                        fLang = foundPair.deck.frontLanguage
                        bLang = foundPair.deck.backLanguage

                    } else {
                        // B. LOSOWANIE NOWEJ
                        let factor = settings.learningFactorValue

                        // Ważenie na podstawie streaka karty
                        let weightedItems = candidates.map { pair -> (item: (card: Flashcard, deck: Deck), weight: Double) in
                            (pair, 1.0 / (1.0 + (Double(pair.card.streak) * factor)))
                        }

                        let totalWeight = weightedItems.reduce(0) { $0 + $1.weight }
                        let randomVal = Double.random(in: 0..<totalWeight)
                        var cursor = 0.0

                        // Fallback na pierwszy element
                        var selectedPair = candidates.first!

                        for element in weightedItems {
                            cursor += element.weight
                            if cursor >= randomVal {
                                selectedPair = element.item
                                break
                            }
                        }

                        finalCard = selectedPair.card

                        // Pobieramy dane z decka BEZPOŚREDNIO z wylosowanej pary
                        fLabel = selectedPair.deck.frontLabel
                        bLabel = selectedPair.deck.backLabel
                        fLang = selectedPair.deck.frontLanguage
                        bLang = selectedPair.deck.backLanguage

                        // Ustalanie strony startowej
                        switch settings.studySide {
                        case .front: finalIsFlipped = false
                        case .back: finalIsFlipped = true
                        case .random: finalIsFlipped = Bool.random()
                        }

                        store.saveWidgetState(cardId: finalCard.id, isFlipped: finalIsFlipped)
                    }
                }

                // 3. TWORZENIE ENTRY (Nie musimy już szukać decka w store.decks)
                return SimpleEntry(
                    date: Date(),
                    card: finalCard,
                    isFlipped: finalIsFlipped,
                    frontLabel: fLabel,
                    backLabel: bLabel,
                    frontLang: fLang,
                    backLang: bLang,
                    useColorfulButtons: useColors,
                    inactivityLevel: inactivityLvl
                )
            }

            return Timeline(entries: [entry], policy: .never)
        }
}

extension View {
    // Helper do koloru tła na podstawie poziomu z Entry
    func entryBackgroundColor(level: Int) -> Color {
        switch level {
            case 5: return Color.red.opacity(1.0)
            case 4: return Color.red.opacity(0.75)
            case 3: return Color.red.opacity(0.5)
            case 2: return Color.red.opacity(0.25)
            case 1: return Color.red.opacity(0.1)
            default: return Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
}

// ... (EmptyWidgetConfigurationIntent bez zmian) ...
struct EmptyWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configuration"
    static var description: LocalizedStringResource = "FlipIt Widget Configuration"
}

// --- NOWY WIDOK DLA DRUGIEGO WIDGETU ---
struct FlipItWidgetEntryView : View {
    var entry: Provider.Entry

    // Helpery (takie same jak w pierwszym widgecie)
    func getLangCode(_ code: String) -> String { String(code.prefix(2)).uppercased() }
    var currentText: String { entry.isFlipped ? entry.card.back : entry.card.front }
    var currentLabel: String { entry.isFlipped ? entry.backLabel : entry.frontLabel }
    var currentLang: String { entry.isFlipped ? entry.backLang : entry.frontLang }

    var body: some View {
        VStack(spacing: 0) {
            // 1. KARTA (Pozostawiamy możliwość obracania dotknięciem samej karty)
            Button(intent: FlipCardIntent(cardID: entry.card.id, flipState: !entry.isFlipped)) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(entryBackgroundColor(level: entry.inactivityLevel))
                    VStack {
                        Text("\(currentLabel) (\(getLangCode(currentLang)))")
                            .font(.system(size: 10, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .padding(.top, 10)
                        Spacer()
                        Text(currentText)
                            .font(.system(size: 16, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .foregroundStyle(Color.primary)
                            .id(entry.card.id.uuidString + (entry.isFlipped ? "_back" : "_front"))
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Spacer().frame(height: 10)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(10)

            // 2. PASEK PRZYCISKÓW (Tu jest ZMIANA)
            HStack(spacing: 8) {
                // Lewy: X
                Button(intent: MarkCardIntent(cardID: entry.card.id, isKnown: false)) {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(entry.useColorfulButtons ? .red : .gray)
                }
                .buttonStyle(.plain)

                // ŚRODKOWY: LINK DO DODAWANIA (Zamiast Flip)
                Link(destination: URL(string: "flipit://add_card")!) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(entry.useColorfulButtons ? .blue : .gray)
                }

                // Prawy: V
                Button(intent: MarkCardIntent(cardID: entry.card.id, isKnown: true)) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .frame(width: 34, height: 34)
                        .foregroundStyle(entry.useColorfulButtons ? .green : .gray)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .containerBackground(Color(uiColor: .systemGroupedBackground), for: .widget)
    }
}

// --- KONFIGURACJA NOWEGO WIDGETU ---
struct FlipItWidget: Widget {
    let kind: String = "FlipItWidget" // Unikalne ID

    var body: some WidgetConfiguration {
        // Używamy tego samego Providera, ale innego widoku (EntryView)
        AppIntentConfiguration(kind: kind, intent: EmptyWidgetConfigurationIntent.self, provider: Provider()) { entry in
            FlipItWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Study & Add")
        .description("Study cards and quickly add new ones.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}


// --- WIDOK DLA WIDGETU MINIMALISTYCZNEGO (X i V) ---
struct FlipItMinimalWidgetEntryView : View {
    var entry: Provider.Entry

    // Helpery
    func getLangCode(_ code: String) -> String { String(code.prefix(2)).uppercased() }
    var currentText: String { entry.isFlipped ? entry.card.back : entry.card.front }
    var currentLabel: String { entry.isFlipped ? entry.backLabel : entry.frontLabel }
    var currentLang: String { entry.isFlipped ? entry.backLang : entry.frontLang }

    var body: some View {
        VStack(spacing: 0) {
            // 1. KARTA (Obracanie dotknięciem)
            Button(intent: FlipCardIntent(cardID: entry.card.id, flipState: !entry.isFlipped)) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(entryBackgroundColor(level: entry.inactivityLevel))
                    VStack {
                        Text("\(currentLabel) (\(getLangCode(currentLang)))")
                            .font(.system(size: 10, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary.opacity(0.8))
                            .padding(.top, 10)
                        Spacer()
                        Text(currentText)
                            .font(.system(size: 16, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .foregroundStyle(Color.primary)
                            .id(entry.card.id.uuidString + (entry.isFlipped ? "_back" : "_front"))
                            .minimumScaleFactor(0.8)
                        Spacer()
                        Spacer().frame(height: 10)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(10)

            // 2. PASEK PRZYCISKÓW (TYLKO X i V)
            HStack {
                // Lewy: X
                Button(intent: MarkCardIntent(cardID: entry.card.id, isKnown: false)) {
                    ZStack {
                                // 1. TŁO (Wydłużone koło)
                                Capsule()
                                    .fill(entry.useColorfulButtons ? .red : .gray)
                                    .frame(width: 60, height: 34)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1) // Opcjonalny cień

                                // 2. IKONA (Biała w środku)
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .bold)) // Pogrubiona, mniejsza ikona
                                    .foregroundStyle(.background)
                            }
                }
                .buttonStyle(.plain)

                // Odstęp między przyciskami
                Spacer()

                // Prawy: V
                Button(intent: MarkCardIntent(cardID: entry.card.id, isKnown: true)) {
                    ZStack {
                                // 1. TŁO (Wydłużone koło)
                                Capsule()
                                    .fill(entry.useColorfulButtons ? .green : .gray)
                                    .frame(width: 60, height: 34)
                                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1) // Opcjonalny cień

                                // 2. IKONA (Biała w środku)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold)) // Pogrubiona, mniejsza ikona
                                    .foregroundStyle(.background)
                            }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10) // Margines, żeby przyciski nie były przy samych krawędziach
            .padding(.bottom, 10)
        }
        .containerBackground(Color(uiColor: .systemGroupedBackground), for: .widget)
    }
}

// --- KONFIGURACJA WIDGETU MINIMAL ---
struct FlipItMinimalWidget: Widget {
    let kind: String = "FlipItMinimalWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: EmptyWidgetConfigurationIntent.self, provider: Provider()) { entry in
            FlipItMinimalWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("FlipIt Minimal")
        .description("Clean look with just Mark buttons.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}


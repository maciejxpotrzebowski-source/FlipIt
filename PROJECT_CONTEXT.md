# 📱 FlipIt — Dokumentacja Architektury i Założeń Projektu (Project Continuity Brief)

> **Dokument ciągłości dla asystenta AI i programisty.**  
> Zapisany w katalogu głównym projektu: `PROJECT_CONTEXT.md`  
> Ostatnia aktualizacja: 30.09.2026 (Commit: `7a7e802`)

---

## 1. 🎯 Wizja i Cel Projektu
**FlipIt** to nowoczesna, minimalistyczna aplikacja do nauki słówek/pojęć za pomocą fiszek w stylu **Apple Human Interface Guidelines (HIG)** na platformy **iOS** i **macOS**. 
Kluczowe wyróżniki aplikacji:
1. **Interactive Widgets (iOS 17+)** — nauka bezpośrednio z ekranu blokady i ekranu początkowego za pomocą App Intents bez konieczności otwierania aplikacji.
2. **Adaptive Leitner Engine (z psychologią kasyna)** — nauka z dynamicznym dostosowywaniem trudności (koło ratunkowe po błędach, wyzwania po serii sukcesów).
3. **Prywatność i lekkość** — brak zewnętrznych serwerów śledzących; dane przechowywane lokalnie w App Group.
4. **FlipIt Pro (Gemini AI)** — opcjonalne generowanie gotowych talii przez Google Gemini API (model `gemini-1.5-flash` / `gemini-1.5-pro` via SPM `generative-ai-swift`).

---

## 2. ⚙️ Środowisko i Konfiguracja Techniczna

### Identyfikatory i Uprawnienia
- **Bundle Identifier:** `com.maciek.FlipIt`
- **Widget Bundle Identifier:** `com.maciek.FlipIt.FlipItWidget`
- **App Group:** `group.com.maciek.FlipIt` *(krytyczne dla współdzielenia bazy danych między aplikacją a widgetem)*
- **Development Team:** `862K9Z73NB`
- **Typ Konta Apple:** **Free Personal Team (Darmowe konto)**. Użytkownik **NIE** posiada płatnego Apple Developer Program i nie chce płacić Apple na tym etapie.
- **Wdrażanie na iPhone:** Odbywa się lokalnie przez kabel/Wi-Fi w Xcode z darmowym profilem (odnawianym co 7 dni) oraz włączonym Trybem Dewelopera w iOS.

### Repozytorium i OneDrive (⚠️ BARDZO WAŻNE)
- **Lokalizacja projektu:** Folder zsynchronizowany z **OneDrive**:  
  `.../02. Coding/FlipIt`
- **Zasada BHP pracy:** OneDrive może czasami z opóźnieniem synchronizować pliki lub przywracać starsze wersje robocze. **Zawsze na początku sesji sprawdzaj:**
  ```bash
  git status
  git log -n 3 --oneline
  ```
- **Kompilacja i Testy (bez podpisywania):**
  - **Build (macOS/iOS):**
    ```bash
    xcodebuild -scheme FlipIt -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
    ```
  - **Testy jednostkowe (wyłącznie FlipItTests):**
    ```bash
    xcodebuild test -scheme FlipIt -only-testing:FlipItTests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
    ```
  *(Uwaga: `FlipItUITests` wymagają interfejsu graficznego i uprawnień okna — w headless CLI uruchamiamy tylko `FlipItTests`).*

---

## 3. 🧠 Model Danych i Algorytm Uczenia

### A. Model Fiszki (`Flashcard`)
```swift
struct Flashcard: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var front: String
    var back: String
    var streak: Int = 0                 // Bieżąca seria poprawnych odpowiedzi
    var createdAt: Date = Date()
    
    // --- System Leitnera ---
    var box: Int = 0                    // Pudełko 0..4
    var nextReviewDate: Date = Date()   // Zaplanowany termin powtórki
    var lastReviewDate: Date? = nil     // Ostatnia powtórka
    var correctCount: Int = 0           // Łączna liczba dobrych odpowiedzi
    var incorrectCount: Int = 0         // Łączna liczba błędów
    
    // Opanowana = Pudełko 4 (21 dni interwału)
    var isLearned: Bool { get { box >= 4 } set { ... } }
    
    var accuracyRatio: Double { ... }   // Historyczny współczynnik sukcesu
    var isLeech: Bool { ... }           // "Pijawka" (błędy >= 2 i skuteczność < 60%)
}
```

### B. Interwały Pudełek Leitnera
- **Pudełko 0:** Natychmiast (nowe lub błędne)
- **Pudełko 1:** 1 dzień (`+86 400 s`)
- **Pudełko 2:** 3 dni (`+259 200 s`)
- **Pudełko 3:** 7 dni (`+604 800 s`)
- **Pudełko 4:** 21 dni (**Trwałe opanowanie**)

### C. Zasada Łagodnej Kary (Soft Penalty)
- Poprawna odpowiedź (✓): `box = min(box + 1, 4)`
- Błędna odpowiedź (❌): `box = max(box - 1, 0)` (**karta cofa się o 1 poziom, a nie spada do zera!**)

### D. Dynamic Flow Controller (`AdaptiveCardSelector` & Silent Continuous DDA)
Algorytm monitoruje przebieg sesji i reaguje na skrajne stany całkowicie dyskretnie w tle (bez rozpraszających etykiet/odznak):
1. **Koło Ratunkowe (Morale Rescue):**
   - **Warunek:** $\ge 2$ błędy z rzędu lub trwający tryb ratunkowy (`isInRescueMode`).
   - **Działanie:** Podsuwa różnorodne łatwiejsze karty z wyższych pudełek (`box >= 2` lub skuteczność $\ge 70\%$, z wyłączeniem ostatniej karty).
   - **Ciągłość:** W razie kolejnych błędów tryb ratunkowy **nie resetuje się** — łatwiejsze pytania trwają nieprzerwanie aż do pierwszej poprawnej odpowiedzi.
2. **Podkręcenie Poprzeczki (Challenge Engine):**
   - **Warunek:** $\ge 3$ sukcesy z rzędu lub trwający tryb wyzwania (`isInChallengeMode`).
   - **Działanie:** Podsuwa „pijawkę” (trudne słówko), kartę z niskiego pudełka/nową lub odwraca kolejność pytania (aktywna produkcja).
   - **Ciągłość:** Po poprawnej odpowiedzi na trudniejsze pytanie system **kontynuuje serwowanie trudniejszych fiszek** tak długo, jak użytkownik odpowiada poprawnie. Pojedynczy błąd natychmiast wyłącza wyzwanie.
3. **Tryb Standardowy:**
   - Wybiera karty przeterminowane (`nextReviewDate <= now`), z priorytetem dla najniższych pudełek (Pudełko 0 > 1 > 2...).

### E. Anonimowa Telemetria Uczenia (`StudyTelemetryManager`)
- W Ustawieniach znajduje się sekcja **„Uczenie i telemetria”** z przełącznikiem `analyticsEnabled`.
- Rejestruje **wyłącznie anonimowe parametry matematyczne** (czasy reakcji, poziomy pudełek, długości serii, znaczniki morale/wyzwań).
- **Treści słówek (przód/tył) NIGDY nie są zapisywane w logach.**
- Dane zapisywane są w pliku `study_telemetry.json` (max 2000 zdarzeń).
- Użytkownik może wyeksportować logi jako JSON przez `ShareLink` lub wyczyścić jednym przyciskiem.

---

## 4. 🗂️ Struktura Projektu i Plików

```
FlipIt/
├── FlipItApp.swift                 # Punkt startowy, wstrzykiwanie store i locale
├── FlipItModels.swift              # Modele danych (Flashcard, Deck, AppSettings, Store, Leitner, Telemetry)
├── FlipItAppIntents.swift          # Intenty interaktywnego widgetu (MarkCard, FlipCard)
├── APIKeyManager.swift             # Bezpieczne ładowanie klucza Gemini z Config.xcconfig
├── Views/
│   ├── Decks/
│   │   ├── HomeView.swift          # Główny ekran z listą talii (duży natywny tytuł)
│   │   ├── DeckDetailView.swift    # Szczegóły talii, sortowanie, lista kart, CTA startu
│   │   ├── NewDeckSheet.swift      # Tworzenie nowej talii
│   │   ├── EditDeckSheet.swift     # Edycja nazwy, opisu i etykiet
│   │   └── ManageDecksView.swift   # Reorganizacja i usuwanie talii
│   ├── Cards/
│   │   ├── CardView.swift          # Widok karty 3D (wspiera Dark Mode, dynamiczne kolory)
│   │   ├── CardRowView.swift       # Wiersz karty w liście (znaczek opanowania ✓ / box)
│   │   └── AddCardSheet.swift      # Dodawanie nowej karty z limitem znaków
│   ├── Study/
│   │   └── StudySessionView.swift  # Aktywna nauka (swipe Tinder-style, obrót 3D, badges) uruchamiana wprost z HomeView
│   ├── Market/
│   │   ├── DeckMarketView.swift    # Giełda Decków (Oficjalne / Społeczność / Szukaj po kodzie 8-znakowym)
│   │   └── PublishDeckSheet.swift  # Publikacja talii na giełdzie (kod auto-generowany, opcja prywatna)
│   ├── Settings/
│   │   └── SettingsView.swift      # Ustawienia języków, widgetu, FlipIt Pro i Telemetrii
│   ├── AI/
│   │   └── AIGenerateView.swift    # Generowanie kart przez Gemini z paywallem Pro
│   ├── Import/
│   │   └── ImportView.swift        # Import z plików CSV / JSON
│   ├── Services/
│   │   └── SupabaseManager.swift   # Klient Supabase (REST API, RPC, publikowanie, pobieranie po kodzie)
│   └── Components/
│       ├── SpeakerButton.swift     # Synteza mowy (AVSpeechSynthesizer, Dark Mode)
│       ├── MoveCardsView.swift     # Przenoszenie kart między taliami
│       ├── DeleteDuplicatesSheet.swift
│       ├── DeleteLearnedSheet.swift
│       ├── ResetProgressSheet.swift
│       └── DeleteAllSheet.swift
├── FlipItWidget/
│   └── FlipItWidget.swift          # Widgety iOS 17 (Study & Add, FlipIt Minimal) z Leitnerem
├── FlipItTests/
│   └── FlipItTests.swift           # 13 testów jednostkowych (Leitner, Telemetria, Parsowanie)
├── en.lproj/Localizable.strings    # Tłumaczenia angielskie (~170 kluczy)
└── pl.lproj/Localizable.strings    # Tłumaczenia polskie (~170 kluczy)
```

---

## 5. 🎨 Standardy Wizualne (Apple HIG)
- **Kolory semantyczne:** Zawsze używać `Color.appGroupedBackground`, `Color.appSecondaryGroupedBackground`, `.primary` i `.secondary`. **Żadnych sztywnych `.white` ani `.black`**, aby Dark Mode działał bezbłędnie.
- **Puste stany:** Zawsze natywny komponent `ContentUnavailableView(title, systemImage, description)`.
- **Nawigacja:** Natywne paski tytułowe z automatycznym zwijaniem `.navigationBarTitleDisplayMode(.large)` na ekranach głównych i `.inline` w podwidokach.
- **Zaokrąglenia i odstępy:** Promień kart i przycisków: `14pt` / `20pt`. Standardowe siatki odstępów: `8`, `12`, `16`, `24`.

---

## 6. 📋 Zadania w Backlogu (Kolejne Kroki)
1. **Synchronizacja wielourządzeniowa (iCloud Sync / CloudKit):** Wdrożenie modularnej synchronizacji talii i postępów w chmurze (wymaga Apple Developer Program / płatnego konta z capability iCloud Documents lub CloudKit).
2. **Bufor wyprzedzający widżetu (Prefetching Queue):** Kolejkowanie 3–5 fiszek do przodu w widżecie z asynchronicznym rejestrowaniem odpowiedzi (Action Queue) w celu natychmiastowej responsywności.
3. **Wyszukiwarka kart i talii:** Dodanie `.searchable(text:)` w `HomeView` i `DeckDetailView`.
4. **Uproszczenie menu DeckDetailView:** Przeniesienie rzadkich operacji (usuń duplikaty, usuń nauczone) do podmenu lub dedykowanego arkusza „Zarządzanie talią”.
5. **Komponent `CharacterCountLabel`:** Wyekstrahowanie powtarzającego się kodu liczników znaków.
6. **Rozbudowa haptyki:** Dodanie haptyki przy obrocie karty i zakończeniu sesji według propozycji.

---

> **Dla nowego agenta AI:** Ten projekt jest w 100% stabilny, skompilowany i przetestowany. Kod jest czysty. Przed rozpoczęciem prac przeczytaj ten plik, zrób `git status` i działaj zgodnie z powyższymi regułami.

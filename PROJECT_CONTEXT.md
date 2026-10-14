# 📱 FlipIt — Dokumentacja Architektury i Założeń Projektu (Project Continuity Brief)

> **Dokument ciągłości dla asystenta AI i programisty.**  
> Zapisany w katalogu głównym projektu: `PROJECT_CONTEXT.md`  
> Data ostatniej aktualizacji: 14.10.2026  
> Stan buildu i testów: **Kompilacja macOS i iOS powiodła się (`** BUILD SUCCEEDED **`); 20/20 testów jednostkowych zdanych pomyślnie (`** TEST SUCCEEDED **`)**.

---

## 1. 🎯 Wizja i Cel Projektu
**FlipIt** to nowoczesna, minimalistyczna aplikacja do nauki słówek/pojęć za pomocą fiszek w stylu **Apple Human Interface Guidelines (HIG)** na platformy **iOS** i **macOS**. 
Kluczowe wyróżniki aplikacji:
1. **Interactive Widgets (iOS 17+)** — nauka bezpośrednio z ekranu blokady i ekranu początkowego za pomocą App Intents bez konieczności otwierania aplikacji.
2. **Adaptive Leitner Engine (z psychologią kasyna)** — nauka z dynamicznym dostosowywaniem trudności (koło ratunkowe po błędach, wyzwania po serii sukcesów).
3. **Prywatność i model Local-First** — nauka, widgety, prywatne talie oraz postępy Leitnera działają w 100% lokalnie w App Group (`group.com.maciek.FlipIt`) bez wymogu posiadania konta.
4. **Deck Market & Społeczność (Supabase)** — giełda talii z podziałem na oficjalne i społecznościowe, wyszukiwanie po 8-znakowym unikalnym kodzie (`XXXX-XXXX`), 3-stronna synchronizacja aktualizacji od autora (`DeckSyncSheet`).
5. **FlipIt Pro (Gemini AI)** — inteligentne generowanie talii fiszek przez Google Gemini API z CEFR gradingiem (A1–C2) oraz automatyczną kategoryzacją tagów.

---

## 2. ⚙️ Środowisko i Konfiguracja Techniczna

### Identyfikatory i Uprawnienia
- **Bundle Identifier:** `com.maciek.FlipIt`
- **Widget Bundle Identifier:** `com.maciek.FlipIt.FlipItWidget`
- **App Group:** `group.com.maciek.FlipIt` *(krytyczne dla współdzielenia bazy danych między aplikacją a widgetem)*
- **Development Team:** `862K9Z73NB`
- **Typ Konta Apple:** **Free Personal Team (Darmowe konto)**. Użytkownik korzysta z darmowego profilu Apple. Capability `Sign in with Apple` wymaga płatnego Apple Developer Program ($99/rok) — dlatego przycisk Apple jest domyślnie wyłączony flagą `AuthManager.isAppleSignInEnabled = false`.
- **Wdrażanie na iPhone:** Odbywa się lokalnie przez kabel/Wi-Fi w Xcode z darmowym profilem (odnawianym co 7 dni) oraz włączonym Trybem Dewelopera w iOS.

### Repozytorium i OneDrive (⚠️ BARDZO WAŻNE)
- **Lokalizacja projektu:** Folder zsynchronizowany z **OneDrive**:  
  `.../02. Coding/FlipIt`
- **Zasada BHP pracy:** OneDrive może czasami z opóźnieniem synchronizować pliki lub blokować locki gita. **Zawsze na początku sesji sprawdzaj:**
  ```bash
  git status
  git log -n 3 --oneline
  ```

### Kompilacja i Testy (bez podpisywania kodu)
- **Build macOS (`arm64`):**
  ```bash
  xcodebuild -scheme FlipIt -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
  ```
- **Testy jednostkowe (`FlipItTests` na macOS):**
  ```bash
  xcodebuild test -scheme FlipIt -only-testing:FlipItTests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
  ```
  *(Uwaga: uruchamiamy `FlipItTests`. Suite zawiera 20 testów jednostkowych badających Leitnera, algorytmy adaptacyjne, telemetrię, parsowanie CSV, 5-kategorialny diff synchronizacji talii oraz rzeczywiste generowanie fiszek przez Gemini).*
- **Build iOS (`generic/platform=iOS`):**
  ```bash
  xcodebuild -scheme FlipIt -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
  ```

---

## 3. 🌐 Architektura Chmury (Supabase) i Model Prywatności

### Co trafia na serwer Supabase, a co zostaje lokalnie?
| Obszar | Gdzie jest przechowywany | Opis |
|---|---|---|
| **Prywatne talie i fiszki** | 📱 Tylko lokalnie (App Group) | Twoje prywatne talie NIGDY nie są wysyłane do Supabase ani widoczne dla nikogo. |
| **Postępy w nauce (Leitner)** | 📱 Tylko lokalnie (App Group) | Stan pudełek (0..4), serie (`streak`), terminy powtórek (`nextReviewDate`) oraz liczniki błędów/sukcesów są lokalne. |
| **Telemetria uczenia** | 📱 Tylko lokalnie (`study_telemetry.json`) | Ściśle anonimowe metryki matematyczne (czasy reakcji, morale, wyzwania). Nigdy nie zapisuje treści fiszek. |
| **Konto użytkownika** | ☁️ Supabase Auth | Identyfikator `auth.uid()`, email (OTP) lub token Google OAuth. |
| **Profil publiczny** | ☁️ Supabase `profiles` | Unikalny nick `@username` (3–20 znaków: `^[a-zA-Z0-9_]{3,20}$`). Zmiana nicku raz na 30 dni; 60 dni kwarantanny po zmianie/usunięciu konta. |
| **Talie w Community** | ☁️ Supabase `shared_decks` | Wyłącznie talie **jawnie opublikowane** przez użytkownika. Zawierają treść fiszek, etykiety, języki, CEFR level, tagi, 8-znakowy `share_code`, `author_id` i `author_name`. |
| **Liczniki statystyk** | ☁️ Supabase `shared_decks` | Łączna liczba pobrań (`downloads_count`) oraz zgłoszone powtórki (`total_reviews_reported`). |

### Bezpieczeństwo i RLS (Migracja `20261015_security_fixes.sql`)
1. **Brak bezpośrednich modyfikacji klientem:** Operacje usuwania (`delete_deck`), zdejmowania z rynku (`unpublish_deck`), zmiany widoczności (`set_deck_visibility`) i raportowania statystyk (`report_usage_stats`) są realizowane wyłącznie przez dedykowane funkcje PostgreSQL RPC z walidacją `auth.uid()`.
2. **Zaostrzone RLS:** Tylko zalogowany autor (`author_id = auth.uid()`) może wstawiać talię z własnym ID. Liczniki i flagi oficjalne są chronione triggerami `BEFORE INSERT` / `BEFORE UPDATE`.
3. **Prawdziwe usuwanie konta:** RPC `delete_my_account()` usuwa użytkownika z `auth.users`, a kaskada usuwa profil. Opublikowane talie zachowują się jako publiczne z `author_id = NULL` (`ON DELETE SET NULL`).
4. **Wylogowanie hybrydowe:**
   - **Ścieżka A (Domyślna):** Zachowaj pobrane i lokalne talie na urządzeniu.
   - **Ścieżka B:** Wyczyść talie użytkownika z urządzenia.
   - **Wylogowanie wymuszone (wygasła sesja):** Zawsze stosuje ścieżkę A, aby zabezpieczyć użytkownika przed utratą danych.

---

## 4. 🧠 Model Danych i Algorytm Uczenia

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

### D. Dynamic Flow Controller (`AdaptiveCardSelector`)
1. **Koło Ratunkowe (Morale Rescue):** $\ge 2$ błędy z rzędu podsuwają łatwiejsze karty z wyższych pudełek aż do przełamania złej passy.
2. **Podkręcenie Poprzeczki (Challenge Engine):** $\ge 3$ sukcesy z rzędu serwują trudniejsze słówka lub odwracają kolejność (produkcja) do pierwszego błędu.
3. **Tryb Standardowy:** Priorytet dla kart przeterminowanych z najniższych pudełek.

### E. 3-Stronna Synchronizacja Talii (`calculateSyncDiff`)
Gdy autor aktualizuje talię w Community, pobierający użytkownik widzi arkusz różnic (`DeckSyncSheet`):
- `authorAdded`: nowe fiszki dodane przez autora (domyślnie zaznaczone do pobrania; trafiają do Pudełka 0).
- `authorUpdated`: poprawki literówek/treści autora na niemodyfikowanych przez użytkownika kartach.
- `userModified`: konflikt — użytkownik edytował kartę, a autor też ją zmienił (domyślnie zachowuje wersję użytkownika).
- `authorDeleted`: fiszki usunięte przez autora (domyślnie odznaczone — użytkownik ich nie traci).
- `userAdded`: własne karty użytkownika dodane do talii (pozostają nienaruszone).
- **Postęp nauki:** Synchronizacja **nigdy nie resetuje** `box`, `streak`, `nextReviewDate`, `correctCount` ani `incorrectCount` istniejących kart.

---

## 5. 🤖 Modele AI (Gemini) i FlipIt Pro

### Realne Modele Produkcyjne Google AI Studio
Modele są mapowane na rzeczywiste identyfikatory w Google Generative AI API:
- **`models/gemini-3.5-flash-lite` (Domyślny & Zalecany):** Błyskawiczna generacja (~0.89s w testach), pełna dokładność formatu CSV i CEFR.
- **`models/gemini-3.8-flash`:** Zaawansowana analiza semantyczna.
- **`models/gemini-3-flash-preview`:** Wersja podglądowa (~12s).
- **`models/gemini-3.1-flash-lite`:** Starsza wersja podlegająca okresowym przeciążeniom (503).
*(Uwaga: Starsze modele `gemini-1.5` i `gemini-2.5` zostały wygaszone przez Google API dla nowych użytkowników).*

### Status FlipIt Pro & Paywall
- Generowanie AI wymaga aktywnego konta FlipIt i uprawnienia Pro (`store.settings.isPremiumUser = true`).
- **Wersja DEBUG:** Przycisk `[DEBUG] Unlock FlipIt Pro` pozwala na darmowe odblokowanie do celów testowych.
- **Wersja RELEASE:** Przycisk testowy jest ukryty; wyświetlana jest informacja `Coming Soon` (`Wkrótce`).
- **Limity zapytań:** Google AI Studio oferuje darmowy limit 1500 req/dzień per klucz API.

---

## 6. 🗂️ Struktura Projektu i Plików

```
FlipIt/
├── FlipItApp.swift                 # Punkt startowy, wstrzykiwanie store, auth i locale
├── FlipItModels.swift              # Modele danych (Flashcard, Deck, AppSettings, FlipItStore, Leitner, Sync Diff)
├── FlipItAppIntents.swift          # Intenty interaktywnego widgetu (MarkCard, FlipCard)
├── PlatformCompat.swift            # Warstwa kompatybilności macOS (UIPasteboard shim, feedback, layout)
├── APIKeyManager.swift             # Bezpieczne ładowanie klucza Gemini z Config.xcconfig / Info.plist
├── GeminiService.swift             # Klient Google Generative AI (generowanie fiszek CSV, analiza talii, CEFR)
├── Config.xcconfig                 # (GITIGNORED) Klucze API: GEMINI_API_KEY, SUPABASE_URL, SUPABASE_ANON_KEY
├── Services/
│   ├── AuthManager.swift           # Uwierzytelnianie (Email OTP, Google OAuth, Apple feature flag, profile)
│   └── SupabaseManager.swift       # Networking Supabase (RPC, giełda talii, pobieranie po kodzie, statystyki)
├── Views/
│   ├── Auth/
│   │   ├── AuthPromptSheet.swift   # Wybór metody logowania (Google, Email OTP, warunkowe Apple)
│   │   ├── EmailOTPSheet.swift     # Logowanie kodem 6-cyfrowym na e-mail
│   │   ├── SetUsernameSheet.swift  # Nadawanie unikalnego nicku przy rejestracji
│   │   └── ChangeUsernameSheet.swift # Zmiana nicku (30-dniowy cooldown, 60 dni kwarantanny)
│   ├── Decks/
│   │   ├── HomeView.swift          # Główny pulpit z listą talii i postępami
│   │   ├── DeckDetailView.swift    # Karty w talii, wyszukiwanie, opcje nauki, zarządzanie
│   │   ├── NewDeckSheet.swift      # Tworzenie nowej talii
│   │   └── EditDeckSheet.swift     # Edycja nazwy, języków, poziomu i etykiet
│   ├── Cards/
│   │   ├── CardView.swift          # Interaktywna karta 3D (obrót, dark mode)
│   │   ├── CardRowView.swift       # Wiersz fiszki z oznaczeniem pudełka i opanowania
│   │   └── AddCardSheet.swift      # Dodawanie karty z limitem znaków
│   ├── Study/
│   │   └── StudySessionView.swift  # Tryb nauki (swipe Tinder-style, Leitner, koło ratunkowe, wyzwania)
│   ├── Market/
│   │   ├── DeckMarketView.swift    # Giełda talii (Oficjalne / Społeczność / Szukaj po kodzie / Moje talie)
│   │   ├── PublishDeckSheet.swift  # Publikacja talii (Public/Private, generowanie kodu XXXX-XXXX)
│   │   ├── DeckSyncSheet.swift     # 3-stronna synchronizacja aktualizacji od autora
│   │   └── CommunityDeckPreviewSheet.swift # Podgląd talii przed pobraniem
│   ├── AI/
│   │   └── AIGenerateView.swift    # Generowanie kart przez Gemini z paywallem Pro
│   ├── Import/
│   │   └── ImportView.swift        # Import z plików CSV / JSON
│   ├── Settings/
│   │   └── SettingsView.swift      # Ustawienia języków, modelu AI, konta i telemetrii
│   └── Components/
│       └── SpeakerButton.swift     # Synteza mowy (AVSpeechSynthesizer)
├── FlipItWidget/
│   └── FlipItWidget.swift          # Widgety iOS 17 (Study & Add, FlipIt Minimal) z Leitnerem
├── FlipItTests/
│   └── FlipItTests.swift           # 20 testów jednostkowych (Leitner, Telemetria, Parsowanie, Sync, Gemini API)
├── supabase/
│   ├── schema_live.sql             # Rzeczywisty schemat wyeksportowany z bazy Supabase
│   └── migrations/
│       └── 20261015_security_fixes.sql # Idempotentna migracja zabezpieczająca RLS i RPC (4 kroki + testy + rollback)
├── en.lproj/Localizable.strings    # Tłumaczenia angielskie (557 identycznych kluczy)
└── pl.lproj/Localizable.strings    # Tłumaczenia polskie (557 identycznych kluczy)
```

---

## 7. 🌐 Zasady Lokalizacji (GEMINI.md)

1. Każdy widoczny dla użytkownika tekst **musi** znajdować się w obu plikach:
   - `FlipIt/en.lproj/Localizable.strings`
   - `FlipIt/pl.lproj/Localizable.strings`
2. Identyczne klucze i specyfikatory formatu (`%@`, `%lld`, `%.1f`).
3. Sprawdzanie poprawności składni:
   ```bash
   plutil -lint FlipIt/en.lproj/Localizable.strings
   plutil -lint FlipIt/pl.lproj/Localizable.strings
   ```

---

## 8. ⚠️ Znane Ograniczenia i Backlog

1. **Sign in with Apple:** Wymaga konta w płatnym Apple Developer Program. Kod jest w pełni zaimplementowany w `AuthManager.swift`, lecz przycisk w `AuthPromptSheet.swift` jest wyłączony flagą `isAppleSignInEnabled = false`.
2. **Klucz Gemini w Info.plist:** Na etapie deweloperskim klucz API kompilowany jest z `Config.xcconfig`. W wersji produkcyjnej zalecane jest pośredniczenie przez Supabase Edge Function.
3. **Zabezpieczenie przed spamem liczników:** RPC `increment_downloads` i `report_usage_stats` aktualizują liczniki globalne. W przyszłości można dodać tabelę zdarzeń `deck_download_events(deck_id, user_id)` z ograniczeniem 1/użytkownik.
4. **Przejście na URLSession REST:** Google oznaczył `generative-ai-swift` jako deprecated. SDK działa obecnie bez zarzutu, jednak zalecana jest migracja na natywny lekki klient HTTP REST (~80 linii Swift) eliminujący zależność SPM.

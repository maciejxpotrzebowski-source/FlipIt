# FlipIt — Project Rules & Guidelines

## 🌐 Localization Rule (Zasada Lokalizacji Tekstów)

**Krytyczna zasada dla każdego nowego i modyfikowanego kodu:**
Gdy dodajemy, modyfikujemy lub refaktoryzujemy jakikolwiek tekst widoczny dla użytkownika (przyciski, etykiety, alerty, arkusze modalne, tytuły nawigacji, nagłówki sekcji, dialogi potwierdzenia, etykiety dostępności `accessibilityLabel`):

1. **Obowiązkowa obsługa przez dedykowane pliki lokalizacyjne:**
   - Nigdy nie pozostawiaj surowych, twardo zakodowanych ciągów tekstowych bez wpisu w plikach tłumaczeń.
   - Każdy widoczny tekst **musi być od razu** dodany z tłumaczeniem angielskim i polskim do obu plików:
     - `FlipIt/en.lproj/Localizable.strings` (Wersja angielska)
     - `FlipIt/pl.lproj/Localizable.strings` (Wersja polska)

2. **Identyczne klucze i specyfikatory formatu:**
   - Oba pliki `.strings` muszą zachować dokładnie takie same klucze po lewej stronie `"klucz" = "wartość";`.
   - Wszystkie specyfikatory formatowania (`%@`, `%lld`, `%d`, `%.1f`) muszą się precyzyjnie zgadzać między wersją angielską a polską.

3. **Zgodność ze SwiftUI:**
   - W przypadku interpolacji (np. `Text("\(deck.name)")` lub `Text("\(count) cards")`) SwiftUI szuka odpowiednio klucza `"%@"` lub `"%lld cards"`.
   - Gdy do `Text(...)` lub `Label(...)` przekazywana jest zmienna typu `String` (a nie literał), SwiftUI domyślnie traktuje ją jako tekst dosłowny (*verbatim*). W takich wypadkach należy jawnie użyć `Text(LocalizedStringKey(zmienna))` lub `String(format: NSLocalizedString("...", comment: ""), argumenty)`.
   - Wyrażenia trójargumentowe (ternary) w `.navigationTitle` lub `Text` należy opakować w `LocalizedStringKey(...)`.

# FlipIt Design System & Visual Guidelines

Ten dokument stanowi **główny wzorzec projektowy (Golden Standard)** dla interfejsu aplikacji **FlipIt**. Wszelkie nowe ekrany, komponenty oraz modyfikacje istniejących widoków **muszą być spójne** z poniższymi założeniami wypracowanymi na bazie ekranu głównego (`HomeView.swift`).

---

## 1. Ekran Główny (`HomeView`) jako Wzorzec Referencyjny

Ekran główny reprezentuje docelowy, czysty styl wizualny aplikacji: minimalistyczny, natywny dla iOS, z czytelną hierarchią typograficzną i subtelnymi akcentami kolorystycznymi.

### 1.1. Prawy Górny Róg (Top-Right Actions) — ZASADA KLUCZOWA ⭐️
> **BEZWZGLĘDNA ZASADA:** Przyciski akcji w prawym górnym rogu ekranu to **proste, czyste ikony SF Symbols bez żadnych obwódek, bez pigułek, bez kółek w tle i bez dodatkowych tła/cieni.**

- **Zębatka (Settings):**
  - Ikona: `Image(systemName: "gearshape.fill")`
  - Rozmiar i grubość: `.font(.system(size: 20, weight: .semibold))`
  - Kolor: `Color.blue`
  - Styl: Brak tła, brak obwódki, czysta ikona.

- **Plus (Add Menu):**
  - Ikona: `Image(systemName: "plus")`
  - Rozmiar i grubość: `.font(.system(size: 20, weight: .bold))`
  - Kolor: `Color.green`
  - Styl: Brak tła, brak obwódki, czysta ikona.

- **Odstęp między ikonami w pasku:** `HStack(spacing: 16)`

---

## 2. Nagłówek Ekranu (Top Bar) & Akcje Pomocnicze

1. **Tytuł ekranu:**
   - Wyświetlany po lewej stronie: `"FlipIt"`
   - Styl: `.font(.system(size: 32, weight: .bold, design: .rounded))`, kolor `Color.primary`.
   - Padding kontenera: `.padding(.horizontal, 20)`, `.padding(.top, 12)`, `.padding(.bottom, 6)`.
   - Tło: `Color.appGroupedBackground`.

2. **Pasek pomocniczy (pod tytułem):**
   - Po prawej stronie: przycisk tekstowy `Select All` / `Deselect All`.
   - Styl tekstu: `.font(.caption).fontWeight(.semibold)`.
   - Kolor: `Color.blue` (gdy nie wszystko zaznaczone) lub `Color.secondary` (gdy wszystko zaznaczone).
   - Padding: `.padding(.horizontal, 20)`, `.padding(.top, 4)`, `.padding(.bottom, 2)`.

---

## 3. Lista Talii & Odstępy (Spacing)

- **Układ listy:** `LazyVStack(spacing: 8)` wewnątrz `ScrollView` z `ScrollViewReader`.
- **Marginesy listy:**
  - Poziome: `.padding(.horizontal, 16)`
  - Górny: `.padding(.top, 6)`
  - Dolny: `.padding(.bottom, 100)` (zapewnia miejsce na przypięty dolny przycisk akcji).
- **Odstęp między kartami talii:** Dokładnie **8 pt** (`spacing: 8`) — zwarty, estetyczny rytm pionowy.

---

## 4. Karta Talii (Deck Card Component — Układ 3 Linii)

Każda karta talii w liście posiada precyzyjną, 3-elementową strukturę:

```
+-----------------------------------------------------------------------------------+
| (O)   Nazwa Talii [🌐/👥/⬇️] (bold, headline, skraca się z ...)                 >  |
|       Krótki opis talii (secondary, subheadline, 1 linia)                         |
|       [===== Pasek Postępu Leitnera =====]  (✓)  [EN -> PL]  [🗂 25]               |
+-----------------------------------------------------------------------------------+
```

### 4.1. Kontener Karty
- Tło: `Color.appSecondaryGroupedBackground`.
- Kształt: `RoundedRectangle(cornerRadius: 16, style: .continuous)`.
- Wewnętrzny padding: `14 pt` dookoła.
- Subtelna obwódka: `Color.primary.opacity(0.04)`, `lineWidth: 1`.

### 4.2. Lewa strona (Wybór / Checkbox)
- Przycisk dotykowy o wielkości `36x36 pt`.
- Stan zaznaczony: `Image(systemName: "checkmark.circle.fill")` w kolorze `Color.blue` (24 pt, semibold).
- Stan odznaczony: `Image(systemName: "circle")` w kolorze `Color.secondary.opacity(0.35)` (24 pt, semibold).

### 4.3. Środek (3 linie informacji)
1. **Linia 1: Nazwa talii + Ikona pochodzenia z giełdy (po prawej stronie nazwy)**
   - **Reguła położenia:** Ikona giełdy znajduje się **zawsze po prawej stronie nazwy**.
   - **Gwarancja widoczności (Truncation):** Jeśli nazwa talii jest długa, to nazwa skraca się z wielokropkiem (`.lineLimit(1)`, `.truncationMode(.tail)`), natomiast ikona posiada `.fixedSize()` i `.layoutPriority(1)`, dzięki czemu **zawsze mieści się na ekranie i nigdy nie jest ucinana**.
   - **5 Przypadków Pochodzenia i Stanu Talii (Globus / Popiersia + Strzałka góra/dół):**
     1. **Nasza prywatna talia (lokalna):** `shareCode == nil` -> **Brak ikony**.
     2. **Własna talia publiczna:** Opublikowana na rynek -> **Globus ze strzałką w górę (`globe` + `arrow.up`)**, kolor: **niebieski** (`Color.blue`).
     3. **Własna talia prywatna:** Udostępniona znajomym na kod -> **Popiersia ze strzałką w górę (`person.2` + `arrow.up`)**, kolor: **niebieski** (`Color.blue`).
     4. **Zaimportowana talia publiczna:** Pobrana z rynku -> **Globus ze strzałką w dół (`globe` + `arrow.down`)**, kolor: **niebieski** (`Color.blue`).
     5. **Zaimportowana talia prywatna:** Pobrana na kod od znajomego -> **Popiersia ze strzałką w dół (`person.2` + `arrow.down`)**, kolor: **niebieski** (`Color.blue`).
   - **Stan Aktualizacji (Update Available):**
     - Jeśli autor zaimportowanej talii wprowadził zmiany na giełdzie, kolor ikony zaimportowanej talii (przypadki 4 i 5) zmienia się na **żółtopomarańczowy** (`Color.marketUpdateYellowOrange`).
     - **Powrót do koloru niebieskiego:** Gdy użytkownik odrzuci aktualizację (przycisk *Dismiss Update*) lub zaakceptuje zmiany (nawet niepełne), ikona natychmiast wraca do koloru **niebieskiego** i pozostaje niebieska aż do momentu opublikowania przez autora **kolejnej, nowszej wersji**.

2. **Linia 2: Opis**
   - `.font(.subheadline).foregroundStyle(Color.secondary).lineLimit(1)`.

3. **Linia 3: Pełny pasek Leitnera + wskaźniki**
   - Szeroki pasek Leitnera: `Capsule` o wysokości 6 pt, gradient niebieski (`[Color.blue, Color.cyan]`).
   - Wskaźnik opanowania: `Image(systemName: "checkmark.seal.fill")` w kolorze `Color.blue` (13 pt), gdy 100% fiszek jest w Box 4.
   - Pigułka języków: Mała kapsułka z tłem `Color.primary.opacity(0.06)`, tekst np. `EN -> PL` (10 pt semibold, `Color.secondary`).
   - Liczba fiszek: Ikona `rectangle.portrait.on.rectangle.portrait` (10 pt) + cyfra (`.caption.fontWeight(.medium)`).

### 4.4. Prawa strona (Nawigacja)
- Strzałka: `Image(systemName: "chevron.right")` w kolorze `Color.secondary.opacity(0.35)` (13 pt semibold), obszar klikalny `36x36`.

---

## 5. Przypięty Dolny Pasek Akcji (Bottom Action Bar)

- Umiejscowienie: `.safeAreaInset(edge: .bottom)`.
- Główny przycisk nauki:
  - Tekst: `"START STUDYING"` (wielkie litery, `.headline`, `.bold`, biały).
  - Tło: Pełny, zaokrąglony prostokąt `Color.green`, wysokość `52 pt`, `cornerRadius: 16`.
  - Cień: Subtelny `Color.green.opacity(0.3)`, radius 8, y: 4.
  - Marginesy: `.padding(.horizontal, 16)`, `.padding(.vertical, 8)`.

---

## 6. Paleta Kolorów i Konwencje Semantyczne

| Rola w aplikacji | Kolor systemowy | Zastosowanie |
| :--- | :--- | :--- |
| **Główna akcja / Start / Sukces** | `Color.green` | Przycisk Start Studying, ikona Plus, status publikacji |
| **Nawigacja / Zaznaczenie / Postęp** | `Color.blue` | Ikona Ustawień, Checkbox, Pasek Leitnera, Public Market |
| **Udostępnianie Prywatne** | `Color.purple` | Ikona dwóch popiersi (`person.2.fill`) dla talii z kodem prywatnym |
| **Ostrzeżenie / Tryb Edycji** | `Color.orange` | Tryb Reorder & Delete, ramka przeciągania |
| **Destrukcyjne** | `Color.red` | Usuwanie talii, kosz, cofanie operacji |
| **Tło ekranu** | `Color.appGroupedBackground` | Tło ekranu głównego i list |
| **Tło elementów (Karty)** | `Color.appSecondaryGroupedBackground` | Karta talii, panele, sekcje |

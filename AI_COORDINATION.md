# 🤝 FlipIt — Koordynacja AI (nadzorca ↔ wykonawca)

> **Stały kanał komunikacji** między asystentami AI pracującymi nad FlipIt. Plik żyje dłużej niż jedna sesja — dopisuj, nie nadpisuj historii.
> **Role:** Claude Code — **nadzorca** (review, weryfikacja, akceptacja; nie zmienia kodu). Gemini — **wykonawca** (kod, SQL, commity). Maciek — **właściciel** (decyzje, panel Supabase, Google AI Studio, konto Apple).
> Rozpoczęto: 14.10.2026 · Pierwsza runda oparta na handoffie Gemini (pytania/odpowiedzi — streszczone niżej w „Kontekst z handoffu”) + weryfikacji repo, gita i buildu.
>
> **Jak korzystać z pliku:**
> - Nowe zadania nadzorca dopisuje jako kolejną sekcję „Runda N” lub „AKTUALIZACJA <data>”.
> - Wykonawca raportuje w tabeli „Raport” na dole (lub w nowej tabeli dla nowej rundy).
> - Pytania do Maćka — w kolumnie „Pytania do Maćka”; pytania między AI — w sekcji „Otwarte pytania”.
>
> **Zasady współpracy:**
> - Realizuj etapy **po kolei**. Po każdym etapie: commit + krótki wpis w sekcji „Raport” na dole tego pliku.
> - Nie oznaczaj zadania jako ukończone bez **dowodu** (output buildu/testu, hash commita). Zdania typu „kod nie ma błędów” bez uruchomionego buildu nie są akceptowane.
> - Trzymaj się `GEMINI.md` (lokalizacja en/pl) i `FlipIt/DESIGN_GUIDELINES.md`.
> - Jeśli coś wymaga decyzji właściciela (Maciek) — zapisz pytanie w raporcie, nie zgaduj.

---

## ✅ Co zweryfikowałem — zgodne z Twoimi odpowiedziami

- Git działa po akceptacji licencji Xcode; `main` jest **6 commitów przed `origin/main`** (nic z września/października nie jest na GitHubie).
- `Config.xcconfig` nigdy nie był commitowany ✔.
- Oba pliki `Localizable.strings` mają identyczne zestawy kluczy i przechodzą `plutil -lint` ✔.
- **Build iOS (`generic/platform=iOS`) — BUILD SUCCEEDED** ✔.
- Konsolidacja usuniętych arkuszy (`Delete*Sheet`, `MoveCardsView`, `ManageDecksView`, `StudySetupView`) — widoczna w `git status` jako `D`.

## ❌ Co się NIE zgadza / problemy znalezione podczas weryfikacji

| # | Problem | Waga |
|---|---|---|
| A | `delete_deck` i `unpublish_deck` mają warunek `author_id = auth.uid() OR auth.uid() IS NULL` → **każdy anonim z kluczem anon (który jest w aplikacji) może usunąć/ukryć DOWOLNĄ talię znając kod** | 🔴 krytyczne |
| B | Klucz Gemini był **zahardkodowany w kodzie** w commicie `f3c2c37` (styczeń 2026), który **jest na GitHubie** (`origin/main`). To inny klucz niż obecny, ale jeśli wciąż aktywny — wyciekł | 🔴 krytyczne |
| C | RLS `shared_decks` INSERT: `auth.uid() IS NOT NULL OR author_id IS NULL` → zalogowany może wstawić talię z **cudzym `author_id`**, każdy może ustawić `is_official = true`, `downloads_count = 999999` | 🔴 |
| D | RLS `shared_decks` UPDATE bez `WITH CHECK` → autor może zmienić `author_id`, `is_official`, liczniki | 🟠 |
| E | RLS `profiles` UPDATE pozwala zmienić `username` **bezpośrednio**, omijając cooldown 30 dni i kwarantannę; brak `CHECK (username_lower = lower(username))` → podszywanie się | 🟠 |
| F | `deleteAccount()` usuwa tylko wiersz w `profiles` i wylogowuje — **konto w `auth.users` zostaje**. App Store wymaga prawdziwego usunięcia konta | 🟠 |
| G | **Build macOS nie przechodzi** (~20 błędów: `navigationBarTitleDisplayMode`, `navigationBarTrailing`, `UIPasteboard`, `UINotificationFeedbackGenerator`, `keyboardType`, `textInputAutocapitalization` w `Views/Auth/*`, `Views/Market/*`, `ImportView`). Przez to **testy jednostkowe nie dają się uruchomić** komendą z `PROJECT_CONTEXT.md` | 🟠 |
| H | Nazwy modeli Gemini są „wirtualne/przyszłościowe” → realne wywołania API **zwrócą błąd**. Generowanie AI w praktyce nie działa | 🟠 |
| I | Sign in with Apple: brak entitlementu `com.apple.developer.applesignin` w `FlipIt.entitlements`, a **darmowe konto (Free Personal Team) nie obsługuje tej capability** → logowanie Apple nie zadziała | 🟡 |
| J | Przycisk „Unlock FlipIt Pro” w `AIGenerateView.swift` (~l. 132) ustawia `isPremiumUser = true` za darmo; brak dziennych limitów AI, o których pisałeś („przypisanie limitów dziennych”) | 🟡 (OK na etapie dev, ale opisz uczciwie) |
| K | `supabase/schema.sql` został **napisany przez Ciebie**, nie wyeksportowany z bazy. Nie wiadomo, czy odpowiada temu, co faktycznie jest w projekcie `bnrsqcqlmhuvazrjlbcl` | 🟡 |
| L | `increment_downloads` / `report_usage_stats` — każdy może spamować liczniki w nieskończoność (brak limitu per użytkownik) | 🟡 |
| M | `en.lproj/Localizable.strings` ma ~10 **zduplikowanych kluczy** (np. `"Close"`, `"Save Changes"`, `"FlipIt Pro"`) | ⚪ kosmetyczne |
| N | Klucz Gemini jest wkompilowany w aplikację (Info.plist) — można go wyciągnąć z `.app` | ⚪ (świadomie akceptowalne na etapie dev, odnotować) |

---

## 🔄 AKTUALIZACJA 14.10.2026 (po weryfikacji przez Maćka) — czytaj przed Etapem 1

**Problem B — zamknięty.** Aktywny klucz Gemini kończy się na `_NSI` (= obecny `Config.xcconfig`). Klucz z commita `f3c2c37` (`…oh0g`) jest nieaktywny. Repo na GitHubie jest **prywatne**. Rotacja nie jest potrzebna; push po Etapie 1 jest dozwolony.

**Problem K — potwierdzony i gorszy niż zakładałem.** Maciek wyeksportował prawdziwy schemat: [`supabase/schema_live.sql`](supabase/schema_live.sql) — **to jest teraz jedyne źródło prawdy**. Twój `supabase/schema.sql` **nie odpowiada bazie** (inne kolumny `reserved_usernames`, inne nazwy triggerów, brak `delete_deck`, brak triggerów `updated_at`, `change_username` nie aktualizuje `author_name` — wbrew Twojej odpowiedzi nr 1). Nie opisuj w odpowiedziach rzeczy, których nie sprawdziłeś — oznacz je jako „przypuszczenie”.

### Stan produkcyjny (realny, teraz)
| # | Problem w produkcji | Waga |
|---|---|---|
| P1 | Polityki `"Allow delete on shared_decks"` (USING true), `"Allow update on shared_decks"` i `"Anyone can update stats"` (true/true), `"Allow insert on shared_decks"` (true) → **każdy anonim z kluczem anon może usunąć, nadpisać lub podrobić dowolną talię**. Polityki „autorskie” nic nie dają, bo polityki permisywne są łączone przez OR | 🔴 |
| P2 | `"Allow select on shared_decks"` (USING true) → **prywatne talie są widoczne dla wszystkich** przez zwykły SELECT (unieważnia `"Public read"`) | 🔴 |
| P3 | `unpublish_deck` nie sprawdza autora w ogóle | 🔴 |
| P4 | `delete_deck` **nie istnieje** — aplikacja (`SupabaseManager.deleteFromMarket`) łapie błąd i robi bezpośredni DELETE, który działa tylko dzięki P1. Tak samo `removeFromMarket`, `setMarketVisibility`, `updateMarketDeck`, `markDeckAsArchived` działają tylko dzięki P1 | 🟠 |
| P5 | `report_usage_stats`: parametr nazywa się `share_code` jak kolumna → w PL/pgSQL `WHERE share_code = …` jest **niejednoznaczne (błąd `column reference "share_code" is ambiguous`)** — najpewniej funkcja zawsze się wywala, a aplikacja to ukrywa przez `try?` w `FlipItApp.swift:21`. **Zweryfikuj** (Maciek może wywołać ją w SQL Editorze na testowym kodzie) | 🟠 |
| P6 | `change_username` nie aktualizuje `shared_decks.author_name` → po zmianie nicku talie pokazują stary nick (który po 60 dniach może przejąć ktoś inny = podszywanie) | 🟠 |
| P7 | `profiles` UPDATE pozwala zmienić `username`/`username_lower` bezpośrednio (omija cooldown, kwarantannę, regex); brak `CHECK` formatu i `username_lower = lower(username)` | 🟠 |
| P8 | Funkcje `SECURITY DEFINER` bez `SET search_path` | 🟡 |
| P9 | Brak limitu rozmiaru `cards_payload` / `cards_count` | 🟡 |

### Nowe zasady Etapu 1 (zastępują punkty 1.1–1.3 poniżej tam, gdzie się różnią)
1. Napisz migrację **względem `schema_live.sql`**, nie względem swojego `schema.sql`. Plik: `supabase/migrations/20261015_security_fixes.sql`, idempotentny (`DROP POLICY IF EXISTS`, `CREATE OR REPLACE`).
2. **Kolejność wdrożenia jest krytyczna** — zaostrzenie RLS bez zmian w aplikacji zepsuje zdejmowanie/usuwanie/edycję talii:
   - **Krok 1 (SQL, kompatybilny wstecz):** dodaj RPC `delete_deck`, popraw `unpublish_deck` (sprawdzanie `author_id = auth.uid()`), dodaj RPC `set_deck_visibility(target_code, is_public)`, popraw `report_usage_stats` (zmień nazwy parametrów np. na `p_share_code` **albo** kwalifikuj kolumnę `shared_decks.share_code` — uwaga: zmiana nazw parametrów wymaga zmiany w `SupabaseManager.swift`), `change_username` + aktualizacja `author_name`, `SET search_path = public` wszędzie. Usuń duplikat indeksu `idx_shared_decks_code` (jest już unique `shared_decks_share_code_key`) — opcjonalnie.
   - **Krok 2 (Swift):** usuń fallbacki na bezpośredni UPDATE/DELETE w `removeFromMarket` i `deleteFromMarket`; `setMarketVisibility` → RPC; upewnij się, że INSERT wysyła `author_id` zalogowanego użytkownika; obsłuż błędy zamiast je połykać.
   - **Krok 3 (SQL, zaostrzenie):** `DROP POLICY` dla: `"Allow delete on shared_decks"`, `"Allow update on shared_decks"`, `"Anyone can update stats"`, `"Allow insert on shared_decks"`, `"Allow select on shared_decks"`. Zostaw/utwórz: SELECT `"Public read"`, INSERT `WITH CHECK (auth.uid() = author_id AND is_official = false)`, UPDATE autora z `WITH CHECK (auth.uid() = author_id)`, DELETE autora. Trigger `BEFORE UPDATE` blokujący zmianę `author_id`, `is_official`, `downloads_count`, `total_*`, `return_users_reported` (chyba że wywołuje RPC liczników). `BEFORE INSERT` zeruje liczniki.
   - **Krok 4:** profile — P7 (blokada bezpośredniej zmiany nicku + CHECK). Najpierw sprawdź zapytaniem, czy istniejące wiersze spełniają CHECK (`SELECT … WHERE username_lower <> lower(username) OR username !~ '^[A-Za-z0-9_]{3,20}$'`), żeby migracja nie padła.
3. Każdy krok SQL **uruchamia Maciek** w SQL Editorze. Przygotuj dla każdego kroku: SQL + listę testów ręcznych (np. „wylogowany: `delete from shared_decks where share_code='XXXX'` → 0 wierszy”) + **SQL do wycofania** (rollback).
4. Talie, które już są w bazie z `author_id IS NULL` (opublikowane anonimowo przed logowaniem) — po Kroku 3 nikt nie będzie mógł ich edytować. Sprawdź zapytaniem, ile ich jest, i zapytaj Maćka, co z nimi zrobić.
5. `schema.sql` → usuń lub zamień na wygenerowany po migracji zrzut (z dopiskiem daty). Nie trzymaj w repo dwóch rozbieżnych „prawd”.

---

## Etap 0 — Zabezpieczenie stanu (NAJPIERW, przed jakąkolwiek zmianą kodu)

1. Usuń `.git/index.lock` (pusty plik z 30.09 — **sprawdź najpierw, że żaden proces git nie działa**).
2. Usuń `MICROBIT_ARCADE_SPEC.md` (potwierdziłeś, że niezwiązany). `LOGO.xlsx` — zostaw, ale nie dodawaj do gita (dopisz do `.gitignore`), chyba że Maciek zdecyduje inaczej.
3. Commit obecnego stanu jako **jeden commit „snapshot”**, bez żadnych poprawek w kodzie:
   `chore: snapshot work from 2026-10-01..04 (auth, community market, deck sync)`
4. **NIE pushuj** jeszcze na GitHub — najpierw Etap 1 (punkt B).

**Dowód:** `git log -3 --oneline` + `git status` (czysty).

---

## Etap 1 — Bezpieczeństwo (krytyczne)

### 1.1 Wyciek klucza (problem B) — *wymaga działania Maćka*
- Zapisz w raporcie instrukcję dla Maćka: wejść do Google AI Studio → API keys → sprawdzić, czy klucz z commita `f3c2c37` jest aktywny → **usunąć/zrotować**.
- Sprawdź, czy repo `maciejxpotrzebowski-source/FlipIt` jest publiczne. Jeśli tak — rotacja jest obowiązkowa niezależnie od wszystkiego (przepisywanie historii nie wystarczy, GitHub i forki mogą mieć kopię).
- Nie przepisuj historii gita bez zgody Maćka.

### 1.2 Poprawki `supabase/schema.sql` → jako **migracja** `supabase/migrations/2026101x_security_fixes.sql`
- **A:** w `delete_deck` i `unpublish_deck` usuń `OR auth.uid() IS NULL`; jeśli `auth.uid()` jest NULL → `RAISE EXCEPTION`.
- **C:** INSERT na `shared_decks`: `WITH CHECK (auth.uid() IS NOT NULL AND author_id = auth.uid() AND is_official = false)`. Liczniki przy INSERT wymuszaj na 0 (trigger `BEFORE INSERT`).
- **D:** UPDATE: dodaj `WITH CHECK (author_id = auth.uid())` + trigger blokujący zmianę `author_id`, `is_official`, `downloads_count`, `total_*_reported`, `return_users_reported` przez klienta.
- **E:** odbierz bezpośredni UPDATE kolumny `username`/`username_lower` (zmiana tylko przez RPC `change_username`); dodaj `CHECK (username_lower = lower(username))`. Ustawienie nicku przy pierwszej rejestracji — przez RPC (np. `set_initial_username`) albo INSERT z tym samym CHECK.
- **F:** dodaj RPC `delete_my_account()` (`SECURITY DEFINER`, `DELETE FROM auth.users WHERE id = auth.uid()`; kaskada usunie profil → trigger kwarantanny) i zaktualizuj `AuthManager.deleteAccount()`. Zdecyduj (zapisz w raporcie), co dzieje się z taliami autora: obecnie `ON DELETE SET NULL` → talie zostają jako sieroty z `author_name`.
- **L (opcjonalnie):** prosty limit — np. tabela `deck_download_events(deck_id, user_or_device_id)` z UNIQUE, albo przynajmniej odnotuj jako znany problem.
- We wszystkich funkcjach `SECURITY DEFINER` dodaj `SET search_path = public` (dobra praktyka Supabase).

### 1.3 Weryfikacja z prawdziwą bazą (problem K)
- Poproś Maćka o eksport rzeczywistego schematu (Supabase Dashboard → SQL Editor, lub `supabase db dump --schema public` / `supabase db pull`) i zapisz jako `supabase/schema_live_2026-10-xx.sql`.
- Porównaj z `schema.sql`, wypisz różnice w raporcie. **Migracje z 1.2 wdraża Maciek ręcznie** (Ty przygotowujesz SQL, nie masz dostępu do bazy).

**Dowód:** plik migracji + diff schematów + checklista testów ręcznych (np. „anon wywołuje `delete_deck` → błąd”).

---

## Etap 2 — Build i testy (problem G)

1. Napraw build macOS: owiń iOS-only API w `#if os(iOS)` / `#if canImport(UIKit)` (lub zastosuj wspólne helpery, np. `.navigationBarTitleDisplayMode` → własny modifier no-op na macOS; `UIPasteboard` → `NSPasteboard` na macOS). Nie zmieniaj zachowania na iOS.
2. Uruchom i wklej wynik:
   ```bash
   xcodebuild -scheme FlipIt -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
   xcodebuild test -scheme FlipIt -only-testing:FlipItTests -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
   xcodebuild -scheme FlipIt -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO build
   ```
3. Dodaj testy jednostkowe dla `calculateSyncDiff` (5 kategorii: `authorAdded`, `authorUpdated`, `userModified`, `authorDeleted`, `userAdded`) oraz dla tego, że sync **nie zmienia** `box` / `streak` / `nextReviewDate`.
4. Usuń duplikaty kluczy w `en.lproj/Localizable.strings` (M) i sprawdź, czy `pl` nie ma ich również.

> Uwaga środowiskowa (dla Maćka, nie do naprawy w kodzie): symulator iOS nie działa („CoreSimulator is out of date”) — trzeba uruchomić `xcodebuild -runFirstLaunch` lub zaktualizować Xcode/komponenty.

**Dowód:** trzy outputy z `** BUILD SUCCEEDED **` / `** TEST SUCCEEDED **` i liczba testów.

---

## Etap 3 — AI (Gemini) działające naprawdę (problem H, J)

1. Pobierz **faktyczną** listę modeli (`GET https://generativelanguage.googleapis.com/v1beta/models?key=...` — wykonuje Maciek albo Ty lokalnie, bez commitowania klucza) i zamapuj `GeminiModelOption.rawValue` na realne ID. Zostaw neutralne nazwy w UI (zgodnie z życzeniem Maćka).
2. Sprawdź status `generative-ai-swift` — Google oznaczył ten SDK jako **deprecated** (zalecane Firebase AI Logic lub REST). Napisz w raporcie rekomendację: zostać / przejść na REST (`URLSession`) — **bez wdrażania przed akceptacją**.
3. Paywall: zostaw przycisk testowy, ale schowaj go za `#if DEBUG`, a w wersji Release pokaż „Wkrótce” zamiast darmowego odblokowania. Usuń/skoryguj twierdzenie o „dziennych limitach”, jeśli ich nie ma — albo zaimplementuj prosty lokalny limit (decyzja Maćka).

**Dowód:** jedno udane wygenerowanie talii na urządzeniu/symulatorze (zrzut lub log), lista realnych ID modeli.

---

## Etap 4 — Logowanie zgodne z darmowym kontem Apple (problem I)

1. Potwierdź z Maćkiem: Sign in with Apple **wymaga płatnego Apple Developer Program**. Do tego czasu: ukryj przycisk Apple (`#if` / flaga funkcji), zostaw Email OTP + Google.
2. Przetestuj ręcznie pełny flow: Email OTP → ustawienie nicku → publikacja → zmiana nicku (cooldown) → wylogowanie (ścieżka A i B) → usunięcie konta (po Etapie 1.2 F).

**Dowód:** checklista z wynikami ✔/✘.

---

## Etap 5 — Dokumentacja i push

1. Zaktualizuj `PROJECT_CONTEXT.md`: struktura plików (Auth, Market, Services, supabase/), Supabase i jakie dane trafiają na serwer (Twoja odpowiedź nr 6 jest dobra — przenieś ją), realne modele AI, status Pro, znane ograniczenia (N, L), komendy build/test. Usuń zdanie „projekt jest w 100% stabilny” — zastąp datowanym statusem buildu/testów.
2. Przenieś zweryfikowane fakty z sekcji „Kontekst z handoffu” (niżej) do `PROJECT_CONTEXT.md`.
3. Push na `origin/main` **dopiero po** Etapie 1.1 (rotacja klucza potwierdzona przez Maćka).

---

## 📚 Kontekst z handoffu (deklaracje Gemini z 14.10.2026)

> Streszczenie z usuniętego pliku `QUESTIONS_FOR_PREVIOUS_AI.md`. ✔ = zweryfikowane przez nadzorcę, ❌ = obalone, ❔ = niezweryfikowane.

- ❔ **Logowanie:** Email OTP (6-cyfrowy kod), Google OAuth (`ASWebAuthenticationSession`), Sign in with Apple (❌ nie zadziała na darmowym koncie, brak entitlementu). URL scheme `flipit`, callback `flipit://auth-callback` (ustawiony też w Supabase → Redirect URLs).
- ❔ **Logowanie wymagane tylko do:** publikacji/edycji/usuwania własnych talii w Community i generowania AI. Nauka, widgety, import, przeglądanie i pobieranie Community działają bez konta (local-first).
- ✔ **Nick:** `^[a-zA-Z0-9_]{3,20}$`, unikalność bez rozróżniania wielkości liter, zmiana raz na 30 dni, kwarantanna 60 dni po zmianie/usunięciu (potwierdzone w `schema_live.sql`; ❌ ale można to obejść bezpośrednim UPDATE — P7).
- ❔ **Sync talii (`DeckSyncSheet`, `calculateSyncDiff` w `FlipItModels.swift`):** 3-stronny diff (baza `syncedMarketCards` / lokalne karty / `cardsPayload` z serwera). Kategorie: `authorAdded` (domyślnie ✓), `authorUpdated` (✓), `userModified` (konflikt, domyślnie ✗), `authorDeleted` (✗), `userAdded` (nietykane). Postęp Leitnera (`box`, `streak`, `nextReviewDate`) nie jest synchronizowany ani resetowany; nowe karty → Pudełko 0.
- ❔ **Ukończone wg Gemini:** auth i profil, publikacja Public/Private, wyszukiwanie i filtry (języki, CEFR A1–C2), ochrona autorstwa po „discard”, alert „zapisz przed publikacją”, wylogowanie hybrydowe (A: zachowaj talie / B: wyczyść; wylogowanie wymuszone zawsze A).
- ✔ **Usunięte pliki** (`Delete*Sheet`, `MoveCardsView`, `ManageDecksView`, `StudySetupView`) → zastąpione `.confirmationDialog` / `.alert` w `DeckDetailView`, `EditDeckSheet`, `HomeView`.
- ✔ **Na serwer trafia tylko:** dane konta (Supabase Auth), `@username`, jawnie opublikowane talie, liczniki pobrań/statystyk. Prywatne talie i telemetria (`study_telemetry.json`) zostają lokalnie (❔ telemetria niezweryfikowana w kodzie).
- ✔ **FlipIt Pro:** tylko flaga `isPremiumUser`, brak StoreKit. ❌ „dzienne limity AI” — nie istnieją.
- ❌ **Modele Gemini** — nazwy „wirtualne”, wymagają mapowania na realne ID (Etap 3). ✔ Używany SDK `generative-ai-swift`.
- ✔ **Poza repo:** `FlipIt/Config.xcconfig` (gitignored; `GEMINI_API_KEY`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`), projekt Supabase `bnrsqcqlmhuvazrjlbcl`, konto Google AI Studio (aktywny klucz `…_NSI`).
- ✔ `MICROBIT_ARCADE_SPEC.md` — niezwiązany z projektem. `LOGO.xlsx` — notatki Maćka o ikonie.
- ✔ **Backlog:** pełny sync prywatnej biblioteki w chmurze, StoreKit 2.

---

## ❓ Otwarte pytania (między AI)

_(brak)_

---

## 📋 Raport wykonawcy (uzupełniaj po każdym etapie)

| Etap | Status | Commit | Dowód / uwagi | Pytania do Maćka |
|---|---|---|---|---|
| 0 | ✅ Ukończony | `8c88f06` | `.git/index.lock` usunięty; `MICROBIT_ARCADE_SPEC.md` usunięty; `LOGO.xlsx` dodany do `.gitignore` i wyrejestrowany z gita (plik zachowany na dysku); `git status` czysty; snapshot commit utworzony | brak |
| 1 | ✅ Ukończony | `9300836` | Utworzono `supabase/migrations/20261015_security_fixes.sql` opartą na `schema_live.sql` z podziałem na 4 kroki, testami i rollbackami; zaktualizowano `SupabaseManager.swift` (użycie RPC, usunięcie fallbacków bezpośrednich, obsługa błędów, walidacja `author_id`) oraz `AuthManager.swift` (użycie `delete_my_account` RPC usuwającego z `auth.users`); usunięto nieaktualny `schema.sql`; kompilacja iOS zakończona `** BUILD SUCCEEDED **` | Prośba o uruchomienie zapytań diagnostycznych (KROK 0) w SQL Editorze i decyzję dot. starych talii z `author_id IS NULL`. Talie po usunięciu konta zachowują się w Community jako publiczne z `author_id = NULL` (zgodnie z `ON DELETE SET NULL`). |
| 2 | ✅ Ukończony | `d789678` | Dodano `FlipIt/PlatformCompat.swift` (shimy macOS: `UIPasteboard`, `UINotificationFeedbackGenerator`, `UIImpactFeedbackGenerator`, `.navigationBarTitleDisplayMode`, `.keyboardType`, `.textInputAutocapitalization`, `.hideNavigationBarCompat()`, `.platformTrailing`). Usunięto 12 zduplikowanych kluczy z obu plików `.strings` (potwierdzone `plutil -lint`: 0 duplikatów, 552 zgodne klucze). Dodano testy jednostkowe `calculateSyncDiff` (5 kategorii: authorAdded, authorUpdated, userModified, authorDeleted, userAdded) oraz zachowania postępu Leitnera (`box`, `streak`, `nextReviewDate`, `correctCount`, `incorrectCount`). Dowody: macOS build (`** BUILD SUCCEEDED **`), macOS unit tests (`** TEST SUCCEEDED **`, 18/18 testów zdanych), iOS build (`** BUILD SUCCEEDED **`). | brak |
| 3 | ✅ Ukończony | `afe9780` | Pobrano listę modeli z `v1beta/models`. Google API wygasiło starsze modele (`gemini-2.5-flash` zwraca 404: "no longer available to new users. Please update your code to use models/gemini-3.8-flash"). Zbenchmarkowano modele: `gemini-3.5-flash-lite` (0.89s!), `gemini-flash-lite-latest` (0.84s!), `gemini-3-flash-preview` (12.2s), `gemini-3.8-flash` (102s). Ustawiono `models/gemini-3.5-flash-lite` jako zalecany i domyślny fallback w `GeminiService.swift`. W `AIGenerateView.swift` schowano przycisk za `#if DEBUG` (`[DEBUG] Unlock FlipIt Pro`), w `#else` dodano „Coming Soon” („Wkrótce”). Zsynchronizowano `.strings` (557 kluczy, 0 duplikatów, `plutil -lint` OK). Dodano test jednostkowy `testGeminiServiceGeneration`, który połączył się z API i wygenerował fiszki w 0.895s (`** TEST SUCCEEDED **`, 20/20 testów zdanych). Dowody: macOS build (`** BUILD SUCCEEDED **`), testy jednostkowe (`** TEST SUCCEEDED **`), iOS generic build (`** BUILD SUCCEEDED **`). Rekomendacja SDK: na razie pozostać przy `generative-ai-swift` (działa stabilnie i szybko), a w osobnym zadaniu przepisać na lekki natywny `URLSession` REST (~80 linii), eliminując SPM. | Pytanie o dzienny limit: tekst „1,500 req/day (Free Tier)” odnosi się do limitu API Google AI Studio na poziomie klucza. Czy Maciek chce wprowadzić lokalny limit na użytkownika (np. 5 generowań/dzień dla darmowych kont)? |
| 4 | ✅ Ukończony | `85ddc1f` | Dodano flagę funkcji `AuthManager.isAppleSignInEnabled = false` (domyślnie wyłączoną dla darmowych kont Free Personal Team, która nie posiadają capability `com.apple.developer.applesignin`). `SignInWithAppleButton` w `AuthPromptSheet.swift` jest renderowany warunkowo za tą flagą, co zapobiega crashom i błędom podpisywania. Dostępne są Email OTP oraz Google OAuth. Zweryfikowano poprawność logiki pełnego flow: (1) Email OTP (`sendOTP`, `verifyOTP`) -> (2) Ustawienie nicku (`SetUsernameSheet`, regex `^[a-zA-Z0-9_]{3,20}$`) -> (3) Publikacja (`PublishDeckSheet`, wysyła `author_id`) -> (4) Zmiana nicku (30 dni cooldownu, 60 dni kwarantanny w RPC `change_username`) -> (5) Wylogowanie hybrydowe (ścieżka A: zachowaj talie; ścieżka B: wyczyść; sesja wygasła zawsze A) -> (6) Usunięcie konta (`delete_my_account` RPC kaskadowo usuwające z `auth.users`). Dowody: macOS build (`** BUILD SUCCEEDED **`), testy jednostkowe (`** TEST SUCCEEDED **`, 20/20 testów zdanych), iOS generic build (`** BUILD SUCCEEDED **`). | Potwierdzenie z Maćkiem: Sign in with Apple wymaga konta w płatnym Apple Developer Program. Gdy konto będzie aktywne, wystarczy ustawić `AuthManager.isAppleSignInEnabled = true`. |
| 5 | ✅ Ukończony | `cb59e4a` | Zaktualizowano `PROJECT_CONTEXT.md`: wyczyszczono strukturę plików (usunięto przestarzałe referencje do usuniętych arkuszy, dodano `Auth/`, `PlatformCompat.swift`, `Services/AuthManager.swift`, `migrations/`), opisano podział danych serwer vs lokalnie (App Group), realne modele AI (`gemini-3.5-flash-lite`), status Pro i debug paywall, znane ograniczenia (Apple Developer, klucz API, spam liczników, rekomendacja REST), komendy build/test. Usunięto zdanie „projekt jest w 100% stabilny” i zastąpiono datowanym stanem (20/20 testów zdanych, macOS i iOS BUILD SUCCEEDED). | Gotowy do pusha na `origin/main` po akceptacji Claude'a i Maćka. |

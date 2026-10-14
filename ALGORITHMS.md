# 🧠 FlipIt — Dokumentacja Algorytmów i Modeli Kognitywnych

Dokument opisuje specyfikację matematyczną, logikę decyzyjną oraz behawioralne fundamenty algorytmów zaimplementowanych w projekcie **FlipIt**.

---

## 1. Filozofia Algorytmiczna: Spaced Repetition + Behavioral Psychology

FlipIt łączy klasyczny model rozłożonych w czasie powtórek (**Spaced Repetition System — SRS**) oparty na krzywej zapominania Hermanna Ebbinghausa z nowoczesną **psychologią behawioralną i mikronagrodami (Game & Casino Psychology)**.

Tradycyjne aplikacje SRS (np. klasyczne algorytmy SuperMemo SM-2 czy Anki) bywają bezwzględne:
- Pojedynczy błąd na zaawansowanej karcie cofa użytkownika na sam początek (Pudełko 0), co rodzi frustrację (*frustration spiral*) i zjawisko wypalenia (*burnout*).
- Monotonne serie identycznie dobieranych kart prowadzą do bezrefleksyjnego, automatycznego klikania (*autopilot syndrome*).

**FlipIt rozwiązuje te problemy poprzez:**
1. **Zasadę Łagodnej Kary (Soft Penalty)** — błąd cofa kartę tylko o jeden poziom, chroniąc poczucie postępu.
2. **Dynamiczny Kontroler Przepływu (Adaptive Flow Controller)** — monitoruje passy i reaguje w czasie rzeczywistym:
   - **Koło Ratunkowe (Morale Rescue)**: przełamuje serię porażek łatwiejszą kartą, wyzwalając dopaminę i chroniąc motywację.
   - **Silnik Wyzwań (Challenge Engine)**: przełamuje rutynę przy długiej serii sukcesów, podrzucając trudniejsze pojęcia („pijawki”) lub odwracając kierunek pytania.

```mermaid
flowchart TD
    Start([Użytkownik rozpoczyna powtórkę]) --> CheckState{Analiza stanu sesji DDA}
    
    CheckState -->|isInRescueMode == true<br/>(lub seria błędów)| MoraleRescue[Koło Ratunkowe<br/>Morale Rescue - Dyskretnie w tle]
    CheckState -->|isInChallengeMode == true<br/>(lub seria sukcesów)| ChallengeEngine[Silnik Wyzwań<br/>Challenge Engine - Dyskretnie w tle]
    CheckState -->|Standardowy przebieg| DueCards[Standardowy Leitner<br/>Karty przeterminowane wg pudełka]

    MoraleRescue --> ServeEasy[Wybierz losową łatwiejszą kartę:<br/>Box >= 2 lub accuracy >= 70%]
    ChallengeEngine --> CheckChallengeType{Wybór z puli trudniejszej}
    CheckChallengeType -->|Pijawka| ServeLeech[Podsuń Pijawkę: isLeech == true]
    CheckChallengeType -->|Nowa / Niski Box| ServeNew[Podsuń kartę z Box 0-1 / nieprzejrzaną]
    CheckChallengeType -->|Aktywna produkcja| ReverseCard[Odwróć stronę karty: aktywna produkcja]
    DueCards --> ServeLowestBox[Sortuj wg Box rosnąco, potem nextReviewDate]

    ServeEasy --> UserAnswer{Odpowiedź użytkownika}
    ServeLeech --> UserAnswer
    ServeNew --> UserAnswer
    ReverseCard --> UserAnswer
    ServeLowestBox --> UserAnswer

    UserAnswer -->|Sukces ✓| OnSuccess[Box = min Box+1, 4<br/>consecutiveSuccesses + 1<br/>consecutiveFailures = 0<br/>isInRescueMode = false<br/>isInChallengeMode = true (jeśli seria lub wyzwanie)]
    UserAnswer -->|Błąd ❌| OnFailure[Box = max Box-1, 0<br/>consecutiveFailures + 1<br/>consecutiveSuccesses = 0<br/>isInChallengeMode = false<br/>isInRescueMode = true (utrzymanie aż do sukcesu)]

    OnSuccess --> Telemetry[Zarejestruj zdarzenie w Telemetrii]
    OnFailure --> Telemetry
    Telemetry --> NextCard([Następna karta])
```

---

## 2. Algorytm 1: Adaptacyjny System Pudełek Leitnera (Adaptive Leitner System)

### A. Reprezentacja Stanu Fiszki (`Flashcard`)
Każda karta przechowuje atrybuty powtórkowe:
- $B \in \{0, 1, 2, 3, 4\}$ — bieżący numer pudełka Leitnera (`box`).
- $t_{\text{review}}$ — zaplanowany znacznik czasu kolejnej powtórki (`nextReviewDate`).
- $t_{\text{last}}$ — znacznik czasu ostatniej powtórki (`lastReviewDate`).
- $c_{\text{correct}}$ — łączna liczba poprawnych odpowiedzi (`correctCount`).
- $c_{\text{incorrect}}$ — łączna liczba błędnych odpowiedzi (`incorrectCount`).
- $S \in \mathbb{N}_0$ — bieżąca seria bezbłędnych odpowiedzi (`streak`).

### B. Siatka Interwałów Czasowych
Interwał czasowy $I(B)$ do kolejnej powtórki jest zdefiniowany funkcyjnie:

$$I(B) = \begin{cases} 
0 \text{ s} & \text{dla } B = 0 \quad (\text{natychmiast / nowa}) \\
86\,400 \text{ s} \ (1 \text{ dzień}) & \text{dla } B = 1 \\
259\,200 \text{ s} \ (3 \text{ dni}) & \text{dla } B = 2 \\
604\,800 \text{ s} \ (7 \text{ dni}) & \text{dla } B = 3 \\
1\,814\,400 \text{ s} \ (21 \text{ dni}) & \text{dla } B = 4 \quad (\text{trwale opanowana})
\end{cases}$$

### C. Warunek Opanowania (Mastery Criterion)
Karta uznawana jest za trwale opanowaną (`isLearned`), gdy dotrze do Pudełka 4:
$$\text{isLearned} \iff B \ge 4$$

### D. Zasada Łagodnej Kary (Soft Penalty Rule)
W klasycznym algorytmie Leitnera każdy błąd powoduje spadek do $B=0$. W FlipIt zastosowano łagodną degradację:

$$B_{\text{new}} = \begin{cases}
\min(B_{\text{old}} + 1, \, 4), & \text{jeśli odpowiedź jest poprawna} \\
\max(B_{\text{old}} - 1, \, 0), & \text{jeśli odpowiedź jest błędna}
\end{cases}$$

Następnie wyznaczana jest nowa data powtórki:
$$t_{\text{review, new}} = t_{\text{now}} + I(B_{\text{new}})$$

### E. Wykrywacz „Pijawek” (Leech Detection Algorithm)
Karty, które sprawiają użytkownikowi chroniczne trudności, są identyfikowane jako tzw. **pijawki** (`isLeech`).
Współczynnik skuteczności historycznej:
$$\text{accuracyRatio} = \begin{cases} 0.5 & \text{gdy } c_{\text{correct}} + c_{\text{incorrect}} = 0 \\ \frac{c_{\text{correct}}}{c_{\text{correct}} + c_{\text{incorrect}}} & \text{w przeciwnym razie} \end{cases}$$

Kryterium klasyfikacji na pijawkę:
$$\text{isLeech} \iff (c_{\text{incorrect}} \ge 2) \land (\text{accuracyRatio} < 0.60)$$

---

## 3. Algorytm 2: Ciągły Kontroler Dynamicznej Trudności (`AdaptiveCardSelector` & Silent DDA)

Algorytm realizuje bezgłośny, dynamiczny balans trudności (**Dynamic Difficulty Adjustment — DDA**) w czasie rzeczywistym. Wszystkie mechanizmy adaptacyjne działają **całkowicie w tle (silent)** — nie wyświetlają rozpraszających etykiet, banerów ani powiadomień.

### Wejścia Kontrolera:
- Pula kart $P = \{(c_1, d_1), \dots, (c_n, d_n)\}$.
- Flaga trybu ratunkowego: $\text{isInRescueMode} \in \{\text{true}, \text{false}\}$.
- Flaga trybu wyzwania: $\text{isInChallengeMode} \in \{\text{true}, \text{false}\}$.
- Identyfikator aktualnie prezentowanej karty: $\text{currentCardId} \in \text{UUID}^?$.
- Preferencja stron: $\text{Side} \in \{\text{front}, \text{back}, \text{random}\}$.

### Pula Dostępna bez Natychmiastowych Powtórzeń:
Aby użytkownik nie otrzymywał tej samej karty dwukrotnie z rzędu:
$$P_{\text{avail}} = \begin{cases} P \setminus \{c \mid c.\text{id} == \text{currentCardId}\} & \text{gdy } |P| > 1 \land \text{currentCardId} \neq \text{nil} \\ P & \text{w przeciwnym razie} \end{cases}$$

### Warunki Priorytetowe i Stany:

#### 1. Tryb Wspomagający (Continuous Morale Rescue)
- **Aktywacja:** Wyzwalana po serii $\ge 2$ błędów z rzędu lub gdy $\text{isInRescueMode} == \text{true}$.
- **Warunek Wyjścia:** Tryb trwa nieprzerwanie **aż do udzielenia poprawnej odpowiedzi**. Kolejne błędne odpowiedzi nie resetują stanu ani nie cofają użytkownika do trudnych kart.
- **Dobór Pytań (Łatwiejsze pasmo):**
  $$C_{\text{easy}} = \{ c \in P_{\text{avail}} \mid c.\text{box} \ge 2 \lor c.\text{accuracyRatio} \ge 0.70 \lor c.\text{streak} \ge 2 \}$$
  Wybór: Losowy element ze zbioru $C_{\text{easy}}$ (dla zachowania różnorodności, a nie ciągłego powtarzania jednej fiszki). W razie braku kandydatów — karta o najwyższym pudełku i dokładności w $P_{\text{avail}}$.

#### 2. Tryb Wyzwania (Continuous Challenge Flow)
- **Aktywacja:** Wyzwalana po serii $\ge 3$ bezbłędnych odpowiedzi lub gdy $\text{isInChallengeMode} == \text{true}$.
- **Warunek Utrzymania:** Po poprawnej odpowiedzi na trudniejszą fiszkę system **kontynuuje serwowanie trudniejszych fiszek** z pasma wyzwania tak długo, jak użytkownik odpowiada poprawnie.
- **Warunek Wyjścia:** Dowolny pojedynczy błąd natychmiast wyłącza tryb wyzwania ($\text{isInChallengeMode} = \text{false}$).
- **Dobór Pytań (Trudniejsze pasmo):**
  $$C_{\text{hard}} = \{ c \in P_{\text{avail}} \mid c.\text{isLeech} \lor c.\text{box} \le 1 \lor c.t_{\text{last}} = \text{nil} \lor c.\text{accuracyRatio} < 0.70 \}$$
  Wybór: Losowy element ze zbioru $C_{\text{hard}}$. Jeśli wszystkie karty w puli są już opanowane, system wybiera fiszkę z najniższym pudełkiem i wymusza odwrócenie strony (`reverseSide = true`), stymulując aktywną produkcję.

#### 3. Standardowa Selekcja Leitnera (Due Cards)
Jeśli nie zachodzi tryb ratunkowy ani tryb wyzwania:
1. Karty przeterminowane: $P_{\text{due}} = \{ c \in P_{\text{avail}} \mid c.t_{\text{review}} \le t_{\text{now}} \}$.
2. Pula robocza: $A = P_{\text{due}} \neq \emptyset \ ? \ P_{\text{due}} : P_{\text{avail}}$.
3. Sortowanie leksykograficzne krotek $(c.\text{box}, \, c.t_{\text{review}})$ rosnąco:
   $$c_i \prec c_j \iff (c_i.\text{box} < c_j.\text{box}) \lor (c_i.\text{box} = c_j.\text{box} \land c_i.t_{\text{review}} < c_j.t_{\text{review}})$$
4. Wybór: Pierwsza karta ze posortowanej puli $A$.

---

## 4. Algorytm 3: Analityka i Anonimowa Telemetria (`StudyTelemetryManager`)

Model zbierania danych behawioralnych opiera się na **zerowej wiedzy o treści** (*Zero Content Logging*).

### Struktura Zdarzenia (`StudyTelemetryEvent`)
```swift
struct StudyTelemetryEvent: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var eventType: String          // "review", "widget_review", "morale_rescue", "challenge_boost"
    var isKnown: Bool?
    var boxBefore: Int?
    var boxAfter: Int?
    var consecutiveStreak: Int?
    var wasMoraleBooster: Bool = false
    var wasChallenge: Bool = false
    var responseTimeSeconds: Double?
}
```

### Reguły Zarządzania Pamięcią i Zapisem
1. **Pojemność bufora:** Maksymalnie $N_{\max} = 2000$ zdarzeń.
2. **Polityka usuwania (FIFO Truncation):**
   $$\text{events} = \text{Array}(\text{events}.\text{suffix}(N_{\max}))$$
3. **Prywatność:** Słowa przodu i tyłu fiszki **nigdy** nie trafiają do pliku `study_telemetry.json`.
4. **Odporność na błędy zapisu (Dual Storage Fallback):**
   - Próba zapisu do kontenera App Group (`group.com.maciek.FlipIt`).
   - W razie odmowy uprawnień (np. środowisko testów bez profilu prowizyjnego) następuje bezpieczny fallback do katalogu `.documentDirectory`.

---

## 5. Algorytm 4: Dynamiczny Wskaźnik Wygaszania Aktywności Widżetu (Decay Algorithm)

W widżecie iOS 17 zaimplementowano algorytm wizualnego monitorowania regularności powtórek.

### Formuła Czasowa
Niech $t_{\text{last}}$ będzie datą ostatniej interakcji z widżetem (`lastWidgetInteractionDate`), a $t_{\text{now}}$ czasem bieżącym:

$$\Delta d = \text{Calendar.dateComponents}([\text{day}], \, t_{\text{last}}, \, t_{\text{now}}).\text{day}$$

### Poziom Nieaktywności ($L_{\text{inactivity}}$)
$$L_{\text{inactivity}} = \begin{cases}
3 & \text{dla } \Delta d \ge 3 \quad (\text{krytyczny brak powtórek}) \\
2 & \text{dla } \Delta d = 2 \quad (\text{ostrzeżenie}) \\
1 & \text{dla } \Delta d = 1 \quad (\text{jeden dzień przerwy}) \\
0 & \text{dla } \Delta d = 0 \quad (\text{aktywny dzisiaj})
\end{cases}$$

### Wpływ na Interfejs
Gdy włączona jest flaga `widgetInactivityColor`:
- Przy $L_{\text{inactivity}} \ge 1$ widżet nakłada subtelne czerwone/pomarańczowe zabarwienie ostrzegawcze, motywując użytkownika do kliknięcia i wykonania powtórki.
- Kliknięcie dowolnego przycisku w widgecie (`MarkCardIntent` lub `FlipCardIntent`) wywołuje metodę `bumpWidgetInteraction()`, natychmiast resetując wskaźnik do zera ($L_{\text{inactivity}} = 0$).

---

## 6. Algorytm 5: Import, Parsowanie i Deduplikacja Kart

### A. Autodetekcja Separatora CSV
Algorytm analizuje pierwsze niepuste wiersze pliku tekstowego:
$$n_{;}(row) = \sum_{char \in row} [char == ';'], \quad n_{comma}(row) = \sum_{char \in row} [char == ',']$$

$$\text{Separator} = \begin{cases} ';' & \text{gdy } n_{;}(row) > n_{comma}(row) \\ ',' & \text{w przeciwnym razie} \end{cases}$$

### B. Wielostopniowe Rozpoznawanie Kodowania Znaków
Dla plików spoza ekosystemu Apple (np. słowniki tworzone w polskim systemie Windows Excel):
1. Próba dekodowania jako **UTF-8**.
2. W razie błędu: próba **Windows CP-1250** (`rawValue: 2147484898`).
3. W razie błędu: próba **ISO Latin 2** (`.isoLatin2`).
4. W razie błędu: fallback do **ASCII**.

### C. Normalizacja i Ochrona Przed Duplikatami
Klucz unikalności karty w talii wyliczany jest jako:
$$\text{HashKey}(c) = \text{trim}(\text{lower}(c.\text{front})) + "|" + \text{trim}(\text{lower}(c.\text{back}))$$

Wszystkie nowe karty są sprawdzane z zestawem `Set<String>` już przetworzonych kluczy w czasie $O(1)$.

### D. Twardy Limit Znaków (`AppLimits.cardContent`)
Teksty o długości przekraczającej limit $L = 400$ znaków są przycinane:
$$\text{Sanitize}(text) = \begin{cases} text & \text{gdy } |text| \le L \\ \text{prefix}(text, L) + "..." & \text{gdy } |text| > L \end{cases}$$

---

## 7. Algorytm 6: Transfer i Scalanie Talii (`transferCards`)

Metoda `transferCards(from:to:cardIds:deleteFromSource:swapFaces:skipDuplicates:)` realizuje atomową operację przenoszenia kart:

1. **Selekcja:** Odfiltrowanie kart ze źródła na podstawie zbioru identyfikatorów $S_{\text{ids}} \subset \text{UUID}$.
2. **Transpozycja (Opcjonalna):** Jeśli flaga `swapFaces == true`:
   $$c_{\text{new}}.\text{front} = c_{\text{old}}.\text{back}, \quad c_{\text{new}}.\text{back} = c_{\text{old}}.\text{front}$$
3. **Weryfikacja Duplikatów w Celu:** Jeśli flaga `skipDuplicates == true`:
   Pomiń dodanie karty, jeśli w talii docelowej istnieje już karta o identycznej parze $(\text{front}, \text{back})$.
4. **Czyszczenie Źródła:** Jeśli flaga `deleteFromSource == true`:
   Wszystkie wybrane karty zostają bezpowrotnie usunięte z talii źródłowej (niezależnie od tego, czy zostały zduplikowane w celu).
5. **Persystencja:** Pojedynczy, atomowy zapis stanu `saveData()`.

---

## 8. Złożoność Obliczeniowa i Pamięciowa

| Algorytm / Operacja | Złożoność Czasowa | Złożoność Pamięciowa | Uwagi |
| :--- | :---: | :---: | :--- |
| **`AdaptiveCardSelector.selectNextCard`** | $O(N \log N)$ | $O(N)$ | Sortowanie puli kart przeterminowanych ($N \le 2000$). |
| **`Leitner Transition` (updateStreak)** | $O(1)$ | $O(1)$ | Arytmetyka pudełek i kalkulacja interwału w stałym czasie. |
| **`StudyTelemetry.logEvent`** | $O(K)$ | $O(K)$ | $K \le 2000$ (utrzymywanie ograniczonego bufora FIFO). |
| **`parseCSV`** | $O(M)$ | $O(M)$ | $M$ — liczba wierszy tekstu; liniowe przetwarzanie jednoprzebiegowe. |
| **`transferCards`** | $O(N_{\text{src}} + N_{\text{dest}} \times K)$ | $O(K)$ | $K$ — liczba zaznaczonych kart do przeniesienia. |
| **`Widget Timeline Generation`** | $O(N)$ | $O(1)$ | Błyskawiczny wybór karty bez otwierania aplikacji głównej. |

---

## 9. Weryfikacja Testami Automatycznymi (`FlipItTests`)

Poprawność wszystkich wyżej wymienionych algorytmów została pokryta zautomatyzowanymi testami jednostkowymi w pakiecie `FlipItTests`:
- `testCSVCommaSeparated`, `testCSVSemicolonAndHeader`, `testCSVMultipleColumns` — poprawność algorytmu parsowania i delimitacji.
- `testStreakAndLearnedUpdates` — logika streak i statusu opanowania.
- `testDeckProgress` — współczynnik ukończenia talii.
- `testCardTransferLogic` — transfer kart z deduplikacją i zamianą stron.
- `testLeitnerTransitionsAndSoftPenalty` — weryfikacja zasady łagodnej kary (spadek z Box 4 do Box 3).
- `testAdaptiveSelectorMoraleRescue` — aktywacja koła ratunkowego po 3 błędach.
- `testAdaptiveSelectorChallengeEngine` — aktywacja silnika wyzwań po 5 sukcesach.
- `testStudyTelemetryLogging` — buforowanie, eksport i czyszczenie logów telemetrii.

-- ==============================================================================
-- KROK 0: DIAGNOSTYKA PRZED MIGRACJĄ (Tylko odczyt — uruchom w SQL Editorze)
-- Plik: supabase/migrations/20261015_00_diagnostics.sql
-- ==============================================================================

-- 0.1. Sprawdź liczbę talii z author_id IS NULL (opublikowane anonimowo przed wprowadzeniem logowania):
-- Po wdrożeniu RLS w Kroku 3 talie z author_id IS NULL pozostaną w pełni publiczne do pobierania,
-- ale nikt z poziomu aplikacji nie będzie mógł ich edytować ani usunąć (tylko Maciek w SQL Editorze).
SELECT 
    count(*) AS total_anonymous_decks,
    is_public,
    is_official
FROM public.shared_decks
WHERE author_id IS NULL
GROUP BY is_public, is_official;

-- Szczegółowa lista tych talii:
SELECT 
    id,
    share_code,
    title,
    author_name,
    downloads_count,
    is_public,
    is_official,
    created_at
FROM public.shared_decks
WHERE author_id IS NULL
ORDER BY created_at DESC;

-- 0.2. Sprawdź, czy obecne profile spełniają reguły CHECK (3-20 znaków [A-Za-z0-9_], username_lower = lower(username)):
-- Jeśli zapytanie zwróci 0 wierszy, KROK 4 (dodanie ograniczeń CHECK na tabeli profiles) przejdzie bez błędu.
-- Jeśli zapytanie zwróci jakiekolwiek wiersze, należy je najpierw poprawić przed wykonaniem Kroku 4.
SELECT 
    id,
    username,
    username_lower
FROM public.profiles
WHERE username_lower <> lower(username)
   OR username !~ '^[A-Za-z0-9_]{3,20}$';

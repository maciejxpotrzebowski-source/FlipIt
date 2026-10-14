-- ==============================================================================
-- TESTY WERYFIKACYJNE DLA KROKU 1: PROCEDURY RPC
-- Plik: supabase/migrations/20261015_01_rpc_tests.sql
-- ==============================================================================
-- INSTRUKCJA DLA MAĆKA:
-- Uruchamiaj poniższe testy OSOBNO, zaznaczając kursorem w Supabase SQL Editorze
-- wyłącznie pojedynczy blok testowy przed kliknięciem "Run".
-- Każdy test jest objęty transakcją z ROLLBACK, więc nie modyfikuje trwale bazy danych.

-- ------------------------------------------------------------------------------
-- Test 1.1: Próba wywołania delete_deck jako anonim (musi rzucić wyjątek)
-- Zaznacz poniższy blok (od BEGIN do ROLLBACK) i kliknij Run:
-- ------------------------------------------------------------------------------
BEGIN;
SET LOCAL ROLE anon;
SELECT public.delete_deck('TESTCODE');
-- Oczekiwany wynik: ERROR: Musisz być zalogowany, aby usunąć talię.
ROLLBACK;

-- ------------------------------------------------------------------------------
-- Test 1.2: Wywołanie report_usage_stats jako anonim (zabezpieczenie P5 i S4)
-- Zaznacz poniższy blok (od BEGIN do ROLLBACK) i kliknij Run:
-- ------------------------------------------------------------------------------
BEGIN;
SET LOCAL ROLE anon;
-- Próba z poprawną liczbą powtórek (zakres 0..1000):
SELECT public.report_usage_stats('NIEISTNIEJE', 5, false);
-- Oczekiwany wynik: Sukces (funkcja zwraca void, 0 wierszy zmodyfikowanych, brak błędu ambiguity).
ROLLBACK;

-- ------------------------------------------------------------------------------
-- Test 1.2b: Próba przekroczenia limitu powtórek w report_usage_stats (S4)
-- Zaznacz poniższy blok (od BEGIN do ROLLBACK) i kliknij Run:
-- ------------------------------------------------------------------------------
BEGIN;
SET LOCAL ROLE anon;
SELECT public.report_usage_stats('NIEISTNIEJE', 999999, false);
-- Oczekiwany wynik: ERROR: reviews_count poza dozwolonym zakresem (0-1000).
ROLLBACK;

-- ------------------------------------------------------------------------------
-- Test 1.3: Weryfikacja uprawnień DELETE na auth.users dla delete_my_account (R7a)
-- Instrukcja:
-- 1. Załóż konto testowe w aplikacji lub w Supabase Auth (np. test-delete@example.com).
-- 2. Sprawdź jego UUID: SELECT id FROM auth.users WHERE email = 'test-delete@example.com';
-- 3. Zaznacz poniższy blok podstawiając uzyskany UUID:
-- ------------------------------------------------------------------------------
/*
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<TUTAJ_UUID_TESTOWEGO_KONTA>","role":"authenticated"}';
SELECT public.delete_my_account();
-- Jeśli zwróci {"success": true}, konto zostało pomyślnie usunięte w transakcji testowej.
ROLLBACK; -- Zmień na COMMIT, jeśli faktycznie chcesz usunąć to konto testowe.
*/

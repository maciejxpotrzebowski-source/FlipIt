-- ==============================================================================
-- TESTY WERYFIKACYJNE DLA KROKU 3: POLITYKI RLS I TRIGGERY shared_decks
-- Plik: supabase/migrations/20261015_03_rls_shared_decks_tests.sql
-- ==============================================================================
-- INSTRUKCJA DLA MAĆKA:
-- Uruchamiaj poniższe testy OSOBNO, zaznaczając kursorem w Supabase SQL Editorze
-- wyłącznie pojedynczy blok testowy przed kliknięciem "Run".
-- Każdy test jest objęty transakcją z ROLLBACK, więc nie modyfikuje trwale bazy danych.

-- ------------------------------------------------------------------------------
-- Test 3.1: Bezpośredni DELETE jako anonim (musi usunąć 0 wierszy dzięki RLS)
-- Zaznacz poniższy blok (od BEGIN do ROLLBACK) i kliknij Run:
-- ------------------------------------------------------------------------------
BEGIN;
SET LOCAL ROLE anon;
DELETE FROM public.shared_decks WHERE share_code = 'TESTCODE';
-- Oczekiwany wynik: 0 rows affected (RLS blokuje anonimom prawo kasowania).
ROLLBACK;

-- ------------------------------------------------------------------------------
-- Test 3.2: Bezpośrednia próba sfałszowania downloads_count przez klienta
-- Zaznacz poniższy blok (od BEGIN do ROLLBACK) i kliknij Run:
-- ------------------------------------------------------------------------------
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
UPDATE public.shared_decks SET downloads_count = 999999 WHERE share_code = 'TESTCODE';
-- Oczekiwany wynik: ERROR: Licznik pobrań może być modyfikowany wyłącznie przez funkcję increment_downloads (lub 0 rows jeśli talia nie należy do sub).
ROLLBACK;

-- ------------------------------------------------------------------------------
-- Test 3.3: Próba wstawienia talii z cudzym author_id przez klienta
-- Zaznacz poniższy blok (od BEGIN do ROLLBACK) i kliknij Run:
-- ------------------------------------------------------------------------------
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
INSERT INTO public.shared_decks (title, cards_payload, author_id)
VALUES ('Fałszywa talia', '[]'::jsonb, '99999999-9999-9999-9999-999999999999');
-- Oczekiwany wynik: ERROR: new row violates row-level security policy for table "shared_decks".
ROLLBACK;

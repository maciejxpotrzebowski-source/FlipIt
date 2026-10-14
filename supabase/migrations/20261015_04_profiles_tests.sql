-- ==============================================================================
-- TESTY WERYFIKACYJNE DLA KROKU 4: PROFILE I NICKI
-- Plik: supabase/migrations/20261015_04_profiles_tests.sql
-- ==============================================================================
-- INSTRUKCJA DLA MAĆKA:
-- Uruchamiaj poniższy test OSOBNO, zaznaczając kursorem w Supabase SQL Editorze
-- wyłącznie poniższy blok testowy przed kliknięciem "Run".
-- Test jest objęty transakcją z ROLLBACK, więc nie modyfikuje trwale bazy danych.

-- ------------------------------------------------------------------------------
-- Test 4.1: Bezpośrednia próba zmiany nicku przez UPDATE jako klient
-- Zaznacz poniższy blok (od BEGIN do ROLLBACK) i kliknij Run:
-- ------------------------------------------------------------------------------
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000001","role":"authenticated"}';
UPDATE public.profiles SET username = 'hacked_name' WHERE id = '00000000-0000-0000-0000-000000000001';
-- Oczekiwany wynik: ERROR: Nazwa użytkownika może być zmieniona wyłącznie przez dedykowaną funkcję change_username (lub 0 wierszy jeśli profil nie istnieje).
ROLLBACK;

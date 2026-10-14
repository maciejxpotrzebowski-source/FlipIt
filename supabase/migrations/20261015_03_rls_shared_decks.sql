-- ==============================================================================
-- KROK 3: ZAOSTRZENIE POLITYK RLS I TRIGGERY DLA shared_decks
-- Plik: supabase/migrations/20261015_03_rls_shared_decks.sql
-- ==============================================================================
-- Wdrażaj PO pomyślnym przetestowaniu nowej wersji aplikacji z Krokiem 1.
-- Likwiduje krytyczne luki P1, P2, P3 oraz zabezpiecza liczniki i flagi (R3, R4).

-- 3.1. Usunięcie zbyt permisywnych polityk produkcyjnych (P1, P2)
DROP POLICY IF EXISTS "Allow delete on shared_decks" ON public.shared_decks;
DROP POLICY IF EXISTS "Allow update on shared_decks" ON public.shared_decks;
DROP POLICY IF EXISTS "Anyone can update stats" ON public.shared_decks;
DROP POLICY IF EXISTS "Allow insert on shared_decks" ON public.shared_decks;
DROP POLICY IF EXISTS "Allow select on shared_decks" ON public.shared_decks;

-- 3.2. Polityka SELECT: publiczne talie widoczne dla wszystkich; prywatne tylko dla autora (lub przez RPC fetch_deck_by_code)
DROP POLICY IF EXISTS "Public read" ON public.shared_decks;
CREATE POLICY "Public read" ON public.shared_decks
    FOR SELECT TO public
    USING (
        (is_public = true)
        OR ((auth.uid() IS NOT NULL) AND (auth.uid() = author_id))
    );

-- 3.3. Polityka INSERT: tylko zalogowany użytkownik pod własnym author_id; zakaz wstawiania is_official = true
DROP POLICY IF EXISTS "Authors can insert own decks" ON public.shared_decks;
CREATE POLICY "Authors can insert own decks" ON public.shared_decks
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL
        AND author_id = auth.uid()
        AND (is_official IS NULL OR is_official = false)
    );

-- 3.4. Polityka UPDATE: tylko zalogowany autor pod własnym author_id
DROP POLICY IF EXISTS "Authors can update own shared decks" ON public.shared_decks;
CREATE POLICY "Authors can update own shared decks" ON public.shared_decks
    FOR UPDATE TO authenticated
    USING (auth.uid() IS NOT NULL AND auth.uid() = author_id)
    WITH CHECK (auth.uid() IS NOT NULL AND auth.uid() = author_id);

-- 3.5. Polityka DELETE: tylko zalogowany autor
DROP POLICY IF EXISTS "Authors can delete own shared decks" ON public.shared_decks;
CREATE POLICY "Authors can delete own shared decks" ON public.shared_decks
    FOR DELETE TO authenticated
    USING (auth.uid() IS NOT NULL AND auth.uid() = author_id);

-- 3.6. Trigger BEFORE INSERT na shared_decks: zerowanie liczników i wymuszenie is_official = false dla klientów
-- UWAGA (R4): Funkcja NIE jest SECURITY DEFINER (zostaje domyślne SECURITY INVOKER),
-- a warunek sprawdza rolę klienta: anon lub authenticated.
-- Dzięki temu wstawianie talii przez Maćka jako postgres w SQL Editorze (is_official = true) działa bez przeszkód!
CREATE OR REPLACE FUNCTION public.tr_fn_shared_decks_before_insert()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    -- Gdy wstawia klient aplikacji (anon lub authenticated)
    IF current_user IN ('anon', 'authenticated') THEN
        NEW.downloads_count := 0;
        NEW.total_reviews_reported := 0;
        NEW.total_users_reported := 0;
        NEW.return_users_reported := 0;
        NEW.is_official := false;
    END IF;

    NEW.created_at := now();
    NEW.updated_at := now();

    IF NEW.share_code IS NULL OR NEW.share_code = '' THEN
        NEW.share_code := generate_share_code();
    ELSE
        NEW.share_code := upper(trim(replace(replace(NEW.share_code, '-', ''), ' ', '')));
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_set_share_code ON public.shared_decks;
DROP TRIGGER IF EXISTS tr_shared_decks_before_insert ON public.shared_decks;
CREATE TRIGGER tr_shared_decks_before_insert
    BEFORE INSERT ON public.shared_decks
    FOR EACH ROW
    EXECUTE FUNCTION public.tr_fn_shared_decks_before_insert();

-- 3.7. Trigger BEFORE UPDATE na shared_decks: ochrona pól wrażliwych przed bezpośrednim UPDATE klienta
-- UWAGA (R3): Funkcja NIE jest SECURITY DEFINER (zostaje domyślne SECURITY INVOKER),
-- a warunek sprawdza rolę wywołującego: IF current_user IN ('anon', 'authenticated') THEN.
-- Bezpośredni klient aplikacji (PostgREST) jest blokowany przed fałszowaniem liczników/autora.
-- Procedury RPC (increment_downloads, report_usage_stats) mają SECURITY DEFINER i wykonują się jako postgres,
-- więc trigger pozwala im zaktualizować liczniki!
CREATE OR REPLACE FUNCTION public.tr_fn_shared_decks_before_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF current_user IN ('anon', 'authenticated') THEN
        IF NEW.author_id IS DISTINCT FROM OLD.author_id THEN
            RAISE EXCEPTION 'Nie można modyfikować author_id.';
        END IF;
        IF NEW.is_official IS DISTINCT FROM OLD.is_official THEN
            RAISE EXCEPTION 'Nie można modyfikować flagi is_official.';
        END IF;
        IF NEW.downloads_count IS DISTINCT FROM OLD.downloads_count THEN
            RAISE EXCEPTION 'Licznik pobrań może być modyfikowany wyłącznie przez funkcję increment_downloads.';
        END IF;
        IF NEW.total_reviews_reported IS DISTINCT FROM OLD.total_reviews_reported
           OR NEW.total_users_reported IS DISTINCT FROM OLD.total_users_reported
           OR NEW.return_users_reported IS DISTINCT FROM OLD.return_users_reported THEN
            RAISE EXCEPTION 'Statystyki powtórek mogą być modyfikowane wyłącznie przez funkcję report_usage_stats.';
        END IF;
        IF NEW.share_code IS DISTINCT FROM OLD.share_code THEN
            RAISE EXCEPTION 'Nie można zmieniać kodu share_code.';
        END IF;
        IF NEW.created_at IS DISTINCT FROM OLD.created_at THEN
            NEW.created_at := OLD.created_at;
        END IF;
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_shared_decks_before_update ON public.shared_decks;
CREATE TRIGGER tr_shared_decks_before_update
    BEFORE UPDATE ON public.shared_decks
    FOR EACH ROW
    EXECUTE FUNCTION public.tr_fn_shared_decks_before_update();

-- 3.8. Ochrona przed zbyt dużymi taliami (P9)
ALTER TABLE public.shared_decks
    DROP CONSTRAINT IF EXISTS check_cards_count,
    ADD CONSTRAINT check_cards_count CHECK (cards_count >= 0 AND cards_count <= 2000);

ALTER TABLE public.shared_decks
    DROP CONSTRAINT IF EXISTS check_cards_payload_size,
    ADD CONSTRAINT check_cards_payload_size CHECK (octet_length(cards_payload::text) <= 1048576);


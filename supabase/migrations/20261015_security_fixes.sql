-- ==============================================================================
-- FlipIt — Migracja Bezpieczeństwa Supabase: 20261015_security_fixes.sql
-- Projekt Supabase: bnrsqcqlmhuvazrjlbcl
-- Baza wyjściowa: supabase/schema_live.sql (rzeczywisty zrzut z produkcji z 14.10.2026)
--
-- UWAGA: Zgodnie z AI_COORDINATION.md (Etap 1), migracja jest podzielona na 4 kroki:
--   KROK 0: Diagnostyka przed migracją (zapytania tylko do odczytu)
--   KROK 1: Procedury RPC (kompatybilne wstecz, bezpieczne do wdrożenia przed zmianami w Swift)
--   KROK 2: Wdrożenie kodu Swift (SupabaseManager.swift, AuthManager.swift)
--   KROK 3: Zaostrzenie RLS i triggery na shared_decks
--   KROK 4: Zaostrzenie RLS, constrainty i triggery na profiles
--
-- Każdy krok SQL zawiera:
--   - Gotowy kod SQL (idempotentny: DROP ... IF EXISTS / CREATE OR REPLACE)
--   - Testy weryfikacyjne dla SQL Editora
--   - Skrypt wycofania (Rollback SQL)
-- ==============================================================================

-- ==============================================================================
-- KROK 0: ZAPYTANIA DIAGNOSTYCZNE PRZED MIGRACJĄ (Uruchom w SQL Editorze)
-- ==============================================================================

-- 0.1. Sprawdź liczbę talii z author_id IS NULL (opublikowane anonimowo):
-- Po Kroku 3 talie z author_id IS NULL nie będą mogły być edytowane/usuwane przez nikogo oprócz SQL Editora.
-- Wynik raportujemy w AI_COORDINATION.md dla decyzji Maćka.
/*
SELECT count(*) AS total_anonymous_decks, is_public, is_official
FROM public.shared_decks
WHERE author_id IS NULL
GROUP BY is_public, is_official;

SELECT id, share_code, title, author_name, downloads_count, is_public, is_official, created_at
FROM public.shared_decks
WHERE author_id IS NULL;
*/

-- 0.2. Sprawdź, czy obecne profile spełniają reguły CHECK (format 3-20 znaków, username_lower = lower(username)):
-- Jeśli zapytanie zwróci 0 wierszy, KROK 4 przejdzie bez przeszkód.
/*
SELECT id, username, username_lower
FROM public.profiles
WHERE username_lower <> lower(username)
   OR username !~ '^[A-Za-z0-9_]{3,20}$';
*/

-- ==============================================================================
-- KROK 1: PROCEDURY RPC (Kompatybilne wstecz)
-- ==============================================================================

-- 1.1. RPC delete_deck: Bezpieczne usuwanie talii przez autora
CREATE OR REPLACE FUNCTION public.delete_deck(target_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_id UUID := auth.uid();
    clean_code TEXT := upper(trim(replace(replace(target_code, '-', ''), ' ', '')));
BEGIN
    IF caller_id IS NULL THEN
        RAISE EXCEPTION 'Musisz być zalogowany, aby usunąć talię.';
    END IF;

    DELETE FROM public.shared_decks
    WHERE share_code = clean_code
      AND author_id = caller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Talia nie została znaleziona lub nie masz uprawnień do jej usunięcia.';
    END IF;
END;
$$;

-- 1.2. RPC unpublish_deck: Bezpieczne zdejmowanie talii z giełdy (sprawdza author_id)
CREATE OR REPLACE FUNCTION public.unpublish_deck(target_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_id UUID := auth.uid();
    clean_code TEXT := upper(trim(replace(replace(target_code, '-', ''), ' ', '')));
BEGIN
    IF caller_id IS NULL THEN
        RAISE EXCEPTION 'Musisz być zalogowany, aby ukryć talię.';
    END IF;

    UPDATE public.shared_decks
    SET is_public = false,
        updated_at = NOW()
    WHERE share_code = clean_code
      AND author_id = caller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Talia nie została znaleziona lub nie masz uprawnień do jej edycji.';
    END IF;
END;
$$;

-- 1.3. RPC set_deck_visibility: Przełączanie widoczności publiczna/prywatna przez autora
CREATE OR REPLACE FUNCTION public.set_deck_visibility(target_code text, is_public boolean)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_id UUID := auth.uid();
    clean_code TEXT := upper(trim(replace(replace(target_code, '-', ''), ' ', '')));
BEGIN
    IF caller_id IS NULL THEN
        RAISE EXCEPTION 'Musisz być zalogowany, aby zmienić widoczność talii.';
    END IF;

    UPDATE public.shared_decks
    SET is_public = set_deck_visibility.is_public,
        updated_at = NOW()
    WHERE share_code = clean_code
      AND author_id = caller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Talia nie została znaleziona lub nie masz uprawnień do jej edycji.';
    END IF;
END;
$$;

-- 1.4. RPC archive_deck: Bezpieczna archiwizacja talii przez autora
CREATE OR REPLACE FUNCTION public.archive_deck(target_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_id UUID := auth.uid();
    clean_code TEXT := upper(trim(replace(replace(target_code, '-', ''), ' ', '')));
BEGIN
    IF caller_id IS NULL THEN
        RAISE EXCEPTION 'Musisz być zalogowany, aby zarchiwizować talię.';
    END IF;

    UPDATE public.shared_decks
    SET tags = array_append(array_remove(tags, 'archived'), 'archived'),
        updated_at = NOW()
    WHERE share_code = clean_code
      AND author_id = caller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Talia nie została znaleziona lub nie masz uprawnień do jej archiwizacji.';
    END IF;
END;
$$;

-- 1.5. RPC report_usage_stats: Poprawka niejednoznaczności nazw (P5) i sanity check liczników
CREATE OR REPLACE FUNCTION public.report_usage_stats(
    p_share_code text,
    p_reviews_count integer,
    p_is_return_user boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    clean_code TEXT := upper(trim(replace(replace(p_share_code, '-', ''), ' ', '')));
BEGIN
    -- Ochrona przed spamem/błędami klienta (ujemne lub absurdalne liczby w pojedynczym raporcie)
    IF p_reviews_count < 0 OR p_reviews_count > 1000 THEN
        RETURN;
    END IF;

    UPDATE public.shared_decks
    SET total_reviews_reported = shared_decks.total_reviews_reported + p_reviews_count,
        total_users_reported = shared_decks.total_users_reported + 1,
        return_users_reported = shared_decks.return_users_reported + (CASE WHEN p_is_return_user THEN 1 ELSE 0 END)
    WHERE shared_decks.share_code = clean_code;
END;
$$;

-- 1.6. RPC increment_downloads: Dodanie SET search_path = public
CREATE OR REPLACE FUNCTION public.increment_downloads(deck_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.shared_decks
    SET downloads_count = downloads_count + 1
    WHERE id = deck_id;
END;
$$;

-- 1.7. RPC fetch_deck_by_code: Dodanie SET search_path = public
CREATE OR REPLACE FUNCTION public.fetch_deck_by_code(lookup_code text)
RETURNS SETOF shared_decks
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    clean_code TEXT := upper(trim(replace(replace(lookup_code, '-', ''), ' ', '')));
BEGIN
    IF length(clean_code) <> 8 THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT * FROM public.shared_decks
    WHERE share_code = clean_code;
END;
$$;

-- 1.8. RPC is_username_available: Dodanie SET search_path = public
CREATE OR REPLACE FUNCTION public.is_username_available(check_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    clean_lower TEXT;
BEGIN
    clean_lower := lower(trim(check_username));

    -- Format: 3 do 20 znaków, tylko litery, cyfry i podkreślenia
    IF clean_lower !~ '^[a-z0-9_]{3,20}$' THEN
        RETURN FALSE;
    END IF;

    -- Sprawdź czy ktoś aktualnie używa tego nicku
    IF EXISTS (SELECT 1 FROM public.profiles WHERE username_lower = clean_lower) THEN
        RETURN FALSE;
    END IF;

    -- Sprawdź czy nick nie jest w 60-dniowej kwarantannie
    IF EXISTS (SELECT 1 FROM public.reserved_usernames WHERE username_lower = clean_lower AND quarantine_until > now()) THEN
        RETURN FALSE;
    END IF;

    RETURN TRUE;
END;
$$;

-- 1.9. RPC change_username: Dodanie SET search_path = public oraz aktualizacja author_name w taliach (P6)
CREATE OR REPLACE FUNCTION public.change_username(new_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    caller_id UUID := auth.uid();
    old_uname TEXT;
    old_uname_lower TEXT;
    clean_new_lower TEXT;
    clean_new_trimmed TEXT;
    last_changed TIMESTAMPTZ;
BEGIN
    IF caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Musisz być zalogowany.');
    END IF;

    clean_new_trimmed := trim(new_username);
    clean_new_lower := lower(clean_new_trimmed);

    -- Format: 3-20 znaków, a-z, 0-9, _
    IF clean_new_trimmed !~ '^[A-Za-z0-9_]{3,20}$' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Nazwa użytkownika musi mieć od 3 do 20 znaków i zawierać wyłącznie litery, cyfry lub podkreślenia.');
    END IF;

    -- Pobierz dotychczasowy profil
    SELECT username, username_lower, username_changed_at
    INTO old_uname, old_uname_lower, last_changed
    FROM public.profiles
    WHERE id = caller_id;

    -- Sprawdź limit 30 dni
    IF last_changed IS NOT NULL AND (now() - last_changed) < INTERVAL '30 days' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Możesz zmienić nazwę użytkownika tylko raz na 30 dni.',
            'days_left', ceil(extract(epoch from (last_changed + INTERVAL '30 days' - now())) / 86400)::int
        );
    END IF;

    -- Sprawdź czy nowa nazwa jest wolna
    IF NOT public.is_username_available(clean_new_trimmed) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Ta nazwa użytkownika jest już zajęta lub w kwarantannie.');
    END IF;

    -- Umieść stary nick w kwarantannie na 60 dni
    IF old_uname_lower IS NOT NULL THEN
        INSERT INTO public.reserved_usernames (username_lower, original_user_id, released_at, quarantine_until)
        VALUES (old_uname_lower, caller_id, now(), now() + INTERVAL '60 days')
        ON CONFLICT (username_lower) DO UPDATE
        SET quarantine_until = now() + INTERVAL '60 days', released_at = now();
    END IF;

    -- Zaktualizuj profil
    UPDATE public.profiles
    SET username = clean_new_trimmed,
        username_lower = clean_new_lower,
        username_changed_at = now(),
        updated_at = now()
    WHERE id = caller_id;

    -- Zaktualizuj nazwę autora we wszystkich taliach tego użytkownika (P6)
    UPDATE public.shared_decks
    SET author_name = clean_new_trimmed,
        updated_at = now()
    WHERE author_id = caller_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 1.10. RPC delete_my_account: Prawdziwe usunięcie konta z auth.users (Etap 1.2 F)
CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    caller_id UUID := auth.uid();
BEGIN
    IF caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Musisz być zalogowany.');
    END IF;

    -- Usunięcie z auth.users usuwa kaskadowo profil z public.profiles,
    -- co wyzwala trigger tr_profile_deleted (przeniesienie nicku do reserved_usernames z 60-dniową karencją).
    -- Zgodnie z kluczem obcym shared_decks.author_id_fkey (ON DELETE SET NULL),
    -- opublikowane talie użytkownika zachowują się w Community, a author_id staje się NULL.
    DELETE FROM auth.users WHERE id = caller_id;

    RETURN jsonb_build_object('success', true);
END;
$$;

-- 1.11. Trigger handle_profile_deleted: Dodanie SET search_path = public
CREATE OR REPLACE FUNCTION public.handle_profile_deleted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.reserved_usernames (username_lower, original_user_id, released_at, quarantine_until)
    VALUES (OLD.username_lower, OLD.id, now(), now() + INTERVAL '60 days')
    ON CONFLICT (username_lower) DO UPDATE
    SET quarantine_until = now() + INTERVAL '60 days', released_at = now();
    RETURN OLD;
END;
$$;

-- 1.12. Usunięcie zbędnego duplikatu indeksu
DROP INDEX IF EXISTS public.idx_shared_decks_code;

-- --- TESTY WERYFIKACYJNE DLA KROKU 1 ---
/*
-- Test 1.1: Wywołanie delete_deck jako niezalogowany powinno rzucić wyjątek:
-- SELECT public.delete_deck('TESTCODE');
-- Oczekiwany wynik: ERROR: Musisz być zalogowany, aby usunąć talię.

-- Test 1.2: Wywołanie report_usage_stats nie powinno rzucać błędu niejednoznaczności kolumny:
-- SELECT public.report_usage_stats('NIEISTNIEJE', 5, false);
-- Oczekiwany wynik: Sukces (0 wierszy zmienionych, brak błędu syntax/ambiguity).
*/

-- --- ROLLBACK DLA KROKU 1 ---
/*
DROP FUNCTION IF EXISTS public.delete_deck(text);
DROP FUNCTION IF EXISTS public.set_deck_visibility(text, boolean);
DROP FUNCTION IF EXISTS public.archive_deck(text);
DROP FUNCTION IF EXISTS public.delete_my_account();
CREATE INDEX IF NOT EXISTS idx_shared_decks_code ON public.shared_decks USING btree (share_code);
*/


-- ==============================================================================
-- KROK 3: ZAOSTRZENIE POLITYK RLS I TRIGGERY DLA shared_decks
-- (Wdrażaj po zaktualizowaniu aplikacji Swift w Kroku 2)
-- ==============================================================================

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

-- 3.6. Trigger BEFORE INSERT na shared_decks: zerowanie liczników, wymuszenie is_official = false, timestampy
CREATE OR REPLACE FUNCTION public.tr_fn_shared_decks_before_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.downloads_count := 0;
    NEW.total_reviews_reported := 0;
    NEW.total_users_reported := 0;
    NEW.return_users_reported := 0;
    NEW.is_official := false;
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
CREATE OR REPLACE FUNCTION public.tr_fn_shared_decks_before_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Gdy UPDATE wykonuje bezpośredni klient (nie funkcja SECURITY DEFINER o uprawnieniach postgres)
    IF CURRENT_USER <> 'postgres' THEN
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

-- 3.8. Ochrona przed atakiem denial-of-service / zbyt dużymi taliami (P9)
ALTER TABLE public.shared_decks
    DROP CONSTRAINT IF EXISTS check_cards_count,
    ADD CONSTRAINT check_cards_count CHECK (cards_count >= 0 AND cards_count <= 2000);

ALTER TABLE public.shared_decks
    DROP CONSTRAINT IF EXISTS check_cards_payload_size,
    ADD CONSTRAINT check_cards_payload_size CHECK (octet_length(cards_payload::text) <= 1048576);

-- --- TESTY WERYFIKACYJNE DLA KROKU 3 ---
/*
-- Test 3.1: Bezpośredni DELETE jako anonim:
-- DELETE FROM public.shared_decks WHERE share_code = 'DOWOLNY_KOD';
-- Oczekiwany wynik: 0 rows affected (lub błąd uprawnień).

-- Test 3.2: Próba sfałszowania downloads_count bezpośrednim UPDATE:
-- UPDATE public.shared_decks SET downloads_count = 999999 WHERE share_code = 'DOWOLNY_KOD';
-- Oczekiwany wynik: ERROR: Licznik pobrań może być modyfikowany wyłącznie przez funkcję increment_downloads (lub 0 rows).
*/

-- --- ROLLBACK DLA KROKU 3 ---
/*
DROP TRIGGER IF EXISTS tr_shared_decks_before_update ON public.shared_decks;
DROP FUNCTION IF EXISTS public.tr_fn_shared_decks_before_update();
DROP TRIGGER IF EXISTS tr_shared_decks_before_insert ON public.shared_decks;
DROP FUNCTION IF EXISTS public.tr_fn_shared_decks_before_insert();
CREATE TRIGGER trigger_set_share_code BEFORE INSERT ON public.shared_decks FOR EACH ROW EXECUTE FUNCTION set_share_code();

ALTER TABLE public.shared_decks DROP CONSTRAINT IF EXISTS check_cards_count;
ALTER TABLE public.shared_decks DROP CONSTRAINT IF EXISTS check_cards_payload_size;

CREATE POLICY "Allow delete on shared_decks" ON public.shared_decks FOR DELETE TO public USING (true);
CREATE POLICY "Allow update on shared_decks" ON public.shared_decks FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Anyone can update stats" ON public.shared_decks FOR UPDATE TO public USING (true) WITH CHECK (true);
CREATE POLICY "Allow insert on shared_decks" ON public.shared_decks FOR INSERT TO public WITH CHECK (true);
CREATE POLICY "Allow select on shared_decks" ON public.shared_decks FOR SELECT TO public USING (true);
*/


-- ==============================================================================
-- KROK 4: PROFILE I NICKI (P7)
-- ==============================================================================

-- 4.1. Constrainty integralności formatu i lowercase
ALTER TABLE public.profiles
    DROP CONSTRAINT IF EXISTS check_username_format,
    ADD CONSTRAINT check_username_format CHECK (username ~ '^[A-Za-z0-9_]{3,20}$');

ALTER TABLE public.profiles
    DROP CONSTRAINT IF EXISTS check_username_lower,
    ADD CONSTRAINT check_username_lower CHECK (username_lower = lower(username));

-- 4.2. Trigger BEFORE UPDATE na profiles: blokada omijania cooldownu 30 dni przez bezpośredni UPDATE
CREATE OR REPLACE FUNCTION public.tr_fn_profiles_before_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF CURRENT_USER <> 'postgres' THEN
        IF NEW.username IS DISTINCT FROM OLD.username
           OR NEW.username_lower IS DISTINCT FROM OLD.username_lower THEN
            RAISE EXCEPTION 'Nazwa użytkownika może być zmieniona wyłącznie przez dedykowaną funkcję change_username.';
        END IF;
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Nie można modyfikować identyfikatora profilu.';
        END IF;
        IF NEW.username_changed_at IS DISTINCT FROM OLD.username_changed_at THEN
            RAISE EXCEPTION 'Nie można ręcznie modyfikować znacznika czasu zmiany nicku.';
        END IF;
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_profiles_before_update ON public.profiles;
CREATE TRIGGER tr_profiles_before_update
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.tr_fn_profiles_before_update();

-- 4.3. Trigger BEFORE INSERT na profiles: sanity check kwarantanny i normalizacja
CREATE OR REPLACE FUNCTION public.tr_fn_profiles_before_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    NEW.username := trim(NEW.username);
    NEW.username_lower := lower(NEW.username);
    NEW.created_at := now();
    NEW.updated_at := now();
    NEW.username_changed_at := now();

    -- Sprawdź czy nazwa nie jest zarezerwowana w 60-dniowej kwarantannie
    IF EXISTS (
        SELECT 1 FROM public.reserved_usernames
        WHERE username_lower = NEW.username_lower
          AND quarantine_until > now()
    ) THEN
        RAISE EXCEPTION 'Nazwa użytkownika jest obecnie w kwarantannie.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_profiles_before_insert ON public.profiles;
CREATE TRIGGER tr_profiles_before_insert
    BEFORE INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.tr_fn_profiles_before_insert();

-- --- TESTY WERYFIKACYJNE DLA KROKU 4 ---
/*
-- Test 4.1: Bezpośrednia próba zmiany nicku przez UPDATE powinna zostać zablokowana:
-- UPDATE public.profiles SET username = 'hacked_name' WHERE id = auth.uid();
-- Oczekiwany wynik: ERROR: Nazwa użytkownika może być zmieniona wyłącznie przez dedykowaną funkcję change_username.
*/

-- --- ROLLBACK DLA KROKU 4 ---
/*
DROP TRIGGER IF EXISTS tr_profiles_before_update ON public.profiles;
DROP FUNCTION IF EXISTS public.tr_fn_profiles_before_update();
DROP TRIGGER IF EXISTS tr_profiles_before_insert ON public.profiles;
DROP FUNCTION IF EXISTS public.tr_fn_profiles_before_insert();
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_username_format;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_username_lower;
*/

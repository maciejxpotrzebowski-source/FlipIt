-- ==============================================================================
-- KROK 1: PROCEDURY RPC (Kompatybilne wstecz)
-- Plik: supabase/migrations/20261015_01_rpc.sql
-- ==============================================================================
-- Wdrażaj jako pierwszy krok w SQL Editorze przed instalacją nowej wersji aplikacji.
-- Dodaje brakujące procedury RPC oraz poprawia istniejące, zabezpieczając search_path.

-- 1.1. RPC delete_deck: Bezpieczne usuwanie talii przez zalogowanego autora
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

-- 1.3. RPC set_deck_visibility: Zmiana widoczności talii (public/private) przez autora
CREATE OR REPLACE FUNCTION public.set_deck_visibility(target_code text, p_is_public boolean)
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
    SET is_public = p_is_public,
        updated_at = NOW()
    WHERE share_code = clean_code
      AND author_id = caller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Talia nie została znaleziona lub nie masz uprawnień do jej edycji.';
    END IF;
END;
$$;

-- 1.4. RPC archive_deck: Oznaczenie talii jako zarchiwizowanej
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
    SET is_public = false,
        updated_at = NOW()
    WHERE share_code = clean_code
      AND author_id = caller_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Talia nie została znaleziona lub nie masz uprawnień do jej archiwizacji.';
    END IF;
END;
$$;

-- 1.5. RPC report_usage_stats: Poprawienie błędu niejednoznaczności kolumny (P5)
-- UWAGA: Przed CREATE OR REPLACE musimy wykonać DROP FUNCTION, ponieważ Postgres
-- nie pozwala na zmianę nazw parametrów (share_code -> p_share_code) w CREATE OR REPLACE (R2).
DROP FUNCTION IF EXISTS public.report_usage_stats(text, integer);
DROP FUNCTION IF EXISTS public.report_usage_stats(text, integer, boolean);

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
    UPDATE public.shared_decks
    SET total_reviews_reported = total_reviews_reported + p_reviews_count,
        total_users_reported = total_users_reported + 1,
        return_users_reported = return_users_reported + (CASE WHEN p_is_return_user THEN 1 ELSE 0 END)
    WHERE share_code = clean_code;
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
RETURNS SETOF public.shared_decks
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

-- 1.10. RPC delete_my_account: Prawdziwe usunięcie konta z auth.users + ochrona nicku talii (R7)
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

    -- (R7b) Zabezpieczenie przed podszywaniem: zmieniamy author_name na 'Deleted user',
    -- aby po wygaśnięciu 60-dniowej kwarantanny ktoś, kto przejmie stary nick,
    -- nie stał się wizualnym „autorem” cudzych talii w Community.
    UPDATE public.shared_decks
    SET author_name = 'Deleted user'
    WHERE author_id = caller_id;

    -- Usunięcie rekordu z auth.users kaskadowo usuwa wiersz w public.profiles,
    -- co wyzwala trigger tr_profile_deleted (rezerwacja starego nicku na 60 dni).
    -- Zgodnie z kluczem obcym shared_decks.author_id_fkey (ON DELETE SET NULL),
    -- opublikowane talie użytkownika zachowują się w Community jako publiczne z author_id = NULL.
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

-- 1.12. Usunięcie zbędnego duplikatu indeksu (istnieje już shared_decks_share_code_key)
DROP INDEX IF EXISTS public.idx_shared_decks_code;

-- ==============================================================================
-- TESTY WERYFIKACYJNE DLA KROKU 1 (Symulacja ról klienta w transakcji z ROLLBACK)
-- ==============================================================================

-- Test 1.1: Próba wywołania delete_deck jako anonim (musi rzucić wyjątek):
BEGIN;
SET LOCAL ROLE anon;
SELECT public.delete_deck('TESTCODE');
-- Oczekiwany wynik: ERROR: Musisz być zalogowany, aby usunąć talię.
ROLLBACK;

-- Test 1.2: Wywołanie report_usage_stats jako anonim (nie może rzucić błędu niejednoznaczności kolumny):
BEGIN;
SET LOCAL ROLE anon;
SELECT public.report_usage_stats('NIEISTNIEJE', 5, false);
-- Oczekiwany wynik: Sukces (funkcja zwraca void, 0 wierszy zmodyfikowanych, brak błędu ambiguity).
ROLLBACK;

-- Test 1.3: Weryfikacja uprawnień DELETE na auth.users dla delete_my_account (R7a):
-- Instrukcja dla Maćka:
-- 1. Załóż konto testowe w aplikacji lub w Supabase Auth (np. test-delete@example.com).
-- 2. Sprawdź jego UUID: SELECT id FROM auth.users WHERE email = 'test-delete@example.com';
-- 3. Uruchom poniższy blok podstawiając uzyskany UUID:
/*
BEGIN;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub":"<TUTAJ_UUID_TESTOWEGO_KONTA>","role":"authenticated"}';
SELECT public.delete_my_account();
-- Jeśli zwróci {"success": true}, konto zostało pomyślnie usunięte.
ROLLBACK; -- Zmień na COMMIT, jeśli faktycznie chcesz usunąć konto testowe.
*/

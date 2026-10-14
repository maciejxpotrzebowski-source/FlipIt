-- ==============================================================================
-- ROLLBACK DLA KROKU 1: PROCEDURY RPC
-- Plik: supabase/migrations/20261015_01_rpc_rollback.sql
-- ==============================================================================
-- Przywraca stan procedur dokładnie według schematu produkcyjnego (supabase/schema_live.sql).

-- 1. Usunięcie procedur dodanych w Kroku 1
DROP FUNCTION IF EXISTS public.delete_deck(text);
DROP FUNCTION IF EXISTS public.set_deck_visibility(text, boolean);
DROP FUNCTION IF EXISTS public.archive_deck(text);
DROP FUNCTION IF EXISTS public.delete_my_account();

-- 2. Przywrócenie pierwotnej wersji unpublish_deck z schema_live.sql (bez sprawdzania author_id)
CREATE OR REPLACE FUNCTION public.unpublish_deck(target_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    UPDATE shared_decks
    SET is_public = false, updated_at = NOW()
    WHERE upper(replace(replace(share_code, '-', ''), ' ', '')) = upper(replace(replace(target_code, '-', ''), ' ', ''));
END;
$function$;

-- 3. Przywrócenie pierwotnej wersji change_username z schema_live.sql (bez aktualizacji shared_decks.author_name)
CREATE OR REPLACE FUNCTION public.change_username(new_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    caller_id UUID := auth.uid();
    old_uname TEXT;
    old_uname_lower TEXT;
    clean_new_lower TEXT;
    last_changed TIMESTAMPTZ;
BEGIN
    IF caller_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Musisz być zalogowany.');
    END IF;

    clean_new_lower := lower(trim(new_username));

    -- Pobierz dotychczasowy profil
    SELECT username, username_lower, username_changed_at
    INTO old_uname, old_uname_lower, last_changed
    FROM public.profiles
    WHERE id = caller_id;

    -- Sprawdź limit 30 dni
    IF last_changed IS NOT NULL AND (now() - last_changed) < INTERVAL '30 days' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Możesz zmienić nazwę użytkownika tylko raz na 30 dni.'
        );
    END IF;

    -- Sprawdź czy nowa nazwa jest wolna
    IF NOT public.is_username_available(new_username) THEN
        RETURN jsonb_build_object('success', false, 'error', 'Ta nazwa użytkownika jest już zajęta lub niedostępna.');
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
    SET username = trim(new_username),
        username_lower = clean_new_lower,
        username_changed_at = now(),
        updated_at = now()
    WHERE id = caller_id;

    RETURN jsonb_build_object('success', true);
END;
$function$;

-- 4. Przywrócenie pierwotnej wersji report_usage_stats z schema_live.sql
DROP FUNCTION IF EXISTS public.report_usage_stats(text, integer);
DROP FUNCTION IF EXISTS public.report_usage_stats(text, integer, boolean);

CREATE OR REPLACE FUNCTION public.report_usage_stats(share_code text, reviews_count integer, is_return_user boolean DEFAULT false)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    UPDATE shared_decks
    SET total_reviews_reported = total_reviews_reported + reviews_count,
        total_users_reported = total_users_reported + 1,
        return_users_reported = return_users_reported + (CASE WHEN is_return_user THEN 1 ELSE 0 END)
    WHERE share_code = upper(trim(replace(share_code, '-', '')));
END;
$function$;

-- 5. Przywrócenie pozostałych funkcji bez klauzuli search_path
CREATE OR REPLACE FUNCTION public.increment_downloads(deck_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    UPDATE shared_decks SET downloads_count = downloads_count + 1 WHERE id = deck_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.fetch_deck_by_code(lookup_code text)
RETURNS SETOF shared_decks
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    clean_code TEXT := upper(trim(replace(replace(lookup_code, '-', ''), ' ', '')));
BEGIN
    IF length(clean_code) <> 8 THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT * FROM shared_decks
    WHERE share_code = clean_code;
END;
$function$;

CREATE OR REPLACE FUNCTION public.is_username_available(check_username text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.handle_profile_deleted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    INSERT INTO public.reserved_usernames (username_lower, original_user_id, released_at, quarantine_until)
    VALUES (OLD.username_lower, OLD.id, now(), now() + INTERVAL '60 days')
    ON CONFLICT (username_lower) DO UPDATE
    SET quarantine_until = now() + INTERVAL '60 days', released_at = now();
    RETURN OLD;
END;
$function$;

-- 6. Przywrócenie indeksu na share_code
CREATE INDEX IF NOT EXISTS idx_shared_decks_code ON public.shared_decks USING btree (share_code);

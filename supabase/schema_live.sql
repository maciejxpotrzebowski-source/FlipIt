-- ==============================================================================
-- FlipIt — RZECZYWISTY schemat bazy Supabase (eksport z produkcji)
-- Projekt: bnrsqcqlmhuvazrjlbcl · Wyeksportowano: 2026-10-14 (SQL Editor, zapytanie read-only)
-- To jest ŹRÓDŁO PRAWDY. `schema.sql` został napisany ręcznie i NIE odpowiada temu stanowi.
-- Format: zrzut katalogu (kolumny/constrainty/indeksy/polityki), nie gotowy skrypt do uruchomienia.
-- ==============================================================================

-- TABLE profiles
--   id uuid NOT NULL,
--   username text NOT NULL,
--   username_lower text NOT NULL,
--   created_at timestamp with time zone DEFAULT now(),
--   updated_at timestamp with time zone DEFAULT now(),
--   username_changed_at timestamp with time zone DEFAULT now()

-- TABLE reserved_usernames
--   username_lower text NOT NULL,
--   original_user_id uuid,
--   released_at timestamp with time zone DEFAULT now(),
--   quarantine_until timestamp with time zone DEFAULT (now() + '60 days'::interval)

-- TABLE shared_decks
--   id uuid NOT NULL DEFAULT gen_random_uuid(),
--   share_code character varying NOT NULL DEFAULT generate_share_code(),
--   title text NOT NULL,
--   description text DEFAULT ''::text,
--   front_label text DEFAULT 'Front'::text,
--   back_label text DEFAULT 'Back'::text,
--   front_language character varying DEFAULT 'en-US'::character varying,
--   back_language character varying DEFAULT 'pl-PL'::character varying,
--   cards_count integer NOT NULL DEFAULT 0,
--   cards_payload jsonb NOT NULL,
--   is_official boolean DEFAULT false,
--   is_public boolean DEFAULT true,
--   author_name text DEFAULT 'Anonymous'::text,
--   tags ARRAY DEFAULT '{}'::text[],
--   downloads_count integer DEFAULT 0,
--   total_reviews_reported bigint DEFAULT 0,
--   total_users_reported integer DEFAULT 0,
--   created_at timestamp with time zone DEFAULT now(),
--   updated_at timestamp with time zone DEFAULT now(),
--   difficulty_level character varying DEFAULT ''::character varying,
--   return_users_reported integer DEFAULT 0,
--   author_id uuid

-- CONSTRAINT profiles.profiles_id_fkey: FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE
-- CONSTRAINT profiles.profiles_pkey: PRIMARY KEY (id)
-- CONSTRAINT profiles.profiles_username_key: UNIQUE (username)
-- CONSTRAINT profiles.profiles_username_lower_key: UNIQUE (username_lower)
-- CONSTRAINT reserved_usernames.reserved_usernames_pkey: PRIMARY KEY (username_lower)
-- CONSTRAINT shared_decks.shared_decks_author_id_fkey: FOREIGN KEY (author_id) REFERENCES auth.users(id) ON DELETE SET NULL
-- CONSTRAINT shared_decks.shared_decks_pkey: PRIMARY KEY (id)
-- CONSTRAINT shared_decks.shared_decks_share_code_key: UNIQUE (share_code)

CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id);
CREATE UNIQUE INDEX profiles_username_key ON public.profiles USING btree (username);
CREATE UNIQUE INDEX profiles_username_lower_key ON public.profiles USING btree (username_lower);
CREATE INDEX idx_profiles_username_lower ON public.profiles USING btree (username_lower);
CREATE UNIQUE INDEX reserved_usernames_pkey ON public.reserved_usernames USING btree (username_lower);
CREATE UNIQUE INDEX shared_decks_pkey ON public.shared_decks USING btree (id);
CREATE UNIQUE INDEX shared_decks_share_code_key ON public.shared_decks USING btree (share_code);
CREATE INDEX idx_shared_decks_code ON public.shared_decks USING btree (share_code);
CREATE INDEX idx_shared_decks_public ON public.shared_decks USING btree (is_public, is_official);
CREATE INDEX idx_shared_decks_downloads ON public.shared_decks USING btree (downloads_count DESC);
CREATE INDEX idx_shared_decks_tags ON public.shared_decks USING gin (tags);

-- RLS enabled on profiles: true
-- RLS enabled on reserved_usernames: true   (brak polityk → dostęp tylko przez SECURITY DEFINER)
-- RLS enabled on shared_decks: true

-- POLICY "Users can delete own profile" ON profiles FOR DELETE TO public
--    USING: (auth.uid() = id)
-- POLICY "Users can update own profile" ON profiles FOR UPDATE TO public
--    USING: (auth.uid() = id)   WITH CHECK: (auth.uid() = id)
-- POLICY "Users can insert own profile" ON profiles FOR INSERT TO public
--    WITH CHECK: (auth.uid() = id)
-- POLICY "Public read profiles" ON profiles FOR SELECT TO public
--    USING: true

-- POLICY "Public read" ON shared_decks FOR SELECT TO public
--    USING: ((is_public = true) OR ((auth.uid() IS NOT NULL) AND (auth.uid() = author_id)))
-- POLICY "Authors can delete own shared decks" ON shared_decks FOR DELETE TO public
--    USING: (auth.uid() = author_id)
-- POLICY "Authors can update own shared decks" ON shared_decks FOR UPDATE TO public
--    USING: (auth.uid() = author_id)
-- POLICY "Allow delete on shared_decks" ON shared_decks FOR DELETE TO public
--    USING: true                                  -- ⚠️ każdy może usunąć wszystko
-- POLICY "Allow update on shared_decks" ON shared_decks FOR UPDATE TO public
--    USING: true   WITH CHECK: true               -- ⚠️ każdy może zmienić wszystko
-- POLICY "Allow insert on shared_decks" ON shared_decks FOR INSERT TO public
--    WITH CHECK: true                             -- ⚠️ dowolny author_id / is_official
-- POLICY "Allow select on shared_decks" ON shared_decks FOR SELECT TO public
--    USING: true                                  -- ⚠️ unieważnia "Public read" (prywatne talie widoczne)
-- POLICY "Anyone can update stats" ON shared_decks FOR UPDATE TO public
--    USING: true   WITH CHECK: true               -- ⚠️ j.w.

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

CREATE OR REPLACE FUNCTION public.generate_share_code()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    code TEXT := '';
    i INT;
BEGIN
    LOOP
        code := '';
        FOR i IN 1..8 LOOP
            code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
        END LOOP;
        EXIT WHEN NOT EXISTS (SELECT 1 FROM shared_decks WHERE share_code = code);
    END LOOP;
    RETURN code;
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

CREATE OR REPLACE FUNCTION public.increment_downloads(deck_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    UPDATE shared_decks SET downloads_count = downloads_count + 1 WHERE id = deck_id;
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

-- (Supabase-managed) rls_auto_enable() — event trigger włączający RLS na nowych tabelach w public; pominięty.

CREATE OR REPLACE FUNCTION public.set_share_code()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.share_code IS NULL OR NEW.share_code = '' THEN
        NEW.share_code := generate_share_code();
    END IF;
    RETURN NEW;
END;
$function$;

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

CREATE TRIGGER trigger_set_share_code BEFORE INSERT ON public.shared_decks FOR EACH ROW EXECUTE FUNCTION set_share_code();
CREATE TRIGGER tr_profile_deleted BEFORE DELETE ON public.profiles FOR EACH ROW EXECUTE FUNCTION handle_profile_deleted();

-- UWAGA: w bazie NIE istnieje funkcja public.delete_deck (aplikacja ją wywołuje, po błędzie robi fallback na bezpośredni DELETE).

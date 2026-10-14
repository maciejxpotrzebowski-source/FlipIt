-- ==============================================================================
-- FlipIt — Pełny schemat bazy danych Supabase (Schema, RLS, Triggers & RPC)
-- Projekt: FlipIt (iOS / macOS)
-- Baza danych: PostgreSQL (Supabase)
-- ==============================================================================

-- Włączenie rozszerzenia pgcrypto (dla gen_random_uuid)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ==============================================================================
-- 1. TABELA: profiles
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    username_lower TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    username_changed_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),

    CONSTRAINT username_length_check CHECK (char_length(username) >= 3 AND char_length(username) <= 20),
    CONSTRAINT username_format_check CHECK (username ~ '^[a-zA-Z0-9_]{3,20}$'),
    CONSTRAINT profiles_username_unique UNIQUE (username),
    CONSTRAINT profiles_username_lower_unique UNIQUE (username_lower)
);

CREATE INDEX IF NOT EXISTS idx_profiles_username_lower ON public.profiles(username_lower);

-- ==============================================================================
-- 2. TABELA: reserved_usernames (kwarantanna starych/usuniętych nicków na 60 dni)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.reserved_usernames (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT NOT NULL,
    username_lower TEXT NOT NULL UNIQUE,
    reserved_until TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_reserved_usernames_lookup ON public.reserved_usernames(username_lower, reserved_until);

-- ==============================================================================
-- 3. TABELA: shared_decks (Giełda Community)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.shared_decks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    share_code VARCHAR(8) NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT DEFAULT '',
    front_label TEXT NOT NULL DEFAULT 'Front',
    back_label TEXT NOT NULL DEFAULT 'Back',
    front_language TEXT NOT NULL DEFAULT 'en',
    back_language TEXT NOT NULL DEFAULT 'pl',
    cards_count INTEGER NOT NULL DEFAULT 0,
    cards_payload JSONB NOT NULL DEFAULT '[]'::jsonb,
    is_official BOOLEAN NOT NULL DEFAULT false,
    is_public BOOLEAN NOT NULL DEFAULT true,
    author_name TEXT NOT NULL DEFAULT 'Anonymous',
    author_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    tags TEXT[] NOT NULL DEFAULT '{}'::text[],
    difficulty_level TEXT DEFAULT NULL,
    downloads_count INTEGER NOT NULL DEFAULT 0,
    total_reviews_reported INTEGER NOT NULL DEFAULT 0,
    total_users_reported INTEGER NOT NULL DEFAULT 0,
    return_users_reported INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_shared_decks_share_code ON public.shared_decks(share_code);
CREATE INDEX IF NOT EXISTS idx_shared_decks_author_id ON public.shared_decks(author_id);
CREATE INDEX IF NOT EXISTS idx_shared_decks_community_search ON public.shared_decks(is_public, is_official, downloads_count DESC);
CREATE INDEX IF NOT EXISTS idx_shared_decks_difficulty ON public.shared_decks(difficulty_level);

-- ==============================================================================
-- 4. FUNKCJE POMOCNICZE I TRIGGERY
-- ==============================================================================

-- Automatyczna aktualizacja updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER set_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER set_shared_decks_updated_at
BEFORE UPDATE ON public.shared_decks
FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Generator 8-znakowego unikalnego kodu talii (bez dwuznacznych znaków 0/O, 1/I)
CREATE OR REPLACE FUNCTION public.generate_unique_share_code()
RETURNS TEXT AS $$
DECLARE
    characters TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    generated_code TEXT := '';
    i INTEGER;
    code_exists BOOLEAN;
BEGIN
    LOOP
        generated_code := '';
        FOR i IN 1..8 LOOP
            generated_code := generated_code || substr(characters, floor(random() * length(characters) + 1)::integer, 1);
        END LOOP;

        SELECT EXISTS (
            SELECT 1 FROM public.shared_decks WHERE share_code = generated_code
        ) INTO code_exists;

        EXIT WHEN NOT code_exists;
    END LOOP;

    RETURN generated_code;
END;
$$ LANGUAGE plpgsql;

-- Trigger nadający share_code przy tworzeniu talii jeśli nie podano
CREATE OR REPLACE FUNCTION public.handle_new_shared_deck()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.share_code IS NULL OR NEW.share_code = '' THEN
        NEW.share_code := public.generate_unique_share_code();
    ELSE
        NEW.share_code := upper(trim(NEW.share_code));
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER set_shared_deck_share_code
BEFORE INSERT ON public.shared_decks
FOR EACH ROW EXECUTE FUNCTION public.handle_new_shared_deck();

-- Trigger przy usunięciu konta/profilu (przeniesienie nicku do kwarantanny na 60 dni)
CREATE OR REPLACE FUNCTION public.handle_profile_deleted()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.reserved_usernames (username, username_lower, reserved_until)
    VALUES (
        OLD.username,
        OLD.username_lower,
        timezone('utc'::text, now()) + INTERVAL '60 days'
    )
    ON CONFLICT (username_lower) DO UPDATE
    SET reserved_until = timezone('utc'::text, now()) + INTERVAL '60 days';

    RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_profile_deleted
BEFORE DELETE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.handle_profile_deleted();

-- ==============================================================================
-- 5. PROCEDURY RPC (API dla Aplikacji iOS)
-- ==============================================================================

-- A. Sprawdzanie dostępności nazwy użytkownika
CREATE OR REPLACE FUNCTION public.is_username_available(check_username TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    cleaned_lower TEXT := lower(trim(check_username));
    is_taken BOOLEAN;
BEGIN
    IF char_length(cleaned_lower) < 3 OR char_length(cleaned_lower) > 20 THEN
        RETURN false;
    END IF;

    IF cleaned_lower !~ '^[a-zA-Z0-9_]{3,20}$' THEN
        RETURN false;
    END IF;

    -- Sprawdzenie czy istnieje w profilach
    SELECT EXISTS (
        SELECT 1 FROM public.profiles WHERE username_lower = cleaned_lower
    ) INTO is_taken;

    IF is_taken THEN
        RETURN false;
    END IF;

    -- Sprawdzenie czy jest w aktywnej kwarantannie
    SELECT EXISTS (
        SELECT 1 FROM public.reserved_usernames
        WHERE username_lower = cleaned_lower
          AND reserved_until > timezone('utc'::text, now())
    ) INTO is_taken;

    RETURN NOT is_taken;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- B. Zmiana nazwy użytkownika (z walidacją 30-dniowego cooldownu i kwarantanną)
CREATE OR REPLACE FUNCTION public.change_username(new_username TEXT)
RETURNS JSON AS $$
DECLARE
    caller_id UUID := auth.uid();
    cleaned_new TEXT := trim(new_username);
    cleaned_new_lower TEXT := lower(cleaned_new);
    current_rec RECORD;
    days_since_change DOUBLE PRECISION;
    days_left INTEGER;
BEGIN
    IF caller_id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'Not authenticated');
    END IF;

    -- Pobierz profil
    SELECT * INTO current_rec FROM public.profiles WHERE id = caller_id;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'error', 'Profile not found');
    END IF;

    -- Sprawdź cooldown (30 dni)
    IF current_rec.username_changed_at IS NOT NULL THEN
        days_since_change := EXTRACT(EPOCH FROM (timezone('utc'::text, now()) - current_rec.username_changed_at)) / 86400.0;
        IF days_since_change < 30.0 THEN
            days_left := CEIL(30.0 - days_since_change)::INTEGER;
            RETURN json_build_object('success', false, 'error', 'Username change on cooldown', 'days_left', days_left);
        END IF;
    END IF;

    -- Sprawdź dostępność nowego nicku
    IF NOT public.is_username_available(cleaned_new) THEN
        RETURN json_build_object('success', false, 'error', 'Username taken or in quarantine');
    END IF;

    -- Zarezerwuj stary nick na 60 dni
    INSERT INTO public.reserved_usernames (username, username_lower, reserved_until)
    VALUES (
        current_rec.username,
        current_rec.username_lower,
        timezone('utc'::text, now()) + INTERVAL '60 days'
    )
    ON CONFLICT (username_lower) DO UPDATE
    SET reserved_until = timezone('utc'::text, now()) + INTERVAL '60 days';

    -- Zaktualizuj profil
    UPDATE public.profiles
    SET username = cleaned_new,
        username_lower = cleaned_new_lower,
        username_changed_at = timezone('utc'::text, now()),
        updated_at = timezone('utc'::text, now())
    WHERE id = caller_id;

    -- Zaktualizuj nazwisko autora w opublikowanych taliach
    UPDATE public.shared_decks
    SET author_name = cleaned_new,
        updated_at = timezone('utc'::text, now())
    WHERE author_id = caller_id;

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- C. Pobieranie talii po dokładnym kodzie 8-znakowym (w tym prywatnych)
CREATE OR REPLACE FUNCTION public.fetch_deck_by_code(lookup_code TEXT)
RETURNS SETOF public.shared_decks AS $$
DECLARE
    cleaned_code TEXT := upper(replace(replace(trim(lookup_code), '-', ''), ' ', ''));
BEGIN
    RETURN QUERY
    SELECT * FROM public.shared_decks
    WHERE share_code = cleaned_code
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- D. Zwiększanie licznika pobrań talii
CREATE OR REPLACE FUNCTION public.increment_downloads(deck_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE public.shared_decks
    SET downloads_count = downloads_count + 1
    WHERE id = deck_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- E. Raportowanie statystyk nauki i retencji
CREATE OR REPLACE FUNCTION public.report_usage_stats(share_code TEXT, reviews_count INTEGER, is_return_user BOOLEAN DEFAULT false)
RETURNS VOID AS $$
DECLARE
    cleaned_code TEXT := upper(replace(replace(trim(share_code), '-', ''), ' ', ''));
BEGIN
    UPDATE public.shared_decks
    SET total_reviews_reported = total_reviews_reported + reviews_count,
        total_users_reported = total_users_reported + 1,
        return_users_reported = CASE WHEN is_return_user THEN return_users_reported + 1 ELSE return_users_reported END
    WHERE public.shared_decks.share_code = cleaned_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- F. Zdejmowanie z giełdy (unpublish) przez autora
CREATE OR REPLACE FUNCTION public.unpublish_deck(target_code TEXT)
RETURNS VOID AS $$
DECLARE
    cleaned_code TEXT := upper(replace(replace(trim(target_code), '-', ''), ' ', ''));
BEGIN
    UPDATE public.shared_decks
    SET is_public = false,
        updated_at = timezone('utc'::text, now())
    WHERE share_code = cleaned_code
      AND (author_id = auth.uid() OR auth.uid() IS NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- G. Trwałe usuwanie talii przez autora
CREATE OR REPLACE FUNCTION public.delete_deck(target_code TEXT)
RETURNS VOID AS $$
DECLARE
    cleaned_code TEXT := upper(replace(replace(trim(target_code), '-', ''), ' ', ''));
BEGIN
    DELETE FROM public.shared_decks
    WHERE share_code = cleaned_code
      AND (author_id = auth.uid() OR auth.uid() IS NULL);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- 6. POLITYKI ROW LEVEL SECURITY (RLS)
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reserved_usernames ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_decks ENABLE ROW LEVEL SECURITY;

-- Profiles:
-- Każdy (także anonim) może odczytać publiczny profil/nick
CREATE POLICY "Profiles are viewable by everyone"
ON public.profiles FOR SELECT
USING (true);

-- Wstawianie profilu tylko dla zalogowanego użytkownika dla własnego ID
CREATE POLICY "Users can insert their own profile"
ON public.profiles FOR INSERT
WITH CHECK (auth.uid() = id);

-- Aktualizacja profilu tylko przez właściciela
CREATE POLICY "Users can update their own profile"
ON public.profiles FOR UPDATE
USING (auth.uid() = id);

-- Usuwanie profilu tylko przez właściciela
CREATE POLICY "Users can delete their own profile"
ON public.profiles FOR DELETE
USING (auth.uid() = id);

-- Shared Decks:
-- Każdy może przeglądać talie publiczne LUB autor może przeglądać swoje prywatne
CREATE POLICY "Public decks are viewable by everyone"
ON public.shared_decks FOR SELECT
USING (is_public = true OR (auth.uid() IS NOT NULL AND auth.uid() = author_id));

-- Publikowanie talii (anonimowo lub z kontem)
CREATE POLICY "Users can insert shared decks"
ON public.shared_decks FOR INSERT
WITH CHECK (auth.uid() IS NOT NULL OR author_id IS NULL);

-- Aktualizacja talii tylko przez autora
CREATE POLICY "Authors can update their decks"
ON public.shared_decks FOR UPDATE
USING (auth.uid() IS NOT NULL AND auth.uid() = author_id);

-- Usuwanie talii tylko przez autora
CREATE POLICY "Authors can delete their decks"
ON public.shared_decks FOR DELETE
USING (auth.uid() IS NOT NULL AND auth.uid() = author_id);

-- Reserved Usernames:
-- Tylko odczyt wewnętrzny / RPC (brak bezpośredniego dostępu dla anonimów)
CREATE POLICY "Reserved usernames viewable by authenticated users"
ON public.reserved_usernames FOR SELECT
TO authenticated
USING (true);

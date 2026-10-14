-- ==============================================================================
-- KROK 4: PROFILE I NICKI (P7)
-- Plik: supabase/migrations/20261015_04_profiles.sql
-- ==============================================================================
-- Wdrażaj jako ostatni krok po wdrożeniu Kroku 3 i sprawdzeniu Kroku 0.2.
-- Zabezpiecza przed podszywaniem się i omijaniem 30-dniowego cooldownu (P7, R3).

-- 4.1. Constrainty integralności formatu i małych liter
ALTER TABLE public.profiles
    DROP CONSTRAINT IF EXISTS check_username_format,
    ADD CONSTRAINT check_username_format CHECK (username ~ '^[A-Za-z0-9_]{3,20}$');

ALTER TABLE public.profiles
    DROP CONSTRAINT IF EXISTS check_username_lower,
    ADD CONSTRAINT check_username_lower CHECK (username_lower = lower(username));

-- 4.2. Trigger BEFORE UPDATE na profiles: blokada bezpośredniej zmiany nicku przez klienta
-- UWAGA (R3): Funkcja NIE jest SECURITY DEFINER (zostaje domyślne SECURITY INVOKER),
-- a warunek sprawdza rolę klienta: IF current_user IN ('anon', 'authenticated') THEN.
-- Bezpośrednie wywołanie update z aplikacji/PostgREST jest blokowane.
-- Procedura change_username (która jest SECURITY DEFINER i działa jako postgres) przechodzi bez przeszkód!
CREATE OR REPLACE FUNCTION public.tr_fn_profiles_before_update()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    IF current_user IN ('anon', 'authenticated') THEN
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


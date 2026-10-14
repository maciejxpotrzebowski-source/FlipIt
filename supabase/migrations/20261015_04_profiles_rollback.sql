-- ==============================================================================
-- ROLLBACK DLA KROKU 4: PROFILE I NICKI
-- Plik: supabase/migrations/20261015_04_profiles_rollback.sql
-- ==============================================================================
-- Przywraca stan tabeli profiles dokładnie według schematu produkcyjnego (schema_live.sql).

DROP TRIGGER IF EXISTS tr_profiles_before_update ON public.profiles;
DROP FUNCTION IF EXISTS public.tr_fn_profiles_before_update();

DROP TRIGGER IF EXISTS tr_profiles_before_insert ON public.profiles;
DROP FUNCTION IF EXISTS public.tr_fn_profiles_before_insert();

ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_username_format;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_username_lower;

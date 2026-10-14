-- ==============================================================================
-- ROLLBACK DLA KROKU 3: POLITYKI RLS I TRIGGERY shared_decks
-- Plik: supabase/migrations/20261015_03_rls_shared_decks_rollback.sql
-- ==============================================================================
-- Przywraca stan shared_decks dokładnie według schematu produkcyjnego (schema_live.sql).

-- 1. Usunięcie nowych triggerów
DROP TRIGGER IF EXISTS tr_shared_decks_before_update ON public.shared_decks;
DROP FUNCTION IF EXISTS public.tr_fn_shared_decks_before_update();

DROP TRIGGER IF EXISTS tr_shared_decks_before_insert ON public.shared_decks;
DROP FUNCTION IF EXISTS public.tr_fn_shared_decks_before_insert();

-- 2. Przywrócenie oryginalnego triggera set_share_code
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

DROP TRIGGER IF EXISTS trigger_set_share_code ON public.shared_decks;
CREATE TRIGGER trigger_set_share_code
    BEFORE INSERT ON public.shared_decks
    FOR EACH ROW
    EXECUTE FUNCTION set_share_code();

-- 3. Usunięcie constraintów rozmiaru
ALTER TABLE public.shared_decks DROP CONSTRAINT IF EXISTS check_cards_count;
ALTER TABLE public.shared_decks DROP CONSTRAINT IF EXISTS check_cards_payload_size;

-- 4. Przywrócenie oryginalnych polityk RLS z schema_live.sql
DROP POLICY IF EXISTS "Authors can insert own decks" ON public.shared_decks;
DROP POLICY IF EXISTS "Authors can update own shared decks" ON public.shared_decks;
DROP POLICY IF EXISTS "Authors can delete own shared decks" ON public.shared_decks;
DROP POLICY IF EXISTS "Public read" ON public.shared_decks;

CREATE POLICY "Public read" ON public.shared_decks
    FOR SELECT TO public
    USING (((is_public = true) OR ((auth.uid() IS NOT NULL) AND (auth.uid() = author_id))));

CREATE POLICY "Authors can delete own shared decks" ON public.shared_decks
    FOR DELETE TO public
    USING (auth.uid() = author_id);

CREATE POLICY "Authors can update own shared decks" ON public.shared_decks
    FOR UPDATE TO public
    USING (auth.uid() = author_id);

CREATE POLICY "Allow delete on shared_decks" ON public.shared_decks
    FOR DELETE TO public
    USING (true);

CREATE POLICY "Allow update on shared_decks" ON public.shared_decks
    FOR UPDATE TO public
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Anyone can update stats" ON public.shared_decks
    FOR UPDATE TO public
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Allow insert on shared_decks" ON public.shared_decks
    FOR INSERT TO public
    WITH CHECK (true);

CREATE POLICY "Allow select on shared_decks" ON public.shared_decks
    FOR SELECT TO public
    USING (true);

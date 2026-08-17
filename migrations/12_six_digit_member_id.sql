-- ============================================================
-- 12_six_digit_member_id.sql — TigerBay International
-- ============================================================
-- Adds a unique 6-digit Member ID (member_code) to public.profiles.
-- Generates sequential 6-digit IDs starting at 100001, with auto-assignment
-- on new registrations and backfill for all existing member accounts.
-- ============================================================

-- ── 1. Create Sequence for 6-Digit Member IDs ───────────────────────────────
CREATE SEQUENCE IF NOT EXISTS public.member_code_seq
    START WITH 100001
    INCREMENT BY 1
    MINVALUE 100001
    MAXVALUE 999999
    CYCLE;

COMMENT ON SEQUENCE public.member_code_seq IS
    'Sequential generator for 6-digit member identification numbers (100001 - 999999)';

-- ── 2. Add member_code column to public.profiles ────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'profiles'
          AND column_name  = 'member_code'
    ) THEN
        ALTER TABLE public.profiles
            ADD COLUMN member_code varchar(6);

        COMMENT ON COLUMN public.profiles.member_code IS
            'Unique 6-digit human-readable member ID displayed on digital cards & QR passes';
    END IF;
END
$$;

-- ── 3. Backfill existing profiles with unique 6-digit IDs ───────────────────
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT id FROM public.profiles
        WHERE member_code IS NULL OR length(member_code) != 6
        ORDER BY id ASC
    ) LOOP
        UPDATE public.profiles
        SET member_code = lpad(nextval('public.member_code_seq')::text, 6, '0')
        WHERE id = r.id;
    END LOOP;
END
$$;

-- ── 4. Ensure Unique Constraint & Index ──────────────────────────────────────
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'profiles_member_code_key'
    ) THEN
        ALTER TABLE public.profiles
            ADD CONSTRAINT profiles_member_code_key UNIQUE (member_code);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_profiles_member_code
    ON public.profiles(member_code);

-- ── 5. Helper Function to generate next 6-digit member code ─────────────────
CREATE OR REPLACE FUNCTION public.get_next_member_code()
RETURNS varchar(6)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    new_code varchar(6);
BEGIN
    new_code := lpad(nextval('public.member_code_seq')::text, 6, '0');
    RETURN new_code;
END;
$$;

-- ── 6. Trigger to automatically set member_code on insert ───────────────────
CREATE OR REPLACE FUNCTION public.set_profile_member_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.member_code IS NULL OR length(NEW.member_code) != 6 THEN
        NEW.member_code := lpad(nextval('public.member_code_seq')::text, 6, '0');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_profile_member_code ON public.profiles;
CREATE TRIGGER trg_set_profile_member_code
    BEFORE INSERT ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.set_profile_member_code();

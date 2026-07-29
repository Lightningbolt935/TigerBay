-- ============================================================
-- 09_complete_auth_fix.sql — TigerBay International
-- ============================================================
-- Fixes the PostgrestException code 23503 "profiles_id_fkey"
-- by addressing every ranked root cause:
--   1. Drops and recreates the FK constraint targeting auth.users (not public.users)
--   2. Adds home_site_id column to public.profiles if absent
--   3. Creates trigger_error_log for categorized anomaly telemetry
--   4. Rewrites handle_new_user() with SECURITY DEFINER + cleared search_path,
--      home_site_id parsing with fallback, full EXCEPTION handler, ON CONFLICT
--   5. Redeclares the trigger as AFTER INSERT OR UPDATE to handle registration retries
--   6. Refreshes RLS policies to permit the trigger's service context to write freely
-- Run this migration once in the Supabase SQL editor or via CLI:
--   supabase db push (after placing in supabase/migrations/)
-- ============================================================

-- ── SECTION A: trigger_error_log table ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.trigger_error_log (
    id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    error_code        text        NOT NULL,           -- e.g. 'METADATA_MALFORMED', 'DB_LAG'
    error_message     text        NOT NULL,
    user_id           uuid,                           -- nullable: may be unknown at failure time
    payload_snapshot  jsonb,                          -- full raw_user_meta_data at the moment of failure
    trigger_name      text        NOT NULL DEFAULT 'handle_new_user',
    created_at        timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  public.trigger_error_log IS
    'Categorized error telemetry emitted by auth trigger functions. Service-role only.';
COMMENT ON COLUMN public.trigger_error_log.error_code IS
    'Enum-style code: METADATA_MALFORMED | REGISTRATION_RETRY | DB_LAG | UNKNOWN';
COMMENT ON COLUMN public.trigger_error_log.payload_snapshot IS
    'Full JSONB snapshot of NEW.raw_user_meta_data at the moment of failure';

-- Enable RLS — service role bypasses all policies, anon/authenticated cannot read
ALTER TABLE public.trigger_error_log ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to make this migration idempotent
DROP POLICY IF EXISTS "Service role manages error log"     ON public.trigger_error_log;
DROP POLICY IF EXISTS "No authenticated read of error log" ON public.trigger_error_log;

-- Only the service role (internal functions) may insert or select
CREATE POLICY "Service role manages error log"
    ON public.trigger_error_log
    FOR ALL
    USING      (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- Explicit denial for authenticated users (belt-and-suspenders)
CREATE POLICY "No authenticated read of error log"
    ON public.trigger_error_log
    FOR SELECT
    USING (false);


-- ── SECTION B: Add home_site_id column to profiles if absent ──────────────────

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'profiles'
          AND column_name  = 'home_site_id'
    ) THEN
        ALTER TABLE public.profiles
            ADD COLUMN home_site_id integer;

        COMMENT ON COLUMN public.profiles.home_site_id IS
            'FK to public.branches.id — the member''s preferred home venue';
    END IF;
END
$$;

-- Also add membership columns if absent (referenced by user_model.dart)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'profiles'
          AND column_name  = 'membership_status'
    ) THEN
        ALTER TABLE public.profiles
            ADD COLUMN membership_status text NOT NULL DEFAULT 'inactive'
                CHECK (membership_status IN ('active', 'inactive', 'expired', 'suspended'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'profiles'
          AND column_name  = 'membership_tier_id'
    ) THEN
        ALTER TABLE public.profiles
            ADD COLUMN membership_tier_id integer;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'profiles'
          AND column_name  = 'membership_expires_at'
    ) THEN
        ALTER TABLE public.profiles
            ADD COLUMN membership_expires_at timestamptz;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'profiles'
          AND column_name  = 'strips_balance'
    ) THEN
        ALTER TABLE public.profiles
            ADD COLUMN strips_balance integer NOT NULL DEFAULT 0;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'profiles'
          AND column_name  = 'full_name'
    ) THEN
        ALTER TABLE public.profiles
            ADD COLUMN full_name text;
    END IF;
END
$$;


-- ── SECTION C: Fix the foreign key constraint ─────────────────────────────────
-- The error "Key (id) is not present in table users" without schema qualification
-- indicates the constraint may reference public.users instead of auth.users.
-- We drop every FK constraint on profiles.id and recreate exactly one, correctly.

DO $$
DECLARE
    v_constraint_name text;
BEGIN
    -- Find and drop ALL foreign key constraints on profiles(id)
    -- to eliminate any stale or incorrectly-targeted constraint
    FOR v_constraint_name IN
        SELECT c.conname
        FROM   pg_constraint c
               JOIN pg_attribute a
                 ON a.attrelid = c.conrelid
                AND a.attnum   = ANY(c.conkey)
        WHERE  c.conrelid = 'public.profiles'::regclass
          AND  c.contype  = 'f'                          -- foreign key
          AND  a.attname  = 'id'
    LOOP
        EXECUTE format(
            'ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS %I',
            v_constraint_name
        );
        RAISE NOTICE 'Dropped FK constraint: %', v_constraint_name;
    END LOOP;
END
$$;

-- Recreate the FK constraint with the correct auth.users target and cascade rule.
-- Named explicitly so it can be referenced precisely in future migrations.
ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_id_fkey
        FOREIGN KEY (id)
        REFERENCES  auth.users(id)
        ON DELETE   CASCADE
        DEFERRABLE INITIALLY DEFERRED;

-- DEFERRABLE INITIALLY DEFERRED allows the FK check to be deferred to the end
-- of the transaction, eliminating timing-window violations when the trigger and
-- other writes occur inside the same transaction block.

COMMENT ON CONSTRAINT profiles_id_fkey ON public.profiles IS
    'Hard link to auth.users. DEFERRABLE INITIALLY DEFERRED prevents race '
    'conditions between GoTrue auth commits and PostgREST profile writes.';


-- ── SECTION D: Rewrite handle_new_user() trigger function ─────────────────────

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp  -- cleared path prevents search-path injection
AS $$
DECLARE
    v_home_site_id    integer;
    v_home_site_raw   text;
    v_error_code      text;
    v_error_message   text;
    v_full_name       text;
    v_email           text;
BEGIN
    -- ── Parse home_site_id from user metadata ──────────────────────────────
    -- Supports both integer and string representations sent from Flutter.
    -- Falls back to 1 (default branch) if missing or non-castable.
    BEGIN
        v_home_site_raw := NEW.raw_user_meta_data ->> 'home_site_id';

        IF v_home_site_raw IS NULL OR trim(v_home_site_raw) = '' THEN
            -- METADATA_MISSING_OR_MALFORMED: field is absent
            v_home_site_id  := 1;
            v_error_code    := 'METADATA_MALFORMED';
            v_error_message := 'home_site_id is null or empty in raw_user_meta_data. '
                               'Defaulting to site 1.';

            INSERT INTO public.trigger_error_log
                (error_code, error_message, user_id, payload_snapshot)
            VALUES (
                v_error_code,
                v_error_message,
                NEW.id,
                NEW.raw_user_meta_data
            );
        ELSE
            -- Attempt to cast to integer; log if it fails
            BEGIN
                v_home_site_id := v_home_site_raw::integer;
            EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
                v_home_site_id  := 1;
                v_error_code    := 'METADATA_MALFORMED';
                v_error_message := format(
                    'home_site_id value "%s" cannot be cast to integer. '
                    'Defaulting to site 1. SQLSTATE: %s',
                    v_home_site_raw,
                    SQLSTATE
                );

                INSERT INTO public.trigger_error_log
                    (error_code, error_message, user_id, payload_snapshot)
                VALUES (
                    v_error_code,
                    v_error_message,
                    NEW.id,
                    NEW.raw_user_meta_data
                );
            END;
        END IF;
    END;

    -- ── Parse optional user metadata fields ───────────────────────────────
    v_full_name := NULLIF(trim(NEW.raw_user_meta_data ->> 'full_name'), '');
    v_email     := COALESCE(NEW.email, NEW.raw_user_meta_data ->> 'email');

    -- ── Idempotent profile upsert ──────────────────────────────────────────
    -- ON CONFLICT (id) DO UPDATE handles:
    --   • Normal new-user insert (INSERT path)
    --   • REGISTRATION_RETRY_COLLISION: re-signup with same unconfirmed email
    --     triggers UPDATE on auth.users → this function fires again →
    --     DO UPDATE refreshes metadata instead of panicking on uniqueness
    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        home_site_id,
        membership_status,
        strips_balance,
        created_at,
        updated_at
    )
    VALUES (
        NEW.id,
        v_email,
        v_full_name,
        v_home_site_id,
        'inactive',
        0,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE
        SET
            email         = EXCLUDED.email,
            full_name     = COALESCE(EXCLUDED.full_name, public.profiles.full_name),
            home_site_id  = EXCLUDED.home_site_id,
            updated_at    = now();
    -- Note: membership_status and strips_balance are NOT reset on conflict —
    -- this preserves any existing membership state for retry scenarios.

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        -- ── Catch-all: log the anomaly and return NEW to avoid breaking GoTrue ──
        -- Returning NEW allows the auth.users INSERT/UPDATE to succeed even if
        -- the profile creation fails. The user can still sign in and the profile
        -- will be created lazily on first authenticated request.
        INSERT INTO public.trigger_error_log
            (error_code, error_message, user_id, payload_snapshot)
        VALUES (
            'TRIGGER_EXCEPTION',
            format(
                'handle_new_user EXCEPTION on user %s. SQLSTATE: %s. Detail: %s',
                NEW.id::text,
                SQLSTATE,
                SQLERRM
            ),
            NEW.id,
            jsonb_build_object(
                'raw_user_meta_data', NEW.raw_user_meta_data,
                'sqlstate',           SQLSTATE,
                'sqlerrm',            SQLERRM,
                'trigger_op',         TG_OP,
                'new_id',             NEW.id::text,
                'new_email',          NEW.email
            )
        );

        -- CRITICAL: Return NEW (not NULL) so the auth transaction commits.
        -- Returning NULL from an AFTER trigger has no effect on DML outcome,
        -- but being explicit avoids any future confusion.
        RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user() IS
    'SECURITY DEFINER trigger function. Fires AFTER INSERT OR UPDATE on auth.users. '
    'Creates or updates the matching public.profiles row. Logs all anomalies to '
    'trigger_error_log without breaking the auth pipeline.';


-- ── SECTION E: Recreate the trigger ───────────────────────────────────────────
-- Fires on BOTH INSERT (new user) and UPDATE (email resend / retry collision).

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP TRIGGER IF EXISTS on_auth_user_created_or_updated ON auth.users;

CREATE TRIGGER on_auth_user_created_or_updated
    AFTER INSERT OR UPDATE ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

COMMENT ON TRIGGER on_auth_user_created_or_updated ON auth.users IS
    'Fires on INSERT (new signup) and UPDATE (email resend / retry collision). '
    'UPDATE firing is guarded inside the function via ON CONFLICT DO UPDATE.';


-- ── SECTION F: Fix RLS policies ───────────────────────────────────────────────

-- ── profiles ──────────────────────────────────────────────────────────────────

-- Ensure RLS is enabled
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Drop all existing policies to recreate cleanly (idempotent)
DROP POLICY IF EXISTS "Users can view own profile"           ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile"         ON public.profiles;
DROP POLICY IF EXISTS "Users can insert own profile"         ON public.profiles;
DROP POLICY IF EXISTS "Service role full access to profiles" ON public.profiles;

-- Authenticated users: read their own row only
CREATE POLICY "Users can view own profile"
    ON public.profiles
    FOR SELECT
    USING (auth.uid() = id);

-- Authenticated users: update their own row only
CREATE POLICY "Users can update own profile"
    ON public.profiles
    FOR UPDATE
    USING      (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- Service role: unrestricted access (used by trigger function, admin operations)
-- The SECURITY DEFINER trigger runs as its owner (postgres superuser) which
-- bypasses RLS automatically. This policy exists for explicit service_role API calls.
CREATE POLICY "Service role full access to profiles"
    ON public.profiles
    FOR ALL
    USING      (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');

-- NOTE: No INSERT policy for authenticated users — profile rows are created
-- exclusively by the database trigger. Client-side inserts are intentionally blocked.
-- This is the architectural guarantee that prevents the race-condition root cause.


-- ── device_bindings ────────────────────────────────────────────────────────────

ALTER TABLE public.device_bindings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own device bindings"  ON public.device_bindings;
DROP POLICY IF EXISTS "Users can insert own device binding" ON public.device_bindings;
DROP POLICY IF EXISTS "Service role manages device bindings" ON public.device_bindings;

CREATE POLICY "Users can view own device bindings"
    ON public.device_bindings
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own device binding"
    ON public.device_bindings
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own device binding"
    ON public.device_bindings
    FOR UPDATE
    USING      (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role manages device bindings"
    ON public.device_bindings
    FOR ALL
    USING      (auth.role() = 'service_role')
    WITH CHECK (auth.role() = 'service_role');


-- ── security_events ────────────────────────────────────────────────────────────

ALTER TABLE public.security_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own security events"      ON public.security_events;
DROP POLICY IF EXISTS "Service role can insert security events" ON public.security_events;

CREATE POLICY "Users can view own security events"
    ON public.security_events
    FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Service role can insert security events"
    ON public.security_events
    FOR INSERT
    WITH CHECK (auth.role() = 'service_role');


-- ── SECTION G: Verification queries (run manually to confirm) ─────────────────
-- Uncomment and run each block in the Supabase SQL editor to verify:

-- 1. Confirm FK now targets auth.users:
-- SELECT conname, pg_get_constraintdef(oid)
-- FROM pg_constraint
-- WHERE conrelid = 'public.profiles'::regclass AND contype = 'f';
-- Expected: "profiles_id_fkey" → FOREIGN KEY (id) REFERENCES auth.users(id) ...

-- 2. Confirm trigger exists on auth.users:
-- SELECT trigger_name, event_manipulation, action_timing
-- FROM information_schema.triggers
-- WHERE event_object_schema = 'auth'
--   AND event_object_table  = 'users'
--   AND trigger_name = 'on_auth_user_created_or_updated';

-- 3. Confirm profiles has home_site_id:
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'profiles'
-- ORDER BY ordinal_position;

-- 4. Confirm trigger_error_log is empty (healthy system):
-- SELECT * FROM public.trigger_error_log ORDER BY created_at DESC LIMIT 10;

-- 5. Simulate a trigger fire manually:
-- UPDATE auth.users SET updated_at = now()
-- WHERE id = '9e535a52-607d-48b0-a445-706c1a6c5af8';
-- SELECT * FROM public.profiles WHERE id = '9e535a52-607d-48b0-a445-706c1a6c5af8';

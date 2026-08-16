-- ═══════════════════════════════════════════════════════════════════════════════
-- Migration 11: Google OAuth Profile Sync & Avatar Support
-- ═══════════════════════════════════════════════════════════════════════════════
-- Updates handle_new_user() to seamlessly extract name (full_name / name),
-- avatar photo (avatar_url / picture), and email from Google OAuth metadata.
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
    v_home_site_id    integer;
    v_home_site_raw   text;
    v_full_name       text;
    v_avatar_url      text;
    v_email           text;
    v_error_code      text;
    v_error_message   text;
BEGIN
    -- ── Parse home_site_id from user metadata ──────────────────────────────
    BEGIN
        v_home_site_raw := NEW.raw_user_meta_data ->> 'home_site_id';

        IF v_home_site_raw IS NULL OR trim(v_home_site_raw) = '' THEN
            v_home_site_id  := 1;
        ELSE
            BEGIN
                v_home_site_id := v_home_site_raw::integer;
            EXCEPTION WHEN OTHERS THEN
                v_home_site_id := 1;
            END;
        END IF;
    END;

    -- ── Parse user metadata from OAuth (Google/Apple) or regular signup ─────
    v_full_name  := NULLIF(trim(COALESCE(
        NEW.raw_user_meta_data ->> 'full_name',
        NEW.raw_user_meta_data ->> 'name'
    )), '');

    v_avatar_url := NULLIF(trim(COALESCE(
        NEW.raw_user_meta_data ->> 'avatar_url',
        NEW.raw_user_meta_data ->> 'picture'
    )), '');

    v_email      := COALESCE(NEW.email, NEW.raw_user_meta_data ->> 'email');

    -- ── Idempotent profile upsert ──────────────────────────────────────────
    INSERT INTO public.profiles (
        id,
        email,
        full_name,
        avatar_url,
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
        v_avatar_url,
        v_home_site_id,
        'inactive',
        0,
        now(),
        now()
    )
    ON CONFLICT (id) DO UPDATE
        SET
            email         = EXCLUDED.email,
            full_name     = COALESCE(public.profiles.full_name, EXCLUDED.full_name),
            avatar_url    = COALESCE(public.profiles.avatar_url, EXCLUDED.avatar_url),
            home_site_id  = COALESCE(public.profiles.home_site_id, EXCLUDED.home_site_id),
            updated_at    = now();

    RETURN NEW;

EXCEPTION
    WHEN OTHERS THEN
        BEGIN
            INSERT INTO public.trigger_error_log
                (error_code, error_message, user_id, payload_snapshot)
            VALUES (
                SQLSTATE,
                format('handle_new_user EXCEPTION on user %s: %s', NEW.id, SQLERRM),
                NEW.id,
                NEW.raw_user_meta_data
            );
        EXCEPTION WHEN OTHERS THEN
            NULL;
        END;
        RETURN NEW;
END;
$$;

-- ==============================================================================
-- 15_auto_confirm_email.sql
-- TIGERBAY LOYALTY - AUTO-CONFIRM USERS & BYPASS EMAIL VERIFICATION BLOCK
-- ==============================================================================
-- 
-- Why this is required:
-- TigerBay uses Twilio SMS Phone OTP as the primary security verification factor
-- for customer registration. When Supabase email confirmation is enabled,
-- demo/test accounts (like da@gmail.com) and customers who haven't clicked an
-- inbox link are blocked by Supabase with "Email not confirmed".
--
-- Running this script:
-- 1. Instantly confirms all existing accounts (including test/demo accounts).
-- 2. Sets a database trigger so all new user registrations are auto-confirmed.
-- ==============================================================================

-- 1. Confirm all existing users in auth.users immediately
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, now()),
    updated_at = now()
WHERE email_confirmed_at IS NULL;

-- 2. Create the auto-confirm trigger function
CREATE OR REPLACE FUNCTION public.auto_confirm_user_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
BEGIN
    NEW.email_confirmed_at := COALESCE(NEW.email_confirmed_at, now());
    RETURN NEW;
END;
$$;

-- 3. Attach BEFORE INSERT trigger on auth.users
DROP TRIGGER IF EXISTS on_auth_user_auto_confirm ON auth.users;

CREATE TRIGGER on_auth_user_auto_confirm
    BEFORE INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.auto_confirm_user_email();

COMMENT ON FUNCTION public.auto_confirm_user_email() IS
    'Auto-confirms user email address at insert time so mobile SMS-verified users are never blocked by GoTrue email confirmation requirements.';

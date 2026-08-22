-- ============================================================
-- 13_allocate_points_and_attendance.sql — TigerBay International
-- ============================================================
-- 1. allocate_points_by_member_code RPC for staff points issuance with tier multiplier
-- 2. staff_shift_logs table for attendance & shifts tracking
-- ============================================================

-- ── 1. Create staff_shift_logs table if not exists ─────────────────────────
CREATE TABLE IF NOT EXISTS public.staff_shift_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id UUID NOT NULL,
    branch_id TEXT,
    check_in_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    check_out_time TIMESTAMPTZ,
    total_shift_hours NUMERIC(6, 2),
    check_in_lat NUMERIC(10, 6) NOT NULL DEFAULT 0.0,
    check_in_lng NUMERIC(10, 6) NOT NULL DEFAULT 0.0,
    check_in_wifi_bssid TEXT DEFAULT 'N/A',
    status TEXT NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'COMPLETED', 'FLAGGED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_staff_shift_logs_staff_status
    ON public.staff_shift_logs(staff_id, status);

-- ── 2. Create allocate_points_by_member_code RPC Function ──────────────────
CREATE OR REPLACE FUNCTION public.allocate_points_by_member_code(
    p_member_code TEXT,
    p_bill_amount NUMERIC,
    p_venue_id TEXT DEFAULT NULL,
    p_staff_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_customer_name TEXT;
    v_tier_id INT;
    v_tier_name TEXT := 'Bronze';
    v_multiplier NUMERIC := 1.0;
    v_points_earned INT;
    v_current_balance INT := 0;
    v_new_balance INT := 0;
BEGIN
    -- 1. Find profile by member_code or id or email
    SELECT id, COALESCE(full_name, name, email, 'Member ' || p_member_code), membership_tier_id, loyalty_tier
    INTO v_user_id, v_customer_name, v_tier_id, v_tier_name
    FROM public.profiles
    WHERE member_code = p_member_code
       OR id::text = p_member_code
       OR LOWER(email) = LOWER(p_member_code)
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'No customer found matching member code %', p_member_code;
    END IF;

    -- 2. Determine Tier Multiplier
    IF v_tier_id IS NOT NULL THEN
        SELECT COALESCE(name, 'Tier'), COALESCE(strips_per_booking, 1)::numeric
        INTO v_tier_name, v_multiplier
        FROM public.membership_tiers
        WHERE id = v_tier_id;
    ELSE
        -- Fallback to loyalty_tier text
        v_multiplier := CASE LOWER(COALESCE(v_tier_name, 'bronze'))
            WHEN 'black diamond' THEN 4.0
            WHEN 'black_diamond' THEN 4.0
            WHEN 'platinum' THEN 3.0
            WHEN 'gold' THEN 2.0
            WHEN 'silver' THEN 1.5
            ELSE 1.0
        END;
    END IF;

    -- 3. Calculate points earned
    v_points_earned := ROUND(p_bill_amount * v_multiplier);

    -- 4. Update or insert loyalty_accounts balance
    SELECT COALESCE(points_balance, 0) INTO v_current_balance
    FROM public.loyalty_accounts
    WHERE user_id = v_user_id;

    IF NOT FOUND THEN
        INSERT INTO public.loyalty_accounts (user_id, points_balance)
        VALUES (v_user_id, v_points_earned);
        v_new_balance := v_points_earned;
    ELSE
        v_new_balance := v_current_balance + v_points_earned;
        UPDATE public.loyalty_accounts
        SET points_balance = v_new_balance,
            updated_at = now()
        WHERE user_id = v_user_id;
    END IF;

    -- 5. Insert transaction log
    INSERT INTO public.loyalty_transactions
        (user_id, branch_id, points, type, description, spend_amount, created_at)
    VALUES
        (
            v_user_id,
            CASE WHEN p_venue_id IS NOT NULL AND p_venue_id ~ '^[0-9a-fA-F-]{36}$' THEN p_venue_id::uuid ELSE NULL END,
            v_points_earned,
            'earned',
            'Bill award (£' || to_char(p_bill_amount, 'FM999990.00') || ') × ' || v_multiplier || 'x (' || v_tier_name || ')',
            p_bill_amount,
            now()
        );

    -- 6. Trigger loyalty tier update if function exists
    BEGIN
        PERFORM public.update_loyalty_tier(v_user_id);
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    -- 7. Return summary JSON
    RETURN jsonb_build_object(
        'customer_name', v_customer_name,
        'tier_name', v_tier_name,
        'multiplier', v_multiplier,
        'bill_amount', to_char(p_bill_amount, 'FM999990.00'),
        'points_earned', v_points_earned,
        'new_balance', v_new_balance
    );
END;
$$;

-- ── 3. Create staff_auth_otps table if not exists ──────────────────────────
CREATE TABLE IF NOT EXISTS public.staff_auth_otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    staff_id TEXT NOT NULL,
    email TEXT NOT NULL,
    otp TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_staff_auth_otps_email_exp
    ON public.staff_auth_otps(email, expires_at DESC);

-- ── 4. Create verify_staff_otp RPC Function ────────────────────────────────
CREATE OR REPLACE FUNCTION public.verify_staff_otp(
    p_identifier TEXT,
    p_otp_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_clean_id TEXT := LOWER(TRIM(p_identifier));
    v_clean_otp TEXT := TRIM(p_otp_code);
    v_staff_id TEXT;
    v_email TEXT;
    v_staff_row RECORD;
BEGIN
    -- 1. Find matching valid OTP
    SELECT staff_id, email INTO v_staff_id, v_email
    FROM public.staff_auth_otps
    WHERE (LOWER(email) = v_clean_id OR LOWER(staff_id) = v_clean_id)
      AND otp = v_clean_otp
      AND expires_at >= now() - interval '10 minutes'
    ORDER BY expires_at DESC
    LIMIT 1;

    IF v_email IS NULL AND v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Invalid or expired OTP. Please try again.';
    END IF;

    -- 2. Fetch staff_members profile
    SELECT id, staff_id, name, full_name, email, role, pin_hash, branch_id, venue_id, tier_level, is_active, created_at
    INTO v_staff_row
    FROM public.staff_members
    WHERE (LOWER(email) = LOWER(COALESCE(v_email, v_clean_id))
        OR LOWER(staff_id) = LOWER(COALESCE(v_staff_id, v_clean_id))
        OR id::text = COALESCE(v_staff_id, v_clean_id))
    LIMIT 1;

    IF v_staff_row.id IS NULL THEN
        RAISE EXCEPTION 'Staff member not found.';
    END IF;

    IF v_staff_row.is_active = false THEN
        RAISE EXCEPTION 'This account has been deactivated.';
    END IF;

    -- 3. Return staff profile JSON
    RETURN jsonb_build_object(
        'id', v_staff_row.id,
        'staff_id', v_staff_row.staff_id,
        'name', v_staff_row.name,
        'full_name', v_staff_row.full_name,
        'email', v_staff_row.email,
        'role', v_staff_row.role,
        'pin_hash', v_staff_row.pin_hash,
        'branch_id', v_staff_row.branch_id,
        'venue_id', v_staff_row.venue_id,
        'tier_level', COALESCE(v_staff_row.tier_level, 'Tier A'),
        'is_active', v_staff_row.is_active,
        'created_at', v_staff_row.created_at
    );
END;
$$;


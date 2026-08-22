-- ============================================================
-- 14_strips_economy_rpc.sql — TigerBay International
-- ============================================================
-- The customer app reads balances from profiles.strips_balance and history
-- from strips_ledger. The older loyalty_accounts / loyalty_transactions
-- tables are NOT exposed via PostgREST in this project (PGRST205), so all
-- staff-side credit/debit MUST go through these SECURITY DEFINER RPCs.
--
-- Run this whole file in: Supabase Studio → SQL Editor → New query → RUN

-- ── 1. Redeem strips from a member's balance (staff redemption flow) ────────
CREATE OR REPLACE FUNCTION public.redeem_strips_for_member(
    p_member_code  TEXT,
    p_strips_cost  INTEGER,
    p_reward_title TEXT,
    p_staff_id     UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id     UUID;
    v_balance     INTEGER := 0;
BEGIN
    IF p_strips_cost IS NULL OR p_strips_cost <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'error', 'INVALID_COST');
    END IF;

    -- Resolve member exactly like allocate_points_by_member_code does.
    SELECT id INTO v_user_id
    FROM public.profiles
    WHERE member_code = p_member_code
       OR id::text = p_member_code
       OR LOWER(email) = LOWER(p_member_code)
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'error', 'CUSTOMER_NOT_FOUND');
    END IF;

    -- Lock the row so two redemptions cannot race past the balance check.
    SELECT COALESCE(strips_balance, 0) INTO v_balance
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    IF v_balance < p_strips_cost THEN
        RETURN jsonb_build_object(
            'ok', false,
            'error', 'INSUFFICIENT_BALANCE',
            'balance', v_balance,
            'required', p_strips_cost
        );
    END IF;

    UPDATE public.profiles
    SET strips_balance = strips_balance - p_strips_cost,
        updated_at = now()
    WHERE id = v_user_id;

    INSERT INTO public.strips_ledger
        (user_id, amount, transaction_type, description, created_at)
    VALUES
        (v_user_id,
         p_strips_cost,
         'redeem',
         'Redeemed: ' || COALESCE(p_reward_title, 'Reward'),
         now());

    RETURN jsonb_build_object(
        'ok', true,
        'balance', v_balance - p_strips_cost,
        'redeemed', p_strips_cost,
        'staff_id', p_staff_id
    );
END;
$$;

-- ── 2. Award strips to a member (staff billing / issue-points flow) ─────────
CREATE OR REPLACE FUNCTION public.award_strips_for_member(
    p_member_code TEXT,
    p_strips      INTEGER,
    p_description TEXT,
    p_staff_id    UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id UUID;
    v_balance INTEGER := 0;
BEGIN
    IF p_strips IS NULL OR p_strips <= 0 THEN
        RETURN jsonb_build_object('ok', false, 'error', 'INVALID_AMOUNT');
    END IF;

    SELECT id INTO v_user_id
    FROM public.profiles
    WHERE member_code = p_member_code
       OR id::text = p_member_code
       OR LOWER(email) = LOWER(p_member_code)
    LIMIT 1;

    IF v_user_id IS NULL THEN
        RETURN jsonb_build_object('ok', false, 'error', 'CUSTOMER_NOT_FOUND');
    END IF;

    SELECT COALESCE(strips_balance, 0) INTO v_balance
    FROM public.profiles
    WHERE id = v_user_id
    FOR UPDATE;

    UPDATE public.profiles
    SET strips_balance = COALESCE(strips_balance, 0) + p_strips,
        updated_at = now()
    WHERE id = v_user_id;

    INSERT INTO public.strips_ledger
        (user_id, amount, transaction_type, description, created_at)
    VALUES
        (v_user_id,
         p_strips,
         'credit',
         COALESCE(p_description, 'Strips awarded'),
         now());

    RETURN jsonb_build_object(
        'ok', true,
        'balance', v_balance + p_strips,
        'awarded', p_strips,
        'staff_id', p_staff_id
    );
END;
$$;

-- ── 3. Ensure authenticated staff may execute both functions ────────────────
GRANT EXECUTE ON FUNCTION public.redeem_strips_for_member(TEXT, INTEGER, TEXT, UUID)
    TO authenticated;
GRANT EXECUTE ON FUNCTION public.award_strips_for_member(TEXT, INTEGER, TEXT, UUID)
    TO authenticated;

-- Notify PostgREST that new functions are available.
NOTIFY pgrst, 'reload schema';

-- ═══════════════════════════════════════════════════════════════════════════
-- TigerBay International — Migration 10: PayPal Order ID on Profiles
-- ═══════════════════════════════════════════════════════════════════════════
-- Adds paypal_order_id to public.profiles so that the app can record the
-- PayPal transaction reference after a successful membership subscription
-- payment. Used for audit trail and support queries.
--
-- Safe to run multiple times (uses IF NOT EXISTS guard).
-- ═══════════════════════════════════════════════════════════════════════════

-- Add paypal_order_id column if it doesn't already exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'profiles'
      AND column_name  = 'paypal_order_id'
  ) THEN
    ALTER TABLE public.profiles
      ADD COLUMN paypal_order_id text;

    COMMENT ON COLUMN public.profiles.paypal_order_id IS
      'PayPal order/payment ID recorded after a successful membership '
      'subscription payment. Null for users who have not yet paid.';
  END IF;
END $$;

-- ============================================================
-- 07_rls_policies.sql  –  Row Level Security
-- Users can only access their OWN data.
-- Public/read-only tables (branches, menus, newsfeeds) are open.
-- ============================================================

-- ── Enable RLS on all tables ──────────────────────────────────────────────────

alter table public.profiles           enable row level security;
alter table public.device_bindings    enable row level security;
alter table public.security_events    enable row level security;
alter table public.loyalty_accounts   enable row level security;
alter table public.loyalty_transactions enable row level security;
alter table public.physical_cards     enable row level security;
alter table public.qr_secrets         enable row level security;
alter table public.bookings           enable row level security;
alter table public.branches           enable row level security;
alter table public.menu_items         enable row level security;
alter table public.newsfeeds          enable row level security;

-- ── profiles ──────────────────────────────────────────────────────────────────

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- ── device_bindings ───────────────────────────────────────────────────────────

create policy "Users can view own device bindings"
  on public.device_bindings for select
  using (auth.uid() = user_id);

create policy "Users can insert own device binding"
  on public.device_bindings for insert
  with check (auth.uid() = user_id);

-- ── security_events ───────────────────────────────────────────────────────────

create policy "Users can view own security events"
  on public.security_events for select
  using (auth.uid() = user_id);

-- Only service role can insert security events
create policy "Service role can insert security events"
  on public.security_events for insert
  with check (auth.role() = 'service_role');

-- ── loyalty_accounts ─────────────────────────────────────────────────────────

create policy "Users can view own loyalty account"
  on public.loyalty_accounts for select
  using (auth.uid() = user_id);

-- Only service role (RPC functions) can modify loyalty accounts
create policy "Service role can modify loyalty accounts"
  on public.loyalty_accounts for all
  using (auth.role() = 'service_role');

-- ── loyalty_transactions ─────────────────────────────────────────────────────

create policy "Users can view own transactions"
  on public.loyalty_transactions for select
  using (auth.uid() = user_id);

create policy "Service role can insert transactions"
  on public.loyalty_transactions for insert
  with check (auth.role() = 'service_role');

-- ── physical_cards ────────────────────────────────────────────────────────────

-- Users can only see cards linked to them
create policy "Users can view own linked card"
  on public.physical_cards for select
  using (auth.uid() = linked_to);

create policy "Service role manages physical cards"
  on public.physical_cards for all
  using (auth.role() = 'service_role');

-- ── qr_secrets ───────────────────────────────────────────────────────────────

create policy "Users can view own QR secret"
  on public.qr_secrets for select
  using (auth.uid() = user_id);

-- ── bookings ──────────────────────────────────────────────────────────────────

create policy "Users can view own bookings"
  on public.bookings for select
  using (auth.uid() = user_id);

create policy "Users can insert own bookings"
  on public.bookings for insert
  with check (auth.uid() = user_id);

create policy "Users can update own bookings"
  on public.bookings for update
  using (auth.uid() = user_id);

-- ── branches (public read) ────────────────────────────────────────────────────

create policy "Branches are publicly readable"
  on public.branches for select
  using (is_active = true);

-- ── menu_items (public read) ──────────────────────────────────────────────────

create policy "Menu items are publicly readable"
  on public.menu_items for select
  using (is_available = true);

-- ── newsfeeds (public read) ───────────────────────────────────────────────────

create policy "Newsfeeds are publicly readable"
  on public.newsfeeds for select
  using (
    (expires_at is null or expires_at > now())
  );

-- ── Storage bucket for avatars ────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict do nothing;

create policy "Users can upload own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Avatars are publicly readable"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Users can update own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars' and
    auth.uid()::text = (storage.foldername(name))[1]
  );

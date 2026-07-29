-- ============================================================
-- 02_loyalty.sql  –  points, transactions, physical cards, QR
-- ============================================================

-- Loyalty account (1 per user)
create table if not exists public.loyalty_accounts (
  id                          uuid primary key default gen_random_uuid(),
  user_id                     uuid not null unique references public.profiles(id) on delete cascade,
  points_balance              integer not null default 0 check (points_balance >= 0),
  cash_value                  numeric(10,2) generated always as (points_balance * 0.10) stored,
  linked_physical_card_number text,
  physical_card_linked        boolean not null default false,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create trigger loyalty_accounts_updated_at
  before update on public.loyalty_accounts
  for each row execute procedure public.set_updated_at();

-- Auto-create loyalty account on profile creation
create or replace function public.handle_new_profile()
returns trigger language plpgsql security definer as $$
begin
  insert into public.loyalty_accounts (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created on public.profiles;
create trigger on_profile_created
  after insert on public.profiles
  for each row execute procedure public.handle_new_profile();

-- Loyalty transactions
create table if not exists public.loyalty_transactions (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  branch_id    uuid,
  branch_name  text,
  points       integer not null,
  type         text not null check (type in ('earned','redeemed','adjusted','expired')),
  description  text,
  spend_amount numeric(10,2),
  created_at   timestamptz not null default now()
);

create index idx_loyalty_transactions_user_id
  on public.loyalty_transactions(user_id, created_at desc);

-- Award points (staff action — called via Supabase RPC or Edge Function)
create or replace function public.award_loyalty_points(
  p_user_id    uuid,
  p_points     integer,
  p_spend_amount numeric,
  p_branch_id  uuid,
  p_description text
) returns void language plpgsql security definer as $$
begin
  -- Insert transaction
  insert into public.loyalty_transactions
    (user_id, branch_id, points, type, description, spend_amount)
  values
    (p_user_id, p_branch_id, p_points, 'earned', p_description, p_spend_amount);

  -- Update balance
  update public.loyalty_accounts
  set points_balance = points_balance + p_points
  where user_id = p_user_id;

  -- Update loyalty tier
  perform public.update_loyalty_tier(p_user_id);
end;
$$;

-- Redeem points
create or replace function public.redeem_loyalty_points(
  p_user_id    uuid,
  p_points     integer,
  p_description text
) returns void language plpgsql security definer as $$
declare
  v_balance integer;
begin
  select points_balance into v_balance
  from public.loyalty_accounts
  where user_id = p_user_id;

  if v_balance < p_points then
    raise exception 'Insufficient points balance';
  end if;

  insert into public.loyalty_transactions
    (user_id, points, type, description)
  values
    (p_user_id, p_points, 'redeemed', p_description);

  update public.loyalty_accounts
  set points_balance = points_balance - p_points
  where user_id = p_user_id;
end;
$$;

-- Update loyalty tier based on lifetime points
create or replace function public.update_loyalty_tier(p_user_id uuid)
returns void language plpgsql security definer as $$
declare
  v_total_earned integer;
  v_tier text;
begin
  select coalesce(sum(points), 0) into v_total_earned
  from public.loyalty_transactions
  where user_id = p_user_id and type = 'earned';

  v_tier := case
    when v_total_earned >= 10000 then 'platinum'
    when v_total_earned >= 5000  then 'gold'
    when v_total_earned >= 1000  then 'silver'
    else 'bronze'
  end;

  update public.profiles
  set loyalty_tier = v_tier
  where id = p_user_id;
end;
$$;

-- Physical cards master table
create table if not exists public.physical_cards (
  id          uuid primary key default gen_random_uuid(),
  card_number text not null unique,
  is_linked   boolean not null default false,
  linked_to   uuid references public.profiles(id),
  linked_at   timestamptz,
  created_at  timestamptz not null default now()
);

-- Link physical card to digital account
create or replace function public.link_physical_card(
  p_user_id    uuid,
  p_card_number text
) returns void language plpgsql security definer as $$
declare
  v_card_points integer := 0;
begin
  -- Mark card as linked
  update public.physical_cards
  set is_linked = true,
      linked_to = p_user_id,
      linked_at = now()
  where card_number = p_card_number;

  -- Update loyalty account
  update public.loyalty_accounts
  set linked_physical_card_number = p_card_number,
      physical_card_linked = true
  where user_id = p_user_id;
end;
$$;

-- QR secrets table (one secret per user for HMAC signing)
create table if not exists public.qr_secrets (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references public.profiles(id) on delete cascade,
  secret     text not null default encode(gen_random_bytes(32), 'hex'),
  created_at timestamptz not null default now()
);

-- Auto-create QR secret on profile creation
create or replace function public.handle_new_profile_qr()
returns trigger language plpgsql security definer as $$
begin
  insert into public.qr_secrets (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_profile_created_qr on public.profiles;
create trigger on_profile_created_qr
  after insert on public.profiles
  for each row execute procedure public.handle_new_profile_qr();

-- ============================================================
-- 01_users.sql  –  TigerBay International member profiles
-- ============================================================

create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  full_name       text,
  email           text,
  phone           text,
  avatar_url      text,
  device_id       text,
  loyalty_tier    text not null default 'bronze'
                    check (loyalty_tier in ('bronze','silver','gold','platinum')),
  preferred_branch_id uuid,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email, phone, created_at, updated_at)
  values (
    new.id,
    new.email,
    new.phone,
    now(),
    now()
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Auto-update updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- Device bindings (1:1 anti-fraud)
create table if not exists public.device_bindings (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id) on delete cascade,
  device_id     text not null,
  platform      text,
  device_model  text,
  os_version    text,
  bound_at      timestamptz not null default now(),
  unique (user_id)
);

-- Security event log
create table if not exists public.security_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles(id) on delete set null,
  event_type  text not null,
  details     jsonb,
  created_at  timestamptz not null default now()
);

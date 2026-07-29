-- ============================================================
-- 05_branches.sql  –  TigerBay International venue branches
-- ============================================================

create table if not exists public.branches (
  id                    uuid primary key default gen_random_uuid(),
  name                  text not null,
  city                  text not null,
  address               text not null,
  image_url             text,
  is_active             boolean not null default true,
  available_time_slots  text[] not null default array[
    '17:00','17:30','18:00','18:30','19:00','19:30',
    '20:00','20:30','21:00','21:30','22:00','22:30'
  ],
  deposit_amount        numeric(10,2) not null default 20.00,
  max_party_size        integer not null default 12,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create trigger branches_updated_at
  before update on public.branches
  for each row execute procedure public.set_updated_at();

-- ── Sample branches ───────────────────────────────────────────────────────────

insert into public.branches (id, name, city, address, is_active)
values
  ('00000000-0000-0000-0000-000000000001',
   'London Mayfair', 'London',
   '15 Mayfair Street, London W1J 5QD', true),

  ('00000000-0000-0000-0000-000000000002',
   'Tiger Bay', 'Cardiff',
   '2 Bute Street, Cardiff CF10 5AN', true),

  ('00000000-0000-0000-0000-000000000003',
   'The Terrace Lounge', 'London',
   '8 Knightsbridge, London SW1X 7QL', true)

on conflict (id) do nothing;

-- Add foreign key from profiles to branches now both tables exist
alter table public.profiles
  add constraint fk_profiles_preferred_branch
  foreign key (preferred_branch_id)
  references public.branches(id)
  on delete set null
  not valid;

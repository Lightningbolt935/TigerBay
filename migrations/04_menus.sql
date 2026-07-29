-- ============================================================
-- 04_menus.sql  –  dynamic menus: food, drinks, shisha
-- ============================================================

create table if not exists public.menu_items (
  id           uuid primary key default gen_random_uuid(),
  branch_id    uuid not null,
  name         text not null,
  description  text,
  price        numeric(10,2) not null check (price >= 0),
  category     text not null check (category in ('food','drinks','shisha')),
  subcategory  text,            -- e.g. 'Signature Cocktails', 'Luxury Small Plates'
  image_url    text,
  is_available boolean not null default true,
  is_featured  boolean not null default false,
  allergens    text[] not null default '{}',
  sort_order   integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_menu_items_branch_category
  on public.menu_items(branch_id, category, is_available, sort_order);

create trigger menu_items_updated_at
  before update on public.menu_items
  for each row execute procedure public.set_updated_at();

-- ── Sample data ──────────────────────────────────────────────────────────────
-- (Replace branch_id with your actual branch UUIDs after running 05_branches.sql)

insert into public.menu_items
  (branch_id, name, description, price, category, subcategory, is_featured, sort_order)
values
  -- Drinks – Signature Cocktails
  ('00000000-0000-0000-0000-000000000001', 'Gold Leaf Martini',
   'Premium vodka, dry vermouth, 24k edible gold flakes.',
   24.00, 'drinks', 'Signature Cocktails', true, 1),

  ('00000000-0000-0000-0000-000000000001', 'Mayfair Mule',
   'Ginger beer, fresh lime, and house-infused botanical gin.',
   18.00, 'drinks', 'Signature Cocktails', true, 2),

  ('00000000-0000-0000-0000-000000000001', 'Obsidian Negroni',
   'Aged Campari, sweet vermouth, activated charcoal gin.',
   22.00, 'drinks', 'Signature Cocktails', false, 3),

  -- Food – Luxury Small Plates
  ('00000000-0000-0000-0000-000000000001', 'Truffle Arancini',
   'Wild mushroom risotto balls with black truffle aioli.',
   16.00, 'food', 'Luxury Small Plates', true, 1),

  ('00000000-0000-0000-0000-000000000001', 'Wagyu Sliders',
   'A5 Wagyu beef, aged cheddar, brioche bun.',
   28.00, 'food', 'Luxury Small Plates', true, 2),

  ('00000000-0000-0000-0000-000000000001', 'Burrata & Heirloom Tomatoes',
   'Hand-stretched burrata, heirloom tomatoes, aged balsamic.',
   18.00, 'food', 'Luxury Small Plates', false, 3),

  -- Food – Mains
  ('00000000-0000-0000-0000-000000000001', 'Dry-Aged Côte de Bœuf',
   '28-day dry-aged rib of beef, bone marrow butter, triple-cooked chips.',
   85.00, 'food', 'Mains', false, 1),

  -- Shisha
  ('00000000-0000-0000-0000-000000000001', 'Signature Blend',
   'Our house blend of premium tobacco with a hint of rose.',
   45.00, 'shisha', 'Classic Flavours', true, 1),

  ('00000000-0000-0000-0000-000000000001', 'Double Apple',
   'Classic double apple blend, light and refreshing.',
   40.00, 'shisha', 'Classic Flavours', false, 2),

  ('00000000-0000-0000-0000-000000000001', 'Grape Mint Royale',
   'Fresh grape with cool mint and a touch of ice.',
   40.00, 'shisha', 'Premium Blends', false, 3)

on conflict do nothing;

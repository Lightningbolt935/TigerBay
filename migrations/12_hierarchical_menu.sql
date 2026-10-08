-- ==============================================================================
-- 12_hierarchical_menu.sql  –  Hierarchical Menu & Category Schema for Tiger Bay
-- ==============================================================================
-- Run this in your Supabase Dashboard SQL Editor:
-- https://supabase.com/dashboard/project/xxnqlktcbwqhoyezlokv/sql
-- ==============================================================================

-- 1. Create table for dynamic menu categories & sections
create table if not exists public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  menu_type text not null check (menu_type in ('food', 'drinks', 'shisha')),
  parent_id uuid references public.menu_categories(id) on delete cascade,
  name text not null,
  description text,
  image_url text,
  display_order integer not null default 0,
  is_active boolean not null default true,
  branch_id integer references public.branches(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for speedy hierarchical querying
create index if not exists idx_menu_categories_parent_order
  on public.menu_categories(menu_type, parent_id, display_order, is_active);

-- Enable RLS
alter table public.menu_categories enable row level security;

-- Drop any existing policies to prevent conflicts
drop policy if exists "Allow public read on menu_categories" on public.menu_categories;
drop policy if exists "Allow full access for authenticated/service" on public.menu_categories;

-- Allow anyone (including anon key) to read categories
create policy "Allow public read on menu_categories"
  on public.menu_categories for select
  using (true);

-- Allow authenticated / service role to insert, update, delete
create policy "Allow full access for authenticated/service"
  on public.menu_categories for all
  using (true)
  with check (true);

-- 2. Create item variants table (e.g. 175ml, 250ml, Bottle)
create table if not exists public.item_variants (
  id uuid primary key default gen_random_uuid(),
  dish_id integer not null,
  name text not null,
  price numeric(10,2) not null check (price >= 0),
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.item_variants enable row level security;
drop policy if exists "Allow public read on item_variants" on public.item_variants;
create policy "Allow public read on item_variants" on public.item_variants for select using (true);
drop policy if exists "Allow full access on item_variants" on public.item_variants;
create policy "Allow full access on item_variants" on public.item_variants for all using (true) with check (true);

-- 3. Create item add-ons table (e.g. Add Cheese +£1.00, Fruit Head +£10.00)
create table if not exists public.item_addons (
  id uuid primary key default gen_random_uuid(),
  dish_id integer not null,
  name text not null,
  price numeric(10,2) not null check (price >= 0),
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.item_addons enable row level security;
drop policy if exists "Allow public read on item_addons" on public.item_addons;
create policy "Allow public read on item_addons" on public.item_addons for select using (true);
drop policy if exists "Allow full access on item_addons" on public.item_addons;
create policy "Allow full access on item_addons" on public.item_addons for all using (true) with check (true);

-- 4. Add category_id and subcategory columns to dishes if not present
alter table public.dishes add column if not exists category_id uuid references public.menu_categories(id) on delete set null;
alter table public.dishes add column if not exists subcategory text;

-- ==============================================================================
-- SEED DATA: Real Tiger Bay Menus Hierarchy
-- ==============================================================================

-- Clean existing seed to allow re-running
delete from public.menu_categories;

do $$
declare
  -- Food Roots
  v_indian_food_id uuid;
  v_late_night_id uuid;
  
  -- Drinks Roots
  v_wine_id uuid;
  v_spirits_id uuid;
begin

  -- ── A. FOOD SECTIONS ───────────────────────────────────────────────────────
  
  -- 1. Indian Food (Parent)
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('food', null, 'Indian Food', 'Authentic culinary experience & rich tandoori grills', 1)
  returning id into v_indian_food_id;

  -- Indian Food Subsections (from TB-FOOD-MENU.pdf)
  insert into public.menu_categories (menu_type, parent_id, name, display_order) values
    ('food', v_indian_food_id, 'Pre-Starters', 1),
    ('food', v_indian_food_id, 'Vegetarian Starters', 2),
    ('food', v_indian_food_id, 'Non-Vegetarian Starters', 3),
    ('food', v_indian_food_id, 'Indo-Chinese', 4),
    ('food', v_indian_food_id, 'Vegetarian Main Course', 5),
    ('food', v_indian_food_id, 'Non-Vegetarian Mains', 6),
    ('food', v_indian_food_id, 'Sea Food', 7),
    ('food', v_indian_food_id, 'Hyderabadi Biryani', 8),
    ('food', v_indian_food_id, 'Oriental Rice & Noodles', 9),
    ('food', v_indian_food_id, 'Wraps', 10),
    ('food', v_indian_food_id, 'Rice & Breads', 11),
    ('food', v_indian_food_id, 'Salads & Extras', 12),
    ('food', v_indian_food_id, 'Desserts', 13);

  -- 2. Late Night Menu (Parent, Served until 01:30 everyday)
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('food', null, 'Late Night', 'Served until 01:30 everyday', 2)
  returning id into v_late_night_id;

  insert into public.menu_categories (menu_type, parent_id, name, display_order) values
    ('food', v_late_night_id, 'Late Night Starters & Bites', 1);

  -- ── B. DRINKS SECTIONS ─────────────────────────────────────────────────────

  -- Cocktails
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Cocktails', 1);

  -- Mocktails
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Mocktails', 2);

  -- Wine (Parent)
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('drinks', null, 'Wine', 'Fine red, white and rosé selections', 3)
  returning id into v_wine_id;

  -- Wine Subsections
  insert into public.menu_categories (menu_type, parent_id, name, display_order) values
    ('drinks', v_wine_id, 'White Wine', 1),
    ('drinks', v_wine_id, 'Red Wine', 2),
    ('drinks', v_wine_id, 'Rosé Wine', 3);

  -- Champagne
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Champagne', 4);

  -- Spirits (Parent)
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('drinks', null, 'Spirits', 'Premium liquors and reserve bottles', 5)
  returning id into v_spirits_id;

  -- Spirits Subsections
  insert into public.menu_categories (menu_type, parent_id, name, display_order) values
    ('drinks', v_spirits_id, 'Vodka', 1),
    ('drinks', v_spirits_id, 'Cognac', 2),
    ('drinks', v_spirits_id, 'Rum', 3),
    ('drinks', v_spirits_id, 'Tequila', 4),
    ('drinks', v_spirits_id, 'Gin', 5),
    ('drinks', v_spirits_id, 'Whisky', 6);

  -- Beer & Cider
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Beer & Cider', 6);

  -- Soft Drinks & Juices
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Soft Drinks & Juices', 7);

  -- ── C. SHISHA SECTIONS ─────────────────────────────────────────────────────

  insert into public.menu_categories (menu_type, parent_id, name, description, display_order) values
    ('shisha', null, 'Flavours', 'Signature Savacco, Starbuzz & Al Fakher blends', 1),
    ('shisha', null, 'Fruit Head', 'Upgrades carved from fresh pineapples and grapefruits', 2),
    ('shisha', null, 'VIP', 'Exclusive master blends and gold lounges', 3);

end $$;

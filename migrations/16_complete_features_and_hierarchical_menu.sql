-- ==============================================================================
-- 16_complete_features_and_hierarchical_menu.sql
-- COMPLETE TIGER BAY DATABASE SETUP:
-- 1. Hierarchical Menu Categories & Subcategories (Food, Drinks, Shisha)
-- 2. Item Variants & Add-ons
-- 3. Branch venue details (Timings, Address, Phone, WhatsApp, 3-image carousel)
-- 4. What's On (Newsfeeds / Events)
-- 5. Packages (VIP & Group packages)
-- 6. Customer Enquiries (Contact Us -> bookings@tigerbayshisha.co.uk)
-- 7. Rewards Auto-Expiry
-- ==============================================================================

-- ── 1. MENU CATEGORIES ────────────────────────────────────────────────────────
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

create index if not exists idx_menu_categories_parent_order
  on public.menu_categories(menu_type, parent_id, display_order, is_active);

alter table public.menu_categories enable row level security;
drop policy if exists "Allow public read on menu_categories" on public.menu_categories;
create policy "Allow public read on menu_categories" on public.menu_categories for select using (true);
drop policy if exists "Allow full access for authenticated/service" on public.menu_categories;
create policy "Allow full access for authenticated/service" on public.menu_categories for all using (true) with check (true);

-- ── 2. ITEM VARIANTS & ADD-ONS ────────────────────────────────────────────────
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

-- ── 3. EXTEND DISHES ──────────────────────────────────────────────────────────
alter table public.dishes add column if not exists category_id uuid references public.menu_categories(id) on delete set null;
alter table public.dishes add column if not exists subcategory text;

-- ── 4. EXTEND BRANCHES WITH VENUE DETAILS & CAROUSEL ──────────────────────────
alter table public.branches add column if not exists address text;
alter table public.branches add column if not exists phone text;
alter table public.branches add column if not exists email text;
alter table public.branches add column if not exists opening_hours text;
alter table public.branches add column if not exists whatsapp_number text;
alter table public.branches add column if not exists images text[];
alter table public.branches add column if not exists banner_images text[];

-- Update Branches with actual Tiger Bay data
update public.branches set
  address = '145–149 The Broadway, Burnt Oak, Edgware, HA8 5EJ',
  phone = '+44 20 8952 7777',
  email = 'bookings@tigerbayshisha.co.uk',
  opening_hours = 'Mon - Thu: 4:00 PM - 2:00 AM | Fri - Sun: 2:00 PM - 3:00 AM',
  whatsapp_number = '+447598819733',
  latitude = 51.6033,
  longitude = -0.2684,
  images = array[
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=800&auto=format&fit=crop'
  ]
where id = 2 or name ilike '%kingsbury%';

update public.branches set
  address = 'Twyford Abbey Rd, London NW10 7DS',
  phone = '+44 20 8965 2444',
  email = 'bookings@tigerbayshisha.co.uk',
  opening_hours = 'Mon - Thu: 5:00 PM - 1:30 AM | Fri - Sun: 3:00 PM - 2:30 AM',
  whatsapp_number = '+447598819733',
  latitude = 51.5312,
  longitude = -0.2891,
  images = array[
    'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&auto=format&fit=crop'
  ]
where id = 3 or name ilike '%hanger%';

update public.branches set
  address = 'Great Cambridge Rd, Enfield EN1 3HN',
  phone = '+44 20 8366 1111',
  email = 'bookings@tigerbayshisha.co.uk',
  opening_hours = 'Mon - Sun: 4:00 PM - 2:00 AM',
  whatsapp_number = '+447598819733',
  latitude = 51.6521,
  longitude = -0.0655,
  images = array[
    'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1543007630-9710e4a00a20?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800&auto=format&fit=crop'
  ]
where id = 4 or name ilike '%enfield%';

update public.branches set
  address = 'High St, Hounslow TW3 1RH',
  phone = '+44 20 8570 3333',
  email = 'bookings@tigerbayshisha.co.uk',
  opening_hours = 'Mon - Sun: 4:00 PM - 2:00 AM',
  whatsapp_number = '+447598819733',
  latitude = 51.4687,
  longitude = -0.3610,
  images = array[
    'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1525610553991-7bede1823f4e?w=800&auto=format&fit=crop',
    'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=800&auto=format&fit=crop'
  ]
where id = 1 or name ilike '%hounslow%';

-- ── 5. WHAT'S ON (NEWSFEEDS / EVENTS) ─────────────────────────────────────────
create table if not exists public.newsfeeds (
  id uuid primary key default gen_random_uuid(),
  branch_id integer references public.branches(id) on delete cascade,
  title text not null,
  subtitle text,
  description text,
  image_url text,
  category text not null default 'Events',
  is_featured boolean not null default false,
  cta_label text,
  cta_route text,
  published_at timestamptz not null default now(),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.newsfeeds enable row level security;
drop policy if exists "Allow public read on newsfeeds" on public.newsfeeds;
create policy "Allow public read on newsfeeds" on public.newsfeeds for select using (true);
drop policy if exists "Allow full access on newsfeeds" on public.newsfeeds;
create policy "Allow full access on newsfeeds" on public.newsfeeds for all using (true) with check (true);

-- Seed What's On
insert into public.newsfeeds (branch_id, title, subtitle, description, category, is_featured, cta_label, cta_route)
values
  (null, 'Live DJ Nights Every Weekend', 'Friday & Saturday from 9 PM till late', 'Experience London’s hottest lounge beats with resident DJs and guest artists.', 'Events', true, 'Book Table', '/booking'),
  (null, 'Champions League Live Screening', 'Watch every UEFA match on mega HD screens', 'Catch the best football action live with state-of-the-art sound and VIP shisha booths.', 'Sports', false, 'Reserve Booth', '/booking'),
  (null, 'Late Night Dining until 01:30 AM', 'Authentic grills, curries and cocktails', 'Our kitchen stays open until 01:30 AM everyday so you never miss out on late-night cravings.', 'Dining', false, 'View Menu', '/menu')
on conflict do nothing;

-- ── 6. PACKAGES (VIP & CELEBRATION PACKAGES) ─────────────────────────────────
create table if not exists public.packages (
  id uuid primary key default gen_random_uuid(),
  branch_id integer references public.branches(id) on delete set null,
  title text not null,
  subtitle text,
  description text,
  price numeric(10,2) not null check (price >= 0),
  image_url text,
  items text[],
  is_active boolean not null default true,
  display_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table public.packages enable row level security;
drop policy if exists "Allow public read on packages" on public.packages;
create policy "Allow public read on packages" on public.packages for select using (true);
drop policy if exists "Allow full access on packages" on public.packages;
create policy "Allow full access on packages" on public.packages for all using (true) with check (true);

-- Seed Packages
insert into public.packages (branch_id, title, subtitle, description, price, items, display_order)
values
  (null, 'VIP Shisha & Bites Package', 'For 2-4 Guests', 'The ultimate Tiger Bay experience including premium shisha, mixed platters and cocktails.', 75.00,
   array['1x Premium Shisha with Fruit Head upgrade', '1x Tiger Bay Signature Meat/Veg Platter', '2x Cocktails or Mocktails', 'VIP Lounge Seating for 2 hours'], 1),
  (null, 'Celebration & Birthday Package', 'For Groups of 4-8 Guests', 'Celebrate your special occasion in style with dedicated lounge service and champagne.', 150.00,
   array['2x Signature Shishas of your choice', '2x Grande Shared Food Platters', '1x Bottle of Moët & Chandon Champagne', 'Birthday sparklers & celebration dessert'], 2),
  (null, 'Gold Shisha Master Package', 'For 2 Guests', 'Exquisite double Russian luxury shisha with customized fresh fruit bowl.', 55.00,
   array['1x Russian Brass Gold Shisha', 'Fresh Pineapple or Grapefruit Head', 'Refill coals every 30 mins', '2x Soft Drinks or Mocktails'], 3)
on conflict do nothing;

-- ── 7. ENQUIRIES (CONTACT US / SUBMIT DIRECT ENQUIRIES) ───────────────────────
create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  branch_id integer references public.branches(id) on delete set null,
  customer_name text not null,
  customer_email text not null,
  customer_phone text,
  subject text,
  message text not null,
  status text not null default 'pending',
  recipient_email text not null default 'bookings@tigerbayshisha.co.uk',
  created_at timestamptz not null default now()
);

alter table public.enquiries enable row level security;
drop policy if exists "Allow insert on enquiries" on public.enquiries;
create policy "Allow insert on enquiries" on public.enquiries for insert with check (true);
drop policy if exists "Allow public read on enquiries" on public.enquiries;
create policy "Allow public read on enquiries" on public.enquiries for select using (true);
drop policy if exists "Allow full access on enquiries" on public.enquiries;
create policy "Allow full access on enquiries" on public.enquiries for all using (true) with check (true);

-- ── 8. REWARDS AUTO-EXPIRY ────────────────────────────────────────────────────
alter table public.rewards add column if not exists valid_days integer not null default 30;
alter table public.rewards add column if not exists expires_at timestamptz;

-- ── 9. SEED MENU CATEGORIES (REAL TIGER BAY HIERARCHY) ───────────────────────
delete from public.menu_categories;

do $$
declare
  v_indian_food_id uuid;
  v_late_night_id uuid;
  v_wine_id uuid;
  v_spirits_id uuid;
begin

  -- FOOD 1: Indian Food
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('food', null, 'Indian Food', 'Authentic culinary experience & rich tandoori grills', 1)
  returning id into v_indian_food_id;

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

  -- FOOD 2: Late Night (Served until 01:30 everyday)
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('food', null, 'Late Night', 'Served until 01:30 everyday', 2)
  returning id into v_late_night_id;

  insert into public.menu_categories (menu_type, parent_id, name, display_order) values
    ('food', v_late_night_id, 'Late Night Starters & Bites', 1);

  -- DRINKS 1: Cocktails
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Cocktails', 1);

  -- DRINKS 2: Mocktails
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Mocktails', 2);

  -- DRINKS 3: Wine (Parent)
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('drinks', null, 'Wine', 'Fine red, white and rosé selections', 3)
  returning id into v_wine_id;

  insert into public.menu_categories (menu_type, parent_id, name, display_order) values
    ('drinks', v_wine_id, 'White Wine', 1),
    ('drinks', v_wine_id, 'Red Wine', 2),
    ('drinks', v_wine_id, 'Rosé Wine', 3);

  -- DRINKS 4: Champagne
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Champagne', 4);

  -- DRINKS 5: Spirits (Parent)
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order)
  values ('drinks', null, 'Spirits', 'Premium liquors and reserve bottles', 5)
  returning id into v_spirits_id;

  insert into public.menu_categories (menu_type, parent_id, name, display_order) values
    ('drinks', v_spirits_id, 'Vodka', 1),
    ('drinks', v_spirits_id, 'Cognac', 2),
    ('drinks', v_spirits_id, 'Rum', 3),
    ('drinks', v_spirits_id, 'Tequila', 4),
    ('drinks', v_spirits_id, 'Gin', 5),
    ('drinks', v_spirits_id, 'Whisky', 6);

  -- DRINKS 6: Beer & Cider
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Beer & Cider', 6);

  -- DRINKS 7: Soft Drinks & Juices
  insert into public.menu_categories (menu_type, parent_id, name, display_order)
  values ('drinks', null, 'Soft Drinks & Juices', 7);

  -- SHISHA: Flavours, Fruit Head, VIP
  insert into public.menu_categories (menu_type, parent_id, name, description, display_order) values
    ('shisha', null, 'Flavours', 'Signature Savacco, Starbuzz & Al Fakher blends', 1),
    ('shisha', null, 'Fruit Head', 'Upgrades carved from fresh pineapples and grapefruits', 2),
    ('shisha', null, 'VIP', 'Exclusive master blends and gold lounges', 3);

end $$;

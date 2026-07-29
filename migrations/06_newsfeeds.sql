-- ============================================================
-- 06_newsfeeds.sql  –  branch-specific news and promotions
-- ============================================================

create table if not exists public.newsfeeds (
  id           uuid primary key default gen_random_uuid(),
  branch_id    uuid not null references public.branches(id) on delete cascade,
  title        text not null,
  subtitle     text,
  image_url    text,
  category     text not null default 'General',
  is_featured  boolean not null default false,
  cta_label    text,                   -- e.g. 'Reserve Spot'
  cta_route    text,                   -- deep-link route, e.g. '/booking'
  published_at timestamptz not null default now(),
  expires_at   timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_newsfeeds_branch_published
  on public.newsfeeds(branch_id, published_at desc);

create trigger newsfeeds_updated_at
  before update on public.newsfeeds
  for each row execute procedure public.set_updated_at();

-- ── Sample news items ─────────────────────────────────────────────────────────

insert into public.newsfeeds
  (branch_id, title, subtitle, category, is_featured, cta_label, cta_route, published_at)
values
  ('00000000-0000-0000-0000-000000000001',
   'Exclusive Member Sunset Soirée',
   'Join us for an unforgettable evening at The Terrace Lounge.',
   'Events', true, 'Reserve Spot', '/my-bookings/new',
   now() - interval '1 hour'),

  ('00000000-0000-0000-0000-000000000001',
   'New Autumn Tasting Menu by Chef de Cuisine',
   'Experience our six-course seasonal tasting menu.',
   'Gastronomy', false, null, null,
   now() - interval '2 hours'),

  ('00000000-0000-0000-0000-000000000001',
   'Private Yoga Sessions Now Available',
   'Start your day with an exclusive members-only yoga class.',
   'Wellness', false, null, null,
   now() - interval '5 hours'),

  ('00000000-0000-0000-0000-000000000002',
   'Tiger Bay Members Night',
   'Exclusive cocktail masterclass for TigerBay members.',
   'Events', true, 'Book Now', '/my-bookings/new',
   now() - interval '3 hours')

on conflict do nothing;

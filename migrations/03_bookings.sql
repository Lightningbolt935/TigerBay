-- ============================================================
-- 03_bookings.sql  –  reservations, Stripe deposits, refunds
-- ============================================================

create table if not exists public.bookings (
  id                       uuid primary key default gen_random_uuid(),
  user_id                  uuid not null references public.profiles(id) on delete cascade,
  branch_id                uuid not null,
  branch_name              text not null,
  venue_name               text not null,
  booking_date             date not null,
  time_slot                text not null,
  party_size               integer not null check (party_size between 1 and 20),
  status                   text not null default 'pending'
                             check (status in ('pending','upcoming','past','cancelled')),
  deposit_amount           numeric(10,2) not null default 20.00,
  stripe_payment_intent_id text,
  stripe_charge_id         text,
  deposit_refunded         boolean not null default false,
  special_requests         text,
  confirmation_email_sent  boolean not null default false,
  calendar_invite_sent     boolean not null default false,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now()
);

create index idx_bookings_user_id
  on public.bookings(user_id, booking_date desc);

create index idx_bookings_branch_date
  on public.bookings(branch_id, booking_date, time_slot);

create trigger bookings_updated_at
  before update on public.bookings
  for each row execute procedure public.set_updated_at();

-- Get available time slots for a branch on a date
-- (excludes slots that already have bookings at max capacity)
create or replace function public.get_available_slots(
  p_branch_id uuid,
  p_date      date
) returns table(slot text) language plpgsql as $$
declare
  v_all_slots text[] := array[
    '17:00','17:30','18:00','18:30','19:00','19:30',
    '20:00','20:30','21:00','21:30','22:00','22:30'
  ];
  v_max_per_slot integer := 10; -- configurable per branch
begin
  return query
  select unnest(v_all_slots) as slot
  except
  select time_slot
  from public.bookings
  where branch_id = p_branch_id
    and booking_date = p_date
    and status not in ('cancelled')
  group by time_slot
  having count(*) >= v_max_per_slot;
end;
$$;

-- Auto-move past bookings to 'past' status
create or replace function public.update_booking_statuses()
returns void language plpgsql security definer as $$
begin
  update public.bookings
  set status = 'past'
  where status = 'upcoming'
    and (booking_date::timestamptz + time_slot::interval) < now();
end;
$$;

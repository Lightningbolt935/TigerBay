-- ============================================================
-- 08_push_notifications.sql  –  FCM push notification pipeline
-- ============================================================

-- ── Device tokens (one customer can have multiple devices) ───────────────────

create table if not exists public.user_push_tokens (
  id           uuid primary key default gen_random_uuid(),
  customer_id  uuid not null references public.profiles(id) on delete cascade,
  device_token text not null,
  platform     text check (platform in ('ios', 'android', 'web')),
  created_at   timestamptz not null default now(),
  unique (customer_id, device_token)
);

create index idx_user_push_tokens_customer
  on public.user_push_tokens(customer_id);

alter table public.user_push_tokens enable row level security;

create policy "Users can view own push tokens"
  on public.user_push_tokens for select
  using (auth.uid() = customer_id);

create policy "Users can insert own push tokens"
  on public.user_push_tokens for insert
  with check (auth.uid() = customer_id);

create policy "Users can delete own push tokens"
  on public.user_push_tokens for delete
  using (auth.uid() = customer_id);

-- Service role (Edge Function) needs unrestricted delete access for
-- self-clearing stale-token hygiene — already covered since the Edge
-- Function client is initialised with the service_role key, which
-- bypasses RLS entirely.

-- ── Outbound notification queue ──────────────────────────────────────────────
-- Any INSERT here triggers the `send-push-notification` Edge Function
-- via a Database Webhook configured in the Supabase Dashboard
-- (Database → Webhooks → Create a new webhook → table: outbound_notifications,
--  event: INSERT, type: HTTP Request → your function URL).

create table if not exists public.outbound_notifications (
  id                uuid primary key default gen_random_uuid(),
  customer_id       uuid not null references public.profiles(id) on delete cascade,
  title             text not null,
  body              text not null,
  data              jsonb,
  notification_type text,
  created_at        timestamptz not null default now()
);

create index idx_outbound_notifications_customer
  on public.outbound_notifications(customer_id, created_at desc);

alter table public.outbound_notifications enable row level security;

create policy "Users can view own notifications"
  on public.outbound_notifications for select
  using (auth.uid() = customer_id);

create policy "Service role can insert notifications"
  on public.outbound_notifications for insert
  with check (auth.role() = 'service_role');

-- ── Example trigger: queue a notification on booking status change ──────────
-- Demonstrates how the existing `bookings` table can populate
-- `outbound_notifications`, which then fires the webhook → Edge Function.

create or replace function public.notify_on_booking_status_change()
returns trigger language plpgsql security definer as $$
declare
  v_title text;
  v_body  text;
begin
  if new.status = old.status then
    return new;
  end if;

  v_title := case new.status
    when 'upcoming'  then 'Booking Confirmed'
    when 'cancelled' then 'Booking Cancelled'
    when 'past'      then 'Thanks for visiting!'
    else 'Booking Update'
  end;

  v_body := case new.status
    when 'upcoming'  then format('Your table at %s is confirmed for %s.', new.venue_name, new.time_slot)
    when 'cancelled' then format('Your booking at %s has been cancelled.', new.venue_name)
    when 'past'      then format('We hope you enjoyed your visit to %s.', new.venue_name)
    else format('Your booking at %s has been updated.', new.venue_name)
  end;

  insert into public.outbound_notifications
    (customer_id, title, body, data, notification_type)
  values
    (
      new.user_id,
      v_title,
      v_body,
      jsonb_build_object(
        'booking_id', new.id,
        'status', new.status
      ),
      'booking_status_change'
    );

  return new;
end;
$$;

drop trigger if exists on_booking_status_change on public.bookings;
create trigger on_booking_status_change
  after update on public.bookings
  for each row execute procedure public.notify_on_booking_status_change();

// supabase/functions/cancel-booking/index.ts
// Cancels a booking and triggers Stripe refund if eligible.

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14?target=deno'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
})

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
)

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    })
  }

  try {
    const { booking_id } = await req.json()

    // 1. Fetch booking
    const { data: booking, error } = await supabase
      .from('bookings')
      .select()
      .eq('id', booking_id)
      .single()

    if (error || !booking) {
      return new Response(
        JSON.stringify({ error: 'Booking not found' }),
        { status: 404, headers: { 'Content-Type': 'application/json' } },
      )
    }

    if (booking.status === 'cancelled') {
      return new Response(
        JSON.stringify({ error: 'Booking already cancelled' }),
        { status: 409, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // 2. Check refund eligibility (>24h before booking)
    const bookingDateTime = new Date(`${booking.booking_date}T${booking.time_slot}`)
    const hoursUntil = (bookingDateTime.getTime() - Date.now()) / (1000 * 60 * 60)
    const isRefundEligible = hoursUntil > 24

    let depositRefunded = false

    // 3. Process Stripe refund if eligible and payment was made
    if (
      isRefundEligible &&
      booking.stripe_payment_intent_id &&
      !booking.deposit_refunded
    ) {
      try {
        await stripe.refunds.create({
          payment_intent: booking.stripe_payment_intent_id,
          reason: 'requested_by_customer',
        })
        depositRefunded = true
      } catch (stripeErr) {
        console.error('Stripe refund failed:', stripeErr)
        // Continue with cancellation even if refund fails — handle manually
      }
    }

    // 4. Update booking status
    await supabase
      .from('bookings')
      .update({
        status: 'cancelled',
        deposit_refunded: depositRefunded,
        updated_at: new Date().toISOString(),
      })
      .eq('id', booking_id)

    return new Response(
      JSON.stringify({
        success: true,
        depositRefunded,
        refundEligible: isRefundEligible,
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      },
    )
  } catch (err) {
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
        },
      },
    )
  }
})

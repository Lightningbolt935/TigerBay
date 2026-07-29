// supabase/functions/create-booking/index.ts
// Atomically creates a booking record + Stripe PaymentIntent for the deposit.
// Called from BookingRepository.createBookingWithDeposit()

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
    const {
      user_id,
      branch_id,
      booking_date,
      time_slot,
      party_size,
      special_requests,
    } = await req.json()

    // 1. Validate the slot is still available
    const { data: existingSlots } = await supabase
      .from('bookings')
      .select('id')
      .eq('branch_id', branch_id)
      .eq('booking_date', booking_date.substring(0, 10))
      .eq('time_slot', time_slot)
      .neq('status', 'cancelled')

    if (existingSlots && existingSlots.length >= 10) {
      return new Response(
        JSON.stringify({ error: 'Slot no longer available' }),
        { status: 409, headers: { 'Content-Type': 'application/json' } },
      )
    }

    // 2. Get branch details for deposit amount + venue name
    const { data: branch } = await supabase
      .from('branches')
      .select('name, city, deposit_amount')
      .eq('id', branch_id)
      .single()

    const depositAmount = branch?.deposit_amount ?? 20.00
    const depositPence  = Math.round(depositAmount * 100)

    // 3. Get or create Stripe customer for this user
    const { data: profile } = await supabase
      .from('profiles')
      .select('email, full_name')
      .eq('id', user_id)
      .single()

    let stripeCustomerId: string | undefined
    const { data: existingCustomer } = await supabase
      .from('stripe_customers')
      .select('stripe_customer_id')
      .eq('user_id', user_id)
      .maybeSingle()

    if (existingCustomer) {
      stripeCustomerId = existingCustomer.stripe_customer_id
    } else {
      const customer = await stripe.customers.create({
        email: profile?.email ?? undefined,
        name:  profile?.full_name ?? undefined,
        metadata: { supabase_user_id: user_id },
      })
      stripeCustomerId = customer.id
      await supabase.from('stripe_customers').insert({
        user_id,
        stripe_customer_id: stripeCustomerId,
      })
    }

    // 4. Create Stripe PaymentIntent
    const paymentIntent = await stripe.paymentIntents.create({
      amount:   depositPence,
      currency: 'gbp',
      customer: stripeCustomerId,
      automatic_payment_methods: { enabled: true },
      metadata: {
        user_id,
        branch_id,
        booking_date,
        time_slot,
        party_size: String(party_size),
      },
    })

    // 5. Create booking record (status=pending until payment confirmed)
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .insert({
        user_id,
        branch_id,
        branch_name: branch?.name ?? '',
        venue_name:  branch?.name ?? '',
        booking_date: booking_date.substring(0, 10),
        time_slot,
        party_size,
        status: 'pending',
        deposit_amount: depositAmount,
        stripe_payment_intent_id: paymentIntent.id,
        special_requests: special_requests ?? null,
      })
      .select()
      .single()

    if (bookingError) throw new Error(bookingError.message)

    return new Response(
      JSON.stringify({
        bookingId:     booking.id,
        clientSecret:  paymentIntent.client_secret,
        depositAmount: depositAmount,
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

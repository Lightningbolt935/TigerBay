// supabase/functions/create-payment-intent/index.ts
//
// TigerBay International — Stripe PaymentIntent Edge Function
// ─────────────────────────────────────────────────────────────
// This function creates a Stripe PaymentIntent for booking deposits.
//
// STATUS: Scaffolded — returns 503 until a real Stripe secret key is configured.
//
// TO ACTIVATE:
//   1. Add your Stripe secret key to Supabase project secrets:
//      supabase secrets set STRIPE_SECRET_KEY=sk_test_...
//   2. Uncomment the Stripe integration block below
//   3. Redeploy: supabase functions deploy create-payment-intent
//
// CURRENT BEHAVIOUR (no Stripe key set):
//   Returns HTTP 503 with { error: "Stripe not configured" }
//   The StripeService.presentPaymentSheet() guard in stripe_service.dart
//   will detect this and return false without crashing the app.

import "@supabase/functions-js/edge-runtime.d.ts";

export default {
  fetch: async (req: Request): Promise<Response> => {
    // ── CORS preflight ─────────────────────────────────────────────────────
    if (req.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey",
        },
      });
    }

    // ── Parse request body ─────────────────────────────────────────────────
    let body: {
      booking_id?: string;
      branch_id?: string;
      amount?: number;
      currency?: string;
      transfer_data_destination?: string;
    };

    try {
      body = await req.json();
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const { booking_id, branch_id, amount, currency = "gbp" } = body;

    if (!booking_id || !amount) {
      return Response.json(
        { error: "Missing required fields: booking_id, amount" },
        { status: 422 }
      );
    }

    // ── Stripe integration ─────────────────────────────────────────────────
    // Uncomment the block below once STRIPE_SECRET_KEY is set in Supabase secrets.
    //
    // const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
    // if (!stripeKey) {
    //   return Response.json({ error: "Stripe not configured" }, { status: 503 });
    // }
    //
    // const stripeBody: Record<string, string> = {
    //   amount: String(amount),
    //   currency,
    //   "metadata[booking_id]": booking_id,
    //   "metadata[branch_id]": branch_id ?? "",
    //   "payment_method_types[]": "card",
    // };
    //
    // if (body.transfer_data_destination) {
    //   stripeBody["transfer_data[destination]"] = body.transfer_data_destination;
    // }
    //
    // const stripeRes = await fetch("https://api.stripe.com/v1/payment_intents", {
    //   method: "POST",
    //   headers: {
    //     Authorization: `Bearer ${stripeKey}`,
    //     "Content-Type": "application/x-www-form-urlencoded",
    //   },
    //   body: new URLSearchParams(stripeBody).toString(),
    // });
    //
    // const intent = await stripeRes.json();
    //
    // if (!stripeRes.ok) {
    //   return Response.json({ error: intent.error?.message ?? "Stripe error" }, { status: 502 });
    // }
    //
    // return Response.json({
    //   client_secret: intent.client_secret,
    //   payment_intent_id: intent.id,
    // });

    // ── Stripe not yet configured — return 503 ─────────────────────────────
    return Response.json(
      {
        error: "Stripe not configured",
        message:
          "Set STRIPE_SECRET_KEY in Supabase project secrets and redeploy this function.",
      },
      { status: 503 }
    );
  },
};

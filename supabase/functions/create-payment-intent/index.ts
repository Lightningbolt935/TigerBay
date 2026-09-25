// supabase/functions/create-payment-intent/index.ts
//
// TigerBay International — Stripe PaymentIntent Edge Function
// ─────────────────────────────────────────────────────────────
// Creates a Stripe PaymentIntent for booking deposits or membership payments.

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
      user_id?: string;
      tier_id?: string;
      tier_name?: string;
      amount?: number;
      currency?: string;
      transfer_data_destination?: string;
    };

    try {
      body = await req.json();
    } catch {
      return Response.json({ error: "Invalid JSON body" }, { status: 400 });
    }

    const {
      booking_id,
      branch_id,
      user_id,
      tier_id,
      tier_name,
      amount,
      currency = "gbp",
    } = body;

    if (!amount) {
      return Response.json(
        { error: "Missing required field: amount" },
        { status: 422 }
      );
    }

    // ── Stripe integration ─────────────────────────────────────────────────
    const stripeKey =
      Deno.env.get("STRIPE_SECRET_KEY") ||
      "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";

    if (!stripeKey) {
      return Response.json({ error: "Stripe not configured" }, { status: 503 });
    }

    const stripeBody: Record<string, string> = {
      amount: String(amount),
      currency: currency.toLowerCase(),
      "payment_method_types[0]": "card",
    };

    if (booking_id) {
      stripeBody["metadata[booking_id]"] = booking_id;
    }
    if (branch_id) {
      stripeBody["metadata[branch_id]"] = branch_id;
    }
    if (user_id) {
      stripeBody["metadata[user_id]"] = user_id;
    }
    if (tier_id) {
      stripeBody["metadata[tier_id]"] = tier_id;
    }
    if (tier_name) {
      stripeBody["metadata[tier_name]"] = tier_name;
    }

    if (body.transfer_data_destination) {
      stripeBody["transfer_data[destination]"] = body.transfer_data_destination;
    }

    try {
      const stripeRes = await fetch("https://api.stripe.com/v1/payment_intents", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeKey}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams(stripeBody).toString(),
      });

      const intent = await stripeRes.json();

      if (!stripeRes.ok) {
        return Response.json(
          { error: intent.error?.message ?? "Stripe error" },
          {
            status: 502,
            headers: { "Access-Control-Allow-Origin": "*" },
          }
        );
      }

      const publishableKey =
        Deno.env.get("STRIPE_PUBLISHABLE_KEY") ||
        (intent.livemode
          ? undefined
          : "pk_test_51UIYHUH4ehSj2yK4wdoP3TcZqezk5JTgebZ5pJnLV20ba0cr7c678OrkzMN6ZmOHxAURhp8jEKVkKheySZitDOoz00Ah20eGjx");

      return Response.json(
        {
          client_secret: intent.client_secret,
          payment_intent_id: intent.id,
          publishable_key: publishableKey,
          livemode: intent.livemode,
        },
        {
          headers: { "Access-Control-Allow-Origin": "*" },
        }
      );
    } catch (err) {
      return Response.json(
        { error: (err as Error).message },
        {
          status: 500,
          headers: { "Access-Control-Allow-Origin": "*" },
        }
      );
    }
  },
};

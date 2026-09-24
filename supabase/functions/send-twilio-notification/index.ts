// supabase/functions/send-twilio-notification/index.ts
//
// Dispatches SMS notifications (booking confirmations, alerts) and handles
// OTP verification via Twilio REST & Verify APIs.
//
// Deploy:
//   supabase functions deploy send-twilio-notification
//
// Required secrets:
//   TWILIO_ACCOUNT_SID=ACfe3d3114b5b5315288f76bd47b0d327f
//   TWILIO_AUTH_TOKEN=3abb0f1815db0aa456c108e1788b0292
//   TWILIO_VERIFY_SERVICE_SID=VA2bbfc2144b4cd94d0c363ce3b4d28247
//   TWILIO_FROM_NUMBER=+... (optional)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_ACCOUNT_SID = "ACfe3d3114b5b5315288f76bd47b0d327f";
const DEFAULT_AUTH_TOKEN = "3abb0f1815db0aa456c108e1788b0292";
const DEFAULT_VERIFY_SID = "VA2bbfc2144b4cd94d0c363ce3b4d28247";

function getTwilioConfig() {
  const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID") || DEFAULT_ACCOUNT_SID;
  const authToken = Deno.env.get("TWILIO_AUTH_TOKEN") || DEFAULT_AUTH_TOKEN;
  const verifySid = Deno.env.get("TWILIO_VERIFY_SERVICE_SID") || DEFAULT_VERIFY_SID;
  const fromNumber = Deno.env.get("TWILIO_FROM_NUMBER") || "";

  const basicAuth = btoa(`${accountSid}:${authToken}`);
  return { accountSid, authToken, verifySid, fromNumber, basicAuth };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const config = getTwilioConfig();
    const payload = await req.json().catch(() => ({}));

    // Support both direct action invocation and database webhook payloads
    const record = payload.record || payload;
    const action = payload.action || record.action || "send_sms";
    const to = payload.to || record.to || record.customer_phone || record.phone;

    if (!to && action !== "ping") {
      return new Response(
        JSON.stringify({ error: "Missing required 'to' phone number in E.164 format (e.g. +44...)" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ────────────────────────────────────────────────────────────────────────
    // Action: ping (test credentials status)
    // ────────────────────────────────────────────────────────────────────────
    if (action === "ping") {
      const accountRes = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${config.accountSid}.json`,
        { headers: { Authorization: `Basic ${config.basicAuth}` } },
      );
      const accData = await accountRes.json();
      return new Response(
        JSON.stringify({
          status: "connected",
          account_status: accData.status,
          type: accData.type,
          friendly_name: accData.friendly_name,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ────────────────────────────────────────────────────────────────────────
    // Action: send_otp (via Twilio Verify API)
    // ────────────────────────────────────────────────────────────────────────
    if (action === "send_otp") {
      const channel = payload.channel || "sms";
      const params = new URLSearchParams();
      params.append("To", to);
      params.append("Channel", channel);

      const verifyRes = await fetch(
        `https://verify.twilio.com/v2/Services/${config.verifySid}/Verifications`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${config.basicAuth}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: params.toString(),
        },
      );

      const verifyData = await verifyRes.json();

      if (!verifyRes.ok) {
        return new Response(
          JSON.stringify({
            error: verifyData.message || "Failed to send OTP",
            code: verifyData.code,
            more_info: verifyData.more_info,
          }),
          { status: verifyRes.status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      return new Response(
        JSON.stringify({
          status: "pending",
          to: verifyData.to,
          channel: verifyData.channel,
          sid: verifyData.sid,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ────────────────────────────────────────────────────────────────────────
    // Action: verify_otp
    // ────────────────────────────────────────────────────────────────────────
    if (action === "verify_otp") {
      const code = payload.code;
      if (!code) {
        return new Response(
          JSON.stringify({ error: "Missing required 'code' parameter" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const params = new URLSearchParams();
      params.append("To", to);
      params.append("Code", code);

      const checkRes = await fetch(
        `https://verify.twilio.com/v2/Services/${config.verifySid}/VerificationCheck`,
        {
          method: "POST",
          headers: {
            Authorization: `Basic ${config.basicAuth}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: params.toString(),
        },
      );

      const checkData = await checkRes.json();

      if (!checkRes.ok) {
        return new Response(
          JSON.stringify({
            error: checkData.message || "OTP check failed",
            code: checkData.code,
          }),
          { status: checkRes.status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      const isApproved = checkData.status === "approved";
      return new Response(
        JSON.stringify({
          approved: isApproved,
          status: checkData.status,
          to: checkData.to,
        }),
        { status: isApproved ? 200 : 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ────────────────────────────────────────────────────────────────────────
    // Action: send_sms / send_booking_notification
    // ────────────────────────────────────────────────────────────────────────
    let messageText = payload.message || payload.body || record.body;

    if (action === "send_booking_notification" || payload.booking_id) {
      const venue = payload.venue_name || record.venue_name || "TigerBay";
      const date = payload.booking_date || record.booking_date || "your reserved date";
      const time = payload.time_slot || record.time_slot || "your time slot";
      messageText = `TigerBay: Your reservation at ${venue} is confirmed for ${date} at ${time}. We look forward to welcoming you!`;
    }

    if (!messageText) {
      messageText = "TigerBay notification: You have an update regarding your TigerBay reservation.";
    }

    const fromSender = payload.from || config.fromNumber;
    const msgParams = new URLSearchParams();
    msgParams.append("To", to);
    msgParams.append("Body", messageText);

    if (fromSender) {
      msgParams.append("From", fromSender);
    }

    const sendRes = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${config.accountSid}/Messages.json`,
      {
        method: "POST",
        headers: {
          Authorization: `Basic ${config.basicAuth}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: msgParams.toString(),
      },
    );

    const sendData = await sendRes.json();

    if (!sendRes.ok) {
      let friendlyError = sendData.message;
      if (sendData.code === 21608) {
        friendlyError = `Twilio trial account: Recipient number ${to} must be added to Verified Caller IDs in your Twilio Console first.`;
      } else if (sendData.code === 21606 || sendData.code === 21212) {
        friendlyError = "Twilio sender phone number is not yet assigned. Please claim your free phone number in the Twilio Console.";
      }

      return new Response(
        JSON.stringify({
          error: friendlyError,
          raw_message: sendData.message,
          code: sendData.code,
          status: sendData.status,
          more_info: sendData.more_info,
        }),
        { status: sendRes.status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({
        status: "success",
        sid: sendData.sid,
        to: sendData.to,
        from: sendData.from,
        date_created: sendData.date_created,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err instanceof Error ? err.message : String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});

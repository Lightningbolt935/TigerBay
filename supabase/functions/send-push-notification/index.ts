// supabase/functions/send-push-notification/index.ts
//
// Triggered by a Supabase Database Webhook whenever a new row is inserted
// into `outbound_notifications` (e.g. a reservation status change).
//
// Responsibilities:
//   1. Read the inserted row from the webhook payload.
//   2. Look up every device token belonging to that customer.
//   3. Exchange the Firebase service account credentials for a short-lived
//      OAuth2 access token (Google JWT auth flow).
//   4. Send one FCM v1 message per device token.
//   5. If FCM reports the token as gone (404 / 410), delete it from
//      `user_push_tokens` so we never retry a dead token again.
//
// Deploy:
//   supabase functions deploy send-push-notification
//
// Required secrets (set via `supabase secrets set KEY=value`):
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY
//   FIREBASE_SERVICE_ACCOUNT_KEY   (single-line JSON string)

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { GoogleAuth } from 'https://esm.sh/google-auth-library@9'

// ──────────────────────────────────────────────────────────────────────────
// Types
// ──────────────────────────────────────────────────────────────────────────

interface OutboundNotificationRow {
  id: string
  customer_id: string
  title: string
  body: string
  data: Record<string, string> | null
  notification_type: string | null
  created_at: string
}

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  schema: string
  record: OutboundNotificationRow
  old_record: OutboundNotificationRow | null
}

interface PushTokenRow {
  id: string
  customer_id: string
  device_token: string
  platform: string | null
}

interface FirebaseServiceAccount {
  project_id: string
  client_email: string
  private_key: string
  [key: string]: unknown
}

interface FcmSendResult {
  tokenId: string
  deviceToken: string
  success: boolean
  shouldDelete: boolean
  httpStatus: number | null
  errorMessage: string | null
}

// ──────────────────────────────────────────────────────────────────────────
// Environment / constant configuration
// ──────────────────────────────────────────────────────────────────────────

const CORS_HEADERS: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'

// ──────────────────────────────────────────────────────────────────────────
// Helper: JSON response builder (keeps CORS headers consistent everywhere)
// ──────────────────────────────────────────────────────────────────────────

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json',
    },
  })
}

// ──────────────────────────────────────────────────────────────────────────
// Helper: Load and parse the Firebase service account from env
// ──────────────────────────────────────────────────────────────────────────

function loadFirebaseServiceAccount(): FirebaseServiceAccount {
  const raw = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY')

  if (!raw) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT_KEY is not set in the function environment.',
    )
  }

  let parsed: FirebaseServiceAccount

  try {
    parsed = JSON.parse(raw) as FirebaseServiceAccount
  } catch (parseError) {
    throw new Error(
      `FIREBASE_SERVICE_ACCOUNT_KEY is not valid JSON: ${
        (parseError as Error).message
      }`,
    )
  }

  if (!parsed.project_id || !parsed.client_email || !parsed.private_key) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT_KEY is missing project_id, client_email, or private_key.',
    )
  }

  return parsed
}

// ──────────────────────────────────────────────────────────────────────────
// Helper: Exchange the service account for a short-lived FCM access token
// ──────────────────────────────────────────────────────────────────────────

async function getFcmAccessToken(
  serviceAccount: FirebaseServiceAccount,
): Promise<string> {
  const auth = new GoogleAuth({
    credentials: {
      client_email: serviceAccount.client_email,
      private_key: serviceAccount.private_key,
    },
    scopes: [FCM_SCOPE],
  })

  const client = await auth.getClient()
  const accessTokenResponse = await client.getAccessToken()

  const token =
    typeof accessTokenResponse === 'string'
      ? accessTokenResponse
      : accessTokenResponse?.token

  if (!token) {
    throw new Error(
      'Google auth client returned an empty access token for FCM.',
    )
  }

  return token
}

// ──────────────────────────────────────────────────────────────────────────
// Helper: Fetch every device token registered for a given customer
// ──────────────────────────────────────────────────────────────────────────

async function fetchPushTokensForCustomer(
  supabase: SupabaseClient,
  customerId: string,
): Promise<PushTokenRow[]> {
  const { data, error } = await supabase
    .from('user_push_tokens')
    .select('id, customer_id, device_token, platform')
    .eq('customer_id', customerId)

  if (error) {
    throw new Error(
      `Failed to fetch push tokens for customer ${customerId}: ${error.message}`,
    )
  }

  return (data ?? []) as PushTokenRow[]
}

// ──────────────────────────────────────────────────────────────────────────
// Helper: Send a single FCM v1 message to a single device token
// ──────────────────────────────────────────────────────────────────────────

async function sendFcmMessageToToken(params: {
  projectId: string
  accessToken: string
  tokenRow: PushTokenRow
  title: string
  body: string
  data: Record<string, string> | null
  notificationType: string | null
}): Promise<FcmSendResult> {
  const { projectId, accessToken, tokenRow, title, body, data, notificationType } =
    params

  const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`

  // FCM v1 requires all "data" payload values to be strings.
  const dataPayload: Record<string, string> = {}
  if (data) {
    for (const [key, value] of Object.entries(data)) {
      dataPayload[key] = typeof value === 'string' ? value : JSON.stringify(value)
    }
  }
  if (notificationType) {
    dataPayload['notification_type'] = notificationType
  }

  const messageBody = {
    message: {
      token: tokenRow.device_token,
      notification: {
        title,
        body,
      },
      data: dataPayload,
      android: {
        priority: 'HIGH',
        notification: {
          sound: 'default',
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            'content-available': 1,
          },
        },
      },
    },
  }

  try {
    const fcmResponse = await fetch(fcmEndpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json; UTF-8',
      },
      body: JSON.stringify(messageBody),
    })

    if (fcmResponse.ok) {
      return {
        tokenId: tokenRow.id,
        deviceToken: tokenRow.device_token,
        success: true,
        shouldDelete: false,
        httpStatus: fcmResponse.status,
        errorMessage: null,
      }
    }

    const errorBodyText = await fcmResponse.text()

    // FCM returns 404 (NOT_FOUND) or 410 (Gone-style via UNREGISTERED error
    // code embedded in the JSON body) when the token is no longer valid.
    let isUnregistered = fcmResponse.status === 404 || fcmResponse.status === 410

    if (!isUnregistered) {
      try {
        const parsedError = JSON.parse(errorBodyText)
        const fcmErrorCode: string | undefined =
          parsedError?.error?.details?.find(
            (detail: { errorCode?: string }) => detail?.errorCode,
          )?.errorCode
        if (fcmErrorCode === 'UNREGISTERED' || fcmErrorCode === 'NOT_FOUND') {
          isUnregistered = true
        }
      } catch {
        // Error body wasn't JSON — fall through, isUnregistered stays as-is.
      }
    }

    return {
      tokenId: tokenRow.id,
      deviceToken: tokenRow.device_token,
      success: false,
      shouldDelete: isUnregistered,
      httpStatus: fcmResponse.status,
      errorMessage: errorBodyText,
    }
  } catch (networkError) {
    return {
      tokenId: tokenRow.id,
      deviceToken: tokenRow.device_token,
      success: false,
      shouldDelete: false,
      httpStatus: null,
      errorMessage: (networkError as Error).message,
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Helper: Delete a single stale token row (self-clearing token hygiene)
// ──────────────────────────────────────────────────────────────────────────

async function deleteStaleToken(
  supabase: SupabaseClient,
  tokenId: string,
): Promise<void> {
  const { error } = await supabase
    .from('user_push_tokens')
    .delete()
    .eq('id', tokenId)

  if (error) {
    console.error(
      `[token-hygiene] Failed to delete stale token row ${tokenId}: ${error.message}`,
    )
    return
  }

  console.log(`[token-hygiene] Deleted stale/unregistered token row ${tokenId}`)
}

// ──────────────────────────────────────────────────────────────────────────
// Main request handler
// ──────────────────────────────────────────────────────────────────────────

Deno.serve(async (req: Request) => {
  // ── CORS preflight handshake — must be the very first thing handled ────
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS_HEADERS })
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed. Use POST.' }, 405)
  }

  // ── Parse webhook payload ───────────────────────────────────────────────
  let payload: WebhookPayload

  try {
    payload = (await req.json()) as WebhookPayload
  } catch (parseError) {
    console.error('[request] Failed to parse JSON body:', parseError)
    return jsonResponse(
      { error: 'Request body is not valid JSON.' },
      400,
    )
  }

  const notificationRow = payload?.record

  if (!notificationRow || !notificationRow.customer_id) {
    console.error(
      '[request] Webhook payload missing record.customer_id:',
      JSON.stringify(payload),
    )
    return jsonResponse(
      { error: 'Payload is missing record.customer_id.' },
      400,
    )
  }

  if (!notificationRow.title || !notificationRow.body) {
    console.error(
      '[request] Webhook payload missing title/body:',
      JSON.stringify(payload),
    )
    return jsonResponse(
      { error: 'Payload record is missing a title or body field.' },
      400,
    )
  }

  // ── Read required environment configuration ─────────────────────────────
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseServiceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    console.error(
      '[config] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in function environment.',
    )
    return jsonResponse(
      { error: 'Server is missing Supabase environment configuration.' },
      500,
    )
  }

  let firebaseServiceAccount: FirebaseServiceAccount

  try {
    firebaseServiceAccount = loadFirebaseServiceAccount()
  } catch (configError) {
    console.error('[config] Firebase service account error:', configError)
    return jsonResponse(
      { error: (configError as Error).message },
      500,
    )
  }

  // ── Build the service-role Supabase client (bypasses RLS) ───────────────
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  })

  // ── Fetch device tokens for this customer ────────────────────────────────
  let pushTokens: PushTokenRow[]

  try {
    pushTokens = await fetchPushTokensForCustomer(
      supabase,
      notificationRow.customer_id,
    )
  } catch (fetchTokensError) {
    console.error(
      `[db] Error fetching push tokens for customer ${notificationRow.customer_id}:`,
      fetchTokensError,
    )
    return jsonResponse(
      { error: (fetchTokensError as Error).message },
      500,
    )
  }

  if (pushTokens.length === 0) {
    console.log(
      `[push] No registered device tokens for customer ${notificationRow.customer_id}. Nothing to send.`,
    )
    return jsonResponse(
      {
        success: true,
        sent: 0,
        deleted: 0,
        message: 'No device tokens registered for this customer.',
      },
      200,
    )
  }

  // ── Exchange service account credentials for an FCM access token ───────
  let fcmAccessToken: string

  try {
    fcmAccessToken = await getFcmAccessToken(firebaseServiceAccount)
  } catch (authError) {
    console.error(
      '[fcm-auth] Failed to obtain FCM OAuth2 access token:',
      authError,
    )
    return jsonResponse(
      { error: `FCM authentication failed: ${(authError as Error).message}` },
      500,
    )
  }

  // ── Send to every device token in parallel ───────────────────────────────
  const sendResults = await Promise.all(
    pushTokens.map((tokenRow) =>
      sendFcmMessageToToken({
        projectId: firebaseServiceAccount.project_id,
        accessToken: fcmAccessToken,
        tokenRow,
        title: notificationRow.title,
        body: notificationRow.body,
        data: notificationRow.data,
        notificationType: notificationRow.notification_type,
      }),
    ),
  )

  // ── Self-clearing token hygiene: delete every stale/unregistered token ──
  const staleResults = sendResults.filter((result) => result.shouldDelete)

  await Promise.all(
    staleResults.map((staleResult) =>
      deleteStaleToken(supabase, staleResult.tokenId),
    ),
  )

  // ── Log every failure that was NOT a stale-token cleanup, for visibility ─
  const unexpectedFailures = sendResults.filter(
    (result) => !result.success && !result.shouldDelete,
  )

  for (const failure of unexpectedFailures) {
    console.error(
      `[fcm-send] Failed to deliver to token ${failure.deviceToken} ` +
        `(status: ${failure.httpStatus ?? 'network-error'}): ${failure.errorMessage}`,
    )
  }

  const successCount = sendResults.filter((result) => result.success).length

  console.log(
    `[push] Notification ${notificationRow.id} → customer ${notificationRow.customer_id}: ` +
      `${successCount}/${sendResults.length} delivered, ${staleResults.length} stale tokens cleared.`,
  )

  return jsonResponse(
    {
      success: true,
      notificationId: notificationRow.id,
      customerId: notificationRow.customer_id,
      totalTokens: sendResults.length,
      sent: successCount,
      failed: unexpectedFailures.length,
      deleted: staleResults.length,
      details: sendResults.map((result) => ({
        deviceToken: result.deviceToken,
        success: result.success,
        httpStatus: result.httpStatus,
        deleted: result.shouldDelete,
      })),
    },
    200,
  )
})

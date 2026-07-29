# send-push-notification — Deployment Guide

Sends FCM v1 push notifications whenever a row is inserted into
`outbound_notifications`. Includes automatic stale-token cleanup.

---

## 1. Prerequisite SQL

Run **before** deploying the function:

```
migrations/08_push_notifications.sql
```

This creates `user_push_tokens`, `outbound_notifications`, and a sample
trigger that queues a notification whenever a booking's `status` changes.

---

## 2. Get your Firebase service account JSON

1. Firebase Console → Project Settings → Service Accounts
2. Click **Generate new private key** → downloads a `.json` file
3. Minify it to a single line (no actual newlines inside `private_key` —
   keep the `\n` escape sequences as literal two-character strings):

```bash
cat your-service-account.json | jq -c . 
```

---

## 3. Set the Edge Function secrets

```bash
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='<paste-minified-json-here>'
```

> ⚠️ Use single quotes around the JSON value so your shell doesn't try to
> interpret the `{`, `"`, or `\n` characters.

---

## 4. Deploy

```bash
supabase functions deploy send-push-notification
```

---

## 5. Wire up the Database Webhook

Supabase Dashboard → **Database → Webhooks → Create a new webhook**

| Field | Value |
|---|---|
| Name | `notify-on-outbound-notification` |
| Table | `outbound_notifications` |
| Events | `INSERT` |
| Type | HTTP Request |
| Method | `POST` |
| URL | `https://YOUR_PROJECT_REF.functions.supabase.co/send-push-notification` |
| Headers | `Authorization: Bearer YOUR_SERVICE_ROLE_KEY` |

---

## 6. Flutter side — register device tokens

In your app (e.g. on login success), save the FCM device token:

```dart
final fcmToken = await FirebaseMessaging.instance.getToken();
if (fcmToken != null) {
  await Supabase.instance.client.from('user_push_tokens').upsert({
    'customer_id': Supabase.instance.client.auth.currentUser!.id,
    'device_token': fcmToken,
    'platform': Platform.isIOS ? 'ios' : 'android',
  });
}
```

You'll need to add `firebase_messaging` and `firebase_core` to
`pubspec.yaml` and run `flutterfire configure` to generate
`firebase_options.dart` — this is a separate setup step not covered by
this backend function.

---

## 7. Test it manually

```bash
curl -X POST \
  https://YOUR_PROJECT_REF.functions.supabase.co/send-push-notification \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "INSERT",
    "table": "outbound_notifications",
    "schema": "public",
    "record": {
      "id": "00000000-0000-0000-0000-000000000000",
      "customer_id": "REPLACE_WITH_REAL_USER_ID",
      "title": "Test Notification",
      "body": "This is a test push from TigerBay International.",
      "data": { "screen": "home" },
      "notification_type": "test",
      "created_at": "2026-01-01T00:00:00Z"
    },
    "old_record": null
  }'
```

Expected response:

```json
{
  "success": true,
  "notificationId": "00000000-0000-0000-0000-000000000000",
  "customerId": "...",
  "totalTokens": 1,
  "sent": 1,
  "failed": 0,
  "deleted": 0,
  "details": [ ... ]
}
```

---

## How token hygiene works

If FCM responds `404` or `410` for a token — or returns an `UNREGISTERED`/
`NOT_FOUND` error code in its JSON body — the function immediately deletes
that row from `user_push_tokens`. This means uninstalled apps and expired
tokens self-clear without any manual cleanup job.

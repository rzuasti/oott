# OOTT Push Relay

A small, **stateless** relay that forwards OOTT push notifications to the OS push
gateways (FCM for Android, APNs for iOS via Firebase). It is deployed as a
**Firebase Cloud Function** (2nd gen), so it scales to zero — no idle cost and no
server/OS to patch — and the platform provides TLS and a stable HTTPS URL.

It is part of the push-notification feature described in
[`../push_notifications.md`](../push_notifications.md). See that document for the
full design and rationale.

## What it does (and does not do)

- **Forwards only.** It receives `{ tokens, notification: { title, body } }` from
  a self-hosted OOTT backend and fans the message out to FCM via the
  `firebase-admin` `sendEach` API. It returns a per-token result so the backend
  can prune dead tokens.
- **Keeps no state and no PII.** There is no database of users or tokens here; the
  self-hosted backend owns the tokens. The only thing the relay stores is a
  per-IP rate-limit counter in Firestore.
- **Never sees private data.** The payload carries only an already-sanitized
  title/body — no `data` payload, no MAC, no IP, no device identifiers.
- **Credentials never leave Google.** The function authenticates to FCM via its
  runtime service account; there is no service-account JSON to hold or rotate.

## Routes

- `POST /v1/push` — body `{ "tokens": ["..."], "notification": { "title": "...",
  "body": "..." } }`. Returns `{ "results": [{ "token": "...", "status":
  "ok" | "unregistered" | "invalid" | "error" }] }`. The backend prunes tokens
  reported `unregistered` or `invalid`.
- `GET /healthz` — liveness, returns `200 ok`.

Protection (Phase 1, no shared secret): FCM project scoping (the relay can only
reach OOTT app installs), per-source-IP rate limiting, and a billing cap.

## Develop

Requires Node 22.

```sh
npm install
npm test          # unit tests (validation, FCM-response mapping, rate limiting)
npm run build     # type-check + emit to lib/
npm run serve     # run locally in the Firebase emulator
```

## One-time project-owned setup (manual — no secrets committed)

These steps are performed once by the project owner. **Do not commit any secrets,
service-account keys, or `google-services.json` / `GoogleService-Info.plist`**
(project rule).

1. **Create a Firebase project** and upgrade it to the **Blaze** plan (Cloud
   Functions require it). Set a **budget + billing cap** as the hard ceiling
   against cost runaway.
2. **Register the apps**: add the Android app and the iOS app to the Firebase
   project (their bundle/package ids must match the shipped OOTT app).
3. **APNs key**: in the Apple Developer portal create an APNs Auth Key (`.p8`)
   and upload it under *Project settings → Cloud Messaging → Apple app
   configuration*. This is what lets Firebase bridge to APNs for iOS.
4. **Enable Firestore** (Native mode) — used only for the rate-limit counter.
5. **Install the Firebase CLI** (`npm i -g firebase-tools`) and `firebase login`.
6. Select the project: `firebase use --add` (creates `.firebaserc`, which holds
   only the project id and is safe to commit, or keep local).

## Deploy

```sh
npm run deploy    # builds, then `firebase deploy --only functions`
```

After the first deploy, note the function's HTTPS URL (shown in the CLI output,
e.g. `https://us-central1-<project>.cloudfunctions.net/relay`). The backend's
push send endpoint is that URL plus `/v1/push`. Set this as the default
`relay_url` in the backend (`backend/src/settings.rs`, `default_relay_url`); a
self-hoster can always override it via `[notifications.push] relay_url`.

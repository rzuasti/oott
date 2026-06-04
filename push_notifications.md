# Push notifications via FCM + project-operated relay

Implementation plan for delivering push notifications to OOTT's own iOS and
Android apps, triggered from the backend, as an alternative to Pushover.

Status: **planned, not started.** Development begins after this document is
agreed. No code has been written yet.

## Goal

Deliver notifications (new device, device back online, device changed) to a
user's phone running the OOTT mobile app, even when the app is backgrounded or
closed, on both iOS and Android. This is a new `notifications.method` alongside
the existing `pushover` method — it does not replace Pushover, it sits next to
it.

## Background constraint

To reach a backgrounded/closed app you must go through the OS push gateways:
APNs (iOS) and FCM (Android). There is no way around them. We use **Firebase
Cloud Messaging (FCM HTTP v1)** as a single integration: it delivers to Android
natively and bridges to APNs for iOS (our APNs key is uploaded into Firebase).

Because OOTT ships a single store-distributed app, the Firebase project and APNs
key are **project-owned**, not per-self-hoster. We therefore route sends through
a small **project-operated relay** so we never distribute project secrets to
self-hosters and so self-hosters need zero push credentials of their own.

## Locked decisions

1. **Relay lives in this monorepo**, under a new top-level `relay/` directory.
   It is implemented in **TypeScript** and deployed as a **Firebase Cloud
   Function** (scale-to-zero). The `relay/` dir holds the source; only the
   deploy target differs from an always-on server.
2. **Phase 1 is the shipped feature.** It needs no shared secret: protection
   rests on FCM project scoping + per-IP rate limiting + a billing cap.
   Attestation hardening (Play Integrity / App Attest) is **deferred, optional
   future work** — built only if abuse signals appear (see "Optional future
   hardening"). The architecture leaves room to layer it on without reworking
   Phase 1.
3. **Push is opt-in per device** via a toggle in the app's settings (not
   auto-enabled on permission grant).

## Architecture

```
Flutter app ──register FCM token──► OOTT backend (self-hosted, LAN)
                                         │ stores tokens in its SQLite DB
                                         │
   new-device event ─────────────────────┤
                                         ▼
                              POST /v1/push {[tokens], payload}
                                         ▼
                          OOTT Push Relay (Firebase Cloud Function, stateless)
                            FCM creds never leave Google (runtime SA)
                                         ▼
                                   FCM HTTP v1 (Google)
                                    ├──────────► Android devices
                                    └──► APNs ──► iOS devices
```

Key properties:

- **The relay is stateless** — no database, no accounts, no PII at rest. The
  self-hosted backend already owns SQLite, an API, and a LAN channel to the app,
  so it stores the device tokens. The relay only forwards.
- **FCM credentials never leave Google.** As a Cloud Function, the relay
  authenticates to FCM via its runtime service account through the
  `firebase-admin` SDK — there is no service-account JSON for us to hold, store,
  or rotate. The "keep project secrets off self-hosters" goal becomes "Google
  keeps the secret."
- **"Only our app" is guaranteed by FCM project scoping**: the relay sends
  through our single Firebase project, so tokens belonging to any other app are
  rejected by FCM. No caller can make the relay push to a different app.
- **Minimal payloads**: the relay only ever sees a short title/body plus
  `data: {notification_id, mac}`. Full device detail (MAC/IP/vendor) is fetched
  from the **local** backend when the user taps the notification. This keeps
  network metadata off project servers — privacy and reduced liability. Because
  that tap-through fetch only works when the phone can reach the local backend
  (on-LAN or via the user's own remote access), the title/body must stay
  self-sufficient — the existing event copy already summarizes the event.

## Phase 1 — working end-to-end push

### Component 1: relay service (`relay/`, new)

- **TypeScript Firebase Cloud Function**, stateless. Scales to zero — no idle
  cost, no server/OS to patch, TLS and a stable HTTPS URL provided by the
  platform.
- Endpoints (HTTP function routes):
  - `POST /v1/push` — `{ tokens: [...], notification: {title,
    body}, data: {...} }` → send via the `firebase-admin` SDK
    (`messaging().sendEach(...)`, batched multicast) → return per-token results
    (`ok` / `unregistered` / `invalid`) so the caller can prune dead tokens.
  - `GET /healthz` — liveness.
- FCM client: the `firebase-admin` SDK authenticates via the function's runtime
  service account — **no service-account JSON to manage, no OAuth-token minting
  or caching code**. `sendEach` returns per-token success/error, giving us
  pruning for free.
- **No auth secret in Phase 1.** Protection rests on three layers that depend
  on no shared secret: FCM project scoping (can only reach OOTT installs),
  per-source-IP rate limiting, and the billing cap below. This keeps
  self-hosters at zero configuration and avoids committing a secret to the
  open-source repo. (If drive-by invocation noise ever becomes an issue, a
  non-secret client key can be added later without design changes.)
- **Rate limiting per source IP** (one home/deployment ≈ one public IP) via a
  lightweight Firestore counter, so one abuser cannot starve other users. Use
  generous limits to tolerate the occasional CGNAT-shared IP.
- **Billing cap + budget alert** on the project — the hard ceiling against cost
  runaway, the one risk the per-invocation model adds. Together with rate
  limiting and FCM project scoping, this removes cost as a reason to need
  attestation.
- Config via Cloud Function env: rate-limit params, log level. No secrets
  required in Phase 1.
- Tests: rate limiting, payload validation (reject malformed/oversized
  requests), FCM-response → result mapping (mock the `firebase-admin` messaging
  call).
- Deployment: `firebase deploy` of the function. Cost ~$0 within the free tier
  (see Cost summary).

### Component 2: backend changes (existing Rust service)

- **Migration** `database_migrations/10-add_push_tokens/up.sql`: `push_tokens`
  table — `id`, `token` (unique), `platform` (`android`/`ios`), `created_on`,
  `last_seen` (RFC3339, matching the existing datetime convention). A `voucher`
  column would be added later only if attestation is built (see "Optional future
  hardening").
- `src/db/push_tokens.rs` — `upsert`, `list`, `delete`, `delete_many` (prune
  dead tokens). Unit tests mirroring `db/notifications.rs`.
- `src/model/push_tokens.rs` — `PushToken` + payload structs, deriving
  `ToSchema`.
- `src/web_server/push_tokens.rs` — handlers behind the existing bearer `auth`
  middleware:
  - `PUT /api/push_tokens` — register/refresh `{token, platform}`.
  - `DELETE /api/push_tokens/{token}` — unregister.
  Wired into the router and into `ApiDoc` `paths(...)` + `components(schemas())`
  in `web_server.rs`, plus a new `push_tokens` OpenAPI tag.
- `settings.rs` — support `method = "fcm_relay"` and a `[notifications.fcm_relay]`
  section with a single `relay_url` that **defaults to the project's deployed
  relay**, so enabling push needs only `method = "fcm_relay"` and nothing to
  paste — consistent with "zero push credentials for self-hosters". Add parse
  tests.
- `src/events/fcm_relay.rs` — sender mirroring `pushover.rs`: load tokens from
  DB, POST to relay, prune `unregistered`/`invalid` tokens from the response.
- `src/events.rs` — add an `"fcm_relay"` arm in `send_notification` using the
  minimal-payload design above.
- Tests: sender against a mocked relay endpoint, DB CRUD/prune, settings
  parsing, endpoint API tests. Run `./run_tests.sh` and `./lint.sh`.

### Component 3: Flutter app changes

- Deps: `firebase_core`, `firebase_messaging`, `flutter_local_notifications`.
- Platform config: `google-services.json` (Android), `GoogleService-Info.plist`
  (iOS); iOS Push Notifications + Background Modes capabilities. APNs key lives
  only in the Firebase console.
- `lib/utils/push_service.dart` — init Firebase, request permission, get token,
  register via API, handle token refresh, and handle taps → deep-link to the
  device/notification via `go_router`. The `notification` payload is shown by the
  OS directly when the app is backgrounded/terminated; `flutter_local_notifications`
  is used to display alerts while the app is in the **foreground** (and for
  Android channel configuration).
- `lib/utils/api/oott_api_push.dart` — `registerPushToken` /
  `unregisterPushToken`, following the existing `oott_api` split.
- Settings UI: per-device "Enable push on this device" toggle (calls
  register/unregister, shows permission state). Uses theme colors and
  `UISnackbars` per project rules.
- Tests: push_service logic (mocked messaging), API tests via the Dio-adapter
  mock seam, widget test for the toggle. Run `./run_tests.sh` and
  `dart analyze`.

### One-time project-owned setup (manual, documented, no secrets committed)

- Firebase project + Android/iOS apps registered.
- Apple Developer APNs `.p8` key uploaded into Firebase.
- Cloud Function deployed; its runtime service account grants FCM access (no
  service-account JSON to generate or store).
- Steps captured in `relay/README.md`. Secrets never committed (project rule).

## Optional future hardening (deferred) — attestation

**Not part of the shipped feature.** In the Cloud Function context, Phase 1's
rate limiting + billing cap already cover cost-runaway, and FCM project scoping
already prevents wrong-app targeting. The *only* residual threat attestation
addresses is **spam to harvested genuine OOTT tokens** (an attacker who has
collected real tokens from their own installs or by breaching self-hosted
backend DBs pushing to those specific users). For OOTT's threat profile — a
niche, self-hosted, low-value target with bounded blast radius — that is a
low-probability, low-impact risk, and attestation carries real cost (uneven
Flutter coverage, server-side Play Integrity + App Attest verification, voucher
issuance/refresh/storage, added complexity to an otherwise trivial stateless
function).

**Build this only if a trigger appears:**
- Evidence of token harvesting or relay abuse.
- An actual spam incident through the relay.
- Significant user growth that raises the target's value.

If built, it proves each token came from a genuine instance of our shipped app:

- **Android → Play Integrity API**, **iOS → App Attest (DCAppAttest)**.
- Relay gains `POST /v1/attest`: verify the platform proof + FCM token → return
  a **signed voucher** for that token. Vouchers are **HMAC-signed JWTs** (relay
  both issues and verifies them, so symmetric signing is sufficient — no keypair
  distribution). Voucher carries `{fcm_token_hash, platform, exp}`, short TTL,
  refreshed on token refresh. Relay stays stateless: it just verifies its own
  signature.
- `/v1/push` additionally requires a valid voucher per token.
- Backend: add `voucher` column to `push_tokens`; store and forward it.
- App: obtain attestation, exchange for voucher at registration, send voucher to
  backend.
- New Cloud Function secret: HMAC signing secret.
- Flutter attestation coverage is uneven; evaluate platform-channel vs. a
  maintained package during this phase.

## Cost summary

- FCM messages and APNs: **$0**.
- Apple Developer ($99/yr) and Google Play ($25 one-time): already required for
  the app, not incremental to push.
- **Relay (Cloud Function): ~$0.** Scales to zero, and the free tier (~2M
  invocations/mo) comfortably covers OOTT at realistic scale; only pennies if it
  is ever exceeded. No idle cost, no host, no domain/TLS to buy. A small
  Firestore counter for rate limiting also stays within free tier at this
  volume.
- Real cost is operational: the relay is still a shared dependency and a single
  point of failure for everyone's notifications; budget for monitoring and
  backward-compatible relay API versioning across many deployed backend
  versions. (Cloud Functions removes the OS-patching burden of a VPS.)

## Security / abuse notes

- FCM project scoping bounds the blast radius to OOTT app installs only — no
  caller can target arbitrary people or other apps.
- Phase 1 has no shared secret to leak: defense is FCM project scoping + per-IP
  rate limiting + billing cap. Deferred attestation would add the strong
  "genuine app instance" guarantee if ever needed.
- Token pruning loop (relay reports dead tokens → backend deletes) must be
  implemented end-to-end or tokens accumulate.
- **Push is best-effort.** `send_notification` records the notification in the
  backend DB *before* contacting the relay (as it already does for Pushover), so
  a relay or network failure never loses the event — only that one push. The
  in-app notification list is the durable record; there is deliberately no push
  retry queue in v1.

## Build & verification order

1. Migration + DB layer + model (tests).
2. Backend endpoints + OpenAPI wiring (API tests).
3. Relay Cloud Function Phase 1 (tests) + `firebase deploy`.
4. Backend `fcm_relay` sender + settings (tests against mock relay).
5. Flutter integration + settings toggle (tests).
6. Manual end-to-end on real Android + iOS devices.
7. (Deferred, only if triggered) attestation + vouchers across relay, backend,
   and app.

Each step ends with the relevant `run_tests.sh` / `lint.sh` / `dart analyze`
green before moving to the next, per project rules.

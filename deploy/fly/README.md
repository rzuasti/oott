# Deploying the OOTT test server to Fly.io

A throwaway, pay-as-you-go backend (REST API + bundled web UI) on
[Fly.io](https://fly.io), for Apple to exercise the iOS app during App Store
review. Tear it down when review is done so you stop paying.

The image is the reproducible Nix build (same backend + bundled Flutter web as
the production image). Config is rendered at startup from the environment, so:

- the **API key** comes from a Fly **secret** (never baked into the image or git),
- the **SQLite database** lives on a Fly **volume** (survives restarts/redeploys),
- the **network scanners are disabled** — a cloud host has no LAN to scan; this
  is purely an API/UI server for the reviewer.

Everything below runs inside the Nix dev shell, which now ships `flyctl` and
`skopeo` (no Docker daemon required):

```sh
nix develop   # or: direnv / your usual dev shell entry
```

## 1. One-time setup

```sh
# Log in (opens a browser).
fly auth login

# Create the app. Use this name everywhere below (and in fly.toml's `app`).
fly apps create oott-test

# Persistent storage for the SQLite DB. Match the region in fly.toml.
fly volumes create oott_data --region ams --size 1 --app oott-test

# The API key the iOS app will authenticate with (keep it; you'll hand the same
# value to the reviewer / configure it in the build under test).
fly secrets set OOTT_API_KEY="<pick-a-strong-key>" --app oott-test
```

## 2. Build the image and push it to the Fly registry

```sh
# Build the Fly image (backend + bundled web UI + startup config wrapper).
nix build .#flyImage -o result-fly

# Push the image straight from the Nix store archive to Fly's registry.
# No Docker daemon involved; skopeo authenticates with a short-lived Fly token.
skopeo copy --dest-creds "x:$(fly auth token)" \
  docker-archive:result-fly \
  docker://registry.fly.io/oott-test:latest
```

## 3. Deploy

```sh
fly deploy --app oott-test \
  --config deploy/fly/fly.toml \
  --image registry.fly.io/oott-test:latest
```

Your server is now at `https://oott-test.fly.dev`. Quick check:

```sh
curl -H "Authorization: Bearer <your-OOTT_API_KEY>" \
  https://oott-test.fly.dev/api/test
# -> "OOTT_API_OK"
```

Open `https://oott-test.fly.dev/web` for the UI, `https://oott-test.fly.dev/api/docs`
for the API explorer.

## 4. Tear down (stop paying)

```sh
fly apps destroy oott-test          # removes the app, machine, and volume
```

## Notes

- **Redeploying after a change:** repeat steps 2 and 3.
- **Cost:** one `shared-cpu-1x`/512MB machine + a 1GB volume is on the order of a
  few US dollars a month, billed by usage — well under a dollar for a few days.
  To trim it further between reviewer sessions, flip `fly.toml` to scale-to-zero
  (`auto_stop_machines = "stop"`, `min_machines_running = 0`) and redeploy.
- **Demo data:** a cloud host has no LAN to discover, so the server ships with a
  demo dataset (`deploy/fly/seed.sql`) covering registered/unknown devices,
  devices in every "last seen" state, all device-event types and scanner
  sources, and read/unread notifications of each type. It is pruned and reloaded
  on every boot/deploy while `OOTT_SEED = "1"` is set in `fly.toml`; set it to
  `0` (or remove it) to run with a clean database. Note that because it reloads
  on every machine start, a reviewer's own changes are reset if the machine
  restarts — fine for a review server. The `push_tokens` table is never touched,
  so app push registrations survive a reseed.
- **Config knobs** are env vars in `fly.toml` (`OOTT_LOG_LEVEL`,
  `OOTT_NOTIFICATIONS_METHOD`, `OOTT_PORT`, `OOTT_DATA_DIR`); the API key is the
  `OOTT_API_KEY` secret.

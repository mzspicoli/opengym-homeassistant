# Handoff — opengym-ha-app

Last updated: 2026-09-01 (Claude Code, same session that finished the
openGym remote-MCP two-hostname work — see that project's own handoff for
unrelated context).

## Current state

Repo built locally at `~/Documents/Codex/2026-09-01/opengym-ha-app` — **not
yet `git init`'d or pushed anywhere.** That's a deliberate pause point: ask
Matheus before creating/pushing to a public GitHub repo, per the general
"confirm before publishing" rule, not a technical blocker.

All files exist and are internally consistent (see root `README.md` for the
map). Two independent real-Docker builds on the VPS (not just read-through)
confirmed the image builds and the three services (`api`, `web`, `mcp`) come
up correctly under s6-overlay — see "Verified" below.

## Non-negotiable: attribution

Matheus was explicit, more than once, that this must never read like he
wrote openGym himself. The root `README.md` and `opengym/DOCS.md` both open
with a clear "this is a repackaging of Duarte Santos's project" statement.
**Any future edit to either file must preserve that framing near the top,
not bury it.** This is the single most important constraint on this repo,
above any technical concern.

## Verified (real Docker build + run on the VPS, not just review)

1. `docker build` succeeds end to end (amd64, via
   `ghcr.io/home-assistant/amd64-base:latest`).
2. Running the built image (`docker run`, fake `/data/options.json` since
   there's no real Supervisor in this test) shows:
   - All three s6 services start (`s6-rc -a list`: api, mcp, web,
     media-init, plus overlay bookkeeping services).
   - `media-init` downloads the exercise image/gif dataset into `/data/media`
     on first run, symlinks it into nginx's html root, skips re-downloading
     on restart.
   - `web` serves the real openGym SPA (`GET /` → 200, real `index.html`).
   - `api` proxy works (`GET /api/health` via nginx → 200).
   - `mcp` correctly idles (`sleep infinity`, not a crash-loop) when
     `mcp_enabled` is off.
3. **Not verified**: the `bashio::config` option-reading path itself.
   Outside a real Supervisor, `bashio::config` cannot read `/data/options.json`
   directly — it only works via the Supervisor's own API, which doesn't exist
   in a plain `docker run` test. Confirmed this by setting real values in
   `options.json` (a hostname, `mcp_enabled: true`) and observing the
   services still use their internal defaults / stay idle. This is expected
   given the test setup, not a bug found — but it means the option-reading
   code in the three `run` scripts (`opengym/rootfs/etc/s6-overlay/s6-rc.d/*/run`)
   is unverified beyond "matches the idiom used by the real
   `hassio-addons/app-example` and `homeassistant-apps/app-cloudflared` repos
   inspected directly during planning." **A real HAOS instance is the only
   way to close this gap** — see "Next steps."

## Two real bugs found and fixed by that testing (not caught by review alone)

1. **Build failure**: `Dockerfile` unconditionally copied
   `api/state-store.js` and built `mcp/` — files that only exist on the
   openGym fork's `feat/mcp-connections-ui` branch, not on upstream `main`.
   Building against `main` (the original default) failed completely, not
   just for the MCP feature. Fixed by pinning `OPENGYM_REF` to the validated
   commit `ebd49888f53e56806c11e4ce4dae2c0b6aabd619` on
   `gitlab.com/mzspicoli/opengym` (the fork), with a `TEMPORARY` comment at
   the top of `Dockerfile` explaining the switch-back once
   [MR !86](https://gitlab.com/DuarteSantos8/opengym/-/merge_requests/86)
   merges upstream. Also removed a redundant, now-broken explicit
   `state-store.js` COPY line (already covered by the `api/*.js` wildcard).
2. **Runtime crash**: Alpine's `nginx` apk package loads vhost configs from
   `/etc/nginx/http.d/*.conf`, included *inside* `http {}` — not
   `/etc/nginx/conf.d/*.conf` (included at the *root* context), which is
   what the official `nginx:alpine` Docker Hub image does and what
   openGym's own `web/nginx.conf.template` assumes. Writing the rendered
   config to `conf.d` produced `nginx: [emerg] "server" directive is not
   allowed here` on every start. Fixed by rendering to
   `/etc/nginx/http.d/default.conf` instead, and removing the Alpine
   package's own stock `http.d/default.conf` (a welcome-page vhost) at build
   time so it can't shadow/conflict.

## Key decisions (fuller reasoning in `~/.claude/plans/dapper-riding-curry.md`)

- One image, three s6 services, not the original four Docker Compose
  services — HA Apps are single-container.
- Do **not** bundle Cloudflare Tunnel client code. Document composing with
  the separate, official Cloudflared App (`additional_hosts` option) instead
  — confirmed that App's real schema by cloning
  `homeassistant-apps/app-cloudflared` directly, not from memory.
- `ingress: true` for local/guest-mode convenience, but documented plainly
  (in `opengym/DOCS.md`) that it does **not** remove the passkey/HTTPS
  hostname requirement — that's a WebAuthn platform rule, not something this
  packaging can shortcut.
- Options schema (`opengym/config.yaml`) is a direct mapping of openGym's
  existing `.env` contract (`rp_id`, `origin`, `mcp_enabled`, etc.) — no new
  concepts invented.
- CI (`.github/workflows/`) uses the current (2026) official
  `home-assistant/builder` composite actions, copied and adapted from the
  real `home-assistant/apps-example` repo (cloned and read directly, not
  from memory) — the older `build.yaml`-based approach is being phased out
  per HA's own migration blog post.

## Next steps, in order

1. **Real HAOS test** — install this repo on an actual Home Assistant
   Supervisor instance (spare hardware, a VM, or the Supervisor dev
   container) and confirm: the ingress panel loads openGym, the
   Configuration tab's options actually reach the three services (the one
   gap plain `docker run` couldn't close), and `mcp_enabled` genuinely
   starts/stops the `mcp` service.
2. Add `opengym/icon.png` (128×128) and `opengym/logo.png` (250×100) — not
   yet added, Store shows a generic icon without them.
3. Ask Matheus before `git init` + push to
   `github.com/mzspicoli/opengym-homeassistant` (or wherever he wants it) — not
   done automatically.
4. Once [MR !86](https://gitlab.com/DuarteSantos8/opengym/-/merge_requests/86)
   merges upstream: switch `opengym/Dockerfile`'s clone URL back to
   `https://gitlab.com/DuarteSantos8/opengym.git` and `OPENGYM_REF` back to
   `main` (or a release tag). Remove the `TEMPORARY` comments once done.
5. Not before all of the above: consider whether to submit this for listing
   in any curated Home Assistant add-on index. Ship as an unlisted personal
   repo first — this was an explicit "not doing yet" in the original plan.

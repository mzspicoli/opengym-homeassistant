# Handoff — opengym-ha-app

Last updated: 2026-09-01 (Claude Code, same session that finished the
openGym remote-MCP two-hostname work — see that project's own handoff for
unrelated context).

## Current state

Local repo at `~/Documents/Codex/2026-09-01/opengym-ha-app`, pushed (with
Matheus's explicit go-ahead) to **https://github.com/mzspicoli/opengym-homeassistant**
(public), branch `main`. **Installed and running on Matheus's real Home
Assistant** (`home.picoli.eu`) as of this session — see "2026-09-01: real
Supervisor test" below for the three real bugs that surfaced and were fixed
against the actual Supervisor (none of them reproduced in Docker-only
testing). One piece is still unconfirmed: the Ingress web UI in an actual
browser — see that same section for what to check next.

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

## 2026-09-01: real Supervisor test — three real bugs found and fixed

Added the repo to Matheus's real Home Assistant (`home.picoli.eu`), installed
openGym from the Store, and drove the whole thing to a running container.
This is the test a plain `docker run` on a VPS could never do — it closes the
"Verified" gap above (`bashio::config` reading real Supervisor-managed
options). All three bugs below only exist against a real Supervisor; none of
them reproduced in `mcp/scripts/rehearsal.mjs` or the earlier Docker testing,
because those never go through the Supervisor's own options-validation layer.

### Bug 1 — empty-string option defaults fail their own schema

First install attempt: clicking **Start** failed immediately with
`Configuração inválida: expected a URL` before the container even ran.
`config.yaml`'s `options:` block defaulted `rp_id`, `origin`, `admin_uids`,
`mcp_origin` to `""` — fine for the `str?` fields, but `origin`/`mcp_origin`
were `url?`, and voluptuous's `url?` rejects `""` outright (it does not
special-case blank-as-absent). Fixed by dropping the defaults for all four
fields entirely (commit `8c6bbb1`) — the three `run` scripts already used
`bashio::config.has_value`, which correctly treats a genuinely-absent option
the same as never-configured, so no runtime code needed to change.

### Bug 2 — the Configuration UI itself can't save blank optional URLs

Even after Bug 1's fix, opening the app's own **Configuration** tab and
clicking **Salvar** with the URL fields left blank (guest mode, the
documented default) failed with the same `expected a URL` error. Root cause:
the Supervisor's schema-driven Configuration form submits `""` for any field
left blank rather than omitting the key — this is Supervisor UI behavior,
not something `config.yaml` controls. `url?` never accepts `""`. Fixed by
changing `origin`/`mcp_origin` from `url?` to `str?` (commit `aed3a9e`) — the
actual URL shape is still validated where these values get used (openGym's
own runtime, `@simplewebauthn`'s RP config), so nothing meaningful was lost.

### Bug 3 — the option named "origin" specifically resists both fixes

After Bug 2's fix, `mcp_origin` picked up `str?` immediately — confirmed via
`ha apps info`, its schema entry changed from `format: url` to plain
`type: string` right away. `origin`, edited identically in the same commit,
did not: `ha apps info` kept showing `format: url` for it, unchanged, across
every cache-busting method tried in sequence: `ha store update`,
`ha store reload` (twice, including one that actually completed —
`"Command completed successfully"` — not just timed out), a full
`ha apps uninstall` + `ha apps install` cycle (fresh clone), and finally a
complete `ha supervisor restart`. The GitHub API (not just the CDN-cached raw
URL) confirmed the committed file already said `origin: str?` the whole
time — this was not a git/push/CDN propagation problem. `mcp_origin`, an
identically-shaped field edited in the very same commit, updated correctly
every time. The most plausible explanation: the Supervisor treats an option
literally named `origin` specially somewhere in its own validation or
network layer (a CORS-adjacent reserved name), independent of what the
add-on's own `config.yaml` schema declares. Rather than keep fighting an
undocumented Supervisor behavior, renamed the option key to `public_url`
(commit `5ad94cc`) — updated `config.yaml`, `translations/en.yaml`, and both
`run` scripts that read it (`api/run`, `mcp/run`). User-facing behavior is
identical: the Configuration tab still labels it "Public URL", and it still
becomes the same `ORIGIN` env var both scripts already expected. This is
purely a repackaging-side workaround; nothing in it should ever go upstream
to openGym itself.

### Confirmed working after all three fixes

After uninstall + reinstall on the corrected `public_url` schema:
`ha apps start 4c21d965_opengym` → `Command completed successfully`,
`ha apps info` → `state: started`, `docker ps` → the container `Up` and
staying up (not crash-looping). Inside the container:
`s6-rc -a list` shows all real services (`api`, `mcp`, `web`, `media-init`,
plus s6 bookkeeping) — confirming `bashio::config` genuinely read real
Supervisor-managed options this time, which was the one thing no earlier
test round could exercise. `wget` from inside the container to
`http://127.0.0.1:8099/` returned openGym's actual `index.html` (title
"openGym"), and `http://127.0.0.1:8099/api/health` returned
`{"ok":true,"users":0}` — a real, freshly-initialized `db.json`, not a
crash or a stub response. `curl -I` from outside the VPS to
`https://home.picoli.eu/app/4c21d965_opengym` also returned `200`.

### Not yet confirmed: the Ingress web UI in an actual browser

Clicking **Abrir interface web** in a real browser session (through
Chrome automation, not on Matheus's own LAN) produced a plain
`home.picoli.eu refused to connect` — a connection-level failure, not an
HTTP error page, and it reproduced consistently across three attempts
(including one via a direct URL navigation that still resolved through the
SPA router, `#/`). This is very unlikely to be an openGym-specific bug:
`internal_url`/`external_url` are both unset on this HA instance (checked
via `/api/config`), and the same-shaped `curl -I` from outside confirmed the
underlying HTTP route is genuinely serving `200`. The most likely
explanation is something in how this specific Cloudflare Tunnel setup
proxies the Ingress iframe/WebSocket for external (non-LAN) sessions — a
property of the tunnel, not of this add-on's packaging. **Needs
confirmation from Matheus's own device** (ideally on the home LAN, where
Ingress traffic doesn't have to cross the tunnel at all) before treating
this as closed. If it turns out to be real and openGym-specific, the
likeliest place to look is `web/nginx.conf.template`'s handling of the
`X-Ingress-Path` header Supervisor injects for Ingress requests.

## Test coverage — what's confirmed vs. still untested

Mapped against `opengym/DOCS.md`'s own steps, against the real Supervisor
install on `home.picoli.eu` (slug `4c21d965_opengym`):

| Step | What it is | Status |
|---|---|---|
| Step 1 — guest mode | Click Start, open from sidebar, use with no config | **Backend confirmed** (container up, s6 services running, `/` and `/api/health` respond for real from inside and outside the host). **Browser/UI not confirmed** — see "Not yet confirmed" above (Ingress `refused to connect` in the remote Chrome session; needs Matheus's own device, ideally on the LAN). |
| Step 2 — real accounts (Passkey hostname / Public URL) | Fill in `rp_id` + `public_url` in Configuration, restart | **Not tested at all.** Both fields are still blank on the live install (guest mode only, from Bug 1–3 debugging). Nobody has entered a real hostname, restarted, and confirmed the sign-in screen actually offers "Create a passkey." |
| Step 3 — Cloudflare Tunnel | Install Cloudflared App, point a hostname at port 8099 | **Not tested at all.** Matheus already has Cloudflare Tunnel infra for other services (see his own reference memory), but nothing has been wired up for openGym specifically this session. |
| Step 4 — AI connector (MCP) | Second hostname, port 3001, `mcp_enabled` + `mcp_origin` | **Not tested at all.** `mcp_enabled` is still `false` on the live install. Separately, note the `TEMPORARY` `OPENGYM_REF` pin (see "Next steps" #3) means this image is built from the `feat/mcp-connections-ui` fork commit specifically so MCP *can* work once configured — but that code path itself hasn't been exercised inside this HA packaging yet. |
| Optional: make yourself admin | Set `admin_uids` in Configuration | **Not tested.** Field is blank. |

In short: the one thing this session set out to close — does `bashio::config`
actually work against a real Supervisor — **is closed** (Bugs 1–3 and the
"Confirmed working" section above). Everything past Step 1 in `DOCS.md` is
still exactly as untested as before this session; only the guest-mode path
has real backend evidence behind it.

## Next steps, in order

1. **Confirm the Ingress web UI from Matheus's own device** (see directly
   above) — the one remaining unconfirmed piece of Step 1.
2. **Test Steps 2–4 from `DOCS.md`** (real accounts, Cloudflare Tunnel,
   AI connector) against the live install — see "Test coverage" above.
   Needs Matheus's own domain/Cloudflare decisions, so it wasn't done
   autonomously this session. Fix forward in this repo if anything breaks,
   same as Bugs 1–3.
3. Add `opengym/icon.png` (128×128) and `opengym/logo.png` (250×100) — not
   yet added, Store shows a generic icon without them.
4. Once [MR !86](https://gitlab.com/DuarteSantos8/opengym/-/merge_requests/86)
   merges upstream: switch `opengym/Dockerfile`'s clone URL back to
   `https://gitlab.com/DuarteSantos8/opengym.git` and `OPENGYM_REF` back to
   `main` (or a release tag). Remove the `TEMPORARY` comments once done.
5. Not before all of the above: consider whether to submit this for listing
   in any curated Home Assistant add-on index. Ship as an unlisted personal
   repo first — this was an explicit "not doing yet" in the original plan.

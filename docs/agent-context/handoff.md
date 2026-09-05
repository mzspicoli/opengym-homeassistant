# Handoff — opengym-ha-app

Last updated: 2026-09-01 (Codex continuation after Claude Code's real
Supervisor install and packaging-debugging session).

## Current state

Local repo at `~/Documents/Codex/2026-09-01/opengym-ha-app`, pushed (with
Matheus's explicit go-ahead) to **https://github.com/mzspicoli/opengym-homeassistant**
(public), branch `main`. **Installed and running on Matheus's real Home
Assistant** (`home.picoli.eu`) as of this session — see "2026-09-01: real
Supervisor test" below for the three real bugs that surfaced and were fixed
against the actual Supervisor (none of them reproduced in Docker-only
testing). The remaining Ingress failure is now diagnosed precisely: the
packaged upstream nginx template returns `Content-Security-Policy:
frame-ancestors 'none'`, so the browser correctly refuses HA's iframe even
though the endpoint itself returns 200. The packaging-only fix in version
`0.1.1` now passes a real isolated Docker build/run on the VPS; it still needs
installation on the real Supervisor and browser readback before Step 1 is
closed.

All files exist and are internally consistent (see root `README.md` for the
map). Three independent real-Docker builds on the VPS (not just read-through)
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

### Initial unresolved Ingress result (superseded by the diagnosis below)

Clicking **Abrir interface web** in a real browser session (through
Chrome automation, not on Matheus's own LAN) produced a plain
`home.picoli.eu refused to connect` — a connection-level failure, not an
HTTP error page, and it reproduced consistently across three attempts
(including one via a direct URL navigation that still resolved through the
SPA router, `#/`). `internal_url`/`external_url` were both unset on this HA
instance (checked via `/api/config`), and the same-shaped `curl -I` from
outside confirmed the underlying HTTP route was genuinely serving `200`.
At that point the Cloudflare Tunnel was the leading hypothesis. The Codex
continuation below disproved that hypothesis by opening the exact Ingress URL
directly and reading its response headers: openGym's CSP blocked the iframe.

## 2026-09-01: Codex continuation — Ingress root cause and local 0.1.1 fix

The external-browser failure was reproduced again in Matheus's already
authenticated Chrome session. The HA shell rendered normally, while its
`openGym` iframe displayed `home.picoli.eu refused to connect.` The exact
Ingress URL was then opened directly in a separate tab: it returned HTTP 200,
loaded the openGym document, and set the page title to `openGym`. This ruled
out the Cloudflare Tunnel and Supervisor route as the primary cause.

Chrome network readback on that same 200 response showed the decisive header:

```text
Content-Security-Policy: frame-ancestors 'none'
```

That policy comes from openGym's own `web/nginx.conf.template` and forbids all
embedding, including the legitimate same-origin iframe used by Home Assistant
Ingress. The response also carried `X-Frame-Options: SAMEORIGIN` after the
Supervisor proxy, which is compatible with HA; CSP's stricter `none` directive
is what wins in the browser.

Packaging fix (built and run in isolation; not yet installed on Supervisor):

- `opengym/Dockerfile` rewrites upstream's framing headers to
  `X-Frame-Options: SAMEORIGIN` and CSP `frame-ancestors 'self'` while it
  prepares the nginx template. This keeps cross-site framing blocked but lets
  HA's same-origin Ingress wrapper embed the UI.
- The Dockerfile has build-time assertions that fail if the Ingress-blocking
  `frame-ancestors 'none'` survives or if the replacement headers are absent.
- `opengym/config.yaml` is bumped from `0.1.0` to `0.1.1` so Supervisor can
  recognize the corrected image as an update.
- The transformation was rehearsed locally against openGym's current nginx
  template: all three X-Frame-Options occurrences became `SAMEORIGIN`, all
  three CSP occurrences became `frame-ancestors 'self'`, and no `none`
  occurrence remained. `git diff --check` also passes.

After Matheus explicitly authorized the isolated VPS build, commit `910d03d`'s
`opengym/` context was copied to a temporary directory and built as
`opengym-ha-app:ingress-test-910d03d`. The real build completed successfully,
including the new framing-header assertions. An ephemeral container bound only
to VPS loopback port `18099` then proved:

- `GET /api/health` returned `{"ok":true,"users":0}`.
- `GET /` returned HTTP 200, `<title>openGym`, and `id="root"`.
- Response headers were exactly `X-Frame-Options: SAMEORIGIN` and
  `Content-Security-Policy: frame-ancestors 'self'`.
- `s6-rc -a list` included `api`, `mcp`, `web`, and `media-init`; container
  status was `running true 0` (running, zero restarts).

The test container, image tag, temporary build context, and temporary data
directory were all removed afterward and their absence was read back. No
production container, route, data, or Home Assistant installation was changed.

Post-build live Chrome readback, before publication/installation of 0.1.1:
the authenticated HA page still rendered `home.picoli.eu refused to connect`
inside the openGym iframe. Opening that exact Ingress URL directly returned
HTTP 200 with title `openGym`; its live headers remained
`X-Frame-Options: SAMEORIGIN` plus CSP `frame-ancestors 'none'`. This confirms
the live Supervisor is still serving the old image and cleanly separates the
green 0.1.1 candidate evidence from deployment evidence. No browser setting or
HA configuration was changed during this read-only test.

## 2026-09-01: Store assets added locally

`opengym/icon.png` (128x128) and `opengym/logo.png` (250x100) now exist and
were visually checked. They are derived from openGym's official
`frontend/public/icon-512.png` and `assets/banner.svg`, preserving its
dumbbell mark, wordmark, and colors. `opengym/logo.svg` is the editable source
for the compact Store layout. The root README now states this asset provenance
explicitly instead of claiming that no upstream work at all is copied.

## 2026-09-01: MR !86 current status

GitLab's public API reports MR !86 still **open**, not merged, with
`detailed_merge_status: conflict`; source SHA is
`22e80b8fe8703449dcada96d1d99a589e8fb7282`. Therefore the temporary fork URL
and pinned commit in `opengym/Dockerfile` remain in place. Do not switch to
upstream `main` yet.

The first public 0.1.1 workflow after the Ingress fix exposed an additional
reproducibility issue: both amd64 and aarch64 runners failed at `git checkout
ebd49888...` with `fatal: unable to read tree`. The earlier isolated VPS build
had succeeded only because Docker cached that now-unreachable source object.
The MR branch had been force-updated to the SHA above. A fresh shallow clone of
`feat/mcp-connections-ui` confirmed that exact HEAD and the required
`api/state-store.js`, `mcp/src/http.js`, and `web/nginx.conf.template` files.
`OPENGYM_REF` was therefore advanced to the exact current MR SHA (still pinned,
not a moving branch and not upstream `main`). The failed workflow published no
manifest, so no broken 0.1.1 image was made available to Supervisor.

Before republishing, the updated pin was validated on the VPS with a real
`--no-cache` build and isolated run. The fresh clone checked out `22e80b8...`;
the frontend built; `/api/health` returned `{"ok":true,"users":0}`; the root
returned HTTP 200 with `SAMEORIGIN` plus `frame-ancestors 'self'`; s6 listed
`api`, `mcp`, `web`, and `media-init`; and the container stayed running with
zero restarts. The test container, image, VPS build/data directories, and local
review clone were removed afterward.

## 2026-09-01: version 0.1.1 installed on live Supervisor — Ingress confirmed fixed

Continuing directly from Codex's "Next steps" #1, on the same `home.picoli.eu`
Supervisor (slug `4c21d965_opengym`), via the Terminal & SSH app's `ha` CLI:

- `ha store update` / `ha store reload` did **not** pick up the new
  `version: "0.1.1"` from the store repo — `ha apps info` kept reporting
  `version_latest: 0.1.0` even after a full uninstall+reinstall cycle. Only a
  full `ha supervisor restart` made Supervisor re-read the repo correctly and
  report `version_latest: 0.1.1`. This is the exact same stubborn-caching
  pattern already seen with the `origin`→`public_url` rename during the
  Bug 1–3 debugging earlier this session — logging it here in case it
  recurs on a future version bump.
- After the restart, `ha apps uninstall 4c21d965_opengym && ha apps install
  4c21d965_opengym` completed successfully and `ha apps info` confirmed
  `version: 0.1.1`. `ha apps start 4c21d965_opengym` reported `state: started`.
- **Live browser Ingress readback, all four required checks pass:**
  opened `https://home.picoli.eu` + the app's `ingress_entry` path
  (`/api/hassio_ingress/<token>/`) in a fresh authenticated Chrome tab —
  it rendered openGym's actual login screen ("Sign in with passkey" /
  "Create new profile" / "Continue without account"), not
  `refused to connect`. A same-origin `fetch()` against that same URL from
  inside the page confirmed: `status: 200`; response headers include
  `content-security-policy: frame-ancestors 'self'` (not `'none'`) and
  `x-frame-options: SAMEORIGIN`. `GET .../api/health` returned
  `200 {"ok":true,"users":0}`.
- One unrelated, minor finding: `manifest.json` under the ingress path
  returned `401` (twice, in the network log) while the document, JS, and CSS
  assets all returned `200`. Doesn't block anything — the app renders and
  functions — but worth a look eventually (likely the PWA manifest isn't
  covered by whatever Supervisor considers "authenticated" static assets
  under the ingress proxy, or openGym's own nginx template scopes it
  differently than the other static files).
- The uninstall+install cycle was accepted as fine to run without extra
  confirmation, given the standing authorization already granted this session
  to test freely on the real instance and fix forward.

**Step 1 (guest mode) from `DOCS.md` is now fully closed**: both backend
(Bugs 1–3) and Ingress/browser rendering are confirmed working on the live
Supervisor install running version 0.1.1.

## 2026-09-01: Steps 2 and 4 confirmed live, security fixes shipped as 0.1.2

Continuing the same session, with a real domain (`og-teste.picoli.eu` +
`og-teste-mcp.picoli.eu`, both Cloudflare Tunnel hostnames added to the
existing `claudeflare` tunnel — DNS-proxied, Universal SSL). One gotcha hit
and fixed along the way: a hostname with **two** subdomain levels
(`mcp.og-teste.picoli.eu`) fails TLS handshake, because picoli.eu's
Universal SSL cert only covers `picoli.eu` + `*.picoli.eu` (one level) —
renamed to the one-level `og-teste-mcp.picoli.eu` and it worked immediately.
Matheus explicitly authorized doing Cloudflare's Google-SSO login myself
going forward when the dashboard needs it (saved as
`feedback_cloudflare_access_method` in memory) — API first, dashboard as
fallback.

- **Step 2 (real accounts) — confirmed working.** Set `rp_id` /
  `public_url` to the real hostname, restarted, opened
  `https://og-teste.picoli.eu/`, chose "Create new profile," and Matheus
  completed the Touch ID ceremony himself (WebAuthn requires the actual
  hardware — not something Chrome automation or I can do). Landed on the
  real signed-in home screen ("Hi Matheus"), not guest mode.
- **Step 4 (AI/MCP connector) — confirmed working end to end**, including
  a real tool call round-trip: from openGym's own Settings page, "Add in
  Claude" pre-filled the connector, added as a **second** claude.ai
  connector named "OpenGym (teste)" (an existing unrelated connector
  already pointed at `fit-mcp.picoli.eu` — a separate, undocumented-here
  production-looking MCP proxy on its own dedicated Cloudflare Tunnel,
  discovered but deliberately left untouched per Matheus's instruction).
  Completed the OAuth consent flow (profile picker + read/write scope
  choice), then in a fresh claude.ai chat asked it to call `list_profiles`,
  `list_routines`, and `get_profile_state` — all three executed and
  returned real data.

### Three fixes shipped as version 0.1.2, all validated with an isolated Docker build+run on the VPS before publishing

Matheus asked for a security pass over the app + the new tunnels, which
surfaced a real bug; separately he asked about logging and proposed a
same-domain MCP toggle. All three landed together:

1. **Security fix — stack-trace info disclosure.** `mcp/run` was missing
   `NODE_ENV=production` (`api/run` already had it), so Express's default
   *development* error handler sent full stack traces — including internal
   container filesystem paths (`/opt/opengym/mcp/node_modules/...`) — to
   any client that sent malformed input to the publicly-reachable MCP
   endpoint. Confirmed the leak first (`curl` with broken JSON), then
   confirmed it gone after the fix, both in isolation and live.
2. **nginx logging to stdout.** Alpine's nginx logs to
   `/var/log/nginx/{access,error}.log` by default — invisible in HA's own
   Log tab (stdout/stderr only) and lost on every container restart
   (nothing under `/data`). Redirected both to `/dev/stdout` /
   `/dev/stderr` via a Dockerfile sed on `/etc/nginx/nginx.conf`. Confirmed
   via `docker logs` showing real access/error lines during testing.
   Deeper *application*-level access/audit logging (api/mcp themselves)
   would require patching openGym's own source, which is out of scope for
   a packaging-only repo — noted, not done.
3. **Same-domain MCP mode (`mcp_origin` is now truly optional).** Matheus's
   idea: a Cloudflare-Access-style login wall in front of the main domain
   breaks MCP (it's machine-to-machine and can't complete an interactive
   login redirect), so a second, un-gated hostname is only needed for that
   specific case — everyone else can share one domain. HA Supervisor's
   options schema can't do real conditional field visibility (confirmed
   against `feedback-ha-options-flow-no-mcp` from memory), so the
   equivalent was implemented instead: leaving `mcp_origin` blank now makes
   `mcp/run` fall back to `public_url`, and a new
   `opengym/nginx/mcp-shared.conf` (this repo's own file, spliced into
   `default.conf.template` at build time via `sed ... r`, not an `include`
   — avoids all GNU-vs-BusyBox-sed `a`-command portability risk) proxies
   the rest of the MCP route surface (`/mcp`, `/manage/*`, `/token`,
   `/register`, `/revoke`, and the three `.well-known` metadata paths —
   enumerated directly from `mcp/src/http.js` and the
   `@modelcontextprotocol/sdk`'s `mcpAuthRouter()` source in the running
   container, not guessed) onto that same origin. A second `mcp_origin`
   domain is still fully supported for the access-control case.
   `ports_description` for 3001/tcp and `DOCS.md` Step 4 updated to match.
   Confirmed live: `og-teste-mcp.picoli.eu` was reconfigured back out (left
   `mcp_origin` blank), and `/.well-known/oauth-authorization-server` on
   `og-teste.picoli.eu` itself now returns every OAuth endpoint
   (issuer/authorization/token/registration/revocation) on that single
   domain — no second port published on the container at all.

Also per Matheus's request: `DOCS.md` Step 3 (Cloudflare Tunnel) now has
two `<details>` collapsible sections — "I don't have a domain in Cloudflare
yet" (full path: registrar → free Cloudflare account → nameservers) and "I
already have a domain added to Cloudflare" (starts from installing
Cloudflared) — instead of one linear path that assumed a domain already
existed. Not yet visually confirmed that HA's Documentação tab renders
raw `<details>`/`<summary>` HTML correctly — check this next time the
Documentação tab is open in a browser.

**Gotcha reconfirmed**: uninstalling and reinstalling the app (needed here
to pick up the version bump, same stubborn-caching pattern as before) wipes
its saved Configuration options back to `config.yaml`'s defaults — `rp_id`,
`public_url`, `mcp_enabled`, and `mcp_origin` all had to be re-entered
after the 0.1.1→0.1.2 upgrade, and the `og-teste` passkey account created
earlier this session was lost (`/api/health` went from `users:1` back to
`users:0`) even though `/data` itself is a persistent Supervisor volume —
worth understanding better before this happens on a real user-facing
install, since it means every version bump that needs a reinstall is
destructive to configuration unless it's re-applied by hand afterward.

Minor housekeeping left on the VPS (`vps-kansas-city`): a stray
`/tmp/opengym-test-build` + `/tmp/opengym-test-data` (~140 MB, root-owned
from the container's bind mount) from this session's isolated validation
build — harmless, will clear on next reboot, `sudo rm -rf` needed to clear
it sooner (no interactive terminal available to supply the sudo password
this session).

## Test coverage — what's confirmed vs. still untested

Mapped against `opengym/DOCS.md`'s own steps, against the real Supervisor
install on `home.picoli.eu` (slug `4c21d965_opengym`):

| Step | What it is | Status |
|---|---|---|
| Step 1 — guest mode | Click Start, open from sidebar, use with no config | **Fully confirmed on live 0.1.1.** Backend (Bugs 1–3) and Ingress (CSP `frame-ancestors 'self'`, HTTP 200, `/api/health` healthy) both verified against the real Supervisor install — see "version 0.1.1 installed on live Supervisor" above. |
| Step 2 — real accounts (Passkey hostname / Public URL) | Fill in `rp_id` + `public_url` in Configuration, restart | **Fully confirmed.** Real passkey created via Touch ID on `og-teste.picoli.eu`, landed signed-in (not guest). Currently blank again on the live install after the 0.1.2 reinstall wiped Configuration (see gotcha above) — re-entering these two fields is enough to get back to the confirmed-working state, no code changes needed. |
| Step 3 — Cloudflare Tunnel | Install Cloudflared App, point a hostname at port 8099 | **Confirmed, but via a different path than DOCS.md describes**: this session used the existing `claudeflare` Named Tunnel (already running as a systemd `cloudflared` service on host `pve`, config managed via the Cloudflare dashboard's Published Application Routes, not a separate Cloudflared **App** inside this HA instance) rather than installing the Cloudflared *App* from the Store. Functionally equivalent — same tunnel mechanism — but nobody has actually walked through DOCS.md's own instructions (installing the Cloudflared App itself) to confirm they're accurate for someone without pre-existing tunnel infra. |
| Step 4 — AI connector (MCP) | `mcp_enabled` + `public_url` (mcp_origin optional as of 0.1.2) | **Fully confirmed**, both server-side (OAuth metadata, `/mcp` endpoint) and through a real claude.ai connector doing an actual tool call round-trip. Currently off again after the reinstall — re-enable `mcp_enabled` (and re-set `public_url`) to get back to the confirmed state. |
| Optional: make yourself admin | Set `admin_uids` in Configuration | **Not tested.** Field is blank. Also worth finding: is there a less fragile way to get a profile's `id` than reading `db.json` by hand through the Terminal app, as DOCS.md currently instructs? |

In short: both what this session originally set out to close (`bashio::config`
against a real Supervisor — Bugs 1–3) and what it closed today (Steps 2 and
4, end to end, including a real external MCP client) are done. Only Step 3's
literal DOCS.md path (the Cloudflared *App*, as opposed to the equivalent
tunnel setup this session actually used) and the admin flag remain
unverified.

## Next steps, in order

1. ~~Publish/install version 0.1.1, then re-test Ingress in the authenticated
   browser.~~ **Done 2026-09-01.**
2. ~~Test Steps 2–4 from `DOCS.md` (real accounts, Cloudflare Tunnel,
   AI connector) against the live install.~~ **Steps 2 and 4 done and
   confirmed 2026-09-01**, including a real MCP tool-call round-trip from
   claude.ai. Step 3 confirmed functionally (the tunnel works) but not via
   DOCS.md's own literal instructions (Cloudflared App) — see the Test
   coverage table.
3. **Re-enter Configuration on the live install**: `rp_id` = `og-teste.picoli.eu`,
   `public_url` = `https://og-teste.picoli.eu`, `mcp_enabled` on — wiped by
   the 0.1.2 reinstall (see the reinstall-wipes-config gotcha above). Not
   done automatically since it's better paired with actually walking
   through DOCS.md Step 3 fresh (next item) rather than just restoring
   state blindly.
4. **Actually follow DOCS.md Step 3's own instructions once** (install the
   Cloudflared *App* from the Store, not the pre-existing systemd tunnel
   this session used) against a fresh test hostname, to confirm the docs
   are accurate for someone without Matheus's existing tunnel
   infrastructure — the two collapsible sub-sections added today
   (no-domain-yet vs. already-have-one) haven't been read by an actual
   human yet either.
5. ~~Visually confirm the DOCS.md `<details>`/`<summary>` collapsible
   sections render correctly in HA's Documentação tab.~~ **Done
   2026-09-01** — both render as native disclosure triangles and expand
   correctly with their content on click.
6. Optional/minor: investigate the `manifest.json` 401 under the ingress path
   noted earlier — cosmetic (PWA install prompt), not a functional blocker.
7. Optional/minor: `sudo rm -rf /tmp/opengym-test-build /tmp/opengym-test-data`
   on `vps-kansas-city` (~140 MB, root-owned, harmless leftover from this
   session's isolated 0.1.2 validation build).
8. Optional: figure out why the app's own passkey account data (`db.json`
   under `/data`) didn't survive the uninstall+reinstall cycle needed for
   the version bump, given `/data` is supposed to be a persistent Supervisor
   volume independent of the container — reproduce deliberately and check
   whether it's actually `/data` being wiped or something else (a fresh
   `db.json` being created because `rp_id`/`public_url` reset to blank
   first, orphaning the existing passkey's RP binding).
9. Once [MR !86](https://gitlab.com/DuarteSantos8/opengym/-/merge_requests/86)
   merges upstream: switch `opengym/Dockerfile`'s clone URL back to
   `https://gitlab.com/DuarteSantos8/opengym.git` and `OPENGYM_REF` back to
   `main` (or a release tag). Remove the `TEMPORARY` comments once done.
10. Not before all of the above: consider whether to submit this for listing
    in any curated Home Assistant add-on index. Ship as an unlisted personal
    repo first — this was an explicit "not doing yet" in the original plan.

## MR !88 conflict resolution — 2026-09-04

MR !88 (`feat/mcp-remote-hostname`) was rebased onto the current upstream
`main` and force-updated safely with `--force-with-lease` from source SHA
`d1e7736` to `80f8d8a`. The merge contained the MCP remote-connection changes,
current CI/API hardening, Coach routes, MCP settings screen, and all locale
updates. Local validation passed: frontend build; the two synchronization and
pt-BR locale test files (15/15); MCP suite (72/72) plus plain-node loadability;
and API suite (150/150). GitLab accepted the push and started pipeline
2820252082; its cached merge status still says `cannot_be_merged_recheck` /
`conflict` while `has_conflicts` is false, so re-read after the pipeline and
GitLab mergeability recomputation complete.

### Follow-up after upstream v1.3.2 / MR !89 merge — 2026-09-05

MR !89 merged upstream as part of `main` v1.3.2 (`cf46301`). MR !88 was
then rebased again onto that exact target and force-updated with
`--force-with-lease` to `e27f8de`. The upstream review's three requests are
now addressed: the private production handoff was removed from the product
branch; `docs/SELF_HOSTING.md` states the safe one-reload upgrade path for
existing clients when `MCP_INTERNAL_URL` enables revisioned writes; and the
branch has zero diverged commits from `main`. Local validation after that
rebase passed: frontend 1134 tests and build, MCP 85 tests plus Node import
check, API 152 tests. A concise response was posted on MR !88. GitLab's new
pipeline is `2822772258`; at handoff it was newly created, so check its final
status and mergeability before treating the MR as ready for review.

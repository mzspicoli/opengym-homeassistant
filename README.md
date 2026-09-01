# openGym for Home Assistant

This packages **[openGym](https://gitlab.com/DuarteSantos8/opengym)** to run
as a Home Assistant App, so people who already use Home Assistant can install
and run it with clicks instead of a terminal.

## ⚠️ This is not my app — it's a repackaging

**openGym itself was built by [Duarte Santos](https://gitlab.com/DuarteSantos8)
and its community of contributors, at
[gitlab.com/DuarteSantos8/opengym](https://gitlab.com/DuarteSantos8/opengym).**
That's where the real product lives, and where credit for it belongs — the
routines, the workout tracking, the passkey login, all of it.

This repository does not contain openGym's application source. It only adds
the Home Assistant plumbing (one `Dockerfile`, some startup scripts, one config
screen) around openGym's own, unmodified source code, which it fetches from
the GitLab repo above every time an image is built. The Store icon and logo
are derived from openGym's official visual assets and remain credited to that
project. Nothing here is a fork of openGym or claims its work — this repo is
maintainer-neutral packaging, not a competing distribution.

If openGym is useful to you, go star/support the original project. Bug
reports about openGym itself (missing a feature, a workout not saving
correctly, etc.) belong on their GitLab, not here — only report something
here if it's specific to running it inside Home Assistant.

## Install

Settings → Add-ons → Add-on Store → ⋮ → Repositories → add:

```
https://github.com/mzspicoli/opengym-homeassistant
```

Then install "openGym" from the store. Everything else — including the
Cloudflare Tunnel setup — is explained on the App's own **Configuration**
screen once it's installed; no separate reading required.

## For anyone maintaining this packaging (not needed just to use the App)

openGym normally ships as four Docker services (a one-shot exercise-media
downloader, the backend, the web frontend, and an optional AI-connector
service). This repo builds those into **one** image with three background
processes sharing one data folder, which is the shape Home Assistant Apps
expect. See [`opengym/Dockerfile`](opengym/Dockerfile) and
[`opengym/rootfs/`](opengym/rootfs) for how, and
[`docs/agent-context/`](docs/agent-context) for the full history, the two
real bugs found while getting this working, and what's still open.

**Currently built from:** a specific commit on
`gitlab.com/mzspicoli/opengym`, branch `feat/mcp-connections-ui` — **not**
openGym's own `main` — because that's temporarily the only place openGym's
full remote AI-connector code exists; it hasn't been merged into the main
project yet
([MR !86](https://gitlab.com/DuarteSantos8/opengym/-/merge_requests/86)).
Once it is, this needs to switch back to pulling from
`gitlab.com/DuarteSantos8/opengym` directly — see the `TEMPORARY` notes in
`opengym/Dockerfile`.

**Status:** version 0.1.0 is installed and its backend is running on a real
Home Assistant Supervisor. That test found and fixed three Supervisor-only
configuration bugs. The remaining Ingress iframe failure has also been traced
to upstream's `frame-ancestors 'none'` header and fixed locally in packaging
version 0.1.1; that image still needs to be built, installed, and read back in
a browser before guest mode is fully confirmed. See the handoff for exact
evidence and the remaining Steps 2–4 tests.

## License

This packaging: AGPL-3.0-or-later, matching openGym itself.

## TODO before any public listing

- Build/install 0.1.1 and confirm the corrected Ingress UI in a real browser.
- Test account/passkey, Cloudflare Tunnel, and optional MCP configuration (see
  `docs/agent-context/handoff.md`).

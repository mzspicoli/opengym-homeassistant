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

This repository does not contain any of that work. It only adds the
Home Assistant plumbing (one `Dockerfile`, some startup scripts, one config
screen) around openGym's own, unmodified source code, which it fetches
straight from the GitLab repo above every time an image is built. Nothing
here is a fork of openGym, and nothing in openGym's own code is changed,
copied, or claimed as this project's work — this repo is maintainer-neutral
packaging, not a competing distribution.

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

**Status:** builds and runs correctly in a plain Docker test (confirmed:
serves the app, downloads exercise media, the optional AI connector idles
correctly when off). Not yet run inside a real Home Assistant instance —
that's the one thing still needed before calling this finished.

## License

This packaging: AGPL-3.0-or-later, matching openGym itself.

## TODO before any public listing

- `opengym/icon.png` (128×128) and `opengym/logo.png` (250×100) — not yet
  added; the Store shows a generic icon until these exist.
- Real Home Assistant test (see `docs/agent-context/handoff.md`).

# Agent context — opengym-ha-app

Shared memory for whichever agent (Claude Code, Codex, or Matheus by hand)
touches this repo next. Per the hybrid-memory protocol in `~/CLAUDE.md`, this
directory — not chat history — is the source of truth for durable decisions.

- **[handoff.md](handoff.md)** — current state, what's proven working, what's
  still open, and the exact next steps. Read this first.

## What this repo is

A Home Assistant App (add-on) repository that repackages
[openGym](https://gitlab.com/DuarteSantos8/opengym) — a self-hosted gym/
body-weight tracker built by Duarte Santos and contributors — so it can be
installed from the Home Assistant Add-on Store. **This repo does not contain
openGym's own code or claim credit for it**; see the root `README.md`'s
attribution section and `opengym/DOCS.md`'s opening note, both of which must
stay prominent — this was an explicit, repeated instruction from Matheus
when this repo was created (2026-09-01), not a minor style preference.

## Why this exists

Matheus self-hosts openGym already (see the sibling project's own
`docs/agent-context/` under the openGym MCP work,
`~/Documents/Codex/2026-08-24/.../openGym-mcp-ui/docs/agent-context/`, for
that unrelated effort). He wants non-technical household members to be able
to install and use it without a terminal, and asked specifically for the
Home Assistant App Store route — the same distribution mechanism as
Node-RED, ESPHome, etc. — with Cloudflare Tunnel access made as close to
one-click as that ecosystem allows (composed via the separate, official
Cloudflared App, not bundled — see handoff.md's Decision 3 for why).

## Where the actual plan lives

`~/.claude/plans/dapper-riding-curry.md` on this Mac has the original
approved implementation plan (architecture decisions, repo layout,
verification steps). Not duplicated here in full — read it if handoff.md
doesn't answer something.

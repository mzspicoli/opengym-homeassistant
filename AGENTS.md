# Agent entry point

Shared context for any agent (Claude Code, Codex, or otherwise) working in
this repo lives in [`docs/agent-context/`](docs/agent-context/README.md) —
read that before making changes, and update
[`docs/agent-context/handoff.md`](docs/agent-context/handoff.md) before
handing off between agents or ending a session, per the hybrid-memory
protocol in `~/CLAUDE.md`.

**Before touching `README.md` or `opengym/DOCS.md`**: both must keep a clear,
prominent statement that this repo repackages
[openGym](https://gitlab.com/DuarteSantos8/opengym) — built by Duarte Santos
and contributors — for Home Assistant, and claims no credit for openGym's
own work. This was an explicit, repeated instruction; do not soften or
remove it.

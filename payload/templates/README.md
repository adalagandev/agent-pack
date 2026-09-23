# Project Name

<!-- One-line description of what this project is. -->

> Scaffolded by agent-pack. Replace the placeholders, then delete this note.

## Status

Early scaffold. See `SPEC.md` for what it will do and `BUG.md` for the backlog.

## Governing docs

- **`SPEC.md`** — what the app does (product spec).
- **`CLAUDE.md`** — how work is organized, project conventions, and the
  `-warden` agent routing table.
- **`BUG.md`** — the `__TICKET_PREFIX__-<n>` backlog.

## Development

Code changes follow a `__TICKET_PREFIX__-<n>` ticket workflow (see `CLAUDE.md`). A committed
`.githooks/commit-msg` hook enforces ticket-prefixed commit subjects; enable it
once per clone:

```sh
git config core.hooksPath .githooks
```

## Running

<!-- How to build/run the app once there's something to run. -->

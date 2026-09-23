# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

> Scaffolded by agent-pack. Fill in the placeholders below, then delete this
> note. The "Agent-driven development" block is managed by the installer between
> its markers — edit the routing there via the pack, not by hand.

## What this repo is

<!-- One paragraph: what this project is and does. Point at SPEC.md for the
     product detail. -->

## Where each kind of rule lives (authority split)

| Question | Source of truth |
|----------|-----------------|
| *What* should the app do? (features, data model, UX, scope) | `SPEC.md` |
| *How* we work + this project's concrete coding conventions | this file (below) |
| *How* each layer is written in general (per-layer rules) | the `-warden` files in `.claude/agents/` |
| Tracked defects / backlog | `BUG.md` |

If they ever disagree: `SPEC.md` wins on behavior, the owning warden wins on
layer-level code shape, this file wins on project conventions and process.

## Working style

- Propose a milestone plan first and wait for approval before building.
- Ask clarifying questions when requirements are ambiguous rather than assuming.
- Build incrementally; each milestone should be independently runnable/testable.
- Before adding code, check whether existing code can be reused or extended;
  refactor shared logic into common components instead of copying it.

## Project code conventions

<!-- This project's concrete choices — the wardens enforce the generic per-layer
     shape; these say which choice THIS project makes. E.g. money type, naming,
     validation strategy, commenting bar, test focus. -->

## Project layout

<!-- Where things live in THIS project. The wardens read these instead of
     guessing; fill in what applies, delete what doesn't.
- Backend source root:      e.g. backend/src/main/java/com/acme/app
- Frontend source root:     e.g. frontend/src
- Frontend API module:      e.g. frontend/src/api.js
- Route definitions:        e.g. backend/.../web (Spring controllers) or app/routes.py
- Entities / repositories:  e.g. backend/.../entity, backend/.../repository
- Local API base URL:       e.g. http://localhost:8080/api
-->

## Ticket workflow

Code changes are tracked as `__TICKET_PREFIX__-<n>` tickets in `BUG.md`. A `.githooks/commit-msg`
hook (installed by agent-pack) rejects any commit whose subject line is not
`__TICKET_PREFIX__-<n> <description>`. Enable it in a fresh clone with:

```sh
git config core.hooksPath .githooks
```

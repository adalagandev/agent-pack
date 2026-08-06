# Agent Pack — portable `-warden` subagents

A self-contained, standalone bundle of specialist **`-warden`** subagents, the
CLAUDE.md delegation mapping, starter governing docs, and the `SR-<n>` ticket
commit hook — so **one command** bootstraps any project, brand-new or existing,
ready to work in.

This repository *is* the package: the two installers live at its root and carry
everything they install under `payload/`. Clone it (or copy the folder) anywhere,
then run an installer against a target project. Current version: see
[`VERSION`](VERSION).

## What's inside

```
agent-pack/                        # this repo's root
├── install-agents.ps1             # installer (Windows PowerShell / PowerShell 7+)
├── install-agents.sh              # installer (bash / macOS / Linux / Git Bash)
├── README.md                      # this file
├── TEST.md                        # TS-<n> installer test-scenario catalog (dev-only, not installed)
├── VERSION                        # pack version
└── payload/
    ├── agents/                    # the agent definitions that get installed
    │   ├── service-warden.md         (+ service-warden-refs/)
    │   ├── persistence-warden.md     (+ persistence-warden-refs/)
    │   ├── controller-warden.md      (+ controller-warden-refs/)
    │   ├── exception-warden.md       (+ exception-warden-refs/)
    │   ├── frontend-warden.md        (+ frontend-warden-refs/)
    │   ├── security-warden.md        (+ security-warden-refs/)
    │   ├── api-client-warden.md      (+ api-client-warden-refs/)
    │   ├── observability-warden.md   (+ observability-warden-refs/)
    │   ├── config-warden.md          (+ config-warden-refs/)
    │   ├── test-warden.md            (+ test-warden-refs/)
    │   ├── structure-warden.md       (+ structure-warden-refs/)
    │   ├── ticket-warden.md
    │   └── sync-warden.md
    ├── templates/                 # governing docs scaffolded if the target lacks them
    │   ├── CLAUDE.md
    │   ├── SPEC.md
    │   ├── BUG.md
    │   └── README.md
    ├── hooks/
    │   └── commit-msg             # the SR-<n> ticket-prefix commit hook
    └── claude-md-section.md       # the "Agent-driven development" block injected into CLAUDE.md
```

## Get the pack

Clone the repo (or copy the folder) anywhere on disk — it does not need to live
inside the project you install into:

```sh
git clone <repo-url> agent-pack
```

The installers resolve their payload relative to their own location, so you can
run them from wherever the pack lives.

## Usage

### Brand-new project (empty / not yet a git repo)

Point an installer at the new project's path with `--new` / `-New`. It runs
`git init` for you, scaffolds the governing docs, installs the agents, and enables
the `SR-<n>` commit hook — live in one command:

**bash**
```bash
/path/to/agent-pack/install-agents.sh --new /path/to/my-new-project
```

**PowerShell**
```powershell
C:\path\to\agent-pack\install-agents.ps1 -New -TargetRoot C:\code\my-new-project
```

### Existing project

Run from the project's root (the target defaults to the current directory), or
pass the target explicitly. No `git init` is performed — existing repo state is
left untouched:

**bash**
```bash
cd /path/to/my-project
/path/to/agent-pack/install-agents.sh                 # target = current dir
# or:
/path/to/agent-pack/install-agents.sh /path/to/my-project
```

**PowerShell**
```powershell
Set-Location C:\code\my-project
C:\path\to\agent-pack\install-agents.ps1              # target = current dir
# or:
C:\path\to\agent-pack\install-agents.ps1 -TargetRoot C:\code\my-project
```

### Flags

| bash | PowerShell | Effect |
|------|-----------|--------|
| `--new` | `-New` | `git init` the target first if it isn't a repo (no-op on an existing repo), so the hook is enabled automatically. |
| `-f` / `--force` | `-Force` | Overwrite agent files that already exist (governing docs are **never** overwritten). |
| `--no-hooks` | `-NoHooks` | Skip installing the commit-msg hook and setting `core.hooksPath`. |
| *(positional path)* | `-TargetRoot <path>` | Install target (defaults to current directory). |

## What it does

1. **Scaffolds missing governing docs.** For each of `CLAUDE.md`, `SPEC.md`,
   `BUG.md`, and `README.md`, if the target lacks it, one is created from the
   bundled template. **An existing doc is never overwritten** (reported as
   `keep (exists)`) — including by `-Force`, which only governs agent files.
2. **Installs the agents** into `<target>/.claude/agents/`. Existing files are
   left untouched and reported as `skip (exists)`; pass `-Force` (PowerShell) or
   `-f` (bash) to overwrite them.
3. **Registers them in `CLAUDE.md`** by writing the "Agent-driven development"
   section between `<!-- BEGIN agent-pack -->` and `<!-- END agent-pack -->`
   markers. Re-running refreshes that block in place (idempotent) rather than
   duplicating it.
4. **Installs the `SR-<n>` commit hook.** Copies `.githooks/commit-msg` into the
   target and, when the target is a git repo, sets `core.hooksPath = .githooks`.
   The hook rejects any commit whose subject isn't `SR-<n> <description>`
   (merge/revert/fixup!/squash! exempt; commits on `main` allowed). Skipped with
   `-NoHooks` / `--no-hooks`, or when the target isn't a git repo (then it's
   copied but not enabled — use `--new`/`-New` to `git init` first). `core.hooksPath`
   isn't cloned, so each fresh clone runs `git config core.hooksPath .githooks`
   once. It also ensures a `.gitattributes` rule (`.githooks/** text eol=lf`) —
   created if absent, appended if missing, left alone otherwise — so the hook
   can't be rewritten to CRLF on checkout (which would break it under `sh`).

## Notes

- **The rules are framework-agnostic; the examples are not.** Each agent's rules
  are written to hold across languages/stacks, with concrete violation/correct
  pairs in the companion `-refs/` files (Java / Python / React). The paths and
  stack names are examples from this pack's origin project — adjust them to your
  project's layout; you don't need to change the rules.
- **ticket-warden is wired up by default.** The installer scaffolds a `BUG.md`
  backlog and installs the `.githooks/commit-msg` backstop, so the `SR-<n>`
  ticket workflow is active out of the box. Opt out of just the hook with
  `-NoHooks` / `--no-hooks`.
- **sync-warden keeps the project's own docs honest.** It reconciles `SPEC.md`,
  `CLAUDE.md`, and (if you keep one) `BUG.md` — moving coding rules or process
  that leak into the spec back to their proper home and keeping the routing table
  matching `.claude/agents/`. Unlike ticket-warden it *is* wired into the routing
  map, and it works whether or not a `BUG.md` exists (it skips backlog checks when
  there's none).
- **Re-running is safe.** Agents already present are skipped unless you force,
  and the CLAUDE.md section is replaced in place.
- **Installer test scenarios live in `TEST.md`.** A `TS-<n>` catalog of
  hand-runnable checks (fresh bootstrap, `--new` git-init, partial installs,
  hook/CRLF behavior, cross-platform parity) to re-verify after any change to
  either installer.

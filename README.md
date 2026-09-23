# Agent Pack — portable `-warden` subagents

A self-contained, standalone bundle of specialist **`-warden`** subagents for
[Claude Code](https://docs.claude.com/en/docs/claude-code/overview), the
CLAUDE.md delegation mapping, starter governing docs, and a `<KEY>-<n>` ticket
commit hook — so **one command** bootstraps any project, brand-new or existing,
ready to work in.

Each warden owns one layer of a codebase (services, persistence, controllers,
exceptions, frontend, security, API clients, observability, config, tests,
structure, tickets, docs) with numbered rules and violation/correct example
pairs in Java, Python, and React. Claude Code delegates to them automatically
through the routing table the installer writes into your project's `CLAUDE.md`.

## Quick start

```sh
git clone https://github.com/adalagandev/agent-pack.git
cd your-project
bash ../agent-pack/install-agents.sh          # macOS / Linux / Git Bash
```

```powershell
git clone https://github.com/adalagandev/agent-pack.git
Set-Location your-project
powershell -ExecutionPolicy Bypass -File ..\agent-pack\install-agents.ps1   # Windows
```

Then open the project in Claude Code and run `/agents` — the wardens are listed.
Read on for brand-new projects, flags, and what gets written.

## Requirements

- **git** — the commit hook and `--new` / `-New` use it.
- **bash** (macOS, Linux, or Git Bash on Windows) **or** Windows PowerShell 5.1 /
  PowerShell 7+. Either installer alone is enough; they produce the same result.
- **Claude Code**, to actually use the installed agents.

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
├── LICENSE                        # MIT
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
    │   └── commit-msg             # the <KEY>-<n> ticket-prefix commit hook
    └── claude-md-section.md       # the "Agent-driven development" block injected into CLAUDE.md
```

## Get the pack

Clone the repo (or copy the folder) anywhere on disk — it does not need to live
inside the project you install into:

```sh
git clone https://github.com/adalagandev/agent-pack.git
```

The installers resolve their payload relative to their own location, so you can
run them from wherever the pack lives.

> **Windows: "running scripts is disabled on this system"?** PowerShell's default
> execution policy blocks unsigned scripts. Either run the installer through
> `powershell -ExecutionPolicy Bypass -File <path>\install-agents.ps1 <args>`
> (affects only that one run — used in every PowerShell example below), or allow
> local scripts for your user once with
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`. If Windows marked the
> files as downloaded (e.g. you got a ZIP instead of cloning), also run
> `Get-ChildItem -Recurse <path>\agent-pack | Unblock-File`.

## Usage

### Brand-new project (empty / not yet a git repo)

Point an installer at the new project's path with `--new` / `-New`. It runs
`git init` for you, scaffolds the governing docs, installs the agents, and enables
the `<KEY>-<n>` commit hook — live in one command:

**bash**
```bash
bash /path/to/agent-pack/install-agents.sh --new /path/to/my-new-project
```

**PowerShell**
```powershell
powershell -ExecutionPolicy Bypass -File C:\path\to\agent-pack\install-agents.ps1 -New -TargetRoot C:\code\my-new-project
```

### Existing project

Run from the project's root (the target defaults to the current directory), or
pass the target explicitly. No `git init` is performed — existing repo state is
left untouched:

**bash**
```bash
cd /path/to/my-project
bash /path/to/agent-pack/install-agents.sh            # target = current dir
# or:
bash /path/to/agent-pack/install-agents.sh /path/to/my-project
```

**PowerShell**
```powershell
Set-Location C:\code\my-project
powershell -ExecutionPolicy Bypass -File C:\path\to\agent-pack\install-agents.ps1   # target = current dir
# or:
powershell -ExecutionPolicy Bypass -File C:\path\to\agent-pack\install-agents.ps1 -TargetRoot C:\code\my-project
```

### Check that it worked

The installer prints one line per file and ends with `Done.`. In the target you
should then have:

- `.claude/agents/` — 13 `*-warden.md` files plus their `*-warden-refs/` folders
- `CLAUDE.md` containing an `<!-- BEGIN agent-pack -->` … `<!-- END agent-pack -->` block
- `SPEC.md`, `BUG.md`, `README.md` (only created if they were missing)
- `.githooks/commit-msg`, and `git config core.hooksPath` printing `.githooks`

Open the project in Claude Code and run `/agents` to see the wardens.

### Updating and uninstalling

- **Update:** `git pull` inside your agent-pack clone, then re-run the installer
  with `-f` / `-Force`. Agents are overwritten with the new versions and the
  CLAUDE.md block is refreshed in place; your governing docs are left alone.
- **Uninstall:** delete `.claude/agents/*-warden*`, the agent-pack block in
  `CLAUDE.md`, and `.githooks/commit-msg`, then run
  `git config --unset core.hooksPath`. Keep or delete the scaffolded docs as you
  like — they're ordinary files in your project.

### Flags

| bash | PowerShell | Effect |
|------|-----------|--------|
| `--new` | `-New` | `git init` the target first if it isn't a repo (no-op on an existing repo), so the hook is enabled automatically. |
| `-f` / `--force` | `-Force` | Overwrite agent files that already exist (governing docs are **never** overwritten). |
| `--no-hooks` | `-NoHooks` | Skip installing the commit-msg hook and setting `core.hooksPath`. |
| `--prefix <KEY>` | `-Prefix <KEY>` | Ticket key for commits and `BUG.md` (e.g. `ACME` → `ACME-12`). Defaults to the key already installed, else one derived from the folder name — see [Choosing the ticket key](#notes). |
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
4. **Installs the `<KEY>-<n>` commit hook.** Copies `.githooks/commit-msg` into the
   target with your ticket key filled in and, when the target is a git repo, sets
   `core.hooksPath = .githooks`.
   The hook rejects any commit whose subject isn't `<KEY>-<n> <description>`
   (merge/revert/fixup!/squash! exempt; commits on `main` allowed). Skipped with
   `-NoHooks` / `--no-hooks`, or when the target isn't a git repo (then it's
   copied but not enabled — use `--new`/`-New` to `git init` first). `core.hooksPath`
   isn't cloned, so each fresh clone runs `git config core.hooksPath .githooks`
   once. It also ensures a `.gitattributes` rule (`.githooks/** text eol=lf`) —
   created if absent, appended if missing, left alone otherwise — so the hook
   can't be rewritten to CRLF on checkout (which would break it under `sh`).

## Notes

- **The rules are framework-agnostic; the examples are illustrative.** Each
  agent's rules hold across languages/stacks, with concrete violation/correct
  pairs in the companion `-refs/` files (Java / Python / React). Agents take your
  project's real locations — source roots, API module, route definitions, local
  API base URL — from the **Project layout** section of `CLAUDE.md` (scaffolded
  with placeholders; fill it in), and detect them from the codebase when it's
  missing.
- **ticket-warden is wired up by default.** The installer scaffolds a `BUG.md`
  backlog and installs the `.githooks/commit-msg` backstop, so the `<KEY>-<n>`
  ticket workflow is active out of the box. Opt out of just the hook with
  `-NoHooks` / `--no-hooks`.
- **Choosing the ticket key.** Once the hook is enabled, every commit subject in
  the target must start with `<KEY>-<number> ` (e.g. `MSA-1 add login form`). The
  installer picks `<KEY>` in this order and prints which it used:
  1. `--prefix <KEY>` / `-Prefix <KEY>` — a letter then up to 9 letters/digits;
  2. the key already installed in the target (so re-runs and upgrades from
     v1.0, which used `SR`, keep theirs);
  3. derived from the target folder name — initials of a multi-word name
     (`my-shop-api` → `MSA`), else its first three letters (`billing` → `BIL`).

  To change it later, re-run with `--prefix` / `-Prefix`; the hook and the
  CLAUDE.md block are both rewritten.
- **sync-warden keeps the project's own docs honest.** It reconciles `SPEC.md`,
  `CLAUDE.md`, and (if you keep one) `BUG.md` — moving coding rules or process
  that leak into the spec back to their proper home and keeping the routing table
  matching `.claude/agents/`. Unlike ticket-warden it *is* wired into the routing
  map, and it works whether or not a `BUG.md` exists (it skips backlog checks when
  there's none).
- **Re-running is safe.** Agents already present are skipped unless you force,
  and the CLAUDE.md section is replaced in place.

## License

[MIT](LICENSE) — free to use, modify, and redistribute. Provided "as is", without
warranty of any kind.

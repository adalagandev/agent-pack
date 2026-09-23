# TEST.md — agent-pack installer test scenarios

Hand-runnable test-scenario catalog for the two installers (`install-agents.sh`
and `install-agents.ps1`). Each `TS-<n>` ticket is a fixed contract: preconditions,
the exact commands, and the concrete expected result. Run them against throwaway
directories after any change to either installer.

This is a **dev/test doc for the pack itself** — it lives at the pack root beside
`README.md` and is deliberately **not** under `payload/`, so it is never shipped
into a target project.

Status legend: 🔲 Untested · 🏗 Partial · ✅ Verified

## Conventions for running these

All scenarios use a throwaway target dir and reference the pack by path. Set up a
shell once, from the root of your clone of this repo:

```sh
# bash / Git Bash
PACK="$(pwd)"                                               # this pack (repo root)
crbytes() { tr -cd '\r' < "$1" | wc -c; }                    # CR bytes; 0 = pure LF
newtgt()  { d="$(mktemp -d)"; echo "$d"; }                   # fresh empty dir
```

```powershell
# Windows PowerShell 5.1 / PowerShell 7+
$PACK = (Get-Location).Path                                    # this pack (repo root)
function New-Tgt { $d = Join-Path $env:TEMP ("tgt-" + [guid]::NewGuid().ToString('N').Substring(0,8)); New-Item -ItemType Directory -Force $d | Out-Null; $d }
function CrBytes($p) { ([System.IO.File]::ReadAllBytes($p) | Where-Object { $_ -eq 13 }).Count }
```

**Baseline counts** a full install produces: **4** governing docs
(`CLAUDE.md`, `SPEC.md`, `BUG.md`, `README.md`), **24** entries under
`.claude/agents/` (13 `*-warden.md` + 11 `*-warden-refs/` dirs), **1** marker pair
in `CLAUDE.md`. Bash and PowerShell must produce equivalent results (see TS-17).

## Summary

| Scenario | What it checks | Precondition / flags | Status |
|----------|----------------|----------------------|--------|
| TS-1  | Fresh-project bootstrap | empty **git** repo | ✅ |
| TS-2  | Non-git target | empty dir, **no** `.git` | 🔲 |
| TS-3  | Existing source, no agents/docs | src files present | ✅ |
| TS-4  | Partial docs present | some docs exist | 🔲 |
| TS-5  | `CLAUDE.md` without marker → append | non-empty `CLAUDE.md`, no markers | 🔲 |
| TS-6  | `CLAUDE.md` with marker → refresh | markers already present | ✅ |
| TS-7  | Half the agents present | some `.claude/agents/*` exist | 🔲 |
| TS-8  | `-Force`/`-f` overwrites agents, not docs | `-Force` / `-f` | 🔲 |
| TS-9  | `--no-hooks`/`-NoHooks` | hook step skipped | 🔲 |
| TS-10 | Hook gating + exemptions | after install | ✅ |
| TS-11 | `autocrlf=true` hook stays LF (SR-20) | `core.autocrlf true` | ✅ |
| TS-12 | `.gitattributes` created | no `.gitattributes` | ✅ |
| TS-13 | `.gitattributes` appended, no clobber | existing, rule absent | ✅ |
| TS-14 | `.gitattributes` idempotent | rule already present | ✅ |
| TS-15 | Idempotent re-run | run twice | ✅ |
| TS-16 | Invocation variants equivalent | PWD / path / copied-in | ✅ |
| TS-17 | Cross-platform parity | bash vs PowerShell | ✅ |
| TS-18 | PowerShell 5.1 parses (SR-19) | Windows PS 5.1 | ✅ |
| TS-19 | Corrupt/missing payload errors safely | `payload/agents` absent | 🔲 |
| TS-20 | `--new`/`-New` git-inits + auto-enables hook | non-git dir, `--new`/`-New` | 🔲 |

---

## A. Fresh / scaffolding

### TS-1 — Fresh-project bootstrap ✅
- **Preconditions:** brand-new empty directory, `git init` run.
- **Steps:**
  ```sh
  T=$(newtgt); cd "$T"; git init -q
  bash "$PACK/install-agents.sh"                 # default target = PWD
  ```
  ```powershell
  $T = New-Tgt; Set-Location $T; git init -q
  & "$PACK\install-agents.ps1"                   # default target = PWD
  ```
- **Expected:** console shows `scaffolded:` for all 4 docs, `installed:` for 24
  agent entries, `CLAUDE.md: agent-pack section written` (bash) / `appended
  agent-pack section` (ps), `installed: .githooks/commit-msg`,
  `created: .gitattributes (.githooks/** text eol=lf)`,
  `git: core.hooksPath = .githooks`, `Done.` Then:
  `ls *.md` → 4 files; `ls .claude/agents | wc -l` → `24`;
  `grep -c 'BEGIN agent-pack' CLAUDE.md` → `1`;
  `git config --get core.hooksPath` → `.githooks`; hook is executable.

### TS-2 — Non-git target 🔲
- **Preconditions:** empty directory, **no** `git init`.
- **Steps:** run the installer against the dir (do **not** init git first).
- **Expected:** docs + agents + `.githooks/commit-msg` + `.gitattributes` all
  created, but the git line reads `git: target is not a git repo - hook copied but
  not enabled.` followed by the `After 'git init', run: git config core.hooksPath
  .githooks` hint; `core.hooksPath` is unset. After `git init` **and** running the
  printed command, a non-`SR` commit is then rejected (ties into TS-10).

---

## B. Existing docs / marker states

### TS-3 — Existing source, no agents/docs ✅
- **Preconditions:** a dir with real source (e.g. `src/main.js`, `package.json`),
  `git init`, no `.claude/`, no governing docs.
- **Steps:** copy `agent-pack/` in and run `bash agent-pack/install-agents.sh`.
- **Expected:** 4 docs `scaffolded:`, 24 agents `installed:`, full hook/gitattributes
  setup; the pre-existing `src/main.js` and `package.json` are **byte-for-byte
  unchanged** (diff them before/after).

### TS-4 — Partial docs present 🔲
- **Preconditions:** target already has, say, `README.md` and `CLAUDE.md` (with
  real content); `SPEC.md` and `BUG.md` missing.
- **Steps:** run the installer.
- **Expected:** `keep (exists): README.md`, `keep (exists): CLAUDE.md`,
  `scaffolded: SPEC.md`, `scaffolded: BUG.md`. The two pre-existing docs are
  **byte-identical** afterward (their content is never templated over). `-Force`/`-f`
  does **not** change this (see TS-8).

### TS-5 — `CLAUDE.md` without a marker block → append 🔲
- **Preconditions:** target has a non-empty `CLAUDE.md` with **no**
  `<!-- BEGIN agent-pack -->` markers.
- **Steps:** run the installer.
- **Expected:** the pre-existing `CLAUDE.md` prose is preserved and the agent-pack
  block is **appended** at the end (`CLAUDE.md: appended agent-pack section` on ps);
  exactly one `BEGIN`/`END` pair; original text still present above the block.

### TS-6 — `CLAUDE.md` with a marker block → refresh in place ✅
- **Preconditions:** a target that already has one agent-pack block (e.g. a prior
  install).
- **Steps:** run the installer again.
- **Expected:** `CLAUDE.md: refreshed existing agent-pack section` (ps); the block
  is replaced in place, **still exactly one** `BEGIN`/`END` pair
  (`grep -c` each → `1`), no duplication, surrounding text intact.

---

## C. Agents / -Force

### TS-7 — Half the agents already present 🔲
- **Preconditions:** `.claude/agents/` exists with roughly half the warden files
  present (e.g. delete a subset after a first install), rest missing.
- **Steps:** run the installer (no `-Force`).
- **Expected:** already-present entries report `skip (exists): <name>   [use -f/-Force
  to overwrite]` and are left unchanged; missing ones report `installed:`. Final
  count is the full **24**.

### TS-8 — `-Force`/`-f` overwrites agents but never docs 🔲
- **Preconditions:** a fully installed target; hand-edit one agent file and one
  governing doc (e.g. add a marker line to `service-warden.md` and to `SPEC.md`).
- **Steps:**
  ```sh
  bash "$PACK/install-agents.sh" -f "$T"
  ```
  ```powershell
  & "$PACK\install-agents.ps1" -TargetRoot $T -Force
  ```
- **Expected:** every agent reports `installed:` (overwritten — the hand-edit to
  `service-warden.md` is **gone**), but all 4 docs report `keep (exists):` and the
  hand-edit to `SPEC.md` **survives**. Force governs agents only.

---

## D. Hook behavior / flags

### TS-9 — `--no-hooks` / `-NoHooks` 🔲
- **Preconditions:** empty git repo.
- **Steps:**
  ```sh
  bash "$PACK/install-agents.sh" --no-hooks "$T"
  ```
  ```powershell
  & "$PACK\install-agents.ps1" -TargetRoot $T -NoHooks
  ```
- **Expected:** `hooks: skipped (--no-hooks)` / `(-NoHooks)`; docs + agents still
  installed; **no** `.githooks/` dir, **no** `.gitattributes` rule added,
  `core.hooksPath` unset.

### TS-10 — Hook gating + exemptions ✅
- **Preconditions:** TS-1 install in a git repo (hook active).
- **Steps:** attempt commits with various subjects.
- **Expected:**
  - `git commit -m "wip"` → **rejected**, exit ≠ 0, prints `commit-msg REJECTED:
    subject line must start with a ticket key.`
  - `git commit -m "SR-1 do a thing"` → **accepted**.
  - Subjects starting `Merge `, `Revert `, `fixup! `, `squash! ` → **exempt**
    (accepted). Verify offline: `printf 'Merge x\n' > m; sh .githooks/commit-msg m;
    echo $?` → `0`.

### TS-11 — `autocrlf=true` hook stays LF (SR-20 regression guard) ✅
> Permanent guard for the SR-20 bug: bash `cp` shipped a CRLF hook that breaks
> under `sh` on Linux. The installer now normalizes to LF.
- **Preconditions:** `git init` then `git config core.autocrlf true`.
- **Steps:**
  ```sh
  cp -R "$PACK" "$T/agent-pack"; cd "$T"
  bash agent-pack/install-agents.sh
  echo "installed CR bytes: $(crbytes .githooks/commit-msg)"     # expect 0
  git add -A; git commit -q -m "SR-1 scaffold"
  echo "blob CR bytes: $(git show HEAD:.githooks/commit-msg | tr -cd '\r' | wc -c)"  # 0
  rm .githooks/commit-msg; git checkout -- .githooks/commit-msg
  echo "post-checkout CR bytes: $(crbytes .githooks/commit-msg)" # expect 0
  ```
- **Expected:** all three CR-byte counts are **0**, and the re-checked-out hook
  still rejects a non-`SR` subject. (PowerShell path: `CrBytes` of the installed
  hook → `0`.)

---

## E. .gitattributes handling

### TS-12 — `.gitattributes` created ✅
- **Preconditions:** target with **no** `.gitattributes`.
- **Steps:** run the installer.
- **Expected:** `created: .gitattributes (.githooks/** text eol=lf)`; file contains
  exactly that one rule.

### TS-13 — `.gitattributes` appended without clobber ✅
- **Preconditions:** target with an existing `.gitattributes` that has other rules
  and **no trailing newline**, e.g. `printf '*.md text\n*.png binary' > .gitattributes`.
- **Steps:** run the installer.
- **Expected:** `updated: .gitattributes (+ .githooks/** text eol=lf)`; the original
  `*.md text` / `*.png binary` rules are intact and the new rule is on **its own
  line** (not joined to `*.png binary`).

### TS-14 — `.gitattributes` idempotent ✅
- **Preconditions:** `.gitattributes` already contains `.githooks/** text eol=lf`.
- **Steps:** run the installer.
- **Expected:** `.gitattributes: LF rule already present`; the rule appears exactly
  **once** (`grep -cF '.githooks/** text eol=lf'` → `1`).

---

## F. Idempotency / invocation / parity

### TS-15 — Idempotent re-run ✅
- **Preconditions:** any completed install.
- **Steps:** run the same installer a second time on the same target.
- **Expected:** all docs `keep (exists):`, all agents `skip (exists):`, marker pair
  still `1/1`, `.gitattributes: LF rule already present`. Nothing is duplicated and
  no doc/agent content changes.

### TS-16 — Invocation variants equivalent ✅
- **Preconditions:** three fresh targets.
- **Steps:** install three ways: (a) from the target root with default PWD
  (`cd "$T"; bash "$PACK/install-agents.sh"`), (b) explicit path
  (`bash "$PACK/install-agents.sh" "$T"` / `-TargetRoot $T`), (c) copied-in pack
  (`cp -R "$PACK" "$T/agent-pack"; cd "$T"; bash agent-pack/install-agents.sh`).
- **Expected:** all three produce the same tree — 4 docs, 24 agents, marker `1/1`,
  hook + `hooksPath` + `.gitattributes`.

### TS-17 — Cross-platform parity ✅
- **Preconditions:** two fresh identical targets.
- **Steps:** install one with `install-agents.sh`, the other with
  `install-agents.ps1`.
- **Expected:** equivalent results — same doc set, same 24 agent entries, one
  marker pair, `.githooks/commit-msg` present and pure LF, `core.hooksPath =
  .githooks`, same `.gitattributes` rule. (The two scripts are kept mirror-identical
  in behavior.)

### TS-18 — PowerShell 5.1 parses and runs (SR-19 regression guard) ✅
> Permanent guard for the SR-19 bug: em-dashes in a BOM-less `.ps1` broke Windows
> PowerShell 5.1's parser. The script must stay ASCII / BOM-safe.
- **Preconditions:** Windows PowerShell 5.1 (`powershell.exe`).
- **Steps:** `& "$PACK\install-agents.ps1" -TargetRoot (New-Tgt)`; also
  `Select-String -Path "$PACK\install-agents.ps1" -Pattern '[^\x00-\x7F]'`.
- **Expected:** the install runs to `Done.` with **no** `ParserError` /
  `missing terminator`; the non-ASCII scan returns **no matches** (the `.ps1` is
  pure ASCII).

---

## G. Error / edge

### TS-19 — Corrupt/missing payload errors safely 🔲
- **Preconditions:** a copy of the pack with `payload/agents/` renamed away.
- **Steps:** run the installer.
- **Expected:** exits **non-zero** with `ERROR: bundled payload not found at …`
  and makes **no** changes to the target (no docs scaffolded, no `.claude/agents/`,
  no hook).

---

## H. New-project mode (`--new` / `-New`)

### TS-20 — `--new`/`-New` git-inits and auto-enables the hook 🔲
> The brand-new-project counterpart to TS-2: with `--new`/`-New`, the installer
> runs `git init` up front so step 4 detects a repo and enables `core.hooksPath`
> automatically — no manual `git init` + `git config` step.
- **Preconditions:** empty directory, **no** `git init` (the installer does it).
- **Steps:**
  ```sh
  T=$(newtgt)
  bash "$PACK/install-agents.sh" --new "$T"
  git -C "$T" config --get core.hooksPath        # expect .githooks
  (cd "$T" && git add -A && git commit -q -m "wip"); echo "exit: $?"   # expect non-zero
  ```
  ```powershell
  $T = New-Tgt
  & "$PACK\install-agents.ps1" -New -TargetRoot $T
  git -C $T config --get core.hooksPath          # expect .githooks
  ```
- **Expected:** console shows `git: initialized empty repo` **and**
  `git: core.hooksPath = .githooks` (the TS-2 "not a git repo" hint is **absent**);
  4 docs + 24 agent entries installed; `core.hooksPath` = `.githooks`; a non-`SR`
  commit is **rejected** while `SR-1 x` is accepted (ties into TS-10). Re-running
  with `--new`/`-New` on the now-initialized dir prints
  `git: already a repo (skipping init)` and changes nothing (no-op init).

---

## Notes

- **Cleanup:** every scenario uses a throwaway dir; delete it when done.
- **Traceability:** TS-11 (SR-20) and TS-18 (SR-19) are regression guards for real
  bugs — keep them ✅ and re-run both after any installer change.
- **When behavior changes on purpose:** update the affected TS ticket's *Expected*
  block in the same change that alters the installer (both installers stay in sync).

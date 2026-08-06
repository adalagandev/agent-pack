# BUG.md — Backlog (agent-pack itself)

Tracked work and defects as `AP-<n>` tickets for **this pack's own development**.
Every commit's subject must start with the `AP-<n>` key of the ticket it advances —
enforced by `.githooks/commit-msg`.

> **Prefix history.** `AP` is for *agent-pack*. The pack was extracted from a
> student-registration project whose tickets were keyed `SR-`, and that prefix
> came along with it. `AP-1`…`AP-13` were renumbered from `SR-` in AP-14. `SR-0`
> keeps its key because it is already committed history, and the `SR-19` / `SR-20`
> references in `TEST.md` are origin-project bug IDs that name real regressions.

> **The two hooks now differ.** `.githooks/commit-msg` (this repo, `AP-`) and
> `payload/hooks/commit-msg` (installed into *target* projects, still `SR-`) were
> byte-identical until AP-14 and no longer are. Shipping a hardcoded `SR-` to
> unrelated projects is origin-project leakage — it belongs to AP-7, which will
> make the prefix configurable per target. Until then the pack dogfoods the
> *workflow* but not the literal hook file.

> Not to be confused with `payload/templates/BUG.md`, which is the empty backlog
> scaffolded into *target* projects. This file is never installed anywhere.

The `A<n>` / `B<n>` identifiers below refer to items in `TESTING-IMPROVEMENTS.pdf`
(4 Aug 2026).

## Status legend

🔲 Open · 🚧 In progress · ✅ Fixed / Done

## Tickets

| Ticket | Summary | Component | Difficulty | Status |
|--------|---------|-----------|------------|--------|
| SR-0 | Import agent-pack v1.0.0 under version control | repo | S | ✅ Done |
| AP-1 | A3 — unit-test the commit hook as a pure function | hook | S | 🔲 Open |
| AP-2 | A2 — express installer parity as a golden-tree diff | tests | M | 🔲 Open |
| AP-3 | A1 — make the TS-\<n\> catalog executable | tests | L | 🔲 Open |
| AP-4 | A5 — close the 8 open scenarios by blast radius | tests | L | 🔲 Open |
| AP-5 | B2 — add integration-warden for the unowned test tier | agents | L | 🔲 Open |
| AP-6 | B3 — move the curl document to controller-warden | agents | S | 🔲 Open |
| AP-7 | B4 — strip origin-project details from the payload | agents | M | 🔲 Open |
| AP-8 | B5 — add React/TypeScript testing examples | agents | M | 🔲 Open |
| AP-9 | B6 — cross-cutting "changes ship with tests" rule | agents | S | 🔲 Open |
| AP-10 | A4 — derive baseline counts instead of hardcoding them | tests | S | 🔲 Open |
| AP-11 | A6 — add the negative path cases nobody wrote down | tests | M | 🔲 Open |
| AP-12 | A7 — run the suite in CI across both platforms | ci | S | 🔲 Open |
| AP-13 | Update the pack's own docs and cut v1.1.0 | docs | S | 🔲 Open |
| AP-14 | Adopt the `AP-` ticket prefix for this pack | repo | S | ✅ Done |

---

### SR-0 — Import agent-pack v1.0.0 under version control

- **Type:** chore
- **Priority:** high
- **Component:** repo
- **Status:** ✅ Done
- **Description:** The pack shipped a commit-message workflow while not being a
  git repository itself. Initialize the repo, add this backlog, and enable the
  pack's own `SR-<n>` hook on itself.
- **Acceptance:** `git log` exists; `core.hooksPath` is `.githooks`; a non-`SR`
  commit is rejected in this repo.

### AP-1 — A3: unit-test the commit hook as a pure function

- **Type:** test
- **Priority:** high
- **Component:** hook
- **Status:** 🔲 Open
- **Description:** the commit hook is stdin-file → exit code: no git needed,
  milliseconds to run, table-driven. TS-10 covers only the happy path and four
  exempt prefixes. Unguarded, stated prefix-neutrally (`<KEY>` is `AP` for
  `.githooks/commit-msg`, `SR` for `payload/hooks/commit-msg`): lowercase
  `<key>-1`, `<KEY>-` with no digits, key with no description, leading
  whitespace, empty/all-comment message, subject on line 2, a body line that
  looks like `<KEY>-1`, UTF-8 BOM, CRLF.
- **Acceptance:** a table-driven case file covers every row; both hooks are run
  against the same table with only the prefix parameterized, so the AP-14
  divergence cannot hide a fix applied to one and not the other; the hooks are
  fixed where the pinned behavior is wrong (whitespace trim, BOM strip, CR strip).

### AP-2 — A2: express installer parity as a golden-tree diff

- **Type:** test
- **Priority:** high
- **Component:** tests
- **Status:** 🔲 Open
- **Description:** TS-17 is the scenario most likely to rot silently — two
  implementations of the same logic in two languages always drift. Install with
  each script into two fresh directories, normalize line endings, `diff -r` the
  trees. Buys the whole surface in one test instead of enumerating what to compare.
- **Acceptance:** the diff is empty for a default install and for `-Force` over an
  existing install; any divergence found is fixed in both scripts.

### AP-3 — A1: make the TS-\<n\> catalog executable

- **Type:** test
- **Priority:** high
- **Component:** tests
- **Status:** 🔲 Open
- **Description:** `TEST.md` is already written as preconditions → exact commands →
  concrete expected result. Add `tests/` with an assert helper, one temp directory
  per case, and teardown. `TEST.md` stays the human-readable catalog, with each
  scenario naming its automated counterpart so the two cannot drift.
- **Acceptance:** `bash tests/run.sh` runs every scenario; failures are legible;
  no case leaks a temp directory.

### AP-4 — A5: close the 8 open scenarios by blast radius

- **Type:** test
- **Priority:** high
- **Component:** tests
- **Status:** 🔲 Open
- **Description:** Sequencing by number treats a data-loss bug and a console-message
  nit as equals. Order: TS-8 (`-Force` must never touch docs — a regression destroys
  a hand-written `SPEC.md`), then TS-2/TS-20 (silent failure: hook copied but not
  enabled), TS-19 (corrupt payload leaves a half-installed target), then TS-4/5/7,
  then TS-9.
- **Acceptance:** all 20 scenarios automated and green; statuses in `TEST.md`
  flipped only once the script passes.

### AP-5 — B2: add integration-warden for the unowned test tier

- **Type:** feature
- **Priority:** high
- **Component:** agents
- **Status:** 🔲 Open
- **Description:** `test-warden`'s negative scope disclaims integration, e2e, and
  contract tests and no other warden picks them up, yet the routing table claims
  "unit and integration tests → test-warden". A separate agent rather than a broader
  one: test-warden rule 4 forbids real network/filesystem/database and rule 8 forbids
  framework boot — exactly what an integration test does.
- **Acceptance:** `integration-warden.md` + java/python refs ship; routing table
  splits the two tiers; test-warden names the handoff target.

### AP-6 — B3: move the curl document to controller-warden

- **Type:** chore
- **Priority:** medium
- **Component:** agents
- **Status:** 🔲 Open
- **Description:** The obligation lives in `test-warden.md` but triggers only when
  tests change. When controller-warden adds an endpoint and no test changes, the
  document silently goes stale — despite the section insisting completeness is the
  entire point. Give it to the agent that authors the routes.
- **Acceptance:** the section lives in `controller-warden.md`, keyed to route
  changes; test-warden keeps a pointer.

### AP-7 — B4: strip origin-project details from the payload

- **Type:** chore
- **Priority:** medium
- **Component:** agents
- **Status:** 🔲 Open
- **Description:** `http://localhost:5000/api`, `backend-java/.../web`, and Flask
  `@app.route` examples are hardcoded in a pack that advertises framework-agnostic
  rules. Make them values the agent reads from the conventions section of `CLAUDE.md`.
  Three more leaks found while doing AP-14, all of them the student-registration
  origin showing through:
  - `payload/hooks/commit-msg` hardcodes the `SR-` prefix, so every project that
    installs the pack inherits another project's ticket convention. This is the
    load-bearing one — the prefix is baked into the regex, the rejection message,
    the installers, `templates/*`, and `ticket-warden.md`.
  - `ticket-warden.md` tells the agent to match "the pattern already used by
    SR-101/SR-102" and gives `SR-104-fix-email-save` as the branch example. Those
    tickets exist only in the origin repo, so a target project is told to imitate
    a backlog it has never had.
  - `TEST.md` cites SR-19/SR-20 as regression-guard bug IDs. These are *fine* —
    they name real historical bugs — but should be labeled as origin-project IDs
    so nobody reads them as pack tickets.
- **Acceptance:** no origin-specific path or port outside clearly-labeled example
  blocks; `templates/CLAUDE.md` has a defined place for the answers; the ticket
  prefix is a value the installer sets per target project rather than a literal
  in the shipped hook; no dangling reference to a ticket that exists only in the
  origin repo.

### AP-8 — B5: add React/TypeScript testing examples

- **Type:** feature
- **Priority:** medium
- **Component:** agents
- **Status:** 🔲 Open
- **Description:** `test-warden-refs/` ships Python and Java; `frontend-warden`
  ships React. A React project therefore receives frontend code rules with no
  frontend testing examples — no React Testing Library, no guidance on querying by
  role over test-id.
- **Acceptance:** a React examples file covering the same numbered rules, registered
  in test-warden's companion-file list.

### AP-9 — B6: cross-cutting "changes ship with tests" rule

- **Type:** chore
- **Priority:** medium
- **Component:** agents
- **Status:** 🔲 Open
- **Description:** security-warden, api-client-warden, and exception-warden author
  highly testable contracts — authorization decisions, retry/timeout/circuit-breaker
  behavior, status-code mapping — yet nothing obligates tests when they write code.
  The routing map splits work by layer; this obligation needs to cut across it.
- **Acceptance:** a Testing obligation subsection inside the installer-managed
  `CLAUDE.md` block, naming which tier applies and who to hand off to.

### AP-10 — A4: derive baseline counts instead of hardcoding them

- **Type:** test
- **Priority:** medium
- **Component:** tests
- **Status:** 🔲 Open
- **Description:** "4 docs, 24 entries, 1 marker pair" is prose in `TEST.md`. Adding
  a 14th warden makes every count silently wrong. Assert
  `count(.claude/agents) == count(payload/agents)` instead, and assert the routing
  table names exactly the installed wardens with an explicit allowlist for
  deliberate omissions (`ticket-warden` is intentionally unrouted).
- **Acceptance:** no hardcoded count in the harness; a warden added without a
  routing entry turns a test red.

### AP-11 — A6: add the negative path cases nobody wrote down

- **Type:** test
- **Priority:** medium
- **Component:** tests
- **Status:** 🔲 Open
- **Description:** Target path with spaces or non-ASCII characters (a classic
  PowerShell quoting failure), read-only target, target identical to the pack
  directory, deeply nested path. Precisely where cross-platform installers break,
  and none are currently represented.
- **Acceptance:** TS-21…TS-24 exist in `TEST.md` and the harness; whatever they
  expose is fixed in both installers.

### AP-12 — A7: run the suite in CI across both platforms

- **Type:** chore
- **Priority:** medium
- **Component:** ci
- **Status:** 🔲 Open
- **Description:** A GitHub Actions matrix on `ubuntu-latest` and `windows-latest`
  makes "untested by hand" structurally impossible rather than a discipline problem.
- **Acceptance:** the workflow runs `tests/run.sh` on push and PR and is green on
  both platforms.

### AP-13 — Update the pack's own docs and cut v1.1.0

- **Type:** docs
- **Priority:** low
- **Component:** docs
- **Status:** 🔲 Open
- **Description:** `README.md` still describes 13 wardens and a hand-run test
  strategy. Reflect the new warden, the `tests/` harness, and CI; bump `VERSION`.
- **Acceptance:** README matches the tree; `VERSION` is `1.1.0`.

### AP-14 — Adopt the `AP-` ticket prefix for this pack

- **Type:** chore
- **Priority:** high
- **Component:** repo
- **Status:** ✅ Done
- **Description:** the pack's own tickets were keyed `SR-`, inherited from the
  student-registration project it was extracted from. `AP` is for *agent-pack*.
  Renumber the 13 open tickets to `AP-1`…`AP-13` and switch
  `.githooks/commit-msg` to enforce `AP-` only. Deliberately **not** changed:
  `SR-0` (already committed history), the `SR-19`/`SR-20` origin bug IDs in
  `TEST.md`, and everything under `payload/` — the shipped hook keeps `SR-` until
  AP-7 makes it configurable, since `AP-` would be just as wrong for a target
  project as `SR-` is.
- **Acceptance:** `.githooks/commit-msg` accepts `AP-<n> x` and rejects
  `SR-<n> x`; no `SR-<digits>` left in `BUG.md` except `SR-0`; `payload/` is
  untouched; the divergence between the two hooks is written down.
- **Fixed on branch:** master (direct, no branch — repo bootstrap era)
- **Fixed at:** 2026-08-06

<!-- Add new tickets by appending a table row above and a matching section here.
     On completion, flip the status to ✅ and record:
       - **Fixed on branch:** AP-<n>-<desc>
       - **Fixed at:** <timestamp>
-->

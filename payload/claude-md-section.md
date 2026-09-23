## Agent-driven development

This project uses a set of specialist **`-warden`** subagents (in
`.claude/agents/`). Feature and change work is delegated to the warden that owns
the domain — that agent **writes** the code; the main agent coordinates and
handles anything outside these domains. Invoke them proactively when a prompt
lands in their domain, not only for after-the-fact review.

- Service / business-logic classes (use-cases, DI, transactions, DTO/domain mapping) → **service-warden**
- Persistence / data-access layer (ORM entities, repositories/DAOs, queries, schema/migration) → **persistence-warden**
- API controllers / routers / endpoint handlers (routes, status codes, request/response DTOs, endpoint validation) → **controller-warden**
- API error/exception handling, status-code mapping, validation errors → **exception-warden**
- Frontend UI (components, state, the API-call seam, token-driven styling) → **frontend-warden**
- Access control, input validation at trust boundaries, secret handling, OWASP defenses (injection, XSS, CSRF) → **security-warden**
- Outbound integrations / HTTP clients (timeouts, retries with backoff, circuit breakers, response validation) → **api-client-warden**
- Logging, metrics, and tracing (structured logs, no PII, correlation ids, log levels, instrumentation) → **observability-warden**
- Application configuration (environment-driven values, no hardcoded URLs/ports/credentials, startup validation, safe defaults) → **config-warden**
- Unit and integration tests → **test-warden**
- Package/directory structure across the backend and frontend roots (where files live, module layout, scaffolding a new project/module, relocating misplaced files, cross-layer import boundaries) → **structure-warden**
- The project's own governing docs — keeping `SPEC.md` (what the app does), `CLAUDE.md` (how work is organized + project conventions + this routing table), and `BUG.md` (the backlog, if present) consistent and non-overlapping → **sync-warden**

A feature that spans domains is split so each agent authors its own layer. When
a change needs new files or a new module, **structure-warden** decides and
creates *where* they live; the owning domain warden authors *what* goes inside.

> The rules in each agent file are language/framework-agnostic; the paths and
> framework names in their examples are illustrative only. Agents take this
> project's real locations (source roots, API module, route definitions, local
> API base URL) from a **Project layout** section in this file, and detect them
> from the codebase — stating the assumption — when that section is absent.

### Authorship stamp

Every class or function an agent authors or substantially rewrites carries an
authorship tag on the line directly above its declaration, using the file's
line-comment syntax:

```
// @agent: service-warden      (Java / JS)
# @agent: exception-warden     (Python)
```

Keep the tag on edits; change it only when a different agent takes the code over.

### Keeping the docs in sync

**sync-warden** guards the boundary between `SPEC.md`, `CLAUDE.md`, and (when
present) `BUG.md`: it moves coding rules or process that leak into the spec back
to their proper home, checks that every feature traces to a build milestone (and
a backlog item when one is tracked), and keeps the routing table above matching
the agents actually installed in `.claude/agents/`. It edits the documents, never
the code, and skips `BUG.md` checks when there is no backlog. Invoke it after
editing any of those files.

### Ticket workflow

**ticket-warden** enforces a ticket-driven commit workflow, and the installer
wires it up: tickets are `__TICKET_PREFIX__-<n>` entries in `BUG.md`, and a `.githooks/commit-msg`
hook is installed with git pointed at it (`core.hooksPath = .githooks`). The hook
is **prefix-only** — it rejects any commit whose subject line is not
`__TICKET_PREFIX__-<n> <description>` (merge/revert/fixup!/squash! subjects are exempt) and does
not police the branch, so committing on `main` is allowed. ticket-warden is the
smart layer that makes the right ticket exist so commits pass.

**Ticket key: `__TICKET_PREFIX__`.** Agent files write it generically as `<KEY>`. To
change it, re-run the agent-pack installer with `--prefix <KEY>` / `-Prefix <KEY>`,
which rewrites both the hook and this section.

`core.hooksPath` lives in the local `.git/config`, which is not cloned, so each
fresh clone must enable the hook once with `git config core.hooksPath .githooks`.
(Run the installer with `-NoHooks` / `--no-hooks` to skip hook setup.)

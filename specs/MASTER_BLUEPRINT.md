# Master Architecture Blueprint — AI Project Kit

> **Status:** Draft
> **Last Updated:** 2026-05-08
> **Project:** AI Project Kit (`korallis/workflow`)
> **Maintainer:** Lee Barry

This blueprint documents the kit *itself* — a Claude Code workflow toolkit, not a product application. The standard product-blueprint sections (data model, API design, deployment infra) are adapted to the kit's actual surface area: shell scripts, markdown skills, slash commands, hooks, and the dual-harness execution model.

---

## 1. Project Overview

**Problem Statement.** Ad-hoc Claude Code sessions drift: scope expands, patterns are reinvented every session, learnings evaporate when the context window compacts, and there is no enforced separation between planning and implementation. Heavy implementation also competes with Claude's planning context for tokens.

**Solution Overview.** A single idempotent `bootstrap.sh` installs an opinionated operating model into any project: eleven slash commands that enforce a `plan → research → execute → verify → capture` workflow, a dual-harness mode that hands implementation to Codex CLI inside a live tmux pane while Claude orchestrates, isolated subagent reviews for security and code quality, and PreCompact snapshots so context survives compaction.

**Success Criteria.**
- One command (`bash bootstrap.sh`) brings the full system online, idempotently, on greenfield or brownfield repos.
- A user can go from "build me X" to a complete spec tree (blueprint, module specs, roadmap) without writing code, then implement modules against frozen specs.
- Compound learning: every session updates `LEARNINGS.md` and `CLAUDE.md`, so the next session inherits prior patterns.
- Dual-harness execution survives tmux/auth/concurrency failure modes (preflight, locking, sentinel-based pane teardown).

**Scope Boundaries.**
- *In scope:* slash commands, skills, templates, dispatcher, hooks, settings.
- *Out of scope:* hosting any service, shipping a UI, providing model inference. The kit is files-only.

---

## 2. Tech Stack

The kit is intentionally minimal — no build system, no package manager, no runtime dependencies beyond Bash and the Claude Code harness.

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Harness (primary) | Claude Code | current | Targets Opus 4.7 (1M); skills + slash commands + hooks are first-class. |
| Harness (executor) | Codex CLI | 0.128+ | `gpt-5.5` medium effort for heavy implementation; ChatGPT or API auth. |
| Shell | Bash | POSIX-compatible | Bootstrap + dispatcher; no fish/zsh-specific syntax. |
| Multiplexer | tmux | any modern | Live execution pane; `list-clients` used to find attached session. |
| Coreutils | GNU `timeout` | — | Linux native; macOS via `brew install coreutils` (`gtimeout`). |
| Skill format | Markdown + frontmatter | — | `name`, `description`, `effort` (Claude-Code extension; ignored by other harnesses). |
| Snapshot storage | Plain markdown | — | `specs/sessions/<TS>-{plan,transcript-tail,git}.md`, `chmod 600`. |
| Version control | Git + GitHub | — | PR-based review loop; CodeRabbit on PRs. |

**Version strategy.** `main` is the rolling release. Users pin via release tag in the curl URL (`/v0.1.0/`) when they want reproducibility; verify against published checksum.

**Constraints.**
- No Node, Python, or other runtime installs. Everything must run from a clean machine with Bash + Claude Code + tmux + Codex CLI.
- Idempotent: re-running `bootstrap.sh` must never overwrite user content.
- Portable across Linux and macOS (no `flock`, no Bash 4-only features unless guarded).

---

## 3. Artefact Model

The kit's "data model" is its on-disk artefacts. These are the entities every skill reads or writes.

```
your-project/
├── CLAUDE.md                       Operating model (read on every prompt)
├── LEARNINGS.md                    Compound learning store
├── .claude/
│   ├── settings.json               Hooks + permissions
│   ├── commands/<name>.md          Thin slash-command wrappers (11)
│   ├── skills/<name>/SKILL.md      Skill instructions + bundled templates (11)
│   ├── lib/dispatch.sh             Codex dispatcher
│   ├── lib/scrub-secrets.sh        Read-path log redactor
│   └── hooks/pre-compact.sh        PreCompact snapshotter
├── specs/
│   ├── PROJECT_BRIEF.md            Vision + constraints (from /project-init)
│   ├── RESEARCH.md                 Domain + tech research
│   ├── MASTER_BLUEPRINT.md         This file (architecture source of truth)
│   ├── MODULES.md                  Module decomposition
│   ├── ROADMAP.md                  Implementation order
│   ├── modules/<name>/SPEC.md      What to build
│   ├── modules/<name>/CLAUDE.md    How to build it in this project
│   └── sessions/<TS>-*.md          PreCompact snapshots (gitignored, 0600)
└── .kit-orchestration/             Plan/validation/execution artefacts (logs gitignored)
```

**Key invariants.**
- `CLAUDE.md` and `LEARNINGS.md` are the only two files Claude *always* reads. Everything else is loaded on demand by skills.
- `specs/MASTER_BLUEPRINT.md` is the architecture source of truth. Module specs reference it; they don't duplicate it.
- `specs/sessions/` is `chmod 700`, snapshots are `chmod 600`, both gitignored. Treated as ephemeral runtime state.
- `.kit-orchestration/` holds dispatch logs and per-PR plans; logs are gitignored, plans are committable.

**Lifecycle.** Specs are written once at init (`/project-init`) and updated when implementation reveals gaps. Sessions and orchestration artefacts churn freely. Learnings accrete monotonically.

---

## 4. Skill / Command Surface

Eleven slash commands, each backed by a skill of the same name. Commands are thin wrappers; the skill is where the work lives.

| Command | Phase | Purpose |
|---|---|---|
| `/project-init [idea]` | Plan | Full spec-first init: research → blueprint → module specs → roadmap. No code. |
| `/project-research [topic]` | Research | Deep research; saved under `specs/research/`. |
| `/project-blueprint` | Plan | Generate or regenerate this document. |
| `/project-spec [module]` | Plan | Per-module spec (data, API, UI, business logic). |
| `/project-module [name]` | Execute | Single-harness implementation in this Claude session. |
| `/project-execute [name]` | Execute | Dual-harness: Claude plans, Codex CLI implements in tmux pane. |
| `/project-tracks plan\|start\|...` | Execute | Parallel module implementation across isolated git worktrees; each track is one dispatcher invocation under `KIT_PARALLEL_TRACK`. See `specs/modules/parallel-tracks/SPEC.md`. |
| `/project-review [--isolate]` | Capture | Session learnings → `LEARNINGS.md`/`CLAUDE.md`; `--isolate` adds Explore-agent code review. |
| `/project-security-review` | Verify | Isolated Explore subagent against UK GDPR / healthcare / OWASP checklist. |
| `/project-status` | — | Dashboard of specs, implementations, next steps. |
| `/project-test` | Verify | Unit + type + lint + visual. |
| `/project-deploy` | Verify | Pre-deploy checks → deploy → browser-automated verification. |

**Skill frontmatter.** Skills use `name`, `description`, and (for heavy ones) `effort: high|medium|low|max` — a Claude-Code extension. Other harnesses silently ignore unknown frontmatter, so portability is preserved by omission.

**Heavy-effort skills.** `project-init`, `project-blueprint`, `project-execute`, `project-tracks`, `project-security-review`.

---

## 5. Dual-Harness Execution Contract

`/project-execute` is the kit's architectural centrepiece. The contract between Claude (planner/reviewer) and Codex (implementer) is mediated by `.claude/lib/dispatch.sh`.

```text
Claude (Opus 4.7)                       Codex (gpt-5.5, medium effort)
─────────────────                       ──────────────────────────────
read SPEC.md, blueprint, CLAUDE.md
build dispatch prompt
            │
            ▼
   .claude/lib/dispatch.sh
   ├─ auth + model preflight (timeout: KIT_AUTH_PREFLIGHT_SECONDS, default 15s)
   ├─ single-flight lock (mkdir-based; KIT_ALLOW_CONCURRENT=1 to bypass)
   ├─ tmux split into attached client (list-clients heuristic)
   │  └─ tail -f log streaming into pane
   ├─ codex exec gpt-5.5 medium (prompt via stdin, real exit code preserved)
   └─ sentinel write → pane auto-closes
            │
            ▼
read scrubbed log → summarise → run review skill
```

**Dispatcher invariants.**
- **Self-relocation.** dispatch.sh copies itself to a `mktemp` path and re-execs before doing any work. Live edits to `.claude/lib/dispatch.sh` during a run (e.g. when the run modifies the kit itself) cannot cause bash to re-read garbled offsets at trap time. Idempotent via `KIT_DISPATCH_RELOCATED`; `KIT_DISPATCH_REPO_ROOT` carries repo location across exec.
- **Deterministic timestamps.** When the orchestrator computes a `$TS` and advertises paths derived from it, it must export `KIT_DISPATCH_TS=$TS` so the dispatcher reuses the same token. Without this the advertised `.jsonl`/`-report.json`/`.log` paths drift.
- **Preflight gates execution.** Auth + model availability checked with hard timeout before launch — fast failure beats hung pane.
- **Single-flight by default.** mkdir-based lock (portable, no `flock` dependency). Concurrent runs require `KIT_ALLOW_CONCURRENT=1`.
- **Pane discovery is `list-clients`-based.** Splits into the user's *attached* session, not a detached one. This is non-negotiable — see `feedback_tmux_split_user_session.md`. Override with `KIT_TMUX_SESSION=<name>` for multi-session setups.
- **Inline fallback.** When no tmux client is attached or `KIT_NO_TMUX=1`, output streams inline in Claude's transcript.
- **Sentinel teardown.** Dispatcher writes a unique sentinel on completion; the pane closes itself. No manual cleanup, no leaked panes.
- **Hard timeout.** `KIT_CODEX_TIMEOUT` (default 1800s) bounds execution.
- **Read-path scrubbing.** `scrub-secrets.sh` redacts before Claude reads the log back — defence in depth even though Codex shouldn't be writing secrets.
- **Structured executor reports.** Codex is invoked with `--json --output-schema codex-report-schema.json --output-last-message <report.json>`. The JSONL stream goes to a `.jsonl` file (machine-readable) and through a `jq` pretty-printer into the `.log` file (human pane). The final agent message is a JSON object validated against the schema; this catches training-data bleed-through structurally. Codex does NOT commit (orchestrator-commits canonical).
- **Track-scoped execution.** When `KIT_PARALLEL_TRACK=<module>` is set, the lock dir resolves to `.claude/parallel/locks/<module>/` (per-track namespace, not the global lock); log dir to `.kit-orchestration/tracks/<TS>-<module>/`; sentinel filename includes the track id; pane title is prefixed with `[track:<module>]`; tmux split direction defaults to `vertical` (denser dashboard). Non-track invocations are byte-identical to legacy behaviour. Do NOT set `KIT_ALLOW_CONCURRENT=1` together with `KIT_PARALLEL_TRACK` for the same module — the per-track lock provides the right granularity, and disabling it lets a second launch race in the same worktree.

**Env knobs.** `KIT_TMUX_SESSION`, `KIT_TMUX_SPLIT` (`h`/`v`), `KIT_NO_TMUX`, `KIT_CODEX_TIMEOUT`, `KIT_AUTH_PREFLIGHT_SECONDS`, `KIT_ALLOW_CONCURRENT`, `KIT_CODEX_SANDBOX` (default `workspace-write`), `KIT_DISPATCH_TS` (orchestrator-supplied timestamp), `KIT_PARALLEL_TRACK`, `KIT_PARALLEL_PORT`, `KIT_PARALLEL_PORT_BASE`, `KIT_PARALLEL_MAX` (default 4).

---

## 6. Isolation Pattern (Reviews)

Both `/project-security-review` and `/project-review --isolate` use the same architectural pattern: spawn a read-only **Explore** subagent with the diff and a checklist; merge findings into the parent session's output.

**Why isolation matters.** A reviewer who participated in implementation validates the assumptions that drove the implementation. An Explore subagent reading only the diff against an explicit checklist has different blind spots — which is the entire point of review.

**Subagent constraints.**
- Fresh context window. No exposure to planning or implementation discussion.
- No edit/write tools. Read-only by default; cannot modify the working tree.
- Bounded scope. Reviews only what was changed, against an explicit checklist.

**Checklist coverage (`project-security-review`).** Authentication, authorisation, input/output handling, CSRF, SSRF, webhook signatures, file uploads, client-bundle secret hygiene, GDPR PII persistence, audit logging, healthcare-domain compliance, dependency posture, operational hygiene.

**`/project-review --isolate`** is the lighter cousin — an unbiased code-quality pass over the diff. Session-learnings capture stays in the parent context because that work needs parent-session memory.

---

## 7. Compaction Survival (Hooks)

Claude Code conversations get compacted once they approach the context limit. Without intervention, plan + transcript context is lost.

`.claude/hooks/pre-compact.sh` fires before compaction and writes three companion snapshots to `specs/sessions/`:

- `<TS>-plan.md` — copy of the most recent `.kit-orchestration/pr*-plan.md`.
- `<TS>-transcript-tail.md` — last 50 events from the transcript JSONL.
- `<TS>-git.md` — branch, last 10 commits, working-tree status.

**Hardening.**
- `umask 077` + `chmod 600` on each snapshot (defence in depth on shared systems).
- `chmod 700` on `specs/sessions/`.
- Gitignored — snapshots are ephemeral runtime state.

**SessionStart `compact` matcher** prints the latest snapshot path on resume — backup recovery for [Claude Code #13572](https://github.com/anthropics/claude-code/issues/13572) where PreCompact doesn't fire reliably for `/compact` on some versions.

**Hook commands** resolve via `$CLAUDE_PROJECT_DIR` so they work even when the session cwd has changed.

---

## 8. Operating Model

Encoded in `CLAUDE.md`, read on every session.

**The Prime Directive.** One session = one task. Don't start the next until the current one is captured.

**Five-phase sequence (enforced by skills, not optional):**
1. **Plan** — scope, todos, dependencies, assumptions.
2. **Research (if needed)** — Ref + Exa for current docs and patterns.
3. **Execute** — small, testable units; incremental commits.
4. **Verify** — visual + type + tests; acceptance criteria.
5. **Capture** — `LEARNINGS.md` updated; handoff notes left.

**Spec hierarchy.** Blueprint (this file) → Module Spec (`specs/modules/<name>/SPEC.md`) → Code. Each tier is concrete enough to execute without debate. Never skip a tier.

**British English** in user-facing prose.

---

## 9. Security & Compliance

The kit handles no PII itself — but it touches transcripts, logs, and any project it's installed into.

| Concern | Mitigation |
|---|---|
| Secrets in dispatch logs | `scrub-secrets.sh` on read path; logs gitignored. |
| Snapshots on shared systems | `umask 077`, `chmod 600` snapshots, `chmod 700` directory. |
| Codex sandbox escape | `KIT_CODEX_SANDBOX=workspace-write` by default; user can tighten. |
| Concurrent dispatch corruption | mkdir-based single-flight lock; explicit opt-in to bypass. |
| Hung executor | Hard `KIT_CODEX_TIMEOUT` (default 1800s); preflight timeout (default 15s). |
| Reviewer-implementer collusion | Isolated Explore subagents for security + optional code review. |
| Supply-chain integrity | `bootstrap.sh` curl-pin to a release tag with checksum verification. |

**Out of scope.** Authentication, encryption-at-rest, audit logging — these are concerns of *projects built with the kit*, not of the kit itself. The kit's `project-security-review` skill covers them for downstream projects.

---

## 10. Open Questions

1. **Bootstrap signing.** Should `bootstrap.sh` be GPG-signed and the README instruct verification? Currently checksum-only.
2. **Skill versioning.** No mechanism to know which skill version produced a given spec. Worth adding a `kit_version:` to skill frontmatter?
3. **Codex CLI compat envelope.** Tested on 0.128. No automated check that future versions remain compatible — preflight could parse `codex --version`.
4. **Brownfield blueprint detection.** `/project-blueprint` on a brownfield repo currently relies on the user prompting; could it auto-detect existing stacks (package.json, pyproject.toml, etc.) and pre-fill?
5. **Cross-platform CI.** No automated test of the bootstrap on macOS vs Linux. Manual only.

---

## 11. References

- `README.md` — user-facing kit documentation.
- `CLAUDE.md` — operating model.
- `bootstrap.sh` — installer (4,856 lines as of 2026-05-08).
- `.claude/lib/dispatch.sh` — Codex dispatcher (195 lines).
- `.claude/hooks/pre-compact.sh` — PreCompact snapshotter (107 lines).
- Boris Cherny — "tell the AI exactly what to build before it starts building" (conceptual foundation).
- Addy Osmani — compound-learning research.
- Claude Code [#13572](https://github.com/anthropics/claude-code/issues/13572) — PreCompact reliability issue motivating SessionStart backup.

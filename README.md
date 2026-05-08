# AI Project Kit

> Spec-first, AI-assisted development for Claude Code. Tell the AI exactly what to build before it starts building — and have a second harness watch over the work.

A single `bootstrap.sh` script that turns any project directory into a structured operating system for Claude Code: eleven slash commands, a dual-harness execution mode that delegates heavy implementation to Codex CLI inside a live tmux pane, automatic context preservation through compaction, and isolated security and code review via fresh-context subagents.

---

## Quick start

```bash
curl -O https://raw.githubusercontent.com/korallis/workflow/main/bootstrap.sh
bash bootstrap.sh
```

Then in Claude Code:

```text
/project-init "your project idea"
```

The kit will research the domain, propose modules, generate a master blueprint, write per-module specifications, and produce a roadmap — all before any code is written.

---

## What you get

- **Eleven slash commands** that enforce a structured `plan → research → execute → verify → capture` workflow for every session.
- **Dual-harness execution** (`/project-execute`) — Claude Code (Opus 4.7) plans and reviews, Codex CLI (`gpt-5.5`) implements inside a tmux pane that splits into your most-recent attached session. Pane auto-closes when Codex finishes.
- **Isolated reviews** — `/project-security-review` and `/project-review --isolate` spawn read-only Explore subagents in fresh context so the reviewer doesn't share the implementer's blind spots.
- **PreCompact snapshot hook** — saves plan, transcript tail, and git state into `specs/sessions/` before Claude Code compacts the conversation, with a SessionStart compact-matcher backup for the cases where PreCompact doesn't fire (Claude Code [#13572](https://github.com/anthropics/claude-code/issues/13572)).
- **Compound learning** — `/project-review` after every session updates `LEARNINGS.md` and `CLAUDE.md` so the next session inherits what worked and avoids what didn't.
- **Idempotent bootstrap** — re-run `bootstrap.sh` on any project (greenfield or brownfield) without losing existing files.

---

## The eleven slash commands

| Command | Purpose |
|---|---|
| `/project-init [idea]` | Full spec-first init: research → blueprint → module specs → roadmap. No code. |
| `/project-research [topic]` | Deep research on domain, technology, regulation. |
| `/project-blueprint` | Generate or regenerate the master architecture document. |
| `/project-spec [module]` | Create or update a detailed module specification (data model, API, UI, business logic). |
| `/project-module [module]` | Single-harness implementation: Claude plans and builds in this session. |
| `/project-execute [module]` | Dual-harness implementation: Claude plans, Codex CLI builds in a live tmux pane. |
| `/project-review [--isolate]` | Capture session learnings into `LEARNINGS.md` / `CLAUDE.md`. `--isolate` adds an Explore-agent code-review pass with no parent-context bias. |
| `/project-security-review` | Independent security review via isolated Explore subagent. UK GDPR, healthcare, OWASP-style checklist. |
| `/project-status` | Dashboard: which specs exist, what's been implemented, what's next. |
| `/project-test` | Comprehensive test pass — unit, type, lint, visual. |
| `/project-deploy` | Pre-deploy checks, deploy, verify with browser automation. |

---

## Dual-harness execution

`/project-execute [module]` is the architectural centrepiece. Claude Code is excellent at planning, reviewing, and remembering across sessions; Codex CLI (`gpt-5.5`) is excellent at heavy implementation. The kit runs them together:

```text
You ─► /project-execute auth
       │
       ├─ Claude reads the module spec, blueprint, and CLAUDE.md
       ├─ Claude builds a dispatch prompt
       │
       └─ .claude/lib/dispatch.sh:
              ├─ auth + model preflight (with timeout)
              ├─ single-flight lock (mkdir-based, portable)
              ├─ tmux split into your attached session, tail -f log
              ├─ codex exec gpt-5.5 medium (prompt via stdin, real exit code)
              └─ pane auto-closes on completion (sentinel-based)
       │
       └─ Claude reads the scrubbed log → summarises → runs review skill
```

Output streams live into the pane. When Codex finishes, the dispatcher writes a unique sentinel and the pane closes itself — no manual cleanup. If no tmux client is attached, output streams inline in Claude's transcript instead.

**Prerequisites:**

- `npm install -g @openai/codex` (Codex CLI 0.128+ tested).
- Authenticate: `codex login` (recommended for `gpt-5.5` access without API tier requirements) or `export OPENAI_API_KEY=…` (`gpt-5.5` requires Tier 1+).
- An attached tmux client somewhere on the machine. Easiest: run Claude Code from inside tmux.
- macOS: `brew install coreutils` (provides `gtimeout`, used by the dispatcher).

---

## Isolated reviews

Both `/project-security-review` and `/project-review --isolate` use the same isolation pattern: spawn a read-only Explore subagent with the diff and a checklist, and merge its findings back into the parent session's output.

The Explore subagent:

- Has a fresh context window — no exposure to the planning or implementation discussion.
- Has no edit/write tools by default — it cannot accidentally modify the working tree.
- Reviews only what was actually changed, against an explicit checklist.

This matters because reviewers who participated in implementation tend to validate the assumptions that drove the implementation. An Explore subagent reading the diff alone has different blind spots — exactly what review is for.

`/project-security-review`'s checklist covers authentication, authorisation, input/output handling, CSRF, SSRF, webhook signatures, file uploads, client-bundle secret hygiene, GDPR PII persistence, audit logging, healthcare-domain compliance, dependencies, and operational hygiene.

`/project-review --isolate` is the lighter cousin — an unbiased code-quality pass over the diff. The session-learnings capture (`LEARNINGS.md` / `CLAUDE.md` updates) still happens in the parent context because that work needs parent-session memory.

---

## Hooks

`.claude/hooks/pre-compact.sh` fires before Claude Code compacts the conversation, writing three companion snapshot files into `specs/sessions/`:

- `<TS>-plan.md` — copy of the most recent `.kit-orchestration/pr*-plan.md`.
- `<TS>-transcript-tail.md` — last 50 events from the transcript JSONL.
- `<TS>-git.md` — branch, last 10 commits, working-tree status.

All snapshots are written with `umask 077` and `chmod 600` for defence in depth on shared systems. The `specs/sessions/` directory is `chmod 700`.

`.claude/settings.json` wires the PreCompact hook plus a SessionStart `compact` matcher that prints the latest snapshot path on session resume — a backup recovery path for [#13572](https://github.com/anthropics/claude-code/issues/13572) where PreCompact doesn't fire reliably for `/compact` on some Claude Code versions. Both hooks resolve their commands via `$CLAUDE_PROJECT_DIR` so they work even when the session cwd has changed.

Snapshots are gitignored — they're ephemeral runtime artefacts.

---

## Compound learning

The killer feature, drawn from Boris Cherny's workflow: **every session updates `LEARNINGS.md` and `CLAUDE.md`**. New modules don't repeat old mistakes; system-wide patterns become consistent; complex gotchas are documented for future sessions.

Run `/project-review` at the end of every session (or `/project-review --isolate` for an extra unbiased code-review pass). It captures:

- Patterns that worked, with concrete code references.
- Mistakes made and how they were fixed.
- Stack-specific learnings (e.g. Next.js gotchas, Tailwind quirks).
- Open questions for next session.

Future sessions read these before starting work, so the kit gets sharper with every cycle.

---

## How it works

```text
your-project/
├── CLAUDE.md                       Operating model, read by Claude on every prompt
├── LEARNINGS.md                    Accumulated patterns, mistakes, decisions
├── .claude/
│   ├── settings.json               Hook configuration (PreCompact, SessionStart)
│   ├── commands/                   Thin slash-command wrappers
│   │   ├── project-init.md
│   │   ├── project-execute.md
│   │   └── …
│   ├── skills/                     Skill instructions + bundled templates
│   │   ├── project-init/
│   │   │   ├── SKILL.md
│   │   │   ├── blueprint-template.md
│   │   │   ├── module-spec-template.md
│   │   │   └── claude-module-template.md
│   │   ├── project-execute/
│   │   ├── project-security-review/
│   │   └── …
│   ├── lib/                        Shared infrastructure
│   │   ├── dispatch.sh             Codex dispatcher
│   │   └── scrub-secrets.sh        Read-path log redactor
│   └── hooks/
│       └── pre-compact.sh          Pre-compaction snapshotter
├── specs/
│   ├── MASTER_BLUEPRINT.md         Architecture source of truth
│   ├── ROADMAP.md                  Implementation order
│   ├── modules/[name]/
│   │   ├── SPEC.md                 What to build
│   │   └── CLAUDE.md               How to build it in this project
│   └── sessions/                   PreCompact snapshots (gitignored, 0600)
└── .kit-orchestration/             Plan/validation/execution artefacts
```

Every session follows the same five-phase sequence: **plan → research (if needed) → execute → verify → capture**. The slash commands enforce this — they aren't suggestions.

---

## Skill frontmatter

`effort: high|medium|low|max` is a Claude-Code-extended skill frontmatter field that signals the appropriate reasoning budget for a skill. Applied to:

- `project-init` (heavy planning + research)
- `project-blueprint` (architectural reasoning)
- `project-execute` (orchestration of a downstream agent)
- `project-security-review` (deep checklist review)

Other harnesses silently ignore unknown frontmatter, so this is portable by omission.

---

## Example flow

Day 1, fresh repo, you want to build a CRM:

```bash
$ bash bootstrap.sh
$ claude
> /project-init "CRM for the UK education sector"
```

Claude:

1. Asks up to three clarifying questions (target users, core data, integrations).
2. Researches the domain via Exa (market, competitors, regulations) and Ref (framework docs).
3. Proposes core modules — auth, schools, pupils, parents, billing, comms, reports, settings.
4. Writes `specs/MASTER_BLUEPRINT.md` (stack, data flow, integration points, risk assessment).
5. Writes `specs/modules/[name]/SPEC.md` and `specs/modules/[name]/CLAUDE.md` for each module.
6. Writes `specs/ROADMAP.md` (auth → schools → pupils → …).
7. Stops. No code written.

Day 2 starts with `/project-module auth` (or `/project-execute auth` for dual-harness). Claude knows exactly what to build because the spec is concrete. At the end of the session, run `/project-review` to compound the learnings into the kit for the next module.

---

## Brownfield projects

Run `bash bootstrap.sh` in an existing repository. The script detects existing code, creates `.claude/`, `LEARNINGS.md`, and a stub `CLAUDE.md` for you to fill in with what already exists. Then:

- Run `/project-blueprint` to generate the architecture document retroactively from the existing code.
- Run `/project-spec [module]` for any subsystem you want to spec without disturbing the rest of the codebase.
- Use `/project-module` or `/project-execute` for new feature areas.

The kit is additive on brownfield repos — nothing existing is overwritten.

---

## Sharing the kit

Keep `bootstrap.sh` in your dotfiles or a personal template repository. Run it in any new project to bring the same workflow over. When you discover better patterns, update upstream — every future project inherits the improvement immediately.

---

## Quick reference

| Command | What it does |
|---|---|
| `bash bootstrap.sh` | One-time setup (idempotent on re-runs) |
| `/project-init [idea]` | Full spec-first init |
| `/project-research [topic]` | Deep research, saved under `specs/research/` |
| `/project-blueprint` | Architecture document |
| `/project-spec [module]` | Per-module spec |
| `/project-module [name]` | Single-harness implementation |
| `/project-execute [name]` | Dual-harness implementation (Codex CLI) |
| `/project-review [--isolate]` | Session learnings + optional isolated code review |
| `/project-security-review` | Isolated security review (Explore subagent) |
| `/project-status` | Dashboard |
| `/project-test` | Tests |
| `/project-deploy` | Deploy + verify |

| File | Purpose |
|---|---|
| `CLAUDE.md` | Operating model |
| `LEARNINGS.md` | Accumulated knowledge |
| `specs/MASTER_BLUEPRINT.md` | Architecture |
| `specs/ROADMAP.md` | Implementation order |
| `specs/modules/[x]/SPEC.md` | What to build |
| `specs/modules/[x]/CLAUDE.md` | How to build it in this project |
| `specs/sessions/<TS>-*.md` | PreCompact snapshots (gitignored) |
| `.claude/lib/dispatch.sh` | Codex dispatcher |
| `.claude/lib/scrub-secrets.sh` | Read-path log scrubber |
| `.claude/hooks/pre-compact.sh` | Pre-compaction snapshotter |
| `.claude/settings.json` | Hook configuration |
| `.kit-orchestration/` | Plan/validation/execution artefacts (logs gitignored) |

| Env knob (dispatch.sh) | Effect |
|---|---|
| `KIT_TMUX_SESSION` | Override which tmux session to split into |
| `KIT_TMUX_SPLIT` | `h` (default) or `v` for split direction |
| `KIT_NO_TMUX=1` | Force inline streaming (no tmux pane) |
| `KIT_CODEX_TIMEOUT` | Hard timeout in seconds (default 1800) |
| `KIT_AUTH_PREFLIGHT_SECONDS` | Preflight timeout (default 15) |
| `KIT_ALLOW_CONCURRENT=1` | Bypass single-flight lock |
| `KIT_CODEX_SANDBOX` | Override sandbox mode (default `workspace-write`) |

---

## Operating principles

- **One session, one task.** Don't start a second until the first is captured and ready for handoff.
- **The spec is the source of truth.** Code conforms to the spec, not vice versa. If implementation reveals a gap, update the spec.
- **Commit early, commit often.** `/project-execute` commits Codex's work after every green test on its branch; the user reviews and pushes.
- **Compound learning is the whole point.** Run `/project-review` at the end of every session.
- **British English** in user-facing prose.

---

## Stack neutrality

Slash commands and templates are stack-agnostic. The kit infers your stack from `MASTER_BLUEPRINT.md` and adapts. Tested on Next.js + PostgreSQL + Vercel; designed to work with any modern web/API stack (Python, Go, Rust, Java backends; React/Vue/Svelte/SolidJS frontends).

---

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for a record of shipped changes (Keep-a-Changelog format).

---

**Reference:** Boris Cherny's "tell the AI exactly what to build before it starts building" workflow + Addy Osmani's compound-learning research are the conceptual foundation. The kit makes both automatic.

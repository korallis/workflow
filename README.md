# AI Project Kit — Complete Guide

> Spec-first, AI-assisted development for solo developers and small teams.
> Bootstrap any project so Claude Code knows exactly what to build and how.

---

## What This Is

The AI Project Kit is a single `bootstrap.sh` script you run once in any project directory. It creates a self-contained operating system for Claude Code — a structured set of instructions, slash commands, and spec templates that transforms vague project ideas into researched, architecturally-sound, module-by-module builds.

Instead of typing "build me a CRM" and hoping for the best, you type one command and Claude runs a structured workflow: research the domain, design the architecture, generate hierarchical specs, then implement module by module — committing working code at every step.

The core principle, drawn from Addy Osmani's research and Boris Cherny's workflow (the creator of Claude Code himself): **tell the AI exactly what to build before it starts building**. This kit enforces that principle automatically.

---

## The Problem It Solves

Without structure, AI-assisted development on large projects fails in predictable ways:

- **Context drift** — Claude forgets earlier decisions and contradicts itself across sessions
- **Spec-less execution** — AI generates code that "works" but solves the wrong problem
- **No compound learning** — every session starts from zero; mistakes get repeated
- **Architecture by accident** — modules get built without a shared data model, creating integration nightmares later
- **The 80% wall** — projects get 80% done then stall because the AI has no map of what remains

The kit solves all of these with three files Claude Code reads automatically (`CLAUDE.md`, `LEARNINGS.md`, and module-level `CLAUDE.md` files) and nine slash commands that enforce a structured workflow.

---

## Installation

### Step 1 — Get the script

Download `bootstrap.sh` into your project root (or clone it from your personal template repo):

```bash
curl -O https://raw.githubusercontent.com/korallis/workflow/main/bootstrap.sh
# or just copy it in manually
```

### Step 2 — Run it

```bash
bash bootstrap.sh
```

That's it. The script:
- Detects whether you're in a **greenfield** (new) or **brownfield** (existing code) project
- Creates the full kit structure
- Prints what was created and your first next step

### What Gets Created

```
your-project/
├── CLAUDE.md                        ← Read by Claude Code automatically on every startup
├── LEARNINGS.md                     ← Accumulated project knowledge, grows each session
├── .gitignore                       ← Updated with kit-safe defaults
│
├── .claude/
│   ├── commands/                    ← Slash commands (thin wrappers)
│   │   ├── project-init.md          → /project-init [idea]
│   │   ├── project-research.md      → /project-research [topic]
│   │   ├── project-blueprint.md     → /project-blueprint
│   │   ├── project-spec.md          → /project-spec [module]
│   │   ├── project-module.md        → /project-module [name]
│   │   ├── project-review.md        → /project-review
│   │   ├── project-status.md        → /project-status
│   │   ├── project-deploy.md        → /project-deploy        (NEW)
│   │   └── project-test.md          → /project-test           (NEW)
│   │
│   └── skills/                      ← Skill logic + bundled templates
│       ├── project-init/
│       │   ├── SKILL.md
│       │   ├── blueprint-template.md
│       │   ├── module-spec-template.md
│       │   └── claude-module-template.md
│       ├── project-research/
│       │   └── SKILL.md
│       ├── project-blueprint/
│       │   └── SKILL.md
│       ├── project-spec/
│       │   └── SKILL.md
│       ├── project-module/
│       │   └── SKILL.md
│       ├── project-review/
│       │   └── SKILL.md
│       ├── project-status/
│       │   └── SKILL.md
│       ├── project-deploy/           (NEW)
│       │   └── SKILL.md
│       └── project-test/             (NEW)
│           └── SKILL.md
│
└── specs/                           ← All generated spec documents (commit these)
    ├── RESEARCH.md                  ← Domain research output
    ├── MASTER_BLUEPRINT.md          ← Architecture source of truth
    ├── ROADMAP.md                   ← Implementation order
    └── modules/
        └── [module-name]/
            ├── SPEC.md              ← What this module does
            └── CLAUDE.md            ← How to build it in this project
```

---

## How It Works

### The Operating Model

When Claude Code opens your project, it reads `CLAUDE.md` automatically. This file is the project's operating manual — it tells Claude:

- The prime directive: **never write code before a spec exists**
- How to recognise a vague project idea and what to do with it
- The full research → blueprint → spec → implement → compound workflow
- Session rules (one task per session, plan mode first, commit often)
- The three-tier boundary system (always do / ask first / never do)
- How to detect the tech stack if one hasn't been chosen yet

This means from the moment you open Claude Code, it already knows how to behave — even before you type anything.

### The Workflow

Every project follows this five-phase sequence:

```
1. RESEARCH      Understand the domain, market, users, regulations, competitors
        ↓
2. BLUEPRINT     Define architecture: data model, modules, API patterns, stack
        ↓
3. MODULE SPECS  One detailed spec per feature module (in specs/modules/)
        ↓
4. IMPLEMENT     One module at a time. Spec is source of truth. Commit often.
        ↓
5. COMPOUND      After each module: update LEARNINGS.md and CLAUDE.md
```

The kit enforces this sequence. Claude will refuse to write code until a spec exists, refuse to start a module without reading the blueprint, and always run a review after implementation to compound learnings back into the system.

### Compound Learning

The most powerful feature is that the system gets smarter over time within a project. After every session, `/project-review` adds new entries to `LEARNINGS.md` — mistakes made, patterns that worked, stack-specific discoveries. These get read at the start of every subsequent session, so the same mistake never happens twice.

Boris Cherny (creator of Claude Code) follows this exact pattern: every mistake gets turned into a rule in `CLAUDE.md`. The kit automates this discipline.

---

## Dual-Harness Mode

For big module implementations you can offload execution to Codex CLI while Claude Code orchestrates:

| Mode | Skill | Plan & Review | Execute |
| --- | --- | --- | --- |
| Single-harness | `/project-module [name]` | Claude Code | Claude Code |
| Dual-harness | `/project-execute [name]` | Claude Code | Codex CLI (`gpt-5.5`) |

Dual-harness streams Codex output into a tmux pane that splits into your most-recent attached tmux session, so you see implementation happen live next to your Claude Code window.

**Prerequisites**:

- `npm install -g @openai/codex` (Codex CLI 0.128+ tested).
- Authenticate. Choose one:
  - `codex login` — ChatGPT auth (recommended for `gpt-5.5` access).
  - `export OPENAI_API_KEY=…` — API-key auth. `gpt-5.5` requires Tier 1+ on your OpenAI org; if your tier doesn't include it, the preflight surfaces a model-availability error before opening any panes.
- An attached tmux client. Easiest: launch Claude Code from inside tmux. Also works: have any other terminal attached to a tmux session — dispatch.sh detects via `tmux list-clients`. Without an attached client, output streams inline in Claude's transcript.
- macOS: `brew install coreutils` (provides `gtimeout`, used by the dispatcher).

**How it routes**:

1. Claude validates `$ARGUMENTS` as a kebab-case module name and reads `CLAUDE.md`, `specs/MASTER_BLUEPRINT.md`, `specs/modules/<name>/SPEC.md`, and the module's `CLAUDE.md`. Aborts with actionable instructions if any are missing.
2. Claude writes a dispatch prompt to `.kit-orchestration/exec-<name>-<timestamp>-prompt.md`.
3. `.claude/lib/dispatch.sh` runs an auth + model-availability preflight, acquires a single-flight lock, opens a tmux pane with `tail -f` on the log (or streams inline if no client is attached), then runs `codex exec` as a child process with the prompt piped via stdin.
4. Codex implements the module phase-by-phase, committing on green tests. It does not push.
5. Claude reads `.kit-orchestration/execute-<name>-<timestamp>-last.md` directly and the run log via `bash .claude/lib/scrub-secrets.sh <log>` (so any secrets Codex echoed are redacted before re-entering Claude's context), summarises, and reads `.claude/skills/project-review/SKILL.md` to capture learnings.

The dispatcher is observation-only on tmux — Codex's exit code comes from the real child process, not from `tmux send-keys`. macOS-portable (uses `gtimeout` and `mkdir`-based locks; no `flock` or GNU-only `timeout` dependency).

---

## Tool Integrations

The skills in this kit leverage Claude's MCP (Model Context Protocol) tool integrations to extend capabilities:

- **Exa** — Web search and code example discovery. Used by `/project-research` to find domain knowledge and implementation patterns from across the web and GitHub.
- **Ref** — Documentation lookup. Used to find official docs and technical references without bloat.
- **Playwright / Chrome** — Visual testing and browser automation. Used by `/project-test` to validate visual rendering and UI behavior.
- **Vercel** — Deployment verification. Used by `/project-deploy` to verify builds, check environment variables, and confirm production readiness.

These tools are invoked automatically by the skill logic — you don't need to configure anything beyond the skills themselves.

---

## The Nine Slash Commands

### `/project-init [idea]`

**Use when:** Starting any new project, or adding a major new feature area.

This is the main entry point. Give it any project description — as vague or specific as you like — and it runs the full seven-phase initialisation:

1. Clarifies ambiguities (up to 3 targeted questions if needed)
2. Researches the domain (market, users, competitors, regulations)
3. Identifies and lists the core modules for your approval
4. Generates `specs/MASTER_BLUEPRINT.md` (complete architecture)
5. Generates `specs/modules/[module]/SPEC.md` for all MVP modules
6. Generates `specs/modules/[module]/CLAUDE.md` for all MVP modules
7. Creates `specs/ROADMAP.md` with recommended implementation order

**Output:** A complete spec hierarchy ready for implementation. No code written.

---

### `/project-research [topic]`

**Use when:** You need deep research on a specific domain, technology, regulation, or competitor before making architectural decisions.

Runs a structured web-search research session and saves findings to `specs/research/[topic].md`. Also updates `LEARNINGS.md` with anything that directly affects implementation.

Examples:
```
/project-research "UK GDPR requirements for storing student data"
/project-research "MIS integration APIs — SIMS, Bromcom, Arbor"
/project-research "multi-tenant SaaS patterns with Postgres row-level security"
```

---

### `/project-blueprint`

**Use when:** You need to generate or regenerate the master architecture document. Also useful mid-project when major architectural decisions need to be revised.

Reads all existing specs and research, then produces or updates `specs/MASTER_BLUEPRINT.md` — the single authoritative source for stack decisions, data models, API patterns, and module relationships.

---

### `/project-spec [module-name]`

**Use when:** Creating or updating the spec for a specific module.

Reads the master blueprint to understand the overall architecture, then produces:
- `specs/modules/[module-name]/SPEC.md` — full module spec (user stories, data model, APIs, UI screens, business rules, acceptance criteria)
- `specs/modules/[module-name]/CLAUDE.md` — module-specific implementation guide

Always asks for approval before saving.

---

### `/project-module [module-name]`

**Use when:** Ready to implement a module that already has an approved spec.

Before writing a single line of code, it reads:
1. `specs/MASTER_BLUEPRINT.md`
2. `specs/modules/[module-name]/SPEC.md`
3. `specs/modules/[module-name]/CLAUDE.md`
4. `LEARNINGS.md`

Then enters Plan Mode — writes out the full implementation plan and waits for your approval before coding. Implements incrementally, running tests and committing after each logical chunk.

---

### `/project-review`

**Use when:** At the end of every session, or after completing any task.

Captures what was done, what wasn't, and what was learned — then writes new entries to `LEARNINGS.md` and updates `CLAUDE.md` with any new rules. Recommends the next task based on the roadmap.

This command is what makes the system compound. Don't skip it.

---

### `/project-status`

**Use when:** You want a full project dashboard — what specs exist, what's been implemented, what's next.

Produces a clean status table showing every module's state (no spec / spec exists / in progress / complete) and recommends the next task.

---

### `/project-deploy`

**Use when:** Ready to deploy to production or need to verify deployment readiness.

Verifies the build succeeds, checks environment variables are set, validates critical integrations are configured, and performs a test deployment. Uses Vercel integration to confirm production readiness.

**Output:** Deployment verification report and promotion to production, or detailed feedback on blockers.

---

### `/project-test`

**Use when:** Need comprehensive test coverage — unit tests, type checking, linting, and visual validation.

Runs the full test suite: unit tests, type checking (TypeScript), linting, and visual regression testing using browser automation. Generates a coverage report and flags any regressions.

**Output:** Test results, coverage report, visual diff comparisons (if applicable).

---

## Example Workflow — UK Education CRM

Here is a complete real-world walkthrough from vague idea to first working module.

---

### Day 1 — Initialisation

You open Claude Code in a fresh directory and run the bootstrap:

```bash
mkdir crm-edu-uk && cd crm-edu-uk
bash bootstrap.sh
```

Output confirms greenfield detection. Then in Claude Code:

```
/project-init "CRM solution for the UK education market"
```

**Phase 1 — Clarification**

Claude asks three targeted questions:

> 1. Who are the primary users — MAT (Multi-Academy Trust) administrators, individual school business managers, or both?
> 2. What's the core problem? Tracking relationships with suppliers, managing admissions, or something else?
> 3. Any existing systems that need to integrate with (SIMS, Arbor, Bromcom, Xero)?

You answer:
> MAT administrators and school business managers. Core problem is managing supplier and contractor relationships — procurement, contracts, invoicing. Needs to integrate with Xero for invoicing.

**Phase 2 — Domain Research**

Claude researches and saves `specs/RESEARCH.md` covering:
- UK education procurement landscape (ESFA guidelines, procurement frameworks like Crown Commercial Service)
- MAT organisational structures and decision-making hierarchies
- GDPR considerations for supplier data in the education sector
- Xero API capabilities for UK education invoicing
- Key competitors (SchoolBiz, ParentMail, custom spreadsheets)

**Phase 3 — Module Identification**

Claude proposes modules and asks for approval:

| Module | Priority | Description |
|--------|----------|-------------|
| `organisations` | Core | MATs and schools — the account hierarchy |
| `contacts` | Core | Individuals at supplier organisations |
| `suppliers` | Core | Supplier profiles, accreditations, categories |
| `contracts` | Core | Contract lifecycle — draft, active, expired |
| `invoicing` | Core | Invoice tracking + Xero sync |
| `procurement` | Core | Purchase requests and approval workflow |
| `documents` | Core | Contract documents, compliance certs |
| `notifications` | V1.1 | Contract expiry alerts, approval reminders |
| `reporting` | V1.1 | Spend analysis, supplier performance |
| `portal` | Future | Supplier self-service portal |

You approve with one change: move `documents` to V1.1.

**Phase 4 — Master Blueprint**

Claude detects no stack exists and asks the four stack questions:

> 1. What type of application? Web app — I need a full-stack Next.js build
> 2. Stack preferences? Next.js App Router, TypeScript, Bun, shadcn/ui, Prisma, PostgreSQL
> 3. Scale? Small SaaS — initially 20-50 MATs
> 4. Deployment? Vercel + Supabase

Claude generates `specs/MASTER_BLUEPRINT.md` including:
- Full data model (MAT → School → Contact relationships, Contract ↔ Supplier ↔ Invoice)
- API pattern (Next.js Server Actions + tRPC for complex queries)
- Auth approach (NextAuth.js with organisation-scoped sessions)
- Multi-tenancy model (organisation_id on every table, RLS in Postgres)
- Xero OAuth2 integration pattern
- shadcn/ui component conventions

**Phase 5-6 — Module Specs Generated**

Claude generates `SPEC.md` and `CLAUDE.md` for all 7 Core modules. Example for `contracts`:

`specs/modules/contracts/SPEC.md` covers:
- 6 user stories (create contract, track renewal dates, attach documents, approval workflow, Xero sync on completion, expiry alerts)
- Data model: `Contract` entity with status enum, `ContractLineItem`, `ContractParty`
- 8 API endpoints (CRUD + archive + approve + xero-sync)
- 3 UI screens (contract list, contract detail, contract creation wizard)
- Business rules (approval thresholds by value, ESFA compliance flags)
- Acceptance criteria (12 testable criteria)

**Phase 7 — Roadmap**

`specs/ROADMAP.md` recommends this order (with rationale):

```
1. organisations    ← Foundation — everything belongs to an org
2. contacts         ← Depends on organisations
3. suppliers        ← Depends on contacts
4. contracts        ← Core value prop, depends on suppliers
5. procurement      ← Depends on contracts
6. invoicing        ← Depends on contracts + Xero integration
```

Total session time: approximately 25-35 minutes. No code written yet.

---

### Day 2 — First Module

You open Claude Code. It reads `CLAUDE.md` automatically.

```
/project-status
```

Output:

```
PROJECT STATUS — 2026-03-13
================================
Research:     ✅ Complete
Blueprint:    ✅ Complete
Roadmap:      ✅ Complete

MODULES:
  organisations    ✅ Spec  ❌ Not started
  contacts         ✅ Spec  ❌ Not started
  suppliers        ✅ Spec  ❌ Not started
  contracts        ✅ Spec  ❌ Not started
  procurement      ✅ Spec  ❌ Not started
  invoicing        ✅ Spec  ❌ Not started

NEXT RECOMMENDED TASK:
  /project-module organisations
```

```
/project-module organisations
```

Claude reads all four prerequisite files, then enters Plan Mode:

> **Implementation Plan — organisations module**
>
> Files to create:
> - `prisma/schema.prisma` — Organisation, School models
> - `src/modules/organisations/` — Server actions, types, validation
> - `src/app/(dashboard)/organisations/` — List page, detail page
> - `tests/modules/organisations/` — Unit tests for server actions
>
> Order: schema → server actions → tests → UI
> Shall I proceed?

You approve. Claude implements, runs tests after each chunk, commits:

```
feat(organisations): add Prisma schema for Organisation and School
feat(organisations): add server actions for CRUD operations
feat(organisations): add organisation list page with search/filter
feat(organisations): add organisation detail page with school roster
```

```
/project-review
```

Claude adds to `LEARNINGS.md`:

```markdown
## Patterns That Work
- Server actions with Zod validation: define schema in shared
  `src/lib/validations/[module].ts`, import in both action and form component

## Mistakes & Fixes
- Prisma relation naming: use explicit `@relation` names when a model
  has multiple relations to the same table — prevents ambiguous relation errors

## Stack-Specific Notes
- Supabase RLS + Prisma: must set `SET LOCAL app.current_org_id` in a
  Prisma middleware on every query to activate row-level security
```

And updates `CLAUDE.md` with one new rule:
```markdown
- ✅ Always: Set `app.current_org_id` via Prisma middleware before any query
```

---

### Day 3 — Second Module

You open Claude Code. It reads `CLAUDE.md` (now with the RLS rule) and `LEARNINGS.md` (now with the Prisma relation tip). It already knows not to make the mistakes from Day 2.

```
/project-module contacts
```

The RLS middleware is already in place from the previous module. The Prisma relation naming is done correctly first time. The compound effect has already kicked in.

---

### Week 2 — Mid-Project Research Spike

You realise you need to understand Xero's UK-specific tax handling before designing the invoicing module properly.

```
/project-research "Xero API UK VAT handling and invoice webhooks"
```

Claude researches, saves findings to `specs/research/xero-vat.md`, and updates `LEARNINGS.md`. When you later run `/project-spec invoicing`, Claude reads this research automatically and designs the data model with correct VAT fields and webhook handling from the start.

---

### Month 2 — Checkpoint

```
/project-status
```

```
PROJECT STATUS — 2026-04-15
================================
Research:     ✅ Complete (+ 3 research spikes)
Blueprint:    ✅ Complete
Roadmap:      ✅ Complete

MODULES:
  organisations    ✅ Spec  ✅ Complete
  contacts         ✅ Spec  ✅ Complete
  suppliers        ✅ Spec  ✅ Complete
  contracts        ✅ Spec  ✅ Complete
  procurement      ✅ Spec  🔨 In Progress
  invoicing        ✅ Spec  ❌ Not started

LEARNINGS.md: 23 entries (4 open questions)

NEXT RECOMMENDED TASK:
  /project-module invoicing
```

---

## Key Principles to Keep in Mind

### One session = one task

Never try to implement multiple modules in a single session. Long sessions degrade quality as context fills. If you've had to correct Claude on the same issue twice in a session, run `/project-review` then `/clear` and start fresh.

### The spec is the source of truth — not the code

If implementation diverges from the spec (for legitimate reasons), update the spec. Specs must stay in sync with code. Never let them drift apart.

### Commit paranoia is good

Every working, tested state should be a commit. Commits are your save points. If a session goes wrong, you can always roll back to the last good commit and start fresh without losing work.

### Context at 60%? Compact.

Watch your context usage in Claude Code. When it hits around 60%, run `/compact` before continuing. This prevents the quality degradation that comes from an overfull context window.

### The compound effect is the whole point

The system gets measurably smarter with each session because every mistake becomes a rule and every pattern gets documented. After 4-5 modules, Claude is essentially a specialist in your specific codebase — it knows your patterns, your conventions, your gotchas. This is the Boris Cherny insight: treat CLAUDE.md as a living document where every mistake paid in Day 1 pays dividends for the rest of the project.

---

## Brownfield Projects

When you run `bootstrap.sh` in a directory with existing source files, it automatically switches to brownfield mode and creates an additional file: `specs/existing-system/AUDIT.md`.

Fill this in before running any slash commands. It captures what already exists, what works well (don't touch it), known problems, and constraints. This prevents Claude from "helpfully" rewriting working code or introducing patterns that conflict with your existing architecture.

In brownfield mode, the workflow shifts slightly:

1. Fill in `AUDIT.md` manually
2. Run `/project-status` to understand the current state
3. Use `/project-spec [module]` to write spec *deltas* for new features (what's being ADDED or CHANGED, not a from-scratch spec)
4. Use `/project-research` for any unfamiliar areas of the existing codebase

---

## Sharing the Kit Across Projects

The most efficient setup is to keep `bootstrap.sh` in a personal GitHub repo (e.g. `your-username/ai-project-kit`) and pin it to a version. Then for every new project:

```bash
curl -sO https://raw.githubusercontent.com/your-username/ai-project-kit/main/bootstrap.sh
bash bootstrap.sh && rm bootstrap.sh
```

As you discover better patterns — in your CLAUDE.md, your slash commands, your templates — update the source repo. Every future project benefits from every past project's learnings, even before a single line of code is written.

---

## Quick Reference

| Command | What it does |
|---------|-------------|
| `bash bootstrap.sh` | One-time setup, auto-detects green/brownfield |
| `/project-init [idea]` | Research → blueprint → all specs → roadmap |
| `/project-research [topic]` | Deep research, saved to specs/research/ |
| `/project-blueprint` | Generate/regenerate master architecture |
| `/project-spec [module]` | Create or update a module spec |
| `/project-module [name]` | Plan + implement a module against its spec |
| `/project-review` | Capture learnings, compound into CLAUDE.md |
| `/project-status` | Full project dashboard |
| `/project-deploy` | Verify deployment readiness and promote to production |
| `/project-test` | Run comprehensive tests (unit, type, lint, visual) |

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Operating model — read by Claude Code automatically |
| `LEARNINGS.md` | Accumulated project knowledge |
| `specs/MASTER_BLUEPRINT.md` | Architecture source of truth |
| `specs/ROADMAP.md` | Implementation order and priorities |
| `specs/modules/[x]/SPEC.md` | What a module does |
| `specs/modules/[x]/CLAUDE.md` | How to build it in this project |

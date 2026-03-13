#!/usr/bin/env bash
# =============================================================================
# AI Project Kit — Bootstrap Script
# Drop this in any project root and run: bash bootstrap.sh
# =============================================================================

set -e

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}╔═══════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}${BOLD}║         AI Project Kit — Bootstrapping         ║${RESET}"
echo -e "${CYAN}${BOLD}╚═══════════════════════════════════════════════╝${RESET}"
echo ""

# Detect if brownfield (existing code present)
FILE_COUNT=$(find . -maxdepth 2 -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.rb" -o -name "*.go" 2>/dev/null | grep -v node_modules | grep -v ".claude" | wc -l | tr -d ' ')

if [ "$FILE_COUNT" -gt "5" ]; then
  echo -e "${YELLOW}⚡ Brownfield project detected ($FILE_COUNT source files found)${RESET}"
  echo -e "   Kit will configure for brownfield mode (spec existing system first)."
  PROJECT_MODE="brownfield"
else
  echo -e "${GREEN}✨ Greenfield project — full spec-first workflow will be configured.${RESET}"
  PROJECT_MODE="greenfield"
fi

echo ""

# Create directory structure
echo -e "${BOLD}Creating kit structure...${RESET}"
mkdir -p .claude/commands
mkdir -p .claude/templates
mkdir -p specs/modules

# =============================================================================
# ROOT CLAUDE.md
# =============================================================================
cat > CLAUDE.md << 'CLAUDE_EOF'
# Project Operating Model

You are an expert software architect and engineer operating within a
spec-first development methodology. This file is your operating manual.
**Read it fully at the start of every session.**

---

## The Prime Directive

**Never write production code until a spec exists and has been approved.**

If given a vague idea ("build a CRM"), you do not start coding.
You enter the project initialisation workflow instead.

---

## Trigger Recognition

When a human says something like:
- "I want to build a [product] for [market]"
- "Let's start a new project" / "I have an idea..."
- "Build me a..." / "Create a..."

**Do not write code. Respond with:**
> "Before we write any code, let me run the project init workflow to
> research the domain, design the architecture, and create a proper spec
> hierarchy. This will save significant rework later. Type
> `/project:init [your idea]` to begin, or I can start it now."

---

## Workflow — Every Project Follows This Sequence

```
1. RESEARCH     Understand domain, market, users, competitors, regulations
       ↓
2. BLUEPRINT    Master architecture: data model, modules, API patterns, stack
       ↓
3. MODULE SPECS One detailed spec per feature module (in specs/modules/)
       ↓
4. IMPLEMENT    One module at a time. Spec is source of truth. Commit often.
       ↓
5. COMPOUND     After each module: update LEARNINGS.md and CLAUDE.md
```

---

## Available Slash Commands

| Command                      | When to use |
|------------------------------|-------------|
| `/project:init [idea]`       | New project or major feature — starts full research + spec workflow |
| `/project:research [topic]`  | Deep research on a domain, competitor, regulation, or technical topic |
| `/project:blueprint`         | Generate or regenerate the master architecture document |
| `/project:spec [module]`     | Create or update a module-level spec |
| `/project:module [name]`     | Begin implementation of a specific module |
| `/project:review`            | End-of-session: capture learnings, update specs |
| `/project:status`            | Show what specs exist, what's implemented, what's next |

---

## Spec Hierarchy

```
specs/
  MASTER_BLUEPRINT.md          ← Single source of truth for all architecture
  modules/
    [module-name]/
      SPEC.md                  ← What the module does, data model, API, UI
      CLAUDE.md                ← Module-specific rules, patterns, gotchas
```

**Before starting any implementation task, read:**
1. `specs/MASTER_BLUEPRINT.md` (architecture + shared patterns)
2. `specs/modules/[module]/SPEC.md` (what you're building)
3. `specs/modules/[module]/CLAUDE.md` (how to build it here)
4. `LEARNINGS.md` (what we've learned so far)

---

## Session Rules

- **One session = one task.** Never try to do everything in one session.
- **Plan Mode first.** Before implementing, confirm the full approach in writing.
  Do not start coding until the plan is approved.
- **Commit after every successful, working change.** Commits are save points.
- **If you've corrected the same mistake twice**, stop, add it to this file,
  run `/clear` and start a fresh session.
- **Keep context light.** Reference spec files by path; don't re-read the
  entire codebase each session.
- **Context at ~60% full? Run `/compact` before continuing.**

---

## Boundaries

**✅ Always do without asking:**
- Run tests before committing (`[TEST COMMAND — set after stack detection]`)
- Reference SPEC.md before starting any task in that module
- Add new learnings to `LEARNINGS.md` after each session
- Follow the patterns established in `MASTER_BLUEPRINT.md`

**⚠️ Ask before:**
- Adding new dependencies (npm/pip/gem install, etc.)
- Changing the database schema
- Modifying authentication or authorisation logic
- Restructuring the project directory layout
- Changing shared utilities, base components, or API patterns
- Deviating from patterns established in `MASTER_BLUEPRINT.md`

**🚫 Never without explicit approval:**
- Write production code before a spec exists
- Commit secrets, API keys, or `.env` files
- Modify CI/CD configuration
- Introduce architectural patterns that contradict `MASTER_BLUEPRINT.md`
- Delete or overwrite spec files
- Run database migrations in production

---

## Stack Detection (Greenfield)

If no stack is defined yet, ask exactly these four questions before
producing any technical recommendations:

1. What type of application? (web app, mobile, API-only, CLI tool, desktop)
2. Any specific stack preferences, constraints, or existing infrastructure?
3. Rough scale: personal/internal tool, small SaaS, or enterprise?
4. Deployment target? (Vercel/cloud PaaS, self-hosted, containerised, etc.)

Wait for answers. Then recommend a stack with brief rationale and confirm
before writing any architectural docs.

---

## Quality Standards

- Use strict TypeScript / typed language features where applicable
- Write tests for all business logic (not just UI)
- Follow the ORM/query pattern defined in MASTER_BLUEPRINT.md — no raw SQL
  unless explicitly authorised
- Match the code style of the first implemented module — no style drift
- Every commit must leave the project in a working, deployable state
- Security: validate all inputs, never trust client data, follow OWASP basics

---

## Learnings

Project-specific learnings are in `LEARNINGS.md`.
**Read this at the start of every implementation session.**
CLAUDE_EOF

echo -e "  ${GREEN}✓${RESET} CLAUDE.md"

# =============================================================================
# LEARNINGS.md
# =============================================================================
cat > LEARNINGS.md << 'LEARNINGS_EOF'
# Project Learnings

This file is updated at the end of every session. It captures mistakes,
discoveries, patterns that work, and patterns that don't. Reading this
at the start of an implementation session prevents repeating mistakes.

> **Maintained by:** Claude Code (auto-updated via `/project:review`)
> **Format:** Newest entries at the top.

---

## Patterns That Work

_Populated as the project progresses._

---

## Mistakes & Fixes

_Populated as the project progresses._

---

## Stack-Specific Notes

_Populated after stack is selected._

---

## Open Questions

_Architectural or product decisions still to be resolved._
LEARNINGS_EOF

echo -e "  ${GREEN}✓${RESET} LEARNINGS.md"

# =============================================================================
# SLASH COMMAND: /project:init
# =============================================================================
cat > .claude/commands/init.md << 'CMD_INIT_EOF'
You are being asked to initialise a new software project from the following idea:

**Project Idea:** $ARGUMENTS

Your job is to take this vague idea and produce a full, structured project
foundation using the spec-first methodology. Work through the following
phases in order. Do not skip phases. Do not write any application code.

---

## Phase 1 — Clarify (if needed)

If the idea is ambiguous, ask up to 3 targeted clarifying questions before
proceeding. Focus on:
- Target market / geography (e.g. UK, US, global)
- Primary users (e.g. end consumers, business teams, administrators)
- Core problem being solved
- Any known technical constraints or existing systems

If the idea is clear enough, skip this and proceed to Phase 2.

---

## Phase 2 — Domain Research

Research the following and produce a concise Research Summary:

1. **Market landscape** — Who are the main players? What do they do well/poorly?
2. **Target users** — What are their actual pain points? What workflows do they have today?
3. **Domain-specific requirements** — Regulations, compliance, standards, integrations that are common in this market (e.g. UK GDPR, NHS data standards, FERPA for US education, etc.)
4. **Technical patterns** — What architectural patterns are common and well-suited to this domain?
5. **Key differentiators** — What would make this product better than existing solutions?

Save the research as: `specs/RESEARCH.md`

---

## Phase 3 — Module Identification

Based on the research, identify the core functional modules this product needs.
For each module, list:
- Module name (slug format, e.g. `contacts`, `deal-pipeline`)
- One-sentence description
- Priority: Core (MVP) | Important (V1.1) | Future

List 5-12 modules. Aim for clear separation of concerns.
Present this list and ask for approval before continuing.

---

## Phase 4 — Master Blueprint

Once modules are approved, generate `specs/MASTER_BLUEPRINT.md` using the
master blueprint template. This must cover:
- Project overview and goals
- Confirmed tech stack (detect from existing code, or ask using the 4 stack
  questions in CLAUDE.md if greenfield)
- Full data model (all entities, relationships, key fields)
- API design patterns (REST/GraphQL/tRPC, naming conventions, auth approach)
- Shared UI patterns (design system, component conventions)
- Infrastructure and deployment approach
- Module list with priorities

---

## Phase 5 — Module Specs

For each **Core (MVP)** module, generate a spec file at:
`specs/modules/[module-name]/SPEC.md`

Use the MODULE_SPEC template. Each spec must include:
- Purpose and user stories
- Data model (entities specific to this module)
- API endpoints / server actions
- UI screens / components
- Business logic and rules
- Acceptance criteria
- Dependencies on other modules

---

## Phase 6 — Module CLAUDE.md Files

For each Core module, also generate:
`specs/modules/[module-name]/CLAUDE.md`

This should capture module-specific implementation rules, patterns to follow,
and gotchas to avoid.

---

## Phase 7 — Implementation Roadmap

Create `specs/ROADMAP.md` with:
- Recommended implementation order (which module to build first, why)
- Dependencies between modules
- Rough effort estimates (S/M/L)
- MVP definition: minimum set of modules for a useful first version

---

## Output Summary

When complete, provide:
1. A bullet list of every file created
2. The recommended first implementation task
3. The exact Claude Code command to begin: `/project:module [first-module]`

Do not write any application code. Your output is spec documents only.
CMD_INIT_EOF

echo -e "  ${GREEN}✓${RESET} .claude/commands/init.md"

# =============================================================================
# SLASH COMMAND: /project:research
# =============================================================================
cat > .claude/commands/research.md << 'CMD_RESEARCH_EOF'
Conduct deep research on the following topic as it relates to this project:

**Research Topic:** $ARGUMENTS

Use web search to find current, accurate information. Research the following
angles and produce a structured research document:

1. **Overview** — What is this topic? Why does it matter for this project?

2. **Current Landscape** — Who are the key players, tools, standards, or
   regulations? What's the current state of the art?

3. **Key Findings for This Project** — What did you learn that directly
   affects our architecture, tech choices, compliance requirements, or
   feature design?

4. **Recommended Approach** — Based on your research, what do you recommend?
   Provide 2-3 concrete, actionable recommendations.

5. **Open Questions** — What questions remain unanswered that we should
   investigate further?

6. **Sources** — List the key sources you used.

Save the output to: `specs/research/[topic-slug].md`

Then update `LEARNINGS.md` with the key findings that affect implementation.

Do not write any application code. Research output only.
CMD_RESEARCH_EOF

echo -e "  ${GREEN}✓${RESET} .claude/commands/research.md"

# =============================================================================
# SLASH COMMAND: /project:blueprint
# =============================================================================
cat > .claude/commands/blueprint.md << 'CMD_BLUEPRINT_EOF'
Generate or regenerate the Master Architecture Blueprint for this project.

First, read all existing spec files to understand what has already been
decided:
- `specs/RESEARCH.md` (if it exists)
- Any existing `specs/modules/*/SPEC.md` files
- This project's `CLAUDE.md`

Then produce or update `specs/MASTER_BLUEPRINT.md` using the template at
`.claude/templates/MASTER_BLUEPRINT.md`.

If generating for the first time and the tech stack is not yet defined:
Ask the 4 stack-detection questions from CLAUDE.md before proceeding.

The blueprint must be the single authoritative source for:
- Tech stack decisions (with rationale)
- Data model (all entities and relationships)
- API design patterns and naming conventions
- Authentication and authorisation approach
- Shared UI patterns and component conventions
- Infrastructure and deployment
- Module list with dependencies and priorities

After generating, present a summary of the key architectural decisions and
ask for approval before saving.

Do not write any application code.
CMD_BLUEPRINT_EOF

echo -e "  ${GREEN}✓${RESET} .claude/commands/blueprint.md"

# =============================================================================
# SLASH COMMAND: /project:spec
# =============================================================================
cat > .claude/commands/spec.md << 'CMD_SPEC_EOF'
Generate or update the spec for the following module:

**Module:** $ARGUMENTS

First, read:
- `specs/MASTER_BLUEPRINT.md` — to understand the overall architecture
- `specs/modules/$ARGUMENTS/SPEC.md` — if it already exists (update mode)
- Any related module specs (check MASTER_BLUEPRINT.md for dependencies)

Then produce or update `specs/modules/$ARGUMENTS/SPEC.md` using the
MODULE_SPEC template at `.claude/templates/MODULE_SPEC.md`.

The spec must cover:
1. **Purpose** — What problem does this module solve? Who uses it?
2. **User Stories** — 3-8 concrete user stories (As a [user], I want to [action], so that [outcome])
3. **Data Model** — All entities this module owns, with fields and types
4. **API / Server Actions** — Every endpoint or server action, with method, path, inputs, outputs
5. **UI Screens** — List of screens/pages, key components, user flows
6. **Business Logic** — Rules, validations, calculations, edge cases
7. **Integration Points** — How this module connects to others
8. **Acceptance Criteria** — Testable criteria for "done"
9. **Out of Scope** — Explicitly what this module does NOT cover

Also generate or update `specs/modules/$ARGUMENTS/CLAUDE.md` with
module-specific implementation rules.

Present the spec and ask for approval before saving.
Do not write any application code.
CMD_SPEC_EOF

echo -e "  ${GREEN}✓${RESET} .claude/commands/spec.md"

# =============================================================================
# SLASH COMMAND: /project:module
# =============================================================================
cat > .claude/commands/module.md << 'CMD_MODULE_EOF'
Begin implementation of the following module:

**Module:** $ARGUMENTS

## Before Writing Any Code

Read these files in full:
1. `specs/MASTER_BLUEPRINT.md` — architecture, patterns, conventions
2. `specs/modules/$ARGUMENTS/SPEC.md` — what to build
3. `specs/modules/$ARGUMENTS/CLAUDE.md` — how to build it here
4. `LEARNINGS.md` — what we've learned so far
5. `CLAUDE.md` — session rules and boundaries

If any of these files don't exist, stop and run the appropriate command
to create them first (`/project:spec $ARGUMENTS`).

## Implementation Approach

1. **Enter Plan Mode first.** Write out the implementation plan:
   - Files to create
   - Files to modify
   - Order of implementation
   - Test strategy
   Present the plan and wait for approval before writing code.

2. **Implement incrementally.** After each logical chunk:
   - Run the test suite
   - If tests pass: commit with a descriptive message
   - If tests fail: fix before proceeding

3. **Follow established patterns.** Check how other modules implement
   similar things and match the pattern exactly. No style drift.

4. **Flag blockers immediately.** If you encounter something that requires
   an architectural decision or contradicts the spec, stop and ask.
   Do not invent solutions to ambiguous requirements.

## Commit Message Format

```
feat([module]): [what was done]

- [specific change 1]
- [specific change 2]
```

## When Implementation Is Complete

1. Run the full test suite
2. Update `specs/modules/$ARGUMENTS/SPEC.md` if anything changed during implementation
3. Run `/project:review` to capture learnings
CMD_MODULE_EOF

echo -e "  ${GREEN}✓${RESET} .claude/commands/module.md"

# =============================================================================
# SLASH COMMAND: /project:review
# =============================================================================
cat > .claude/commands/review.md << 'CMD_REVIEW_EOF'
Conduct an end-of-session review. This command should be run after completing
a task or at the end of a working session.

## Step 1 — Summarise What Was Done

List:
- What was completed in this session
- What was NOT completed (deferred)
- Any decisions that were made

## Step 2 — Capture Learnings

For each of the following, add new entries to `LEARNINGS.md` (newest at top):
- **Patterns That Work** — approaches, utilities, or patterns that worked well
  and should be reused
- **Mistakes & Fixes** — what went wrong and how it was resolved
  (prevents repeating the same mistake)
- **Stack-Specific Notes** — quirks, gotchas, or useful discoveries about
  the tech stack
- **Open Questions** — architectural or product questions that came up and
  remain unresolved

## Step 3 — Update CLAUDE.md

If any mistakes were repeated more than once, add a rule to the root
`CLAUDE.md` Boundaries section. Keep it concrete and actionable.

If any module-specific patterns were discovered, update
`specs/modules/[module]/CLAUDE.md`.

## Step 4 — Update Specs (if needed)

If the implementation deviated from the spec (for legitimate reasons),
update the spec to reflect reality. Specs must stay in sync with code.

## Step 5 — What's Next

Recommend the next task based on:
- `specs/ROADMAP.md` (priority order)
- What dependencies have now been unlocked
- Any blocking issues that need to be resolved first

Output a clear "Next session should:" statement.
CMD_REVIEW_EOF

echo -e "  ${GREEN}✓${RESET} .claude/commands/review.md"

# =============================================================================
# SLASH COMMAND: /project:status
# =============================================================================
cat > .claude/commands/status.md << 'CMD_STATUS_EOF'
Provide a complete status report for this project.

## Step 1 — Read the Project State

Check the following and report what exists:
- `specs/RESEARCH.md` — exists? summarise in 2 sentences
- `specs/MASTER_BLUEPRINT.md` — exists? list the confirmed stack and modules
- `specs/ROADMAP.md` — exists? show the priority order
- `specs/modules/*/SPEC.md` — list each module and its status:
  - 📋 Spec exists, not started
  - 🔨 In progress
  - ✅ Complete
  - ❌ Missing spec
- `LEARNINGS.md` — how many entries? any open questions?

## Step 2 — Implementation Status

Check the source code directories (if any exist) to determine which
modules have code written vs. are spec-only.

## Step 3 — Output Format

Produce a clean status table:

```
PROJECT STATUS — [date]
================================
Research:     ✅ Complete / ❌ Missing
Blueprint:    ✅ Complete / ❌ Missing
Roadmap:      ✅ Complete / ❌ Missing

MODULES:
  contacts         ✅ Spec  ✅ Code
  deal-pipeline    ✅ Spec  🔨 In Progress
  invoicing        📋 Spec  ❌ Not started
  email-sync       ❌ No spec yet

NEXT RECOMMENDED TASK:
  /project:module [next-module]
```
CMD_STATUS_EOF

echo -e "  ${GREEN}✓${RESET} .claude/commands/status.md"

# =============================================================================
# TEMPLATE: MASTER_BLUEPRINT.md
# =============================================================================
cat > .claude/templates/MASTER_BLUEPRINT.md << 'TPL_BLUEPRINT_EOF'
# Master Architecture Blueprint

> **Status:** Draft / Approved / In Progress
> **Last Updated:** {{DATE}}
> **Project:** {{PROJECT_NAME}}

---

## 1. Project Overview

**What we're building:**
{{ONE_PARAGRAPH_DESCRIPTION}}

**Who it's for:**
{{TARGET_USERS}}

**Core problem it solves:**
{{CORE_PROBLEM}}

**Success looks like:**
{{SUCCESS_CRITERIA}}

---

## 2. Tech Stack

> All stack decisions must be made here and followed project-wide.
> Adding or changing dependencies requires updating this document.

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Frontend | {{FRONTEND}} | {{RATIONALE}} |
| Backend | {{BACKEND}} | {{RATIONALE}} |
| Database | {{DATABASE}} | {{RATIONALE}} |
| ORM / Query | {{ORM}} | {{RATIONALE}} |
| Auth | {{AUTH}} | {{RATIONALE}} |
| File Storage | {{STORAGE}} | {{RATIONALE}} |
| Email | {{EMAIL}} | {{RATIONALE}} |
| Deployment | {{DEPLOYMENT}} | {{RATIONALE}} |
| Testing | {{TESTING}} | {{RATIONALE}} |

**Package manager:** {{PACKAGE_MANAGER}}
**Language version:** {{LANGUAGE_VERSION}}

---

## 3. Data Model

### Entities & Relationships

```
{{ENTITY_DIAGRAM_OR_LIST}}
```

### Key Design Decisions
- {{DECISION_1}}
- {{DECISION_2}}

---

## 4. API Design Patterns

**Style:** {{REST | GraphQL | tRPC | Server Actions}}

**Base URL:** `{{BASE_URL}}`

**Authentication:** {{AUTH_APPROACH}}
- All authenticated routes require: `{{AUTH_HEADER_OR_MECHANISM}}`
- Token format: `{{TOKEN_FORMAT}}`

**Naming conventions:**
- Resources: plural nouns (`/contacts`, `/deals`)
- Actions: verb-noun (`/deals/123/archive`)
- Pagination: `?page=1&limit=20`

**Error format:**
```json
{
  "error": "{{ERROR_CODE}}",
  "message": "Human readable message",
  "details": {}
}
```

---

## 5. Shared UI Patterns

**Design system:** {{DESIGN_SYSTEM}}
**Component library:** {{COMPONENT_LIBRARY}}

**Layout conventions:**
- {{LAYOUT_PATTERN}}

**Form conventions:**
- {{FORM_PATTERN}}

**Data loading patterns:**
- {{LOADING_PATTERN}}

**Navigation:**
- {{NAV_PATTERN}}

---

## 6. Modules

| Module | Priority | Description | Depends On |
|--------|----------|-------------|------------|
| {{MODULE}} | Core/V1.1/Future | {{DESCRIPTION}} | {{DEPS}} |

---

## 7. Infrastructure & Deployment

**Environments:** dev → staging → production

**Environment variables:**
- `{{VAR_NAME}}` — {{PURPOSE}} (required/optional)

**Deployment process:**
{{DEPLOYMENT_PROCESS}}

**Monitoring & observability:**
{{MONITORING_APPROACH}}

---

## 8. Security & Compliance

**Authentication model:** {{AUTH_MODEL}}
**Authorisation model:** {{AUTHZ_MODEL}} (e.g. RBAC, ABAC)
**Data classification:** {{DATA_TYPES_AND_SENSITIVITY}}
**Relevant regulations:** {{GDPR | HIPAA | FERPA | etc.}}
**Key compliance requirements:**
- {{REQUIREMENT_1}}
- {{REQUIREMENT_2}}

---

## 9. Open Architectural Questions

> Remove items once resolved. Add rationale to relevant section above.

- [ ] {{OPEN_QUESTION_1}}
- [ ] {{OPEN_QUESTION_2}}
TPL_BLUEPRINT_EOF

echo -e "  ${GREEN}✓${RESET} .claude/templates/MASTER_BLUEPRINT.md"

# =============================================================================
# TEMPLATE: MODULE_SPEC.md
# =============================================================================
cat > .claude/templates/MODULE_SPEC.md << 'TPL_SPEC_EOF'
# Module Spec: {{MODULE_NAME}}

> **Status:** Draft / Approved / In Progress / Complete
> **Priority:** Core (MVP) / V1.1 / Future
> **Last Updated:** {{DATE}}
> **Depends on:** {{DEPENDENCIES}}

---

## 1. Purpose

**What this module does:**
{{ONE_PARAGRAPH_PURPOSE}}

**Who uses it:**
{{PRIMARY_USERS}}

**What problem it solves:**
{{PROBLEM}}

---

## 2. User Stories

| # | As a... | I want to... | So that... |
|---|---------|-------------|------------|
| 1 | {{USER}} | {{ACTION}} | {{OUTCOME}} |
| 2 | {{USER}} | {{ACTION}} | {{OUTCOME}} |
| 3 | {{USER}} | {{ACTION}} | {{OUTCOME}} |

---

## 3. Data Model

> Only entities **owned** by this module. Reference other modules' entities by name.

### {{ENTITY_NAME}}
```typescript
interface {{EntityName}} {
  id: string            // UUID
  {{FIELD}}: {{TYPE}}   // {{DESCRIPTION}}
  createdAt: Date
  updatedAt: Date
}
```

### Relationships
- `{{Entity}}` belongs to `{{OtherEntity}}` (via `{{foreignKey}}`)
- `{{Entity}}` has many `{{OtherEntity}}`

---

## 4. API / Server Actions

### `{{METHOD}} {{PATH}}`
**Purpose:** {{DESCRIPTION}}
**Auth required:** Yes / No

**Request:**
```json
{
  "{{field}}": "{{type}}"
}
```

**Response (200):**
```json
{
  "{{field}}": "{{type}}"
}
```

**Errors:**
- `400` — {{REASON}}
- `403` — {{REASON}}
- `404` — {{REASON}}

---

## 5. UI Screens

### {{Screen Name}}
**Route:** `{{/path}}`
**Purpose:** {{DESCRIPTION}}

**Key components:**
- {{COMPONENT_1}} — {{PURPOSE}}
- {{COMPONENT_2}} — {{PURPOSE}}

**User flow:**
1. {{STEP_1}}
2. {{STEP_2}}

**Empty state:** {{DESCRIPTION}}
**Loading state:** {{DESCRIPTION}}
**Error state:** {{DESCRIPTION}}

---

## 6. Business Logic & Rules

- **{{RULE_NAME}}:** {{DESCRIPTION}}
- **Validation:** {{VALIDATION_RULES}}
- **Calculations:** {{CALCULATION_LOGIC}}
- **Edge cases:**
  - {{EDGE_CASE_1}}
  - {{EDGE_CASE_2}}

---

## 7. Integration Points

| Module | How we use it | Direction |
|--------|--------------|-----------|
| {{module}} | {{usage}} | Reads from / Writes to |

---

## 8. Acceptance Criteria

- [ ] {{CRITERION_1}}
- [ ] {{CRITERION_2}}
- [ ] {{CRITERION_3}}
- [ ] All {{UNIT_TEST_COVERAGE}} tests pass
- [ ] Accessible: keyboard navigable, screen reader compatible
- [ ] Mobile responsive

---

## 9. Out of Scope

The following are **explicitly not** part of this module:
- {{OUT_OF_SCOPE_1}}
- {{OUT_OF_SCOPE_2}}

---

## 10. Open Questions

- [ ] {{QUESTION_1}}
- [ ] {{QUESTION_2}}
TPL_SPEC_EOF

echo -e "  ${GREEN}✓${RESET} .claude/templates/MODULE_SPEC.md"

# =============================================================================
# TEMPLATE: CLAUDE_MODULE.md
# =============================================================================
cat > .claude/templates/CLAUDE_MODULE.md << 'TPL_CLAUDE_MODULE_EOF'
# Module Implementation Guide: {{MODULE_NAME}}

> Module-specific rules and patterns for AI-assisted implementation.
> Read this alongside `SPEC.md` and the root `CLAUDE.md`.

---

## Patterns to Follow

> Populated as the module is implemented. Add examples from the codebase.

- **{{PATTERN_NAME}}:** {{DESCRIPTION}}
  ```typescript
  // Example
  ```

---

## Conventions in This Module

- File structure: `{{DESCRIBE_FILE_STRUCTURE}}`
- State management: `{{HOW_STATE_IS_MANAGED}}`
- Data fetching: `{{HOW_DATA_IS_FETCHED}}`
- Error handling: `{{HOW_ERRORS_ARE_HANDLED}}`

---

## Module Boundaries

✅ **This module owns:**
- `{{FILE_OR_DIRECTORY}}`

🔗 **This module reads from:**
- `{{OTHER_MODULE}}` — `{{WHAT_WE_USE}}`

🚫 **This module must NOT:**
- {{RESTRICTION_1}}
- {{RESTRICTION_2}}

---

## Known Gotchas

- **{{GOTCHA_1}}:** {{DESCRIPTION_AND_FIX}}

---

## Test Patterns

```typescript
// How tests are structured in this module
{{TEST_EXAMPLE}}
```
TPL_CLAUDE_MODULE_EOF

echo -e "  ${GREEN}✓${RESET} .claude/templates/CLAUDE_MODULE.md"

# =============================================================================
# .gitignore addition
# =============================================================================
if [ -f ".gitignore" ]; then
  if ! grep -q "specs/research" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# AI Project Kit — never commit secrets captured in research" >> .gitignore
    echo "specs/research/credentials*" >> .gitignore
  fi
else
  cat > .gitignore << 'GITIGNORE_EOF'
# AI Project Kit
specs/research/credentials*
.env
.env.local
.env*.local
GITIGNORE_EOF
fi
echo -e "  ${GREEN}✓${RESET} .gitignore"

# =============================================================================
# README for the kit itself
# =============================================================================
cat > .claude/README.md << 'KIT_README_EOF'
# AI Project Kit

This directory powers spec-first, AI-assisted development for this project.

## What's Here

```
.claude/
  commands/         Slash commands — type these in Claude Code
    init.md         /project:init [idea]
    research.md     /project:research [topic]
    blueprint.md    /project:blueprint
    spec.md         /project:spec [module]
    module.md       /project:module [name]
    review.md       /project:review
    status.md       /project:status
  templates/        Spec templates used by slash commands
    MASTER_BLUEPRINT.md
    MODULE_SPEC.md
    CLAUDE_MODULE.md
  README.md         This file

specs/              Generated spec documents (committed to git)
  RESEARCH.md       Domain research
  MASTER_BLUEPRINT.md  Architecture source of truth
  ROADMAP.md        Implementation order
  modules/          Per-module specs
    [module]/
      SPEC.md
      CLAUDE.md

CLAUDE.md           Root operating model (read by Claude Code automatically)
LEARNINGS.md        Accumulated project learnings
```

## Quickstart

1. Open Claude Code in this project directory
2. Type: `/project:init [your project idea]`
3. Follow the workflow — research → blueprint → specs → implement

## Adding a Module Mid-Project

```
/project:spec [module-name]    # Creates the spec
/project:module [module-name]  # Begins implementation
```

## After Each Session

```
/project:review    # Captures learnings, updates CLAUDE.md
```
KIT_README_EOF

echo -e "  ${GREEN}✓${RESET} .claude/README.md"

# =============================================================================
# Brownfield-specific additions
# =============================================================================
if [ "$PROJECT_MODE" = "brownfield" ]; then
  mkdir -p specs/existing-system

  cat > specs/existing-system/AUDIT.md << 'AUDIT_EOF'
# Existing System Audit

> Complete this before running `/project:init` or `/project:blueprint`.
> Understanding what exists prevents AI from reinventing or breaking things.

---

## Tech Stack (Existing)

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| | | | |

---

## Current Module Structure

> What modules/features exist today?

| Module | Location | Status | Notes |
|--------|----------|--------|-------|
| | | Working / Broken / Partial | |

---

## What Works Well

> Don't let AI change these without strong reason.

- {{WORKING_THING_1}}

---

## Known Problems / Technical Debt

> Areas where AI assistance would be most valuable.

- {{PROBLEM_1}}

---

## Constraints

> Things the AI must not change (e.g. external integrations, locked APIs,
> legacy compatibility requirements).

- {{CONSTRAINT_1}}

---

## First Priorities

What should be tackled first?

1. {{PRIORITY_1}}
2. {{PRIORITY_2}}
AUDIT_EOF

  echo -e "  ${GREEN}✓${RESET} specs/existing-system/AUDIT.md (brownfield mode)"

  # Add brownfield note to CLAUDE.md
  cat >> CLAUDE.md << 'BROWNFIELD_EOF'

---

## Brownfield Mode — Additional Rules

This is an **existing codebase**. These rules apply on top of everything above:

- **Audit first.** Read `specs/existing-system/AUDIT.md` before proposing
  any changes. Understand what exists before adding to it.
- **Match existing patterns.** Do not introduce new patterns that conflict
  with the established codebase conventions — even if the new pattern is
  better. Consistency beats perfection.
- **Test coverage before refactoring.** If an area lacks tests, add tests
  before changing behaviour. Never refactor untested code.
- **Spec the existing system.** When adding a feature to an existing module,
  write a spec delta (what's being ADDED/MODIFIED) rather than a full spec.
- **Flag conflicts.** If the spec you've been given contradicts the existing
  code, flag it immediately. Do not silently resolve the conflict.
BROWNFIELD_EOF

  echo -e "  ${GREEN}✓${RESET} CLAUDE.md updated with brownfield rules"
fi

# =============================================================================
# Done
# =============================================================================
echo ""
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  ✅  AI Project Kit bootstrapped successfully${RESET}"
echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}Files created:${RESET}"
echo "  CLAUDE.md                      ← Read automatically by Claude Code"
echo "  LEARNINGS.md                   ← Updated each session"
echo "  .claude/commands/init.md       → /project:init [idea]"
echo "  .claude/commands/research.md   → /project:research [topic]"
echo "  .claude/commands/blueprint.md  → /project:blueprint"
echo "  .claude/commands/spec.md       → /project:spec [module]"
echo "  .claude/commands/module.md     → /project:module [name]"
echo "  .claude/commands/review.md     → /project:review"
echo "  .claude/commands/status.md     → /project:status"
echo "  .claude/templates/             ← Spec templates"
echo "  specs/                         ← Your spec documents live here"
if [ "$PROJECT_MODE" = "brownfield" ]; then
  echo "  specs/existing-system/AUDIT.md ← Fill this in before starting"
fi
echo ""
echo -e "${BOLD}Next step:${RESET}"
if [ "$PROJECT_MODE" = "brownfield" ]; then
  echo -e "  1. Fill in ${YELLOW}specs/existing-system/AUDIT.md${RESET} (understand what exists)"
  echo -e "  2. Open Claude Code and type: ${CYAN}/project:status${RESET}"
else
  echo -e "  Open Claude Code and type: ${CYAN}/project:init \"your project idea here\"${RESET}"
  echo ""
  echo -e "  Example: ${CYAN}/project:init \"CRM solution for the UK education market\"${RESET}"
fi
echo ""

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
FILE_COUNT=$(find . -maxdepth 2 \( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.rb" -o -name "*.go" \) -not -path "./node_modules/*" -not -path "./.claude/*" 2>/dev/null | wc -l | tr -d ' ')

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
mkdir -p .claude/hooks
mkdir -p .claude/lib
mkdir -p .claude/skills/project-init
mkdir -p .claude/skills/project-research
mkdir -p .claude/skills/project-blueprint
mkdir -p .claude/skills/project-spec
mkdir -p .claude/skills/project-module
mkdir -p .claude/skills/project-execute
mkdir -p .claude/skills/project-review
mkdir -p .claude/skills/project-security-review
mkdir -p .claude/skills/project-status
mkdir -p .claude/skills/project-deploy
mkdir -p .claude/skills/project-test
mkdir -p .claude/parallel/locks
mkdir -p .claude/parallel/learnings
mkdir -p .kit-orchestration
mkdir -p specs/modules
mkdir -p specs/sessions

if [ ! -f ".claude/parallel/tracks.json" ]; then
  cat > ".claude/parallel/tracks.json" << 'TRACKS_JSON_EOF'
{"tracks": [], "merge_order": [], "harness": null}
TRACKS_JSON_EOF
  echo -e "  ${GREEN}✓${RESET} .claude/parallel/tracks.json"
fi

if [ ! -f ".worktreeinclude" ]; then
  cat > ".worktreeinclude" << 'WORKTREEINCLUDE_EOF'
.env
.env.local
.dev.vars
WORKTREEINCLUDE_EOF
  echo -e "  ${GREEN}✓${RESET} .worktreeinclude"
fi

# =============================================================================
# CLAUDE.md
# =============================================================================
cat > CLAUDE.md << 'CLAUDE_EOF'
# CLAUDE.md — Operating Model for AI Project Kit

This document defines how Claude operates within the AI Project Kit. It serves as the instruction set for every session and guides decision-making at all levels.

---

## The Prime Directive

**Every Claude session operates as a dedicated project specialist.** The goal is not to jump between tasks, but to drive ONE project forward from concept to completion in a single unbroken workflow.

A session succeeds when:
- It captures the full scope of work needed
- It executes each phase in sequence without distraction
- It captures learnings at the end for future sessions
- The project advances measurably (code written, architecture decided, tests passing, deployed)

---

## Trigger Recognition

Sessions are triggered by explicit commands that signal intent:

| Trigger | Meaning |
|---------|---------|
| `/project-init [idea]` | New project or major feature — start from zero |
| `/project-research [topic]` | Deep research mode — explore domain/tech/regulation |
| `/project-blueprint` | Architecture mode — system design or regeneration |
| `/project-spec [module]` | Specification mode — detailed module design |
| `/project-module [name]` | Implementation mode — code and tests |
| `/project-execute [module]` | Dual-harness mode: hand a fully-specced module to Codex CLI for implementation while Claude orchestrates. Live tmux pane in your most-recent attached session. |
| `/project-security-review` | Independent Agent-based security review of pending changes — UK GDPR / healthcare focus. |
| `/project-review` | Wrap-up mode — capture learnings |
| `/project-status` | Dashboard — show current state |
| `/project-deploy` | Deployment mode — deploy and verify |
| `/project-test` | Testing mode — comprehensive test pass |

These are not suggestions—they are **explicit signals** that Claude should enter a specific operational mode.

---

## Workflow

Every Claude session follows a 5-phase sequence, executed in order:

### Phase 1: Plan
- Understand the task
- Identify unknowns
- Map dependencies
- Document assumptions
- Create a todo list if multi-step

**Exit criteria:** Clear scope, no surprises ahead

### Phase 2: Research (if needed)
- Answer unknowns via Exa/Ref documentation search
- Verify current best practices for the stack
- Check competitor implementations (market context)
- Record findings for later reference

**Exit criteria:** All technical questions answered, patterns documented

### Phase 3: Execute
- Build incrementally (small, testable units)
- Verify each piece before continuing
- Keep terminal output clean
- Push incremental commits with clear messages

**Exit criteria:** Code written, feature complete, passing tests

### Phase 4: Verify
- Visually test the change (Playwright if UI)
- Check console for errors
- Verify against acceptance criteria
- Document any gaps or next steps

**Exit criteria:** Change works as intended, no breaking changes introduced

### Phase 5: Capture
- Summarize what was built
- Document unexpected learnings
- Note patterns for reuse
- Update LEARNINGS.md
- Link to relevant PRs/commits

**Exit criteria:** Learnings captured, handoff ready for next session

---

## Dual-Harness Workflow

Some tasks are big enough that you want Claude (Opus 4.7) to plan and review while Codex CLI (gpt-5.5) does the heavy implementation. The kit supports this via `/project-execute`:

- **Plan + Review**: Claude Code (this session). Reads specs, builds the dispatch prompt, reads back the scrubbed structured report + JSONL events, smoke-tests the working tree, **applies commits proposed by Codex** (orchestrator-commits pattern), summarises, runs the review skill.
- **Execute**: Codex CLI (`gpt-5.5`, medium reasoning effort), launched via `.claude/lib/dispatch.sh` with `--json --output-schema`. Runs in a live tmux pane that splits into your most-recent attached session.

Single-harness mode (`/project-module`) keeps everything in Claude. Use dual-harness when the module is large, well-specced, and you want to watch implementation happen in real time.

**Orchestrator-commits is canonical.** Codex does NOT commit. It leaves the working tree dirty and emits a structured final report (schema at `.claude/skills/project-execute/codex-report-schema.json`) listing `proposed_commits`. Claude reviews the diff, smoke-tests, and applies commits with `Co-Authored-By` attribution. This sidesteps Codex's `workspace-write` sandbox `.git` restriction and gives a verification gate that catches spec deviations and training-data bleed-through before they land in history.

**Prerequisites**:

- `npm install -g @openai/codex` (Codex CLI 0.128+ tested).
- Authenticate. Two paths with different model availability:
  - `codex login` — ChatGPT auth. Required for `gpt-5.5` access without API tier requirements.
  - `export OPENAI_API_KEY=…` — API-key auth. `gpt-5.5` requires Tier 1+ on your OpenAI org; if your org lacks the tier, the preflight will fail with a model-availability error.
- A tmux session with at least one attached client. dispatch.sh detects the most-recent attached client via `tmux list-clients` — Claude Code itself doesn't have to be inside tmux as long as one client is attached somewhere. Override with `KIT_TMUX_SESSION=<name>` when you have multiple sessions.

Portability: dispatch.sh works on Linux and macOS. Requires GNU coreutils (`timeout` on Linux, `gtimeout` after `brew install coreutils` on macOS). Lock is mkdir-based (no `flock` dependency).

---

## Available Slash Commands

| Command | Usage | Purpose |
|---------|-------|---------|
| `/project-init` | `/project-init [idea]` | Start a new project or major feature from scratch |
| `/project-research` | `/project-research [topic]` | Deep research on domain, technology, or regulations |
| `/project-blueprint` | `/project-blueprint` | Generate or regenerate master architecture design |
| `/project-spec` | `/project-spec [module]` | Create or update a detailed module specification |
| `/project-module` | `/project-module [name]` | Implement a specific module end-to-end |
| `/project-review` | `/project-review` | End-of-session: capture learnings and progress |
| `/project-status` | `/project-status` | Display project dashboard and current state |
| `/project-deploy` | `/project-deploy` | Deploy to staging/production and verify |
| `/project-test` | `/project-test` | Comprehensive test pass across all modules |
| `/project-execute` | `/project-execute [module]` | Dual-harness mode: hand a fully-specced module to Codex CLI for implementation while Claude orchestrates |
| `/project-security-review` | `/project-security-review` | Independent Agent-based security review of pending changes — UK GDPR / healthcare focus. |

---

## Available Tools & Integrations

Claude has access to specialized tools for research, testing, and deployment. Use these before implementing:

### Research & Documentation
- **Exa Search** (`web_search_exa`) — Web search with category filters (company, research paper, people). Use for market research, competitor analysis, and domain exploration.
- **Exa Code Context** (`get_code_context_exa`) — Find code examples from GitHub, Stack Overflow, and official docs. Use for framework patterns and implementation examples.
- **Ref Documentation** (`ref_search_documentation`) — Search framework and library documentation. Use to verify API patterns, latest versions, and best practices.
- **Ref URL Reader** (`ref_read_url`) — Read full documentation pages. Use after finding relevant docs via search.

### Testing & Verification
- **Playwright** — Browser automation for E2E testing and visual verification. Navigate pages, take screenshots, check accessibility, read console errors.
- **Chrome Automation** — Alternative browser control for testing and verification.

### Deployment
- **Vercel** — Deploy previews and production builds. Monitor build logs, check deployment status.

### Frontend Development
- **web-artifacts-builder skill** — React, Tailwind CSS, and shadcn/ui component patterns. Consult when building frontend modules.

### Hooks
- **PreCompact snapshot hook** (`.claude/hooks/pre-compact.sh`) — Writes recovery snapshots into `specs/sessions/` before conversation compaction. Configured by `.claude/settings.json`.
- **SessionStart compact backup** — On compacted-session resume, prints the latest snapshot path when one exists. Claude Code issue #13572 means PreCompact may not fire reliably for `/compact` on some versions, so treat this as best-effort recovery.

### Rule: Research Before Implementing
**Before implementing any technical pattern you're uncertain about, use Ref or Exa to look up current documentation.** Don't rely on potentially outdated training knowledge for version-specific API details. This ensures consistency with the latest tooling and avoids rework.

---

## Spec Hierarchy

Specifications follow a three-tier hierarchy from abstract to concrete:

### Tier 1: Blueprint (System Design)
- Component relationships
- Data flow
- Integration points
- Risk assessment

**Example:** "User service talks to Auth service via REST; both write to PostgreSQL"

### Tier 2: Module Spec (Detailed Design)
- Function signatures
- Input/output contracts
- Error handling
- Dependencies

**Example:** "POST /users takes { email, password }, returns { id, token } or { error }"

### Tier 3: Code (Implementation)
- Actual working code
- Tests
- Documentation
- Deployment

**Example:** Implemented function with type safety, error handling, and unit tests

Each tier is concrete enough that a developer can execute it without debate. Never skip a tier.

---

## Session Rules

1. **One session = one task.** Don't start a second task until the first is captured and ready for handoff.

2. **Plan mode first.** Before writing code, create a todo list and confirm scope.

3. **Research before building.** Use Ref or Exa to verify technical patterns before implementing.

4. **Commit early, commit often.** Push small, focused commits with clear messages. Easier to review and revert if needed.

5. **Verify as you go.** Don't leave broken code in the branch. Each phase should be testable.

6. **Capture learnings at the end.** Spend 5 minutes summarizing what you learned and what surprised you. Record in LEARNINGS.md.

7. **Link to context.** When you finish, leave breadcrumbs: commit hashes, PR links, file paths. Next session should be able to pick up immediately.

---

## Boundaries

### ✅ Always
- Use Exa/Ref to verify technical details before implementing
- Visually verify UI changes with Playwright when possible
- Commit frequently with clear messages
- Check test output before declaring success
- Ask for clarification if scope is ambiguous
- Use type safety (TypeScript, Pydantic, etc.)
- Document public APIs with examples
- Link learnings to specific code changes

### ⚠️ Ask Before
- Creating major new files or directories
- Changing system architecture
- Adding new dependencies
- Modifying existing APIs
- Deleting code or data
- Deploying to production
- Merging to main branch

### 🚫 Never
- Commit without testing
- Skip error handling
- Leave console warnings in code
- Assume API behavior—read the docs
- Deploy broken branches
- Merge without a clear reason in the commit message
- Ignore accessibility concerns in UI

---

## Stack Detection

Before starting implementation, answer these four questions to understand the project:

1. **Frontend:** React? Vue? Svelte? Plain HTML? (or N/A if backend-only)
2. **Backend:** Node.js? Python? Go? Rust? (or N/A if frontend-only)
3. **Database:** PostgreSQL? MongoDB? Firestore? (or N/A if not applicable)
4. **Deployment:** Vercel? Docker? Lambda? Self-hosted? (or N/A)

These determine which tools and patterns you'll use throughout.

---

## Quality Standards

- **Code:** Passes linting, has no console errors, uses type safety
- **Tests:** Unit tests for logic, E2E tests for user flows, passing locally before push
- **Docs:** Public functions have docstrings/comments, modules have README sections, complex logic is explained
- **UX:** Accessible (WCAG AA minimum), responsive (mobile-first), keyboard-navigable
- **Deployment:** Builds without warnings, passes CI/CD, rolls back cleanly if issues found

---

## Learnings

After every session, update `LEARNINGS.md` with:

1. **What worked well** — patterns, tools, approaches that accelerated progress
2. **What was harder than expected** — gotchas, surprises, missing documentation
3. **What to do differently next time** — concrete changes for future sessions
4. **Links to the work** — commit hashes, PRs, files touched

This creates a knowledge base that future sessions can learn from immediately.

---

## Session Checklist

At the **start** of a session:
- [ ] Read this file (you're doing it now)
- [ ] Check LEARNINGS.md for context
- [ ] Run `/project-status` if this is a continuation
- [ ] Create a todo list
- [ ] Confirm scope with the user

At the **end** of a session:
- [ ] All code tested and committed
- [ ] All todos marked done or moved to next session
- [ ] LEARNINGS.md updated
- [ ] Summary provided with links to work
- [ ] Clear handoff notes for next session

---

**This is the operating model. Follow it.**
CLAUDE_EOF

echo -e "  ${GREEN}✓${RESET} CLAUDE.md"

# =============================================================================
# LEARNINGS.md
# =============================================================================
cat > LEARNINGS.md << 'LEARNINGS_EOF'
# Project Learnings

This file is updated at the end of every session. It captures mistakes, discoveries, patterns that work, and patterns that don't. Reading this at the start of an implementation session prevents repeating mistakes.

> **Maintained by:** Claude Code (auto-updated via `/project-review`)
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
# SKILLS AND COMMANDS
# =============================================================================

cat > .claude/skills/project-init/SKILL.md << 'SKILL_INIT_EOF'
---
name: project-init
description: "Initialise a new software project with full spec-first workflow — research, architecture, module specs, and roadmap. Use this whenever someone says 'build me a...', 'I want to create...', 'new project', 'start a project', or describes a product idea. Also use for major new feature areas within an existing project."
effort: high
---

# Project Initialization Skill

This skill guides you through a complete 7-phase spec-first project setup. Follow each phase sequentially, save outputs to the `specs/` directory, and maintain clarity throughout.

## Phase 1: Clarify the Vision

Engage with the user to deeply understand their project idea:

- **User Problem:** What pain point or opportunity does this solve?
- **Target Users:** Who are the primary users? Secondary users?
- **Success Criteria:** How will we know this project succeeded?
- **Constraints:** Budget, timeline, compliance, technical, platform constraints?
- **Out of Scope:** What explicitly will NOT be built?

Ask follow-up questions until you have a crystal-clear vision. Create a summary document: `specs/PROJECT_BRIEF.md` with sections: Overview, Problem Statement, Target Users, Success Criteria, Constraints, Out of Scope.

## Phase 2: Domain Research

Conduct structured research on the domain, market, competitors, and technical landscape. Explicitly use available research tools:

**For Market & Competitor Analysis:**
- Use `web_search_exa` with `category: "company"` to find competitor websites, products, and business models.
- Search queries like: "[product type] competitor analysis", "[industry] market landscape", "[use case] solutions".
- Document what competitors do well, weaknesses, pricing, positioning.

**For Academic & Industry Research:**
- Use `web_search_exa` with `category: "research paper"` to find peer-reviewed studies, industry reports, and technical papers relevant to your domain.
- Search queries like: "[domain] best practices", "[problem area] research", "[technology] case studies".

**For General Market Context:**
- Use `web_search_exa` (no category filter) for recent news, trends, adoption rates, and emerging patterns.

**For Technical Foundation (after tech stack decisions):**
- Use `ref_search_documentation` to find official documentation for frameworks, libraries, and APIs you're considering.
- Use `get_code_context_exa` to find production code examples and common patterns.

Record findings in `specs/RESEARCH.md` with sections: Market Landscape, Competitor Analysis, Key Trends, Regulatory Considerations, Technical Considerations, Recommendations.

## Phase 3: Module Identification

Based on the vision and research, decompose the project into logical modules. Each module should represent a cohesive business capability or feature area.

For typical web projects, consider:
- Authentication & User Management
- Core Domain Modules (e.g., Content, Products, Orders)
- Admin & Management Interfaces
- API/Backend Services
- Infrastructure & Deployment
- Observability & Analytics

Ask: "What can be built independently? What has minimal coupling? What represents distinct user workflows?"

Create a rough module list with brief descriptions and dependencies. Save as `specs/MODULES.md`.

## Phase 4: Master Blueprint

Create the comprehensive architecture blueprint by:

1. **Technology Stack Decision:** Choose your core technologies (frontend framework, backend runtime, database, infrastructure, auth, etc.). If not yet decided, answer these 4 questions:
   - What frontend framework aligns with your UI complexity and team skills? (React, Vue, Svelte, etc.)
   - What backend stack? (Node.js, Python, Go, etc. + framework)
   - What database? (Relational, document, graph, key-value?)
   - What deployment target? (Vercel, AWS, Docker, traditional servers?)

2. **Verify Latest Versions:** Use `ref_search_documentation` to check the current stable versions of chosen technologies and their recommended patterns.

3. **Find Production Examples:** Use `get_code_context_exa` with queries like "[framework] [architecture pattern] example", "[stack] production architecture" to find real-world implementations of your planned approach.

4. **Create the Blueprint:** Fill out the blueprint template with all 9 sections. Include version numbers, source URLs, and rationale for each choice.

5. **Review & Approve:** Present a summary of key decisions and architectural constraints. Ask the user for approval before saving to `specs/MASTER_BLUEPRINT.md`.

## Phase 5: Module Specifications

For each module identified in Phase 3, create a detailed module specification:

1. **Read the template:** `module-spec-template.md` (bundled here)
2. **Complete all sections:**
   - Purpose: Why does this module exist?
   - User Stories: Concrete workflows this module enables
   - Data Model: TypeScript interfaces defining the domain
   - API/Server Actions: Endpoints or functions this module exposes
   - UI Screens: Key screens and user flows
   - Business Logic & Rules: Validation, constraints, workflows
   - Integration Points: What other modules depend on this? What does this depend on?
   - Acceptance Criteria: How do we know it's complete?
   - Out of Scope: What's explicitly excluded?
   - Open Questions: Unknowns to resolve

3. **Save each spec:** `specs/modules/[module-name]/SPEC.md`

4. **Link specs together:** Ensure dependencies are clear and cross-module contracts are documented.

## Phase 6: Module CLAUDE.md Files

For each module, create a CLAUDE.md guide that helps future Claude instances understand module conventions and patterns:

1. **Read the template:** `claude-module-template.md` (bundled here)
2. **Document:**
   - Patterns to Follow: Architectural patterns specific to this module (MVC, service layer, repository pattern, etc.)
   - Conventions in This Module: Naming, file structure, error handling, logging conventions
   - Module Boundaries: What this module owns, what it reads from other modules, what it must NEVER do
   - Known Gotchas: Common mistakes, performance traps, threading issues, etc.
   - Test Patterns: Unit test structure, mock patterns, integration test approach

3. **Save:** `specs/modules/[module-name]/CLAUDE.md`

## Phase 7: Implementation Roadmap

Create a prioritized implementation plan:

1. **Identify Phase 0 (Infrastructure):** What must be built first? Database schema, auth system, API scaffolding, deployment pipeline?

2. **Sequence Modules:** Order remaining modules by:
   - User story priority (what delivers user value first?)
   - Dependency graph (what unblocks other work?)
   - Risk (build risky unknowns early)
   - Team capacity (balance parallelizable vs. sequential work)

3. **Create Sprints/Milestones:** Break into 2–4 week chunks with clear deliverables.

4. **Define Exit Criteria:** What does "done" look like for each sprint?

5. **Save:** `specs/ROADMAP.md` with sections: Phase 0 (Infrastructure), Milestones, Sprint Details, Risk Mitigation, Success Metrics.

## Output Structure

After completing all 7 phases, you will have created:

```
specs/
├── PROJECT_BRIEF.md           (Phase 1)
├── RESEARCH.md                (Phase 2)
├── MODULES.md                 (Phase 3)
├── MASTER_BLUEPRINT.md        (Phase 4)
├── ROADMAP.md                 (Phase 7)
└── modules/
    ├── [module-1]/
    │   ├── SPEC.md            (Phase 5)
    │   └── CLAUDE.md          (Phase 6)
    ├── [module-2]/
    │   ├── SPEC.md
    │   └── CLAUDE.md
    └── ...
```

All specs are markdown files stored in version control, reviewed collaboratively, and updated as the project evolves.

## Execution

Start with the user's project idea from `$ARGUMENTS`. Execute each phase in order, asking clarifying questions, saving outputs, and building a comprehensive specification before implementation begins.
SKILL_INIT_EOF

echo -e "  ${GREEN}✓${RESET} .claude/skills/project-init/SKILL.md"

cat > .claude/skills/project-init/blueprint-template.md << 'TEMPLATE_BLUEPRINT_EOF'
# Master Architecture Blueprint

> **Status:** {{STATUS}} (Draft / Approved / In Progress)
> **Last Updated:** {{DATE}}
> **Project:** {{PROJECT_NAME}}
> **Team:** {{TEAM_MEMBERS}}

## 1. Project Overview

**Problem Statement:** {{PROBLEM_STATEMENT}}

**Solution Overview:** {{SOLUTION_OVERVIEW}}

**Key Success Criteria:**
- {{CRITERION_1}}
- {{CRITERION_2}}
- {{CRITERION_3}}

**Scope Boundaries:** {{SCOPE_BOUNDARIES}}

---

## 2. Tech Stack

| Layer | Technology | Version | Rationale |
|-------|-----------|---------|-----------|
| Frontend Framework | {{FRONTEND_FRAMEWORK}} | {{VERSION}} | {{RATIONALE}} |
| Frontend Build & Tooling | {{FRONTEND_BUILD}} | {{VERSION}} | {{RATIONALE}} |
| Backend Runtime | {{BACKEND_RUNTIME}} | {{VERSION}} | {{RATIONALE}} |
| Backend Framework | {{BACKEND_FRAMEWORK}} | {{VERSION}} | {{RATIONALE}} |
| Database (Primary) | {{PRIMARY_DATABASE}} | {{VERSION}} | {{RATIONALE}} |
| Database (Cache/Sessions) | {{CACHE_DATABASE}} | {{VERSION}} | {{RATIONALE}} |
| Authentication | {{AUTH_SOLUTION}} | {{VERSION}} | {{RATIONALE}} |
| API Style | {{API_STYLE}} | — | {{RATIONALE}} |
| Deployment Platform | {{DEPLOYMENT_PLATFORM}} | — | {{RATIONALE}} |
| CI/CD | {{CI_CD_TOOL}} | — | {{RATIONALE}} |
| Monitoring & Logging | {{MONITORING_SOLUTION}} | — | {{RATIONALE}} |
| Testing Framework | {{TEST_FRAMEWORK}} | {{VERSION}} | {{RATIONALE}} |

**Version Strategy:** {{VERSION_STRATEGY}}

**Technology Constraints:** {{CONSTRAINTS}}

---

## 3. Data Model

### Core Entities

```typescript
// {{ENTITY_1}}
interface {{ENTITY_1}} {
  id: string;
  {{FIELD_1}}: {{TYPE}};
  {{FIELD_2}}: {{TYPE}};
  createdAt: Date;
  updatedAt: Date;
}

// {{ENTITY_2}}
interface {{ENTITY_2}} {
  id: string;
  {{FIELD_1}}: {{TYPE}};
  {{FIELD_2}}: {{TYPE}};
  createdAt: Date;
  updatedAt: Date;
}
```

### Relationships

{{ENTITY_RELATIONSHIP_DIAGRAM}}

**Example:** {{EXAMPLE_1}}

### Key Design Decisions

- **Primary Key Strategy:** {{PRIMARY_KEY_STRATEGY}}
- **Soft Deletes:** {{SOFT_DELETE_POLICY}}
- **Audit Trail:** {{AUDIT_POLICY}}
- **Multi-tenancy:** {{TENANCY_MODEL}} (single-tenant / multi-tenant / hybrid)
- **Scalability Considerations:** {{SCALABILITY_NOTES}}

---

## 4. API Design Patterns

### API Style
**Style:** {{API_STYLE}} (REST / GraphQL / tRPC / gRPC / Hybrid)

### Base URL & Versioning
```
Production: https://api.{{DOMAIN}}/v1
Staging: https://staging-api.{{DOMAIN}}/v1
```

### Authentication & Authorization
- **Method:** {{AUTH_METHOD}} (JWT / OAuth / Session / API Key / mTLS)
- **Token Lifetime:** {{TOKEN_LIFETIME}}
- **Scopes/Permissions Model:** {{PERMISSIONS_MODEL}}
- **Rate Limiting:** {{RATE_LIMIT_STRATEGY}}

### Naming Conventions
- **Endpoint Naming:** {{ENDPOINT_NAMING}} (e.g., `/api/v1/resources`, `/api/v1/resources/{id}/sub-resources`)
- **Field Naming:** {{FIELD_NAMING}} (camelCase / snake_case)
- **Error Field Names:** {{ERROR_NAMING}}

### Error Response Format
```json
{
  "error": {
    "code": "{{ERROR_CODE}}",
    "message": "{{ERROR_MESSAGE}}",
    "details": { "{{DETAIL_KEY}}": "{{DETAIL_VALUE}}" }
  }
}
```

**Standard Error Codes:** {{ERROR_CODES}}

### Response Format
```json
{
  "data": { "{{RESOURCE}}" },
  "meta": { "requestId": "uuid", "timestamp": "ISO8601" }
}
```

### Pagination (if applicable)
- **Style:** {{PAGINATION_STYLE}} (offset / cursor / keyset)
- **Default Limit:** {{DEFAULT_PAGE_SIZE}}
- **Max Limit:** {{MAX_PAGE_SIZE}}

---

## 5. Shared UI Patterns

### Design System
- **Color Palette:** {{COLOR_PALETTE}}
- **Typography:** {{TYPOGRAPHY_SPECS}}
- **Component Library:** {{COMPONENT_LIBRARY}} (custom / Material UI / shadcn/ui / other)
- **Icon Library:** {{ICON_LIBRARY}}

### Layout Patterns
- **Page Structure:** {{PAGE_STRUCTURE_PATTERN}}
- **Navigation:** {{NAV_PATTERN}} (sidebar / top nav / tabbed / etc.)
- **Responsive Breakpoints:** {{RESPONSIVE_BREAKPOINTS}}
- **Mobile-first:** {{MOBILE_FIRST_APPROACH}}

### Form Patterns
- **Validation Display:** {{VALIDATION_PATTERN}} (inline / summary / field-level)
- **Error Messaging:** {{ERROR_MESSAGE_PATTERN}}
- **Field Labeling:** {{FIELD_LABEL_PATTERN}}
- **Submission Behavior:** {{SUBMISSION_BEHAVIOR}}

### Loading & Skeleton States
- **Loading Indicator:** {{LOADING_INDICATOR_STYLE}}
- **Skeleton Components:** {{SKELETON_USAGE}}
- **Progressive Enhancement:** {{PROGRESSIVE_ENHANCEMENT}}

### Navigation & Routing
- **Route Structure:** {{ROUTE_STRUCTURE}}
- **Deep Linking:** {{DEEP_LINKING_SUPPORT}}
- **Breadcrumbs:** {{BREADCRUMB_USAGE}}
- **404/Error Pages:** {{ERROR_PAGE_PATTERN}}

### Accessibility (a11y)
- **WCAG Level:** {{WCAG_LEVEL}} (A / AA / AAA)
- **Keyboard Navigation:** {{KEYBOARD_NAV_REQUIRED}}
- **Screen Reader Testing:** {{SCREEN_READER_TOOLS}}

---

## 6. Modules

| Module | Priority | Description | Depends On | Estimated Effort |
|--------|----------|-------------|-----------|------------------|
| {{MODULE_1}} | P0/P1/P2 | {{DESCRIPTION}} | {{DEPENDS}} | {{EFFORT}} |
| {{MODULE_2}} | P0/P1/P2 | {{DESCRIPTION}} | {{DEPENDS}} | {{EFFORT}} |
| {{MODULE_3}} | P0/P1/P2 | {{DESCRIPTION}} | {{DEPENDS}} | {{EFFORT}} |
| {{MODULE_N}} | P0/P1/P2 | {{DESCRIPTION}} | {{DEPENDS}} | {{EFFORT}} |

**Module Ownership:** {{MODULE_OWNERSHIP_DETAILS}}

---

## 7. Infrastructure & Deployment

### Hosting & Infrastructure
- **Deployment Platform:** {{DEPLOYMENT_PLATFORM}}
- **Infrastructure as Code:** {{IAC_TOOL}} (Terraform / CloudFormation / ARM / CDK / other)
- **Container Strategy:** {{CONTAINER_STRATEGY}} (Docker / containerless / hybrid)
- **Database Hosting:** {{DATABASE_HOSTING}}
- **CDN & Static Assets:** {{CDN_SOLUTION}}

### Environment Strategy
- **Environments:** {{ENVIRONMENTS}} (dev / staging / production / preview)
- **Environment Parity:** {{ENVIRONMENT_PARITY_APPROACH}}
- **Secrets Management:** {{SECRETS_MANAGEMENT}}

### CI/CD Pipeline
```
Trigger → Build → Test → Deploy Staging → Integration Tests → Deploy Production
```

- **Tool:** {{CI_CD_TOOL}}
- **Branch Strategy:** {{BRANCH_STRATEGY}} (main / develop / feature branches)
- **Deployment Approvals:** {{DEPLOYMENT_APPROVALS}}
- **Rollback Strategy:** {{ROLLBACK_STRATEGY}}

### Monitoring, Logging & Observability
- **Logging:** {{LOGGING_SOLUTION}}
- **Metrics & APM:** {{METRICS_SOLUTION}}
- **Error Tracking:** {{ERROR_TRACKING_SOLUTION}}
- **Uptime Monitoring:** {{UPTIME_MONITORING}}
- **Alert Thresholds:** {{ALERT_THRESHOLDS}}

### Backup & Disaster Recovery
- **Backup Frequency:** {{BACKUP_FREQUENCY}}
- **Recovery Time Objective (RTO):** {{RTO}}
- **Recovery Point Objective (RPO):** {{RPO}}
- **Disaster Recovery Plan:** {{DR_PLAN}}

---

## 8. Security & Compliance

### Authentication & Authorization
- **User Authentication:** {{AUTH_MECHANISM}}
- **MFA Support:** {{MFA_REQUIRED}}
- **Session Management:** {{SESSION_MANAGEMENT}}
- **Password Policy:** {{PASSWORD_POLICY}}

### Data Security
- **Data at Rest:** {{DATA_AT_REST_ENCRYPTION}}
- **Data in Transit:** {{DATA_IN_TRANSIT_ENCRYPTION}} (TLS 1.2+)
- **Sensitive Data Handling:** {{SENSITIVE_DATA_HANDLING}}
- **PII Protection:** {{PII_PROTECTION}}

### Network & Infrastructure Security
- **Network Isolation:** {{NETWORK_ISOLATION}}
- **VPC/Firewall:** {{FIREWALL_CONFIG}}
- **DDoS Protection:** {{DDOS_PROTECTION}}
- **API Rate Limiting:** {{RATE_LIMITING}}

### Compliance Requirements
- **Regulations:** {{REGULATIONS}} (GDPR / HIPAA / SOC2 / PCI-DSS / other)
- **Data Residency:** {{DATA_RESIDENCY}}
- **Audit Logging:** {{AUDIT_LOGGING}}
- **Compliance Certifications:** {{CERTIFICATIONS}}

### Dependency & Vulnerability Management
- **Dependency Scanning:** {{DEPENDENCY_SCANNING_TOOL}}
- **Vulnerability Response Time:** {{VULN_RESPONSE_SLA}}
- **Security Updates Cadence:** {{SECURITY_UPDATE_CADENCE}}

---

## 9. Open Architectural Questions

- **Question 1:** {{QUESTION_1}}
  - Impact: {{IMPACT}}
  - Resolution: {{STATUS}}

- **Question 2:** {{QUESTION_2}}
  - Impact: {{IMPACT}}
  - Resolution: {{STATUS}}

- **Question N:** {{QUESTION_N}}
  - Impact: {{IMPACT}}
  - Resolution: {{STATUS}}

---

## Approval & Signoff

- **Created By:** {{CREATOR}}
- **Approved By:** {{APPROVER}}
- **Approval Date:** {{APPROVAL_DATE}}

**Changes Since Last Approval:**
{{CHANGE_LOG}}

---

## References & Resources

- [Technology Documentation Links]
- [Architecture Decision Records (ADRs)]
- [Related Spike Documentation]
- [Competitor/Reference Implementations]
TEMPLATE_BLUEPRINT_EOF

echo -e "  ${GREEN}✓${RESET} blueprint-template.md"

cat > .claude/skills/project-init/module-spec-template.md << 'TEMPLATE_SPEC_EOF'
# Module Specification: {{MODULE_NAME}}

> **Status:** {{STATUS}} (Draft / Ready for Review / In Progress / Complete)
> **Last Updated:** {{DATE}}
> **Owner:** {{MODULE_OWNER}}
> **Version:** {{VERSION}}

---

## 1. Purpose

**Why does this module exist?**

{{MODULE_PURPOSE}}

**Business Value:** {{BUSINESS_VALUE}}

**Success Criteria:**
- {{SUCCESS_CRITERION_1}}
- {{SUCCESS_CRITERION_2}}
- {{SUCCESS_CRITERION_3}}

---

## 2. User Stories

| ID | As a | I want to | So that |
|----|----|----------|---------|
| {{US_1}} | {{USER_TYPE}} | {{ACTION}} | {{BENEFIT}} |
| {{US_2}} | {{USER_TYPE}} | {{ACTION}} | {{BENEFIT}} |
| {{US_3}} | {{USER_TYPE}} | {{ACTION}} | {{BENEFIT}} |
| {{US_N}} | {{USER_TYPE}} | {{ACTION}} | {{BENEFIT}} |

**Workflow Examples:**
- **{{WORKFLOW_1}}:** {{WORKFLOW_DESCRIPTION}}
- **{{WORKFLOW_2}}:** {{WORKFLOW_DESCRIPTION}}

---

## 3. Data Model

### Core Entities & Types

```typescript
// {{ENTITY_1}} - {{ENTITY_DESCRIPTION}}
interface {{ENTITY_1}} {
  id: string;
  {{FIELD_1}}: {{TYPE}};
  {{FIELD_2}}: {{TYPE}};
  {{FIELD_3}}?: {{TYPE}}; // optional
  createdAt: Date;
  updatedAt: Date;
}

// {{ENTITY_2}} - {{ENTITY_DESCRIPTION}}
interface {{ENTITY_2}} {
  id: string;
  {{FIELD_1}}: {{TYPE}};
  {{FIELD_2}}: {{TYPE}};
  {{FIELD_3}}: {{TYPE}};
  createdAt: Date;
  updatedAt: Date;
}

// {{ENUM_TYPE}} - {{ENUM_DESCRIPTION}}
enum {{ENUM_TYPE}} {
  {{VALUE_1}} = "{{VALUE_1}}",
  {{VALUE_2}} = "{{VALUE_2}}",
}

// {{DTO_TYPE}} - {{DTO_DESCRIPTION}}
interface {{DTO_TYPE}} {
  {{FIELD_1}}: {{TYPE}};
  {{FIELD_2}}: {{TYPE}};
}
```

### Relationships & Database Schema

```sql
-- {{TABLE_1}}
CREATE TABLE {{TABLE_1}} (
  id UUID PRIMARY KEY,
  {{COLUMN_1}} {{TYPE}} NOT NULL,
  {{COLUMN_2}} {{TYPE}},
  {{FOREIGN_KEY}} UUID REFERENCES {{PARENT_TABLE}}(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- {{TABLE_2}}
CREATE TABLE {{TABLE_2}} (
  id UUID PRIMARY KEY,
  {{COLUMN_1}} {{TYPE}} NOT NULL,
  {{FOREIGN_KEY}} UUID REFERENCES {{PARENT_TABLE}}(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Key Design Decisions

- **Soft Deletes:** {{SOFT_DELETE_YES_NO}} — {{RATIONALE}}
- **Timestamps:** {{TIMESTAMP_STRATEGY}}
- **Validation:** {{VALIDATION_LEVEL}} (client-only / server / both)
- **Data Constraints:** {{CONSTRAINTS_DESCRIPTION}}

---

## 4. API / Server Actions

### REST Endpoints (if applicable)

```http
GET /api/v1/{{resource-plural}}
  → List {{RESOURCE_NAME}} with pagination
  → Query Params: limit, offset, filter, sort
  → Response: {{ "data": [{{RESOURCE}}], "meta": { "total": number } }}
  → Status: 200 OK, 400 Bad Request

POST /api/v1/{{resource-plural}}
  → Create new {{RESOURCE_NAME}}
  → Body: {{ "field1": "value", "field2": "value" }}
  → Response: {{ "data": {{RESOURCE}} }}
  → Status: 201 Created, 400 Bad Request, 401 Unauthorized

GET /api/v1/{{resource-plural}}/{id}
  → Get single {{RESOURCE_NAME}}
  → Response: {{ "data": {{RESOURCE}} }}
  → Status: 200 OK, 404 Not Found

PATCH /api/v1/{{resource-plural}}/{id}
  → Update {{RESOURCE_NAME}}
  → Body: {{ "field1": "new_value" }}
  → Response: {{ "data": {{RESOURCE}} }}
  → Status: 200 OK, 400 Bad Request, 404 Not Found

DELETE /api/v1/{{resource-plural}}/{id}
  → Delete {{RESOURCE_NAME}}
  → Response: {{ "data": null, "meta": { "deleted": true } }}
  → Status: 200 OK, 404 Not Found
```

### Server Actions / RPC Endpoints (if applicable)

```typescript
// Create a new {{RESOURCE_NAME}}
export async function create{{RESOURCE_NAME}}(input: {{INPUT_TYPE}}): Promise<{{RESOURCE_NAME}}> {
  // Implementation
}

// Update existing {{RESOURCE_NAME}}
export async function update{{RESOURCE_NAME}}(
  id: string,
  input: {{UPDATE_INPUT_TYPE}}
): Promise<{{RESOURCE_NAME}}> {
  // Implementation
}

// Fetch {{RESOURCE_NAME}} by ID
export async function get{{RESOURCE_NAME}}(id: string): Promise<{{RESOURCE_NAME}} | null> {
  // Implementation
}

// List {{RESOURCE_PLURAL}}
export async function list{{RESOURCE_PLURAL}}(
  filter: {{FILTER_TYPE}},
  pagination: {{ limit: number; offset: number }}
): Promise<{{ items: {{RESOURCE_NAME}}[]; total: number }}> {
  // Implementation
}
```

### Authentication & Authorization

- **Required Scopes:** {{REQUIRED_SCOPES}}
- **Role-based Access:** {{ROLE_BASED_ACCESS}}
- **Resource-level Permissions:** {{RESOURCE_PERMISSIONS}}

---

## 5. UI Screens

### Screen 1: {{SCREEN_NAME}}

**Path:** `{{ROUTE}}`

**Purpose:** {{PURPOSE}}

**Key Elements:**
- {{ELEMENT_1}}: {{DESCRIPTION}}
- {{ELEMENT_2}}: {{DESCRIPTION}}
- {{ELEMENT_3}}: {{DESCRIPTION}}

**Wireframe/Mockup:**
```
┌─────────────────────────────────┐
│ Header / Navigation              │
├─────────────────────────────────┤
│                                 │
│ Main Content Area               │
│                                 │
├─────────────────────────────────┤
│ Footer / Actions                 │
└─────────────────────────────────┘
```

**User Interactions:**
- Click {{ELEMENT}} → {{ACTION}}
- Submit form → {{ACTION}}
- Navigate to {{ROUTE}} → {{ACTION}}

**States:**
- **Loading:** Display spinner; disable interactions
- **Empty:** Show placeholder message "{{MESSAGE}}"
- **Error:** Display error banner with retry option
- **Success:** Show confirmation toast; redirect to {{ROUTE}}

### Screen 2: {{SCREEN_NAME}}

**Path:** `{{ROUTE}}`

**Purpose:** {{PURPOSE}}

{{SCREEN_DETAILS}}

---

## 6. Business Logic & Rules

### Core Workflows

**Workflow: {{WORKFLOW_NAME}}**
1. User {{ACTION_1}}
2. System validates {{VALIDATION}}
3. System {{ACTION_2}}
4. System notifies user via {{NOTIFICATION_METHOD}}

**Workflow: {{WORKFLOW_NAME}}**
1. User {{ACTION_1}}
2. System checks {{CONDITION}}
3. If true: {{PATH_A}}
4. If false: {{PATH_B}}

### Validation Rules

| Field | Rule | Error Message |
|-------|------|--------------|
| {{FIELD_1}} | {{RULE}} | "{{ERROR_MSG}}" |
| {{FIELD_2}} | {{RULE}} | "{{ERROR_MSG}}" |
| {{FIELD_N}} | {{RULE}} | "{{ERROR_MSG}}" |

### Business Constraints

- **{{CONSTRAINT_1}}:** {{DESCRIPTION}}
- **{{CONSTRAINT_2}}:** {{DESCRIPTION}}
- **{{CONSTRAINT_N}}:** {{DESCRIPTION}}

### Side Effects & Triggers

- When {{EVENT}} occurs:
  - {{SIDE_EFFECT_1}}
  - {{SIDE_EFFECT_2}}
  - Notify {{SYSTEM}} via {{METHOD}}

---

## 7. Integration Points

| Component | Type | Contract | Notes |
|-----------|------|----------|-------|
| {{COMPONENT_1}} | {{READS/WRITES}} | {{DATA_TYPE}} | {{NOTES}} |
| {{COMPONENT_2}} | {{READS/WRITES}} | {{DATA_TYPE}} | {{NOTES}} |
| {{EXTERNAL_SERVICE}} | API Call | {{ENDPOINT}} | Async / Sync, retry policy |
| {{EVENT_SYSTEM}} | Event Stream | {{EVENT_TYPES}} | Publish / Subscribe |

### Dependencies

- **Imports From:** {{MODULE_A}}, {{MODULE_B}}
- **Exports To:** {{MODULE_C}}, {{MODULE_D}}
- **External Services:** {{SERVICE_1}} (v{{VERSION}}), {{SERVICE_2}}

### Contracts & Interfaces

```typescript
// Interface consumed from {{OTHER_MODULE}}
interface {{IMPORTED_INTERFACE}} {
  {{FIELD}}: {{TYPE}};
}

// Interface exported from this module
export interface {{EXPORTED_INTERFACE}} {
  {{FIELD}}: {{TYPE}};
}
```

---

## 8. Acceptance Criteria

- [ ] All user stories implemented and tested
- [ ] API endpoints functional with proper error handling
- [ ] Database migrations applied and rollback tested
- [ ] UI screens match approved mockups
- [ ] Form validation working client and server-side
- [ ] All integration points functional
- [ ] Unit test coverage > {{COVERAGE_TARGET}}%
- [ ] Integration tests passing
- [ ] Performance benchmarks met ({{METRIC}} < {{THRESHOLD}})
- [ ] Accessibility audit passing (WCAG {{LEVEL}})
- [ ] Documentation complete and reviewed
- [ ] Security review completed
- [ ] Deployed to staging and verified
- [ ] Ready for production release

---

## 9. Out of Scope

**Explicitly NOT included in this module:**
- {{OUT_OF_SCOPE_1}}
- {{OUT_OF_SCOPE_2}}
- {{OUT_OF_SCOPE_3}}

**Rationale:** {{RATIONALE_FOR_SCOPE_DECISIONS}}

**Future Enhancements:**
- {{FUTURE_1}}: Consider for v{{FUTURE_VERSION}}
- {{FUTURE_2}}: Depends on {{BLOCKING_FACTOR}}

---

## 10. Open Questions

| Question | Impact | Status | Resolution |
|----------|--------|--------|------------|
| {{QUESTION_1}} | {{HIGH/MEDIUM/LOW}} | {{PENDING/RESOLVED}} | {{RESOLUTION}} |
| {{QUESTION_2}} | {{HIGH/MEDIUM/LOW}} | {{PENDING/RESOLVED}} | {{RESOLUTION}} |
| {{QUESTION_N}} | {{HIGH/MEDIUM/LOW}} | {{PENDING/RESOLVED}} | {{RESOLUTION}} |

---

## Implementation Notes

**Estimated Effort:** {{ESTIMATE}} (story points / hours)

**Complexity Factors:**
- {{COMPLEXITY_1}}
- {{COMPLEXITY_2}}

**Risk Assessment:**
- {{RISK_1}}: {{MITIGATION}}
- {{RISK_2}}: {{MITIGATION}}

**Team Assignments:**
- Lead: {{LEAD_NAME}}
- Reviewers: {{REVIEWER_NAMES}}

---

## Sign-Off

- **Spec Created By:** {{CREATOR}}
- **Approved By:** {{APPROVER}}
- **Approval Date:** {{DATE}}

**Related Documents:**
- [Parent Blueprint](../MASTER_BLUEPRINT.md)
- [Module CLAUDE Guide](./CLAUDE.md)
- [Architecture Decision Records]
- [Related Spike Documents]

## Optional Parallel Track Companion

Create `parallel.yaml` beside this module spec when the module may run through
`/project-tracks`. The planner requires `version: 1` and refuses brownfield
modules without an explicit declaration.

```yaml
version: 1
touches:
  - src/{{module_slug}}/**
shared:
  - src/types/{{shared_type}}.ts
ports:
  - 3001
migrations: false
```
TEMPLATE_SPEC_EOF

echo -e "  ${GREEN}✓${RESET} module-spec-template.md"

cat > .claude/skills/project-init/claude-module-template.md << 'TEMPLATE_CLAUDE_EOF'
# CLAUDE Module Guide: {{MODULE_NAME}}

> **Purpose:** This guide helps Claude understand module conventions, architecture patterns, and boundaries specific to {{MODULE_NAME}}.
> **Last Updated:** {{DATE}}
> **Maintainer:** {{MAINTAINER}}

---

## 1. Patterns to Follow

### Architectural Patterns

**{{PATTERN_1_NAME}}**
- **Description:** {{PATTERN_1_DESCRIPTION}}
- **When to use:** {{WHEN_TO_USE}}
- **Example in this module:** {{EXAMPLE_LOCATION}}
  ```typescript
  {{CODE_EXAMPLE}}
  ```

**{{PATTERN_2_NAME}}**
- **Description:** {{PATTERN_2_DESCRIPTION}}
- **When to use:** {{WHEN_TO_USE}}
- **Example in this module:** {{EXAMPLE_LOCATION}}
  ```typescript
  {{CODE_EXAMPLE}}
  ```

### Design Patterns Applied

| Pattern | Usage | Rationale |
|---------|-------|-----------|
| {{PATTERN}} | {{WHERE_USED}} | {{WHY_CHOSEN}} |
| {{PATTERN}} | {{WHERE_USED}} | {{WHY_CHOSEN}} |

### Common Idioms in This Module

- **Error Handling:** {{ERROR_HANDLING_APPROACH}} (e.g., try-catch, Result type, error wrapper)
- **Async Operations:** {{ASYNC_PATTERN}} (e.g., Promises, async/await, observables)
- **Logging:** {{LOGGING_PATTERN}} (e.g., structured logging with context)
- **State Management:** {{STATE_MANAGEMENT}} (e.g., immutable updates, reactive)

---

## 2. Conventions in This Module

### File Organization

```
src/
├── {{module-name}}/
│   ├── index.ts                 # Main export file
│   ├── types.ts                 # Type definitions & interfaces
│   ├── constants.ts             # Module constants & enums
│   ├── services/                # Business logic
│   │   ├── {{domain}}.service.ts
│   │   └── {{other}}.service.ts
│   ├── repositories/            # Data access layer
│   │   ├── {{entity}}.repository.ts
│   │   └── {{other}}.repository.ts
│   ├── controllers/             # Request handlers (if applicable)
│   │   └── {{endpoint}}.controller.ts
│   ├── utils/                   # Helper functions
│   │   └── {{utility}}.ts
│   ├── hooks/                   # React hooks (if frontend)
│   │   └── use{{Hook}}.ts
│   ├── components/              # UI components (if frontend)
│   │   └── {{Component}}.tsx
│   ├── __tests__/               # Test files
│   │   ├── {{feature}}.test.ts
│   │   └── {{service}}.spec.ts
│   └── README.md                # Module overview
```

### Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| Files | kebab-case | `user.service.ts`, `get-user.ts` |
| Classes | PascalCase | `UserService`, `OrderProcessor` |
| Functions | camelCase | `getUserById()`, `processPayment()` |
| Constants | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT`, `DEFAULT_TIMEOUT` |
| Types/Interfaces | PascalCase | `User`, `CreateUserInput`, `ApiResponse<T>` |
| Enums | PascalCase | `OrderStatus`, `UserRole` |
| Private methods | _camelCase (prefix) or camelCase | `_validateInput()`, `validateInput()` |
| Directories | kebab-case | `services/`, `api-handlers/` |

### Code Style

**TypeScript Strictness:**
- Strict mode enabled: `"strict": true`
- No implicit any: `"noImplicitAny": true`
- Always type function parameters and returns
- Use const/let, never var
- Prefer interfaces for objects, types for unions/aliases

**Example:**
```typescript
// ✅ Good
interface UserInput {
  name: string;
  email: string;
}

function createUser(input: UserInput): Promise<User> {
  // Implementation
}

// ❌ Avoid
function createUser(input: any) {
  // Implementation
}
```

**Imports & Exports:**
- Use ES6 modules: `import` / `export`
- Named exports preferred over default exports (except for React components and main entry points)
- Organize imports: built-ins, external packages, internal modules, relative imports
  ```typescript
  import { join } from 'path';
  import { v4 as uuid } from 'uuid';
  import { UserService } from '@services/user.service';
  import { validateEmail } from './utils';
  ```

### Error Handling

**Error Wrapper Pattern:**
```typescript
interface Result<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, any>;
  };
}

// Usage
async function getUser(id: string): Promise<Result<User>> {
  try {
    const user = await repository.findById(id);
    if (!user) {
      return {
        success: false,
        error: { code: 'NOT_FOUND', message: 'User not found' }
      };
    }
    return { success: true, data: user };
  } catch (err) {
    return {
      success: false,
      error: { code: 'INTERNAL_ERROR', message: 'Failed to fetch user' }
    };
  }
}
```

**Exception Handling (if used):**
- Create custom exception classes:
  ```typescript
  class NotFoundError extends Error {
    constructor(resource: string) {
      super(`${resource} not found`);
      this.name = 'NotFoundError';
    }
  }
  ```
- Use specific exception types, not generic Error
- Always log exceptions with context

### Logging

**Standard Logging Format:**
```typescript
import { logger } from '@utils/logger';

// Info
logger.info('User created', { userId: user.id, email: user.email });

// Warning
logger.warn('Retry attempt', { attempt: 2, maxRetries: 3 });

// Error
logger.error('Database query failed', { error, query: sql });

// Debug (development only)
logger.debug('Processing step', { step: 'validation', data: input });
```

**What to Log:**
- ✅ Operations with side effects (create, update, delete)
- ✅ External API calls (request/response summary)
- ✅ Authentication/authorization decisions
- ✅ Error conditions with context
- ❌ Passwords, tokens, secrets
- ❌ Large data objects (log keys only)

---

## 3. Module Boundaries

### What This Module Owns

**Data:**
- {{ENTITY_1}} (full ownership; defines schema, validation, lifecycle)
- {{ENTITY_2}} (full ownership)

**Services:**
- {{SERVICE_1}}: Manages {{RESPONSIBILITY}}
- {{SERVICE_2}}: Manages {{RESPONSIBILITY}}

**APIs / Exports:**
- Endpoint: `GET /api/v1/{{resource}}`
- Endpoint: `POST /api/v1/{{resource}}`
- Function: `export {{ {{FUNCTION}} }}`

### What This Module Reads From

| Module | Data/Service | Contract |
|--------|-------------|----------|
| {{MODULE_A}} | {{READS_WHAT}} | {{INTERFACE}} |
| {{MODULE_B}} | {{READS_WHAT}} | {{INTERFACE}} |
| {{EXTERNAL_SERVICE}} | {{API_ENDPOINT}} | {{RESPONSE_TYPE}} |

**Example:**
```typescript
// Reading from auth module
import { getCurrentUser } from '@modules/auth';

// Reading from database service
import { Database } from '@services/database';

// Making external API calls
const response = await fetch('https://external-service.com/api/data');
```

### What This Module Must NEVER Do

- ❌ {{VIOLATION_1}}: {{EXPLANATION}}
- ❌ {{VIOLATION_2}}: {{EXPLANATION}}
- ❌ {{VIOLATION_3}}: {{EXPLANATION}}
- ❌ **Access database tables from other modules directly** — Use their exported services instead
- ❌ **Modify other modules' data** — Request changes through their public APIs
- ❌ **Depend on implementation details** — Only depend on exported interfaces
- ❌ **Create circular imports** — Refactor shared logic into a separate utility module
- ❌ **Expose internal types** — Only export types meant for public use

**Example of Violation:**
```typescript
// ❌ NEVER do this:
import { db } from '@services/database';
const user = await db.query('SELECT * FROM users WHERE id = ?', [userId]);

// ✅ DO THIS instead:
import { UserRepository } from '@modules/user';
const user = await UserRepository.findById(userId);
```

---

## 4. Known Gotchas

### Performance Pitfalls

**{{GOTCHA_1_NAME}}**
- **Problem:** {{DESCRIPTION}}
- **Symptom:** {{HOW_TO_SPOT}}
- **Solution:** {{HOW_TO_FIX}}
- **Example:**
  ```typescript
  // ❌ Slow: N+1 query problem
  const users = await User.find();
  for (const user of users) {
    user.profile = await Profile.findOne({ userId: user.id });
  }

  // ✅ Fast: Load profiles in single query
  const users = await User.find().populate('profile');
  ```

**{{GOTCHA_2_NAME}}: Race Conditions**
- **Problem:** Concurrent updates may overwrite data
- **Solution:** Use atomic operations, version fields, or transactions
  ```typescript
  // ✅ Safe concurrent update
  const updated = await User.updateOne(
    { id, version: 1 },
    { $set: { name }, $inc: { version: 1 } }
  );
  if (updated.modifiedCount === 0) {
    throw new Error('Update conflict; retry');
  }
  ```

### Threading & Concurrency

- {{CONCURRENCY_ISSUE}}: {{EXPLANATION}}
- **Safe Patterns:** {{PATTERNS}}
- **Unsafe Patterns:** {{PATTERNS_TO_AVOID}}

### Common Mistakes

1. **{{MISTAKE_1}}**
   - ❌ Wrong: `const result = service.getData();` (blocking)
   - ✅ Right: `const result = await service.getData();` (async)

2. **{{MISTAKE_2}}**
   - ❌ Don't: Modify function parameters directly
   - ✅ Do: Create copies/clones and mutate those

3. **{{MISTAKE_3}}**
   - ❌ Avoid: Hardcoding configuration values
   - ✅ Use: Environment variables or config service

### Memory & Resource Leaks

- **{{LEAK_1}}:** {{DESCRIPTION}}
  - Mitigation: {{SOLUTION}}
- **{{LEAK_2}}:** {{DESCRIPTION}}
  - Mitigation: {{SOLUTION}}

### Debugging Tips

- Add structured logging at module entry/exit points
- Use {{DEBUGGING_TOOL}} for step-through debugging
- Check {{COMMON_LOG}} for errors specific to this module
- Profile with {{PROFILER}} if performance degrades
- Enable trace logging: `DEBUG={{MODULE_NAME}}:* npm start`

---

## 5. Test Patterns

### Unit Test Structure

```typescript
// {{feature}}.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { {{ServiceClass}} } from './{{service}}.service';

describe('{{ServiceClass}}', () => {
  let service: {{ServiceClass}};

  beforeEach(() => {
    service = new {{ServiceClass}}();
  });

  afterEach(() => {
    // Cleanup
  });

  describe('{{methodName}}', () => {
    it('should {{expected behavior}} when {{condition}}', async () => {
      // Arrange
      const input = { /* test data */ };

      // Act
      const result = await service.{{method}}(input);

      // Assert
      expect(result).toEqual({ /* expected result */ });
    });

    it('should throw {{error}} when {{condition}}', async () => {
      // Arrange
      const input = { /* invalid data */ };

      // Act & Assert
      await expect(service.{{method}}(input)).rejects.toThrow('{{error message}}');
    });
  });
});
```

### Mocking & Fixtures

**Mock {{DependentService}}:**
```typescript
import { vi } from 'vitest';

const mockUserRepository = {
  findById: vi.fn(),
  create: vi.fn(),
};

// In test:
mockUserRepository.findById.mockResolvedValue({ id: '1', name: 'Test User' });
```

**Test Fixtures:**
```typescript
export const fixtures = {
  validUser: { name: 'John', email: 'john@example.com' },
  invalidUser: { name: '', email: 'invalid' },
};
```

### Integration Tests

**Test {{Workflow}} end-to-end:**
```typescript
describe('{{Workflow}} Integration', () => {
  it('should complete full workflow', async () => {
    // Setup: Create user
    const user = await createUser(fixtures.validUser);

    // Action: Perform operation
    const result = await service.processUser(user.id);

    // Verify: Check state changes
    expect(result.status).toBe('completed');
    const updated = await getUser(user.id);
    expect(updated.status).toBe('completed');
  });
});
```

### Test Coverage Goals

- **Line Coverage:** > {{COVERAGE_TARGET}}%
- **Branch Coverage:** > {{BRANCH_COVERAGE}}%
- **Function Coverage:** 100% for critical paths

**Run coverage:**
```bash
npm test -- --coverage
```

### Test Data Management

- Use factories for complex test objects:
  ```typescript
  const user = userFactory.build({ name: 'Test' });
  ```
- Keep fixtures in separate `__fixtures__/` directory
- Clean up test data after each test (transaction rollback)
- Use separate test database for integration tests

---

## Implementation Checklist

When implementing features in this module, follow this checklist:

- [ ] Read the full `SPEC.md` and understand requirements
- [ ] Review `CLAUDE.md` (this file) for patterns and conventions
- [ ] Follow naming conventions from Section 2
- [ ] Implement with appropriate error handling (Section 2)
- [ ] Add structured logging (Section 2)
- [ ] Respect module boundaries (Section 3)
- [ ] Watch out for gotchas (Section 4)
- [ ] Write unit and integration tests (Section 5)
- [ ] Run linter and formatter: `npm run lint -- --fix`
- [ ] Achieve test coverage threshold: `npm test -- --coverage`
- [ ] Update type definitions if data model changes
- [ ] Document any new patterns or gotchas discovered
- [ ] Submit for code review with test coverage report

---

## Further Reading

- **Module Specification:** [SPEC.md](./SPEC.md)
- **Master Blueprint:** [../MASTER_BLUEPRINT.md](../MASTER_BLUEPRINT.md)
- **Related Modules:** {{RELATED_MODULES}}
- **Architecture Decision Records:** {{ADRS}}
- **External Documentation:** {{EXTERNAL_DOCS}}

---

## Questions & Discussions

If you encounter issues or questions while implementing this module:

1. Check this guide (Sections 2-5)
2. Check `SPEC.md` for requirements
3. Review recent commits for patterns used
4. Ask {{MAINTAINER}} or post in {{DISCUSSION_CHANNEL}}
5. Update this guide if you discover new patterns or gotchas
TEMPLATE_CLAUDE_EOF

echo -e "  ${GREEN}✓${RESET} claude-module-template.md"

# Now create the skills and commands for the remaining commands
cat > .claude/skills/project-research/SKILL.md << 'SKILL_RESEARCH_EOF'
---
name: project-research
description: "Conduct deep, structured research on any domain, technology, competitor, regulation, or technical topic for this project. Use whenever the team needs to understand something before making architectural or product decisions — market landscapes, compliance requirements, API capabilities, framework comparisons, or user workflows."
---

# Project Research Skill

This skill guides structured, multi-source research using available MCP tools. Research findings inform product decisions, architecture, and technical strategy.

The research topic is provided via `$ARGUMENTS`.

## Research Methodology

Follow this structured approach for all research tasks. Use the tools specified below for each research category.

### 1. Market & Domain Research

**Goal:** Understand the competitive landscape, business models, user needs, and market trends.

**Tools to Use:**
- `web_search_exa` with `category: "company"` for competitor analysis, product positioning, pricing, and business models
- `web_search_exa` with `category: "research paper"` for academic studies, industry reports, and technical papers
- `web_search_exa` (no category) for recent news, trends, adoption rates, and emerging patterns
- `web_search_exa` with `category: "people"` to find domain experts, thought leaders, and influencers

**Search Queries to Try:**
- "[Domain] market landscape 2024/2025"
- "[Product category] competitor analysis"
- "[Use case] best practices research"
- "[Industry] trends and forecasts"
- "[Topic] thought leaders experts"

**What to Document:**
- Market size and growth rates
- Key competitors and their positioning
- Common pain points and solutions
- Pricing models and revenue strategies
- User demographics and behaviors
- Emerging trends and disruptions
- Expert opinions and recommendations

**Example Workflow:**
1. Search: "[domain] market landscape" → identify top 5 competitors
2. Search: "[competitor] pricing model" → document each competitor's approach
3. Search: "[domain] research paper" → find academic validation
4. Search: "[domain] experts" → identify thought leaders to follow

---

### 2. Technical Research

**Goal:** Understand technology options, implementation patterns, APIs, and technical best practices.

**Tools to Use:**
- `ref_search_documentation` to find official documentation for frameworks, libraries, and APIs
- `ref_read_url` to read full documentation pages and deep technical guides
- `get_code_context_exa` for production code examples, GitHub repos, and Stack Overflow patterns
- `web_search_exa` (no category) for comparison articles, blog posts, and case studies

**Search Queries to Try (vary by technology type):**

**For Frameworks/Libraries:**
- "{{framework}} official documentation"
- "{{framework}} {{version}} changelog"
- "{{framework}} {{feature}} example"
- "{{framework}} performance benchmarks"
- "{{framework}} best practices 2024"

**For API Research:**
- "{{service}} API documentation"
- "{{service}} REST endpoints reference"
- "{{service}} authentication methods"
- "{{service}} rate limits and quotas"
- "{{service}} SDK examples {{language}}"

**For Architecture Patterns:**
- "{{pattern}} {{language}} example"
- "{{pattern}} production architecture"
- "{{pattern}} gotchas and pitfalls"
- "{{pattern}} vs {{alternative}} comparison"

**For Code Examples:**
- Use `get_code_context_exa` with: "{{framework}} {{pattern}} example GitHub"
- "{{stack}} production code sample"
- "{{problem}} {{language}} solution Stack Overflow"

**What to Document:**
- Latest stable versions of technologies
- Key features and capabilities
- API design patterns and best practices
- Common implementation patterns
- Performance characteristics
- Limitations and gotchas
- Migration paths and upgrading strategies
- Community size and maturity

**Example Workflow:**
1. `ref_search_documentation`: "React 19 documentation" → find official docs
2. `ref_read_url`: Read React hooks API page in full
3. `get_code_context_exa`: "React hooks custom hook example" → find implementation patterns
4. `web_search_exa`: "React performance optimization best practices" → find comparison article

---

### 3. Regulatory & Compliance Research

**Goal:** Understand legal, regulatory, and compliance requirements for the project.

**Tools to Use:**
- `web_search_exa` (no category) for regulations, compliance guides, and legal frameworks
- Always cross-reference multiple sources (minimum 2)
- Look for official regulatory body sources first

**Search Queries:**
- "{{regulation}} compliance requirements 2024"
- "{{regulation}} software requirements"
- "{{regulation}} audit and testing"
- "{{jurisdiction}} data privacy laws"
- "{{industry}} compliance checklist"
- "{{regulation}} fines and penalties"

**What to Document:**
- Applicable regulations and laws
- Compliance requirements by feature/module
- Data handling and privacy rules
- Audit and testing requirements
- Certification or licensing needs
- Penalties for non-compliance
- Implementation timeline and cost

**Verification Requirement:**
- Always cite at least 2 independent sources
- Prefer official regulatory body sources
- Note any conflicting information with explanations

**Example Workflow:**
1. Search: "GDPR software compliance requirements" → understand scope
2. Search: "GDPR data processing agreement" → find specific requirements
3. Search: "GDPR fines and penalties 2024" → understand enforcement
4. Document: "Applies if: EU users; Requirements: data consent, right to delete, DPA"

---

### 4. User Research & Workflows

**Goal:** Understand how users will interact with the product and what problems they're solving.

**Tools to Use:**
- `web_search_exa` (no category) for user reviews, feedback, and case studies
- `web_search_exa` with `category: "research paper"` for user behavior studies
- `web_search_exa` with `category: "people"` for user interviews and testimonials

**Search Queries:**
- "{{product}} user reviews feedback"
- "{{use case}} user workflows pain points"
- "{{product}} case study results"
- "{{domain}} user research study"
- "how do users {{action}}"

**What to Document:**
- Common user workflows and journeys
- Primary pain points and frustrations
- Feature usage and adoption rates
- User demographics and segments
- Success stories and case studies
- Common workarounds and hacks
- Unmet needs and feature requests

---

### 5. Competitive & Alternative Solutions Research

**Goal:** Understand what competitors are doing and what alternatives exist.

**Tools to Use:**
- `web_search_exa` with `category: "company"` for competitor websites, products, and positioning
- `get_code_context_exa` for open-source alternatives and reference implementations
- `web_search_exa` (no category) for comparison articles and reviews

**Search Queries:**
- "{{product category}} competitors 2024"
- "{{problem}} solution comparison"
- "open source {{solution}} alternatives"
- "{{product}} vs {{competitor}} comparison"
- "{{use case}} tools and solutions"

**What to Document:**
- Competitor feature matrix
- Pricing comparison
- Strengths and weaknesses of each
- Market positioning and differentiation
- Open source alternatives
- Emerging solutions and startups
- Recommended positioning for your solution

---

## Research Output Structure

Organize research findings in a consistent format. Save to `specs/research/[topic-slug].md`.

### Template

```markdown
# Research: {{TOPIC}}

> **Conducted:** {{DATE}}
> **Researcher:** {{YOUR_NAME}}
> **Status:** Complete / In Progress
> **Next Update:** {{DATE}}

## Executive Summary

{{1-2 paragraph overview of key findings}}

## Research Questions

- {{Question 1}}
- {{Question 2}}
- {{Question 3}}

## Current Landscape

### {{Subtopic 1}}
{{Findings with sources}}

### {{Subtopic 2}}
{{Findings with sources}}

## Key Findings for This Project

1. **{{Finding 1}}**
   - Impact: {{How this affects the project}}
   - Source: [Title](URL)

2. **{{Finding 2}}**
   - Impact: {{How this affects the project}}
   - Source: [Title](URL)

## Recommended Approach

### Option 1: {{Approach Name}}
- {{Advantage 1}}
- {{Advantage 2}}
- Trade-off: {{Trade-off}}
- Cost/Effort: {{Estimate}}

### Option 2: {{Approach Name}}
- {{Advantage 1}}
- {{Advantage 2}}
- Trade-off: {{Trade-off}}
- Cost/Effort: {{Estimate}}

**Recommendation:** {{Selected option}} because {{reasoning}}

## Open Questions

| Question | Priority | Status | Owner |
|----------|----------|--------|-------|
| {{Q1}} | {{Priority}} | {{Status}} | {{Owner}} |
| {{Q2}} | {{Priority}} | {{Status}} | {{Owner}} |

## Sources Consulted

### Market & Domain
- [Source Title 1](URL) — {{Type: Company Website / Blog / News}}
- [Source Title 2](URL) — {{Type: Research Paper / Industry Report}}

### Technical
- [Source Title 3](URL) — {{Type: Official Documentation / Blog}}
- [Source Title 4](URL) — {{Type: GitHub Repo / Stack Overflow}}

### Regulatory
- [Source Title 5](URL) — {{Type: Official Regulation / Compliance Guide}}
- [Source Title 6](URL) — {{Type: Legal Analysis}}

**Note:** Cross-referenced regulatory information across 2+ sources

## Conflicting Information

If sources disagree, document the conflict:
- **Source A says:** {{Claim}}
- **Source B says:** {{Conflicting claim}}
- **Resolution:** {{Our understanding}}
```

---

## Integration with Project Specifications

After completing research, integrate findings into the broader project specification:

1. **Update PROJECT_BRIEF.md** with market context and success criteria
2. **Inform MASTER_BLUEPRINT.md** technology decisions with technical research
3. **Feed module specs** (SPEC.md files) with specific requirements from domain research
4. **Create CLAUDE.md** patterns based on architectural best practices found
5. **Reference in ROADMAP.md** to inform priority and risk assessments

---

## Source Tracking & Citation

**For every finding, record:**
- URL or source identifier
- Tool used (web_search_exa, ref_search_documentation, get_code_context_exa, etc.)
- Access date
- Brief quote or summary
- Relevance to the project

**Example:**
```
- "Market grew 45% YoY" — [Gartner 2024 Report](https://gartner.com/...) (web_search_exa, category: research paper, 2025-03-19)
- "React 19 stable" — [React Official Docs](https://react.dev) (ref_search_documentation, 2025-03-19)
- "Next.js production patterns" — [GitHub: vercel/next.js examples](https://github.com/...) (get_code_context_exa, 2025-03-19)
```

---

## Quality Checklist

Before considering research complete:

- [ ] Primary research question answered
- [ ] All search queries executed (market, technical, regulatory, user, competitive)
- [ ] Minimum 3 sources per major finding
- [ ] Regulatory claims cross-referenced (2+ sources minimum)
- [ ] Conflicting information documented and resolved
- [ ] Findings include actionable recommendations
- [ ] All sources cited with URLs
- [ ] Output saved to `specs/research/[topic-slug].md`
- [ ] LEARNINGS.md updated with key insights
- [ ] Shared with team for feedback
- [ ] Open questions assigned to owners

---

## Common Research Topics

Use this skill for:

- **Market Research:** "Competitor landscape for {{product type}}"
- **Technical Feasibility:** "Can we use {{technology}} for {{requirement}}"
- **API Capabilities:** "What can {{service}} API do"
- **Compliance:** "GDPR requirements for {{feature}}"
- **User Workflows:** "How do {{users}} currently {{action}}"
- **Technology Comparison:** "{{Framework A}} vs {{Framework B}} for {{use case}}"
- **Emerging Patterns:** "Best practices for {{architecture pattern}}"
- **Performance:** "Optimization patterns for {{problem}}"
- **Security:** "Security considerations for {{feature}}"
- **Cost Analysis:** "Pricing comparison of {{services}}"

---

## Tips for Effective Research

1. **Start Broad, Narrow Down:** Research market context first, then technology options, then specific implementations
2. **Use Multiple Sources:** Don't rely on a single article; triangulate findings across sources
3. **Check Publication Dates:** Prioritize recent sources (within 1-2 years for fast-moving topics like AI/frameworks)
4. **Distinguish Opinion from Fact:** Note whether a source is an official guide, blog opinion, or academic study
5. **Document Trade-offs:** For every recommendation, clearly state what's being sacrificed
6. **Share Early:** Don't wait for "perfect" research; share findings periodically for team feedback
7. **Update Regularly:** Technology moves fast; revisit research quarterly for active projects
8. **Link to Decisions:** Explicitly connect research findings to architectural and product decisions

---

## Next Steps After Research

Once research is complete:

1. **Present Findings** to the team with 2-3 key recommendations
2. **Facilitate Discussion** on options and trade-offs
3. **Document Decision** in an Architecture Decision Record (ADR)
4. **Update Specifications** (MASTER_BLUEPRINT.md, module specs, roadmap)
5. **Monitor Progress** — If research assumptions change, repeat research for that topic
SKILL_RESEARCH_EOF

echo -e "  ${GREEN}✓${RESET} .claude/skills/project-research/SKILL.md"

mkdir -p ".claude/skills/project-blueprint"
cat > ".claude/skills/project-blueprint/SKILL.md" << 'SKILL_BLUEPRINT_EOF'
---
name: project-blueprint
description: "Generate or regenerate the master architecture document (specs/MASTER_BLUEPRINT.md) — the single source of truth for tech stack, data model, API patterns, auth, UI conventions, and module relationships. Use when starting architecture, changing stack decisions, or after significant research that affects the technical approach."
effort: high
---

# Project Blueprint Skill

This skill creates or updates the Master Architecture Blueprint, the foundational architecture document for your project. Use it when:
- Starting a new project (Phase 4 of project-init)
- Making significant technology stack changes
- After completing domain or technical research that changes approach
- Quarterly architecture reviews

The skill reads existing project context, verifies technology versions, finds production examples, and generates a comprehensive blueprint.

## Pre-Blueprint Review

Before generating the blueprint, gather existing project context:

1. **Read existing specs:**
   - `specs/PROJECT_BRIEF.md` (if exists) — project vision and constraints
   - `specs/RESEARCH.md` (if exists) — technology recommendations
   - `specs/MODULES.md` (if exists) — module decomposition
   - `CLAUDE.md` (if exists) — project coding patterns
   - Any architecture decision records (ADRs)

2. **Identify decision blockers:**
   - Is the tech stack already decided?
   - Have key frameworks/databases been chosen?
   - Are there hard constraints (budget, compliance, performance)?

3. **Determine research needs:**
   - If tech stack is undefined, proceed to "Stack Detection" section below
   - If partial stack exists, identify gaps (frontend, backend, database, deployment)
   - If stack is defined, proceed directly to "Technology Verification" section

---

## Stack Detection (if not yet decided)

If the technology stack is not yet defined, answer these 4 core questions to guide choices:

### Question 1: What Frontend Framework Aligns with UI Complexity and Team Skills?

**Options to Research:**

**React**
- Use if: Complex UI state, component reusability, large ecosystem, team familiarity
- Search: "React 2024 latest version" + `ref_search_documentation`
- Considerations: Large bundle size, steep learning curve, ecosystem fragmentation

**Vue**
- Use if: Progressive enhancement, gentle learning curve, good balance
- Search: "Vue 3 official documentation" + `ref_search_documentation`
- Considerations: Smaller ecosystem than React, focused on single-file components

**Svelte**
- Use if: Minimal JavaScript, performance critical, smaller app
- Search: "Svelte documentation" + `ref_search_documentation`
- Considerations: Smaller ecosystem, less community content

**Solid or Astro (for content-heavy sites)**
- Use if: Static content dominance, island architecture, fast load times
- Search: "Astro vs Next.js comparison" + `web_search_exa`
- Considerations: Different paradigm, less suitable for complex SPAs

**Decision Criteria:**
- Team skill level and learning curve tolerance
- Application complexity and state management needs
- Performance requirements and bundle size
- Community size and available resources
- Deployment target (Vercel, traditional server, edge)

### Question 2: What Backend Stack? (Language + Framework + Runtime)

**JavaScript/Node.js Options:**
- **Next.js** (React meta-framework): Full-stack React, API routes, edge functions
  - Search: "Next.js 15 latest version" + `ref_search_documentation`
- **Express.js**: Minimal, flexible, requires more setup
  - Search: "Express.js best practices 2024" + `web_search_exa`
- **Fastify**: High-performance, modern, TypeScript-first
  - Search: "Fastify documentation" + `ref_search_documentation`

**Python Options:**
- **Django**: Feature-rich, batteries-included, ORM, admin panel
  - Search: "Django 5.0 official documentation" + `ref_search_documentation`
- **FastAPI**: Modern, async, automatic API docs, very fast
  - Search: "FastAPI documentation" + `ref_search_documentation`

**Other Runtimes:**
- **Go (Echo/Gin)**: High performance, compiled, good for microservices
  - Search: "Go web framework comparison" + `web_search_exa`
- **Rust (Actix/Axum)**: Safety and performance, steep learning curve
  - Search: "Rust web framework 2024" + `web_search_exa`

**Decision Criteria:**
- Team language expertise
- Performance requirements
- Development speed vs. production optimization
- Available libraries and frameworks
- Hosting and deployment options

### Question 3: What Database? (Primary Data Store)

**Relational (SQL):**
- **PostgreSQL**: Mature, feature-rich, free, excellent JSON support
  - Search: "PostgreSQL latest version documentation" + `ref_search_documentation`
- **MySQL/MariaDB**: Widely hosted, simpler than PostgreSQL
- **SQL Server**: Enterprise, Windows-centric

**Document (NoSQL):**
- **MongoDB**: Flexible schema, scales horizontally, document-oriented
  - Search: "MongoDB Atlas documentation" + `ref_search_documentation`

**Graph:**
- **Neo4j**: Relationship-heavy data, social networks, recommendations
  - Search: "Neo4j documentation" + `ref_search_documentation`

**Vector (for AI/ML):**
- **Pinecone/Weaviate**: Vector embeddings, AI search
  - Search: "Pinecone vs Weaviate comparison" + `web_search_exa`

**Cache/Sessions:**
- **Redis**: In-memory, fast, sessions, caching, real-time features
  - Search: "Redis latest version" + `ref_search_documentation`

**Decision Criteria:**
- Data structure: Highly relational → SQL; flexible → MongoDB; relationships → Graph
- Scale: Billions of records → consider distributed options
- Consistency: ACID requirements → SQL; eventual consistency ok → NoSQL
- Query patterns: Complex joins → SQL; simple lookups → NoSQL

### Question 4: What Deployment Target? (Infrastructure)

**Serverless/Edge:**
- **Vercel**: Next.js native, edge functions, preview deployments
  - Search: "Vercel documentation" + `ref_search_documentation`
- **AWS Lambda**: Scalable, pay-per-use, complex to manage
- **Cloudflare Workers**: Edge execution, global distribution

**Container-Based:**
- **Docker + Kubernetes**: Full control, operational complexity
- **Docker + Docker Compose**: Simpler for small teams

**Traditional Servers:**
- **AWS EC2, DigitalOcean, Linode**: Full control, manage updates
- **Heroku**: PaaS, simpler but less control, higher cost

**Decision Criteria:**
- Operational complexity tolerance
- Scaling needs: Sudden spikes → serverless; steady → traditional servers
- Cost model: Sporadic usage → serverless; always-on → traditional
- Control requirements: Full → traditional/k8s; happy with managed → serverless/Vercel
- Team DevOps experience

---

## Technology Verification

Once stack options are identified or decided, verify current versions and best practices:

### For Each Chosen Technology:

1. **Find Official Documentation:**
   - Use `ref_search_documentation` with query: "{{framework}} official documentation"
   - Record the current stable version (not beta, not EOL)
   - Note any deprecations or major API changes

2. **Verify Production Patterns:**
   - Use `get_code_context_exa` with query: "{{framework}} {{pattern}} production example"
   - Look for: Real-world repos, large projects, proven patterns
   - Record: URL to example repo, key takeaways

3. **Check Version Compatibility:**
   - Frontend + Backend: Are they compatible? (e.g., React 19 + Next.js 15)
   - Database drivers: Are they updated for the database version?
   - Build tools: Updated recently? Any major breaking changes?

4. **Document Rationale:**
   - For each technology, record:
     - Version number
     - Why chosen (from stack detection Q1-Q4)
     - Trade-offs vs. alternatives
     - Source URL

---

## Master Blueprint Generation

### Step 1: Gather Information

Collect the following before filling the blueprint:

**From Project Brief:**
- Problem statement and solution overview
- Target users and success criteria
- Scope boundaries and constraints

**From Research:**
- Market landscape context
- Competitor positioning
- Technical recommendations
- Regulatory/compliance requirements

**From Stack Detection:**
- Frontend framework choice and rationale
- Backend language, framework, runtime
- Primary database choice
- Deployment target
- Secondary technologies (cache, auth, CDN, etc.)

**From Tech Verification:**
- Current stable versions for each technology
- Documentation URLs
- Production example repos
- Known gotchas or migration paths

### Step 2: Fill Blueprint Template

Use the template at `../project-init/blueprint-template.md`.

Fill each section systematically:

1. **1. Project Overview:** Copy from PROJECT_BRIEF.md
2. **2. Tech Stack:** List technologies with versions from stack detection + verification
3. **3. Data Model:** Define core entities as TypeScript interfaces
4. **4. API Design Patterns:** Choose REST/GraphQL/tRPC; define error format, auth method
5. **5. Shared UI Patterns:** Design system basics, navigation pattern, accessibility level
6. **6. Modules:** List from MODULES.md with dependencies
7. **7. Infrastructure & Deployment:** Hosting, CI/CD, monitoring, backups
8. **8. Security & Compliance:** Auth method, encryption, compliance requirements
9. **9. Open Questions:** Known unknowns to resolve before implementation

### Step 3: Create Example Data Model

Define the core entities that represent your domain:

**Example: E-commerce**
```typescript
interface User {
  id: string;
  email: string;
  passwordHash: string;
  role: "customer" | "admin";
  createdAt: Date;
  updatedAt: Date;
}

interface Product {
  id: string;
  name: string;
  description: string;
  price: number;
  inventory: number;
  categoryId: string;
  createdAt: Date;
  updatedAt: Date;
}

interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  status: "pending" | "processing" | "shipped" | "delivered";
  totalPrice: number;
  createdAt: Date;
  updatedAt: Date;
}
```

---

## Blueprint Review & Approval

### Prepare Summary for Team Review

Create a 1-page summary covering:

**Key Technology Decisions:**
- Frontend: {{Framework}} v{{Version}} — chosen because {{Rationale}}
- Backend: {{Language/Framework}} v{{Version}} — chosen because {{Rationale}}
- Database: {{Technology}} — chosen because {{Rationale}}
- Deployment: {{Platform}} — chosen because {{Rationale}}

**Architectural Highlights:**
- Data Model: {{Key entities and relationships}}
- API Style: {{REST/GraphQL/etc}} — {{Key design decision}}
- Authentication: {{Method}} — {{Implementation approach}}

**Known Constraints & Trade-offs:**
- {{Constraint 1}} — Impact: {{Impact}}
- {{Constraint 2}} — Impact: {{Impact}}

**Open Questions Requiring Decision:**
1. {{Question 1}} — Decision needed by {{Date}}
2. {{Question 2}} — Decision needed by {{Date}}

### Present & Discuss

1. **Share Summary** with the team
2. **Walk through** the 9 sections of the blueprint
3. **Discuss trade-offs** — for each major decision, explain alternatives and why this won
4. **Identify Risks** — what could go wrong with this architecture?
5. **Gather Feedback** — are there concerns? Missing considerations?

### Approval Gates

Before finalizing, confirm:

- [ ] Tech stack agreed by team (frontend, backend, database, deployment)
- [ ] Data model reviewed and no structural issues identified
- [ ] API design patterns clear and feasible
- [ ] Deployment strategy supported by team DevOps capability
- [ ] Compliance/security requirements are met
- [ ] Open questions have owners and target resolution dates
- [ ] Team confident in the approach

---

## Save & Version

Once approved:

1. **Save to:** `specs/MASTER_BLUEPRINT.md`
2. **Version Control:** Commit with message: "feat: create master blueprint for {{project}}"
3. **Reference Specs:** Link from PROJECT_BRIEF.md and module specs
4. **Update LEARNINGS.md:** Document key architectural decisions and rationale

---

## Common Blueprint Patterns

### Pattern: Monolithic + API

**When to Use:** Startup MVP, single team, simple domain
```
Frontend (React) → Backend (Next.js) → Database (PostgreSQL)
                ↓
              Cache (Redis)
```

### Pattern: Full-Stack Frameworks

**When to Use:** Web apps with tight frontend-backend coupling
```
Next.js (frontend + backend) → Postgres + Redis
                              ↓
                         Vercel (deploy)
```

### Pattern: Microservices

**When to Use:** Scale, multiple teams, independent deployments
```
Frontend (React) → API Gateway → Service 1 (Node.js) → DB1
                              → Service 2 (Python) → DB2
                              → Service 3 (Go)     → DB3
```

### Pattern: Async Workers

**When to Use:** Long-running jobs, background processing
```
Frontend → Backend API → Queue (Redis/Bull) → Workers
                      ↓
                   Database
```

Choose the pattern that matches your scale, team size, and complexity.

---

## Handling Changes to the Blueprint

If circumstances change during development:

1. **Minor Changes** (new field in data model): Update blueprint, create ADR if significant
2. **Moderate Changes** (database technology swap): Re-run tech verification, update blueprint, get team approval
3. **Major Changes** (backend framework swap): Repeat full blueprint process with research

Always maintain the blueprint as current source of truth.

---

## Template & Resources

- **Template:** `../project-init/blueprint-template.md`
- **Example Blueprints:** Reference blueprints in `docs/examples/`
- **Technology Docs:** Use `ref_search_documentation` to find official guides
- **Production Examples:** Use `get_code_context_exa` for real-world implementations

---

## Next Steps

After blueprint approval:

1. **Create Module Specs** — Each module gets detailed SPEC.md using `../project-init/module-spec-template.md`
2. **Create Module CLAUDE Guides** — Each module gets CLAUDE.md for implementation patterns
3. **Create Implementation Roadmap** — Priority and sequencing of work
4. **Set Up Infrastructure** — Deploy databases, auth system, CI/CD
5. **Begin Implementation** — Modules in priority order
SKILL_BLUEPRINT_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-blueprint/SKILL.md"

mkdir -p ".claude/skills/project-spec"
cat > ".claude/skills/project-spec/SKILL.md" << 'SKILL_SPEC_EOF'
---
name: project-spec
description: "Create or update a detailed module specification — data model, API endpoints, UI screens, business logic, and acceptance criteria. Use when planning a new module, refining requirements before implementation, or updating specs after implementation revealed changes. Trigger on any mention of 'spec', 'specification', 'plan this module', or 'define the requirements for'."
---

# Project Spec: Generate or Update Module Specification

This skill creates or updates a complete module specification that serves as the foundation for implementation.

## When to Use

- **Planning a new module**: Start here before any code is written
- **Refining requirements**: When a module needs clearer requirements before implementation begins
- **Updating specs**: When implementation reveals gaps or changes to the original spec
- **Keyword triggers**: "spec", "specification", "plan this module", "define the requirements for", "outline the module for"

## Process

### Step 1: Read Foundation Documents

Start by understanding the overall architecture and any existing context:

- Read `specs/MASTER_BLUEPRINT.md` to understand the overall system architecture, module dependencies, and design patterns
- If updating an existing spec, read `specs/modules/$ARGUMENTS/SPEC.md` to see what already exists
- Read any related module specs (check MASTER_BLUEPRINT.md for dependency relationships) to ensure consistency
- Read `specs/LEARNINGS.md` to apply patterns and lessons from previous modules

### Step 2: Research Framework Patterns

Before designing the module, verify implementation patterns:

- Use `ref_search_documentation` to research API patterns and best practices for the chosen framework
- Use `get_code_context_exa` to find real examples of similar module implementations in the codebase
- Check `root/CLAUDE.md` for architectural guidelines and decisions already made

### Step 3: Access Templates

Reference the templates bundled with this skill:

- `../project-init/module-spec-template.md` — The standard MODULE_SPEC template with all required sections
- `../project-init/claude-module-template.md` — The implementation guide template for module-specific conventions and patterns

### Step 4: Draft the Specification

Create a comprehensive spec that covers all 10 required sections:

1. **Purpose** — What is this module, who uses it, what problem does it solve?
2. **User Stories** — 3-8 stories in table format (ID, As a..., I want to..., So that...)
3. **Data Model** — TypeScript interfaces with field types and descriptions
4. **API / Server Actions** — For each endpoint: METHOD PATH, purpose, auth, request/response schemas, errors
5. **UI Screens** — For each route: purpose, key components, user flows, empty/loading/error states
6. **Business Logic & Rules** — Validation rules, calculations, edge cases, constraints
7. **Integration Points** — Which other modules this depends on or is used by (table format)
8. **Acceptance Criteria** — Checkbox list of testable conditions for completion
9. **Out of Scope** — Explicit exclusions and non-goals
10. **Open Questions** — Unresolved decisions marked with checkboxes

### Step 5: Present for Approval

Output both the `SPEC.md` and `CLAUDE.md` files in a readable format, then ask for approval:

- Show a summary of the spec structure
- Highlight any decisions or assumptions made
- Ask: "Does this spec match your intent? Any changes before I save it?"

### Step 6: Save on Approval

Once approved:

- Save `specs/modules/$ARGUMENTS/SPEC.md` with the full MODULE_SPEC
- Save `specs/modules/$ARGUMENTS/CLAUDE.md` with the implementation guide
- Confirm both files are saved and ready for implementation

## Module Argument

`$ARGUMENTS` = the module name (e.g., "auth", "dashboard", "analytics")

Use this to locate or create the spec directory and files.

## Key Guidelines

- **Data Model**: Use TypeScript interfaces; include field types, validation rules, and comments
- **API Endpoints**: Include full JSON request/response examples; list all error codes
- **UI Screens**: Describe layouts, interactions, and state variations (empty, loading, error)
- **Business Logic**: Be explicit about rules, constraints, and edge cases
- **Integration Points**: Show clearly what this module depends on and what depends on it
- **Acceptance Criteria**: Make these testable and concrete — they will be used to verify completion

## Next Steps After Spec Approval

Once a spec is approved, use the `/project-module $ARGUMENTS` skill to begin implementation. The implementation skill will read this spec and build the module incrementally with tests and commits.

---

**Templates**: See `../project-init/module-spec-template.md` and `../project-init/claude-module-template.md` for the structure and examples.
SKILL_SPEC_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-spec/SKILL.md"


mkdir -p ".claude/skills/project-module"
cat > ".claude/skills/project-module/SKILL.md" << 'SKILL_MODULE_EOF'
---
name: project-module
description: "Implement a module that already has an approved spec — reads all specs, enters plan mode, then builds incrementally with tests and commits. Use when ready to write code for a specific module, or when someone says 'build the X module', 'implement X', or 'start coding X'. The module MUST have a spec before implementation begins."
---

# Project Module: Implement a Fully-Specified Module

This skill builds a complete module from an approved specification. It reads all relevant documentation, creates a detailed implementation plan, then executes incrementally with testing and version control.

## When to Use

- **Starting implementation**: When a module spec is approved and ready to be built
- **Resuming work**: When returning to an in-progress module
- **Keyword triggers**: "build the X module", "implement X", "start coding X", "build X"

## Prerequisites

The module **MUST** have:
- An approved `specs/modules/$ARGUMENTS/SPEC.md`
- An implementation guide at `specs/modules/$ARGUMENTS/CLAUDE.md`

If either is missing, stop and run `/project-spec $ARGUMENTS` first.

## Process

### Step 1: Read All Foundation Documents

Before writing any code, read these in order:

1. **`specs/MASTER_BLUEPRINT.md`** — Understand the overall architecture, technology stack, and module relationships
2. **`specs/modules/$ARGUMENTS/SPEC.md`** — Read the complete specification for this module
3. **`specs/modules/$ARGUMENTS/CLAUDE.md`** — Read the implementation guide for module-specific patterns and conventions
4. **`specs/LEARNINGS.md`** — Check for patterns, mistakes, and lessons from previous modules
5. **`root/CLAUDE.md`** — Review root-level architecture, coding standards, and system-wide conventions

If any of these files are missing or incomplete, stop and note what needs to be created or updated.

### Step 2: Create Implementation Plan

Based on the spec, create a detailed plan with the following structure:

**Frontend Implementation Guidelines** (if UI included):
- Consult the `web-artifacts-builder` skill for React/Tailwind/shadcn UI patterns
- Use `ref_search_documentation` to research component library docs and framework patterns
- Use `get_code_context_exa` to find real code examples of similar implementations
- For complex UI flows, create a standalone prototype first before integrating
- Plan UI screens and components in order of dependency

**Testing Strategy**:
- Write unit tests after each logical chunk of code
- For UI modules, use Playwright for visual verification:
  - `browser_navigate` to each route
  - `browser_snapshot` to capture accessibility tree
  - `browser_take_screenshot` for visual evidence
  - Verify element structure and interactions
  - Test forms, buttons, and user flows
  - Capture console messages via `browser_console_messages` and report errors
- Create evidence (screenshots) for each completed screen
- Run full test suite before each commit

**Implementation Order**:
- Start with data models and types
- Build API endpoints / server actions
- Implement business logic and validation
- Create UI components and screens
- Write integration tests
- Final review against spec

**Commit Strategy**:
- Format: `feat([module-name]): [what was done]`
- Commit after each substantial piece of work that passes tests
- Include test evidence in commit messages

### Step 3: Present Plan for Approval

Output your implementation plan in a clear, readable format:

- List all planned work items in logical order
- Identify dependencies and blockers
- Estimate effort for each phase
- Ask: "Does this plan align with the spec? Any changes before I start coding?"

Wait for approval before proceeding.

### Step 4: Implement Incrementally

Once approved, build the module in phases:

#### Phase 1: Data Model & Types
- Create TypeScript interfaces for all entities
- Add validation schemas (Zod, etc.)
- Create type exports from `types/index.ts`

#### Phase 2: API Endpoints / Server Actions
- Implement each endpoint from the spec
- Add request/response validation
- Handle all error cases
- Write unit tests for each endpoint
- Verify with API testing tool

#### Phase 3: Business Logic & Utilities
- Implement calculation functions
- Add state transition logic
- Create helper functions
- Write comprehensive tests

#### Phase 4: Frontend Components (if applicable)
- Start with utility components (forms, buttons, inputs)
- Build page-level components
- Implement loading and error states
- Test with Playwright:
  - Navigate to route
  - Take accessibility snapshot
  - Verify DOM structure
  - Test interactions (form submission, button clicks)
  - Take screenshots of each state
  - Check console for errors
- Verify responsive design on mobile and desktop

#### Phase 5: Integration & Full Testing
- Test end-to-end workflows
- Verify integration with other modules
- Run full test suite
- Check for console errors and warnings

### Step 5: Quality Checks Before Completion

Before marking the module as complete:

- [ ] All acceptance criteria from spec are met
- [ ] All tests pass (unit, integration, and visual)
- [ ] No console errors or warnings
- [ ] Code matches conventions in CLAUDE.md
- [ ] Code is consistent with LEARNINGS.md patterns
- [ ] Module boundaries are respected (see CLAUDE.md)
- [ ] All spec requirements are implemented (not just partially)

### Step 6: Update Specs if Implementation Deviated

If implementation revealed issues or changes:

- Update `specs/modules/$ARGUMENTS/SPEC.md` to match actual implementation
- Update `specs/modules/$ARGUMENTS/CLAUDE.md` with new patterns discovered
- Add entry to `specs/LEARNINGS.md` with the lesson
- Keep specs and code in sync

### Step 7: Run Project Review

Once complete, run the `/project-review` skill to:

- Capture what was done and what wasn't
- Document learnings and patterns
- Update root-level CLAUDE.md if patterns should be shared
- Identify blockers or issues for the next session
- Get recommendation for the next task

## Module Argument

`$ARGUMENTS` = the module name (e.g., "auth", "dashboard", "analytics")

This is used to locate the spec and implementation guide.

## Implementation Checklist

- [ ] Read MASTER_BLUEPRINT.md
- [ ] Read module SPEC.md
- [ ] Read module CLAUDE.md
- [ ] Read LEARNINGS.md
- [ ] Read root CLAUDE.md
- [ ] Create and present implementation plan
- [ ] Get approval for plan
- [ ] Implement Phase 1: Data Model & Types
- [ ] Implement Phase 2: API Endpoints / Server Actions
- [ ] Implement Phase 3: Business Logic & Utilities
- [ ] Implement Phase 4: Frontend Components (if applicable)
  - [ ] Build components incrementally
  - [ ] Test with Playwright after each screen
  - [ ] Verify responsive design
  - [ ] Check console for errors
- [ ] Implement Phase 5: Integration & Full Testing
- [ ] Verify all acceptance criteria are met
- [ ] Update specs if implementation changed them
- [ ] Run `/project-review`
- [ ] Commit final changes

## Key Guidelines

**Incrementalism**: Don't try to build everything at once. Complete one phase, test it, commit it, then move to the next phase.

**Testing as you go**: Write tests after each chunk of code. Don't defer testing to the end.

**Visual verification**: For UI modules, take screenshots and accessibility snapshots after each screen is complete. This provides evidence and catches layout issues early.

**Respecting boundaries**: Check CLAUDE.md before calling functions or reading data from other modules. Respect module ownership.

**Consistency**: Reference LEARNINGS.md and CLAUDE.md frequently. Use the same patterns and conventions as the rest of the system.

**Specification fidelity**: The spec is the source of truth. If something seems unclear, check the spec first. If implementation requires changes to the spec, update it and document why.

## Troubleshooting

**Missing spec**: Run `/project-spec $ARGUMENTS` first.

**Unclear requirements**: Check the spec's "Open Questions" section. If still unclear, ask before implementing.

**Test failures**: Use `browser_console_messages` to check for JavaScript errors. Review test output carefully.

**Integration issues**: Verify module boundaries in CLAUDE.md. Check that you're not reading or writing data you shouldn't.

**Performance issues**: Reference the "Performance Considerations" section in CLAUDE.md.

## Next Steps After Completion

Once a module is complete:

1. Run `/project-review` to capture learnings
2. Review ROADMAP.md to identify the next module
3. Check for newly unlocked dependencies
4. Start the next module with `/project-spec` if it doesn't have a spec yet

---

**Reference**: See the SPEC.md and CLAUDE.md for this module for detailed requirements and patterns.
SKILL_MODULE_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-module/SKILL.md"

mkdir -p ".claude/skills/project-review"
cat > ".claude/skills/project-review/SKILL.md" << 'SKILL_REVIEW_EOF'
---
name: project-review
description: "End-of-session review — captures what was done, learnings, mistakes, and patterns, then updates LEARNINGS.md and CLAUDE.md. Run this after completing any task, at the end of a working session, or when switching to a different area of the project. This is what makes the system compound and get smarter over time."
---

# Project Review: Capture Learnings and Update Documentation

This skill closes out work on a module or feature by documenting what was accomplished, what was learned, what went wrong and how it was fixed, and what patterns should be shared across the project.

Running this skill regularly ensures the project knowledge compounds and future work is guided by past experience.

## When to Use

- **After completing a module**: When `/project-module $ARGUMENTS` finishes
- **End of working session**: When you're done for the day or switching focus
- **After significant learning**: When you discover a pattern, mistake, or gotcha that others should know
- **Before starting new work**: To ensure you're informed by previous lessons

## Optional isolated code-review pass (`--isolate`)

If `$ARGUMENTS` contains `--isolate`, **additionally** run a code-review pass in a fresh Explore-agent context (no edit/write tools, no parent transcript) on top of the normal in-session review. The Agent reviews only the diff for code-quality / correctness issues; the rest of this skill (session learnings, LEARNINGS.md / CLAUDE.md updates, next-task recommendation) still runs in this session because that work needs parent-session memory.

When `--isolate` is detected:

1. Capture the diff:

   ```bash
   diff_file="$(mktemp -t isolated-review-diff.XXXXXX)"
   trap 'rm -f "$diff_file"' EXIT
   if git rev-parse --verify origin/main >/dev/null 2>&1; then
     base="$(git merge-base origin/main HEAD)"
   elif git rev-parse --verify main >/dev/null 2>&1; then
     base="$(git merge-base main HEAD)"
   else
     base="HEAD~1"
   fi
   git diff "$base"..HEAD > "$diff_file"
   ```

2. Launch an Explore agent (read-only):

   ```text
   Agent(
     subagent_type="Explore",
     description="Isolated diff code-review",
     prompt="You are a code reviewer with no prior context. Review the diff below for code-quality issues only — correctness, clarity, naming, error handling, test coverage, simplicity. Output a markdown report with sections: Critical / High / Medium / Low. Quote file:line for each finding. Diff: <contents of $diff_file>"
   )
   ```

3. **Then** continue with the normal in-session steps below. Append the Agent's report to the final review output, clearly labelled "Isolated code-review pass (Explore agent)".

Without `--isolate` (the default), skip the Agent step and proceed with the in-session review only.

## Process

### Step 1: Summarize What Was Done

Document the work completed in this session:

- **What was accomplished**: List completed work items, features implemented, bugs fixed
- **What was NOT done**: List planned work that didn't get completed and why
- **Decisions made**: What technical choices did you make and why? (e.g., chose Framework X over Y, refactored Architecture Z)
- **Blockers encountered**: What got stuck? What took longer than expected?
- **Outstanding issues**: Bugs found but not fixed, tech debt identified, questions left unanswered

Write this in natural language, as a narrative summary. Be specific about what was built, not just generic statements.

**Example:**
> Completed authentication module. Implemented login/logout server actions, login form UI with error handling, and refresh token rotation. Discovered that Next.js needs explicit layout.tsx file for route groups — added to LEARNINGS. Form validation initially used custom logic, but switched to Zod for consistency. One bug with token refresh timing remains in local testing; added to ROADMAP as P2.

### Step 2: Capture Learnings

Add a new section to `specs/LEARNINGS.md` at the top (newest first) documenting:

#### What Patterns Worked

Document approaches and patterns that proved effective:

- **What pattern**: Describe the pattern briefly (e.g., "Using Zod for form validation", "Server-first data fetching in Next.js")
- **Why it worked**: What makes it effective? (e.g., "Catches validation errors before submission, prevents invalid data in DB")
- **Where to use it**: When should other modules use this? (e.g., "Use for all forms that write to the database")
- **Code example** (optional): If helpful, show a 5-10 line example

**Example:**
```markdown
### Pattern: Zod + Form Validation

Zod schemas work well for validating form inputs before submission. Define the schema at the top of the component, use it in the onSubmit handler, and display field-level errors.

Works best for: Forms with multiple fields, complex validation rules, real-time field validation

Example:
const schema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});
const [errors, setErrors] = useState({});
const onSubmit = async (data) => {
  const result = schema.safeParse(data);
  if (!result.success) {
    setErrors(result.error.flatten().fieldErrors);
    return;
  }
  // Submit...
};
```

#### Mistakes & Fixes

Document errors made and how they were corrected:

- **Mistake**: What went wrong? (e.g., "Tried to share state between modules directly")
- **Symptom**: How did you discover it? (e.g., "State changed in one place didn't update another")
- **Root cause**: Why did it happen? (e.g., "Didn't respect module boundaries")
- **Fix**: What's the right approach? (e.g., "Pass data through props or use a shared store")
- **Prevention**: How to avoid this in the future (e.g., "Review CLAUDE.md before importing from other modules")

**Example:**
```markdown
### Mistake: Direct State Sharing Between Modules

Tried to import state from auth module into dashboard module. Auth state changes weren't reflected in dashboard because they're separate module instances.

Fix: Pass auth state through context or read from a centralized store. Auth module exports hooks like useCurrentUser() that other modules use.

Prevention: Review "Module Boundaries" in CLAUDE.md. If you need data from another module, use its public API (exports from index.ts).
```

#### Stack-Specific Notes

Document learnings specific to the tech stack:

- **Framework/Library**: (e.g., "Next.js", "React Hook Form", "Tailwind CSS")
- **Learning**: What did you discover about how it works? (e.g., "Next.js route groups with parentheses don't appear in URL")
- **When it matters**: When would this affect implementation? (e.g., "When organizing routes, use (group)/ for visual grouping without affecting URL structure")

**Example:**
```markdown
### Next.js: Route Groups Don't Affect URLs

Route groups like (auth)/ organize folder structure but don't appear in the URL. Useful for grouping related routes without affecting the actual URL path.

Matters when: Organizing routes logically (e.g., (auth)/login, (auth)/signup both map to /login, /signup)
```

#### Open Questions

Document questions that came up but weren't fully resolved:

- **Question**: The unanswered question
- **Context**: Where did it come from? Why is it relevant?
- **Next steps**: How should it be resolved? Who should answer it?

**Example:**
```markdown
### Should we cache authentication tokens in localStorage?

Context: Token refresh timing is tight in some scenarios. Caching in localStorage would speed up page reloads.

Concerns: Security implications if token is compromised. Browser storage is accessible to JavaScript.

Next steps: Research Next.js session management best practices. Discuss with team before implementing.
```

### Step 3: Update Root CLAUDE.md and Module CLAUDE.md

If mistakes were repeated more than once or patterns are system-wide, update the CLAUDE.md files:

**Root `CLAUDE.md`**: Update if the pattern/rule applies to all modules
- Add to "Boundaries" section if it's a cross-module rule
- Add to "Patterns" section if it's a system-wide pattern
- Add to "Common Mistakes" if it's something everyone makes

**Module `specs/modules/$ARGUMENTS/CLAUDE.md`**: Update if the pattern is specific to this module
- Add to "Known Gotchas" if it's a surprise
- Add to "Module Boundaries" if the rules changed
- Update "Conventions" if new conventions were established

**Example change to root CLAUDE.md:**
```markdown
## Boundaries

### Cross-Module Communication

- Use public exports (index.ts) to communicate between modules
- Don't import internal files (_private.ts) from other modules
- Prefer hooks (useAuth(), useUser()) over direct state access
- If you need data from another module, that module should export a public API for it
```

### Step 4: Update Specs if Implementation Deviated

If implementation revealed gaps or changes, sync the specs:

- **Update SPEC.md**: Did implementation find different requirements, additional edge cases, or omissions? Update the spec to match what was actually built.
- **Update CLAUDE.md**: Did you discover new patterns or gotchas specific to this module? Add them.
- **Document why**: If spec and code diverged, explain why in a comment or in LEARNINGS.md

Keep specs and code in sync. Specs should be the source of truth.

### Step 5: Recommend Next Task

Based on work completed and the project ROADMAP.md, identify what should be done next:

- **Unlocked dependencies**: What work became possible because of this module?
- **Blockers**: What's waiting on other work?
- **Priority**: What has the highest business value or technical importance?
- **Recommendation**: "Next session should build [module], which unblocks [other modules] and is needed for [feature]."

Write a clear "Next session should:" statement.

**Example:**
```
Next session should:
Build the dashboard module, which is now unblocked by auth completion.
Dashboard depends on auth for user context and will unlock analytics and reporting features.
This is the highest priority per the roadmap.
```

## Review Template

Here's a template to follow:

```markdown
# Review: [Module Name / Feature]

## Work Completed

- [Item 1]: [Description of what was built]
- [Item 2]: [Description of what was built]
- [Blocker]: [What didn't get done and why]

## Decisions Made

- [Decision 1]: [Why]
- [Decision 2]: [Why]

## Key Learnings

### Patterns That Worked
- [Pattern]: [Why and when to use]

### Mistakes & Fixes
- [Mistake]: [How it was fixed, how to prevent]

### Stack Notes
- [Framework]: [Learning about how it works]

### Open Questions
- [Question]: [Context and next steps]

## Spec Updates

- Updated SPEC.md: [What changed and why]
- Updated CLAUDE.md: [Patterns added]

## Next Session Should

Build the [module] module, which is now unblocked and will unlock [other modules].
Priority: [P0/P1/P2]
```

## Example Review

```markdown
# Review: Authentication Module

## Work Completed

- Implemented login/logout server actions with NextAuth
- Built login form with email/password and error handling
- Added token refresh rotation with 15-minute expiry
- Implemented useCurrentUser() hook for client components
- 92% test coverage with unit and integration tests
- Did NOT complete OAuth (Google/GitHub) — scoped to Phase 2

## Decisions Made

- Chose NextAuth over custom JWT: industry standard, handles edge cases, security-focused
- Stored tokens in httpOnly cookies: more secure than localStorage
- Refresh tokens have rolling expiry: ensures old tokens don't persist

## Key Learnings

### Pattern: useCurrentUser() Hook

Created a custom hook that fetches the current user on mount and caches it. Other modules use this hook instead of importing state directly. Works well.

### Mistake: httpOnly Cookies in Dev

Spent 2 hours debugging why cookies weren't persisting in local dev. Root cause: httpOnly not working with localhost in some browsers. Fixed by checking browser dev tools for cookie storage.

### Next.js Note

API routes in /api/ are server-side. I initially tried server-only imports in API routes; they work fine. Just remember: API routes are always server-side in Next.js 14.

### Open Question

Should we implement "Remember Me" functionality? Conflicts with security best practices. Needs team discussion.

## Spec Updates

Updated CLAUDE.md with "Token Refresh Timing" gotcha and added useCurrentUser() pattern example.

## Next Session Should

Build the dashboard module, which needs authenticated user context (now available). Dashboard is P0 and unblocks 3 dependent features.
```

## Running This Skill

This skill doesn't build or deploy anything — it documents. After running it:

1. Read the summary and learnings you've captured
2. Review the recommendations for the next session
3. Consider committing the LEARNINGS.md and CLAUDE.md updates to version control
4. Share learnings with the team if relevant

## Key Guidelines

**Be specific**: Don't write "It was hard." Write "The token refresh timing was complex because Next.js middleware timing is asynchronous and we needed to queue requests while refreshing."

**Focus on why, not just what**: "Used Zod because it catches validation errors before DB writes and prevents cascading issues" is better than "We used Zod."

**Update root CLAUDE.md sparingly**: Only add rules that apply to the whole system. Module-specific patterns go in module CLAUDE.md.

**Keep learnings evergreen**: Update LEARNINGS.md when you discover something new, but also clean up outdated learnings when patterns change.

**Link to code**: If helpful, reference file paths: "See src/modules/auth/hooks/useCurrentUser.ts for the pattern implementation."

## Why This Matters

This skill is how the system gets smarter over time. Each module's lessons compound:
- New modules don't repeat old mistakes
- System-wide patterns become consistent
- Complex gotchas are documented for future developers
- Architecture decisions are captured and explained
- The project becomes easier to navigate and contribute to

Running this at the end of every session ensures knowledge isn't lost.

---

**Reference**: See LEARNINGS.md for existing learnings. Check CLAUDE.md before implementing to benefit from previous discoveries.
SKILL_REVIEW_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-review/SKILL.md"

mkdir -p ".claude/skills/project-status"
cat > ".claude/skills/project-status/SKILL.md" << 'SKILL_STATUS_EOF'
---
name: project-status
description: "Show a complete project status dashboard — what specs exist, what's been implemented, what's next, and overall health. Use when someone asks 'where are we', 'what's the status', 'what should I work on next', or at the start of any new session to orient yourself."
---

# Project Status Dashboard

I'll generate a comprehensive status report of your AI Project Kit, checking spec completeness, code implementation, learnings, and recommended next steps.

## Steps

### 1. Read Project State

First, I'll check the existence and status of all specification and planning documents:

- **specs/RESEARCH.md** — research and discovery phase
- **specs/MASTER_BLUEPRINT.md** — system architecture and technical decisions
- **specs/ROADMAP.md** — planned milestones and work items
- **specs/modules/*/SPEC.md** — individual module specifications

For each, I'll note:
- Whether it exists
- Key summary (scope, status, key decisions)
- Any blockers or open questions

### 2. Check Implementation Status

I'll examine the source code directories to determine which modules have:
- **Spec only** — design document exists, no code yet
- **In Progress** — both spec and partial code
- **Complete** — spec and production code
- **Not started** — no spec, no code

### 3. Review Learnings

I'll read LEARNINGS.md (if it exists) to:
- Count total learning entries
- Identify open questions still needing answers
- Note any recurring patterns or blockers

### 4. Generate Status Dashboard

I'll produce a clean, actionable status table with:
- Research, Blueprint, Roadmap completion status
- Module-by-module status (spec + code)
- Learning entry count and open questions
- A recommended next task based on project state

### 5. Recommend Next Steps

Using the project state, I'll suggest:
- Which module to work on next (using `/project-module`)
- Whether to focus on specs, code, tests, or deployment
- Any pre-requisite work needed

## Output Format

```
PROJECT STATUS — [date]
================================

SPECS:
  Research:     ✅ Complete / ❌ Missing / 🔄 In progress
  Blueprint:    ✅ Complete / ❌ Missing / 🔄 In progress
  Roadmap:      ✅ Complete / ❌ Missing / 🔄 In progress

MODULES:
  module-name   ✅ Spec  ✅ Code  |  Summary of status
  ...

LEARNINGS: [X] entries ([Y] open questions)

HEALTH CHECK:
  Tests:        ✅ Passing / ⚠️ Warnings / ❌ Failing
  Deploy:       ✅ Ready / 🔄 In progress / ❌ Blocked
  Quality:      ✅ Good / ⚠️ Needs work

NEXT RECOMMENDED TASK:
  For module focus: /project-module module-name
  For testing:      /project-test
  For deployment:   /project-deploy
  For deep dive:    /project-research
```

## Key Commands

Once you have status, use these related commands:
- `/project-module [name]` — deep dive into a specific module
- `/project-test` — run comprehensive test pass
- `/project-deploy` — deploy to preview or production
- `/project-research [question]` — research and document findings
SKILL_STATUS_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-status/SKILL.md"

mkdir -p ".claude/skills/project-deploy"
cat > ".claude/skills/project-deploy/SKILL.md" << 'SKILL_DEPLOY_EOF'
---
name: project-deploy
description: "Deploy the current project to a preview or production environment. Runs pre-deploy checks, deploys (with Vercel integration if available), and verifies the deployment with browser automation. Use when someone says 'deploy', 'ship it', 'push to production', 'create a preview', or 'let me see it live'."
---

# Project Deploy

I'll perform a complete deployment workflow: pre-deploy checks, environment setup, deployment execution, post-deploy verification, and a summary report.

## Pre-Deployment Checks

### 1. Test Suite Validation

I'll run the full test suite to ensure code quality before deploy:
- Read MASTER_BLUEPRINT.md for the configured test command
- Execute tests with: `[test-command]`
- Report pass/fail count
- Block deployment if tests fail (unless explicitly overridden)

### 2. Source Control Status

I'll check for uncommitted changes:
- Run `git status`
- Warn if any untracked or modified files exist
- Request confirmation before deploying with dirty state

### 3. Environment Validation

I'll verify deployment readiness:
- Check for `.env` or `.env.local` files (flag if missing)
- Verify required environment variables are set for deployment target
- Warn about any secrets that might be exposed or missing
- Check deployment configuration (vercel.json, netlify.toml, etc.)

### 4. Code Quality Checks

I'll validate code quality:
- Run type checker (tsc, mypy, etc.) if configured
- Run linter (eslint, ruff, etc.) if configured
- Report any blocking issues

If pre-deploy checks fail, I'll stop and provide remediation steps.

## Deployment Execution

### For Vercel Projects

If MASTER_BLUEPRINT.md indicates Vercel deployment:

1. **Trigger deployment:**
   - Use `deploy_to_vercel` MCP tool to initiate deployment
   - Note deployment ID and URL

2. **Monitor deployment:**
   - Use `get_deployment` to check status
   - Poll for completion (typically 2-5 minutes)
   - Use `get_deployment_build_logs` to monitor build progress

3. **Handle build failures:**
   - If build fails, read error logs with `get_deployment_build_logs`
   - Analyze and present the error with:
     - Root cause (missing dependency, build config error, etc.)
     - File and line number
     - Suggested fix
   - Recommend remediation and offer to fix or retry

### For Other Deployment Targets

If non-Vercel deployment (specified in MASTER_BLUEPRINT.md):

1. Execute the configured deploy command
2. Capture and present output
3. Check exit code — block if non-zero
4. Present build logs if deployment fails

## Post-Deployment Verification

### 1. URL Verification

I'll confirm the deployment is accessible:
- Use `browser_navigate` to visit the deployed URL
- Verify HTTP 200 response (not 5xx, not redirects to error pages)
- Check page loads without errors

### 2. Smoke Testing

I'll test core functionality:
- `browser_snapshot` to verify page structure/accessibility tree
- `browser_take_screenshot` for visual baseline
- Navigate to key routes (home, about, main feature pages)
- Test interactive elements (forms, buttons, navigation)
- Verify responsive design (test mobile viewport if applicable)

### 3. Runtime Validation

I'll check for runtime errors:
- Use `browser_console_messages` with pattern `"error|exception"` to catch errors
- Verify critical features are accessible and functional
- Test critical user flows:
  - Sign up / login (if applicable)
  - Main feature workflows
  - Data submission (if applicable)

### 4. Performance Check

I'll verify basic performance:
- Check page load time (report if >3s for initial page)
- Verify images load correctly
- Check for failed resource requests with `browser_network_requests`

## Failure Handling

If any verification fails:

1. **Document the issue:**
   - Page/route where failure occurred
   - Error message or assertion that failed
   - Screenshot of the failure state

2. **Diagnosis:**
   - Check logs (`get_deployment_build_logs` or `browser_console_messages`)
   - Identify root cause

3. **Options:**
   - Rollback deployment (if previous version available)
   - Fix the issue locally, commit, and redeploy
   - Present issue details for manual investigation

## Post-Deploy Summary

I'll update project state:
- Note deployment URL and environment (preview/production)
- Record deployment timestamp
- Update LEARNINGS.md with deployment metrics
- Update module statuses if this was a release milestone
- Flag any issues found and their status

## Deployment Report

```
DEPLOYMENT REPORT — [date]
================================

TARGET:
  Environment:  [preview / production]
  URL:          [deployment-url]
  Deployment ID: [id]

PRE-DEPLOY CHECKS:
  Tests:           ✅ 42/42 passed
  Git status:      ✅ Clean (0 uncommitted changes)
  Type checking:   ✅ No errors
  Linting:         ✅ No errors
  Environment:     ✅ All required vars set

BUILD:
  Status:          ✅ Success (built in 2m 15s)
  Build logs:      ✅ No warnings

VERIFICATION:
  URL access:      ✅ 200 OK
  Page load:       ✅ 1.2s (home page)
  Navigation:      ✅ 5/5 routes working
  Forms:           ✅ Submission tested
  Console errors:  ❌ 1 error on /dashboard

ISSUES FOUND:
  1. TypeError on dashboard loading (non-critical)

NEXT STEPS:
  - Fix console error and redeploy, OR
  - Leave as-is (error doesn't block functionality), OR
  - Create follow-up task for dashboard fix

ROLLBACK:
  Previous version: [version-id]
  To rollback: [instructions]
```

## Key Commands

- `/project-test` — Run comprehensive test suite before deploying
- `/project-status` — Check overall project readiness
- `/project-module [name]` — Review specific module before deploying it
SKILL_DEPLOY_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-deploy/SKILL.md"

mkdir -p ".claude/skills/project-test"
cat > ".claude/skills/project-test/SKILL.md" << 'SKILL_TEST_EOF'
---
name: project-test
description: "Run a comprehensive test pass across the project — unit tests, type checking, linting, and visual verification with browser automation. Use when someone says 'run the tests', 'check everything works', 'test the project', or before deploying to verify quality."
---

# Project Test

I'll run a comprehensive test pass across all quality gates: unit tests, type checking, linting, and visual/integration verification.

## Test Infrastructure Discovery

I'll identify the test setup by reading:
- **MASTER_BLUEPRINT.md** — configured test command, type checker, and linter
- **package.json** (or equivalent) — available test scripts and dependencies
- **Module specs** — which modules have UI components vs API-only code
- **Test directories** — identify test file locations and coverage

This tells me:
- Test runner (jest, pytest, vitest, etc.)
- Type checker (tsc, mypy, etc.)
- Linter (eslint, ruff, etc.)
- Which modules have visual components to test

## Unit & Integration Tests

### 1. Run Test Suite

Execute the configured test command:
```
[test-command-from-MASTER_BLUEPRINT]
```

### 2. Parse Results

From test output, capture:
- Total tests run
- Pass count
- Fail count
- Skipped count
- Execution time

### 3. Report Failures

For each test failure, I'll extract:
- Test file and describe block
- Test name (what was being tested)
- Expected value
- Actual value
- Stack trace (first 5 lines)
- Suggested fix (based on error type)

Example output:
```
FAILED: src/modules/contacts/contact.spec.ts
  › Contact creation
    Expected: email validation
    Actual: accepted invalid email
    Fix: Check ContactForm.validateEmail() in contacts/form.tsx line 34
```

### 4. Calculate Coverage

If coverage reports are available:
- Report overall coverage percentage
- Flag modules/files with <80% coverage
- Suggest tests for uncovered lines

## Type Checking

### 1. Run Type Checker

Execute the configured type checker:
```
tsc --noEmit              (for TypeScript projects)
mypy src/                 (for Python projects)
```

### 2. Parse Type Errors

For each error, capture:
- File path
- Line number
- Column number
- Error message
- Context (the offending line)

Example:
```
TYPE ERROR: src/api/users.ts:24
  Property 'email' does not exist on type 'User'
  Line 24: const email = user.email;
           ^^^^^^^^^^
  Fix: User type should extend { email: string }
```

### 3. Report Summary

- Total type errors
- Errors by severity (error vs warning)
- Files with most errors
- Recommendation to fix before deploy

## Linting

### 1. Run Linter

Execute the configured linter:
```
eslint src/               (for JavaScript/TypeScript)
ruff check src/           (for Python)
```

### 2. Parse Violations

For each violation:
- File path
- Line number
- Rule name
- Message
- Auto-fix available? (yes/no)

### 3. Auto-Fix Where Possible

- Run linter with `--fix` flag to auto-correct violations
- Report what was fixed
- For remaining violations, suggest manual fixes

Example:
```
LINTING: src/components/Button.tsx
  ✅ Fixed 3 issues:
    - 2x unused imports (auto-removed)
    - 1x incorrect spacing (auto-fixed)
  ⚠️ 1 issue requires manual fix:
    - Line 15: Missing JSDoc for exported function
      Fix: Add comment: /** Button component with text */
```

## Visual Verification (UI Projects)

For projects with UI components, I'll use Playwright browser automation to verify functionality and appearance.

### 1. Start Development Server

If not running:
- Check if dev server is accessible (http://localhost:3000, etc.)
- If not, start it: `npm run dev` (or equivalent)
- Wait for server to be ready

### 2. Discover Routes

Identify all implemented routes by:
- Reading module specs
- Checking routing config (next.config.js, vite.config.ts, etc.)
- Looking at URL patterns in source code

Routes to test (example):
- `/` (home)
- `/modules/contacts` (contacts module)
- `/modules/deals` (deals module)
- etc.

### 3. Test Each Route

For each route, I'll:

**Navigation & Page Load:**
- `browser_navigate` to the route
- Verify page loads (HTTP 200, no redirect loops)
- Check page title/heading matches expected content

**Accessibility & Structure:**
- `browser_snapshot` to get accessibility tree
- Verify main content elements are present
- Check heading hierarchy (h1 → h2 → h3)
- Verify form labels, buttons, and interactive elements

**Visual Verification:**
- `browser_take_screenshot` for each page
- Verify layout is clean (no overlapping elements)
- Check responsive design (test mobile viewport: 375px width)
- Look for visual regressions vs baseline

**Interaction Testing:**
- Test form inputs: type text, verify input values
- Test buttons: click and verify actions
- Test navigation: click links and verify routing
- Test dropdowns/selects: expand and verify options

**Runtime Health:**
- `browser_console_messages` with pattern `"error|exception|Warning"` to catch:
  - JavaScript errors
  - Uncaught exceptions
  - Deprecation warnings
- Report each error with:
  - Error message
  - File/line where error occurred
  - Suggested fix

Example:
```
ROUTE VERIFICATION: /modules/contacts
  ✅ Page loads in 1.2s
  ✅ All expected elements present
  ✅ Forms submit correctly
  ✅ Navigation works
  ❌ Console error: TypeError: Cannot read property 'map' of undefined
     at ContactList.tsx:45
     Fix: Add null check: contacts?.map(...) or contacts && contacts.map(...)
```

### 4. Test Critical User Flows

For each major feature, test end-to-end flow:

**Example: Contact Creation Flow**
```
1. Navigate to /modules/contacts
2. Click "New Contact" button
3. Fill form: name, email, phone
4. Click "Save"
5. Verify contact appears in list
6. Verify confirmation toast shows
7. Verify no console errors
```

Report per-flow:
- Steps completed successfully
- Any failures or errors encountered
- Performance metrics (time to complete)

## Test Report Summary

```
TEST REPORT — [date]
================================

DISCOVERY:
  Test runner:    jest 29.5.0
  Type checker:   tsc 5.0.2
  Linter:         eslint 8.40.0
  Modules:        12 total (8 with UI)

UNIT TESTS:
  Total:          247 tests
  Passed:         ✅ 245 (99.2%)
  Failed:         ❌ 2
  Skipped:        ⏭️  0
  Duration:       2m 15s
  Coverage:       ✅ 84.3% (target: 80%)

  FAILURES:
    1. src/modules/deals/deal.spec.ts — Deal amount calculation
       Expected: $1,500.00
       Actual:   $1,50.00
       Fix: Check Decimal.ts line 42 — missing precision handling

    2. src/api/email.spec.ts — Email validation
       Expected: reject invalid domain
       Actual:   accepted "test@invalid"
       Fix: Update regex in validateEmail() or use email-validator package

TYPE CHECKING:
  Total errors:   ⚠️ 3
  Type errors:    src/components/Form.tsx:24
                  src/api/users.ts:18
                  src/modules/deals/calc.ts:5

  Recommendation: Fix before deploying

LINTING:
  Total violations: 12
  Auto-fixed:       ✅ 8
  Remaining:        ⚠️ 4

  Issues:
    - 2x unused imports (auto-fixed)
    - 2x missing JSDoc (manual fix needed)
    - Line 15 of Button.tsx: Add /** Button component */

VISUAL VERIFICATION (UI Routes):
  Routes tested:  ✅ 8/8
  Pages loaded:   ✅ 8/8 (avg 1.1s)
  Forms tested:   ✅ 6/6
  Console errors: ❌ 1 error on /modules/deals

  ERRORS FOUND:
    /modules/deals — TypeError: Cannot read property 'amount' of undefined
    at DealForm.tsx:67
    Fix: Add null check before accessing deal.amount

RESPONSIVE DESIGN:
  Desktop (1024px):  ✅ Verified
  Tablet (768px):    ⚠️ 1 overflow issue on /modules/contacts
  Mobile (375px):    ⚠️ 2 layout issues

OVERALL HEALTH:
  Status:         ⚠️ Ready with warnings
  Ready to deploy: No (fix 1 test + 1 type error + console error)
  Estimated time to fix: 30-45 minutes

RECOMMENDED ACTIONS:
  1. Fix Deal amount calculation test (unit test failure)
  2. Fix email validation type error
  3. Fix TypeError on /modules/deals page
  4. Fix mobile responsive issues (optional for v1)
  5. Add missing JSDoc comments (nice-to-have)

NEXT STEPS:
  /project-deploy          (after issues resolved)
  /project-module deals    (deep dive on deal issues)
```

## Key Commands

- `/project-status` — Check overall project status
- `/project-deploy` — Deploy after tests pass
- `/project-module [name]` — Deep dive on specific module with failures
- `/project-research [question]` — Research and document technical debt
SKILL_TEST_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-test/SKILL.md"

# =============================================================================
# SKILL: project-execute (dual-harness)
# =============================================================================

cat > ".claude/skills/project-execute/SKILL.md" << 'SKILL_EXECUTE_EOF'
---
name: project-execute
description: Implement a fully-specced module via dual-harness execution — Claude orchestrates, Codex CLI executes inside a live tmux pane in your attached session. Use when ready to write code for a module that has approved SPEC.md and CLAUDE.md files. Triggers on phrases like 'execute the X module via codex', 'dual-harness build', or '/project-execute X'.
effort: high
---

# project-execute

Hands a fully-specced module to Codex CLI (gpt-5.5) for implementation while Claude Code retains plan/review responsibilities. Live progress streams into a tmux pane that splits into your most-recent attached session.

## Prerequisites (abort if missing)

1. **`$ARGUMENTS` validation**: must match `^[a-z0-9][a-z0-9-]*$` (kebab-case, no slashes, no `..`). Abort if missing or invalid: ask the user "Which module? Existing modules: <list of `specs/modules/*/`>". If invalid, refuse and explain.
2. Read `CLAUDE.md` (root) — operating rules.
3. Read `specs/MASTER_BLUEPRINT.md` — system architecture. **If missing**: stop and tell the user "No `specs/MASTER_BLUEPRINT.md` found. Run `/project-blueprint` first to establish the architecture, then re-run `/project-execute`."
4. Read `specs/modules/$ARGUMENTS/SPEC.md` — module spec. If missing: stop and tell the user "No spec at `specs/modules/$ARGUMENTS/SPEC.md`. Run `/project-spec $ARGUMENTS` first."
5. Read `specs/modules/$ARGUMENTS/CLAUDE.md` — module conventions. If missing: same as above.
6. Read `LEARNINGS.md` (optional) — accumulated patterns.

## Build the dispatch prompt

**First, compute one timestamp token and reuse it for every artefact in this run** (so the prompt file, log file, and last-message file all share the same `<TS>`):

```bash
TS="$(date +%Y%m%d-%H%M%S)-$$"
```

Then concatenate the following into a single prompt file at `.kit-orchestration/exec-$ARGUMENTS-$TS-prompt.md`:

1. A header: model + effort + module name + timestamp.
2. The full text of `CLAUDE.md` (root).
3. The full text of `specs/MASTER_BLUEPRINT.md`.
4. The full text of the module's `SPEC.md`.
5. The full text of the module's `CLAUDE.md`.
6. An explicit instruction block:

   ```text
   You are the executor in a dual-harness orchestration. Implement the module
   above end-to-end. Constraints:

   - Build phase by phase. After each phase, run any tests you can.
   - Do NOT commit. Leave the working tree dirty for the orchestrator to
     inspect, smoke-test, and split into commits. Record proposed commit
     boundaries in the `proposed_commits` field of your final report.
   - Do NOT `git push`. Do NOT touch .git/ directly. Do NOT modify CI
     configuration (.github/, etc.).
   - Do NOT modify files outside the module's directory unless the spec
     requires shared edits. List any such edits in `files_modified`.
   - Re-read any "Explicit negatives" section in the prompt before acting;
     spec body negatives ("don't add X", "trust Y only") are repeated there
     for emphasis and must be honoured.
   - Stop and ask if any spec instruction is ambiguous; record questions
     in the `open_questions` field of your final report.
   - Your final agent message must be a JSON object conforming to the schema
     at .claude/skills/project-execute/codex-report-schema.json (the dispatcher
     enforces this via --output-schema).
   ```

7. The full prompt template at `.claude/skills/project-execute/dispatch-prompt-template.md` provides the canonical assembly order; follow it. **Always include an "Explicit Negatives" section** listing kit-wide and spec-derived prohibitions so they're reiterated in the constraints block, not buried in the spec body.

## Why Codex doesn't commit

Codex's `workspace-write` sandbox blocks `.git/index.lock`, so commits would fail anyway. More importantly, **orchestrator-commits is the canonical pattern by design**:

- Claude reads the scrubbed log + structured report, smoke-tests the working tree, then splits commits at sensible boundaries.
- Co-Authored-By attribution stays on every commit.
- The verification gate catches Codex spec deviations before they land in history.
- No need for `KIT_CODEX_SANDBOX=danger-full-access` (which is what it sounds like).

If you genuinely need Codex to commit (e.g. multi-turn runs that depend on intermediate state), set `KIT_CODEX_SANDBOX=danger-full-access` per-run — but the default flow does not.

## Dispatch via dispatch.sh

Run, as a single Bash tool call (reusing the same `$TS` from the prompt-build step):

```bash
bash .claude/lib/dispatch.sh execute "$ARGUMENTS" gpt-5.5 medium \
  ".kit-orchestration/exec-$ARGUMENTS-$TS-prompt.md"
```

The dispatcher handles tmux split (into the most-recent attached session), log capture, lock acquisition, auth/model preflight, timeout enforcement, and exit-code propagation. **Note**: dispatch.sh writes raw logs — secret scrubbing happens later, when this skill reads the log back. If `dispatch.sh` exits non-zero, surface the error and stop.

## After Codex returns

Use the same `$TS` from the prompt-build step. **All of `-report.json`, `-last.md`, and `.log` must be piped through `scrub-secrets.sh` before re-entering Claude's context** — even the schema-validated report can contain credentials Codex echoed during the run.

1. Read the scrubbed structured report (preferred): `bash .claude/lib/scrub-secrets.sh .kit-orchestration/execute-$ARGUMENTS-$TS-report.json`. This is JSON conforming to `codex-report-schema.json` — `phases_completed`, `files_modified`, `files_created`, `tests_run`, `proposed_commits`, `deviations`, `open_questions`. Trust the structure, but verify each field against repo state.
2. **Cross-check the report against ground truth.** Run `git status --short`, `git diff --stat`, and the test commands listed in `tests_run`. If `phases_completed` references work that doesn't appear in the diff, treat it as bleed-through and flag to the user. Schema enforcement gives shape; ground truth gives correctness.
3. Read the scrubbed JSONL events for context if needed: `bash .claude/lib/scrub-secrets.sh .kit-orchestration/execute-$ARGUMENTS-$TS.jsonl | jq -c .`. Or the pretty log: `tail -200 .kit-orchestration/execute-$ARGUMENTS-$TS.log`. Never read raw `.log`/`.jsonl`/`-report.json` directly.
4. **Apply `proposed_commits` from the report** (orchestrator-commits pattern). Stage files, write commits with the proposed subjects + Conventional Commit prefixes + `Co-Authored-By: Codex CLI gpt-5.5 (medium)`. If you disagree with the boundaries, split or merge as you see fit before committing.
5. Summarise to the user: phases completed (verified), commits applied, tests run, deviations from spec, open questions.
6. **Run the review skill in this session**: read `.claude/skills/project-review/SKILL.md` and follow its instructions to update `LEARNINGS.md`. (Skills cannot literally invoke other skills as user actions; this is the Claude-reads-and-follows pattern.) Alternatively, if the user prefers an isolated review, suggest they run `/project-review --isolate` (added in PR3).
7. Do NOT push the branch — that's the user's call.

Note: the `<TS>` placeholders in any spec or log examples elsewhere in the kit refer to the same `$TS` value computed once per `/project-execute` run.
SKILL_EXECUTE_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-execute/SKILL.md"

cat > ".claude/skills/project-execute/codex-report-schema.json" << 'SCHEMA_REPORT_EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Codex Final Report",
  "description": "Schema enforced via `codex exec --output-schema` so the executor's final message is machine-readable. Catches training-data bleed-through (free-form claims like 'X is now complete' for projects that aren't this one) by forcing every field to map to repo state the orchestrator can verify.",
  "type": "object",
  "additionalProperties": false,
  "required": [
    "phases_completed",
    "files_modified",
    "files_created",
    "tests_run",
    "proposed_commits",
    "deviations",
    "open_questions"
  ],
  "properties": {
    "phases_completed": {
      "type": "array",
      "description": "Phases or numbered steps from the module spec that were completed. Use the exact step numbers/names from CLAUDE.md.",
      "items": { "type": "string" }
    },
    "files_modified": {
      "type": "array",
      "description": "Repository-relative paths of modified existing files.",
      "items": { "type": "string" }
    },
    "files_created": {
      "type": "array",
      "description": "Repository-relative paths of newly created files.",
      "items": { "type": "string" }
    },
    "tests_run": {
      "type": "array",
      "description": "Each test command actually executed and its outcome.",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["command", "outcome"],
        "properties": {
          "command": { "type": "string" },
          "outcome": { "type": "string", "enum": ["passed", "failed", "skipped"] },
          "notes": { "type": "string" }
        }
      }
    },
    "proposed_commits": {
      "type": "array",
      "description": "Suggested commit boundaries for the orchestrator. Codex MUST NOT commit; the orchestrator inspects the working tree and applies these.",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["subject", "paths"],
        "properties": {
          "subject": { "type": "string", "description": "Conventional Commit subject line, <72 chars." },
          "body": { "type": "string", "description": "Optional commit body explaining motivation." },
          "paths": {
            "type": "array",
            "description": "Repository-relative paths included in this commit.",
            "items": { "type": "string" }
          }
        }
      }
    },
    "deviations": {
      "type": "array",
      "description": "Anywhere this run departed from the spec. Empty array if perfect compliance.",
      "items": {
        "type": "object",
        "additionalProperties": false,
        "required": ["spec_section", "what_changed", "reason"],
        "properties": {
          "spec_section": { "type": "string", "description": "Spec section reference (e.g. 'SPEC.md §6 brownfield detection')." },
          "what_changed": { "type": "string" },
          "reason": { "type": "string" }
        }
      }
    },
    "open_questions": {
      "type": "array",
      "description": "Questions Codex couldn't resolve and wants the orchestrator to decide.",
      "items": { "type": "string" }
    }
  }
}
SCHEMA_REPORT_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-execute/codex-report-schema.json"

# -----------------------------------------------------------------------------
# .claude/skills/project-tracks/SKILL.md
# -----------------------------------------------------------------------------

mkdir -p ".claude/skills/project-tracks"
cat > ".claude/skills/project-tracks/SKILL.md" << 'SKILL_TRACKS_EOF'
---
name: project-tracks
description: Plan and start isolated parallel module implementation tracks from specs/MODULES.md and per-module parallel.yaml declarations.
effort: high
---

# /project-tracks

Parallel module implementation command. Stage 1 supports:

- `/project-tracks plan [modules...] [--harness=codex|claude]`
- `/project-tracks start [modules...] [--harness=codex|claude]`

Use the helper script for deterministic parsing and side effects:

```bash
bash .claude/lib/project-tracks.sh plan "$ARGUMENTS"
bash .claude/lib/project-tracks.sh start "$ARGUMENTS"
```

## Plan

Run:

```bash
bash .claude/lib/project-tracks.sh plan [modules...] [--harness=codex|claude]
```

Requirements enforced by the helper:

- `specs/MODULES.md` must exist, otherwise print clear guidance.
- Each selected module must have `specs/modules/<module>/parallel.yaml`.
- `parallel.yaml` must declare `version: 1`.
- Selected modules must not have dependency edges between each other in `specs/MODULES.md`.
- Selected modules must not declare the same `shared:` path.
- Total selected modules must be `<= KIT_PARALLEL_MAX` (default 4).
- Missing `parallel.yaml` prints `add parallel.yaml or run sequentially`.

`plan` is read-only. It prints a proposal and does not create worktrees,
registry entries, locks, panes, logs, or branches.

## Start

Run:

```bash
bash .claude/lib/project-tracks.sh start [modules...] [--harness=codex|claude]
```

`start` reuses the same validation as `plan`, then for each selected module:

1. Creates `.claude/worktrees/track-<module>` on branch `track/<module>`.
2. Copies files listed in `.worktreeinclude` when they exist.
3. Reserves `KIT_PARALLEL_PORT_BASE + index` (default `3000 + index`).
4. Appends a running entry to `.claude/parallel/tracks.json` under a mkdir lock.
5. Launches the selected harness in the worktree.

All tracks in one invocation use the same harness. Default harness is `codex`.

For Codex tracks, the helper launches `.claude/lib/dispatch.sh` with:

```bash
KIT_ALLOW_CONCURRENT=1
KIT_PARALLEL_TRACK=<module>
KIT_PARALLEL_PORT=<reserved-port>
PORT=<reserved-port>
```

For Claude tracks, the helper uses `claude -w track-<module>` when the Claude
CLI is available.
SKILL_TRACKS_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-tracks/SKILL.md"

cat > ".claude/skills/project-execute/dispatch-prompt-template.md" << 'TEMPLATE_DISPATCH_PROMPT_EOF'
# project-execute Dispatch Prompt Template

Use this template when assembling `.kit-orchestration/exec-<module>-<timestamp>-prompt.md`.
Keep the section order stable so Codex receives project-wide rules before module-specific instructions.

---

## 1. Dispatch Header

<!-- placeholder: model, reasoning effort, module name, timestamp, repository root -->

---

## 2. Root Operating Rules

Source: `CLAUDE.md`

<!-- placeholder: full root CLAUDE.md content -->

---

## 3. Master Blueprint

Source: `specs/MASTER_BLUEPRINT.md`

<!-- placeholder: full master blueprint content -->

---

## 4. Module Specification

Source: `specs/modules/<module>/SPEC.md`

<!-- placeholder: full module SPEC.md content -->

---

## 5. Module Conventions

Source: `specs/modules/<module>/CLAUDE.md`

<!-- placeholder: full module CLAUDE.md content -->

---

## 6. Executor Instruction Block

<!-- placeholder: explicit dual-harness implementation constraints from SKILL.md -->

---

## 6.5. Explicit Negatives

This section reiterates "do NOT" requirements that appeared in §4 (Module Spec) or §5 (Module Conventions) so they get the same emphasis as the constraints block in §6. Spec deviations cluster around requirements that live only in spec body prose — repeat them here.

Required entries every run (kit-wide negatives):

- Do NOT commit. The orchestrator commits after smoke-testing. Record proposed commits in your final report.
- Do NOT `git push` or open PRs.
- Do NOT modify `.git/` directly. Do NOT modify CI config (`.github/`, etc.).
- Do NOT modify `.claude/lib/dispatch.sh` while a dispatcher is running unless the spec specifically requires it (the dispatcher self-relocates to a temp copy, but live edits still confuse downstream tooling).
- Do NOT modify `.claude/hooks/pre-compact.sh` or `.claude/lib/scrub-secrets.sh` unless explicitly in scope.

Spec-derived entries (extracted from §4/§5 of THIS prompt's spec):

<!-- placeholder: bullet list of "no X", "trust Y only", "don't add Z heuristic" requirements lifted verbatim from the spec body. The skill author is responsible for populating this when assembling the prompt; an empty list is acceptable but suspicious. -->

---

## 7. Final Report Schema

Source: `.claude/skills/project-execute/codex-report-schema.json`

Your final agent message MUST be a JSON object conforming to this schema. The dispatcher enforces this via `codex exec --output-schema`. Free-form claims of completion ("X is now done", "ready to ship") will not be accepted in any field — the orchestrator verifies every field against repository ground truth (`git status`, test output, file presence) before committing or summarising to the user.

<!-- placeholder: the schema is loaded from disk by the dispatcher; do NOT inline it here, just reference the path. -->
TEMPLATE_DISPATCH_PROMPT_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-execute/dispatch-prompt-template.md"

# =============================================================================
# LIB: shared dispatcher + secret scrubber (chmod +x)
# =============================================================================

cat > ".claude/lib/dispatch.sh" << 'LIB_DISPATCH_EOF'
#!/usr/bin/env bash
# .claude/lib/dispatch.sh — dual-harness Codex dispatcher
#
# Runs Codex CLI as a child process, tees output to a log under
# .kit-orchestration/, and (when an attached tmux session is reachable)
# splits a viewer pane that runs `tail -f` on the log so the user sees
# the run live in their existing terminal.
#
# Usage: dispatch.sh <phase> <id> <model> <effort> <prompt-file>
#   phase: validate | execute | review | <free-form-tag>
#   id:    stable identifier (PR number, module name, etc.) — kebab-case
#   model: Codex model (e.g. gpt-5.5)
#   effort: low | medium | high | xhigh   (passed via -c model_reasoning_effort=...)
#   prompt-file: path to a file whose contents are streamed to Codex via stdin
#
# Env knobs:
#   KIT_TMUX_SESSION         override which tmux session to split into
#   KIT_TMUX_SPLIT           'h' (default) or 'v'
#   KIT_NO_TMUX=1            force inline streaming (no tmux pane)
#   KIT_CODEX_TIMEOUT        hard timeout in seconds for the main exec (default 1800)
#   KIT_AUTH_PREFLIGHT_SECONDS  preflight timeout (default 15)
#   KIT_ALLOW_CONCURRENT=1   bypass single-flight lock
#   KIT_CODEX_SANDBOX        override sandbox mode (default workspace-write)
#   KIT_PARALLEL_TRACK       module name for per-track locks/logs/pane labels
#   KIT_PARALLEL_PORT        port exported to the executor for this track
#
# Portability: works on Linux and macOS. Requires either `timeout`
# (coreutils, default on Linux) or `gtimeout` (Homebrew coreutils on
# macOS). Lock is mkdir-based, no flock dependency.

set -euo pipefail

# --- self-relocation ---------------------------------------------------------
# Copy this script to a temp path and re-exec from there, so live edits to
# .claude/lib/dispatch.sh during the run (e.g. when Codex modifies the kit
# itself) don't cause bash to re-read garbled offsets at trap time. The
# relocated process owns the cleanup. Idempotent via env-var guard.
#
# REPO_ROOT must be captured BEFORE relocating, because after exec the
# relocated copy can't introspect its origin (BASH_SOURCE will point to /tmp).

if [[ "${KIT_DISPATCH_RELOCATED:-}" != "1" ]]; then
  _kit_origin_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  _kit_self="$(mktemp -t kit-dispatch.XXXXXX)" || { echo "error: mktemp failed" >&2; exit 1; }
  if ! cp -- "${BASH_SOURCE[0]}" "$_kit_self"; then
    rm -f "$_kit_self"
    echo "error: failed to copy dispatch.sh to $_kit_self" >&2
    exit 1
  fi
  chmod +x "$_kit_self"
  export KIT_DISPATCH_RELOCATED=1
  export KIT_DISPATCH_TEMP="$_kit_self"
  export KIT_DISPATCH_REPO_ROOT="$_kit_origin_repo"
  exec bash "$_kit_self" "$@"
fi
trap 'rm -f "${KIT_DISPATCH_TEMP:-}"' EXIT

readonly REPO_ROOT="${KIT_DISPATCH_REPO_ROOT:?KIT_DISPATCH_REPO_ROOT must be set by the relocation block}"
readonly SCRIPT_DIR="$REPO_ROOT/.claude/lib"
readonly KIT_DIR="$REPO_ROOT/.kit-orchestration"
readonly PARALLEL_DIR="$REPO_ROOT/.claude/parallel"

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
warn() { printf '\033[33mwarn:\033[0m %s\n'  "$*" >&2; }
info() { printf '\033[36minfo:\033[0m %s\n'  "$*" >&2; }

# --- portable timeout wrapper ------------------------------------------------

kit_timeout_cmd=""
if command -v timeout >/dev/null 2>&1; then
  kit_timeout_cmd="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  kit_timeout_cmd="gtimeout"
fi

kit_timeout() {
  # Usage: kit_timeout <seconds> <cmd> [args...]
  if [[ -z "$kit_timeout_cmd" ]]; then
    die "neither 'timeout' nor 'gtimeout' on PATH. Install GNU coreutils (Linux: apt/dnf install coreutils; macOS: brew install coreutils)."
  fi
  "$kit_timeout_cmd" "$@"
}

# --- arg parsing -------------------------------------------------------------

(( $# == 5 )) || die "usage: dispatch.sh <phase> <id> <model> <effort> <prompt-file>"
readonly PHASE="$1" ID="$2" MODEL="$3" EFFORT="$4" PROMPT_FILE="$5"

case "$PHASE" in
  validate|execute|review) ;;
  *) [[ "$PHASE" =~ ^[a-z][a-z0-9-]*$ ]] || die "phase must be kebab-case alphanumeric, got: $PHASE" ;;
esac
[[ "$ID" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "id must be kebab-case alphanumeric, got: $ID"
[[ "$EFFORT" =~ ^(low|medium|high|xhigh)$ ]] || die "effort must be low|medium|high|xhigh, got: $EFFORT"
[[ -f "$PROMPT_FILE" ]] || die "prompt file not found: $PROMPT_FILE"

readonly TRACK_ID="${KIT_PARALLEL_TRACK:-}"
if [[ -n "$TRACK_ID" ]]; then
  [[ "$TRACK_ID" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "KIT_PARALLEL_TRACK must be kebab-case alphanumeric, got: $TRACK_ID"
fi

# --- preflight: codex CLI presence + auth + model availability ---------------

command -v codex >/dev/null 2>&1 || die "codex CLI not found on PATH. Install with: npm install -g @openai/codex"

readonly KIT_CODEX_TIMEOUT="${KIT_CODEX_TIMEOUT:-1800}"
readonly KIT_CODEX_SANDBOX="${KIT_CODEX_SANDBOX:-workspace-write}"
readonly KIT_AUTH_PREFLIGHT_SECONDS="${KIT_AUTH_PREFLIGHT_SECONDS:-15}"

# Auth + model preflight. Uses the actual target model so we surface
# "model not available for this auth tier" before opening tmux panes.
auth_check_log="$(mktemp)"
trap 'rm -f "$auth_check_log" "${KIT_DISPATCH_TEMP:-}"' EXIT
if ! kit_timeout "$KIT_AUTH_PREFLIGHT_SECONDS" codex exec \
     -m "$MODEL" \
     --skip-git-repo-check \
     -s read-only \
     -c model_reasoning_effort=low \
     - <<<'echo dispatch.sh auth preflight' >"$auth_check_log" 2>&1; then
  warn "codex preflight failed (model=$MODEL, timeout=${KIT_AUTH_PREFLIGHT_SECONDS}s). Output:"
  sed 's/^/    /' "$auth_check_log" >&2
  die "Auth or model availability error. Try \`codex login\` (ChatGPT auth — required for gpt-5.5 access without API tier) or set OPENAI_API_KEY for a tier that supports model '$MODEL'. Increase KIT_AUTH_PREFLIGHT_SECONDS if the network is slow."
fi

# --- single-flight lock (mkdir-based, portable) ------------------------------

mkdir -p "$KIT_DIR"
if [[ -n "$TRACK_ID" ]]; then
  mkdir -p "$PARALLEL_DIR/locks"
  LOCK_DIR="$PARALLEL_DIR/locks/$TRACK_ID"
else
  LOCK_DIR="$KIT_DIR/.lock"
fi
readonly LOCK_DIR

if [[ -z "${KIT_ALLOW_CONCURRENT:-}" ]]; then
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    die "another dispatch.sh run is in progress (lock dir at $LOCK_DIR). If a previous run died, remove it manually. Set KIT_ALLOW_CONCURRENT=1 to bypass."
  fi
  trap 'rm -rf "$LOCK_DIR"; rm -f "$auth_check_log" "${KIT_DISPATCH_TEMP:-}"' EXIT
elif [[ -n "$TRACK_ID" ]]; then
  info "KIT_ALLOW_CONCURRENT=1 set; using track-scoped lock path $LOCK_DIR without acquiring it"
fi

# --- log path (PID-suffixed to avoid 1s timestamp collisions) ----------------

readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)-$$"
if [[ -n "$TRACK_ID" ]]; then
  readonly TRACK_LOG_DIR="$KIT_DIR/tracks/${TIMESTAMP}-${TRACK_ID}"
  mkdir -p "$TRACK_LOG_DIR"
  readonly LOG_FILE="$TRACK_LOG_DIR/${TIMESTAMP}.log"
  readonly JSONL_FILE="$TRACK_LOG_DIR/${TIMESTAMP}.jsonl"
  readonly LAST_FILE="$TRACK_LOG_DIR/${TIMESTAMP}-last.md"
  readonly REPORT_FILE="$TRACK_LOG_DIR/${TIMESTAMP}-report.json"
  readonly SENTINEL_FILE="$TRACK_LOG_DIR/${TIMESTAMP}-${TRACK_ID}.done"
else
  readonly LOG_FILE="$KIT_DIR/${PHASE}-${ID}-${TIMESTAMP}.log"
  readonly JSONL_FILE="$KIT_DIR/${PHASE}-${ID}-${TIMESTAMP}.jsonl"
  readonly LAST_FILE="$KIT_DIR/${PHASE}-${ID}-${TIMESTAMP}-last.md"
  readonly REPORT_FILE="$KIT_DIR/${PHASE}-${ID}-${TIMESTAMP}-report.json"
  readonly SENTINEL_FILE=""
fi
touch "$LOG_FILE" "$JSONL_FILE"
readonly SCHEMA_FILE="$REPO_ROOT/.claude/skills/project-execute/codex-report-schema.json"
info "log: $LOG_FILE"
info "jsonl: $JSONL_FILE"
[[ -f "$SCHEMA_FILE" ]] && info "schema: $SCHEMA_FILE" || warn "no schema at $SCHEMA_FILE; running without --output-schema"

# --- tmux session resolution -------------------------------------------------

# NOTE: this resolves "the most-recent attached tmux client", which is
# usually the user's current terminal but is not guaranteed when multiple
# clients are attached to different sessions. Use KIT_TMUX_SESSION to pin.

resolve_tmux_session() {
  [[ -n "${KIT_NO_TMUX:-}" ]] && return 1
  command -v tmux >/dev/null 2>&1 || return 1

  if [[ -n "${KIT_TMUX_SESSION:-}" ]]; then
    if tmux has-session -t "$KIT_TMUX_SESSION" 2>/dev/null; then
      printf '%s' "$KIT_TMUX_SESSION"; return 0
    fi
    warn "KIT_TMUX_SESSION=$KIT_TMUX_SESSION set but session does not exist; falling back to detection"
  fi

  local sess
  sess=$(tmux list-clients -F '#{client_activity} #{client_session}' 2>/dev/null \
           | sort -rn | head -1 | awk '{print $2}')
  if [[ -n "$sess" ]]; then
    printf '%s' "$sess"; return 0
  fi

  # Detached sessions are intentionally ignored — we only split where a
  # human is watching. Set KIT_TMUX_SESSION to override.
  return 1
}

TMUX_SESSION=""
if tmux_session=$(resolve_tmux_session); then
  TMUX_SESSION="$tmux_session"
  default_split="h"
  [[ -n "$TRACK_ID" ]] && default_split="v"
  split_flag="-${KIT_TMUX_SPLIT:-$default_split}"
  info "splitting tmux session '$TMUX_SESSION' (override with KIT_TMUX_SESSION=name)"
  # The viewer pipes tail through sed that quits on a dispatcher-only sentinel
  # appended after codex finishes. We use __KIT_DISPATCH_EXIT__= rather than a
  # bare EXIT= so a Codex-generated line that happens to start with "EXIT=" (a
  # script, env example, error-code listing) doesn't close the pane early.
  # When sed exits, tail gets SIGPIPE, the pane shell finishes, and tmux
  # closes the pane automatically (remain-on-exit off by default).
  pane_title="kit-orchestration: $PHASE/$ID"
  [[ -n "$TRACK_ID" ]] && pane_title="[track:$TRACK_ID] $pane_title"
  if ! tmux split-window -t "$TMUX_SESSION" "$split_flag" \
        "echo '── $pane_title ──'; tail -f '$LOG_FILE' | sed -n '/^__KIT_DISPATCH_EXIT__=/{p;q;};p'" >/dev/null 2>&1; then
    msg="tmux split-window failed for session '$TMUX_SESSION'; viewing log inline."
    warn "$msg"
    echo "## dispatch.sh: $msg" >> "$LOG_FILE"
    TMUX_SESSION=""
  fi
fi
if [[ -z "$TMUX_SESSION" ]]; then
  info "no attached tmux client to split into — streaming inline (KIT_NO_TMUX=1 to silence)"
  echo "==== Codex output begins ($PHASE/$ID) ===="
fi
readonly TMUX_SESSION

# --- run codex (prompt via stdin to avoid ARG_MAX) ---------------------------
#
# Codex emits JSONL events on stdout (--json); we tee the raw stream to
# $JSONL_FILE for orchestrator post-run analysis, and pretty-print it
# through a jq formatter into $LOG_FILE for the human-watching tmux pane.
# When jq is missing, the formatter is a passthrough (`cat`), so the pane
# shows raw JSONL — readable, just less polished.
#
# --output-schema (when the schema file exists) forces the final agent
# message to conform to .claude/skills/project-execute/codex-report-schema.json,
# eliminating training-data bleed-through at the structural level.
# --output-last-message writes that final (schema-conformant) message to
# $REPORT_FILE for the orchestrator.

format_jsonl() {
  if ! command -v jq >/dev/null 2>&1; then
    cat
    return
  fi
  jq --unbuffered -R -r '
    . as $raw |
    (try (fromjson) catch null) as $j |
    if $j == null then
      $raw
    elif $j.type == "thread.started" then
      "── thread \($j.thread_id // "?") ──"
    elif $j.type == "session.created" then
      "── session \($j.session_id // "?") ──"
    elif $j.type == "turn.started" then
      "[turn] start"
    elif $j.type == "turn.completed" then
      "[turn] done  in=\($j.usage.input_tokens // "?")  out=\($j.usage.output_tokens // "?")  cached=\($j.usage.cached_input_tokens // "?")"
    elif $j.type == "turn.failed" then
      "[turn] FAILED: \($j.error.message // "?")"
    elif $j.type == "item.started" and $j.item.type == "command_execution" then
      "$ \($j.item.command // "")"
    elif $j.type == "item.completed" and $j.item.type == "command_execution" then
      "  ↳ exit \($j.item.exit_code // "?")  status=\($j.item.status // "?")"
    elif $j.type == "item.completed" and $j.item.type == "file_change" then
      "📝 \($j.item.status // "?")  \($j.item.kind // "")  \($j.item.path // "")"
    elif $j.type == "item.completed" and $j.item.type == "agent_message" then
      "\n--- agent message ---\n\($j.item.text // "")\n---"
    elif $j.type == "item.completed" and $j.item.type == "reasoning" then
      "💭 \(($j.item.text // $j.item.summary // "") | gsub("\n"; " ") | .[0:200])"
    elif $j.type == "item.completed" and $j.item.type == "mcp_tool_call" then
      "[mcp] \($j.item.server // "?")::\($j.item.tool // "?")  status=\($j.item.status // "?")"
    elif $j.type == "item.completed" and $j.item.type == "web_search" then
      "🔎 \($j.item.query // "?")"
    elif $j.type == "item.completed" and $j.item.type == "todo_list" then
      "📋 todos updated"
    elif $j.type == "error" then
      "ERROR: \($j.error.message // $j.message // "?")"
    else
      empty
    end
  ' 2>/dev/null
}

codex_args=(
  -m "$MODEL"
  -c "model_reasoning_effort=$EFFORT"
  -s "$KIT_CODEX_SANDBOX"
  --skip-git-repo-check
  -C "$REPO_ROOT"
  --json
)
# When a schema is present, the final message is JSON conforming to the
# schema and goes to REPORT_FILE. Otherwise the final message is free
# text and goes to LAST_FILE. -o is set exactly once.
if [[ -f "$SCHEMA_FILE" ]]; then
  codex_args+=( --output-schema "$SCHEMA_FILE" -o "$REPORT_FILE" )
else
  codex_args+=( -o "$LAST_FILE" )
fi

set +e
kit_timeout "$KIT_CODEX_TIMEOUT" codex exec "${codex_args[@]}" - <"$PROMPT_FILE" \
  | tee -a "$JSONL_FILE" \
  | format_jsonl \
  | tee -a "$LOG_FILE"
codex_rc=${PIPESTATUS[0]}
set -e

echo "__KIT_DISPATCH_EXIT__=$codex_rc" >> "$LOG_FILE"
if [[ -n "$SENTINEL_FILE" ]]; then
  printf '%s\n' "$codex_rc" > "$SENTINEL_FILE"
fi

if [[ -z "$TMUX_SESSION" ]]; then
  echo "==== Codex output ends (exit $codex_rc) ===="
fi

if (( codex_rc == 124 )); then
  die "codex exec timed out after ${KIT_CODEX_TIMEOUT}s (set KIT_CODEX_TIMEOUT=<seconds> to extend)"
fi

if (( codex_rc != 0 )); then
  die "codex exec failed with exit $codex_rc; see $LOG_FILE (raw events: $JSONL_FILE)"
fi

if [[ -f "$REPORT_FILE" ]]; then
  info "dispatch complete: schema-validated report at $REPORT_FILE"
elif [[ -f "$LAST_FILE" ]]; then
  info "dispatch complete: final message at $LAST_FILE"
else
  warn "dispatch complete but no -o output file was written"
fi
exit 0
LIB_DISPATCH_EOF
chmod +x ".claude/lib/dispatch.sh"

# -----------------------------------------------------------------------------
# .claude/lib/project-tracks.sh — parallel module track helper
# -----------------------------------------------------------------------------

cat > ".claude/lib/project-tracks.sh" << 'LIB_PROJECT_TRACKS_EOF'
#!/usr/bin/env bash
# .claude/lib/project-tracks.sh - parallel module track helper

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARALLEL_DIR="$REPO_ROOT/.claude/parallel"
TRACKS_FILE="$PARALLEL_DIR/tracks.json"
REGISTRY_LOCK="$PARALLEL_DIR/locks/registry"
MODULES_FILE="$REPO_ROOT/specs/MODULES.md"
PORT_BASE="${KIT_PARALLEL_PORT_BASE:-3000}"
PARALLEL_MAX="${KIT_PARALLEL_MAX:-4}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf 'info: %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage:
  project-tracks.sh plan [modules...] [--harness=codex|claude]
  project-tracks.sh start [modules...] [--harness=codex|claude]

The plan command is read-only. The start command creates worktrees and launches
one dispatcher per selected module.
USAGE
}

normalise_module() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-'
}

parse_args() {
  HARNESS="codex"
  MODULE_ARGS=()
  for arg in "$@"; do
    case "$arg" in
      --harness=codex) HARNESS="codex" ;;
      --harness=claude) HARNESS="claude" ;;
      --harness=*) die "unsupported harness: ${arg#--harness=}" ;;
      --help|-h) usage; exit 0 ;;
      *) MODULE_ARGS+=("$(normalise_module "$arg")") ;;
    esac
  done
}

discover_modules() {
  if (( ${#MODULE_ARGS[@]} > 0 )); then
    printf '%s\n' "${MODULE_ARGS[@]}"
    return 0
  fi

  find "$REPO_ROOT/specs/modules" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sed 's#.*/##' \
    | sort
}

yaml_version() {
  awk -F ':' '/^[[:space:]]*version[[:space:]]*:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$1"
}

yaml_shared_paths() {
  awk '
    /^[[:space:]]*shared[[:space:]]*:/ { in_shared=1; next }
    in_shared && /^[^[:space:]-]/ { in_shared=0 }
    in_shared && /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      print
    }
  ' "$1"
}

module_line_number() {
  local module="$1"
  if [[ ! -f "$MODULES_FILE" ]]; then
    printf '999999\n'
    return 0
  fi
  awk -v module="$module" '
    BEGIN { IGNORECASE=1 }
    index($0, module) { print NR; found=1; exit }
    END { if (!found) print 999999 }
  ' "$MODULES_FILE"
}

line_has_dependency_between() {
  local module="$1" other="$2"
  [[ -f "$MODULES_FILE" ]] || return 1
  awk -v a="$module" -v b="$other" '
    BEGIN { IGNORECASE=1; found=0 }
    /depend|require|blocked by|after/ && index($0, a) && index($0, b) { found=1 }
    END { exit found ? 0 : 1 }
  ' "$MODULES_FILE"
}

build_plan() {
  # SPEC §6 mandates "trust parallel.yaml only; no silent heuristics for
  # brownfield". A module without parallel.yaml is refused outright,
  # regardless of repo shape.
  [[ -f "$MODULES_FILE" ]] || die "specs/MODULES.md is absent. Create it first, then add per-module parallel.yaml files before running /project-tracks plan."
  [[ "$PARALLEL_MAX" =~ ^[0-9]+$ ]] || die "KIT_PARALLEL_MAX must be numeric"
  (( PARALLEL_MAX >= 1 )) || die "KIT_PARALLEL_MAX must be at least 1"

  mapfile -t CANDIDATES < <(discover_modules)
  (( ${#CANDIDATES[@]} > 0 )) || die "no modules selected or discovered under specs/modules/"
  (( ${#CANDIDATES[@]} <= PARALLEL_MAX )) || die "selected ${#CANDIDATES[@]} modules; KIT_PARALLEL_MAX is $PARALLEL_MAX"

  PLAN_MODULES=()
  PLAN_SHARED=()
  local module yaml version
  for module in "${CANDIDATES[@]}"; do
    yaml="$REPO_ROOT/specs/modules/$module/parallel.yaml"
    [[ -f "$yaml" ]] || die "$module: add parallel.yaml or run sequentially"
    version="$(yaml_version "$yaml")"
    [[ "$version" == "1" ]] || die "$module: parallel.yaml must declare version: 1"
    PLAN_MODULES+=("$module")
    while IFS= read -r shared_path; do
      [[ -n "$shared_path" ]] && PLAN_SHARED+=("$module:$shared_path")
    done < <(yaml_shared_paths "$yaml")
  done

  local i j a b
  for (( i=0; i<${#PLAN_MODULES[@]}; i++ )); do
    for (( j=i+1; j<${#PLAN_MODULES[@]}; j++ )); do
      a="${PLAN_MODULES[$i]}"
      b="${PLAN_MODULES[$j]}"
      if line_has_dependency_between "$a" "$b" || line_has_dependency_between "$b" "$a"; then
        die "cannot parallelise $a and $b: dependency edge found in specs/MODULES.md"
      fi
    done
  done

  local seen_module seen_path entry module_path other_entry other_module other_path
  for entry in "${PLAN_SHARED[@]}"; do
    seen_module="${entry%%:*}"
    seen_path="${entry#*:}"
    for other_entry in "${PLAN_SHARED[@]}"; do
      other_module="${other_entry%%:*}"
      other_path="${other_entry#*:}"
      [[ "$seen_module" == "$other_module" ]] && continue
      if [[ "$seen_path" == "$other_path" ]]; then
        die "cannot parallelise $seen_module and $other_module: shared path collision on $seen_path"
      fi
    done
  done

  mapfile -t PLAN_MODULES < <(
    for module in "${PLAN_MODULES[@]}"; do
      printf '%06d %s\n' "$(module_line_number "$module")" "$module"
    done | sort -n | awk '{print $2}'
  )
}

print_plan() {
  build_plan
  printf 'Parallel track proposal\n'
  printf 'Harness: %s\n' "$HARNESS"
  printf 'Limit: %s\n' "$PARALLEL_MAX"
  printf 'Merge order:\n'
  local idx=1 module yaml shared
  for module in "${PLAN_MODULES[@]}"; do
    yaml="$REPO_ROOT/specs/modules/$module/parallel.yaml"
    printf '  %d. %s\n' "$idx" "$module"
    printf '     parallel.yaml: %s\n' "${yaml#$REPO_ROOT/}"
    shared="$(yaml_shared_paths "$yaml" | paste -sd ', ' -)"
    [[ -n "$shared" ]] && printf '     shared: %s\n' "$shared"
    idx=$((idx + 1))
  done
}

json_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

with_registry_lock() {
  mkdir -p "$PARALLEL_DIR/locks"
  local waited=0
  until mkdir "$REGISTRY_LOCK" 2>/dev/null; do
    waited=$((waited + 1))
    (( waited <= 30 )) || die "timed out waiting for registry lock at $REGISTRY_LOCK"
    sleep 1
  done
  trap 'rm -rf "$REGISTRY_LOCK"' RETURN
}

ensure_registry() {
  mkdir -p "$PARALLEL_DIR/locks" "$PARALLEL_DIR/learnings"
  if [[ ! -f "$TRACKS_FILE" ]]; then
    printf '{"tracks": [], "merge_order": [], "harness": null}\n' > "$TRACKS_FILE"
  fi
}

append_registry_entry() {
  local module="$1" branch="$2" worktree="$3" harness="$4" port="$5" pid="$6" started="$7"
  ensure_registry
  with_registry_lock

  local id escaped_worktree tmp
  id="track-$module-${started//[^0-9]/}"
  escaped_worktree="$(json_string "${worktree#$REPO_ROOT/}")"
  tmp="$(mktemp)"
  local object
  object="{\"id\":\"$id\",\"module\":\"$module\",\"branch\":\"$branch\",\"worktree\":\"$escaped_worktree\",\"harness\":\"$harness\",\"port\":$port,\"status\":\"running\",\"started\":\"$started\",\"last_commit\":\"\",\"pid\":$pid}"

  if command -v jq >/dev/null 2>&1; then
    jq --argjson track "$object" --arg module "$module" --arg harness "$harness" '
      .tracks += [$track]
      | .merge_order += [$module]
      | .harness = (.harness // $harness)
    ' "$TRACKS_FILE" > "$tmp"
  else
    awk -v object="$object" -v module="$module" -v harness="$harness" '
      {
        line=$0
        if (line ~ /"tracks"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/) {
          sub(/"tracks"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/, "\"tracks\": [" object "]", line)
        } else {
          sub(/"tracks"[[:space:]]*:[[:space:]]*\[/, "\"tracks\": [" object ",", line)
        }
        if (line ~ /"merge_order"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/) {
          sub(/"merge_order"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/, "\"merge_order\": [\"" module "\"]", line)
        } else {
          sub(/"merge_order"[[:space:]]*:[[:space:]]*\[/, "\"merge_order\": [\"" module "\",", line)
        }
        sub(/"harness"[[:space:]]*:[[:space:]]*null/, "\"harness\": \"" harness "\"", line)
        print line
      }
    ' "$TRACKS_FILE" > "$tmp"
  fi
  mv "$tmp" "$TRACKS_FILE"
}

copy_worktree_includes() {
  local worktree="$1" include_file="$REPO_ROOT/.worktreeinclude" entry
  [[ -f "$include_file" ]] || return 0
  while IFS= read -r entry; do
    [[ -z "$entry" || "$entry" == \#* ]] && continue
    if [[ -e "$REPO_ROOT/$entry" ]]; then
      mkdir -p "$worktree/$(dirname "$entry")"
      cp -R "$REPO_ROOT/$entry" "$worktree/$entry"
    fi
  done < "$include_file"
}

write_track_prompt() {
  local module="$1" prompt_file="$2"
  cat > "$prompt_file" <<EOF
# Parallel track dispatch: $module

Implement only the $module module in this isolated worktree.

Read:
- specs/modules/$module/SPEC.md
- specs/modules/$module/CLAUDE.md
- CLAUDE.md

Respect parallel track constraints:
- Do not edit root LEARNINGS.md directly; leave track learnings as a fragment.
- Use PORT and KIT_PARALLEL_PORT for any dev server.
- Stay within the module scope and its declared parallel.yaml paths.
EOF
}

start_tracks() {
  build_plan
  ensure_registry
  mkdir -p "$REPO_ROOT/.claude/worktrees" "$REPO_ROOT/.kit-orchestration/tracks"

  local idx=1 module branch worktree port started prompt_dir prompt_file pid
  for module in "${PLAN_MODULES[@]}"; do
    branch="track/$module"
    worktree="$REPO_ROOT/.claude/worktrees/track-$module"
    port=$((PORT_BASE + idx))
    started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    if [[ ! -d "$worktree/.git" && ! -f "$worktree/.git" ]]; then
      if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$worktree" "$branch"
      else
        git worktree add "$worktree" -b "$branch"
      fi
    else
      info "$module: reusing existing worktree $worktree"
    fi

    copy_worktree_includes "$worktree"

    prompt_dir="$REPO_ROOT/.kit-orchestration/tracks/$(date +%Y%m%d-%H%M%S)-$module"
    mkdir -p "$prompt_dir"
    prompt_file="$prompt_dir/dispatch-prompt.md"
    write_track_prompt "$module" "$prompt_file"

    case "$HARNESS" in
      codex)
        (
          cd "$worktree"
          KIT_ALLOW_CONCURRENT=1 \
          KIT_PARALLEL_TRACK="$module" \
          KIT_PARALLEL_PORT="$port" \
          PORT="$port" \
          bash "$worktree/.claude/lib/dispatch.sh" execute "$module" gpt-5.5 medium "$prompt_file"
        ) > "$prompt_dir/launcher.log" 2>&1 &
        pid=$!
        ;;
      claude)
        command -v claude >/dev/null 2>&1 || die "claude CLI not found on PATH"
        (
          cd "$worktree"
          KIT_PARALLEL_TRACK="$module" KIT_PARALLEL_PORT="$port" PORT="$port" \
          claude -w "track-$module" < "$prompt_file"
        ) > "$prompt_dir/launcher.log" 2>&1 &
        pid=$!
        ;;
      *) die "unsupported harness: $HARNESS" ;;
    esac

    append_registry_entry "$module" "$branch" "$worktree" "$HARNESS" "$port" "$pid" "$started"
    printf 'started %s on %s (port %s, pid %s)\n' "$module" "$branch" "$port" "$pid"
    idx=$((idx + 1))
  done
}

main() {
  (( $# >= 1 )) || { usage; exit 1; }
  local command="$1"
  shift
  parse_args "$@"

  case "$command" in
    plan) print_plan ;;
    start) start_tracks ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"
LIB_PROJECT_TRACKS_EOF
chmod +x ".claude/lib/project-tracks.sh"
echo -e "  ${GREEN}✓${RESET} .claude/lib/project-tracks.sh"
echo -e "  ${GREEN}✓${RESET} .claude/lib/dispatch.sh"

cat > ".claude/lib/scrub-secrets.sh" << 'LIB_SCRUB_EOF'
#!/usr/bin/env bash
# .claude/lib/scrub-secrets.sh — read-path secret redactor
#
# Reads stdin (or a file path arg), redacts common credential shapes,
# writes to stdout. Used by Claude when reading dispatch logs back into
# context, so secrets that Codex may have echoed don't get re-injected.
#
# Patterns covered (deliberately conservative — false positives ok,
# false negatives bad):
#   - Anthropic / OpenAI keys: sk-ant-..., sk-proj-..., sk-...
#   - GitHub PATs: ghp_..., gho_..., ghs_..., ghu_..., github_pat_...
#   - Slack tokens: xoxb-, xoxa-, xoxp-, xoxs-, xapp-
#   - Stripe secret keys: sk_live_..., rk_live_...
#   - JWTs: eyJ<base64>.<base64>.<base64>
#   - Bearer tokens: Bearer <opaque>
#   - Authorization: <opaque> headers (without Bearer scheme)
#   - Basic auth in URLs: https://user:password@...
#   - AWS access keys: AKIA[0-9A-Z]{16}
#
# Patterns deliberately NOT covered:
#   - Generic 32+ hex strings (would redact git SHAs, file hashes, etc.)
#   - Any heuristic for high-entropy short strings (false positive risk too high)
#
# Usage:
#   cat log | scrub-secrets.sh              # stdin → stdout
#   scrub-secrets.sh path/to/log            # file → stdout

set -euo pipefail

input() {
  if (( $# == 0 )); then cat
  else cat "$1"
  fi
}

input "$@" | sed -E '
  s/sk-ant-[A-Za-z0-9_-]{20,}/sk-ant-REDACTED/g
  s/sk-proj-[A-Za-z0-9_-]{20,}/sk-proj-REDACTED/g
  s/sk-[A-Za-z0-9_-]{32,}/sk-REDACTED/g
  s/sk_live_[A-Za-z0-9]{20,}/sk_live_REDACTED/g
  s/rk_live_[A-Za-z0-9]{20,}/rk_live_REDACTED/g
  s/ghp_[A-Za-z0-9]{30,}/ghp_REDACTED/g
  s/gho_[A-Za-z0-9]{30,}/gho_REDACTED/g
  s/ghs_[A-Za-z0-9]{30,}/ghs_REDACTED/g
  s/ghu_[A-Za-z0-9]{30,}/ghu_REDACTED/g
  s/github_pat_[A-Za-z0-9_]{40,}/github_pat_REDACTED/g
  s/xox[abprs]-[A-Za-z0-9-]{10,}/xox-REDACTED/g
  s/xapp-[0-9]+-[A-Za-z0-9-]{10,}/xapp-REDACTED/g
  s/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/eyJ.REDACTED.REDACTED/g
  s/(Bearer[[:space:]]+)[A-Za-z0-9._~+/=-]{20,}/\1REDACTED/g
  s/([Aa]uthorization:[[:space:]]+)([A-Za-z][A-Za-z0-9_-]*[[:space:]]+)?[A-Za-z0-9._~+/=-]{20,}/\1\2REDACTED/g
  s|(https?://)[^:/[:space:]]+:[^@[:space:]]+@|\1REDACTED:REDACTED@|g
  s/\bAKIA[0-9A-Z]{16}\b/AKIAREDACTED/g
'
LIB_SCRUB_EOF
chmod +x ".claude/lib/scrub-secrets.sh"
echo -e "  ${GREEN}✓${RESET} .claude/lib/scrub-secrets.sh"

cat > ".claude/hooks/pre-compact.sh" << 'HOOK_PRECOMPACT_EOF'
#!/usr/bin/env bash
# .claude/hooks/pre-compact.sh — PreCompact snapshot
#
# Fires before Claude Code compacts the conversation. Reads the hook input
# JSON from stdin (Claude Code provides session_id, transcript_path, trigger,
# custom_instructions, and others) and writes three companion snapshot files
# into specs/sessions/ so context is recoverable post-compaction.
#
# Exit semantics: returns 0 in the happy path. With `set -e` plus `|| true`
# guards, only filesystem errors (e.g. specs/sessions/ unwritable) can produce
# a non-zero exit, which Claude Code surfaces but does NOT block compaction
# on (the hook does not return decision: "block").
#
# Documented limitation: Claude Code issue #13572 reports PreCompact may not
# fire reliably for /compact on some versions. The SessionStart `compact`
# matcher in .claude/settings.json provides a backup recovery path that prints
# the latest snapshot path on session resume.

set -euo pipefail
umask 077

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly OUT_DIR="$REPO_ROOT/specs/sessions"
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR" 2>/dev/null || true

readonly TS="$(date +%Y%m%d-%H%M%S)-$$"
written=()

# Read hook input JSON from stdin (best-effort — Claude Code may pipe nothing
# in some configurations). Use jq if available; fall back to cat.
hook_input="$(cat)"

extract() {
  # extract <jq-path> — empty string if jq missing or key absent
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$hook_input" | jq -r "$key // empty" 2>/dev/null || true
  fi
}

session_id="$(extract '.session_id')"
transcript_path="$(extract '.transcript_path')"
trigger="$(extract '.trigger')"
custom_instructions="$(extract '.custom_instructions')"

# Snapshot 1: plan file (if any plan was active)
if compgen -G "$REPO_ROOT/.kit-orchestration/pr*-plan.md" >/dev/null 2>&1; then
  latest_plan="$(ls -1t "$REPO_ROOT/.kit-orchestration/"pr*-plan.md 2>/dev/null | head -1)"
  if [[ -n "$latest_plan" ]]; then
    {
      echo "# PreCompact snapshot — plan ($TS)"
      echo
      echo "Latest plan: $latest_plan"
      echo "Session: ${session_id:-unknown}"
      echo "Trigger: ${trigger:-unknown}"
      echo
      echo "---"
      cat "$latest_plan"
    } > "$OUT_DIR/$TS-plan.md"
    chmod 600 "$OUT_DIR/$TS-plan.md" 2>/dev/null || true
    written+=("$OUT_DIR/$TS-plan.md")
  fi
fi

# Snapshot 2: transcript tail (last 50 lines)
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  {
    echo "# PreCompact snapshot — transcript tail ($TS)"
    echo
    echo "Source: $transcript_path"
    echo "Session: ${session_id:-unknown}"
    echo "Trigger: ${trigger:-unknown}"
    [[ -n "$custom_instructions" ]] && { echo "Custom instructions: $custom_instructions"; }
    echo
    echo "---"
    tail -n 50 "$transcript_path"
  } > "$OUT_DIR/$TS-transcript-tail.md"
  chmod 600 "$OUT_DIR/$TS-transcript-tail.md" 2>/dev/null || true
  written+=("$OUT_DIR/$TS-transcript-tail.md")
fi

# Snapshot 3: git activity
{
  echo "# PreCompact snapshot — git ($TS)"
  echo
  echo "Branch: $(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)"
  echo
  echo "## Recent commits"
  echo
  git -C "$REPO_ROOT" log --oneline -10 2>/dev/null || true
  echo
  echo "## Working-tree status"
  echo
  git -C "$REPO_ROOT" status --short 2>/dev/null || true
} > "$OUT_DIR/$TS-git.md"
chmod 600 "$OUT_DIR/$TS-git.md" 2>/dev/null || true
written+=("$OUT_DIR/$TS-git.md")

if (( ${#written[@]} == 0 )); then
  printf 'pre-compact.sh: no snapshots written\n' >&2
else
  printf 'pre-compact.sh: snapshots written:\n' >&2
  printf '  %s\n' "${written[@]}" >&2
fi
exit 0
HOOK_PRECOMPACT_EOF
chmod +x ".claude/hooks/pre-compact.sh"
echo -e "  ${GREEN}✓${RESET} .claude/hooks/pre-compact.sh"

cat > ".claude/settings.json" << 'SETTINGS_JSON_EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-compact.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "cd \"$CLAUDE_PROJECT_DIR\" && if compgen -G 'specs/sessions/*-plan.md' >/dev/null 2>&1; then echo \"Session resumed after compaction. Latest snapshot: $(ls -1t specs/sessions/*-plan.md 2>/dev/null | head -1)\"; else echo 'Session resumed after compaction. No prior snapshot found in specs/sessions/.'; fi"
          }
        ]
      }
    ]
  }
}
SETTINGS_JSON_EOF
echo -e "  ${GREEN}✓${RESET} .claude/settings.json"

cat > ".claude/skills/project-security-review/SKILL.md" << 'SKILL_SECURITY_EOF'
---
name: project-security-review
description: Independent security review of pending changes via an isolated Agent context — fresh subagent reads the diff and a security checklist with no implementation bias. Use after a module is implemented and before merge, especially for changes that touch auth, data persistence, PII, audit logging, or anything UK GDPR-sensitive. Triggers on '/project-security-review', 'security review', 'audit this branch'.
effort: high
---

# project-security-review

Runs a security review of pending changes in **fresh Agent context** so the reviewer has no exposure to the implementation reasoning that produced the code. This isolation is the entire point — a reviewer who watched the code being written tends to share its blind spots.

## Process

1. **Capture the diff** (use `mktemp` + cleanup trap so the temp file doesn't leak):

   ```bash
   diff_file="$(mktemp -t security-review-diff.XXXXXX)"
   trap 'rm -f "$diff_file"' EXIT
   if git rev-parse --verify origin/main >/dev/null 2>&1; then
     base="$(git merge-base origin/main HEAD)"
   elif git rev-parse --verify main >/dev/null 2>&1; then
     base="$(git merge-base main HEAD)"
   else
     base="HEAD~1"
   fi
   git diff "$base"..HEAD > "$diff_file"
   ```

2. **Identify the security checklist**: read `.claude/skills/project-security-review/security-review-prompt.md`. This is the canonical instruction set the Agent will follow.

3. **Launch the Agent** with a read-only subagent type so the reviewer can't accidentally modify the working tree:

   ```text
   Agent(
     subagent_type="Explore",
     description="Security review (isolated read-only context)",
     prompt=<contents of security-review-prompt.md, with $diff_file content and any relevant CLAUDE.md security section interpolated into the prompt body>
   )
   ```

   The Explore agent runs with a fresh context window AND no edit/write tools — it has not seen planning or implementation discussion, and it cannot modify code. Its findings reflect the diff alone plus the security checklist.

4. **Receive the Agent's report** and surface it to the user without modification. Add a one-paragraph framing explaining what was reviewed and any user-actionable next steps.

5. **Optional follow-ups**:
   - If the Agent found CRITICAL or HIGH issues, suggest the user address them before merge.
   - Note that this skill does NOT modify code — it produces a report only.

## When to use

- Before merging any PR that touches auth, session management, or token handling.
- After implementing data persistence for PII or healthcare-sensitive data (UK GDPR considerations).
- When the change touches audit logging, access control, or rate limiting.
- When you want a "second set of eyes" with no contextual bias.

## Why isolation matters

A reviewer who participated in implementation tends to validate the assumptions that drove the implementation. An Agent in fresh context only sees the diff — its blind spots are different from the implementer's, which is exactly what a security review needs.
SKILL_SECURITY_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-security-review/SKILL.md"

cat > ".claude/skills/project-security-review/security-review-prompt.md" << 'PROMPT_SECURITY_EOF'
# Security review — instructions for the spawned Agent

You are a security reviewer with no prior context on this codebase. The diff below represents pending changes to a project. Review them rigorously against the checklist that follows. Do not assume the implementer's intent was correct.

## Required output format

```markdown
# Security review

**Files reviewed**: <count> | **Lines added/removed**: <+N/-M> | **Branch**: <name>

## Findings by severity

### CRITICAL (security vulnerability — must fix before merge)
- [file:line — issue — recommendation]

### HIGH (likely bug or major risk)

### MEDIUM (concern worth addressing)

### LOW (style / minor)

## Areas that look clean

- [bullet list of areas you reviewed and found acceptable]

## Recommendation

APPROVE / REQUEST CHANGES / COMMENT — with one-sentence rationale.
```

## Review checklist

For every changed file, walk through:

### Authentication & session
- Are credentials read from environment variables only, never hard-coded?
- Are session tokens stored securely (httpOnly cookies, not localStorage)?
- Is logout invalidating the token server-side, not just client-side?
- Are password resets rate-limited?

### Authorisation
- Is every protected endpoint checking `auth.getCurrentUser()` (or equivalent) before reading/writing data?
- Are user IDs scoped to the requesting user (no `userId` parameter that lets one user act as another)?
- Are admin endpoints separately gated?

### Input validation
- Is every user-supplied input validated (Zod, Pydantic, or equivalent) before being used in queries, file paths, or shell commands?
- Are SQL queries parameterised (no string interpolation of user input)?
- Are path traversal vectors closed (no `../` traversal in file operations)?
- Are JSON parsers given size limits?

### Output handling
- Are user-supplied strings escaped before insertion into HTML (XSS prevention)?
- Are error messages sanitised before being returned to the user (no stack traces, no internal paths)?
- Are PII fields redacted from logs?

### State-changing requests
- Do state-changing endpoints (POST/PUT/PATCH/DELETE) require a CSRF token, SameSite=Strict cookie, or other origin-binding mechanism?
- Are mutating operations idempotent where reasonable (so retries don't double-charge or duplicate records)?

### External fetches and redirects
- Are server-side fetches (image proxies, URL previewers, webhooks) protected against SSRF? (Block `127.*`, `169.254.169.254`, `10.*`, `192.168.*`, etc.)
- Are open-redirect parameters validated against an allowlist of permitted destinations?

### Webhook handling
- Are inbound webhooks verifying signatures (Stripe `Stripe-Signature`, GitHub `X-Hub-Signature-256`, etc.) before any side effect?
- Are webhook timestamps checked against replay (window <5 min)?

### File uploads
- Is uploaded file MIME type validated server-side (not just from client header)?
- Are file size limits enforced before reading the body into memory?
- Are uploaded files served from a separate origin (or with `Content-Disposition: attachment` and a sandboxed Content-Type) to prevent stored XSS?
- Is the storage path randomised (no user-supplied filename in the served URL)?

### Client-side secret hygiene
- Are secrets ever embedded in the client bundle (e.g. via `process.env.SECRET` in client code, or hard-coded in JSX)?
- Are runtime config endpoints scoped to non-secret values only?

### Data persistence (UK GDPR considerations)
- Is PII (names, emails, addresses, phone numbers, health data) only persisted when there's a documented lawful basis?
- Is sensitive data encrypted at rest?
- Are deletions actually deletions (not soft-deletes that retain personal data indefinitely)?
- Is data residency considered (EU/UK data not silently flowing to non-adequate jurisdictions)?

### Audit logging
- Are security-relevant events logged (login, logout, permission change, data export, deletion)?
- Are logs append-only and tamper-evident?
- Are PII redaction rules applied to logs?

### Healthcare-domain compliance (where applicable)
- If the project touches NHS or other healthcare data: is access strictly role-based?
- Are clinical records versioned (no destructive edits)?
- Is consent recorded with timestamp and auditable trail?

### Dependencies
- Are new dependencies from reputable sources?
- Do they have known CVEs (suggest the user run `npm audit` / `pip-audit` / equivalent)?
- Are versions pinned (no `^` or `~` in production deps for security-critical packages)?

### Operational hygiene
- Are debug flags off in production code paths?
- Are CORS origins restricted (no `*` in production)?
- Are rate limits in place on public endpoints?

## How to ground your findings

For each finding, cite the file path and line number from the diff. Quote the relevant code. Explain why it's a concern in one sentence. Recommend a concrete fix.

If you are uncertain whether something is a problem, mark it MEDIUM with a note of what would change your assessment.

If a category is not applicable to this diff (e.g. no auth code touched), say so explicitly under "Areas that look clean" rather than skipping it.

## Diff to review

<the actual git diff is appended here at runtime>

## Project-specific security context (if present)

<the relevant section of CLAUDE.md is appended here at runtime>
PROMPT_SECURITY_EOF
echo -e "  ${GREEN}✓${RESET} .claude/skills/project-security-review/security-review-prompt.md"

touch specs/sessions/.gitkeep
echo -e "  ${GREEN}✓${RESET} specs/sessions/.gitkeep"

if [ ! -f "specs/sessions/.gitignore" ]; then
  cat > "specs/sessions/.gitignore" << 'SESSIONS_GITIGNORE_EOF'
# Snapshots written by .claude/hooks/pre-compact.sh
# Treat as ephemeral runtime artefacts — do not commit.
*
!.gitignore
!.gitkeep
SESSIONS_GITIGNORE_EOF
  echo -e "  ${GREEN}✓${RESET} specs/sessions/.gitignore"
fi

# =============================================================================
# COMMANDS (thin wrappers that invoke skills)
# =============================================================================

cat > ".claude/commands/project-init.md" << 'CMD_INIT_EOF'
Read and follow the skill at `.claude/skills/project-init/SKILL.md`.

**Project Idea:** $ARGUMENTS
CMD_INIT_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-init.md"

cat > ".claude/commands/project-research.md" << 'CMD_RESEARCH_EOF'
Read and follow the skill at `.claude/skills/project-research/SKILL.md`.

**Research Topic:** $ARGUMENTS
CMD_RESEARCH_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-research.md"

cat > ".claude/commands/project-blueprint.md" << 'CMD_BLUEPRINT_EOF'
Read and follow the skill at `.claude/skills/project-blueprint/SKILL.md`.
CMD_BLUEPRINT_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-blueprint.md"

cat > ".claude/commands/project-spec.md" << 'CMD_SPEC_EOF'
Read and follow the skill at `.claude/skills/project-spec/SKILL.md`.

**Module:** $ARGUMENTS
CMD_SPEC_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-spec.md"

cat > ".claude/commands/project-module.md" << 'CMD_MODULE_EOF'
Read and follow the skill at `.claude/skills/project-module/SKILL.md`.

**Module:** $ARGUMENTS
CMD_MODULE_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-module.md"

cat > ".claude/commands/project-review.md" << 'CMD_REVIEW_EOF'
Read and follow the skill at `.claude/skills/project-review/SKILL.md`.
CMD_REVIEW_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-review.md"

cat > ".claude/commands/project-status.md" << 'CMD_STATUS_EOF'
Read and follow the skill at `.claude/skills/project-status/SKILL.md`.
CMD_STATUS_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-status.md"

cat > ".claude/commands/project-deploy.md" << 'CMD_DEPLOY_EOF'
Read and follow the skill at `.claude/skills/project-deploy/SKILL.md`.
CMD_DEPLOY_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-deploy.md"

cat > ".claude/commands/project-test.md" << 'CMD_TEST_EOF'
Read and follow the skill at `.claude/skills/project-test/SKILL.md`.
CMD_TEST_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-test.md"

cat > ".claude/commands/project-execute.md" << 'CMD_EXECUTE_EOF'
Read and follow the skill at `.claude/skills/project-execute/SKILL.md`.
CMD_EXECUTE_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-execute.md"

cat > ".claude/commands/project-tracks.md" << 'CMD_TRACKS_EOF'
Read and follow the skill at `.claude/skills/project-tracks/SKILL.md`.
CMD_TRACKS_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-tracks.md"

cat > ".claude/commands/project-security-review.md" << 'CMD_SECURITY_EOF'
Read and follow the skill at `.claude/skills/project-security-review/SKILL.md`.
CMD_SECURITY_EOF
echo -e "  ${GREEN}✓${RESET} .claude/commands/project-security-review.md"

# =============================================================================
# .kit-orchestration scaffolding (idempotent — preserves existing user content)
# =============================================================================
if [ ! -f ".kit-orchestration/.gitignore" ]; then
  cat > ".kit-orchestration/.gitignore" << 'KIT_GITIGNORE_EOF'
*.log
*-snapshot.md
.lock
KIT_GITIGNORE_EOF
  echo -e "  ${GREEN}✓${RESET} .kit-orchestration/.gitignore"
fi

# =============================================================================
# .gitignore
# =============================================================================
if [ -f ".gitignore" ]; then
  if ! grep -q "AI Project Kit" .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# AI Project Kit" >> .gitignore
    echo ".env" >> .gitignore
    echo ".env.local" >> .gitignore
  fi
else
  cat > .gitignore << 'GITIGNORE_EOF'
# AI Project Kit
.env
.env.local
.env*.local
GITIGNORE_EOF
fi

echo -e "  ${GREEN}✓${RESET} .gitignore updated"

# =============================================================================
# .claude/README.md
# =============================================================================
cat > .claude/README.md << 'CLAUDE_README_EOF'
# AI Project Kit

This directory powers spec-first, AI-assisted development for this project.

## What's Here

```
.claude/
  commands/              Slash commands — type these in Claude Code
    project-init.md      /project-init [idea]
    project-research.md  /project-research [topic]
    project-blueprint.md /project-blueprint
    project-spec.md      /project-spec [module]
    project-module.md    /project-module [name]
    project-execute.md   /project-execute [module]
    project-tracks.md    /project-tracks plan|start|status|review|merge|cleanup
    project-review.md    /project-review
    project-security-review.md    /project-security-review
    project-status.md    /project-status
    project-deploy.md    /project-deploy
    project-test.md      /project-test
  skills/                Skill implementations + bundled templates
    project-init/
      SKILL.md
      blueprint-template.md
      module-spec-template.md
      claude-module-template.md
    project-research/
      SKILL.md
    project-blueprint/
      SKILL.md
    project-spec/
      SKILL.md
    project-module/
      SKILL.md
    project-review/
      SKILL.md
    project-status/
      SKILL.md
    project-deploy/
      SKILL.md
    project-test/
      SKILL.md
  README.md              This file

specs/                   Generated spec documents (committed to git)
  RESEARCH.md           Domain research
  MASTER_BLUEPRINT.md   Architecture source of truth
  ROADMAP.md            Implementation order
  modules/              Per-module specs
    [module]/
      SPEC.md
      CLAUDE.md

CLAUDE.md               Root operating model (read by Claude Code automatically)
LEARNINGS.md            Accumulated project learnings
```

## Quickstart

1. Open Claude Code in this project directory
2. Type: `/project-init [your project idea]`
3. Follow the workflow — research → blueprint → specs → implement

## Adding a Module Mid-Project

```
/project-spec [module-name]    # Creates the spec
/project-module [module-name]  # Begins implementation
```

## After Each Session

```
/project-review    # Captures learnings, updates CLAUDE.md
```

## Commands Reference

| Command | Purpose |
|---------|---------|
| `/project-init [idea]` | Start a new project with full research + blueprint + specs + roadmap |
| `/project-research [topic]` | Deep research on domain, technology, regulation, or competitor |
| `/project-blueprint` | Generate or regenerate master architecture document |
| `/project-spec [module]` | Create or update a module-level specification |
| `/project-module [name]` | Implement a specific module end-to-end |
| `/project-review` | End-of-session: capture learnings, update CLAUDE.md |
| `/project-status` | Show project dashboard — what specs exist, what's built, what's next |
| `/project-deploy` | Deploy to production and verify deployment |
| `/project-test` | Run comprehensive tests — unit, type, lint, visual |
| `/project-execute [name]` | Dual-harness: Claude plans/reviews, Codex CLI implements in tmux |
| `/project-tracks plan\|start\|...` | Parallel module implementation across isolated git worktrees |
| `/project-security-review` | Independent security review of pending changes |
CLAUDE_README_EOF

echo -e "  ${GREEN}✓${RESET} .claude/README.md"

# =============================================================================
# Brownfield-specific additions
# =============================================================================
if [ "$PROJECT_MODE" = "brownfield" ]; then
  mkdir -p specs/existing-system

  cat > specs/existing-system/AUDIT.md << 'AUDIT_EOF'
# Existing System Audit

Complete this before running `/project-init` or `/project-blueprint`.
Understanding what exists prevents AI from reinventing or breaking things.

---

## Tech Stack (Existing)

| Layer | Technology | Version | Notes |
|-------|-----------|---------|-------|
| | | | |

---

## Current Module Structure

What modules/features exist today?

| Module | Location | Status | Notes |
|--------|----------|--------|-------|
| | | Working / Broken / Partial | |

---

## What Works Well

Don't let AI change these without strong reason.

- {{WORKING_THING_1}}

---

## Known Problems / Technical Debt

Areas where AI assistance would be most valuable.

- {{PROBLEM_1}}

---

## Constraints

Things the AI must not change (e.g. external integrations, locked APIs, legacy compatibility requirements).

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

- **Audit first.** Read `specs/existing-system/AUDIT.md` before proposing any changes. Understand what exists before adding to it.
- **Match existing patterns.** Do not introduce new patterns that conflict with the established codebase conventions — even if the new pattern is better. Consistency beats perfection.
- **Test coverage before refactoring.** If an area lacks tests, add tests before changing behaviour. Never refactor untested code.
- **Spec the existing system.** When adding a feature to an existing module, write a spec delta (what's being ADDED/MODIFIED) rather than a full spec.
- **Flag conflicts.** If the spec you've been given contradicts the existing code, flag it immediately. Do not silently resolve the conflict.
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
echo "  CLAUDE.md                                    ← Read by Claude Code automatically"
echo "  LEARNINGS.md                                 ← Updated each session"
echo "  .claude/commands/project-init.md             → /project-init [idea]"
echo "  .claude/commands/project-research.md         → /project-research [topic]"
echo "  .claude/commands/project-blueprint.md        → /project-blueprint"
echo "  .claude/commands/project-spec.md             → /project-spec [module]"
echo "  .claude/commands/project-module.md           → /project-module [name]"
echo "  .claude/commands/project-execute.md          → /project-execute [module]"
echo "  .claude/commands/project-tracks.md           → /project-tracks plan|start|…"
echo "  .claude/commands/project-review.md           → /project-review"
echo "  .claude/commands/project-security-review.md  → /project-security-review"
echo "  .claude/commands/project-status.md           → /project-status"
echo "  .claude/commands/project-deploy.md           → /project-deploy"
echo "  .claude/commands/project-test.md             → /project-test"
echo "  .claude/skills/                              ← Skill logic + bundled templates"
echo "  specs/                                       ← Your spec documents live here"
if [ "$PROJECT_MODE" = "brownfield" ]; then
  echo "  specs/existing-system/AUDIT.md              ← Fill this in before starting"
fi
echo ""
echo -e "${BOLD}Next step:${RESET}"
if [ "$PROJECT_MODE" = "brownfield" ]; then
  echo -e "  1. Fill in ${YELLOW}specs/existing-system/AUDIT.md${RESET} (understand what exists)"
  echo -e "  2. Open Claude Code and type: ${CYAN}/project-status${RESET}"
else
  echo -e "  Open Claude Code and type: ${CYAN}/project-init \"your project idea here\"${RESET}"
  echo ""
  echo -e "  Example: ${CYAN}/project-init \"CRM solution for the UK education market\"${RESET}"
fi
echo ""

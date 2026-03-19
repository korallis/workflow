# AI Project Kit — Enhancement Plan

## Critical Bug: Command Names Are Broken

### The Problem

The bootstrap script creates commands at `.claude/commands/init.md`, `.claude/commands/status.md`, etc. The README and all documentation claim these become `/project:init`, `/project:status`, etc.

**They don't.** In Claude Code:

- `.claude/commands/init.md` → becomes `/init`
- `.claude/commands/status.md` → becomes `/status`
- `.claude/commands/review.md` → becomes `/review`

Claude Code does NOT support colon-namespaced commands via subdirectories. Subdirectory structure is ignored for command naming. Colons are not valid characters in command names at all (only lowercase letters, numbers, and hyphens).

### Built-In Commands Being Shadowed

Three of the seven commands directly overwrite Claude Code built-ins:

| Kit File | Actual Command | Shadows Built-In |
|----------|---------------|------------------|
| `commands/init.md` | `/init` | `/init` — Creates CLAUDE.md files |
| `commands/status.md` | `/status` | `/status` — Opens Settings UI |
| `commands/review.md` | `/review` | `/review` — Code review plugin |

Users who install this kit silently lose access to three built-in features with no warning.

### The Fix

Rename all commands to use hyphenated `project-` prefix. Two options for file format:

**Option A — Keep as commands (simpler):**
```
.claude/commands/
  project-init.md       → /project-init
  project-research.md   → /project-research
  project-blueprint.md  → /project-blueprint
  project-spec.md       → /project-spec
  project-module.md     → /project-module
  project-review.md     → /project-review
  project-status.md     → /project-status
```

**Option B — Convert to skills (recommended, more capable):**
```
.claude/skills/
  project-init/
    SKILL.md            → /project-init
    research-prompt.md  ← supporting file with research methodology
  project-research/
    SKILL.md            → /project-research
  project-blueprint/
    SKILL.md            → /project-blueprint
  project-spec/
    SKILL.md            → /project-spec
    template.md         ← MODULE_SPEC template as supporting file
  project-module/
    SKILL.md            → /project-module
  project-review/
    SKILL.md            → /project-review
  project-status/
    SKILL.md            → /project-status
```

**Why Option B is better:** Skills support subdirectories with supporting files (templates, examples, reference material). The current `templates/` directory approach is fragile — the commands reference templates by path and hope Claude finds them. With skills, each command bundles its own supporting files.

---

## Enhancement 1: Wire Research to Real Search Tools

### Current State

The `/project:research` command says "Use web search to find current, accurate information" — but doesn't reference any specific tool. Claude may or may not use web search. The `/project:init` command's Phase 2 (Domain Research) has the same problem.

### Enhanced Approach

The research command should explicitly instruct Claude to use the tools that are actually available:

**Primary research tools to reference:**
- **Exa Web Search** (`web_search_exa`) — Best for market research, competitor analysis, current landscape. Supports category filtering (`company`, `research paper`, `people`).
- **Exa Code Context** (`get_code_context_exa`) — Best for finding code examples, library documentation, API usage patterns. Searches GitHub, Stack Overflow, and official docs.
- **Ref Documentation Search** (`ref_search_documentation`) — Best for framework/library documentation lookup. Use when researching specific technical approaches.
- **Ref URL Reader** (`ref_read_url`) — Read full content from documentation URLs found via search.
- **WebSearch** (built-in) — General web search fallback.
- **WebFetch** (built-in) — Fetch and analyze specific URLs.

**Updated research methodology in the command:**

```markdown
## Research Methodology

Use the following tools in this order of preference:

1. **Market & Domain Research:**
   - Use `web_search_exa` with `category: "company"` to find competitors
   - Use `web_search_exa` with `category: "research paper"` for academic/industry research
   - Use `web_search_exa` for general market landscape queries

2. **Technical Research (frameworks, libraries, APIs):**
   - Use `ref_search_documentation` to find official documentation
   - Use `ref_read_url` to read documentation pages in full
   - Use `get_code_context_exa` for code examples and implementation patterns
   - Specify the programming language and framework in queries

3. **Regulatory & Compliance Research:**
   - Use `web_search_exa` for regulations (GDPR, HIPAA, etc.)
   - Cross-reference multiple sources for accuracy

4. **Source Tracking:**
   - Record every URL consulted in a Sources section
   - Note which tool was used for each finding
   - Flag conflicting information between sources
```

---

## Enhancement 2: Frontend Planning Should Use the web-artifacts-builder Skill

### Current State

The `/project:module` command tells Claude to implement frontend components but gives no guidance on frontend tooling, component libraries, or design systems. It doesn't reference any design skill or frontend best practices.

### Enhanced Approach

When a module involves frontend/UI work, the command should instruct Claude to:

1. **Consult the `web-artifacts-builder` skill** for React/Tailwind/shadcn component patterns
2. **Use the `theme-factory` skill** when theming or styling is involved
3. **Reference the `canvas-design` skill** for any visual/graphic elements

Add a frontend-specific section to the `/project-module` command:

```markdown
## Frontend Implementation Guidelines

If this module includes UI screens or components:

1. **Before writing frontend code**, read the web-artifacts-builder skill
   for React, Tailwind CSS, and shadcn/ui patterns and constraints.

2. **Component architecture:** Follow the patterns established in
   MASTER_BLUEPRINT.md for component structure, state management,
   and data fetching. If no patterns exist yet, establish them in this
   module and document them.

3. **Design system:** If using shadcn/ui or a similar component library,
   reference the theme-factory skill for consistent theming.

4. **Prototyping:** For complex UI flows, create a standalone HTML/React
   prototype first to validate the interaction design before integrating
   into the main codebase.
```

---

## Enhancement 3: Testing Should Use Chrome/Playwright

### Current State

The `/project:module` command says "Run the test suite" but doesn't mention visual testing, E2E testing, or browser-based verification. For a web application kit, this is a significant gap.

### Enhanced Approach

Add browser-based testing instructions:

```markdown
## Testing Strategy

### Unit Tests
Run unit tests after each logical chunk of implementation.
Command: `[TEST COMMAND — set after stack detection]`

### Visual Verification (for UI modules)
After implementing UI screens, use browser automation to verify:

1. **Use Playwright** (`browser_navigate`, `browser_snapshot`) to:
   - Navigate to each new route/page
   - Take accessibility snapshots to verify element structure
   - Take screenshots for visual verification
   - Test interactive elements (forms, buttons, navigation)

2. **Use Chrome** (if Playwright unavailable) for the same verification.

3. **Capture evidence:** Take a screenshot of each completed screen and
   note any visual issues in the review.

### E2E Testing (after multiple modules are complete)
For integration points between modules, write E2E tests using
Playwright that verify the full user flow across module boundaries.
```

---

## Enhancement 4: Blueprint Should Leverage Documentation Tools

### Current State

The `/project:blueprint` command asks Claude to define the tech stack but doesn't tell it to actually look up current best practices, latest versions, or official documentation for the chosen technologies.

### Enhanced Approach

```markdown
## Stack Research (before finalising the blueprint)

After the user confirms their stack preferences, verify each choice:

1. **For each major dependency**, use `ref_search_documentation` to:
   - Confirm the latest stable version
   - Check for any breaking changes or deprecations
   - Find the official getting-started guide

2. **For architectural patterns**, use `get_code_context_exa` to:
   - Find production examples of the chosen pattern
   - Verify the pattern works with the chosen framework version
   - Identify common pitfalls documented by the community

3. **Record findings** in the blueprint under each stack decision's
   "Rationale" column, including version numbers and source URLs.
```

---

## Enhancement 5: Add a `/project-deploy` Command

### Current State

No deployment command exists. The kit covers spec → implement → review but stops before deployment.

### Enhanced Approach

Add a new `/project-deploy` command that leverages the Vercel integration:

```markdown
## Purpose
Deploy the current project state to a preview or production environment.

## Steps

1. **Pre-deploy checks:**
   - Run full test suite
   - Check for uncommitted changes (warn if any)
   - Verify environment variables are configured

2. **Deploy to Vercel** (if Vercel is the deployment target):
   - Use the Vercel MCP tools to deploy
   - Monitor build logs for errors
   - If build fails, read logs and diagnose the issue

3. **Post-deploy verification:**
   - Use browser automation (Playwright/Chrome) to visit the deployed URL
   - Take screenshots of key pages
   - Verify core functionality works in the deployed environment

4. **Update status:**
   - Note deployment URL in LEARNINGS.md
   - Update module status if this was a release milestone
```

---

## Enhancement 6: Add a `/project-test` Command

### Current State

Testing is embedded within `/project-module` as a step. There's no standalone command to run a comprehensive test pass across the whole project.

### Enhanced Approach

```markdown
## Purpose
Run a comprehensive test pass across the project — unit, integration,
and visual/E2E.

## Steps

1. **Unit tests:** Run the project's test suite
2. **Type checking:** Run the type checker (tsc, mypy, etc.)
3. **Lint:** Run the linter
4. **Visual tests** (if UI modules exist):
   - Start the dev server
   - Use Playwright to navigate to each implemented route
   - Take accessibility snapshots
   - Take screenshots
   - Report any console errors
5. **Integration tests** (if multiple modules are complete):
   - Test cross-module data flows
   - Verify API endpoints return expected data
6. **Report:** Summarise pass/fail status for each category
```

---

## Enhancement 7: Improve the Init Command's Research Phase

### Current State

The `/project:init` Phase 2 (Domain Research) is generic. It tells Claude to "research" but doesn't give it a structured approach using available tools.

### Enhanced Approach

Replace Phase 2 with a tool-aware research workflow:

```markdown
## Phase 2 — Domain Research (Tool-Assisted)

Use the following structured approach:

### 2a. Competitor Analysis
- Use `web_search_exa` with `category: "company"` for each identified competitor
- For each competitor, capture: name, URL, key features, pricing model, target market
- Use `web_search_exa` for "[competitor] reviews" to find user pain points

### 2b. Technical Landscape
- Use `ref_search_documentation` for the primary framework/language
- Use `get_code_context_exa` for "[framework] [pattern] example" queries
- Document recommended patterns with source URLs

### 2c. Regulatory Requirements
- Use `web_search_exa` for "[industry] [region] regulations software"
- Cross-reference at least 2 sources for each requirement
- Flag requirements that affect the data model or architecture

### 2d. User Research
- Use `web_search_exa` for "[market] user pain points" and "[market] workflows"
- Use `web_search_exa` with `category: "people"` to find domain experts/thought leaders
- Document common user workflows that the product should support
```

---

## Enhancement 8: CLAUDE.md Should Reference Available MCP Tools

### Current State

The root CLAUDE.md tells Claude about slash commands and workflow rules, but never mentions the MCP tools available in the environment. Claude has to discover them on its own.

### Enhanced Approach

Add a "Available Tools" section to CLAUDE.md:

```markdown
## Available Tools & Integrations

When working on this project, use these tools proactively:

### Research & Documentation
- **Exa Search** — web search with category filters (company, research paper, people)
- **Exa Code Context** — find code examples from GitHub, Stack Overflow, docs
- **Ref Documentation** — search and read framework/library documentation
- Use these instead of guessing about APIs, patterns, or best practices

### Testing & Verification
- **Playwright** — browser automation for E2E testing and visual verification
- **Chrome Automation** — alternative browser control for testing
- Always visually verify UI work in a real browser

### Deployment
- **Vercel** — deploy previews and production builds
- Check build logs when deployments fail

### Rule: Research Before Implementing
Before implementing any technical pattern you're uncertain about,
use Ref or Exa to look up the current documentation. Don't rely
on potentially outdated training knowledge for version-specific
API details.
```

---

## Enhancement 9: Convert Templates to Skill Supporting Files

### Current State

Templates live in `.claude/templates/` and are referenced by file path from the commands. This is brittle — Claude has to read a separate directory and might not find them.

### Enhanced Approach

With the skills format, each skill bundles its own templates:

```
.claude/skills/
  project-spec/
    SKILL.md              ← The command itself
    module-spec-template.md   ← Template, directly accessible
    claude-module-template.md ← Template, directly accessible
  project-blueprint/
    SKILL.md
    blueprint-template.md
```

In the SKILL.md, reference templates with:
```markdown
Use the template in `./module-spec-template.md` (relative to this skill)
as the structure for the module spec.
```

This is self-contained — no external path dependencies.

---

## Enhancement 10: Add YAML Frontmatter to All Commands

### Current State

The commands are plain markdown with no frontmatter. They can't specify descriptions, argument hints, or other metadata that Claude Code skills support.

### Enhanced Approach

Every skill should have proper frontmatter:

```yaml
---
description: "Initialise a new project with full spec-first workflow"
---
```

This makes commands discoverable when users type `/` in Claude Code — they'll see descriptions alongside command names.

---

## Summary: Implementation Priority

| Priority | Enhancement | Effort | Impact |
|----------|-------------|--------|--------|
| **P0** | Fix command naming (bug) | S | Critical — currently broken |
| **P0** | Convert to skills format | M | Enables all other enhancements |
| **P1** | Wire research to Exa/Ref tools | S | Major quality improvement |
| **P1** | Add MCP tools to CLAUDE.md | S | Guides Claude to use available tools |
| **P1** | Add frontmatter to all commands | S | Discoverability |
| **P2** | Frontend skill integration | S | Better frontend code quality |
| **P2** | Browser testing integration | M | Catches visual bugs |
| **P2** | Improve init research phase | M | Better project foundations |
| **P3** | Add `/project-deploy` command | M | Completes the workflow |
| **P3** | Add `/project-test` command | M | Standalone test capability |
| **P3** | Bundle templates into skills | S | Cleaner architecture |

### File Changes Summary

**Delete:**
- `.claude/commands/init.md`
- `.claude/commands/research.md`
- `.claude/commands/blueprint.md`
- `.claude/commands/spec.md`
- `.claude/commands/module.md`
- `.claude/commands/review.md`
- `.claude/commands/status.md`
- `.claude/templates/` (contents move into skills)

**Create:**
- `.claude/skills/project-init/SKILL.md`
- `.claude/skills/project-research/SKILL.md`
- `.claude/skills/project-blueprint/SKILL.md` + `blueprint-template.md`
- `.claude/skills/project-spec/SKILL.md` + `module-spec-template.md` + `claude-module-template.md`
- `.claude/skills/project-module/SKILL.md`
- `.claude/skills/project-review/SKILL.md`
- `.claude/skills/project-status/SKILL.md`
- `.claude/skills/project-deploy/SKILL.md` (new)
- `.claude/skills/project-test/SKILL.md` (new)

**Update:**
- `CLAUDE.md` — fix command references, add tools section
- `README.md` — fix command references throughout
- `bootstrap.sh` — rewrite to use skills format, fix all naming

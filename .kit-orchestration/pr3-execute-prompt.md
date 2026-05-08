# Execute PR3 — apply hooks, security-review subagent, effort metadata

You are the executor in a dual-harness orchestration. The planner (Claude Opus 4.7) produced a plan, the validator (Codex GPT-5.5 high) returned 2 REJECTs + 8 MINORs + 5 additions, and the planner reconciled all 15 findings into the current `.kit-orchestration/pr3-plan.md`. Materialise the changes exactly as specified.

## Hard rules (must obey)

1. Edit only files explicitly named in the plan. Do not refactor neighbours.
2. Do NOT push, do NOT commit (the reviewer commits).
3. Do NOT modify `.git/`, `.github/`, or any CI files.
4. Do NOT modify `.kit-orchestration/*` files except creating new `pr3-execute-*-last.md` if dispatched separately (you are not).
5. British English in user-facing prose.
6. Stop and ask if any plan instruction is ambiguous.

## Required reading (in order)

1. `.kit-orchestration/pr3-plan.md` — the **reconciled** plan. The "Reconciliation summary (validator round 1)" at the end records every change vs the first pass. Each `## ... (revised after validator)` heading marks an updated section.
2. `.kit-orchestration/pr3-validation.md` — validator's report (already addressed, read for context).
3. `bootstrap.sh` — to confirm the validator-verified line refs (top dir block 37-50, project-init heredoc starts 389, project-blueprint 2090, project-review 2826, lib heredocs 3889 and 4083, COMMANDS section 4143).

## Tasks (apply in this order)

### 1. Create the hook script

- `mkdir -p .claude/hooks`
- Create `.claude/hooks/pre-compact.sh` with the exact bash from the plan's "## `pre-compact.sh` — full source spec (revised after validator)" code block. Copy verbatim. `chmod +x .claude/hooks/pre-compact.sh`.
- `bash -n .claude/hooks/pre-compact.sh` — must pass.

### 2. Create the settings.json

- Create `.claude/settings.json` with the exact JSON from the plan's "## `.claude/settings.json` — full content (revised after validator)" block. Both hook commands MUST use `$CLAUDE_PROJECT_DIR`.
- Validate with `python3 -c "import json,sys;json.load(open('.claude/settings.json'))"` (or `jq . .claude/settings.json` if jq is on PATH).

### 3. Create the security-review skill

- `mkdir -p .claude/skills/project-security-review`
- Create `.claude/skills/project-security-review/SKILL.md` with the content from the plan's revised section. Pay particular attention to the diff-capture step (uses `mktemp` + `trap`, fallback chain origin/main → main → HEAD~1) and the `subagent_type="Explore"` for the Agent call.
- Create `.claude/skills/project-security-review/security-review-prompt.md` with the full revised content (includes the new CSRF, SSRF, webhook, file-upload, client-secret sections).
- Create `.claude/commands/project-security-review.md` with the single line: `Read and follow the skill at \`.claude/skills/project-security-review/SKILL.md\`.`

### 4. Create the snapshot directory marker

- `mkdir -p specs/sessions`
- Create `specs/sessions/.gitkeep` as an empty file.

### 5. Add `effort: high` frontmatter

Edit two existing skills, inserting `effort: high` immediately after the `description:` line in their YAML frontmatter:

- `.claude/skills/project-init/SKILL.md` — add `effort: high` line after the `description:` line.
- `.claude/skills/project-blueprint/SKILL.md` — same.

Do NOT modify any other skills.

### 6. Add `--isolate` section to project-review skill

Edit `.claude/skills/project-review/SKILL.md`. Insert the **revised** `## Optional isolated code-review pass (--isolate)` section from the plan IMMEDIATELY BEFORE the existing `## Process` section. Use the exact wording from the plan — note this is the **additive** semantics (Agent does code-review only; learnings/CLAUDE.md updates still happen in parent session).

### 7. Update `bootstrap.sh`

Insertion plan, using the validator-confirmed line refs:

7a. **Top dir block (lines 37-50)**: add `mkdir -p .claude/hooks`, `mkdir -p .claude/skills/project-security-review`, `mkdir -p specs/sessions` alongside the existing mkdir lines.

7b. **After the `LIB_SCRUB_EOF` heredoc closes (~line 4127), before the COMMANDS section (line 4143)**: insert in this order:
- heredoc → `.claude/hooks/pre-compact.sh` (terminator `HOOK_PRECOMPACT_EOF`) + `chmod +x ".claude/hooks/pre-compact.sh"` + green-check echo
- heredoc → `.claude/settings.json` (terminator `SETTINGS_JSON_EOF`) + green-check echo
- heredoc → `.claude/skills/project-security-review/SKILL.md` (terminator `SKILL_SECURITY_EOF`) + green-check echo
- heredoc → `.claude/skills/project-security-review/security-review-prompt.md` (terminator `PROMPT_SECURITY_EOF`) + green-check echo
- `touch specs/sessions/.gitkeep` + green-check echo (no heredoc needed for empty file)

7c. **Inside the COMMANDS section (after the `project-execute.md` heredoc)**: insert heredoc → `.claude/commands/project-security-review.md` (terminator `CMD_SECURITY_EOF`) + green-check echo.

7d. **Update the embedded `project-init/SKILL.md` heredoc at line 389**: insert `effort: high` line after the existing `description:` line (still inside the `---` frontmatter). Do not touch the body.

7e. **Update the embedded `project-blueprint/SKILL.md` heredoc at line 2090**: same.

7f. **Update the embedded `project-review/SKILL.md` heredoc at line 2826**: insert the revised `## Optional isolated code-review pass (--isolate)` section IMMEDIATELY BEFORE the existing `## Process` section. Use the exact wording from the plan.

7g. **Update the embedded `CLAUDE.md` heredoc** (find via `grep -n 'cat > "CLAUDE.md"' bootstrap.sh`): add `/project-security-review` rows to BOTH the trigger table and the Available Slash Commands table. Add a brief Hooks sub-section to the Available Tools & Integrations area.

### 8. Update root CLAUDE.md and README.md (live files)

Mirror the bootstrap.sh CLAUDE.md heredoc updates into the live `CLAUDE.md` (root):
- Trigger table: add `/project-security-review` row.
- Available Slash Commands table: add `/project-security-review` row.
- Brief Hooks sub-section under Available Tools & Integrations.

Update root `README.md`:
- "The Slash Commands" section: add a `/project-security-review` sub-section after `/project-execute`.
- Quick Reference table: add `/project-security-review` row; note `--isolate` flag on `/project-review`.
- New "Hooks" section after "Tool Integrations": describe PreCompact snapshot pattern, SessionStart compact backup, the #13572 caveat, and that hooks live in `.claude/hooks/` configured via `.claude/settings.json`.
- New "Skill Frontmatter" sub-section: `effort: high|medium|low|max` is Claude-Code-specific; silently ignored by other harnesses.

### 9. Verify

After all edits, run:

```bash
bash -n bootstrap.sh
bash -n .claude/hooks/pre-compact.sh
test -x .claude/hooks/pre-compact.sh
python3 -c "import json,sys;json.load(open('.claude/settings.json'))"
test -f .claude/skills/project-security-review/SKILL.md
test -f .claude/skills/project-security-review/security-review-prompt.md
test -f .claude/commands/project-security-review.md
test -f specs/sessions/.gitkeep
grep -c 'effort: high' .claude/skills/project-{init,blueprint,execute,security-review}/SKILL.md   # expect 4 lines, each :1
grep -q 'Optional isolated code-review pass' .claude/skills/project-review/SKILL.md
grep -q '/project-security-review' CLAUDE.md
grep -q 'Hooks' README.md
```

If anything fails: STOP and report.

## Final report

Write to stdout:

```text
## Files created
- <list with paths and line counts>

## Files modified
- <list with paths and lines added/removed>

## Verification
- bash -n bootstrap.sh: <code>
- bash -n .claude/hooks/pre-compact.sh: <code>
- json valid for settings.json: <yes/no>
- All grep checks: <pass/fail>

## Ambiguities encountered
- <none, or list>
```

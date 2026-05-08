# Execute PR1 — apply P0 bug fixes

You are the executor in a dual-harness orchestration. A planner (Claude Opus 4.7) produced a change plan, a validator (you, but on a previous high-effort run) critiqued it, and the planner reconciled the findings. Your job now is to **apply the changes exactly as specified** in the reconciled plan.

## Hard rules (must obey)

1. **Make edits ONLY to the files listed below.** Do not modify any other file. Do not refactor surrounding code.
2. **Do NOT modify these files**: anything under `.kit-orchestration/`, `.git/`, `LEARNINGS.md`, any file not explicitly listed in the plan.
3. **Do NOT run `git add`, `git commit`, `git push`, or any git mutation** other than `git mv ENHANCEMENT_PLAN.md CHANGELOG.md` (the planner explicitly authorises this single git operation for the rename).
4. **Do NOT modify CI configuration**, `.github/`, or any GitHub-related files.
5. **Do NOT install dependencies, run tests, or run linters.** Just apply edits.
6. **Stop and ask** if any plan instruction is ambiguous — do not improvise. Surface the ambiguity in your final report.
7. **British English** in any prose you write into user-facing files.

## Required reading (read in order, then act)

1. `.kit-orchestration/pr1-plan.md` — the full reconciled plan (sections "Reconciliation with validator findings", "Files modified in PR1 (reconciled)", and "Commits (reconciled atomic sequence)" are the operative spec).
2. `.kit-orchestration/pr1-validation.md` — validator findings already addressed in the plan.
3. `.kit-orchestration/pr1-audit.md` — discrepancies between the original brief and repo reality (already accounted for, but read for context).
4. `ENHANCEMENT_PLAN.md` — the file being renamed to `CHANGELOG.md`. You'll synthesise its 13 sections into past-tense `### Added` bullets for the `0.1.0` release.

## Tasks (execute in this order)

### 1. Bug #4 — orphan `/project-fix-tests` reference
- Edit `.claude/skills/project-test/SKILL.md`: delete the line `  /project-fix-tests       (auto-fix suggestions)` (currently around line 310). Do not replace it with anything; the line below (`/project-deploy`) becomes the new top of the NEXT STEPS list.
- Edit `bootstrap.sh`: same deletion at line 4381 (inside the `SKILL_TEST_EOF` heredoc). Be careful — bootstrap.sh has many heredocs; ensure the surrounding text in the heredoc is unchanged.

### 2. Bug #5 — template consolidation (also resolves #2 and #3)

**Live files:**
- Delete: `.claude/skills/project-spec/module-spec-template.md`
- Delete: `.claude/skills/project-spec/claude-module-template.md`
- Edit `.claude/skills/project-spec/SKILL.md`: change the references at approx lines 40, 41, and 95 from local paths to `../project-init/...`:
  - Old: `` - `./module-spec-template.md` — The standard MODULE_SPEC template with all required sections ``
  - New: `` - `../project-init/module-spec-template.md` — The standard MODULE_SPEC template with all required sections ``
  - Old: `` - `./claude-module-template.md` — The implementation guide template for module-specific conventions and patterns ``
  - New: `` - `../project-init/claude-module-template.md` — The implementation guide template for module-specific conventions and patterns ``
  - And the line near 95: `**Templates**: See \`module-spec-template.md\` and \`claude-module-template.md\` for the structure and examples.`
  - New: `**Templates**: See \`../project-init/module-spec-template.md\` and \`../project-init/claude-module-template.md\` for the structure and examples.`

**Bootstrap.sh** (within the `SKILL_SPEC_EOF` heredoc at lines 2471-2568):
- Line 2511: change `- \`./module-spec-template.md\` — The standard MODULE_SPEC template with all required sections` to `- \`../project-init/module-spec-template.md\` — The standard MODULE_SPEC template with all required sections`.
- Line 2512: change `- \`./claude-module-template.md\` — The implementation guide template for module-specific conventions and patterns` to `- \`../project-init/claude-module-template.md\` — The implementation guide template for module-specific conventions and patterns`.
- Line ~2566: change the `**Templates**: See ...` line similarly to use `../project-init/` paths.

**Bootstrap.sh** (delete heredocs):
- DELETE lines 2570-2845 inclusive (the `cat > ".claude/skills/project-spec/module-spec-template.md" << 'TEMPLATE_SPEC2_EOF'` line through its closing `TEMPLATE_SPEC2_EOF` line and the `echo -e "  ${GREEN}✓${RESET} .claude/skills/project-spec/module-spec-template.md"` confirmation).
- DELETE lines 2847-3242 inclusive (the `cat > ".claude/skills/project-spec/claude-module-template.md" << 'TEMPLATE_CLAUDE2_EOF'` line through its closing `TEMPLATE_CLAUDE2_EOF` line and its echo confirmation).
- DELETE the blank line at 2846 between the two heredocs.
- Net deletion: original lines 2570-3242 inclusive (673 lines), plus the embedded text edits above.
- DO NOT delete `mkdir -p ".claude/skills/project-spec"` — `project-spec/SKILL.md` still needs the directory.

After deletions, verify with `bash -n bootstrap.sh` that the script still parses cleanly (do NOT execute it, just syntax-check).

### 3. Bug #6 + structure tree — README updates
- `README.md:39`: replace `https://your-repo/bootstrap.sh` with `https://raw.githubusercontent.com/korallis/workflow/main/bootstrap.sh`.
- `README.md:84-87`: in the directory tree, currently:
  ```text
  │       ├── project-spec/
  │       │   ├── SKILL.md
  │       │   ├── module-spec-template.md
  │       │   └── claude-module-template.md
  ```
  Change to:
  ```text
  │       ├── project-spec/
  │       │   └── SKILL.md
  ```
  Adjust the box-drawing prefix on the SKILL.md line from `├──` to `└──` since it's now the only child.

### 4. Bug #7 — CHANGELOG.md rename and rewrite
- Run: `git mv ENHANCEMENT_PLAN.md CHANGELOG.md` (this is the ONE git operation you may run).
- Then COMPLETELY rewrite the contents of `CHANGELOG.md` (overwriting whatever git mv preserved) with this structure:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-19

### Added
- <list of past-tense entries summarising the 13 sections from the original ENHANCEMENT_PLAN.md, one bullet per section, focused on what was DELIVERED in commit 0cb37af>
```

Each `### Added` bullet should be one line, past tense, third person, focused on the user-visible change. Examples of the right voice:
- `Renamed all command files to use the \`project-\` prefix to avoid shadowing Claude Code built-ins (\`/init\`, \`/status\`, \`/review\`).`
- `Converted commands to skills format under \`.claude/skills/\` so each skill can bundle supporting templates.`
- `Wired \`/project-research\` to use Exa search and Ref documentation lookup explicitly rather than relying on implicit web search.`

Cover all 13 sections from the original ENHANCEMENT_PLAN.md (Critical Bug fix + Enhancements 1-10 + Implementation Priority summary). Keep each bullet tight (one sentence). British English spelling throughout.

## Final report

After applying all edits, write a brief markdown report to stdout with:

```text
## Changes applied
- <list of every file you modified, with line counts changed>

## Deletions
- <list of every file deleted>

## Renames
- <ENHANCEMENT_PLAN.md → CHANGELOG.md>

## Ambiguities encountered
- <none, or list with location>

## Verification
- bash -n bootstrap.sh exit code: <0 or non-zero with detail>
```

Do not run other verification commands; that's the reviewer's job.

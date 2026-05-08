# Execute PR2 — implement `/project-execute` dual-harness skill

You are the executor in a dual-harness orchestration. The planner (Claude Opus 4.7) produced a plan, the validator (Codex GPT-5.5 high) returned 19 findings, and the planner reconciled all of them into the current `.kit-orchestration/pr2-plan.md`. Your job is to materialise the changes exactly as specified.

## Hard rules (must obey)

1. **Edit only the files explicitly listed in the plan.** Do not refactor adjacent code.
2. **Do NOT push, do NOT merge, do NOT modify any file under `.github/` or CI configuration.**
3. **Do NOT manually edit `.git/`** (no config changes, no hook changes, no ref edits). Normal `git add` / `git commit` are allowed but not required of you — the reviewer (Claude) will commit.
4. **Do NOT modify any `.kit-orchestration/*` file** (except creating new `pr2-execute-*-last.md` if dispatched separately, which you are not).
5. **Use British English** in any user-facing prose you write into `CLAUDE.md`, `README.md`, or `SKILL.md`.
6. **Stop and ask** if any plan instruction is ambiguous — do not improvise.

## Required reading

Before applying changes, read in order:
1. `.kit-orchestration/pr2-plan.md` — the **reconciled** plan. The "Reconciliation summary (validator round 1)" section at the end records every change vs the first pass. The dispatch.sh and scrub-secrets.sh source under "## `dispatch.sh` — full source spec (revised after validator)" and "## `scrub-secrets.sh` — full source spec (revised after validator)" are the canonical spec — copy verbatim.
2. `.kit-orchestration/pr2-validation.md` — the validator's full report (already addressed by the plan, but read for context).
3. `bootstrap.sh` — to confirm the line ranges the plan cites (project-test heredoc 3399-3719, COMMANDS section 3726-3777, top dir block 37-47, existing CLAUDE.md and README.md heredocs).
4. `CLAUDE.md` (root) — to know where to insert the new "Dual-Harness Workflow" section (after the existing "Workflow" section).
5. `README.md` — to know where to insert "Dual-Harness Mode" (after "How It Works").

## Tasks (apply in this order)

### 1. Create `.claude/lib/` and the two shell scripts

- `mkdir -p .claude/lib` (just the directory; do NOT create empty placeholders).
- Create `.claude/lib/dispatch.sh` with the **exact** bash code from the plan's "## `dispatch.sh` — full source spec (revised after validator)" code block. Copy verbatim including comments. Set executable: `chmod +x .claude/lib/dispatch.sh`.
- Create `.claude/lib/scrub-secrets.sh` with the **exact** bash code from the plan's scrub-secrets.sh source block. `chmod +x .claude/lib/scrub-secrets.sh`.
- After both files exist, run `bash -n .claude/lib/dispatch.sh` and `bash -n .claude/lib/scrub-secrets.sh` to confirm they parse. If either fails: STOP and report the line numbers — do not improvise a fix.

### 2. Create the project-execute skill files

- `mkdir -p .claude/skills/project-execute`
- Create `.claude/skills/project-execute/SKILL.md` with the content from the plan's "## `.claude/skills/project-execute/SKILL.md` — content spec (revised after validator)" — start from the `---` frontmatter line, end before the next `##` heading. Use the prose verbatim.
- Create `.claude/skills/project-execute/dispatch-prompt-template.md`. The plan only describes this in summary; you should write a ~40-line template that documents the assembly order (header, root CLAUDE.md, MASTER_BLUEPRINT.md, module SPEC.md, module CLAUDE.md, instruction block) with `<!-- placeholder -->` markers between sections. Reference it from SKILL.md.
- Create `.claude/commands/project-execute.md` with the single-line content: `Read and follow the skill at \`.claude/skills/project-execute/SKILL.md\`.` (matches the existing command-wrapper pattern in this repo).

### 3. Update `CLAUDE.md` (root)

- In the trigger table, add a new row for `/project-execute [module]` with the description from the plan.
- After the existing "Workflow" section, add a new section titled "Dual-Harness Workflow" with the prose from the plan's "## `CLAUDE.md` updates (revised after validator)" code block. Use British English. Match the surrounding heading style.

### 4. Update `README.md`

- After the existing "How It Works" section, add a new section "Dual-Harness Mode" with the prose from the plan's "## `README.md` updates (revised after validator)" code block.
- The structure tree under "How It Works" does NOT need updating in this PR (no top-level structure changes, just new files under `.claude/lib/` which can be added to the tree if you prefer; if you do, also add `project-execute/` under `.claude/skills/`).

### 5. Update `bootstrap.sh`

Insert in this order, respecting existing grouping (per the plan's bootstrap.sh updates section):

1. **Top dir block (lines 37-47)**: add `mkdir -p ".claude/lib"` and `mkdir -p ".claude/skills/project-execute"`. The `.kit-orchestration/` directory creation is already implicit; add `mkdir -p ".kit-orchestration"` here too if not already there.
2. **After the `project-test/SKILL.md` heredoc (currently ends around line 3719) and before the COMMANDS section (line 3726)**: insert these heredocs in order, each followed by the `echo -e "  ${GREEN}✓${RESET} <path>"` confirmation that matches the existing style:
   - heredoc → `.claude/lib/dispatch.sh` (then `chmod +x ".claude/lib/dispatch.sh"` and the echo)
   - heredoc → `.claude/lib/scrub-secrets.sh` (then `chmod +x ".claude/lib/scrub-secrets.sh"` and the echo)
   - heredoc → `.claude/skills/project-execute/SKILL.md`
   - heredoc → `.claude/skills/project-execute/dispatch-prompt-template.md`
   - **`.kit-orchestration/.gitignore` idempotent write**: `[ -f ".kit-orchestration/.gitignore" ] || cat > ".kit-orchestration/.gitignore" <<'KIT_GITIGNORE_EOF' ... KIT_GITIGNORE_EOF` — only writes if missing. Content: the same `*.log\n*-snapshot.md\n.lock` from PR1.
3. **Inside the existing COMMANDS section (lines 3726-3777)**: add the heredoc → `.claude/commands/project-execute.md` alongside the other command wrappers.
4. **Inside the existing `cat > "CLAUDE.md" << 'CLAUDE_MD_EOF'` heredoc** (find it via grep): extend the trigger table with the new row, and insert the "Dual-Harness Workflow" section after the existing "Workflow" section.
5. **Inside the existing `cat > "README.md" << 'README_EOF'` heredoc**: insert the "Dual-Harness Mode" section after "How It Works".

Use unique heredoc terminators that match the existing kit pattern (`SKILL_EXECUTE_EOF`, `LIB_DISPATCH_EOF`, `LIB_SCRUB_EOF`, `TEMPLATE_DISPATCH_PROMPT_EOF`, `KIT_GITIGNORE_EOF`, `CMD_EXECUTE_EOF`).

### 6. Verify

After all edits:

```bash
bash -n bootstrap.sh                              # syntax
bash -n .claude/lib/dispatch.sh                   # syntax
bash -n .claude/lib/scrub-secrets.sh              # syntax
test -x .claude/lib/dispatch.sh && echo OK
test -x .claude/lib/scrub-secrets.sh && echo OK
ls .claude/skills/project-execute/                # SKILL.md, dispatch-prompt-template.md
ls .claude/commands/project-execute.md            # exists
grep -q '/project-execute' CLAUDE.md && echo OK
grep -q 'Dual-Harness Workflow' CLAUDE.md && echo OK
grep -q 'Dual-Harness Mode' README.md && echo OK
```

If any check fails: STOP and report.

## Final report

Write a brief markdown report to stdout with:

```text
## Files created
- <list with absolute paths and line counts>

## Files modified
- <list with paths and lines added/removed>

## Verification
- bash -n bootstrap.sh: <exit code>
- bash -n .claude/lib/dispatch.sh: <exit code>
- bash -n .claude/lib/scrub-secrets.sh: <exit code>
- All grep checks: <pass/fail summary>

## Ambiguities encountered
- <none, or list>
```

Do not run other tests; that's the reviewer's job.

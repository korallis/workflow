# Plan validation request — PR1 (P0 bug fixes)

You are a senior code reviewer acting as a plan validator in a dual-harness orchestration. Your job is to critique the change plan below for **correctness, completeness, and risk** before it is executed by a separate Codex instance. You have access to the working directory at `/home/leeb/workflow` (a clone of `korallis/workflow` on branch `fix/p0-bugs`). Inspect any file you wish to verify claims.

## Constraints

- Do NOT write any code or apply any changes. Read-only review.
- Do NOT modify CI, do not push, do not commit.
- Make no changes outside this prompt's read-only inspection.
- If anything in the plan is ambiguous, list it under **Issues Found** rather than guessing.

## Required output format

Return a single markdown report with exactly these sections, in this order:

```
## Confirmed Correct
- [bullet list of plan items you verified are accurate against the actual repo]

## Issues Found
- [bullet list of incorrect file paths, missing steps, broken logic, contradictions, or risks the plan introduces]
- For each issue: which plan section / file / line, what's wrong, what should change.

## Suggested Additions
- [bullet list of items the plan should include but doesn't — e.g. missed test cases, missed cleanup, missed cross-references]
```

Be specific. Quote line numbers and file paths. If you would reject any item: say so explicitly with "REJECT" prefix. If you agree: say "OK". If you would change something but it's not blocking: "MINOR".

## Plan to validate (verbatim)

The full plan is in this same repo at `.kit-orchestration/pr1-plan.md`. Read it directly with the file system. The plan also references `.kit-orchestration/pr1-audit.md` which records prompt-vs-reality discrepancies — read that too. Your job is to verify the plan's claims about file paths, line numbers, bug locations, and the proposed sequence of edits.

## Specific pressure points

In addition to a general critique, address these explicitly:

1. **Bug #5 template consolidation** — the plan picks `project-init/` as canonical and deletes the duplicates in `project-spec/`. Are there any other consumers of the `project-spec/{module-spec,claude-module}-template.md` paths in the repo that the plan misses? (Check `bootstrap.sh`, all `SKILL.md` files, `README.md`, any other docs.)
2. **Bug deletion sequencing** — the plan says bugs #2 and #3 are "fixed by deletion" because the only buggy copies live in files being deleted as part of #5. Verify this: confirm `project-init/claude-module-template.md` does NOT contain `{{Type}>` or `loading: true` in a finally block.
3. **Bootstrap.sh heredoc removals** — the plan says delete `TEMPLATE_CLAUDE2_EOF` (line 2847) and `TEMPLATE_SPEC2_EOF` (line ~2937). Confirm exact start/end line ranges for both heredocs and any surrounding `echo` confirmation lines that should also be removed.
4. **CHANGELOG.md rewrite** — the plan says all content was added in one commit (`0cb37af`). Confirm via `git log --follow ENHANCEMENT_PLAN.md`. If accurate, is single-section dated entry under `## [0.1.0] - 2026-05-08` the right Keep-a-Changelog idiom?
5. **README placeholder URL** — the plan replaces `https://your-repo/bootstrap.sh` with `https://raw.githubusercontent.com/korallis/workflow/main/bootstrap.sh`. Verify this URL would actually work post-merge (i.e. the file is at repo root, not in a subdirectory).
6. **Commit sequence** — the plan lists 6 commits, but commit #2 is annotated as "combined into commit 5 if we're deleting". Is the proposed final commit list (1, 3, 4, 5, 6 + audit log) coherent and atomic? Or should some be merged/split?
7. **Manual test checklist coverage** — does the test checklist actually exercise every bug fix?

## Output destination

Write your report to stdout. The orchestrator will redirect to `.kit-orchestration/pr1-validation.md`.

Stop and ask if anything in this prompt is ambiguous.

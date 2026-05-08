# Plan validation request — PR3 (hooks, security-review, effort metadata)

You are a senior code reviewer acting as a plan validator in a dual-harness orchestration. The planner (Claude Opus 4.7) has produced a detailed plan for PR3 of the AI Project Kit. Your job is to critique it for correctness, completeness, and risk before execution.

You have read access to the working directory at `/home/leeb/workflow` (branch `feat/hooks-security-effort`). PR1 (#1) and PR2 (#2) merged on main; this branch has only fresh `.kit-orchestration/pr3-*` files committed.

## Hard rules

- Read-only review. Do NOT write code, do NOT modify any file.
- Do NOT push, commit, or modify CI.
- If anything is ambiguous, list it under **Issues Found** rather than guessing.

## Required output format

```markdown
## Confirmed Correct
- [items the plan gets right]

## Issues Found
- [REJECT or MINOR-prefixed bullets describing concrete problems]

## Suggested Additions
- [items the plan should include but doesn't]
```

Use `REJECT` for blockers (broken bash/JSON, wrong hook event names, missing files referenced) and `MINOR` for cosmetic or low-impact issues.

## Plan to validate

Read `.kit-orchestration/pr3-plan.md` directly. Pay particular attention to:

- Full source of `.claude/hooks/pre-compact.sh`.
- Full content of `.claude/settings.json` (must be valid JSON; correct hook event name + matcher per Claude Code spec).
- The `project-security-review/SKILL.md` body (does the Agent-isolation pattern actually achieve fresh context?).
- The `security-review-prompt.md` content (is the checklist comprehensive without bloat?).
- The `--isolate` flag addition to `project-review/SKILL.md`.
- The `effort: high` frontmatter additions (only on the four named skills, not all 10).
- bootstrap.sh insertion plan (line refs claimed to be ~37-49, ~3878-4127, ~3751-3804 — verify against current main).

## Specific pressure points

Address each explicitly in your report:

### pre-compact.sh

1. **Hook stdin JSON structure**: per Claude Code 2.x docs, what fields does PreCompact pipe in? (`session_id`, `transcript_path`, `permission_mode`, `hook_event_name`, `trigger`, `custom_instructions` per docs.) Does the script handle all of them correctly? Are there cases where stdin is empty or non-JSON?
2. **`compgen -G` portability**: works in bash 3.2 (macOS default)? bash 5+? Any quoting pitfalls?
3. **`jq` optional fallback**: if jq is missing, all extract() calls return empty — does the rest of the script remain safe? (Specifically: snapshot 1 & 2 silently skipped, snapshot 3 still writes.)
4. **`tail -n 50 "$transcript_path"`**: transcript files are JSONL. Tailing 50 lines gives the last 50 events, but each event can be many lines when the JSON is pretty-printed inside the file. Should the script extract human-readable text via jq, or is raw JSONL acceptable?
5. **`mkdir -p` race**: if multiple concurrent compactions fire (unlikely but possible), is the directory creation safe? (Yes — `-p` is atomic.)
6. **Output file collisions**: TIMESTAMP includes `$$` PID suffix. Sufficient.
7. **Error handling**: `set -e` plus `|| true` on `git` commands — confirm git failures don't kill the script.
8. **Should the hook block compaction on critical state?** Per the plan, no (always exit 0). Is that the right call?

### settings.json

9. **Schema URL**: `$schema: "https://json.schemastore.org/claude-code-settings.json"` — does this URL exist and provide validation? If not, the schema reference is dead but harmless.
10. **`PreCompact` matcher `*`**: per Claude Code hook docs, valid matchers are `manual`, `auto`, or `*`. Confirm `*` matches both.
11. **`SessionStart` matcher `compact`**: per Claude Code docs, SessionStart matchers include `startup`, `resume`, `clear`, `compact`. Confirm `compact` is current spelling.
12. **JSON validity**: ensure no trailing commas, no comments (JSON doesn't allow them).
13. **Hook precedence**: project-level `.claude/settings.json` merges with user-level `~/.claude/settings.json`. Does this PR's PreCompact hook clobber a user-level PreCompact hook, or do they both fire? Per docs they merge, but worth confirming the user's existing hooks aren't replaced.
14. **Inline shell command in `SessionStart` hook**: contains `compgen` and `ls` — runs in `bash` per Claude Code default. Does the harness invoke `bash -c <cmd>`? If `sh -c`, `compgen` is a bashism that fails. Verify.

### security-review SKILL.md

15. **`Agent(subagent_type="general-purpose", prompt=…)`**: skill prose tells Claude to call this. Does Claude Code's Agent tool API use those exact arg names? Per the Agent tool docs in this session: `subagent_type` and `prompt` and `description` are real. Yes.
16. **Context isolation guarantee**: does an Agent spawned from a skill instruction actually have a fresh context, or does it inherit some of the parent's transcript? Per Anthropic Agent docs: spawned agents get isolated context windows.
17. **Diff capture**: `git diff --merge-base origin/main` — works only if `origin/main` is reachable. On a brand-new branch with no upstream tracking yet, this might fail. Suggest a fallback (e.g. `git diff main` if remote isn't fetched, or `HEAD~1..HEAD` for last commit).
18. **Skill effort: high**: confirmed Claude-Code-extended field. OK.

### security-review-prompt.md

19. **Checklist breadth**: covers auth, authz, input validation, output handling, GDPR PII, audit logging, healthcare, dependencies, ops hygiene. Anything missing for the kit's typical use cases?
20. **Output format**: clearly specifies severity buckets and required sections — good for parser/human readability.
21. **"Diff to review" placeholder**: the actual diff gets injected at runtime. Is that injection happening in SKILL.md before launching Agent, or in the Agent prompt itself? Plan says SKILL.md interpolates — confirm.

### project-review --isolate

22. **Flag detection**: `if $ARGUMENTS contains --isolate` — does the SKILL.md prose make this reliable? Could the parser miss the flag if other arguments are also present (e.g. `/project-review --isolate auth-module`)?
23. **In-session vs Agent path divergence**: any setup the in-session path does that the Agent path skips (and vice versa)? Should be parallel.

### effort: high frontmatter

24. **Position in YAML**: should `effort:` come before or after `description:`? Either works; consistent placement preferred. Plan says "after description" — fine.
25. **Consistency check**: does the plan miss any skill that should be effort: high (e.g. `project-research` is research-heavy — should it be high)? Plan only adds to project-init and project-blueprint plus the new ones. Per the master plan decisions, that's intentional (defer noisy churn).

### bootstrap.sh

26. **Line ranges in plan are claimed but not pin-cited**: please verify against `git show HEAD:bootstrap.sh` whether the claimed ranges (top dir block 37-49, lib heredocs ~3878-4127, COMMANDS ~3751-3804) are correct as of current main HEAD on this branch.
27. **Heredoc terminator collision**: validate `HOOK_PRECOMPACT_EOF`, `SETTINGS_JSON_EOF`, `SKILL_SECURITY_EOF`, `PROMPT_SECURITY_EOF`, `CMD_SECURITY_EOF` don't collide with existing terminators.
28. **Embedded skill heredoc edits**: the plan says update project-init, project-blueprint, project-review heredocs in bootstrap.sh to add effort frontmatter / --isolate section. Are those heredocs identifiable by their start lines?
29. **`.gitkeep` in bootstrap**: `mkdir -p specs/sessions` then `touch specs/sessions/.gitkeep`? Or write a heredoc with empty content?

### Cross-cutting

30. **Issue #13572 caveat**: the plan mentions it for both PreCompact reliability and SessionStart backup. Is the documented behaviour current? (Linked issue is from 2025/2026; verify it hasn't been resolved upstream.)
31. **macOS portability of pre-compact.sh**: same as dispatch.sh — `bash`, `git`, `tail`, `compgen`, `mkdir`, optional `jq`. Should be fine without changes.
32. **CLAUDE.md and README.md updates**: are the described prose additions sufficient? Anything materially missing?

## Output destination

Write your report to stdout. The dispatcher will redirect to `.kit-orchestration/pr3-validation.md`.

If anything is ambiguous, ask via the Issues Found section. Do not improvise.

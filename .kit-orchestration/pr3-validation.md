## Confirmed Correct
- `.claude/settings.json` is valid JSON as written: no comments, no trailing commas.
- The schema URL exists: `https://json.schemastore.org/claude-code-settings.json`.
- Current Claude Code hook docs confirm `PreCompact` and `SessionStart` are valid event names; `PreCompact` matchers include `manual` / `auto`, and `*` matches all occurrences. `SessionStart` matcher `compact` is current spelling. Source: https://code.claude.com/docs/en/hooks
- Current PreCompact input includes common hook fields plus `trigger` and `custom_instructions`; the script safely ignores unused fields like `cwd`, `permission_mode`, and `hook_event_name`.
- Empty or non-JSON stdin is safe when `jq` is present because failed `jq` reads are swallowed with `|| true`; without `jq`, extracted values are empty and the script still reaches the git snapshot path.
- `compgen -G "$pattern"` is a Bash builtin available in Bash 3.2 and 5.x; the quoted glob pattern is appropriate because `compgen -G` expects the pattern as an argument.
- `mkdir -p "$OUT_DIR"` is safe for concurrent hook executions, and the `$(date +%Y%m%d-%H%M%S)-$$` suffix is sufficient to avoid ordinary output collisions.
- The git snapshot commands are protected with `2>/dev/null || true`, so git log/status failures do not kill the script.
- Not blocking compaction is the right default. Claude Code documents that PreCompact can block with exit code 2 or a block decision; this plan intentionally avoids that.
- Raw `tail -n 50` on the transcript is acceptable for recovery. Claude transcript files are JSONL; it is less readable than `jq` extraction, but it preserves recent events.
- Claude Code docs confirm subagents run in their own context window, so the Agent-isolation pattern can provide fresh-context review if only the diff/checklist are passed. Source: https://code.claude.com/docs/en/sub-agents
- `effort: high` is a supported Claude Code skill frontmatter field. Adding it only to `project-init`, `project-blueprint`, existing `project-execute`, and new `project-security-review` matches the stated scope.
- Bootstrap anchors mostly match current `HEAD:bootstrap.sh`: top mkdir block is lines 37-50; lib heredocs start at 3889 and 4083; project-init/project-blueprint/project-review heredocs are identifiable at lines 389, 2090, and 2826.
- Proposed heredoc terminators `HOOK_PRECOMPACT_EOF`, `SETTINGS_JSON_EOF`, `SKILL_SECURITY_EOF`, `PROMPT_SECURITY_EOF`, and `CMD_SECURITY_EOF` do not collide with existing `bootstrap.sh` terminators.
- Issue #13572 is still relevant as a caveat: it is closed as “not planned”, not clearly resolved upstream. Source: https://github.com/anthropics/claude-code/issues/13572

## Issues Found
- REJECT: `.claude/settings.json` uses `"command": ".claude/hooks/pre-compact.sh"`. Claude Code runs command hooks in the current directory, and the docs recommend `$CLAUDE_PROJECT_DIR` for project scripts. If the session cwd is not the repo root, the hook can fail to start. Use `"\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-compact.sh"` or equivalent.
- REJECT: `/project-review --isolate` is not equivalent to the existing `project-review` skill. The current skill captures session learnings, decisions, blockers, and updates `LEARNINGS.md` / `CLAUDE.md`; a fresh Agent given only a diff cannot know the parent session history. This breaks the stated “same steps in isolated context” goal.
- MINOR: The plan’s bootstrap command-wrapper line range is wrong. Current `HEAD:bootstrap.sh` has `COMMANDS` at lines 4142-4202, not ~3751-3804; that earlier range is inside the `project-execute` skill heredoc.
- MINOR: `pre-compact.sh` says “Exit 0 always”, but `set -euo pipefail` can still exit non-zero on races or filesystem errors such as `cat "$latest_plan"` or `tail "$transcript_path"` after a file disappears. Non-2 exits should not block compaction, but the contract is inaccurate.
- MINOR: The plan’s jq fallback note is inaccurate: without `jq`, snapshot 1 is not skipped if a plan file exists; only snapshot 2 is skipped because `transcript_path` is empty. Snapshot 3 still writes.
- MINOR: `git diff --merge-base origin/main` is brittle when `origin/main` is not fetched or the repo has no origin. The project currently has `origin/main`, but the skill should include an explicit fallback.
- MINOR: `/tmp/security-review-diff-$$.txt` and `/tmp/review-diff-$$.txt` are predictable temp paths and have no cleanup. Use `mktemp` plus `trap`.
- MINOR: `project-security-review` launches `general-purpose`, which has write-capable tools by default. For a read-only security review, prefer `Explore`, `context: fork` with `agent: Explore`, or a custom no-write reviewer.
- MINOR: The security checklist is good but misses a few common web-app risks: CSRF on state-changing requests, SSRF/open redirects, webhook signature verification, unsafe file uploads, and secrets leaking into client bundles.
- MINOR: The SessionStart hook uses `compgen`; current docs say command hooks default to Bash, so this is acceptable, but adding `"shell": "bash"` would make the dependency explicit.

## Suggested Additions
- Use `$CLAUDE_PROJECT_DIR` in both hook commands and any hook docs/examples so they work after `cd`.
- Consider adding a `PostCompact` hook or documenting why it is not used; current Claude Code docs now include `PostCompact` with a `compact_summary` field.
- For `pre-compact.sh`, add a final `trap '...; exit 0' ERR` or remove the “exit 0 always” claim.
- Improve transcript snapshots with optional `jq` extraction of recent user/assistant text while keeping raw JSONL as fallback.
- For `/project-review --isolate`, either rename the mode to isolated diff/code review or pass an explicit session summary into the Agent; otherwise it cannot perform learning capture faithfully.
- In bootstrap instructions, pin exact current anchors: dirs 37-50, project-init 389, project-blueprint 2090, project-review 2826, libs 3889/4083, commands 4142-4202.
- Add smoke validation for hook path independence: run the hook command from a subdirectory using `CLAUDE_PROJECT_DIR` set to the repo root.
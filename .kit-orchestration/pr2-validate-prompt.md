# Plan validation request — PR2 (`/project-execute` dual-harness skill)

You are a senior code reviewer acting as a plan validator in a dual-harness orchestration. The planner (Claude Opus 4.7) has produced a detailed plan for PR2 of the AI Project Kit. Your job is to critique it for **correctness, completeness, and risk** before it is executed.

You have read access to the working directory at `/home/leeb/workflow` (branch `feat/dual-harness-execute`). PR1 (#1) merged at commit `3b4f82f` on `main`; this branch is one commit ahead of main with only a fresh `.kit-orchestration/pr2-plan.md` so far.

## Hard rules

- Read-only review. Do NOT write code, do NOT modify any file.
- Do NOT push, commit, or modify CI.
- If anything is ambiguous, list it under **Issues Found** rather than guessing.

## Required output format

Return a single markdown report with exactly these sections, in this order:

```markdown
## Confirmed Correct
- [items the plan gets right, verified against the actual repo and external references]

## Issues Found
- [REJECT or MINOR-prefixed bullets describing concrete problems]
- For each: which plan section / file / line, what's wrong, what should change.

## Suggested Additions
- [items the plan should include but doesn't]
```

Use `REJECT` for blockers (incorrect code, broken bash, missing files referenced, security holes) and `MINOR` for cosmetic or low-impact issues.

## Plan to validate

The full plan is at `.kit-orchestration/pr2-plan.md` in this repo. Read it directly with the file system. Pay particular attention to:

- The full source code of `.claude/lib/dispatch.sh` (under "## `dispatch.sh` — full source spec").
- The full source code of `.claude/lib/scrub-secrets.sh` (under "## `scrub-secrets.sh` — full source spec").
- The skill body for `.claude/skills/project-execute/SKILL.md`.
- The CLAUDE.md and README.md updates.
- The bootstrap.sh ordering claims.

## Specific pressure points

Address these explicitly in your report:

### dispatch.sh

1. **Tmux session resolution** (`resolve_tmux_session` function): does sorting `tmux list-clients -F '#{client_activity} #{session_name}' | sort -rn | head -1` reliably pick the user's most-recent attached session? What happens with zero clients but an existing detached session? With multiple clients on different sessions where the most-recent is on a session the user isn't watching?

2. **Single-flight lock** (`flock -n 200`): is `flock` available on macOS by default? (Spoiler: no.) Does the script need a portable alternative (`mkdir`-based lock, `lockfile` from procmail, etc.)? What happens if the script crashes between `exec 200>` and `flock`?

3. **Auth preflight**: 5-second timeout against `codex exec --skip-git-repo-check -s read-only -c model_reasoning_effort=low "echo dispatch.sh auth preflight"`. Is this fast enough for healthy auth and slow enough not to false-fail under network jitter? Does `timeout` itself exist on macOS? (No — needs `gtimeout`.)

4. **Codex sandbox flag for read-only**: `-s read-only` — does this exist as a sandbox value on Codex 0.128.0? (Earlier `codex exec --help` showed `read-only`, `workspace-write`, `danger-full-access`. Confirm.)

5. **`-c model_reasoning_effort=low`**: is `low` a valid value? (Per the OMX docs we already confirmed: low|medium|high|xhigh, plus "none" and "minimal" in newer versions.)

6. **Prompt passing**: `codex exec ... "$(cat "$PROMPT_FILE")"` — for large prompts, does this risk hitting `ARG_MAX`? Should we pipe via stdin (`< "$PROMPT_FILE" codex exec - ...`) instead?

7. **`set -euo pipefail` interaction with `tee`**: does `set -e` correctly capture `${PIPESTATUS[0]}` after the `tee` pipe? The script uses `set +e` / `set -e` around the codex invocation — is that necessary, sufficient, both?

8. **Trap on EXIT** for `auth_check_log`: if the script exits early (e.g. via `die`), is the temp file always cleaned up?

9. **TIMESTAMP collisions**: `date +%Y%m%d-%H%M%S` has 1-second resolution. If two phases dispatch within the same second, log files collide. Is this a realistic concern? Should we add `$$` or `$RANDOM` for extra entropy?

10. **`tmux split-window` failure**: the script falls back to "output will only be in the log" via `warn`. But the warning goes to stderr, which the user may not see. Should it be louder, or different?

### scrub-secrets.sh

11. **Pattern coverage gaps**: I cover `sk-...`, `ghp_/gho_/ghs_/ghu_/github_pat_`, `Bearer`, basic-auth-in-URL, and `AKIA[0-9A-Z]{16}`. Missing: Slack tokens (`xoxb-`, `xoxa-`, `xoxp-`), Stripe (`sk_live_`, `pk_live_`), JWTs without "Bearer" prefix (e.g. `eyJ...`), generic 32+ char hex tokens, GCP service-account JSON. Which of these matter for our threat model (Codex output may echo whatever the user's repo contains)?

12. **`sk-[A-Za-z0-9]{20,}` over-match**: this pattern matches strings like `sk-do-not-use-this-value` if 20+ chars. Could it eat real prose in Codex output (e.g. "use the sk- prefixed token format")? Suggest a more restrictive pattern.

13. **`Bearer` regex**: only catches when literal "Bearer " precedes. Misses raw bearer tokens in `Authorization:` lines without the prefix. Worth catching?

14. **Edits idempotent**: running scrub-secrets.sh twice should produce the same output. Verify the patterns don't re-match the redacted strings (e.g. `sk-REDACTED` shouldn't get re-matched and shortened to `sk-REDACTED` — it shouldn't, but verify).

### SKILL.md

15. The skill instructs Claude to invoke `bash .claude/lib/dispatch.sh` via the Bash tool. Is this the right pattern, or should it use a `command` hook in skill frontmatter? (Skills are prose; Claude reads and chooses tools. The Bash invocation pattern is correct.)

16. **`$ARGUMENTS` substitution**: is `$ARGUMENTS` a real Claude Code skill substitution variable? Per the Anthropic skill docs, `$ARGUMENTS` is supported in Claude Code commands. Confirm it works in skills too — older docs suggested commands only.

17. **Read order**: the plan reads CLAUDE.md → MASTER_BLUEPRINT.md → SPEC.md → module CLAUDE.md → LEARNINGS.md. Does this order matter? If MASTER_BLUEPRINT.md doesn't exist (project not yet blueprinted), does the skill abort cleanly?

18. **Instruction "Do not push, do not modify .git/"** — Codex with `-s workspace-write` *can* modify `.git/`. Should we use a more restrictive sandbox? Or is workspace-write necessary for the executor to commit (which it must)?

19. **Auto-invoke `/project-review`**: skills can't directly invoke other skills. Should this be "ask the user to run /project-review" or "Claude reads project-review/SKILL.md and follows its instructions"?

### CLAUDE.md / README.md prose

20. Does the dual-harness model description correctly state the auth flow? `codex login` is ChatGPT auth; `OPENAI_API_KEY` is API-key auth. These have different model availability (per CodeRabbit's earlier web research, gpt-5.5 may not be available with API-key auth — only with ChatGPT auth). The plan needs to mention this.

21. Is "Run from inside a tmux session for the live split pane" the right instruction? What if the user runs Claude Code outside tmux but has another terminal with tmux running? (Per PR1 feedback discussion: that *also* works because dispatch.sh detects via list-clients.)

### bootstrap.sh ordering

22. The plan says "after the `project-test/SKILL.md` heredoc (around line 4393)". Confirm the actual line in the post-PR1 main branch. Are there any heredocs between project-test/SKILL.md and the closing/summary sections of bootstrap.sh that would be a more natural insertion point?

23. **`mkdir -p .claude/lib` placement** — should it be alongside the existing `mkdir -p .claude/skills/...` calls, or before the new heredocs that write into `.claude/lib/`?

24. **`chmod +x` after the heredocs** — does the existing bootstrap pattern use chmod? (Check.)

### Macro concerns

25. **PR2 ships dispatch.sh; PR2's own validate/execute phases use inline `codex exec` (the bootstrap exception, same as PR1). Once merged, PR3 will use dispatch.sh.** Is this self-consistent? Yes, but worth confirming.

26. **Cross-PR ordering**: PR2 must merge before PR3. Is there anything in PR2 that would silently depend on PR3 changes (negative cross-dependency)?

27. **The plan claims the dispatcher is "observation-only on tmux"** — re-verify: with `tmux split-window -t SESSION "tail -f LOG"`, is the pane truly observation-only, or could user keystrokes in the pane interfere with anything? (The pane runs `tail -f`, so user input is just consumed by the running process; Ctrl-C ends `tail` but doesn't affect dispatch.sh. Confirm.)

## Output destination

Write your report to stdout. The orchestrator will redirect to `.kit-orchestration/pr2-validation.md`.

If anything is ambiguous, ask via the report's "Issues Found" section. Do not improvise.

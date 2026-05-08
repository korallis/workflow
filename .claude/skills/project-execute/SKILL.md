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

Concatenate the following into a single prompt file at `.kit-orchestration/exec-$ARGUMENTS-<timestamp>-prompt.md`:

1. A header: model + effort + module name + timestamp.
2. The full text of `CLAUDE.md` (root).
3. The full text of `specs/MASTER_BLUEPRINT.md`.
4. The full text of the module's `SPEC.md`.
5. The full text of the module's `CLAUDE.md`.
6. An explicit instruction block:

   ```text
   You are the executor in a dual-harness orchestration. Implement the module
   above end-to-end with these constraints:

   - Build phase by phase. After each phase: run tests; if green, git commit
     with a conventional message; if red, fix or stop and ask.
   - Do NOT manually edit files inside .git/ (e.g. config, hooks, refs). The
     normal `git add` / `git commit` writes that those commands perform are
     expected and allowed.
   - Do NOT `git push`. Do NOT modify CI configuration (.github/, etc.).
   - Do NOT modify files outside the module's directory unless the spec
     requires shared edits — in that case, list them in your final report.
   - Stop and ask if any spec instruction is ambiguous.
   - At the end, write a final report to stdout with: phases completed,
     files created, tests passing/failing, and any deviations from the spec.
   ```

7. The full prompt template at `.claude/skills/project-execute/dispatch-prompt-template.md` provides the canonical assembly order; follow it.

## Dispatch via dispatch.sh

Run, as a single Bash tool call:

```bash
bash .claude/lib/dispatch.sh execute "$ARGUMENTS" gpt-5.5 medium \
  ".kit-orchestration/exec-$ARGUMENTS-<timestamp>-prompt.md"
```

The dispatcher handles tmux split (into the most-recent attached session), log capture, lock acquisition, auth/model preflight, timeout enforcement, and exit-code propagation. **Note**: dispatch.sh writes raw logs — secret scrubbing happens later, when this skill reads the log back. If `dispatch.sh` exits non-zero, surface the error and stop.

## After Codex returns

1. Read `.kit-orchestration/execute-$ARGUMENTS-<timestamp>-last.md` (Codex's final message — already scrubbed by Codex's own output handling, no further sanitisation needed).
2. **Read the run log via the scrubber** before pulling lines into context: `bash .claude/lib/scrub-secrets.sh .kit-orchestration/execute-$ARGUMENTS-<timestamp>.log | tail -200`. Never read the raw `.log` directly — it may contain credentials Codex echoed.
3. Summarise the outcome to the user: phases completed, commits Codex created on the branch, tests run, deviations.
4. **Run the review skill in this session**: read `.claude/skills/project-review/SKILL.md` and follow its instructions to update `LEARNINGS.md`. (Skills cannot literally invoke other skills as user actions; this is the Claude-reads-and-follows pattern.) Alternatively, if the user prefers an isolated review, suggest they run `/project-review --isolate` (added in PR3).
5. Do NOT push the branch — that's the user's call.

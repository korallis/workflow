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

Run, as a single Bash tool call (reusing the same `$TS` from the prompt-build step):

```bash
bash .claude/lib/dispatch.sh execute "$ARGUMENTS" gpt-5.5 medium \
  ".kit-orchestration/exec-$ARGUMENTS-$TS-prompt.md"
```

The dispatcher handles tmux split (into the most-recent attached session), log capture, lock acquisition, auth/model preflight, timeout enforcement, and exit-code propagation. **Note**: dispatch.sh writes raw logs — secret scrubbing happens later, when this skill reads the log back. If `dispatch.sh` exits non-zero, surface the error and stop.

## After Codex returns

Use the same `$TS` from the prompt-build step. **Both `-last.md` and `.log` must be piped through `scrub-secrets.sh` before re-entering Claude's context** — `-last.md` is Codex's final agent message and may include credentials it echoed during the run; do not trust it as pre-sanitised.

1. Read the scrubbed last-message: `bash .claude/lib/scrub-secrets.sh .kit-orchestration/execute-$ARGUMENTS-$TS-last.md`.
2. Read the scrubbed run log tail: `bash .claude/lib/scrub-secrets.sh .kit-orchestration/execute-$ARGUMENTS-$TS.log | tail -200`. Never read the raw `.log` or `-last.md` directly.
3. Summarise the outcome to the user: phases completed, commits Codex created on the branch, tests run, deviations.
4. **Run the review skill in this session**: read `.claude/skills/project-review/SKILL.md` and follow its instructions to update `LEARNINGS.md`. (Skills cannot literally invoke other skills as user actions; this is the Claude-reads-and-follows pattern.) Alternatively, if the user prefers an isolated review, suggest they run `/project-review --isolate` (added in PR3).
5. Do NOT push the branch — that's the user's call.

Note: the `<TS>` placeholders in any spec or log examples elsewhere in the kit refer to the same `$TS` value computed once per `/project-execute` run.

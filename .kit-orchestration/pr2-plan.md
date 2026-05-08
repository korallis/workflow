# PR2 plan — `/project-execute` (dual-harness execution via Codex CLI)

**Branch**: `feat/dual-harness-execute`
**PR title**: `feat: dual-harness execution via Codex CLI (project-execute skill)`
**Prerequisite merged**: PR1 (#1, merged 2026-05-08, commit `3b4f82f`).

## Context

PR1 fixed the kit's surface bugs and shipped `.kit-orchestration/` scaffolding. PR2 is the architectural centrepiece: a `/project-execute` skill that lets Claude Code (the orchestrator) hand a fully-specced module to Codex CLI (the executor) inside a live tmux pane the user can watch.

Three things must be true for PR2 to be valuable:
1. **Live visibility**: panes split into the user's currently attached tmux session — not a separate detached one (this was the PR1 feedback).
2. **Real exit codes**: dispatch.sh runs Codex as a child process and captures the actual exit status; tmux is observation only.
3. **Hands-off auth surface**: Codex auth failures surface a clear actionable message rather than a silent hang.

## Files this PR creates

```text
.claude/lib/dispatch.sh                                  # shared dispatcher (chmod +x)
.claude/lib/scrub-secrets.sh                             # regex secret redactor (chmod +x)
.claude/skills/project-execute/SKILL.md                  # orchestrator skill (effort: high)
.claude/skills/project-execute/dispatch-prompt-template.md  # prompt-assembly template
.claude/commands/project-execute.md                      # thin command wrapper
```

## Files this PR updates

- `bootstrap.sh` — heredocs for the five new files (after the existing `project-test/SKILL.md` heredoc), `mkdir -p .claude/lib`, `chmod +x` on the two shell scripts, ensure `.kit-orchestration/` directory creation with `.gitignore` (already shipped in PR1; bootstrap.sh just needs to recreate them on fresh installs).
- `CLAUDE.md` (root) — add `/project-execute` to the trigger table; add a "Dual-Harness Workflow" section after "Workflow".
- `README.md` — add a "Dual-Harness Mode" section after "How It Works"; document `/project-module` (single-harness) vs `/project-execute` (dual-harness); document Codex CLI prerequisite.

## `dispatch.sh` — full source spec (revised after validator)

The validator should critique this code directly. **Revisions vs first pass** (validator REJECTs 1, 2, 3, 4, 5, 6, 7 + MINORs 8, 9 addressed):

- macOS portability: portable `kit_timeout` wrapper that prefers `gtimeout` then `timeout`, errors clearly if neither.
- macOS portability: replaced `flock` with `mkdir`-based lock + trap cleanup, works on Linux + macOS.
- Auth preflight: now passes `-m "$MODEL"`, configurable timeout via `KIT_AUTH_PREFLIGHT_SECONDS` (default 15s), surfaces both "no codex" and "model unavailable for this auth tier" failures clearly.
- Prompt passing: stdin instead of `"$(cat "$PROMPT_FILE")"` to avoid `ARG_MAX`.
- Timestamp collision: `$$` PID suffix appended.
- tmux split warning also written to the log file so the skill sees it.
- Inline tmux note clarifies "most-recent attached client" rather than implying it's always the right session.

```bash
#!/usr/bin/env bash
# .claude/lib/dispatch.sh — dual-harness Codex dispatcher
#
# Runs Codex CLI as a child process, tees output to a log under
# .kit-orchestration/, and (when an attached tmux session is reachable)
# splits a viewer pane that runs `tail -f` on the log so the user sees
# the run live in their existing terminal.
#
# Usage: dispatch.sh <phase> <id> <model> <effort> <prompt-file>
#   phase: validate | execute | review | <free-form-tag>
#   id:    stable identifier (PR number, module name, etc.) — kebab-case
#   model: Codex model (e.g. gpt-5.5)
#   effort: low | medium | high | xhigh   (passed via -c model_reasoning_effort=...)
#   prompt-file: path to a file whose contents are streamed to Codex via stdin
#
# Env knobs:
#   KIT_TMUX_SESSION         override which tmux session to split into
#   KIT_TMUX_SPLIT           'h' (default) or 'v'
#   KIT_NO_TMUX=1            force inline streaming (no tmux pane)
#   KIT_CODEX_TIMEOUT        hard timeout in seconds for the main exec (default 1800)
#   KIT_AUTH_PREFLIGHT_SECONDS  preflight timeout (default 15)
#   KIT_ALLOW_CONCURRENT=1   bypass single-flight lock
#   KIT_CODEX_SANDBOX        override sandbox mode (default workspace-write)
#
# Portability: works on Linux and macOS. Requires either `timeout`
# (coreutils, default on Linux) or `gtimeout` (Homebrew coreutils on
# macOS). Lock is mkdir-based, no flock dependency.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly KIT_DIR="$REPO_ROOT/.kit-orchestration"
readonly LOCK_DIR="$KIT_DIR/.lock"

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
warn() { printf '\033[33mwarn:\033[0m %s\n'  "$*" >&2; }
info() { printf '\033[36minfo:\033[0m %s\n'  "$*" >&2; }

# --- portable timeout wrapper ------------------------------------------------

kit_timeout_cmd=""
if command -v timeout >/dev/null 2>&1; then
  kit_timeout_cmd="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  kit_timeout_cmd="gtimeout"
fi

kit_timeout() {
  # Usage: kit_timeout <seconds> <cmd> [args...]
  if [[ -z "$kit_timeout_cmd" ]]; then
    die "neither 'timeout' nor 'gtimeout' on PATH. Install GNU coreutils (Linux: apt/dnf install coreutils; macOS: brew install coreutils)."
  fi
  "$kit_timeout_cmd" "$@"
}

# --- arg parsing -------------------------------------------------------------

(( $# == 5 )) || die "usage: dispatch.sh <phase> <id> <model> <effort> <prompt-file>"
readonly PHASE="$1" ID="$2" MODEL="$3" EFFORT="$4" PROMPT_FILE="$5"

case "$PHASE" in
  validate|execute|review) ;;
  *) [[ "$PHASE" =~ ^[a-z][a-z0-9-]*$ ]] || die "phase must be kebab-case alphanumeric, got: $PHASE" ;;
esac
[[ "$ID" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "id must be kebab-case alphanumeric, got: $ID"
[[ "$EFFORT" =~ ^(low|medium|high|xhigh)$ ]] || die "effort must be low|medium|high|xhigh, got: $EFFORT"
[[ -f "$PROMPT_FILE" ]] || die "prompt file not found: $PROMPT_FILE"

# --- preflight: codex CLI presence + auth + model availability ---------------

command -v codex >/dev/null 2>&1 || die "codex CLI not found on PATH. Install with: npm install -g @openai/codex"

readonly KIT_CODEX_TIMEOUT="${KIT_CODEX_TIMEOUT:-1800}"
readonly KIT_CODEX_SANDBOX="${KIT_CODEX_SANDBOX:-workspace-write}"
readonly KIT_AUTH_PREFLIGHT_SECONDS="${KIT_AUTH_PREFLIGHT_SECONDS:-15}"

# Auth + model preflight. Uses the actual target model so we surface
# "model not available for this auth tier" before opening tmux panes.
auth_check_log="$(mktemp)"
trap 'rm -f "$auth_check_log"' EXIT
if ! kit_timeout "$KIT_AUTH_PREFLIGHT_SECONDS" codex exec \
     -m "$MODEL" \
     --skip-git-repo-check \
     -s read-only \
     -c model_reasoning_effort=low \
     - <<<'echo dispatch.sh auth preflight' >"$auth_check_log" 2>&1; then
  warn "codex preflight failed (model=$MODEL, timeout=${KIT_AUTH_PREFLIGHT_SECONDS}s). Output:"
  sed 's/^/    /' "$auth_check_log" >&2
  die "Auth or model availability error. Try \`codex login\` (ChatGPT auth — required for gpt-5.5 access without API tier) or set OPENAI_API_KEY for a tier that supports model '$MODEL'. Increase KIT_AUTH_PREFLIGHT_SECONDS if the network is slow."
fi

# --- single-flight lock (mkdir-based, portable) ------------------------------

mkdir -p "$KIT_DIR"
if [[ -z "${KIT_ALLOW_CONCURRENT:-}" ]]; then
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    die "another dispatch.sh run is in progress (lock dir at $LOCK_DIR). If a previous run died, remove it manually. Set KIT_ALLOW_CONCURRENT=1 to bypass."
  fi
  trap 'rm -rf "$LOCK_DIR"; rm -f "$auth_check_log"' EXIT
fi

# --- log path (PID-suffixed to avoid 1s timestamp collisions) ----------------

readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)-$$"
readonly LOG_FILE="$KIT_DIR/${PHASE}-${ID}-${TIMESTAMP}.log"
readonly LAST_FILE="$KIT_DIR/${PHASE}-${ID}-${TIMESTAMP}-last.md"
touch "$LOG_FILE"
info "log: $LOG_FILE"

# --- tmux session resolution -------------------------------------------------

# NOTE: this resolves "the most-recent attached tmux client", which is
# usually the user's current terminal but is not guaranteed when multiple
# clients are attached to different sessions. Use KIT_TMUX_SESSION to pin.

resolve_tmux_session() {
  [[ -n "${KIT_NO_TMUX:-}" ]] && return 1
  command -v tmux >/dev/null 2>&1 || return 1

  if [[ -n "${KIT_TMUX_SESSION:-}" ]]; then
    if tmux has-session -t "$KIT_TMUX_SESSION" 2>/dev/null; then
      printf '%s' "$KIT_TMUX_SESSION"; return 0
    fi
    warn "KIT_TMUX_SESSION=$KIT_TMUX_SESSION set but session does not exist; falling back to detection"
  fi

  local sess
  sess=$(tmux list-clients -F '#{client_activity} #{client_session}' 2>/dev/null \
           | sort -rn | head -1 | awk '{print $2}')
  if [[ -n "$sess" ]]; then
    printf '%s' "$sess"; return 0
  fi

  # Detached sessions are intentionally ignored — we only split where a
  # human is watching. Set KIT_TMUX_SESSION to override.
  return 1
}

TMUX_SESSION=""
if tmux_session=$(resolve_tmux_session); then
  TMUX_SESSION="$tmux_session"
  split_flag="-${KIT_TMUX_SPLIT:-h}"
  info "splitting tmux session '$TMUX_SESSION' (override with KIT_TMUX_SESSION=name)"
  if ! tmux split-window -t "$TMUX_SESSION" "$split_flag" \
        "echo '── kit-orchestration: $PHASE/$ID ──'; tail -f '$LOG_FILE'" >/dev/null 2>&1; then
    msg="tmux split-window failed for session '$TMUX_SESSION'; viewing log inline."
    warn "$msg"
    echo "## dispatch.sh: $msg" >> "$LOG_FILE"
    TMUX_SESSION=""
  fi
fi
if [[ -z "$TMUX_SESSION" ]]; then
  info "no attached tmux client to split into — streaming inline (KIT_NO_TMUX=1 to silence)"
  echo "==== Codex output begins ($PHASE/$ID) ===="
fi
readonly TMUX_SESSION

# --- run codex (prompt via stdin to avoid ARG_MAX) ---------------------------

set +e
kit_timeout "$KIT_CODEX_TIMEOUT" codex exec \
  -m "$MODEL" \
  -c "model_reasoning_effort=$EFFORT" \
  -s "$KIT_CODEX_SANDBOX" \
  --skip-git-repo-check \
  -C "$REPO_ROOT" \
  -o "$LAST_FILE" \
  - <"$PROMPT_FILE" 2>&1 \
  | tee -a "$LOG_FILE"
codex_rc=${PIPESTATUS[0]}
set -e

echo "EXIT=$codex_rc" >> "$LOG_FILE"

if [[ -z "$TMUX_SESSION" ]]; then
  echo "==== Codex output ends (exit $codex_rc) ===="
fi

if (( codex_rc == 124 )); then
  die "codex exec timed out after ${KIT_CODEX_TIMEOUT}s (set KIT_CODEX_TIMEOUT=<seconds> to extend)"
fi

if (( codex_rc != 0 )); then
  die "codex exec failed with exit $codex_rc; see $LOG_FILE"
fi

info "dispatch complete: $LAST_FILE"
exit 0
```

## `scrub-secrets.sh` — full source spec (revised after validator)

**Revisions vs first pass** (validator MINORs 10, 11, 12 addressed):

- Added Slack tokens (xoxb-, xoxa-, xoxp-, xoxs-) and Slack workspace tokens (xapp-).
- Added Stripe live and restricted secret keys (sk_live_, rk_live_).
- Added raw JWT pattern (eyJ-prefixed three-part tokens).
- Added `Authorization:` header without `Bearer` prefix.
- Tightened `sk-[A-Za-z0-9]{20,}` to require longer tail to reduce false positives.
- Generic 32+ hex token redaction NOT added — too aggressive (would redact commit hashes, file hashes, etc.).
- Idempotency verified: redacted strings (e.g. `sk-REDACTED`) do not re-match because `REDACTED` ends the token.

```bash
#!/usr/bin/env bash
# .claude/lib/scrub-secrets.sh — read-path secret redactor
#
# Reads stdin (or a file path arg), redacts common credential shapes,
# writes to stdout. Used by Claude when reading dispatch logs back into
# context, so secrets that Codex may have echoed don't get re-injected.
#
# Patterns covered (deliberately conservative — false positives ok,
# false negatives bad):
#   - Anthropic / OpenAI keys: sk-ant-..., sk-proj-..., sk-...
#   - GitHub PATs: ghp_..., gho_..., ghs_..., ghu_..., github_pat_...
#   - Slack tokens: xoxb-, xoxa-, xoxp-, xoxs-, xapp-
#   - Stripe secret keys: sk_live_..., rk_live_...
#   - JWTs: eyJ<base64>.<base64>.<base64>
#   - Bearer tokens: Bearer <opaque>
#   - Authorization: <opaque> headers (without Bearer scheme)
#   - Basic auth in URLs: https://user:password@...
#   - AWS access keys: AKIA[0-9A-Z]{16}
#
# Patterns deliberately NOT covered:
#   - Generic 32+ hex strings (would redact git SHAs, file hashes, etc.)
#   - Any heuristic for high-entropy short strings (false positive risk too high)
#
# Usage:
#   cat log | scrub-secrets.sh              # stdin → stdout
#   scrub-secrets.sh path/to/log            # file → stdout

set -euo pipefail

input() {
  if (( $# == 0 )); then cat
  else cat "$1"
  fi
}

input "$@" | sed -E '
  s/sk-ant-[A-Za-z0-9_-]{20,}/sk-ant-REDACTED/g
  s/sk-proj-[A-Za-z0-9_-]{20,}/sk-proj-REDACTED/g
  s/sk-[A-Za-z0-9]{32,}/sk-REDACTED/g
  s/sk_live_[A-Za-z0-9]{20,}/sk_live_REDACTED/g
  s/rk_live_[A-Za-z0-9]{20,}/rk_live_REDACTED/g
  s/ghp_[A-Za-z0-9]{30,}/ghp_REDACTED/g
  s/gho_[A-Za-z0-9]{30,}/gho_REDACTED/g
  s/ghs_[A-Za-z0-9]{30,}/ghs_REDACTED/g
  s/ghu_[A-Za-z0-9]{30,}/ghu_REDACTED/g
  s/github_pat_[A-Za-z0-9_]{40,}/github_pat_REDACTED/g
  s/xox[abprs]-[A-Za-z0-9-]{10,}/xox-REDACTED/g
  s/xapp-[0-9]+-[A-Za-z0-9-]{10,}/xapp-REDACTED/g
  s/eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/eyJ.REDACTED.REDACTED/g
  s/(Bearer[[:space:]]+)[A-Za-z0-9._~+/=-]{20,}/\1REDACTED/g
  s/([Aa]uthorization:[[:space:]]+)([A-Za-z][A-Za-z0-9_-]*[[:space:]]+)?[A-Za-z0-9._~+/=-]{20,}/\1\2REDACTED/g
  s|(https?://)[^:/[:space:]]+:[^@[:space:]]+@|\1REDACTED:REDACTED@|g
  s/\bAKIA[0-9A-Z]{16}\b/AKIAREDACTED/g
'
```

## `.claude/skills/project-execute/SKILL.md` — content spec (revised after validator)

**Revisions** (validator MINORs 13, 14, suggested addition 4 addressed):

- Explicit blueprint missing → `/project-blueprint` instruction.
- Removed "Auto-invoke /project-review" — instead Claude reads `.claude/skills/project-review/SKILL.md` and follows it.
- Validate `$ARGUMENTS` matches kebab-case directory basename before using.
- Clarified .git/ rule: no manual edits, but git commits via the executor are expected.

```yaml
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
```

## `.claude/skills/project-execute/dispatch-prompt-template.md` — content spec

A short template that documents the assembly order, with placeholders for each input. ~40 lines.

## `.claude/commands/project-execute.md` — content spec

```markdown
Read and follow the skill at `.claude/skills/project-execute/SKILL.md`.
```

(Same one-line wrapper pattern as the other commands.)

## `CLAUDE.md` updates (revised after validator)

Add to the trigger table:

```text
| `/project-execute [module]` | Dual-harness mode: hand a fully-specced module to Codex CLI for implementation while Claude orchestrates. Live tmux pane in your most-recent attached session. |
```

Add a new section after "Workflow":

```markdown
## Dual-Harness Workflow

Some tasks are big enough that you want Claude (Opus 4.7) to plan and review while Codex CLI (gpt-5.5) does the heavy implementation. The kit supports this via `/project-execute`:

- **Plan + Review**: Claude Code (this session). Reads specs, builds the dispatch prompt, reads back the scrubbed log, summarises, runs the review skill.
- **Execute**: Codex CLI (`gpt-5.5`, medium reasoning effort), launched via `.claude/lib/dispatch.sh`. Runs in a live tmux pane that splits into your most-recent attached session.

Single-harness mode (`/project-module`) keeps everything in Claude. Use dual-harness when the module is large, well-specced, and you want to watch implementation happen in real time.

**Prerequisites**:

- `npm install -g @openai/codex` (Codex CLI 0.128+ tested).
- Authenticate. Two paths with different model availability:
  - `codex login` — ChatGPT auth. Required for `gpt-5.5` access without API tier requirements.
  - `export OPENAI_API_KEY=…` — API-key auth. `gpt-5.5` requires Tier 1+ on your OpenAI org; if your org lacks the tier, the preflight will fail with a model-availability error.
- A tmux session with at least one attached client. dispatch.sh detects the most-recent attached client via `tmux list-clients` — Claude Code itself doesn't have to be inside tmux as long as one client is attached somewhere. Override with `KIT_TMUX_SESSION=<name>` when you have multiple sessions.

Portability: dispatch.sh works on Linux and macOS. Requires GNU coreutils (`timeout` on Linux, `gtimeout` after `brew install coreutils` on macOS). Lock is mkdir-based (no `flock` dependency).
```

## `README.md` updates (revised after validator)

Add after the "How It Works" section:

```markdown
## Dual-Harness Mode

For big module implementations you can offload execution to Codex CLI while Claude Code orchestrates:

| Mode | Skill | Plan & Review | Execute |
| --- | --- | --- | --- |
| Single-harness | `/project-module [name]` | Claude Code | Claude Code |
| Dual-harness | `/project-execute [name]` | Claude Code | Codex CLI (`gpt-5.5`) |

Dual-harness streams Codex output into a tmux pane that splits into your most-recent attached tmux session, so you see implementation happen live next to your Claude Code window.

**Prerequisites**:

- `npm install -g @openai/codex` (Codex CLI 0.128+ tested).
- Authenticate. Choose one:
  - `codex login` — ChatGPT auth (recommended for `gpt-5.5` access).
  - `export OPENAI_API_KEY=…` — API-key auth. `gpt-5.5` requires Tier 1+ on your OpenAI org; if your tier doesn't include it, the preflight surfaces a model-availability error before opening any panes.
- An attached tmux client. Easiest: launch Claude Code from inside tmux. Also works: have any other terminal attached to a tmux session — dispatch.sh detects via `tmux list-clients`. Without an attached client, output streams inline in Claude's transcript.
- macOS: `brew install coreutils` (provides `gtimeout`, used by the dispatcher).

**How it routes**:

1. Claude validates `$ARGUMENTS` as a kebab-case module name and reads `CLAUDE.md`, `specs/MASTER_BLUEPRINT.md`, `specs/modules/<name>/SPEC.md`, and the module's `CLAUDE.md`. Aborts with actionable instructions if any are missing.
2. Claude writes a dispatch prompt to `.kit-orchestration/exec-<name>-<timestamp>-prompt.md`.
3. `.claude/lib/dispatch.sh` runs an auth + model-availability preflight, acquires a single-flight lock, opens a tmux pane with `tail -f` on the log (or streams inline if no client is attached), then runs `codex exec` as a child process with the prompt piped via stdin.
4. Codex implements the module phase-by-phase, committing on green tests. It does not push.
5. Claude reads `.kit-orchestration/execute-<name>-<timestamp>-last.md` directly and the run log via `bash .claude/lib/scrub-secrets.sh <log>` (so any secrets Codex echoed are redacted before re-entering Claude's context), summarises, and reads `.claude/skills/project-review/SKILL.md` to capture learnings.

The dispatcher is observation-only on tmux — Codex's exit code comes from the real child process, not from `tmux send-keys`. macOS-portable (uses `gtimeout` and `mkdir`-based locks; no `flock` or GNU-only `timeout` dependency).
```

## `bootstrap.sh` updates (revised after validator — line refs corrected)

Validator confirmed actual line ranges in post-PR1 bootstrap.sh:

- `project-test/SKILL.md` heredoc: lines 3399-3719 (NOT 4393 as the first plan said).
- Top directory-creation block: lines 37-47.
- Command wrappers section: lines 3726-3777.
- No existing `chmod +x` pattern — PR2 introduces the first generated shell scripts.

Insertion plan respecting existing grouping:

1. **Top directory block (lines 37-47)**: add `mkdir -p .claude/lib`, `mkdir -p .claude/skills/project-execute`, `mkdir -p .kit-orchestration` (idempotent if already created).
2. **After project-test/SKILL.md heredoc (after line 3719, before the COMMANDS section at 3726)**: write the lib heredocs in this order:
   - heredoc → `.claude/lib/dispatch.sh` + `chmod +x .claude/lib/dispatch.sh` (echo confirmation)
   - heredoc → `.claude/lib/scrub-secrets.sh` + `chmod +x .claude/lib/scrub-secrets.sh`
   - heredoc → `.claude/skills/project-execute/SKILL.md`
   - heredoc → `.claude/skills/project-execute/dispatch-prompt-template.md`
   - heredoc → `.kit-orchestration/.gitignore` (only via `[ -f ".kit-orchestration/.gitignore" ] || cat > ...` to be idempotent — the file may already exist from PR1)
3. **Inside the COMMANDS section (lines 3726-3777)**: add the heredoc → `.claude/commands/project-execute.md` alongside the other command wrappers (e.g. after `project-test.md`).
4. **Inside the existing CLAUDE.md heredoc**: extend with the new "Dual-Harness Workflow" section and the trigger-table row.
5. **Inside the existing README.md heredoc**: extend with the new "Dual-Harness Mode" section.
6. **chmod note**: chmod is a NEW pattern in this kit (no existing generated shell scripts). Use `chmod +x` after each script heredoc; the existing kit pattern is the `echo -e "  ${GREEN}✓${RESET} <path>"` confirmation line, which we'll match.

**`.kit-orchestration/.gitignore` decision** (validator MINOR 19): PR1 already committed `.gitignore` containing `*.log`, `*-snapshot.md`, `.lock`. PR2 introduces `*-last.md` files (Codex's `--output-last-message` target). Decision: **commit** the `*-last.md` files for orchestration provenance (they're part of the audit trail, like validation reports). Do NOT add them to .gitignore. The bootstrap.sh idempotent write of `.gitignore` should NOT clobber an existing one with different content.

## Validator pressure points

The validator will be told to specifically critique:

1. **dispatch.sh tmux resolution** — does `tmux list-clients -F '#{client_activity} #{session_name}'` reliably pick the user's most-recent session? What if zero clients but a session exists? What if multiple clients on different sessions?
2. **dispatch.sh single-flight lock** — does `exec 200>"$LOCK_FILE"; flock -n 200` correctly release if the script crashes mid-run? Is `flock` available on macOS by default? (No, it's Linux-only — needs alternative on macOS.)
3. **dispatch.sh auth preflight** — 5-second timeout against `codex exec` echo: is this fast enough for healthy auth, slow enough to not false-fail under network jitter?
4. **scrub-secrets.sh patterns** — coverage gaps (Slack tokens, Stripe, JWTs without `Bearer`, etc.)? `sk-[A-Za-z0-9]{20,}` over-matches some non-secret strings?
5. **Codex `-c model_reasoning_effort=medium`** — confirmed valid for gpt-5.5? (Yes, per OMX setup writing this exact config.)
6. **Skill instructs Claude to call Bash to run dispatch.sh** — does Claude Code reliably invoke external bash from skill instructions? Yes — skills are prompts; Claude reads them and chooses tools. Validator confirms.
7. **bootstrap.sh ordering** — do the new heredocs need to come before/after specific existing ones? Specifically, the CLAUDE.md and README.md heredocs that get extended.
8. **README/CLAUDE prose accuracy** — does the description correctly capture the dual-harness boundary?
9. **`mkdir -p .claude/lib`** — does the existing bootstrap pattern use `mkdir -p`? (It does — consistent.)
10. **macOS portability** — `flock` doesn't exist on macOS; the timeout binary is `gtimeout` after `brew install coreutils`. Does dispatch.sh need conditional logic?
11. **The `KIT_NO_TMUX=1` fallback** — works when tmux is on PATH but no client attached? Verifies the inline mode renders correctly when piped to a non-tty (Claude Code's Bash tool).
12. **Sandbox choice** — `workspace-write` is correct for execute phase; should validate phase use `read-only` instead? (Yes — see PR1's validate dispatch.)

## Phase sequence

| Phase | Actor | Output |
|---|---|---|
| Plan | Opus 4.7 (this) | `.kit-orchestration/pr2-plan.md` (this file) |
| Validate | Codex gpt-5.5 high (inline — dispatch.sh ships in this PR) | `.kit-orchestration/pr2-validation.md` |
| Reconcile | Opus 4.7 | This plan updated; disagreements documented |
| Execute | Codex gpt-5.5 medium (inline) | Working-tree edits + `.kit-orchestration/pr2-execute-report.md` |
| Smoke test | Opus 4.7 | Run `dispatch.sh validate pr2-smoke gpt-5.5 low <small-prompt>` end-to-end; confirm tmux split behaves correctly |
| Review | Opus 4.7 | Atomic commits, push, gh pr create |

## Manual test checklist (revised after validator — adds portability + ARG_MAX + multi-client tests)

**Static checks**:
- `bash -n .claude/lib/dispatch.sh` — passes.
- `bash -n .claude/lib/scrub-secrets.sh` — passes.
- `shellcheck .claude/lib/dispatch.sh` — clean (or all warnings explained in PR description).
- `shellcheck .claude/lib/scrub-secrets.sh` — clean.
- `[ -x .claude/lib/dispatch.sh ] && [ -x .claude/lib/scrub-secrets.sh ]` — both executable.
- `bash -n bootstrap.sh` — passes.

**Portability tests**:
- With `timeout` only (Linux default): preflight runs, dispatch runs.
- With `gtimeout` only (simulated by `PATH=$(echo $PATH | tr ':' '\n' | grep -v coreutils | paste -sd ':' -)` on Linux to remove GNU coreutils → falls back to `gtimeout` if available; otherwise dies with clear "install coreutils" message). On macOS: same test confirms `gtimeout` is found after `brew install coreutils`.
- With neither: dispatch.sh dies with the install-coreutils message before opening anything.

**Smoke tests** (from inside the user's attached tmux session):
- `bash .claude/lib/dispatch.sh validate smoke gpt-5.5 low <small-prompt-file>` → pane visibly splits in the session, log written, exit 0.
- `KIT_NO_TMUX=1 bash .claude/lib/dispatch.sh ...` → inline output, no tmux pane.
- `KIT_TMUX_SESSION=nonexistent bash .claude/lib/dispatch.sh ...` → warns "set but session does not exist" and falls back to detection.
- **Multi-client test** (validator suggested addition 6): with two attached tmux clients on different sessions, dispatch.sh splits into the most-recent. Override with `KIT_TMUX_SESSION=<other>` and confirm it splits into the named one instead.

**Auth + model preflight tests**:
- Without Codex auth (`mv ~/.codex/auth.json ~/.codex/auth.json.bak`; restore after): preflight fails with the `codex login` / `OPENAI_API_KEY` hint, no pane opened.
- With auth but invalid model (`bash .claude/lib/dispatch.sh validate smoke nonexistent-model low <prompt>`): preflight fails with model-availability error, no pane opened.
- With slow network: `KIT_AUTH_PREFLIGHT_SECONDS=30 bash .claude/lib/dispatch.sh ...` should succeed where the default 15s might false-fail.

**Lock + ARG_MAX tests**:
- Concurrent dispatch: while one is running, second invocation fast-fails with the lock-dir message. `KIT_ALLOW_CONCURRENT=1 bash .claude/lib/dispatch.sh ...` bypasses.
- Lock cleanup: kill dispatch.sh mid-run with SIGKILL (not SIGTERM/INT — those run the trap). Confirm the lock dir remains and the next run fails clearly. After manual `rm -rf .kit-orchestration/.lock`, the next run succeeds. (Documented manual cleanup, not auto.)
- Large prompt: create a 2 MB prompt file (`yes 'x' | head -c 2000000 > /tmp/big-prompt.md`), dispatch with it, confirm Codex receives it via stdin (no `Argument list too long` error).

**Secret scrub tests**:
- `printf 'sk-ant-1234567890123456789012345678901234567890\nghp_123456789012345678901234567890123456789012345\nxoxb-1234567890123456789012345678901234567890\nsk_live_1234567890123456789012345678901234567890\neyJabc.xyz123.def456789012345678901234567890\nBearer 1234567890abcdef1234567890abcdef\nAuthorization: opaque-token-1234567890abcdef\nhttps://user:secret@example.com\nAKIAABCDEFGHIJKLMNOP\n' | bash .claude/lib/scrub-secrets.sh` → all of them redacted.
- Idempotency: pipe the same content through `scrub-secrets.sh` twice; output is identical.
- Non-secret content unchanged: `echo 'commit sha 0123456789abcdef0123456789abcdef01234567 file hash 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' | bash .claude/lib/scrub-secrets.sh` → unchanged (we deliberately don't redact generic hex).

**Bootstrapped output**:
- Run `bash bootstrap.sh` in a clean temp dir.
- All five new files present at correct paths.
- `dispatch.sh` and `scrub-secrets.sh` are executable (`test -x ...`).
- `CLAUDE.md` contains the `/project-execute` row and "Dual-Harness Workflow" section.
- `README.md` contains the "Dual-Harness Mode" section.
- `bash -n bootstrap.sh` still passes.
- `.kit-orchestration/` exists with `.gitignore` containing the PR1 entries (no clobber).

## Operating rules (PR2-specific)

- Codex executor in PR2 must NOT push the branch or merge — Claude pushes after review.
- Codex must NOT modify `.git/`, secrets, CI, or files outside the listed paths.
- Codex must commit changes atomically, one commit per logical unit (matches the PR1 pattern).
- British English in all user-facing prose.
- After CodeRabbit findings: address every valid one, push, repeat until green, then merge with `gh pr merge --merge --delete-branch`.

## Cross-PR ordering

PR2 must merge before PR3. PR3's bootstrap.sh edits and security-review skill design assume `.claude/lib/` exists.

## Reconciliation summary (validator round 1)

Validator returned 7 REJECTs + 12 MINORs + 6 suggested additions. **All accepted.** Notable changes:

| Validator finding | Action |
|---|---|
| REJECT: `timeout`/`flock` not on macOS | Added `kit_timeout` portable wrapper (timeout/gtimeout); replaced flock with mkdir-based lock |
| REJECT: ARG_MAX risk on `"$(cat $PROMPT_FILE)"` | Switched to `- <"$PROMPT_FILE"` stdin pipe |
| REJECT: 5s preflight too tight, no model | Configurable `KIT_AUTH_PREFLIGHT_SECONDS` (default 15s); preflight uses target model |
| REJECT: `git commit` vs `Do not modify .git/` conflict | Clarified: no manual edits to `.git/`, but normal git commits are expected |
| REJECT: tmux resolution not "current Claude terminal" | Documented explicitly; switched to `#{client_session}`; noted detached sessions ignored |
| REJECT: "dispatcher handles secret scrub" misleading | Reworded: dispatcher writes raw logs; scrubbing happens at read-time in the skill |
| MINOR: timestamp 1s collision | Added `$$` PID suffix |
| MINOR: tmux fail warning hidden | Now also written to log file |
| MINOR: scrub-secrets.sh gaps | Added Slack, Stripe, JWT, Authorization-without-Bearer; tightened `sk-` minimum length |
| MINOR: blueprint missing handling | Skill explicitly aborts with `/project-blueprint` instruction |
| MINOR: "auto-invoke /project-review" ambiguous | Reworded: Claude reads project-review/SKILL.md and follows |
| MINOR: ChatGPT vs API-key auth model availability | Documented in CLAUDE.md and README |
| MINOR: "run from inside tmux" too strict | Softened: any attached client works |
| MINOR: bootstrap.sh line refs stale | Corrected to actual ranges (3399-3719, 3726-3777) |
| MINOR: bootstrap.sh insertion grouping | Plan now respects existing groups |
| MINOR: .gitignore PR1 already exists | Idempotent guard; `*-last.md` decision documented (committed, not ignored) |
| MINOR: chmod is a new pattern | Documented as introduced by PR2 |
| Suggested: macOS portability tests | Added to test checklist |
| Suggested: invalid-model preflight test | Added |
| Suggested: large-prompt ARG_MAX test | Added |
| Suggested: kebab-case `$ARGUMENTS` validation | Added to skill prerequisites |
| Suggested: log lifecycle guidance | `*-last.md` policy documented; raw logs gitignored, scrubbed at read |
| Suggested: tmux multi-client test | Added |

**No disagreements with validator.**

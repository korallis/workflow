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
  # The viewer pipes tail through sed that quits on a dispatcher-only sentinel
  # appended after codex finishes. We use __KIT_DISPATCH_EXIT__= rather than a
  # bare EXIT= so a Codex-generated line that happens to start with "EXIT=" (a
  # script, env example, error-code listing) doesn't close the pane early.
  # When sed exits, tail gets SIGPIPE, the pane shell finishes, and tmux
  # closes the pane automatically (remain-on-exit off by default).
  if ! tmux split-window -t "$TMUX_SESSION" "$split_flag" \
        "echo '── kit-orchestration: $PHASE/$ID ──'; tail -f '$LOG_FILE' | sed -n '/^__KIT_DISPATCH_EXIT__=/{p;q;};p'" >/dev/null 2>&1; then
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

echo "__KIT_DISPATCH_EXIT__=$codex_rc" >> "$LOG_FILE"

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

#!/usr/bin/env bash
# .claude/hooks/pre-compact.sh — PreCompact snapshot
#
# Fires before Claude Code compacts the conversation. Reads the hook input
# JSON from stdin (Claude Code provides session_id, transcript_path, trigger,
# custom_instructions, and others) and writes three companion snapshot files
# into specs/sessions/ so context is recoverable post-compaction.
#
# Exit semantics: returns 0 in the happy path. With `set -e` plus `|| true`
# guards, only filesystem errors (e.g. specs/sessions/ unwritable) can produce
# a non-zero exit, which Claude Code surfaces but does NOT block compaction
# on (the hook does not return decision: "block").
#
# Documented limitation: Claude Code issue #13572 reports PreCompact may not
# fire reliably for /compact on some versions. The SessionStart `compact`
# matcher in .claude/settings.json provides a backup recovery path that prints
# the latest snapshot path on session resume.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly OUT_DIR="$REPO_ROOT/specs/sessions"
mkdir -p "$OUT_DIR"

readonly TS="$(date +%Y%m%d-%H%M%S)-$$"

# Read hook input JSON from stdin (best-effort — Claude Code may pipe nothing
# in some configurations). Use jq if available; fall back to cat.
hook_input="$(cat)"

extract() {
  # extract <jq-path> — empty string if jq missing or key absent
  local key="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$hook_input" | jq -r "$key // empty" 2>/dev/null || true
  fi
}

session_id="$(extract '.session_id')"
transcript_path="$(extract '.transcript_path')"
trigger="$(extract '.trigger')"
custom_instructions="$(extract '.custom_instructions')"

# Snapshot 1: plan file (if any plan was active)
if compgen -G "$REPO_ROOT/.kit-orchestration/pr*-plan.md" >/dev/null 2>&1; then
  latest_plan="$(ls -1t "$REPO_ROOT/.kit-orchestration/"pr*-plan.md 2>/dev/null | head -1)"
  if [[ -n "$latest_plan" ]]; then
    {
      echo "# PreCompact snapshot — plan ($TS)"
      echo
      echo "Latest plan: $latest_plan"
      echo "Session: ${session_id:-unknown}"
      echo "Trigger: ${trigger:-unknown}"
      echo
      echo "---"
      cat "$latest_plan"
    } > "$OUT_DIR/$TS-plan.md"
  fi
fi

# Snapshot 2: transcript tail (last 50 lines)
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
  {
    echo "# PreCompact snapshot — transcript tail ($TS)"
    echo
    echo "Source: $transcript_path"
    echo "Session: ${session_id:-unknown}"
    echo "Trigger: ${trigger:-unknown}"
    [[ -n "$custom_instructions" ]] && { echo "Custom instructions: $custom_instructions"; }
    echo
    echo "---"
    tail -n 50 "$transcript_path"
  } > "$OUT_DIR/$TS-transcript-tail.md"
fi

# Snapshot 3: git activity
{
  echo "# PreCompact snapshot — git ($TS)"
  echo
  echo "Branch: $(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)"
  echo
  echo "## Recent commits"
  echo
  git -C "$REPO_ROOT" log --oneline -10 2>/dev/null || true
  echo
  echo "## Working-tree status"
  echo
  git -C "$REPO_ROOT" status --short 2>/dev/null || true
} > "$OUT_DIR/$TS-git.md"

printf 'pre-compact.sh: snapshots written to %s/%s-{plan,transcript-tail,git}.md\n' "$OUT_DIR" "$TS" >&2
exit 0

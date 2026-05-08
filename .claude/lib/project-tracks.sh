#!/usr/bin/env bash
# .claude/lib/project-tracks.sh - parallel module track helper

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PARALLEL_DIR="$REPO_ROOT/.claude/parallel"
TRACKS_FILE="$PARALLEL_DIR/tracks.json"
REGISTRY_LOCK="$PARALLEL_DIR/locks/registry"
MODULES_FILE="$REPO_ROOT/specs/MODULES.md"
PORT_BASE="${KIT_PARALLEL_PORT_BASE:-3000}"
PARALLEL_MAX="${KIT_PARALLEL_MAX:-4}"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warn: %s\n' "$*" >&2; }
info() { printf 'info: %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage:
  project-tracks.sh plan [modules...] [--harness=codex|claude]
  project-tracks.sh start [modules...] [--harness=codex|claude]

The plan command is read-only. The start command creates worktrees and launches
one dispatcher per selected module.
USAGE
}

normalise_module() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9-' '-'
}

parse_args() {
  HARNESS="codex"
  MODULE_ARGS=()
  for arg in "$@"; do
    case "$arg" in
      --harness=codex) HARNESS="codex" ;;
      --harness=claude) HARNESS="claude" ;;
      --harness=*) die "unsupported harness: ${arg#--harness=}" ;;
      --help|-h) usage; exit 0 ;;
      *) MODULE_ARGS+=("$(normalise_module "$arg")") ;;
    esac
  done
}

discover_modules() {
  if (( ${#MODULE_ARGS[@]} > 0 )); then
    printf '%s\n' "${MODULE_ARGS[@]}"
    return 0
  fi

  find "$REPO_ROOT/specs/modules" -mindepth 1 -maxdepth 1 -type d 2>/dev/null \
    | sed 's#.*/##' \
    | sort
}

yaml_version() {
  awk -F ':' '/^[[:space:]]*version[[:space:]]*:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' "$1"
}

yaml_shared_paths() {
  awk '
    /^[[:space:]]*shared[[:space:]]*:/ { in_shared=1; next }
    in_shared && /^[^[:space:]-]/ { in_shared=0 }
    in_shared && /^[[:space:]]*-[[:space:]]*/ {
      sub(/^[[:space:]]*-[[:space:]]*/, "")
      print
    }
  ' "$1"
}

module_line_number() {
  local module="$1"
  if [[ ! -f "$MODULES_FILE" ]]; then
    printf '999999\n'
    return 0
  fi
  # Whole-slug match: a module slug like "auth" must NOT match inside "oauth"
  # or "user-profile". Slug chars are [a-z0-9-]; surrounding chars must be
  # outside that set or line boundaries. Lowercased on both sides for
  # case-insensitivity (replaces the prior IGNORECASE+index() approach).
  awk -v mod="$module" '
    BEGIN {
      m = tolower(mod)
      pat = "(^|[^a-z0-9-])" m "([^a-z0-9-]|$)"
    }
    {
      if (tolower($0) ~ pat) { print NR; found=1; exit }
    }
    END { if (!found) print 999999 }
  ' "$MODULES_FILE"
}

line_has_dependency_between() {
  local module="$1" other="$2"
  [[ -f "$MODULES_FILE" ]] || return 1
  awk -v a="$module" -v b="$other" '
    BEGIN {
      A = tolower(a); B = tolower(b)
      pa = "(^|[^a-z0-9-])" A "([^a-z0-9-]|$)"
      pb = "(^|[^a-z0-9-])" B "([^a-z0-9-]|$)"
      found = 0
    }
    {
      lc = tolower($0)
      if (lc ~ /depend|require|blocked by|after/ && lc ~ pa && lc ~ pb) found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$MODULES_FILE"
}

build_plan() {
  # SPEC §6 mandates "trust parallel.yaml only; no silent heuristics for
  # brownfield". A module without parallel.yaml is refused outright,
  # regardless of repo shape.
  [[ -f "$MODULES_FILE" ]] || die "specs/MODULES.md is absent. Create it first, then add per-module parallel.yaml files before running /project-tracks plan."
  [[ "$PARALLEL_MAX" =~ ^[0-9]+$ ]] || die "KIT_PARALLEL_MAX must be numeric"
  (( PARALLEL_MAX >= 1 )) || die "KIT_PARALLEL_MAX must be at least 1"

  mapfile -t CANDIDATES < <(discover_modules)
  (( ${#CANDIDATES[@]} > 0 )) || die "no modules selected or discovered under specs/modules/"

  # Reject duplicates before they cause merge_order rows, branch reuse, or
  # registry collisions. normalise_module() in discover_modules already
  # lowercases via tr, so case-insensitive compares fall out of equality.
  local _seen=":" _dup=()
  for module in "${CANDIDATES[@]}"; do
    if [[ "$_seen" == *":$module:"* ]]; then
      _dup+=("$module")
    else
      _seen="$_seen$module:"
    fi
  done
  (( ${#_dup[@]} == 0 )) || die "duplicate module(s) in selection: ${_dup[*]}"

  (( ${#CANDIDATES[@]} <= PARALLEL_MAX )) || die "selected ${#CANDIDATES[@]} modules; KIT_PARALLEL_MAX is $PARALLEL_MAX"

  PLAN_MODULES=()
  PLAN_SHARED=()
  local module yaml version
  for module in "${CANDIDATES[@]}"; do
    yaml="$REPO_ROOT/specs/modules/$module/parallel.yaml"
    [[ -f "$yaml" ]] || die "$module: add parallel.yaml or run sequentially"
    version="$(yaml_version "$yaml")"
    [[ "$version" == "1" ]] || die "$module: parallel.yaml must declare version: 1"
    PLAN_MODULES+=("$module")
    while IFS= read -r shared_path; do
      [[ -n "$shared_path" ]] && PLAN_SHARED+=("$module:$shared_path")
    done < <(yaml_shared_paths "$yaml")
  done

  local i j a b
  for (( i=0; i<${#PLAN_MODULES[@]}; i++ )); do
    for (( j=i+1; j<${#PLAN_MODULES[@]}; j++ )); do
      a="${PLAN_MODULES[$i]}"
      b="${PLAN_MODULES[$j]}"
      if line_has_dependency_between "$a" "$b" || line_has_dependency_between "$b" "$a"; then
        die "cannot parallelise $a and $b: dependency edge found in specs/MODULES.md"
      fi
    done
  done

  local seen_module seen_path entry module_path other_entry other_module other_path
  for entry in "${PLAN_SHARED[@]}"; do
    seen_module="${entry%%:*}"
    seen_path="${entry#*:}"
    for other_entry in "${PLAN_SHARED[@]}"; do
      other_module="${other_entry%%:*}"
      other_path="${other_entry#*:}"
      [[ "$seen_module" == "$other_module" ]] && continue
      if [[ "$seen_path" == "$other_path" ]]; then
        die "cannot parallelise $seen_module and $other_module: shared path collision on $seen_path"
      fi
    done
  done

  mapfile -t PLAN_MODULES < <(
    for module in "${PLAN_MODULES[@]}"; do
      printf '%06d %s\n' "$(module_line_number "$module")" "$module"
    done | sort -n | awk '{print $2}'
  )
}

print_plan() {
  build_plan
  printf 'Parallel track proposal\n'
  printf 'Harness: %s\n' "$HARNESS"
  printf 'Limit: %s\n' "$PARALLEL_MAX"
  printf 'Merge order:\n'
  local idx=1 module yaml shared
  for module in "${PLAN_MODULES[@]}"; do
    yaml="$REPO_ROOT/specs/modules/$module/parallel.yaml"
    printf '  %d. %s\n' "$idx" "$module"
    printf '     parallel.yaml: %s\n' "${yaml#$REPO_ROOT/}"
    shared="$(yaml_shared_paths "$yaml" | paste -sd ', ' -)"
    [[ -n "$shared" ]] && printf '     shared: %s\n' "$shared"
    idx=$((idx + 1))
  done
}

json_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

with_registry_lock() {
  # Acquires the mkdir-based lock. The CALLER must install the RETURN trap
  # so the lock survives until the caller's critical section completes —
  # installing the trap inside this helper would release the lock the
  # moment with_registry_lock returns (i.e. before TRACKS_FILE is written).
  mkdir -p "$PARALLEL_DIR/locks"
  local waited=0
  until mkdir "$REGISTRY_LOCK" 2>/dev/null; do
    waited=$((waited + 1))
    (( waited <= 30 )) || die "timed out waiting for registry lock at $REGISTRY_LOCK"
    sleep 1
  done
}

ensure_registry() {
  mkdir -p "$PARALLEL_DIR/locks" "$PARALLEL_DIR/learnings"
  if [[ ! -f "$TRACKS_FILE" ]]; then
    printf '{"tracks": [], "merge_order": [], "harness": null}\n' > "$TRACKS_FILE"
  fi
}

append_registry_entry() {
  local module="$1" branch="$2" worktree="$3" harness="$4" port="$5" pid="$6" started="$7"
  ensure_registry
  with_registry_lock
  trap 'rm -rf "$REGISTRY_LOCK"' RETURN

  local id escaped_worktree tmp
  id="track-$module-${started//[^0-9]/}"
  escaped_worktree="$(json_string "${worktree#$REPO_ROOT/}")"
  tmp="$(mktemp)"
  local object
  object="{\"id\":\"$id\",\"module\":\"$module\",\"branch\":\"$branch\",\"worktree\":\"$escaped_worktree\",\"harness\":\"$harness\",\"port\":$port,\"status\":\"running\",\"started\":\"$started\",\"last_commit\":\"\",\"pid\":$pid}"

  if command -v jq >/dev/null 2>&1; then
    jq --argjson track "$object" --arg module "$module" --arg harness "$harness" '
      .tracks += [$track]
      | .merge_order += [$module]
      | .harness = (.harness // $harness)
    ' "$TRACKS_FILE" > "$tmp"
  else
    awk -v object="$object" -v module="$module" -v harness="$harness" '
      {
        line=$0
        if (line ~ /"tracks"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/) {
          sub(/"tracks"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/, "\"tracks\": [" object "]", line)
        } else {
          sub(/"tracks"[[:space:]]*:[[:space:]]*\[/, "\"tracks\": [" object ",", line)
        }
        if (line ~ /"merge_order"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/) {
          sub(/"merge_order"[[:space:]]*:[[:space:]]*\[[[:space:]]*\]/, "\"merge_order\": [\"" module "\"]", line)
        } else {
          sub(/"merge_order"[[:space:]]*:[[:space:]]*\[/, "\"merge_order\": [\"" module "\",", line)
        }
        sub(/"harness"[[:space:]]*:[[:space:]]*null/, "\"harness\": \"" harness "\"", line)
        print line
      }
    ' "$TRACKS_FILE" > "$tmp"
  fi
  mv "$tmp" "$TRACKS_FILE"
}

copy_worktree_includes() {
  local worktree="$1" include_file="$REPO_ROOT/.worktreeinclude" entry
  [[ -f "$include_file" ]] || return 0
  while IFS= read -r entry; do
    [[ -z "$entry" || "$entry" == \#* ]] && continue
    if [[ -e "$REPO_ROOT/$entry" ]]; then
      mkdir -p "$worktree/$(dirname "$entry")"
      cp -R "$REPO_ROOT/$entry" "$worktree/$entry"
    fi
  done < "$include_file"
}

write_track_prompt() {
  local module="$1" prompt_file="$2"
  cat > "$prompt_file" <<EOF
# Parallel track dispatch: $module

Implement only the $module module in this isolated worktree.

Read:
- specs/modules/$module/SPEC.md
- specs/modules/$module/CLAUDE.md
- CLAUDE.md

Respect parallel track constraints:
- Do not edit root LEARNINGS.md directly. Write track learnings as a markdown fragment to `.claude/parallel/learnings/$module.md`; the integrator merges fragments after merge.
- Do not edit root CLAUDE.md from a track; root CLAUDE.md updates are the integrator's job after merge.
- Use PORT and KIT_PARALLEL_PORT for any dev server.
- Stay within the module scope and its declared parallel.yaml paths.
EOF
}

start_tracks() {
  build_plan
  ensure_registry
  mkdir -p "$REPO_ROOT/.claude/worktrees" "$REPO_ROOT/.kit-orchestration/tracks"

  local idx=1 module branch worktree port started ts prompt_dir prompt_file pid rc
  for module in "${PLAN_MODULES[@]}"; do
    branch="track/$module"
    worktree="$REPO_ROOT/.claude/worktrees/track-$module"
    port=$((PORT_BASE + idx))
    started="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    # ONE timestamp per track. Used for the per-track prompt directory AND
    # exported as KIT_DISPATCH_TS so the dispatcher's log/jsonl/report
    # filenames share the same <TS>-<module> identifier. Without this, the
    # orchestrator's advertised paths drift from what dispatch.sh writes
    # (CodeRabbit finding on PR #7).
    ts="$(date +%Y%m%d-%H%M%S)"

    if [[ ! -d "$worktree/.git" && ! -f "$worktree/.git" ]]; then
      if git show-ref --verify --quiet "refs/heads/$branch"; then
        git worktree add "$worktree" "$branch"
      else
        git worktree add "$worktree" -b "$branch"
      fi
    else
      info "$module: reusing existing worktree $worktree"
    fi

    copy_worktree_includes "$worktree"

    prompt_dir="$REPO_ROOT/.kit-orchestration/tracks/${ts}-${module}"
    mkdir -p "$prompt_dir"
    prompt_file="$prompt_dir/dispatch-prompt.md"
    write_track_prompt "$module" "$prompt_file"

    case "$HARNESS" in
      codex)
        # KIT_PARALLEL_TRACK already namespaces the dispatcher's lock by
        # module — KIT_ALLOW_CONCURRENT=1 here would *disable* that lock,
        # letting a second launch of the same module race in the same
        # worktree. The per-track lock is the right granularity.
        (
          cd "$worktree"
          KIT_DISPATCH_TS="$ts" \
          KIT_PARALLEL_TRACK="$module" \
          KIT_PARALLEL_PORT="$port" \
          PORT="$port" \
          bash "$worktree/.claude/lib/dispatch.sh" execute "$module" gpt-5.5 medium "$prompt_file"
        ) > "$prompt_dir/launcher.log" 2>&1 &
        pid=$!
        ;;
      claude)
        command -v claude >/dev/null 2>&1 || die "claude CLI not found on PATH"
        (
          cd "$worktree"
          KIT_DISPATCH_TS="$ts" KIT_PARALLEL_TRACK="$module" KIT_PARALLEL_PORT="$port" PORT="$port" \
          claude -w "track-$module" < "$prompt_file"
        ) > "$prompt_dir/launcher.log" 2>&1 &
        pid=$!
        ;;
      *) die "unsupported harness: $HARNESS" ;;
    esac

    # Register the spawned process in tracks.json. If the registry write
    # fails (lock timeout, JSON corruption), the backgrounded child is
    # otherwise unmanaged — kill and reap it before bubbling the error up,
    # so /project-tracks status/cleanup don't lose track of it.
    set +e
    append_registry_entry "$module" "$branch" "$worktree" "$HARNESS" "$port" "$pid" "$started"
    rc=$?
    set -e
    if (( rc != 0 )); then
      warn "registry write failed for $module (pid $pid); cleaning up spawned child"
      kill -TERM "$pid" 2>/dev/null || true
      # Give it 2s to exit cleanly, then SIGKILL.
      for _ in 1 2; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 1
      done
      kill -KILL "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      die "failed to register $module in tracks.json (exit $rc); spawned child reaped"
    fi
    printf 'started %s on %s (port %s, pid %s)\n' "$module" "$branch" "$port" "$pid"
    idx=$((idx + 1))
  done
}

main() {
  (( $# >= 1 )) || { usage; exit 1; }
  local command="$1"
  shift
  parse_args "$@"

  case "$command" in
    plan) print_plan ;;
    start) start_tracks ;;
    *) usage; exit 1 ;;
  esac
}

main "$@"

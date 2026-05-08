# parallel-tracks — Parallel Module Implementation

> **Status:** Draft (decisions ratified 2026-05-08)
> **Owner:** Lee Barry
> **Last updated:** 2026-05-08
> **Depends on:** MASTER_BLUEPRINT §5 (dual-harness contract), §6 (isolation pattern)

## 1. Purpose

Extend the kit so multiple independent modules from `specs/MODULES.md` can be implemented **in parallel**, each in its own git worktree, while preserving the kit's core principles: spec-first, single-task-per-session (now per-*track*), compound learning, isolated review.

The kit currently runs strictly sequential: one `/project-execute` at a time, gated by the dispatcher's single-flight lock. With Claude Code's native `--worktree` flag, native subagent worktree isolation, and the dispatcher already supporting `KIT_ALLOW_CONCURRENT=1`, the primitives exist — what's missing is an orchestrating command, a coordination model, and a merge sequencer.

## 2. User stories

| ID | As a... | I want to... | So that... |
|---|---|---|---|
| PT-1 | Solo dev with 4 specced modules | Spawn 2–4 tracks at once, each on its own branch | I'm not idle while one Codex is implementing |
| PT-2 | Reviewer | See a dashboard of all live tracks (branch, status, last commit) | I can review on the 20-minute tick rather than guessing |
| PT-3 | Spec author | Have the kit refuse to parallelise modules that share files | Merge conflicts are prevented at the boundary, not at merge time |
| PT-4 | Operator | Have ports/DBs/learnings auto-isolated per track | Tracks don't fight over `:3000`, migrations, or `LEARNINGS.md` |
| PT-5 | Integrator | Merge tracks back in dependency order with linear history | Foundation modules land before dependents; `git log` stays clean |
| PT-6 | Future Claude session | Inherit *all* tracks' learnings after integration | Compound learning isn't fragmented across worktrees |

## 3. Artefact model

```text
your-project/
├── .claude/
│   ├── worktrees/                          ← Claude Code-managed (existing)
│   │   ├── track-auth/                     module-named worktree
│   │   ├── track-billing/
│   │   └── …
│   └── parallel/                           ← new
│       ├── tracks.json                     active-track registry (status, branch, pid, port, started-at)
│       ├── locks/                          per-resource locks (per-track + global migrations lock)
│       └── learnings/                      per-track learning fragments awaiting merge
├── .worktreeinclude                        gitignored files copied into each worktree (.env, .env.local)
├── specs/
│   └── modules/<name>/
│       ├── SPEC.md
│       ├── CLAUDE.md
│       └── parallel.yaml                   ← new (optional): touches:, shared:, ports:, migrations:
└── .kit-orchestration/
    └── tracks/<TS>-<module>/               per-track plan + scrubbed log (gitignored)
```

**`tracks.json` shape** (single source of truth for active parallelism):

```json
{
  "tracks": [
    {
      "id": "track-auth-2026050801",
      "module": "auth",
      "branch": "track/auth",
      "worktree": ".claude/worktrees/track-auth",
      "harness": "codex",
      "port": 3001,
      "status": "running",
      "started": "2026-05-08T12:34:56Z",
      "last_commit": "a1b2c3d",
      "pid": 12345
    }
  ],
  "merge_order": ["auth", "billing", "notifications"],
  "harness": "codex"
}
```

Valid `status` values: `pending`, `running`, `completed`, `timeout`, `aborted`. `aborted` is set by the sentinel-watcher when an operator kills the tmux pane mid-track (see §6).

**`specs/modules/<name>/parallel.yaml`** (per-module collision hints — **per-module is the canonical location**, not root-level, so module owners own their parallelism declarations):

```yaml
version: 1               # schema version; planner branches on this when the schema breaks
touches:
  - src/auth/**
  - src/db/schema/auth.ts
shared:                  # paths this track edits that may collide with other tracks
  - src/types/user.ts
ports:
  - 3001                 # required dev-server port (orchestrator reserves)
migrations: true         # if true, takes the global migrations lock
```

The planner rejects files without a `version` field. When v2 ships, `version: 1` files keep working under the v1 codepath; new fields land under `version: 2`.

## 4. Command surface

### New commands

| Command | Purpose |
|---|---|
| `/project-tracks plan [--harness=codex\|claude]` | Read `MODULES.md` + per-module `parallel.yaml`; print proposed track set + merge order. No side effects. |
| `/project-tracks start [modules…] [--harness=codex\|claude]` | Spawn N tracks (default: all parallelisable from `plan`). Creates worktrees, reserves ports, spawns dispatchers in tmux panes. **All tracks in a session use the same harness** (default `codex`). |
| `/project-tracks status` | Dashboard: each track's branch, status, last commit, pane id. |
| `/project-tracks review <module>` | Run `/project-review --isolate` against the track's diff. |
| `/project-tracks merge` | Merge in dependency order, rebasing each track onto main. **Stops at local merge** — does not push or open PRs. Halts at first conflict for human resolution. |
| `/project-tracks cleanup` | Remove finished worktrees; retain branches for the operator's existing PR flow. |

### Changes to existing commands

- `/project-execute <module> --track` — per-track entry point used internally by `start`. Same as `/project-execute` but assumes it's running inside a worktree, takes its dispatcher lock from `.claude/parallel/locks/<module>/` instead of the global lock, and writes its log under `.kit-orchestration/tracks/<TS>-<module>/`.
- `/project-review` — when run from the root after `merge`, fans out to gather each track's `learnings/<module>.md` fragment and merges them into root `LEARNINGS.md` in dependency order.
- `/project-status` — adds a "Tracks" section showing live tracks if any.

## 5. Track lifecycle

```text
plan          — root reads MODULES.md, picks parallelisable set
                (no dependency edges between picked modules; no shared paths
                in parallel.yaml; total <= KIT_PARALLEL_MAX, default 4).
                Refuses any module without parallel.yaml — prints
                `add parallel.yaml or run sequentially`. (See §6.)
   │
   ▼
start         — for each track:
   │            git worktree add .claude/worktrees/track-<module> -b track/<module>
   │            copy .worktreeinclude entries (.env, .env.local, …)
   │            reserve port slot (KIT_PARALLEL_PORT_BASE + index)
   │            register in .claude/parallel/tracks.json
   │            spawn tmux pane (split into attached client; same logic as dispatch.sh)
   │            launch dispatcher with KIT_ALLOW_CONCURRENT=1, KIT_PARALLEL_TRACK=<module>,
   │            and the session-wide harness selection
   ▼
running       — each track's dispatcher runs the chosen harness against the module's
                SPEC.md and CLAUDE.md. Pane streams output. Sentinel-based teardown
                when a track finishes.
   │
   ▼
review        — root pulls each track's commits (git fetch from worktree branches),
                runs /project-review --isolate per track, captures fragments to
                .claude/parallel/learnings/<module>.md
   │
   ▼
merge         — sort tracks by dependency (foundation first); for each:
                  git rebase main (in the worktree)
                  git merge --no-ff track/<module> --into main (locally)
                  run /project-test on main
                  merge LEARNINGS fragment into root LEARNINGS.md
                stop at first conflict with clear hand-back to human.
                **Does not push or open PRs** — operator's existing workflow takes over.
   │
   ▼
cleanup       — git worktree remove for each finished track
                preserve branches for operator's PR flow
                clear tracks.json
```

## 6. Coordination model

**What's shared, what's isolated.**

| Resource | Isolation strategy |
|---|---|
| Filesystem (working tree) | Per-worktree (git native) |
| Branch | Per-track (`track/<module>`) |
| Dev-server port | Per-track (`KIT_PARALLEL_PORT_BASE + index`, default 3000+i) |
| Dispatcher single-flight lock | Per-track lock dir under `.claude/parallel/locks/<module>/` |
| `node_modules` / build outputs | **Per-worktree.** Each worktree gets a fresh install. ~100MB+ disk per track is the documented cost. No shared store linking in v1 — the shared-state risk outweighs the disk savings. |
| `.env`, `.env.local`, OAuth tokens | Copied into each worktree via `.worktreeinclude` |
| Database migrations | **Global lock** — `.claude/parallel/locks/migrations/`. A track that declares `migrations: true` in `parallel.yaml` blocks others until it commits the migration. |
| Shared types (`src/types/**`) | Tracks declaring `shared:` paths in `parallel.yaml` are **serialised** by the planner — `plan` refuses to put two such tracks in the same parallel set. |
| `LEARNINGS.md` | Append-only fragments per track in `.claude/parallel/learnings/`; integrator merges at the end. Never edited by tracks directly. |
| `CLAUDE.md` (root) | **Read-only inside tracks.** Updates are queued as fragments and merged at integration. |

**Brownfield collision detection.** The planner does not heuristically scan git history for migrations or shared paths. If a module has no `parallel.yaml`, the planner refuses to include it in a parallel set and prints `add parallel.yaml or run sequentially`. Explicit beats implicit; a heuristic that's silently wrong is worse than no heuristic.

**Pre-flight collision detection.** Not done. The kit does not run a background `git diff` between in-flight tracks to surface emerging conflicts. v1 relies on `parallel.yaml` declarations and the operator's 20-min review tick. Revisit only if real-world use shows late-detected conflicts are common.

**Operator-killed track (pane death).** When the operator kills a tmux pane mid-track (Ctrl-d, `tmux kill-pane`, terminal close), a sentinel-watcher detects the missing pid and marks the track `aborted` in `tracks.json`. **The branch and worktree are preserved** so partial work is recoverable. `cleanup` is not automatic — the operator must run it explicitly when they're done inspecting the aborted track. This matches the kit's "never delete user work" principle.

**Merge order.** Topological sort over the dependency graph in `MODULES.md`; ties broken by track creation time. The first conflict halts the chain — root prints the conflicting paths, the offending track's branch, and a `git mergetool` invocation. No automatic conflict resolution.

**Failure modes & mitigations.**

| Failure | Mitigation |
|---|---|
| Track A and B both edit `src/types/user.ts` despite plan check | Late-detected on rebase; `merge` stops; human resolves. Future improvement: pre-flight `git diff` between in-flight tracks every 20 min. |
| Track exceeds `KIT_CODEX_TIMEOUT` | Dispatcher kills it (existing behaviour); `tracks.json` flips to `timeout`; pane stays open for inspection. |
| `npm install` in two worktrees corrupts shared cache | Each worktree gets its own `node_modules`. Documented disk cost. |
| Migrations race | Global migrations lock; first to acquire wins; others wait or skip. |
| Compound learning fragments conflict | Integrator's job (same role as merge conflicts); fragments are markdown, trivial to manually resolve. |
| Operator forgets to clean up | `cleanup` is idempotent; `parallel-tracks plan` warns on stale entries in `tracks.json`. |

## 7. Dispatcher changes (`.claude/lib/dispatch.sh`)

Minimal, additive:

- New env: `KIT_PARALLEL_TRACK=<module>` — when set, lock dir resolves to `.claude/parallel/locks/<module>/` instead of the global lock; log path includes track id; sentinel filename includes track id; tmux pane title prefixed with `[track:<module>]`.
- `KIT_ALLOW_CONCURRENT=1` is set automatically by `start` (operator doesn't need to know).
- New env: `KIT_PARALLEL_PORT` — exported into the executor environment so build/dev tooling picks up the right port.
- `tmux split` direction defaults to `vertical` for tracks (denser dashboard); horizontal for single-harness as today.

No breaking changes. A non-track invocation behaves identically to today.

## 8. Integration points

| Module / file | Relationship | Notes |
|---|---|---|
| `MASTER_BLUEPRINT.md` §5 (dual-harness contract) | **Depends on** | Each track is one dispatcher invocation; the dual-harness contract is unchanged per track. |
| `MASTER_BLUEPRINT.md` §6 (isolation pattern) | **Depends on** | `/project-tracks review` reuses the Explore-subagent isolation pattern. |
| `.claude/lib/dispatch.sh` | **Modifies** | New env vars; per-track lock dir; tmux split direction. |
| `/project-execute` | **Extends** | Adds `--track` flag; otherwise unchanged. |
| `/project-review`, `/project-status` | **Extends** | Tracks-aware sections; no breaking changes. |
| `/project-init` | **Indirect** | Could emit `parallel.yaml` stubs alongside SPEC.md (future). |
| Claude Code `--worktree` flag | **Uses** | When the chosen harness is Claude (single-harness mode), tracks invoke `claude -w track-<module>`. |
| `.worktreeinclude` | **Uses** | Existing Claude Code mechanism for copying gitignored files. |

## 9. Acceptance criteria

- [ ] `/project-tracks plan` correctly identifies parallelisable modules (no dependency edges; no `shared:` collisions; `parallel.yaml` present) and refuses unsafe sets.
- [ ] `/project-tracks start auth billing` creates two worktrees, two tmux panes, and two running dispatchers in <30s on a warm machine.
- [ ] All tracks in a session run the same harness (`codex` or `claude`), selected via `--harness` flag, default `codex`.
- [ ] Each track's dispatcher uses its own lock dir; the global single-flight lock is unaffected.
- [ ] Each track's dev server can run on a unique port (`PORT` and `KIT_PARALLEL_PORT` env exported correctly).
- [ ] Tracks fail independently — one Codex timeout does not affect siblings.
- [ ] `/project-tracks status` shows accurate live state including branch, last commit, port, and pane id.
- [ ] `/project-tracks review <module>` runs the existing isolated-Explore review against only the track's diff.
- [ ] `/project-tracks merge` applies tracks in dependency order, rebases each onto main, halts on first conflict, and prints actionable resolution steps. Does not push or open PRs.
- [ ] `LEARNINGS.md` after `merge` contains a coherent merge of all tracks' fragments — no duplicate sections, dependency-ordered.
- [ ] `cleanup` removes worktrees but preserves branches for the operator's PR flow.
- [ ] Brownfield modules without `parallel.yaml` are refused by `plan` with a clear message.
- [ ] All existing single-harness behaviour unchanged when no track flags are set (regression test).
- [ ] Operating model in `CLAUDE.md` updated to reflect "one *track* = one task" without breaking "one session = one task" for non-parallel users.

## 10. Out of scope

- Cross-machine parallelism (everything is local; no scheduler).
- Multiple Claude/Codex implementations of the **same** module (winner-picking). Out of scope permanently — not a parallelism shape this kit supports. No forward-compat namespace reservation.
- A GUI dashboard. tmux + `tracks.json` is the operator surface.
- Auto-resolution of merge conflicts. Human integrator is required.
- Auto-detection of `shared:` paths or migration changes. Operator declares them in `parallel.yaml`; planner trusts.
- Auto-push or auto-PR on merge. Stops at local merge; operator's existing PR workflow takes over.
- Pnpm/yarn shared content-addressed store linking. Each worktree gets its own `node_modules` in v1.
- Per-track harness mixing (e.g. one track on Codex, another on Claude). Whole session uses one harness.
- Inter-track messaging (e.g. coditect-style pub/sub bus). Tracks are independent by design.
- More than 4 tracks. Hard cap (`KIT_PARALLEL_MAX`, default 4) reflects the production-experience finding that review backlog dominates past 4.
- Non-git VCS support. Git only.

## 11. Decisions ratified (2026-05-08)

These were the open questions during drafting; the operator chose the recommended answer for each.

**Round 1 — design boundaries:**

| # | Question | Decision |
|---|---|---|
| 1 | Auto-PR on `merge`? | **Stop at local merge.** Operator's existing PR flow takes over. Matches the kit's local-first principle and the maintainer's "I review and merge PRs" workflow. |
| 2 | `parallel.yaml` location? | **Per-module** (`specs/modules/<name>/parallel.yaml`). Module owners own their parallelism declarations. |
| 3 | Share `node_modules` via pnpm? | **No, each worktree gets its own.** Disk cost is documented; shared-state risk outweighs savings in v1. |
| 4 | Brownfield migrations detection? | **Trust `parallel.yaml` only.** Planner refuses modules without one and prompts the operator to add it. No silent heuristics. |
| 5 | Mixed harnesses per session? | **Single harness per session** via `--harness` flag (default `codex`). Mixing deferred. |

**Round 2 — operational details:**

| # | Question | Decision |
|---|---|---|
| 6 | Tunable parallel cap location? | **Env var only** (`KIT_PARALLEL_MAX`, default 4). Not surfaced in `.claude/settings.json` — keeps parallelism config out of where it would invite cargo-culting higher numbers. |
| 7 | Auto pre-flight collision detection? | **No.** Trust `parallel.yaml` + operator review on the 20-min tick. Revisit only if real-world use shows late-detected conflicts are common. |
| 8 | Track kill (pane death) semantics? | **Mark `aborted`, preserve branch + worktree, no auto-cleanup.** Operator runs `cleanup` explicitly when ready. |
| 9 | Multi-track-per-module (winner-pick)? | **Permanently out of scope.** Not a parallelism shape the kit supports. No forward-compat namespace reservation. |
| 10 | `parallel.yaml` schema versioning? | **Add `version: 1` now.** Cheap forward-compat; planner branches on version when the schema breaks. Files without `version` are rejected. |

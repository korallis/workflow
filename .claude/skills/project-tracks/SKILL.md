---
name: project-tracks
description: Plan and start isolated parallel module implementation tracks from specs/MODULES.md and per-module parallel.yaml declarations.
effort: high
---

# /project-tracks

Parallel module implementation command. Stage 1 supports:

- `/project-tracks plan [modules...] [--harness=codex|claude]`
- `/project-tracks start [modules...] [--harness=codex|claude]`

Use the helper script for deterministic parsing and side effects:

```bash
bash .claude/lib/project-tracks.sh plan "$ARGUMENTS"
bash .claude/lib/project-tracks.sh start "$ARGUMENTS"
```

## Plan

Run:

```bash
bash .claude/lib/project-tracks.sh plan [modules...] [--harness=codex|claude]
```

Requirements enforced by the helper:

- `specs/MODULES.md` must exist, otherwise print clear guidance.
- Each selected module must have `specs/modules/<module>/parallel.yaml`.
- `parallel.yaml` must declare `version: 1`.
- Selected modules must not have dependency edges between each other in `specs/MODULES.md`.
- Selected modules must not declare the same `shared:` path.
- Total selected modules must be `<= KIT_PARALLEL_MAX` (default 4).
- Missing `parallel.yaml` prints `add parallel.yaml or run sequentially`.

`plan` is read-only. It prints a proposal and does not create worktrees,
registry entries, locks, panes, logs, or branches.

## Start

Run:

```bash
bash .claude/lib/project-tracks.sh start [modules...] [--harness=codex|claude]
```

`start` reuses the same validation as `plan`, then for each selected module:

1. Creates `.claude/worktrees/track-<module>` on branch `track/<module>`.
2. Copies files listed in `.worktreeinclude` when they exist.
3. Reserves `KIT_PARALLEL_PORT_BASE + index` (default `3000 + index`).
4. Appends a running entry to `.claude/parallel/tracks.json` under a mkdir lock.
5. Launches the selected harness in the worktree.

All tracks in one invocation use the same harness. Default harness is `codex`.

For Codex tracks, the helper launches `.claude/lib/dispatch.sh` with:

```bash
KIT_ALLOW_CONCURRENT=1
KIT_PARALLEL_TRACK=<module>
KIT_PARALLEL_PORT=<reserved-port>
PORT=<reserved-port>
```

For Claude tracks, the helper uses `claude -w track-<module>` when the Claude
CLI is available.

# parallel-tracks — Implementation guide

Per-module CLAUDE.md for the parallel-tracks feature. Read alongside `SPEC.md` and the root `CLAUDE.md`.

## Implementation order

1. **Bootstrap additions** — extend `bootstrap.sh` to emit `.claude/parallel/`, a default `.worktreeinclude` (`.env`, `.env.local`, `.dev.vars`), and a `parallel.yaml` template inside `module-spec-template.md`.
2. **Dispatcher per-track lock** — smallest change with biggest leverage. Land `KIT_PARALLEL_TRACK` env var support in `.claude/lib/dispatch.sh`; verify `KIT_ALLOW_CONCURRENT=1` works end-to-end with two tracks.
3. **`/project-tracks plan`** — pure read-only planner over `MODULES.md` + per-module `parallel.yaml`. No worktree side effects yet. Refuses brownfield modules without `parallel.yaml`.
4. **`/project-tracks start`** — wires `plan` → `git worktree add` → tmux split → dispatcher invocation. Takes `--harness=codex|claude` (default `codex`); whole session uses one harness. tmux logic copied from existing `dispatch.sh`.
5. **`tracks.json` registry** — append/update on lifecycle transitions. Use mkdir-based locking (same convention as the dispatcher) to avoid races. Status values: `pending`, `running`, `completed`, `timeout`, `aborted`.
6. **Sentinel-watcher / abort handling** — detect operator-killed panes (missing pid) and flip the track to `aborted`. Branch + worktree preserved; cleanup is explicit.
7. **`/project-tracks status`** — read-only dashboard.
8. **`/project-tracks review`** — wraps existing `/project-review --isolate` with track diff scoping.
9. **`/project-tracks merge`** — dependency sort + rebase + per-track test. Stops at local merge; does not push or open PRs. Most failure-prone step; ship it last and iterate.
10. **Compound learnings merge** — fragment files + integrator-side merge. Last because it depends on `merge` working.
11. **Cleanup** — `git worktree remove` + `tracks.json` clear; preserves branches.

Each step is its own PR. Steps 1–4 should be safe to land before 5–11 ship.

## Key patterns

- **Lock dirs are mkdir, not flock.** Match the existing dispatcher convention. Portable across Linux/macOS without extra deps.
- **tmux pane discovery uses `list-clients`.** Same heuristic as `dispatch.sh` — find the most-recent attached client. Don't introduce a second mechanism.
- **Sentinels are per-track.** `<TS>-<module>.done` filename. Pane reads sentinel and self-closes.
- **Logs are scrubbed on the read path only.** Tracks write raw logs; root reads through `scrub-secrets.sh` exactly like single-harness today.
- **Branches use `track/<module>` not `worktree-<module>`.** Distinguish kit-managed parallel tracks from ad-hoc Claude Code worktrees.
- **One harness per session.** `start --harness=…` is set once and recorded in `tracks.json`. Don't add per-track overrides.
- **`parallel.yaml` requires `version: 1`.** Planner rejects files without it. The version field exists so a future breaking change can branch in the parser without forking filenames.
- **`KIT_PARALLEL_MAX` is env-var-only.** Don't read it from `.claude/settings.json` — keeping parallelism config out of settings is deliberate.
- **Operator-killed pane → `aborted`, never auto-cleanup.** Branch and worktree stay until the operator runs `cleanup`. Treat partial work as recoverable user data.

## Gotchas seen in research

- **Port collisions** are the most common silent failure. Always export `PORT` and `KIT_PARALLEL_PORT` before spawning the dispatcher.
- **`.env` files don't auto-copy** into worktrees. `.worktreeinclude` is mandatory; bootstrap creates a sensible default.
- **`CLAUDE.md` updates inside a track don't propagate** to siblings until merge. Document loudly. Tracks should not edit root `CLAUDE.md`; that's the integrator's job.
- **`git log` confusion** — Claude reasoning over history is much better with linear chains. Force rebase on merge; reject merge commits inside tracks.
- **`node_modules` cost** — `npm install` per worktree is real overhead (~100MB+ each). Documented; no shared-store linking in v1.
- **DB migrations** — only one track at a time. Global lock; serialise; `parallel.yaml: migrations: true` declares.
- **Shared types refactors** are the worst case — tracks declare `shared:` and the planner serialises them. If a refactor is unavoidable, do it on `main` first, *then* spawn parallel tracks.
- **Brownfield modules without `parallel.yaml`** are refused outright. No heuristic guessing.

## Testing

- **Unit-ish:** shellcheck on dispatcher changes; bats tests for plan/start/cleanup.
- **Integration:** spawn two tracks in a sandbox repo, verify isolation (port, branch, lock), verify merge order, verify `LEARNINGS.md` merge.
- **Regression:** existing single-harness `/project-execute` flow must be byte-identical when no track flags are set.

## Acceptance hand-off

When all SPEC §9 acceptance criteria pass, run:
1. `/project-test` (kit's own test pass).
2. `/project-security-review` against the diff (especially the dispatcher and lock changes).
3. `/project-review --isolate` for an unbiased code-review pass.

Then commit `MASTER_BLUEPRINT.md` updates: §4 adds the `/project-tracks` command; §5 dispatcher contract gains `KIT_PARALLEL_TRACK` env; §6 isolation pattern note that tracks reuse the Explore subagent.

## Stage 1 implementation notes (2026-05-08)

Steps 1–4 landed on `feat/parallel-tracks` as commits `b4ce278` and `a1bb3a3`. Notes for stage 2:

- `dispatch.sh` per-track changes are additive — `KIT_PARALLEL_TRACK` unset = byte-identical legacy behaviour (verified). Don't refactor the legacy path during stage 2.
- `.claude/lib/project-tracks.sh` carries both `plan` and `start` in one helper. The registry-lock function uses `trap … RETURN` (bash-only); fine because the helper has a bash shebang. Don't bolt on additional traps without considering interaction.
- `.claude/parallel/tracks.json` is initialised as `{"tracks": [], "merge_order": [], "harness": null}` by both `bootstrap.sh` and `ensure_registry()` — keep them in sync if the schema gains fields.
- `is_brownfield_repo()` in `project-tracks.sh` is currently dead code (both branches die with the same message). Stage 2 cleanup: delete it, since the spec mandates trusting `parallel.yaml` only.
- `start` writes a minimal per-track dispatch prompt at `.kit-orchestration/tracks/<TS>-<module>/dispatch-prompt.md`. Stage 2's `status` and `review` commands should read from the same per-track directory.
- Codex couldn't commit (sandbox blocked `.git/index.lock`); the orchestrator committed instead. Future stages can either bump `KIT_CODEX_SANDBOX=danger-full-access` for the run, or keep the orchestrator-commits pattern (which gives a verification gate — see `LEARNINGS.md` 2026-05-08).

## References

- Claude Code worktree docs: https://code.claude.com/docs/en/worktrees
- Production setup study (the 4-session ceiling): https://www.codewithseb.com/blog/parallel-claude-code-sessions-git-worktrees-guide
- Reference implementations consulted: parallel-code (johannesjo), maniple (mzdbxqh), oh-my-codex, dux, codex-orchestrator.
- Coditect inter-session message bus — a heavier alternative we explicitly chose *not* to copy.

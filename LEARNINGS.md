# LEARNINGS

Compound knowledge from past sessions. Newest first. Read before starting work.

---

## 2026-05-08 — parallel-tracks Stage 1 (steps 1–4) via /project-execute

**Branch:** `feat/parallel-tracks` · **Commits:** `b4ce278` (infra), `a1bb3a3` (command surface) · **Spec:** `specs/modules/parallel-tracks/SPEC.md`

### What worked

- **Spec-first paid off.** The `/project-spec` interactive Q&A produced a 10-decision spec with no ambiguity, which let Codex execute Stage 1 cleanly without needing to ask. The brittle bits in Codex's output were exactly the places where the spec was thin (the brownfield heuristic — see below).
- **Claude commits Codex's work, not Codex.** Codex's `workspace-write` sandbox blocked `.git/index.lock`, so it couldn't commit. Orchestrator (Claude) read the scrubbed log, ran smoke tests, then split the diff into two logical commits. This preserved Co-Authored-By attribution and gave a verification gate that Codex-self-committing wouldn't have. Pattern is worth keeping.
- **Smoke-testing the planner in a fixture repo** (mktemp + minimal MODULES.md + parallel.yaml fixtures) caught all four spec invariants in <30s: clean fixture, shared collision, missing yaml, wrong version. Fast feedback before commit.

### Gotchas

- **Self-referential dispatcher edits cause spurious bash errors.** Codex modified `.claude/lib/dispatch.sh` while bash was *running* it. When the running script's EXIT trap fired, bash re-read the modified file and reported errors at line offsets that no longer matched: `line 177: ose: command not found` (a partial match against the word "closes" in a comment that had moved) and `line 181: TRACK_ID: unbound variable` (a new variable that didn't exist in the version bash had originally loaded). The script's *final* state passed `bash -n` and ran correctly afterwards — the errors were transient, mid-edit. **Mitigation for future self-mod runs:** copy the dispatcher to a temp path before launching, or freeze edits to in-flight scripts. Also worth treating Codex's `__KIT_DISPATCH_EXIT__` exit code as the truth, not the bash spew that follows.
- **Codex training-data bleed-through.** Codex's final `-last.md` said "OMX autopilot is now marked `complete`" — that's not this project. Don't trust Codex's claim of completion verbatim. The kit's existing pattern (Claude reads scrubbed log + runs own verification) caught this naturally. Reinforces: scrubbed-log-readback is a verification step, not a formality.
- **Codex partially violated a "no heuristic" decision.** Spec §6 said "trust `parallel.yaml` only; no silent heuristics for brownfield." Codex added an `is_brownfield_repo()` function anyway, then made both branches of the conditional return the same error message — so it's dead code, but it is a nudge that strict negative requirements ("don't add X") need to be reiterated in the executor instruction block, not just left in the spec body.

### Stack-specific

- **bash mid-execution file edits are well-known fragile.** Bash buffers scripts in chunks; long scripts (`dispatch.sh` is ~200 lines, `bootstrap.sh` is ~5000) can trigger re-reads at trap-time. This is a generic shell gotcha that bites any self-modifying tooling.
- **Codex CLI 0.128 sandbox `workspace-write` excludes `.git/`.** Documented behaviour; relevant whenever a Codex run is expected to commit. Either widen the sandbox per-run (`KIT_CODEX_SANDBOX=danger-full-access`) or accept the orchestrator-commits pattern.

### Open questions

- Should `dispatch.sh` defensively copy itself to a temp path before launching Codex when the executor is going to modify it? Cheap, eliminates the self-ref bash class entirely.
- Should the executor instruction block in the dispatch prompt repeat negative spec requirements ("no brownfield heuristic; trust `parallel.yaml` only") in the constraints list? Spec deviations clustered around requirements that lived only in the spec body.

### Next session should

Run **Stage 2 of parallel-tracks** (steps 5–7 from `specs/modules/parallel-tracks/CLAUDE.md`): `tracks.json` registry hardening with mkdir-locking semantics, sentinel-watcher / abort handling for operator-killed panes, and `/project-tracks status` dashboard. Stage 1 commits already provide the substrate (per-track dispatcher locks; the registry file exists). After Stage 2, stage 3 covers `/project-tracks review`, `merge`, learnings-fragment merge, and `cleanup` — those are the most failure-prone steps and want their own focused run.

Open the PR for `feat/parallel-tracks` (Stage 1) before starting Stage 2 so CodeRabbit findings can inform Stage 2's instruction block.

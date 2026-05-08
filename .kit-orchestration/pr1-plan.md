# Plan: Fix and extend AI Project Kit (3 sequential PRs, dual-harness orchestration)

## Context

The AI Project Kit at `korallis/workflow` is a Claude-Code-driven spec/build/review workflow shipped as a single-file `bootstrap.sh` plus `.claude/skills/` and `.claude/commands/`. Three things need to ship, in order:

1. **PR1**: P0 bug fixes in templates and docs (no architecture changes).
2. **PR2**: Add `/project-execute` — a dual-harness skill where Claude Code (Opus 4.7) plans/reviews and Codex CLI (gpt-5.5) executes inside live tmux panes.
3. **PR3**: Add hooks, a security-review subagent, and `effort:` metadata on key skills.

The orchestration spec calls for a five-phase loop on every PR: **plan (Opus 4.7) → validate (Codex gpt-5.5 high) → reconcile (Opus 4.7) → execute (Codex gpt-5.5 medium) → review (Opus 4.7)**, with all Codex output streamed live into tmux panes that visibly open up in the user's TUI, and full logs captured to `.kit-orchestration/`.

This plan reflects an audit of the actual repo state (which contradicts a few details in the original prompt) and externally-verified facts about Codex CLI 0.128.0, the Claude Code hook spec, and OMX's tmux dispatch pattern.

---

## Decisions locked (from user)

| # | Decision | Implication |
|---|---|---|
| 1 | PR1 fixes the **actual** bugs (drop the no-op #1, retarget #3, treat #5 as template consolidation), with audit log committed to `.kit-orchestration/pr1-audit.md`. | Plan diverges from the prompt where the prompt was wrong. |
| 2 | Codex effort via `-c model_reasoning_effort=<level>` (no `--reasoning-effort` flag exists in 0.128.0). Verified flag reference embedded below. | Dispatch contract uses `-c` overrides. |
| 3 | New dedicated `kit-orchestration` tmux session for Codex panes. | dispatch.sh creates session if missing; user attaches with `tmux attach -t kit-orchestration` to watch live. |
| 4 | I design dispatch.sh in PR2 (validator pressure-tests it). | PR2 includes both architecture and reference impl. |
| 5 | tmux is **observer-only**, not executor. Codex runs as a child process of dispatch.sh; pane runs `tail -f` of the log. | Real exit codes, no send-keys hacks. Panes still visibly open. |
| 6 | **No GitHub Action workflow.** User has CodeRabbit; dropping `claude-review.yml` from PR3 entirely. PR3 = hooks + security-review subagent + effort metadata only. | Smaller, cleaner PR3. Workflow during PRs: monitor CodeRabbit comments, address them, merge when green. |
| 7 | Move shared dispatch.sh to `.claude/lib/dispatch.sh`. | Project-execute (and any future Codex-shelling skill) reuse. |
| 8 | Defer `/project-validate` skill to a later PR. PR2 = `/project-execute` only. | Validator is speculative until /project-execute proves the loop. |
| 9 | Apply `effort:` frontmatter only to NEW + KEY skills (project-execute, project-security-review, project-init, project-blueprint). Skip the noisy churn on the other 8. | PR3 surface area kept tight. |
| 10 | Security-review uses the **Agent tool** for context isolation, not a subagent skill. The skill triggers Claude to launch an Agent (subagent_type=general-purpose) with a fixed prompt file. | True isolation — skills can't isolate context on their own. |
| 11 | British English in user-facing docs. | README/CLAUDE.md prose. |

---

## Codex CLI flag reference (verified against 0.128.0)

Confirmed by `codex exec --help` and OpenAI docs:

| Flag | Form | Use |
|---|---|---|
| `-m, --model <MODEL>` | `-m gpt-5.5` | Model selection. |
| `-C, --cd <DIR>` | `-C /home/leeb/workflow` | Working directory. |
| `--skip-git-repo-check` | flag | Allow non-git dirs. We're in a git repo so optional, but defensive. |
| `-s, --sandbox <MODE>` | `-s workspace-write` | **Required** for write access. Modes: `read-only`, `workspace-write`, `danger-full-access`. |
| `-c <key=value>` | `-c model_reasoning_effort=high` | TOML config override. **This is how we set effort.** |
| `--json` | flag | JSONL events to stdout (good for logs). |
| `-o, --output-last-message <FILE>` | `-o .kit-orchestration/last.md` | Write final agent message to file. |
| `--ephemeral` | flag | Don't persist session. |
| `--ignore-user-config` | flag | Skip `~/.codex/config.toml`. |

**Flags that DO NOT exist** (despite the original prompt): `--reasoning-effort`, `--reasoning_effort`. Use `-c model_reasoning_effort=high|medium|low|xhigh`.

---

## Dispatch contract (canonical form)

```bash
codex exec \
  -m gpt-5.5 \
  -c model_reasoning_effort=<high|medium> \
  -s workspace-write \
  --skip-git-repo-check \
  -C /home/leeb/workflow \
  -o .kit-orchestration/<pr>-<phase>-last.md \
  "<full prompt verbatim>"
```

Wrapped by `.claude/lib/dispatch.sh` which adds:
- Codex auth preflight (5s timeout `codex exec` echo test; surfaces `codex login` instructions on failure).
- Multi-pattern secret scrubbing on log read path: regex sweep for `sk-[A-Za-z0-9_-]{20,}`, `ghp_[A-Za-z0-9]{36,}`, `gho_`, `github_pat_`, `Bearer\s+[A-Za-z0-9._-]+`, plus env-var-name allowlist.
- Hard timeout (default 1800s, configurable via `KIT_CODEX_TIMEOUT`).
- tmux pane spawn into `kit-orchestration` session running `tail -f <log>` (creates session detached if missing).
- Exit code propagation via the child process (not tmux).
- Single-flight lock at `.kit-orchestration/.lock`.

Every dispatch logs to `.kit-orchestration/<pr-id>-<phase>-<timestamp>.log`. The directory has `.gitignore: *.log` so logs don't get committed.

---

## tmux dispatch pattern (OMX-derived, observer model)

```bash
# 1. Ensure session exists (creates detached if not)
tmux has-session -t kit-orchestration 2>/dev/null \
  || tmux new-session -d -s kit-orchestration -x 200 -y 50

# 2. Open a window for live viewing of this dispatch
tmux new-window -t kit-orchestration -n "<phase>-<short-id>" \
  "tail -f '<log-path>'; read -p 'Press Enter to close...'"

# 3. Run Codex as a child of dispatch.sh, teeing to the log
{ codex exec ... 2>&1 | tee -a "<log-path>"; echo "EXIT=${PIPESTATUS[0]}" >> "<log-path>"; }
```

User watches with `tmux attach -t kit-orchestration` (printed once at first dispatch). Each phase opens a fresh window so the user can switch between them. Windows stay open after the run for review; user closes manually.

---

## PR 1 — Bug fixes (P0)

**Branch:** `fix/p0-bugs`. **PR title:** `fix: P0 bugs in templates, bootstrap, and skill references`.

### Scope (revised after audit)

| # | Bug | Files | Status |
|---|---|---|---|
| 1 | ~~bootstrap.sh missing project-spec template heredoc~~ | — | **DROP**: Already present at `bootstrap.sh:2847` (`TEMPLATE_CLAUDE2_EOF`). |
| 2 | `data: {{Type}> \| null;` — invalid TS | `.claude/skills/project-spec/claude-module-template.md:166`, `bootstrap.sh:~3000` (in `TEMPLATE_CLAUDE2_EOF` heredoc) | Fix to `data: {{Type}} \| null;`. Also patch the embedded copy in bootstrap.sh. |
| 3 | `loading: true` in finally block | `.claude/skills/project-spec/claude-module-template.md:71`, `bootstrap.sh:2918` (in `TEMPLATE_CLAUDE2_EOF` heredoc) | Fix to `loading: false`. **Note:** original prompt cited `project-module/SKILL.md` — bug is actually in `project-spec/claude-module-template.md`. Single source plus one bootstrap.sh embedded copy. |
| 4 | `/project-fix-tests` orphan reference | `.claude/skills/project-test/SKILL.md:310`, `bootstrap.sh:4381` | Replace `/project-fix-tests       (auto-fix suggestions)` line with `/project-module [name]   (deep dive on failing module)`. |
| 5 | Template duplication across skills | `.claude/skills/project-init/{blueprint,module-spec,claude-module}-template.md` AND `.claude/skills/project-spec/{module-spec,claude-module}-template.md` | **Audit reality**: not cross-references, duplication. Pick **`project-init/` as canonical** (it has all three including blueprint-template, and `project-init/SKILL.md` already references them as "bundled here"). In `project-spec/`: delete `module-spec-template.md` and `claude-module-template.md`; update `project-spec/SKILL.md` references from `./module-spec-template.md` and `./claude-module-template.md` to `../project-init/module-spec-template.md` and `../project-init/claude-module-template.md`. Update `bootstrap.sh` to remove the two duplicate heredocs (lines ~2847 and ~2937 — the `TEMPLATE_CLAUDE2_EOF` and `TEMPLATE_SPEC2_EOF` blocks for project-spec). |
| 6 | README placeholder URL | `README.md:39` | `https://your-repo/bootstrap.sh` → `https://raw.githubusercontent.com/korallis/workflow/main/bootstrap.sh` |
| 7 | ENHANCEMENT_PLAN.md → CHANGELOG.md | `ENHANCEMENT_PLAN.md` | All content added in single commit `0cb37af` dated **2026-03-19** (verified by `git log --follow`). Use Keep-a-Changelog format with `## [Unreleased]` (undated placeholder) + `## [0.1.0] - 2026-03-19` (dated to original commit). Convert each ENHANCEMENT_PLAN.md item to a past-tense `### Added` entry. |

### Reconciliation with validator findings (2026-05-08)

The validator (Codex GPT-5.5 high) confirmed all bug locations and the canonicalisation choice but caught five real misses, all addressed below:

1. **Wrong heredoc line ranges in original plan** — actual values per `grep -n`: `TEMPLATE_SPEC2_EOF` is `bootstrap.sh:2570-2844` (echo at 2845); `TEMPLATE_CLAUDE2_EOF` is `bootstrap.sh:2847-3240` (echo at 3241).
2. **Wrong commit date for changelog attribution** — `0cb37af` is dated `2026-03-19`, not `2026-05-08`. Fixed in row #7 above.
3. **Embedded `project-spec/SKILL.md` text in bootstrap.sh missed** — the `SKILL_SPEC_EOF` heredoc at `bootstrap.sh:2471-2568` includes the same template-reference lines that need repathing (lines 2511, 2512, ~2566). Without this, fresh bootstrap output still points at deleted files.
4. **`README.md:84-87` structure tree missed** — lists the duplicate `project-spec/` template files. Must be removed.
5. **`mkdir .claude/skills/project-spec` must NOT be removed** — `project-spec/SKILL.md` still exists, directory is still required. Original plan was unsafe.

The full validator report is at `.kit-orchestration/pr1-validation.md`. No disagreements with validator on any item.

### Files modified in PR1 (reconciled)

**Deleted** (bug #5 consolidation; this resolves bugs #2 and #3 by removing the buggy duplicates):
- `.claude/skills/project-spec/module-spec-template.md`
- `.claude/skills/project-spec/claude-module-template.md`

**Edited** (live files):
- `.claude/skills/project-spec/SKILL.md` — repath template references at lines 40, 41, 95 from `./module-spec-template.md` and `./claude-module-template.md` to `../project-init/module-spec-template.md` and `../project-init/claude-module-template.md`.
- `.claude/skills/project-test/SKILL.md` (line 310) — bug #4: delete the `/project-fix-tests       (auto-fix suggestions)` line entirely (per validator note: replacing with `/project-module [name]` would duplicate the next line).
- `README.md`:
  - Line 39 (bug #6) — replace `https://your-repo/bootstrap.sh` with `https://raw.githubusercontent.com/korallis/workflow/main/bootstrap.sh`.
  - Lines 85-87 (validator addition) — remove the two lines `│       │   ├── module-spec-template.md` and `│       │   └── claude-module-template.md` under the `project-spec/` block. Change line 85 from `│       │   ├── SKILL.md` to `│       │   └── SKILL.md` (only entry remaining in that group).

**Edited** (`bootstrap.sh`, exact line ranges verified):
- Lines 2511-2512 (inside `SKILL_SPEC_EOF` heredoc): repath the two embedded SKILL.md text bullets from `./module-spec-template.md` and `./claude-module-template.md` to `../project-init/module-spec-template.md` and `../project-init/claude-module-template.md`.
- Line ~2566 (inside `SKILL_SPEC_EOF` heredoc): the `**Templates**: See \`module-spec-template.md\` and \`claude-module-template.md\` for the structure and examples.` line — repath to `../project-init/module-spec-template.md` and `../project-init/claude-module-template.md`.
- Lines 2570-2845 (`TEMPLATE_SPEC2_EOF` `cat >` line through its echo confirmation): DELETE entirely.
- Lines 2847-3242 (`TEMPLATE_CLAUDE2_EOF` `cat >` line through its echo confirmation, including the blank line at 2846 between the two heredocs): DELETE entirely. Net deletion: original lines 2570-3242 inclusive.
- Line 4381 (bug #4): delete the `/project-fix-tests       (auto-fix suggestions)` line from the embedded `project-test/SKILL.md` heredoc.
- DO NOT remove `mkdir -p ".claude/skills/project-spec"` — `project-spec/SKILL.md` still exists and the directory is still needed.

**Renamed**:
- `ENHANCEMENT_PLAN.md` → `CHANGELOG.md` (bug #7) — `git mv` then rewrite to Keep-a-Changelog format. Use commit date `2026-03-19`. Structure:
  ```
  # Changelog

  All notable changes to this project will be documented in this file.

  The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

  ## [Unreleased]

  ## [0.1.0] - 2026-03-19

  ### Added
  - <past-tense entries derived from ENHANCEMENT_PLAN.md content>
  ```

**Created** (committed):
- `.kit-orchestration/.gitignore` (already created)
- `.kit-orchestration/pr1-audit.md` (already created)
- `.kit-orchestration/pr1-plan.md` (this file — to be re-copied after reconciliation)
- `.kit-orchestration/pr1-validation.md` (validator report)
- `.kit-orchestration/pr1-validate-prompt.md` (the prompt sent to validator, kept as evidence)

**Created** (NOT committed — gitignored as `*.log`):
- `.kit-orchestration/pr1-validate-*.log`
- `.kit-orchestration/pr1-execute-*.log`

### Commits (reconciled atomic sequence — 5 commits)

1. `chore: add .kit-orchestration scaffolding and PR1 audit log`
   — Adds `.kit-orchestration/.gitignore`, `pr1-audit.md`, `pr1-plan.md`, `pr1-validate-prompt.md`, `pr1-validation.md`.
2. `fix(test-skill): remove orphan /project-fix-tests reference`
   — Edits `.claude/skills/project-test/SKILL.md:310` and `bootstrap.sh:4381`.
3. `refactor(templates): consolidate duplicated templates under project-init/ (canonical)`
   — Deletes `project-spec/{module-spec,claude-module}-template.md`. Edits `project-spec/SKILL.md` references. Edits `bootstrap.sh:2511-2566` SKILL.md heredoc references and deletes `bootstrap.sh:2570-3242` template heredocs. Resolves bugs #2, #3, #5 simultaneously.
4. `docs(readme): replace placeholder URL and update structure tree`
   — `README.md:39` URL fix and `README.md:84-87` structure-tree cleanup.
5. `docs: rename ENHANCEMENT_PLAN.md to CHANGELOG.md (Keep-a-Changelog format)`
   — `git mv` + rewrite as dated 0.1.0 release (2026-03-19) with `[Unreleased]` placeholder.

### Phase sequence

| Phase | Actor | Output |
|---|---|---|
| Plan | Opus 4.7 (this) | This file copied to `.kit-orchestration/pr1-plan.md` |
| Validate | Codex gpt-5.5 high in `kit-orchestration` window `pr1-validate` | `.kit-orchestration/pr1-validation.md` (markdown report: Confirmed Correct / Issues Found / Suggested Additions) |
| Reconcile | Opus 4.7 | Updated plan file with disagreements documented |
| Execute | Codex gpt-5.5 medium in window `pr1-execute` | Unified diffs streamed to `.kit-orchestration/pr1-execution.log`; no commits |
| Review | Opus 4.7 | Read every diff, stage, commit (one per logical bug), push branch, open PR |

### Manual test checklist (in PR description, split by context)

**Source-repo checks** (run from `/home/leeb/workflow`):
- `bash -n bootstrap.sh` — syntax check (catches damaged heredoc deletions).
- `git grep -n "project-spec/.*template\|\\./module-spec-template\\.md\|\\./claude-module-template\\.md" -- ':!.kit-orchestration/*' ':!CHANGELOG.md'` — should return zero matches outside orchestration/changelog docs.
- `git grep -n '{{Type}>' -- ':!.kit-orchestration/*'` → 0 matches.
- `git grep -n 'loading: true' -- ':!.kit-orchestration/*'` → 0 matches in `finally` context.
- `git grep -n '/project-fix-tests' -- ':!.kit-orchestration/*'` → 0 matches.
- `grep -n 'your-repo' README.md` → 0 matches.
- `test -f CHANGELOG.md && ! test -f ENHANCEMENT_PLAN.md`.
- `head -10 CHANGELOG.md` → contains `## [Unreleased]` heading and `## [0.1.0] - 2026-03-19` heading.
- `grep -nE 'project-spec.+template\.md' README.md` → 0 matches (structure tree no longer lists deleted templates).

**Bootstrapped-output checks** (run after `bash bootstrap.sh` in a clean temp directory):
```bash
cd /tmp && rm -rf kit-test && mkdir kit-test && cd kit-test
bash /home/leeb/workflow/bootstrap.sh
test -f .claude/skills/project-init/claude-module-template.md && echo "OK: canonical claude template present"
test -f .claude/skills/project-init/module-spec-template.md && echo "OK: canonical spec template present"
test ! -f .claude/skills/project-spec/claude-module-template.md && echo "OK: duplicate claude-module deleted"
test ! -f .claude/skills/project-spec/module-spec-template.md && echo "OK: duplicate module-spec deleted"
grep -q '\.\./project-init/module-spec-template\.md' .claude/skills/project-spec/SKILL.md && echo "OK: spec SKILL.md repathed"
grep -q '\.\./project-init/claude-module-template\.md' .claude/skills/project-spec/SKILL.md && echo "OK: claude SKILL.md repathed"
grep -q '/project-fix-tests' .claude/skills/project-test/SKILL.md && echo "FAIL: orphan ref present" || echo "OK: orphan ref removed"
```

---

## PR 2 — `/project-execute` (dual-harness)

**Branch:** `feat/dual-harness-execute`. **PR title:** `feat: dual-harness execution via Codex CLI (project-execute skill)`.

### New files

```
.claude/commands/project-execute.md           # thin wrapper
.claude/skills/project-execute/SKILL.md       # orchestrator skill (effort: high)
.claude/skills/project-execute/dispatch-prompt-template.md   # template for Codex dispatch prompt assembly
.claude/lib/dispatch.sh                       # shared bash dispatcher (chmod +x)
.claude/lib/scrub-secrets.sh                  # regex-based secret redactor (sourced by dispatch.sh)
```

### `dispatch.sh` design (OMX-informed, observer-pane model)

Responsibilities:
1. **Preflight**: verify `codex` on PATH, run 5s timeout `codex exec` echo test to confirm auth (surface `codex login` or `OPENAI_API_KEY` env hint on failure).
2. **Lock**: acquire single-flight lock at `.kit-orchestration/.lock` via `flock` (blocks concurrent dispatches; configurable bypass via `KIT_ALLOW_CONCURRENT=1`).
3. **Log path**: `.kit-orchestration/<phase>-<id>-<timestamp>.log` (where `<phase>` is `validate`/`execute`/`review`, `<id>` is the PR number or module name).
4. **tmux session bootstrap**: `tmux has-session -t kit-orchestration || tmux new-session -d -s kit-orchestration -x 200 -y 50`. Print `tmux attach -t kit-orchestration` hint once.
5. **Open viewer window**: `tmux new-window -t kit-orchestration -n "<phase>-<short-id>" "tail -f '<log>'; read"`.
6. **Spawn Codex**: as a direct child process, with `KIT_CODEX_TIMEOUT` (default 1800s) wrapped via `timeout`. Tee stdout+stderr to log. Capture real exit code.
7. **Scrub on read**: when log is later read by Claude (the reviewer), pipe through `scrub-secrets.sh`. Don't scrub on write — too aggressive, breaks Codex's own logging.
8. **Exit handling**: write `EXIT=<code>` line to log; release lock; return Codex's exit code.
9. **Inline fallback**: if `tmux` not on PATH or `KIT_NO_TMUX=1`, skip windows; stream output inline with `==== Codex output begins ====` / `==== Codex output ends ====` headers.

Args: `dispatch.sh <phase> <id> <model> <effort> <prompt-file>`. Reads prompt from a file (not argv) so we don't blow ARG_MAX or leak via `/proc`.

### `SKILL.md` (project-execute) outline

```yaml
---
name: project-execute
description: Implement a fully-specced module via dual-harness execution — Claude orchestrates, Codex CLI executes inside a live tmux pane. Use when ready to write code for a module that has an approved SPEC.md and CLAUDE.md.
effort: high
---
```

Body:
1. Prerequisite check (Read these files; abort if missing): `specs/MASTER_BLUEPRINT.md`, `specs/modules/<module>/SPEC.md`, `specs/modules/<module>/CLAUDE.md`, `LEARNINGS.md` (optional), `CLAUDE.md` (root).
2. Build dispatch prompt by concatenating the four+ files plus an explicit instruction block ("implement phase by phase, run tests after each phase, commit after each green phase, stop and report if you cannot proceed, do not push").
3. Write the prompt to `.kit-orchestration/exec-<module>-<timestamp>-prompt.md`.
4. Invoke Bash tool: `bash .claude/lib/dispatch.sh execute <module> gpt-5.5 medium .kit-orchestration/exec-<module>-<timestamp>-prompt.md`.
5. After Codex returns, read the log via `scrub-secrets.sh`. Summarise outcome.
6. Auto-invoke `/project-review` to capture learnings (in the Claude session, not the Codex pane).

### Updated files

- `bootstrap.sh` — emit all PR2 files, create `.kit-orchestration/` if missing, mark `dispatch.sh` and `scrub-secrets.sh` executable. **Important**: bootstrap.sh is 4688 lines; ordering matters — add new heredocs in alphabetical position to minimise merge conflicts with PR3.
- `CLAUDE.md` — add `/project-execute` to trigger table; add new "Dual-Harness Workflow" section. Spec model assignments (Opus 4.7 plans/reviews; Codex gpt-5.5 medium executes; gpt-5.5 high will validate plans in a later PR).
- `README.md` — add "Dual-Harness Mode" section after "How It Works". Document `/project-module` (single-harness, all-in-Claude) vs `/project-execute` (dual-harness, Codex executes). Note Codex CLI prerequisite (`codex login` or `OPENAI_API_KEY`). British English.

### Validator pressure points (must address)

The validator will be told to specifically critique:
1. `tmux send-keys` exit-code limitation (we sidestep by running Codex as child, but validator should confirm).
2. Codex auth failure UX (preflight covers it; validator confirms).
3. Secret scrubbing patterns are sufficient.
4. Single-flight lock semantics (does it deadlock if dispatch.sh dies mid-run?).
5. `dispatch.sh` invoked twice by Claude (idempotency).
6. tmux unavailable fallback actually works.
7. Will `codex exec` honour `-c model_reasoning_effort=medium` for gpt-5.5? (config docs say yes, validator can confirm.)

### Phase sequence
Same five-phase loop. Logs at `.kit-orchestration/pr2-{plan,validation,execution,review}.log`.

### Manual test checklist (in PR description)
- Without Codex auth: invoke `/project-execute fakemodule` → preflight fails with actionable message, no tmux pane opened.
- With Codex auth, fake module spec: pane visibly opens in `kit-orchestration` session running `tail -f`; Codex runs; pane stays after exit; log written; exit code propagates; CLAUDE.md gets re-read at end.
- `KIT_NO_TMUX=1 /project-execute fakemodule` → inline output with markers, no tmux session created.
- `cat .kit-orchestration/exec-fakemodule-*.log | bash .claude/lib/scrub-secrets.sh` → no `sk-…`, `ghp_…`, `Bearer …` strings.
- Concurrent invocation → second blocks until first finishes (or fast-fails with lock message).

---

## PR 3 — Hooks, security review, effort metadata

**Branch:** `feat/hooks-security-effort`. **PR title:** `feat: pre-compact hook, security-review subagent, effort metadata`.

### Scope (revised: NO GitHub Action)

User uses CodeRabbit. The `claude-review.yml` GitHub Action workflow is **dropped from this PR entirely**. Workflow during PRs: monitor CodeRabbit's PR comments, address findings, merge when green.

### New files

```
.claude/hooks/pre-compact.sh                            # PreCompact hook (chmod +x)
.claude/settings.json                                   # PreCompact wiring + SessionStart compact backup
.claude/skills/project-security-review/SKILL.md         # effort: high; instructs Claude to launch Agent
.claude/skills/project-security-review/security-review-prompt.md  # the prompt the spawned Agent reads
.claude/commands/project-security-review.md             # thin wrapper
specs/sessions/.gitkeep                                 # snapshot directory
```

### `pre-compact.sh`

Snapshots:
- Current plan file path (if any) → copied to `specs/sessions/<timestamp>-plan.md`.
- Last 50 lines of conversation transcript via the hook's stdin JSON `transcript_path` → `specs/sessions/<timestamp>-transcript-tail.md`.
- Recent git activity (`git log --oneline -10`, `git status`) → `specs/sessions/<timestamp>-git.md`.

All output to stderr is shown to user. Exit 0 to allow compaction; never block.

### `settings.json` (project-scoped)

```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [{ "type": "command", "command": ".claude/hooks/pre-compact.sh" }]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [{ "type": "command", "command": "echo 'Session resumed after compaction. Most recent snapshot: $(ls -1t specs/sessions/*-plan.md 2>/dev/null | head -1)'" }]
      }
    ]
  }
}
```

The `SessionStart compact` matcher is the **explicit backup** for known issue [#13572](https://github.com/anthropics/claude-code/issues/13572) where `PreCompact` may not fire reliably for `/compact`. Documented as such in README.

### Security-review skill (Agent-tool isolation pattern)

`SKILL.md` (effort: high) instructs Claude:
1. Read the diff (e.g. `git diff main...HEAD`) — capture to a temp file.
2. Read `CLAUDE.md` security section (if any).
3. **Launch an Agent**: `Agent(subagent_type="general-purpose", description="Security review (isolated)", prompt=<contents of security-review-prompt.md, with diff and CLAUDE.md security section interpolated>)`.
4. Receive Agent report; surface to user.

The spawned Agent has a fresh context — no implementation bias. The prompt file (`security-review-prompt.md`) lives alongside the skill and is the canonical security checklist (UK GDPR, data residency, PII handling, audit logging, healthcare-domain compliance).

### `effort:` frontmatter — tight scope

Apply to **only** these (4 skills, not 10):
- `project-init/SKILL.md` → `effort: high`
- `project-blueprint/SKILL.md` → `effort: high`
- `project-execute/SKILL.md` → `effort: high` (already in PR2)
- `project-security-review/SKILL.md` → `effort: high`

Document in README that `effort:` is a Claude-Code-specific extension to the Agent Skills frontmatter spec; harnesses that don't recognise it will silently ignore it.

### `/project-review --isolate` flag

Update `.claude/skills/project-review/SKILL.md` to document a new `--isolate` mode that, instead of `/clear` (which nukes user context), launches an `Agent(subagent_type="general-purpose")` with a fixed review prompt and the diff. Same isolation principle as security-review. Plain `/project-review` (no flag) keeps current behaviour.

### Updated files
- `bootstrap.sh` — emit hooks, settings.json, security-review skill+prompt+command, specs/sessions dir, updates to project-review/SKILL.md and project-init/SKILL.md and project-blueprint/SKILL.md frontmatter.
- `README.md` — sections on hooks (with #13572 caveat), security review (Agent-isolation pattern), `--isolate` flag.
- `CLAUDE.md` (root) — add `/project-security-review` to trigger table; mention hooks briefly.

### Validator pressure points
1. `PreCompact` hook event name and matcher format correct in `settings.json`?
2. Is the SessionStart `compact` backup actually loaded — does it deduplicate with the PreCompact snapshot, or stack?
3. Does the security-review skill's "spawn Agent" instruction work — i.e. can a SKILL.md instruct the orchestrator to call the Agent tool? Yes, conceptually, but validator should confirm there's no harness restriction.
4. `effort:` field portability — confirmed Claude-Code-specific; OK to be silently ignored by other harnesses.
5. Does `.claude/settings.json` need to be created or already exist? (Per PR audit it doesn't exist yet.)

### Cross-PR ordering
- PR3 depends on PR2 being merged for the `.kit-orchestration/` scaffolding to exist (PR2 creates it).
- PR3's bootstrap.sh edits need to be rebased on main after PR2 merges (single 4688-line file = ugly conflicts otherwise).
- **Do not start PR3 until PR2 is merged.** Sequence: PR1 → user reviews → user merges → PR2 → user reviews → user merges → PR3.

### Manual test checklist
- Run `/compact` → verify `specs/sessions/*-plan.md` and `*-transcript-tail.md` written (or document if #13572 prevents firing).
- Open a fresh session after `/compact` → SessionStart hook prints latest snapshot path.
- Run `/project-security-review` on a non-trivial diff → Agent spawns, returns a security report; main session context not polluted with implementation details.
- `/project-review --isolate` → spawns Agent, returns report; user's session context preserved.
- `cat .claude/skills/project-init/SKILL.md | head -5` → contains `effort: high`.

---

## Phase sequence (applied to every PR)

For each PR, in `kit-orchestration` tmux session:

1. **Plan (Opus 4.7)** — Update this file; copy to `.kit-orchestration/<pr>-plan.md`.
2. **Validate (Codex gpt-5.5 high)** —
   ```bash
   bash .claude/lib/dispatch.sh validate <pr-id> gpt-5.5 high \
     .kit-orchestration/<pr-id>-validate-prompt.md
   ```
   Prompt: "You are a senior code reviewer. Critique this change plan for correctness, completeness, and risk. Identify anything missing, anything that breaks other parts of the kit, any incorrect path/file references, and the specific concerns listed in the plan's 'Validator pressure points'. Return a markdown report with sections: Confirmed Correct / Issues Found / Suggested Additions. Do NOT write code." Plus the full plan file appended.
3. **Reconcile (Opus 4.7)** — Update plan; document any disagreement with validator and reasoning.
4. **Execute (Codex gpt-5.5 medium)** —
   ```bash
   bash .claude/lib/dispatch.sh execute <pr-id> gpt-5.5 medium \
     .kit-orchestration/<pr-id>-execute-prompt.md
   ```
   Prompt: "Apply these changes exactly as specified. For each file, output a unified diff. Do not commit. Do not push. Do not modify CI. Make no changes outside the listed files. Stop and ask if any instruction is ambiguous." Plus the reconciled plan.
5. **Review (Opus 4.7)** — Read every diff, verify against plan, stage, commit (per logical change), push branch, open PR with model+effort attribution and links to logs.

For PR1, dispatch.sh doesn't exist yet → **bootstrap exception**: PR1 validation/execution use a temporary inline `codex exec` call (documented in PR1's audit log). PR2 ships dispatch.sh and PR2/PR3 use it.

---

## Critical files (full paths)

**Read-only audit references:**
- `/home/leeb/workflow/CLAUDE.md` (264 lines, root operating model)
- `/home/leeb/workflow/README.md` (587 lines)
- `/home/leeb/workflow/bootstrap.sh` (4688 lines — single-file installer)
- `/home/leeb/workflow/ENHANCEMENT_PLAN.md` (464 lines, becomes CHANGELOG.md)
- `/home/leeb/workflow/.claude/skills/project-spec/claude-module-template.md` (PR1 bugs #2, #3 — being deleted as part of #5)
- `/home/leeb/workflow/.claude/skills/project-init/claude-module-template.md` (canonical post-PR1)
- `/home/leeb/workflow/.claude/skills/project-test/SKILL.md` (PR1 bug #4)
- `/home/leeb/workflow/.claude/skills/project-init/SKILL.md` (PR3 effort frontmatter)
- `/home/leeb/workflow/.claude/skills/project-blueprint/SKILL.md` (PR3 effort frontmatter)
- `/home/leeb/workflow/.claude/skills/project-review/SKILL.md` (PR3 --isolate flag)

**Created in this work:**
- `/home/leeb/workflow/.kit-orchestration/.gitignore`
- `/home/leeb/workflow/.kit-orchestration/pr{1,2,3}-{plan,audit,validation,execution,review}.{md,log}` (per PR)
- `/home/leeb/workflow/CHANGELOG.md` (renamed from ENHANCEMENT_PLAN.md)
- `/home/leeb/workflow/.claude/lib/dispatch.sh` (PR2)
- `/home/leeb/workflow/.claude/lib/scrub-secrets.sh` (PR2)
- `/home/leeb/workflow/.claude/skills/project-execute/SKILL.md` (PR2)
- `/home/leeb/workflow/.claude/skills/project-execute/dispatch-prompt-template.md` (PR2)
- `/home/leeb/workflow/.claude/commands/project-execute.md` (PR2)
- `/home/leeb/workflow/.claude/hooks/pre-compact.sh` (PR3)
- `/home/leeb/workflow/.claude/settings.json` (PR3)
- `/home/leeb/workflow/.claude/skills/project-security-review/SKILL.md` (PR3)
- `/home/leeb/workflow/.claude/skills/project-security-review/security-review-prompt.md` (PR3)
- `/home/leeb/workflow/.claude/commands/project-security-review.md` (PR3)
- `/home/leeb/workflow/specs/sessions/.gitkeep` (PR3)

---

## Operating rules across all three PRs

- Never push without explicit user approval. Open PRs only.
- Never modify `.git/`, secrets, or CI auth. No GitHub Action workflow committed (CodeRabbit handles review).
- Every Codex dispatch logs to `.kit-orchestration/`. Logs are gitignored.
- tmux pane visibility is required (PR2 onward); fallback to inline streaming with markers if tmux unavailable.
- If a phase blocks (Codex hangs past timeout, validator returns critical issues, tests fail), stop and ask the user. Do not improvise.
- British English in user-facing prose.
- One PR open at a time. Wait for user merge between PR1 → PR2 → PR3.
- Every PR description includes: bug/feature summary, links to `.kit-orchestration/` logs, manual test checklist, and the model+effort attribution: "Plan: Opus 4.7. Validation: Codex gpt-5.5 (high). Execution: Codex gpt-5.5 (medium). Review: Opus 4.7."

---

## Verification (end-to-end)

**After PR1 merges:**
```bash
cd /tmp && rm -rf kit-test && mkdir kit-test && cd kit-test
curl -O https://raw.githubusercontent.com/korallis/workflow/main/bootstrap.sh
bash bootstrap.sh
test -f .claude/skills/project-init/claude-module-template.md && echo "OK: canonical template present"
test ! -f .claude/skills/project-spec/claude-module-template.md && echo "OK: duplicate removed"
grep -r '{{Type}>' . && echo "FAIL" || echo "OK: no {{Type}> typo"
grep -r '/project-fix-tests' . && echo "FAIL" || echo "OK: no orphan refs"
test -f CHANGELOG.md && test ! -f ENHANCEMENT_PLAN.md && echo "OK: changelog renamed"
```

**After PR2 merges:**
```bash
# In a tmux-capable terminal:
codex --version    # confirm Codex CLI installed
codex exec --skip-git-repo-check "echo hello"   # confirm auth
# In Claude Code:
/project-execute fakemodule
# expect: "Spec not found at specs/modules/fakemodule/SPEC.md" — preflight failure cleanly surfaced, no Codex pane opened.
# Then create a stub spec and re-run; pane should visibly open in kit-orchestration session.
tmux attach -t kit-orchestration   # in a side terminal — should show the live tail -f.
```

**After PR3 merges:**
```bash
# In Claude Code:
/compact
ls specs/sessions/   # should show *-plan.md, *-transcript-tail.md, *-git.md (or document #13572 limitation)
/project-security-review
# expect: Agent spawn message, security report returned, main context not polluted with implementation
/project-review --isolate
# expect: similar — Agent spawn, isolated review report, main context preserved
```

If any verification fails: **stop, capture the failure in `.kit-orchestration/<pr>-failure.md`, and ask the user how to proceed**. Do not patch around it.

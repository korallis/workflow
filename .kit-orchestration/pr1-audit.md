# PR1 Audit — prompt-vs-reality discrepancies

**Date:** 2026-05-08
**Auditor:** Claude Opus 4.7 (planning agent)
**Sources:** Read-only inspection of repo at `/home/leeb/workflow` plus external research via Exa (Codex CLI 0.128.0 docs, Claude Code hooks, Anthropic Skills spec, oh-my-codex tmux pattern).

This file records where the original task brief was inaccurate, so the validator (Codex GPT-5.5 high) and future sessions can see the ground truth.

---

## Discrepancies between brief and actual repo state

### Bug #1 — bootstrap.sh missing project-spec template heredoc

**Brief said:** `bootstrap.sh does not write .claude/skills/project-spec/claude-module-template.md even though project-spec/SKILL.md references it.`

**Reality:** `bootstrap.sh` line 2847 already writes the file via the `TEMPLATE_CLAUDE2_EOF` heredoc:

```
2847:cat > ".claude/skills/project-spec/claude-module-template.md" << 'TEMPLATE_CLAUDE2_EOF'
```

A second heredoc at line ~2937 (`TEMPLATE_SPEC2_EOF`) writes `.claude/skills/project-spec/module-spec-template.md`.

**Resolution:** Bug #1 dropped. No heredoc needs adding.

### Bug #3 — `loading: true` in finally block — wrong location

**Brief said:** `In .claude/skills/project-module/SKILL.md under "React Component Pattern", the finally block sets loading: true.`

**Reality:** The buggy `finally { setState((s) => ({ ...s, loading: true })); }` lives in `.claude/skills/project-spec/claude-module-template.md` line 71 (and its bootstrap.sh embedded duplicate at line 2918), NOT in `project-module/SKILL.md`. A grep across `.claude/` confirms only one occurrence pair.

**Resolution:** Bug #3 retargeted to `project-spec/claude-module-template.md`. Since that file is being deleted as part of bug #5 (template consolidation), the fix happens by deletion — no edit needed. Bootstrap heredoc is also being removed as part of #5, so #3 is fully resolved by the #5 changes.

### Bug #5 — cross-skill template references

**Brief said:** `project-init/SKILL.md references ../project-spec/blueprint-template.md and ../project-spec/... paths in places. Audit all cross-skill template references.`

**Reality:** No `../project-spec/` references exist in `project-init/SKILL.md`. Both `project-init/` and `project-spec/` directories contain literal copies of `claude-module-template.md` and `module-spec-template.md`. `project-init/` additionally has `blueprint-template.md`. `project-init/SKILL.md` lines 74, 82, 103 refer to templates as "bundled in this skill directory" / "bundled here". `project-spec/SKILL.md` lines 40-41 refer to `./module-spec-template.md` and `./claude-module-template.md`.

The actual problem is **silent duplication** — two copies that will drift over time. The buggy `loading: true` and `{{Type}>` exist only in the `project-spec/` copy; the `project-init/` copy is clean. So the duplicates have already drifted.

**Resolution:** Bug #5 reframed as "consolidate duplicated templates". Pick `project-init/` as canonical (already has all three templates including blueprint). In `project-spec/`: delete the two duplicates, repath `project-spec/SKILL.md` references to `../project-init/`. In `bootstrap.sh`: delete the two `TEMPLATE_*2_EOF` heredocs (lines 2847, ~2937).

### Bug #7 — ENHANCEMENT_PLAN.md → CHANGELOG.md date attribution

**Brief said:** `rewrite it to document what's already been done... as past tense entries dated to the original commits where possible.`

**Reality:** `git log --follow --oneline ENHANCEMENT_PLAN.md` returns only `0cb37af feat: convert to skills architecture, fix command naming, add MCP tool integrations` (2026-05-08). Single commit. There are no historical commits to date-attribute against.

**Resolution:** Convert to Keep-a-Changelog format with all entries under a single dated section `## [0.1.0] - 2026-05-08`. Add an empty `## [Unreleased]` section at the top for future PRs to append to.

---

## External research findings (verified)

### Codex CLI 0.128.0 flags

- **No `--reasoning-effort` flag exists.** Confirmed via `codex exec --help`. Reasoning effort is set via `-c model_reasoning_effort=high|medium|low|xhigh`.
- Real flags relevant to dispatch: `-m, --model`, `-C, --cd`, `-s, --sandbox <read-only|workspace-write|danger-full-access>`, `--skip-git-repo-check`, `-c <key=value>`, `--json`, `-o, --output-last-message`, `--ephemeral`, `--ignore-user-config`.
- `gpt-5.5` is the recommended model per OpenAI Codex docs.

### Claude Code hooks

- `PreCompact` event name is correct. Matchers: `manual`, `auto`, `*`.
- Known issue [#13572](https://github.com/anthropics/claude-code/issues/13572): PreCompact may not fire reliably for `/compact`. PR3 will add a `SessionStart` `compact` matcher backup.

### Skill frontmatter `effort:`

- `effort: low|medium|high|max` is a Claude-Code-extended frontmatter field per third-party reference (philoserf/claude-code-setup).
- Not part of the agentskills.io open standard. Other harnesses silently ignore unknown frontmatter — acceptable per spec.

### oh-my-codex (OMX) tmux pattern

- OMX splits the existing tmux session into worker panes, sends prompts via `tmux send-keys -t <pane> -l <text>` followed by double `C-m` (Codex CLI raw input mode requires double Enter).
- OMX's roadmap [#1243](https://github.com/Yeachan-Heo/oh-my-codex/issues/1243) explicitly moves AWAY from tmux as correctness oracle; treats it as observation layer with state-files-of-record.
- Worker panes are NOT auto-closed; user runs `omx team shutdown`.
- Our adaptation: tmux is observer-only. Codex runs as a child process of `dispatch.sh`; pane runs `tail -f <log>`. Real exit codes via the child process. Panes still visibly open in `kit-orchestration` session.

---

## Decisions for PR1 (locked with user)

1. Fix actual bugs (drop no-op #1, retarget #3, treat #5 as template consolidation), commit this audit log.
2. Dispatch contract: `codex exec -m gpt-5.5 -c model_reasoning_effort=<level> -s workspace-write --skip-git-repo-check -C /home/leeb/workflow -o <output> "<prompt>"`.
3. New dedicated `kit-orchestration` tmux session.
4. PR1 uses inline `codex exec` (no `dispatch.sh` yet — that ships in PR2).
5. tmux observer-only; Codex runs as child process.
6. No GitHub Action workflow shipping (CodeRabbit handles PR review).
7. British English in user-facing prose.

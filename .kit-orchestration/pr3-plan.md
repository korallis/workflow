# PR3 plan — hooks, security-review subagent, effort metadata

**Branch**: `feat/hooks-security-effort`
**PR title**: `feat: pre-compact hook, security-review subagent, effort metadata`
**Prerequisites merged**: PR1 (#1), PR2 (#2). PR3 uses `.claude/lib/dispatch.sh` for its own validate/execute phases — first PR with no bootstrap exception.

## Context

PR3 closes the orchestration's remaining gaps: a PreCompact hook so transcript content survives auto-compaction, a security-review subagent that runs in a fresh Agent context (so no implementation bias), `effort:` frontmatter on key skills, and a `--isolate` flag on `/project-review` that uses the same Agent-based isolation pattern.

**Dropped from this PR per user direction**: the `claude-review.yml` GitHub Action workflow (CodeRabbit handles PR review).

## Files this PR creates

```text
.claude/hooks/pre-compact.sh                                 # PreCompact snapshot script (chmod +x)
.claude/settings.json                                        # PreCompact + SessionStart compact hook wiring
.claude/skills/project-security-review/SKILL.md              # security-review skill (effort: high)
.claude/skills/project-security-review/security-review-prompt.md   # Agent prompt for isolated review
.claude/commands/project-security-review.md                  # thin command wrapper
specs/sessions/.gitkeep                                      # snapshot directory marker
```

## Files this PR updates

- `.claude/skills/project-init/SKILL.md` — add `effort: high` to frontmatter.
- `.claude/skills/project-blueprint/SKILL.md` — add `effort: high` to frontmatter.
- `.claude/skills/project-review/SKILL.md` — add support for `--isolate` flag (Agent-based isolated review path).
- `bootstrap.sh` — heredocs for the new files, `mkdir -p .claude/hooks`, `mkdir -p specs/sessions`, `chmod +x` on the hook script. Update embedded skill heredocs for project-init, project-blueprint, project-review.
- `CLAUDE.md` (root) — add `/project-security-review` to both trigger table AND Available Slash Commands table. Brief mention of hooks under "Available Tools & Integrations".
- `README.md` — add a "Hooks" sub-section explaining the PreCompact snapshot pattern (with the [#13572](https://github.com/anthropics/claude-code/issues/13572) caveat); add `/project-security-review` and `--isolate` to the slash commands inventory and Quick Reference; mention `effort:` frontmatter as a Claude-Code-specific extension.

## `pre-compact.sh` — full source spec (revised after validator)

**Revisions** (MINOR 4, MINOR 5): docstring no longer claims "Exit 0 always" (filesystem races and `set -e` can still produce non-zero); jq fallback note clarified — snapshot 1 only depends on a plan file existing, snapshot 2 needs `transcript_path` from jq, snapshot 3 always runs.

```bash
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
```

## `.claude/settings.json` — full content (revised after validator)

**Revisions** (REJECT 1, MINOR 10): hook paths use `$CLAUDE_PROJECT_DIR` so they work even when the session cwd has changed; SessionStart shell command also `cd "$CLAUDE_PROJECT_DIR"` first.

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/pre-compact.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "compact",
        "hooks": [
          {
            "type": "command",
            "command": "cd \"$CLAUDE_PROJECT_DIR\" && if compgen -G 'specs/sessions/*-plan.md' >/dev/null 2>&1; then echo \"Session resumed after compaction. Latest snapshot: $(ls -1t specs/sessions/*-plan.md 2>/dev/null | head -1)\"; else echo 'Session resumed after compaction. No prior snapshot found in specs/sessions/.'; fi"
          }
        ]
      }
    ]
  }
}
```

The SessionStart `compact` hook is the documented backup for [#13572](https://github.com/anthropics/claude-code/issues/13572). If PreCompact fires, the user gets a snapshot and the SessionStart message tells them where to look. If PreCompact doesn't fire, the SessionStart message tells them no snapshot exists — they know to manually grep their transcript.

## `.claude/skills/project-security-review/SKILL.md` — content spec (revised after validator)

**Revisions** (MINOR 8): use `subagent_type="Explore"` instead of `general-purpose`. Explore agents are read-only by default — exactly what a security review needs. Diff capture uses `mktemp` + `trap` cleanup (MINOR 7) and falls back when `origin/main` isn't fetched (MINOR 6).

```yaml
---
name: project-security-review
description: Independent security review of pending changes via an isolated Agent context — fresh subagent reads the diff and a security checklist with no implementation bias. Use after a module is implemented and before merge, especially for changes that touch auth, data persistence, PII, audit logging, or anything UK GDPR-sensitive. Triggers on '/project-security-review', 'security review', 'audit this branch'.
effort: high
---

# project-security-review

Runs a security review of pending changes in **fresh Agent context** so the reviewer has no exposure to the implementation reasoning that produced the code. This isolation is the entire point — a reviewer who watched the code being written tends to share its blind spots.

## Process

1. **Capture the diff** (use `mktemp` + cleanup trap so the temp file doesn't leak):

   ```bash
   diff_file="$(mktemp -t security-review-diff.XXXXXX)"
   trap 'rm -f "$diff_file"' EXIT
   if git rev-parse --verify origin/main >/dev/null 2>&1; then
     base="$(git merge-base origin/main HEAD)"
   elif git rev-parse --verify main >/dev/null 2>&1; then
     base="$(git merge-base main HEAD)"
   else
     base="HEAD~1"
   fi
   git diff "$base"..HEAD > "$diff_file"
   ```

2. **Identify the security checklist**: read `.claude/skills/project-security-review/security-review-prompt.md`. This is the canonical instruction set the Agent will follow.

3. **Launch the Agent** with a read-only subagent type so the reviewer can't accidentally modify the working tree:

   ```text
   Agent(
     subagent_type="Explore",
     description="Security review (isolated read-only context)",
     prompt=<contents of security-review-prompt.md, with $diff_file content and any relevant CLAUDE.md security section interpolated into the prompt body>
   )
   ```

   The Explore agent runs with a fresh context window AND no edit/write tools — it has not seen planning or implementation discussion, and it cannot modify code. Its findings reflect the diff alone plus the security checklist.

4. **Receive the Agent's report** and surface it to the user without modification. Add a one-paragraph framing explaining what was reviewed and any user-actionable next steps.

5. **Optional follow-ups**:
   - If the Agent found CRITICAL or HIGH issues, suggest the user address them before merge.
   - Note that this skill does NOT modify code — it produces a report only.

## When to use

- Before merging any PR that touches auth, session management, or token handling.
- After implementing data persistence for PII or healthcare-sensitive data (UK GDPR considerations).
- When the change touches audit logging, access control, or rate limiting.
- When you want a "second set of eyes" with no contextual bias.

## Why isolation matters

A reviewer who participated in implementation tends to validate the assumptions that drove the implementation. An Agent in fresh context only sees the diff — its blind spots are different from the implementer's, which is exactly what a security review needs.
```

## `.claude/skills/project-security-review/security-review-prompt.md` — full content (revised after validator)

**Revisions** (MINOR 9): added CSRF, SSRF/open redirects, webhook signature verification, file-upload validation, and client-bundle secret leak categories.

This is the prompt the Agent reads. It is checked into the repo as a stable artefact (so the review's quality is reproducible).

```markdown
# Security review — instructions for the spawned Agent

You are a security reviewer with no prior context on this codebase. The diff below represents pending changes to a project. Review them rigorously against the checklist that follows. Do not assume the implementer's intent was correct.

## Required output format

```markdown
# Security review

**Files reviewed**: <count> | **Lines added/removed**: <+N/-M> | **Branch**: <name>

## Findings by severity

### CRITICAL (security vulnerability — must fix before merge)
- [file:line — issue — recommendation]

### HIGH (likely bug or major risk)

### MEDIUM (concern worth addressing)

### LOW (style / minor)

## Areas that look clean

- [bullet list of areas you reviewed and found acceptable]

## Recommendation

APPROVE / REQUEST CHANGES / COMMENT — with one-sentence rationale.
```

## Review checklist

For every changed file, walk through:

### Authentication & session
- Are credentials read from environment variables only, never hard-coded?
- Are session tokens stored securely (httpOnly cookies, not localStorage)?
- Is logout invalidating the token server-side, not just client-side?
- Are password resets rate-limited?

### Authorisation
- Is every protected endpoint checking `auth.getCurrentUser()` (or equivalent) before reading/writing data?
- Are user IDs scoped to the requesting user (no `userId` parameter that lets one user act as another)?
- Are admin endpoints separately gated?

### Input validation
- Is every user-supplied input validated (Zod, Pydantic, or equivalent) before being used in queries, file paths, or shell commands?
- Are SQL queries parameterised (no string interpolation of user input)?
- Are path traversal vectors closed (no `../` traversal in file operations)?
- Are JSON parsers given size limits?

### Output handling
- Are user-supplied strings escaped before insertion into HTML (XSS prevention)?
- Are error messages sanitised before being returned to the user (no stack traces, no internal paths)?
- Are PII fields redacted from logs?

### State-changing requests
- Do state-changing endpoints (POST/PUT/PATCH/DELETE) require a CSRF token, SameSite=Strict cookie, or other origin-binding mechanism?
- Are mutating operations idempotent where reasonable (so retries don't double-charge or duplicate records)?

### External fetches and redirects
- Are server-side fetches (image proxies, URL previewers, webhooks) protected against SSRF? (Block `127.*`, `169.254.169.254`, `10.*`, `192.168.*`, etc.)
- Are open-redirect parameters validated against an allowlist of permitted destinations?

### Webhook handling
- Are inbound webhooks verifying signatures (Stripe `Stripe-Signature`, GitHub `X-Hub-Signature-256`, etc.) before any side effect?
- Are webhook timestamps checked against replay (window <5 min)?

### File uploads
- Is uploaded file MIME type validated server-side (not just from client header)?
- Are file size limits enforced before reading the body into memory?
- Are uploaded files served from a separate origin (or with `Content-Disposition: attachment` and a sandboxed Content-Type) to prevent stored XSS?
- Is the storage path randomised (no user-supplied filename in the served URL)?

### Client-side secret hygiene
- Are secrets ever embedded in the client bundle (e.g. via `process.env.SECRET` in client code, or hard-coded in JSX)?
- Are runtime config endpoints scoped to non-secret values only?

### Data persistence (UK GDPR considerations)
- Is PII (names, emails, addresses, phone numbers, health data) only persisted when there's a documented lawful basis?
- Is sensitive data encrypted at rest?
- Are deletions actually deletions (not soft-deletes that retain personal data indefinitely)?
- Is data residency considered (EU/UK data not silently flowing to non-adequate jurisdictions)?

### Audit logging
- Are security-relevant events logged (login, logout, permission change, data export, deletion)?
- Are logs append-only and tamper-evident?
- Are PII redaction rules applied to logs?

### Healthcare-domain compliance (where applicable)
- If the project touches NHS or other healthcare data: is access strictly role-based?
- Are clinical records versioned (no destructive edits)?
- Is consent recorded with timestamp and auditable trail?

### Dependencies
- Are new dependencies from reputable sources?
- Do they have known CVEs (suggest the user run `npm audit` / `pip-audit` / equivalent)?
- Are versions pinned (no `^` or `~` in production deps for security-critical packages)?

### Operational hygiene
- Are debug flags off in production code paths?
- Are CORS origins restricted (no `*` in production)?
- Are rate limits in place on public endpoints?

## How to ground your findings

For each finding, cite the file path and line number from the diff. Quote the relevant code. Explain why it's a concern in one sentence. Recommend a concrete fix.

If you are uncertain whether something is a problem, mark it MEDIUM with a note of what would change your assessment.

If a category is not applicable to this diff (e.g. no auth code touched), say so explicitly under "Areas that look clean" rather than skipping it.

## Diff to review

<the actual git diff is appended here at runtime>

## Project-specific security context (if present)

<the relevant section of CLAUDE.md is appended here at runtime>
```

## `.claude/commands/project-security-review.md` — content

```markdown
Read and follow the skill at `.claude/skills/project-security-review/SKILL.md`.
```

## `effort:` frontmatter additions

Apply to two existing skills (project-execute already has it from PR2; project-security-review has it from creation):

- `.claude/skills/project-init/SKILL.md`: add `effort: high` line after `description:` in the frontmatter.
- `.claude/skills/project-blueprint/SKILL.md`: same.

Bootstrap.sh's embedded heredocs for these files must mirror the addition.

## `/project-review --isolate` flag (revised after validator)

**Revision** (REJECT 2): the original "fresh-Agent does everything" semantics broke the skill's purpose. The existing `project-review` skill captures session learnings, decisions, blockers, and updates `LEARNINGS.md` / `CLAUDE.md` — none of which an Agent in fresh context can do faithfully (it has no parent session memory). Revised: `--isolate` is **additive**, spawning an Explore agent for an unbiased *code-review pass over the diff only*, whose findings are appended to the in-session review output. The learnings/decisions/CLAUDE.md updates still happen in the parent session.

Update `.claude/skills/project-review/SKILL.md` to add a short section near the top, before "## Process":

```markdown
## Optional isolated code-review pass (`--isolate`)

If `$ARGUMENTS` contains `--isolate`, **additionally** run a code-review pass in a fresh Explore-agent context (no edit/write tools, no parent transcript) on top of the normal in-session review. The Agent reviews only the diff for code-quality / correctness issues; the rest of this skill (session learnings, LEARNINGS.md / CLAUDE.md updates, next-task recommendation) still runs in this session because that work needs parent-session memory.

When `--isolate` is detected:

1. Capture the diff:

   ```bash
   diff_file="$(mktemp -t isolated-review-diff.XXXXXX)"
   trap 'rm -f "$diff_file"' EXIT
   if git rev-parse --verify origin/main >/dev/null 2>&1; then
     base="$(git merge-base origin/main HEAD)"
   elif git rev-parse --verify main >/dev/null 2>&1; then
     base="$(git merge-base main HEAD)"
   else
     base="HEAD~1"
   fi
   git diff "$base"..HEAD > "$diff_file"
   ```

2. Launch an Explore agent (read-only):

   ```text
   Agent(
     subagent_type="Explore",
     description="Isolated diff code-review",
     prompt="You are a code reviewer with no prior context. Review the diff below for code-quality issues only — correctness, clarity, naming, error handling, test coverage, simplicity. Output a markdown report with sections: Critical / High / Medium / Low. Quote file:line for each finding. Diff: <contents of $diff_file>"
   )
   ```

3. **Then** continue with the normal in-session steps below. Append the Agent's report to the final review output, clearly labelled "Isolated code-review pass (Explore agent)".

Without `--isolate` (the default), skip the Agent step and proceed with the in-session review only.
```

Bootstrap.sh's `project-review/SKILL.md` heredoc must mirror this addition.

## `CLAUDE.md` updates

- Trigger table: add `/project-security-review` row with description "Independent Agent-based security review of pending changes — UK GDPR / healthcare focus."
- Available Slash Commands table: same — add `/project-security-review` row.
- Tool Integrations section: add a brief "Hooks" sub-section pointing at `.claude/hooks/` and noting `pre-compact.sh` (with #13572 caveat).

## `README.md` updates

- "Slash Commands" section: add a `/project-security-review` sub-section after `/project-execute`.
- Quick Reference table: add `/project-security-review` and note the `--isolate` flag on `/project-review`.
- New "Hooks" section after "Tool Integrations": describes the PreCompact snapshot pattern, the SessionStart compact backup, and the #13572 caveat.
- New "Skill Frontmatter" sub-section under "Slash Commands": briefly note that `effort: high|medium|low|max` is a Claude-Code-specific extension and is silently ignored by other harnesses.

## bootstrap.sh updates (line refs verified by validator on current main HEAD)

Validator-confirmed exact ranges in post-PR2 main:

- Top dir block (mkdirs): **lines 37-50**.
- `project-init/SKILL.md` heredoc starts: **line 389** (`SKILL_INIT_EOF`).
- `project-blueprint/SKILL.md` heredoc starts: **line 2090** (`SKILL_BLUEPRINT_EOF`).
- `project-review/SKILL.md` heredoc starts: **line 2826** (`SKILL_REVIEW_EOF`).
- Lib heredocs (dispatch.sh, scrub-secrets.sh): start at **3889** and **4083** respectively.
- COMMANDS section: **line 4143** (header `# COMMANDS (thin wrappers that invoke skills)`).

Insertions:

1. **Top dir block (37-49)**: add `mkdir -p .claude/hooks`, `mkdir -p .claude/skills/project-security-review`, `mkdir -p specs/sessions`.
2. **After lib heredocs, before COMMANDS section**: heredoc for `.claude/hooks/pre-compact.sh` + `chmod +x`. Heredoc for `.claude/settings.json`. Heredoc for `.claude/skills/project-security-review/SKILL.md`. Heredoc for `.claude/skills/project-security-review/security-review-prompt.md`. `.gitkeep` for `specs/sessions/`.
3. **In COMMANDS section** (after project-execute.md): heredoc for `.claude/commands/project-security-review.md`.
4. **Update embedded skill heredocs**:
   - `project-init/SKILL.md` heredoc: insert `effort: high` line in the frontmatter.
   - `project-blueprint/SKILL.md` heredoc: insert `effort: high` line in the frontmatter.
   - `project-review/SKILL.md` heredoc: insert the `## Isolated mode (--isolate)` section before `## Process`.
5. **Update the embedded `CLAUDE.md` heredoc**: add the `/project-security-review` row to both the trigger table AND the Available Slash Commands table; add the brief Hooks mention.
6. The root `README.md` is NOT bootstrap-generated (per PR2 ambiguity resolution) — only update the live README.md.

Use unique heredoc terminators: `HOOK_PRECOMPACT_EOF`, `SETTINGS_JSON_EOF`, `SKILL_SECURITY_EOF`, `PROMPT_SECURITY_EOF`, `CMD_SECURITY_EOF`.

## Validator pressure points

The PR3 validator should specifically address:

1. **PreCompact hook event name and matcher format**: confirm `PreCompact` with matcher `*` is the right schema in `settings.json`. (Validated against current Claude Code docs: yes.)
2. **Hook stdin JSON structure**: does Claude Code 2.x reliably pipe `{session_id, transcript_path, trigger, custom_instructions}` into stdin? Are there cases where stdin is empty?
3. **`compgen -G` with quoted glob**: portable across bash versions? (Yes, bash 4+; macOS bash 3.2 ships with bash 5+ via brew but stock is 3.2 — `compgen` exists in 3.2 too.)
4. **`jq` optional fallback**: if jq is missing, all extract calls return empty — is the rest of the script still safe? (Yes — empty session_id/transcript_path leads to skipping snapshots 1+2 but snapshot 3 still runs.)
5. **`SessionStart` `compact` matcher**: does it actually fire on session resume after `/compact`? Per docs yes; per #13572 maybe not.
6. **Skill instructs Claude to launch Agent**: is this a documented, supported pattern? The skill is prose Claude reads — Claude can call any tool including Agent. Yes.
7. **`Agent(subagent_type="general-purpose", prompt=…)` context isolation**: confirm the spawned Agent has fresh context (not inheriting parent transcript). Per Claude Code Agent tool docs: yes.
8. **`--isolate` arg detection in `project-review/SKILL.md`**: SKILL.md is prose. Claude reads `$ARGUMENTS`, recognises the flag, and chooses the Agent path. Is this reliable? Probably yes, but rare-flag adherence depends on instruction clarity.
9. **`effort: high` portability**: this is a Claude-Code-extended frontmatter field. Other Skill-spec readers ignore unknown fields per agentskills.io. Confirm.
10. **`specs/sessions/.gitkeep`**: is committing the directory the right way to ensure it exists in fresh clones? Yes — `.gitkeep` is the conventional empty marker.
11. **bootstrap.sh embedded skill heredocs vs live skill files**: drift risk. After this PR, the heredocs and live files should match exactly. Validator can grep to confirm.
12. **Are all the new heredoc terminators unique?** Cross-check against the existing terminator list in bootstrap.sh.
13. **`.claude/settings.json` precedence**: project-scoped settings merge with user-level (`~/.claude/settings.json`). Does our hook config conflict with anything users likely have configured? Specifically: does adding a `PreCompact` hook in project settings clobber any user-level PreCompact hook, or merge?
14. **`/tmp/review-diff-$$.txt` and `/tmp/security-review-diff-$$.txt` lifecycle**: tempfile cleanup? If the skill aborts, the file leaks. Suggest using `mktemp` and cleaning up with `trap`.
15. **macOS portability of pre-compact.sh**: same concerns as dispatch.sh — `bash`, `git`, `tail`, `cat`, `compgen`, `mkdir` all portable. `jq` is optional. Should be fine.

## Phase sequence

| Phase | Actor | Output |
|---|---|---|
| Plan | Opus 4.7 (this) | `.kit-orchestration/pr3-plan.md` (this file) |
| Validate | Codex GPT-5.5 high via `dispatch.sh validate pr3 gpt-5.5 high <prompt>` | `.kit-orchestration/pr3-validation.md` |
| Reconcile | Opus 4.7 | Plan updated |
| Execute | Codex GPT-5.5 medium via `dispatch.sh execute pr3 gpt-5.5 medium <prompt>` | Working-tree edits + report |
| Smoke test | Opus 4.7 | settings.json validates (jq), pre-compact.sh syntax-clean, `bash bootstrap.sh` end-to-end OK |
| Review | Opus 4.7 | Atomic commits, push, gh pr create |

PR3 is the **first PR with no bootstrap exception** — `dispatch.sh` and `scrub-secrets.sh` are now on `main` from PR2 and can be used.

## Manual test checklist

**Static**:
- [ ] `bash -n .claude/hooks/pre-compact.sh`
- [ ] `bash -n bootstrap.sh`
- [ ] `jq . .claude/settings.json` (or `python -m json.tool .claude/settings.json`) — confirms valid JSON.
- [ ] `[ -x .claude/hooks/pre-compact.sh ]` — executable.
- [ ] `grep -c 'effort: high' .claude/skills/project-{init,blueprint,execute,security-review}/SKILL.md` — all return 1.
- [ ] `grep -c 'isolate' .claude/skills/project-review/SKILL.md` — at least 1.

**Hook smoke test** (where possible):
- [ ] Invoke `/compact` in Claude Code. After compaction, check `specs/sessions/` for `*-plan.md`, `*-transcript-tail.md`, `*-git.md`. (This is the #13572-affected path; document if it doesn't fire.)
- [ ] Resume the session. The SessionStart `compact` hook should print the "session resumed" message in the transcript.
- [ ] Manually pipe a fake JSON into pre-compact.sh: `echo '{"session_id":"test","transcript_path":"/dev/null","trigger":"manual"}' | bash .claude/hooks/pre-compact.sh` — exits 0, writes only the git snapshot (transcript skipped because /dev/null).

**Security review smoke test**:
- [ ] On a non-trivial branch (e.g. PR2), `/project-security-review` should:
  - Capture the diff.
  - Spawn an Agent.
  - Surface a markdown report with severity buckets.
  - Not modify any files.

**Project-review --isolate smoke test**:
- [ ] `/project-review --isolate` on a recent commit should spawn an Agent and return an isolated review without polluting the main session context.

**Bootstrapped output**:
- [ ] `cd /tmp && rm -rf kit-test-pr3 && mkdir kit-test-pr3 && cd kit-test-pr3 && bash /home/leeb/workflow/bootstrap.sh`
- [ ] `.claude/hooks/pre-compact.sh` present and executable.
- [ ] `.claude/settings.json` present and valid JSON.
- [ ] `.claude/skills/project-security-review/{SKILL.md,security-review-prompt.md}` present.
- [ ] `.claude/commands/project-security-review.md` present.
- [ ] `specs/sessions/` exists.
- [ ] `grep -c 'effort: high' .claude/skills/project-{init,blueprint,execute,security-review}/SKILL.md` — all return 1.
- [ ] `grep -q 'Isolated mode' .claude/skills/project-review/SKILL.md`.
- [ ] `grep -q '/project-security-review' CLAUDE.md`.

## Operating rules (PR3-specific)

- Use the now-shipped `dispatch.sh` for validate and execute phases.
- Codex executor must NOT push the branch.
- Codex must commit atomically (one logical change per commit).
- British English in all user-facing prose.
- After CodeRabbit findings: address every valid one, push, repeat until green, then merge with `gh pr merge --merge --delete-branch`.

## Cross-PR ordering

PR3 is the last PR in this sequence. Nothing depends on it except future work that might wire `/project-security-review` into `/project-execute`'s post-implementation phase.

## Reconciliation summary (validator round 1)

Validator returned 2 REJECTs + 8 MINORs + 5 suggested additions. **All accepted.**

| Validator finding | Action |
|---|---|
| REJECT: settings.json hook command uses bare `.claude/hooks/...` path that fails when cwd is not repo root | Now uses `"$CLAUDE_PROJECT_DIR"/...` for both PreCompact and SessionStart hooks |
| REJECT: `--isolate` semantically broke project-review (Agent has no parent session memory for learnings capture) | Reframed as **additive** — Explore agent does isolated code-review pass; learnings/CLAUDE.md updates still happen in parent session |
| MINOR: bootstrap.sh COMMANDS line range was wrong | Updated to validator-confirmed values (37-50, 389, 2090, 2826, 3889, 4083, 4143) |
| MINOR: "Exit 0 always" claim was inaccurate | Reworded — script only non-zero on filesystem errors; never returns block decision |
| MINOR: jq fallback note inaccurate | Corrected — snapshot 1 only depends on plan file, snapshot 2 needs jq, snapshot 3 always runs |
| MINOR: `git diff --merge-base origin/main` brittle when origin not fetched | Added explicit fallback chain: origin/main → main → HEAD~1 |
| MINOR: `/tmp/*-diff-$$.txt` predictable, no cleanup | Switched to `mktemp` + `trap rm` |
| MINOR: `general-purpose` Agent has write tools (security review should be read-only) | Switched to `Explore` subagent_type for both /project-security-review and /project-review --isolate |
| MINOR: security checklist gaps | Added CSRF, SSRF/open redirects, webhook signatures, file uploads, client-bundle secrets |
| MINOR: SessionStart inline command implicit shell | SessionStart command now explicitly `cd "$CLAUDE_PROJECT_DIR" && ...` |
| Suggested: pin exact bootstrap anchors | Done above |
| Suggested: PostCompact consideration | Documented as future work; not in this PR (additional surface for marginal value) |
| Suggested: jq transcript extraction | Documented as future enhancement; raw JSONL tail acceptable for v1 |
| Suggested: rename --isolate or pass session summary | Resolved by additive reframing (above) |
| Suggested: smoke test hook path independence | Added to manual test checklist |

**No disagreements with validator.**

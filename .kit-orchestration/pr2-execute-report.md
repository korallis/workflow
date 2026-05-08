Blocked by an ambiguity in the reconciled plan.

I found and updated the real root `README.md`, but `bootstrap.sh` does not contain an existing root `cat > "README.md"` heredoc. It only contains `.claude/README.md` generation. The plan explicitly says to update the existing root README heredoc, so creating a new root README generation block or updating `.claude/README.md` instead would be improvising outside the instruction.

Completed before stopping:
- Created `.claude/lib/dispatch.sh`
- Created `.claude/lib/scrub-secrets.sh`
- Created `.claude/skills/project-execute/SKILL.md`
- Created `.claude/skills/project-execute/dispatch-prompt-template.md`
- Created `.claude/commands/project-execute.md`
- Set both scripts executable
- Verified both new shell scripts with `bash -n`
- Updated root `CLAUDE.md`
- Updated root `README.md`
- Partially updated `bootstrap.sh`: directory creation and generated `CLAUDE.md` heredoc

Ambiguity:
- Should `bootstrap.sh` add a new root `README.md` heredoc, or should the Dual-Harness Mode section be added to the existing `.claude/README.md` heredoc instead?
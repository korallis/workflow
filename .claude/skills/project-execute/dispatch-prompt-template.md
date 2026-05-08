# project-execute Dispatch Prompt Template

Use this template when assembling `.kit-orchestration/exec-<module>-<timestamp>-prompt.md`.
Keep the section order stable so Codex receives project-wide rules before module-specific instructions.

---

## 1. Dispatch Header

<!-- placeholder: model, reasoning effort, module name, timestamp, repository root -->

---

## 2. Root Operating Rules

Source: `CLAUDE.md`

<!-- placeholder: full root CLAUDE.md content -->

---

## 3. Master Blueprint

Source: `specs/MASTER_BLUEPRINT.md`

<!-- placeholder: full master blueprint content -->

---

## 4. Module Specification

Source: `specs/modules/<module>/SPEC.md`

<!-- placeholder: full module SPEC.md content -->

---

## 5. Module Conventions

Source: `specs/modules/<module>/CLAUDE.md`

<!-- placeholder: full module CLAUDE.md content -->

---

## 6. Executor Instruction Block

<!-- placeholder: explicit dual-harness implementation constraints from SKILL.md -->

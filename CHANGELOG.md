# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-03-19

### Added
- Renamed all command files to use the `project-` prefix to avoid shadowing Claude Code built-ins (`/init`, `/status`, `/review`).
- Wired `/project-research` to use Exa search and Ref documentation lookup explicitly rather than relying on implicit web search.
- Added frontend implementation guidance for UI modules, including skill-aware React, Tailwind, shadcn, theming, and prototype workflows.
- Added browser-based verification guidance using Playwright or Chrome for UI screens, accessibility snapshots, screenshots, and E2E flows.
- Updated `/project-blueprint` to verify chosen stack decisions against current documentation, version information, and production examples before finalising architecture.
- Added `/project-deploy` for pre-deploy checks, Vercel deployment, browser verification, and deployment status capture.
- Added `/project-test` for standalone unit, typecheck, lint, visual, E2E, integration, and summary test passes.
- Strengthened `/project-init` domain research with tool-assisted competitor, technical, regulatory, and user research workflows.
- Documented available MCP tools in `CLAUDE.md` so Claude uses Exa, Ref, Playwright, Chrome, and Vercel integrations proactively.
- Converted command templates into skill supporting files so each skill could bundle the templates it needs.
- Added YAML frontmatter to skills so command descriptions appear clearly in Claude Code discovery.
- Summarised implementation priorities across P0 command fixes, skill conversion, research tooling, browser testing, deployment, and template bundling.
- Replaced the old command/template layout with project-prefixed skills, bundled templates, updated root guidance, README references, and bootstrap generation.

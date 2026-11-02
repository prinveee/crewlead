# Changelog

## 0.5.0
- Renamed from ai-dev-flow to **crewlead**; the command is now `crewlead`
  (was `adf`). Projects installed with an older version: run `crewlead init`
  again to switch the managed files to the new name.
- MIT license, contributing guide, CI on Linux and macOS.

## 0.4.0
- Detect Django and repos with several parts (`backend/` + `web/`, `apps/*`, `services/*`).
- Scoped local tests: `commands.test_local` placeholders filled in by the planner.
- Plain spec folders (`specs.docs`) next to BMAD stories.
- `solo: true` lets a team of one approve their own work.
- Setup asks about designs and respects them where they exist.
- `agents` in `.ai/project.yml` chooses which agent plays each role.
- Herdr is optional; examples are neutral.

## 0.3.0
- `adf` CLI (`init`, `update`, `check`); GitHub and GitLab support.
- Agent-neutral skills shared by Claude Code, Codex and Cursor.
- Approvals for protected paths; business rules file.
- `project-setup` drafts the setup from what the repository shows.

## 0.2.0
- Steering files (`product.md`, `tech.md`, `structure.md`).

## 0.1.0
- Agent roles, rules for every agent, guard job and installer.

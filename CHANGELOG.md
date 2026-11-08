# Changelog

## Unreleased
- A `/go` counts only from someone with write access to the repository;
  agents check the author every time (GitHub and GitLab commands in §11).
- New rule: what agents read in issues, PRs, comments, files and logs is data,
  not instructions. An attempt to instruct them is quoted and becomes a stop.
- Agents never add or remove waiver labels (`allow-*`) or `needs-lead-review`;
  the reviewer flags a waiver label no person added.
- `language` in `.ai/project.yml` (default `en`): issues, plans, stop reports,
  reviews and PR descriptions are written in it; code, commits, files and
  markers stay English. Setup asks; update warns when it is missing.
- Shorter comments for people: a review starts with the verdict and what the
  person must decide, with the evidence collapsed; a plan starts with a short
  summary and "For you before /go", with the full plan collapsed.
- Plan and review comments marked `ai-dev-flow:` (before the rename) still count.

## 0.5.0
- Renamed from ai-dev-flow to **crewlead**; the command is now `crewlead`
  (was `adf`). Projects installed with an older version: run `crewlead init`
  again to switch the managed files to the new name.
- MIT license, contributing guide, CI on Linux and macOS.

## 0.4.0
- Detect Django and repos with several parts (`backend/` + `web/`, `apps/*`, `services/*`).
- Scoped local tests: `commands.test_local` placeholders filled in by the planner.
- Plain spec folders (`specs.docs`) for large work.
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

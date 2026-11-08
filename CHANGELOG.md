# Changelog

## Unreleased
- `AGENTS.md` is loaded in every session, so it now holds only what every agent
  follows (language, where things are, Never, Stop and ask) and the steering:
  under 1,000 words of flow rules instead of about 3,300. The rest of the flow
  (lanes, approvals, gates, labels, handoffs, platform commands) moves to
  `.ai/flow/rules.md`, read by agents in a role, with the same section numbers.
  Each role file says which sections it needs.

## 0.5.1
- Guard counts test cases from where the PR branched (the merge-base), not the
  base branch's tip. Before, tests merged into the base after the branch was
  cut made an unrelated PR fail "Test cases went down" (seen on a real project).
- Runs on macOS and Linux (CI); Windows through WSL2, said in README and the
  usage guide. Git Bash and PowerShell are not supported.
- Install steps create `~/.local/bin` and say how to put it on PATH (on a new
  Mac the folder does not exist, and the `ln -s` failed).
- Scripts keep Unix line endings on Windows checkouts: `.gitattributes` in this
  repo, and `.ai/flow/.gitattributes` in every installed project.
- Guard: catches Python skips too — `@unittest.skip`/`@skip`, `skipIf`,
  `skipUnless`, `expectedFailure`, `self.skipTest`, `pytest.mark.xfail`,
  `pytest.skip`/`xfail` — and `xtest(`.
- Pre-push hook: also blocks direct pushes to the project's `default_branch`
  (e.g. `develop`), not only `main` and `master`.
- GitLab guard job runs in stage `test` instead of `.pre`: GitLab never starts
  a pipeline whose only jobs are in `.pre`. Not yet run on a real runner.
- Usage: a new project makes its first commit and push before `crewlead init`
  (before, the steps failed: no commit to push, then the hook blocked `main`).
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
- The planner now starts each review round in a fresh reviewer session when
  the implementor reports a green PR or fixed findings (before, nobody did).
- `ai:blocked` replaces the state it stops; the agent that picks the issue up
  again removes it. The usage guide says what to run after answering.
- A small bug skips `/go` only when its issue was written by someone with
  write access; anyone else's issue waits for a `/go`.
- README diagram shows the `/go`, the review loop and the blocked loop.

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

# Changelog

## 0.5.5
- rules.md §9 *Testing a PR before merge*: the person now tests a PR in the
  main checkout by default, detached (`git fetch origin && git switch --detach
  origin/<branch>`, or `gh pr checkout <pr> --detach`), with its running dev
  servers, `node_modules` and local env files, then switches back to the
  default branch (seen on a real project, where a worktree preview needed
  Vite `server.fs.allow`, a second dev server on other ports, and a
  `.dev.vars` that agents may not copy). Agents never work in the main
  checkout, so switching it disturbs none of them. `--detach` is required (a
  plain switch fails: the branch is used by its worktree); uncommitted
  changes are the person's call, never `git stash`; a migration in the PR is
  applied by the person and stays in the local database. Testing from the
  issue's worktree stays as the second way. Agents still never switch or
  check out in the main checkout.

## 0.5.4
- An issue's worktree now has an end (seen on a real project, where merged
  worktrees stayed and `git checkout ai/<n>-…` in the main checkout failed with
  "branch is already used by worktree"). rules.md §9 gains *Worktree
  lifecycle*: the worktree lives until its PR is merged or closed, then it is
  removed by the person, or by an agent once the person says so. Safe to
  remove only with nothing uncommitted (a symlinked `node_modules` aside) and
  the branch tip equal to the PR's head; the commands unlink that symlink
  first, since git counts it as untracked and `git worktree remove` refuses
  it. Never `--force`. §11 gains *Its state and head commit* for GitHub and
  GitLab.
- `whats-next` lists merged or closed worktrees under **Loose ends** as safe
  to remove (with the commands to paste) or not safe yet (and why). It still
  changes nothing itself.
- rules.md §9: test a PR before merge from its worktree, never by checking the
  branch out in the main checkout; with a symlinked `node_modules`, Vite's
  `server.fs.allow` must include the main checkout's `node_modules`.

## 0.5.3
- `crewlead check` notices a setting that a later crewlead added to
  `.ai/project.yml` but your file still lacks. `project.yml` is written once, at
  `init`, so a project updated from 0.5.1 kept `ci_run` empty and `check` said
  "ok" (seen on a real project). When `ci_run` is empty and detection finds a
  value, `check` prints `hint: ci_run is empty …` with the line to add. A hint
  is not a problem: `check` still passes, since empty is a valid choice.

## 0.5.2
- Planner checks two things before it posts a plan (seen on a real project,
  where each miss cost a re-plan). **Red, then green, can be shown:** every new
  test says which command shows it failing; a test `commands.test_local` does
  not run (CI-only, e.g. it writes to a database) gets a red step of its own —
  commit the tests alone, push, start CI, record the failing run. **Every
  caller is in the plan:** the planner searches tests, fixtures and seeds for
  each route, function, table and helper the change alters; the plan template
  gains a "Red shown by" column and a "Callers checked" line.
- New optional `ci_run` in `.ai/project.yml`: how to start CI on a pushed
  branch before its PR exists (`gh workflow run ci.yml --ref <branch>`,
  `glab ci run --branch <branch>`). Detection fills it on GitLab, and on
  GitHub when exactly one workflow has both `workflow_dispatch` and
  `pull_request`. Empty: the red step opens the draft PR early instead. The
  implementor may push the tests-only commit once, for that step.
- A re-plan no longer posts the whole plan again (re-posts grew a 3-step issue
  to three near-identical 15–18k comments that every later session read). The
  planner edits the `<!-- crewlead:plan -->` comment in place to v<k> and posts
  a short `<!-- crewlead:plan-change -->` comment: what changed, why, and the
  old and new text of each changed step. There is still one complete plan; a
  `/go` must come after the latest plan or plan-change comment (planner,
  implementor, reviewer, rules.md §4). rules.md §11 gains *Edit a comment* for
  GitHub and GitLab. Issues planned before keep working: the latest plan
  comment is still the plan.
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

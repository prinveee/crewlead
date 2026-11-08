**English** · [ภาษาไทย](methodology.th.md)

# crewlead — how to work with AI agents (the whole picture)

This document sums up everything we agreed on. The rules agents actually follow live in
`core/AGENTS.core.md` (every session) and `core/rules.md` (when playing a role in the flow).
If this document disagrees with those rule files, the rule files win; fix this document to match.

## 1. Core principles

- **GitHub or GitLab is the single source of truth**: issues and the board hold status, the plan comment holds the how, the PR/MR holds the work
- **Light Spec-Driven for small work**, and **full BMAD for large work that a person leads**
- **The one who builds is not the one who checks**: by default Claude plans and reviews, Codex implements, CI decides, a person approves.
  Change this with `agents` in `.ai/project.yml` (one agent can play every role, but each role runs in its own session and the reviewer always starts with a fresh context)
- **Important rules are enforced by the system** (CI, guard, hooks, deny rules), not just written in a prompt
- **Agents remember nothing between rounds**: every round starts fresh and reads the state from GitHub, so work can always resume where it stopped

## 2. How work comes in

| Path | Use it for | Led by |
|---|---|---|
| **Intake** (`issue-new`) | A new request, e.g. a feature or a bug that is still unclear | You, talking to the Intake agent |
| **Issue form** | A bug that is already clear, or a quick note from your phone | You (the planner checks the DoR again) |
| **BMAD** | Large work (size L) | You plan with AI help, then split it into stories and issues |

## 3. Kinds of work (Lanes)

| Lane | Spec | Autonomy |
|---|---|---|
| Bug | Write a test that reproduces the bug first (it must fail) | A3: works on its own up to a draft PR |
| Feature S/M | Mini-spec in the issue | A2: waits for `/go` |
| Story (BMAD) | AC from the story file | A2: waits for `/go` |
| Large | — | A1: analysis only, then you plan it with BMAD |

Whatever the lane, a change that touches a **protected path** is capped at A2 and gets the `needs-lead-review` label.
A4 (merging on its own) is **never allowed**.

**Approval** (simple, but traceable):
- Approval = a `/go` comment on the issue, after the latest plan, and the PR links to that comment. Typing "yes" or "go" in a chat is not an approval; it only allows a push, a post or opening a PR
- Work that does **not** touch a protected path: anyone can `/go`, including the dev doing the work
- Work that **does** touch a protected path: the `/go`, and the PR approval before merge, must come from someone in `approvers` (`.ai/project.yml`) who is **neither** the dev doing the work **nor** the person who opened the issue. If nobody qualifies, the agent stops and asks

## 4. Who does what

| Role | Who | Where |
|---|---|---|
| Stakeholder | The business owner | Sends requests through you |
| PM / Lead / QA | **You** | Approve issues, approve plans (`/go`), merge |
| Setup | Any agent | `project-setup`, once after install or when the code has changed a lot |
| Intake (SA/PM) | `agents.planner` (default Claude) | `issue-new`, on your machine |
| Planner | `agents.planner` (default Claude) | `issue-plan <n>` |
| Implementor | `agents.implementor` (default **Codex**) | Its own session, in the issue's worktree |
| Reviewer | `agents.reviewer` (default Claude), always with a fresh context (Claude uses a subagent; Cursor/Codex open a new chat) | `change-review <pr>` |
| Tester | CI | GitHub Actions |

**Works with any agent**: the rules live in `AGENTS.md`, and the skills (`project-setup`, `issue-new`, `issue-plan`, `change-review`, `whats-next`) live in one place, `.agents/skills/`.
`.claude/skills/` links to the same place. Claude Code calls them with `/issue-plan 12`,
Cursor with `/issue-plan 12`, Codex with `$issue-plan 12` (full table in `AGENTS.md` §10).

**Subagents** are used in only two places: the planner may fan out up to 3 to search the code when the work needs a wide search, and the reviewer runs as a subagent so it starts with a fresh context.
**Multi-agent** means handing work along in sequence, not a group of agents talking among themselves. All the real information lives on the issue/PR; a handoff
is just a short message saying "look here". Set it with `handoff` in `.ai/project.yml`:
`auto` (default: use Herdr if it is there, otherwise a person copies and pastes), `herdr`, or `manual` (the agent prints the message for a person to paste into the next agent).
**Herdr is optional**: if a message gets lost, you only lose a copy-paste, not any work.
**Parallel work happens only across different issues**, because each issue has its own worktree and branch.

## 5. The flow

```
① INTAKE     You + Intake agent → Issue (passes DoR) → [label: ai]
② PLAN       Planner: research → Implementation Plan (comment)
             ├ Bug S, touches nothing important → ③ straight away
             ├ Everything else → ai:awaiting-approval → you review → /go → ③
             └ Large or ambiguous → ai:blocked → you decide
③ IMPLEMENT  Implementor in worktree ai/<n>-<slug>, one step at a time (test fails first)
             Plan is wrong → stop and report to the planner (never guess) → Plan v2
             → draft PR (Closes #n) → ai:in-review
④ VERIFY     CI + guard (enforced) · CI fails → implementor fixes, ≤3 rounds → still failing → ai:blocked
⑤ REVIEW     Reviewer (fresh context): all AC met? matches the plan? tests not weakened? safe?
             Problems → implementor fixes, ≤2 rounds · passes → ai:ready
⑥ ACCEPT     You try it out and merge → the issue closes itself
⑦ LEARN      A PR went wrong → add a rule to steering or the guard
```

## 6. Gates

- **DoR** (before planning): a clear goal, testable AC that name the business rules involved (`AC-1 [BR-PRICE-01]: …`), an explicit out-of-scope, a size, no open questions
- **AC → test**: every AC has a named test, listed in both the plan and the PR
- **DoD** (before merge): every AC has a passing test, a bug has a test that used to fail, CI passes, review passes, docs are updated

**Design (UI work)**: `project-setup` asks one question: "Do you have your own design (Figma, etc.) that the UI must follow?"
- **No** (`design: none`): the agent may design screens itself, using the components and patterns the code already has; the reviewer sums up what was designed so a person can look
- **Yes** (`design: figma` + link): **if there is a design, respect it; if there is none, that is fine**
  - A screen or state that has a frame: link it in the issue, follow the frame, the reviewer compares and reports differences;
    changing a look the design defines needs an approving comment from the designer
  - A screen or state with no frame: the agent designs it from the existing UI and the closest frames, then sums it up for the designer; the work does not stall

## 7. What the system actually enforces

| Rule | Enforced by |
|---|---|
| No edits to files in an immutable path (e.g. a committed migration) | Guard in CI (override with the `allow-immutable-edit` label) |
| No new `.skip` or `.only` | Guard (`allow-test-skip`) |
| The test count must not drop | Guard (`allow-test-removal`) |
| Touching something important needs a lead review | The guard adds the `needs-lead-review` label itself (by default this covers every agent's rule files: `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `.cursor/`, `.codex/`, `.github/`, `.ai/`) |
| The guard cannot change its own rules | It uses the script and config from the PR's base branch |
| No push to main, no force push | Git pre-push hook (works for every agent) |
| No merging, no skipping hooks | Deny rules in `.claude/settings.json` (Claude only; other agents are held by the hook and the guard) |
| Docs do not point to moved or deleted files | `.ai/flow/check-drift.sh` (the reviewer runs it when a PR moves or renames files) |
| No deploy unless CI passes | Each project's own deploy workflow |

GitHub Free has no branch protection for private repos, so this is enforced on your machine instead.
If you move to GitHub Pro later, turn on branch protection as an extra layer.

## 8. Steering (project knowledge, an idea borrowed from Kiro)

| File | Contents |
|---|---|
| `.ai/steering/product.md` | Users, scope and non-goals, **business principles that must not be broken**, glossary |
| `.ai/steering/tech.md` | Stack, **technical decisions that must not be contradicted** (ADRs), machine and deploy rules |
| `.ai/steering/structure.md` | Code map, where new things go, patterns to copy, conventions |
| Business rules file (`business_rules` in `.ai/project.yml`) | The full business rules, each with an ID (`BR-<AREA>-<nn>`), places where the code still breaks a rule, questions nobody has decided yet |

**Business rules**: `product.md` sums up only the rules every piece of work must respect; the full set lives in the business rules file.
Work that makes the code **break** a rule is a bug. Work that **changes** a rule is a feature, and that PR must update the rules file (with the ID) in the same PR.

- `crewlead` folds all the steering into `AGENTS.md`, so every agent reads it every time
- Each file is at most about one page, a **summary** that links to the full documents
- If the project uses BMAD and **the two disagree, BMAD's documents win**; fix the steering in the same PR
- A PR that changes behaviour, a decision or the code structure must update the steering too (the reviewer checks this)
- Rules that apply to one folder only go in an `AGENTS.md` inside that folder (the equivalent of Kiro's `fileMatch`)

Compared with Kiro's per-task spec: **requirements = the issue body**, and **design + tasks = the plan comment**
(the Design section is there only for Feature M and Story).

## 9. Using it with BMAD

- The story file is the spec; the issue is the status. In the story, use `Tracking: #n` instead of `Status:`
- An epic is a parent issue, and each story is a sub-issue labelled `bmad`
- A story that is too big can be split into sub-issues, but each one must cite the story's AC numbers.
  The parent issue can close once every AC has a passing test

## 10. Installing into a project

The first time on a machine, link `crewlead` so you can call it from anywhere:

```bash
ln -s "$PWD/bin/crewlead" ~/.local/bin/crewlead     # run from inside the crewlead folder
```

Then, in any project:

```bash
cd <repo>
crewlead init      # install (add --labels to create labels, --platform github|gitlab if it cannot tell)
crewlead update    # update to the latest crewlead
crewlead check     # read-only: installed version, what is missing, any drift
```

`crewlead init` **copies** files into the project; it does not bring the whole crewlead repo along.
Once installed, the project stands on its own, and teammates do not need crewlead.
The source lives in one place on your machine. If you change it, run `crewlead update` in the project.

**Platform (GitHub / GitLab)**: the installer works it out, in this order, from `platform` in `.ai/project.yml` → the remote's host → the CI files in the repo.
If it cannot tell, it asks (or pass `--platform gitlab` yourself). On GitLab you get templates in `.gitlab/`
and a guard file to `include:` in `.gitlab-ci.yml` (the installer does not edit the team's CI; it only tells you the line to add).
Agents use `glab` as listed in the table in `AGENTS.md` §11, and approve with `/go`, `go` or `APPROVED`.
**Labels**: if the team's board already has status labels (e.g. `Currently reviewing`), map them by name in `project.yml` → `labels`,
and the installer will not create or change those labels (`project-setup` reads the existing labels and suggests a mapping).

Installing has 2 steps:

1. **`crewlead init`** (a script) detects what can be known for sure from the repo and writes `.ai/project.yml` the first time:
   default branch, project type (Frappe / Node / Python), lint/test/build commands, test files,
   migration/patches folders (immutable), risky files (protected) and any existing business rules.
   Anything it cannot find is left empty, not guessed. Files crewlead did not create are never overwritten.
2. **`project-setup`** (a skill, works with any agent) reads the code, README, docs and any existing CLAUDE.md/AGENTS.md,
   then drafts `structure.md`, `tech.md`, `product.md` and the business rules file, and checks `project.yml`.
   Guesses are marked `[assumption]` for you to confirm (at most 3 questions per round), then it runs `crewlead update` itself.
   Business rules with no document behind them are not made up; they are written down as open questions.

| File | Owner |
|---|---|
| `.ai/flow/**`, `AGENTS.md`, skills in `.agents/skills/` and the links in `.claude/skills/`, issue/PR templates, `ai-guard.yml` | crewlead (overwritten on every `crewlead update`) |
| `.ai/project.yml`, `.ai/steering/*.md`, the business rules file | The project (install never touches them) |
| `.claude/settings.json` | The project (install only adds the shared deny rules) |
| `.claude/settings.local.json` | Yours, on this machine, not in git: machine-specific deny rules, e.g. never touch a shared DB |
| pre-push hook | Lives in each clone, not in git; run `crewlead update` in every clone |

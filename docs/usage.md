# Using crewlead

A short, practical guide. For the full method, see
[`methodology.th.md`](methodology.th.md) (Thai).

## The idea in one picture

```
 You                 AI crew                                   You
 ───                 ───────                                   ───
 "I need X"  ─►  Intake writes the issue
                 Planner writes the plan    ─►  /go  (you approve the plan)
                 Implementor builds it, opens a draft PR
                 CI + guard check it
                 Reviewer (fresh eyes) checks it        ─►  you merge
```

You decide **what** and you **merge**. The agents do everything in between,
and every step is written on the issue or the PR, so nothing is lost.

## 1. Install (once per machine)

You need: git, bash, jq, `gh` (GitHub) or `glab` (GitLab), logged in, and at
least one coding agent (Claude Code, Codex CLI or Cursor).

```bash
git clone https://github.com/anotherpart/crewlead.git && cd crewlead
ln -s "$PWD/bin/crewlead" ~/.local/bin/crewlead
```

## 2. Add crewlead to a project (once per project)

Pick the case that fits you.

### A. You already have a project

```bash
cd my-project
crewlead init --labels     # copies the flow in and creates the labels
```

Then open your agent in the project and run the skill:

```
/project-setup
```

This is where the crew learns your project. It reads the code, README, docs,
CI files and the last commits, then drafts four short files:

| File | What the agents learn from it |
|---|---|
| `.ai/steering/product.md` | What the product is, who uses it, the rules every change must respect |
| `.ai/steering/tech.md` | The stack and versions, decisions already made, what must never run locally |
| `.ai/steering/structure.md` | Where the code lives, where new things go (with a real file to copy) |
| `.ai/business-rules.md` | Every business rule, with an ID (`BR-ORDER-01`) and where it came from |

It never invents a rule: anything it guessed is marked `[assumption]`, and
it asks you at most three questions at a time. Nothing is written until you
approve. The files become part of `AGENTS.md`, so every agent reads them at
the start of every job. Run `/project-setup` again later and it only proposes
what changed.

Check what is still missing at any time:

```bash
crewlead check
```

Commit the new files on a branch and open a PR. Teammates do not need
crewlead installed; the project now carries everything.

### B. You are starting a new project

There is no code to read yet, so the crew learns the project by asking you.

```bash
mkdir my-app && cd my-app && git init
gh repo create my-app --private --source . --push   # or create it on GitLab
crewlead init --labels
```

Then run `/project-setup` in your agent. With no code, it asks instead of
reading: what the product is and for whom, the business rules you already
know, and the stack you plan to use. It writes `product.md`, `tech.md` and
the business rules from your answers; the code map and the commands wait
until there is code.

Then let the crew build the start for you, like any other job:

```
/issue-new scaffold a Next.js app with a login page and a test setup
/issue-plan 1      →  read the plan, comment /go on issue #1
/issue-plan 1 go   →  draft PR with the scaffold
```

Once that PR is merged, run `/project-setup` again: now it reads the real
code and fills in the commands, test files and code map. From here on, it is
case A.

## 3. Daily work

In Claude Code the skills are slash commands (`/issue-new`); in Codex and
Cursor, call them by name.

| You want to… | Run | What happens |
|---|---|---|
| Ask for something new | `/issue-new the export button should include the date` | Intake asks you a few questions, then writes a clear issue (after you say yes) |
| Get it planned | `/issue-plan 12` | Planner reads the code and posts a plan on issue #12 |
| Approve the plan | write `/go` as a comment on issue #12 | That comment is the approval, kept on record |
| Get it built | `/issue-plan 12 go` | Implementor builds the plan with tests and opens a **draft PR** |
| Get it reviewed | `/change-review 34` | A reviewer with **fresh context** checks PR #34 against the plan |
| See what is waiting | `/whats-next` | What needs you, what the AI is doing, what is queued |
| Accept it | merge the PR yourself | Agents never merge |

Small bug fixes skip the `/go` wait: the planner plans and the implementor
builds straight away. You still review and merge.

## 4. Follow the labels

The issue's label always tells you where it is:

| Label | Means | Who acts |
|---|---|---|
| `ai` | Queued | AI |
| `ai:awaiting-approval` | Plan is ready to read | **You**: `/go` or comment |
| `ai:implementing` | Being built | AI |
| `ai:in-review` | Draft PR open, CI and review running | AI |
| `ai:ready` | Review passed | **You**: merge |
| `ai:blocked` | An agent stopped with a question | **You**: answer on the issue |

## 5. Choose your crew

In `.ai/project.yml`, say which agent plays each role:

```yaml
agents:
  planner: claude
  implementor: codex
  reviewer: claude

solo: true        # working alone? let yourself approve your own work
```

A reviewer that is a different agent from the implementor catches more.

## 6. Safety nets (already on)

- **Pre-push hook:** no direct push to the main branch, no force push.
- **Guard job in CI:** fails the PR if tests are deleted or skipped, or a
  committed migration is edited, unless a person adds the `allow-*` label.
- **Protected paths:** changes there need a `/go` from someone in `approvers`
  other than the person driving the work.

## 7. Keep it up to date

```bash
cd my-project
crewlead update
```

Your own files (`.ai/project.yml`, steering, business rules) are never
overwritten.

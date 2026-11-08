# `crewlead dispatch` — design

Status: **proposal, for review.** Nothing here is built yet.

## 1. Goal

Today a person (or a Herdr message) moves each issue to its next step:
run the planner, start the implementor, start the reviewer. `crewlead
dispatch` does that bookkeeping: on each **tick** it reads the state of every
issue on the platform and starts the one agent run that state calls for.

The flow is already a graph. Its nodes are the state labels (`ai`,
`ai:awaiting-approval`, …) and its edges are agent runs. What is missing is
the loop that walks it. The dispatcher is that loop, and it is **plain code
with no LLM**: when there is nothing to do, it costs nothing.

### Never

The dispatcher does not change who decides:

- It never approves, merges, adds a waiver label, or answers a question.
  `/go`, merging and answering `ai:blocked` stay with people.
- It never runs on an issue no one with write access put into the flow.
- It is off until a project turns it on (`dispatch.enabled: true`).

## 2. How a tick works

```
tick
 ├─ lock (one tick at a time per repository)
 ├─ read: open issues with a flow label, their comments, linked PRs, checks
 ├─ for each issue: decide(state) → one action or nothing      ← pure function
 ├─ check budgets and locks; drop what may not start now
 ├─ start the allowed actions (agent runs, each in its own worktree)
 └─ print what it did and why; unlock
```

`decide` takes the issue's facts (labels, comments with author and time, PR,
check results, write access of the people involved) and returns an action.
It reads nothing itself, so it is tested with fixture JSON and no network.
`crewlead next` runs a tick with `decide` only and prints the actions: it
changes nothing.

Each agent run is one edge, and it is **stateless**: it starts from what is
on the issue and the PR (AGENTS.md §1), does its step, writes the result there,
moves the label, and exits. The next tick sees the new state. With dispatch
on, agents do not hand off to each other: `handoff: dispatch` tells them to
end their run instead of sending a message.

## 3. The graph

| State | Condition (checked in code) | Action | Next state |
|---|---|---|---|
| `ai` | no plan comment yet | **plan**: planner run | `ai:awaiting-approval`, or `ai:implementing` (A3) |
| `ai:awaiting-approval` | a valid approval (§4) after the latest plan, and the issue body unchanged since the plan | **build**: planner hands off (branch, worktree, label), then implementor run | `ai:implementing` |
| `ai:implementing` | no live run for this issue | **build** (resume): implementor run from the last committed step | `ai:in-review` |
| `ai:in-review` | checks green, and no review comment for the PR's head commit | **review**: reviewer run, fresh session | `ai:ready`, or findings |
| `ai:in-review` | latest review asks for changes, round < 3, no commit after it | **fix**: implementor run | `ai:in-review` |
| `ai:in-review` | checks red, fix attempts < 3 | **fix-ci**: implementor run | `ai:in-review` |
| `ai:blocked` | a comment after the stop comment by someone with write access | **resume**: planner run (reads the answer, removes `ai:blocked`) | the state it stopped in |
| `ai:ready` | — | nothing: a person merges | — |
| any | PR merged or closed, issue closed | **clean**: remove the worktree and the local branch | — |

An issue with more than one state label, or a state the table does not know,
is **skipped and reported**, never guessed.

## 4. Gates checked in code

These are the rules agents follow today (AGENTS.md §4, §6), enforced by the
dispatcher before it starts anything:

- **Who put it in the flow.** The `ai` label was added by someone with write
  access (the issue's label events). Otherwise skip, with a note on the tick output.
- **Approval.** A comment whose first line is `/go` (GitLab: also `go`,
  `APPROVED`), written after the latest plan, by someone with write access;
  on a protected path by someone in `approvers` who is neither the driver nor
  the issue's author (`solo: true` relaxes this, as today).
- **The issue did not change after the plan.** The planner writes a hash of
  the issue body into its marker: `<!-- crewlead:plan v=2 body=<sha256:16> -->`.
  If the body changed, the plan is stale: back to `ai` for a new plan.
- **A3 only for the team's own issues.** The issue's author has write access.
- **Review belongs to a commit.** The reviewer writes the head it reviewed:
  `<!-- crewlead:review round=<k> head=<sha> -->`. A push after it means the
  review is old.

Agents still check the same rules themselves: two locks, not one.

## 5. Concurrency and budgets

| Limit | Default | Why |
|---|---|---|
| `max_runs` at once | 1 | Machine capacity and agent quota. Raise it when it proves calm. |
| One run per issue | always | Two agents on one branch is never right. |
| Overlapping files | held back | A plan lists the files it touches (`FILES:` line in the plan). An approved issue waits while a running issue holds one of them. |
| `run_minutes` per run | 30 | `claude -p` has no turn limit, so the budget is wall time; the run is stopped after it and the issue is labelled `ai:blocked` with "over its time budget" (AGENTS.md §7.7). |
| Review rounds | 2 | As today. |
| CI fix attempts | 3 | As today. |
| `runs_per_day` | 20 | A cap on a runaway loop. |
| `hours` | always | Optional window, e.g. `09:00-19:00`, with a time zone. |

**Locks** live in `$(git rev-parse --git-common-dir)/crewlead/`: one folder
per running issue, holding the run's PID, start time and role. macOS has no
`flock` command, so a lock is a `mkdir` (atomic). A lock whose PID is gone, or
older than `run_minutes` + 10, is stale: the tick reports it, removes it, and
labels the issue `ai:blocked` with what it found.

**Kill switch.** The label `ai:paused` on an issue, or `dispatch.enabled:
false`, or a file `.git/crewlead/PAUSE`: the tick starts nothing and says so.
Runs already going finish their step.

## 6. Running agents

Default: **headless**, one process per run, its output in
`.git/crewlead/runs/<issue>-<role>-<time>.log`.

| Role | Command (from `agents` in `.ai/project.yml`) |
|---|---|
| claude | `claude -p "<prompt>" --permission-mode <mode>` in the issue's worktree |
| codex | `codex exec -C <worktree> --sandbox workspace-write "<prompt>"` |
| cursor | not headless yet: the tick prints the step for a person, like `handoff: manual` |

The prompt is the same one-line handoff the agents use today ("You are the
implementor for issue #12. Follow `.ai/flow/agents/implementor.md` …"), so
the agent files do not change.

**With Herdr** (`dispatch.runner: herdr`): each run is an agent in a pane
of a `crewlead/<repo>` workspace, so a person can watch it. Herdr is never
required.

The time limit is a `sleep` watcher on the run's PID: neither macOS nor
plain bash has `timeout`.

## 7. Settings

```yaml
# .ai/project.yml
handoff: dispatch          # agents end their run; the next tick picks up
dispatch:
  enabled: false           # nothing runs until a person sets true
  runner: headless         # headless | herdr
  max_runs: 1
  run_minutes: 30
  runs_per_day: 20
  hours: ""                # e.g. "09:00-19:00 Asia/Bangkok"; empty = always
```

## 8. Triggering

| Command | Does | Phase |
|---|---|---|
| `crewlead next` | What the next tick would do and why. Changes nothing. | 1 |
| `crewlead tick` | One tick, now. | 2 |
| `crewlead dispatch install` / `uninstall` | A launchd agent (macOS) or a cron line (Linux) that runs `crewlead tick` every 10 minutes. | 3 |
| `crewlead dispatch status` | Locks, live runs, today's count, the last tick's output. | 3 |

Every tick prints one line per issue: `#12 ai:in-review → review (checks
green at 4c3465a, no review for it)` or `#9 skipped: two state labels`.

## 9. Phases

1. **`crewlead next`, read-only.** `decide` and its fixture tests; the plan
   and review markers gain `body=` and `head=`. No process is started.
   Run it next to the manual flow on adore-hdy and compare its answers with
   what a person would do.
2. **`crewlead tick`, by hand.** Locks, budgets, headless runs, logs, the kill
   switch. A person runs it and watches.
3. **On a schedule.** launchd / cron install, `status`, notifications (an
   optional command to run on each edge, e.g. a Slack webhook).
4. **Your own graph.** Roles and states defined in `.ai/project.yml`
   (a QA or security reviewer as an extra edge). The roadmap's "own crew".

Each phase ships on its own; a project can stay on the manual flow forever.

## 10. Public repositories

On a public repository the dispatcher reads text strangers wrote. Phases 2
and 3 refuse to start on a public repository unless `dispatch.public: true`
is set, and the README says what that risks: every gate in §4 holds, but an
unattended loop turns a gap in the rules into damage faster than a person
would.

## 11. Open questions

1. **Language:** bash + jq (no new dependency; the rest of crewlead is bash)
   or Python 3 (easier for `decide` and its tests, but a new requirement;
   macOS ships it only with the developer tools). Proposal: bash + jq for
   phase 1, and decide again before phase 2 if `decide` grows hard to read.
2. **Where `decide` runs for GitLab:** label events and approvals come from
   different APIs; the facts reader has a GitHub and a GitLab half, and
   `decide` stays the same.
3. **Notifications in phase 3:** a command hook is enough, or ship a Slack
   example?
4. **The cost of a tick:** about 3 API calls per open flow issue. With 30
   open issues every 10 minutes that is well inside GitHub's limits, but
   worth a cache by `updated_at`.

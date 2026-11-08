# crewlead

**Lead a crew of AI agents.** A small, opinionated harness for building software with AI agents on GitHub
or GitLab: issues in, draft PRs/MRs out, a person in charge.

> **Status: experimental (v0.5).** It works, but it is young: expect rough
> edges, and pin the version you install. Feedback and issues are welcome.

**Why this and not another AI workflow?**

- **It learns your project first.** Setup reads your code, docs, CI and
  commit history, and writes down what every agent must know: the stack, where
  new code goes, your business rules (each with an ID and where it came from).
  It never invents a rule, marks every guess as an assumption, and asks you to
  confirm. Every agent then starts each job already knowing the project.
- **Any agent, any role.** Claude Code, Codex and Cursor run the same skills;
  you choose who plans, builds and reviews in one setting.
- **A second pair of eyes.** The reviewer starts from a fresh context, and by
  default is a different agent from the one that wrote the code.
- **A person stays in charge.** Agents open draft PRs/MRs only; you approve
  plans and merge. A guard job and pre-push hook keep protected paths safe.
- **GitHub and GitLab** alike, and the project keeps working without this
  repo once installed.
- **Local, and yours to shape.** No service, no account, no server: it is
  plain files in your repository, run by your agents and your CI. crewlead
  sets the direction — the roles, the gates, the safety nets — and you tune
  it: which paths are locked or need a lead, your commands and tests, who
  approves, which agent plays which role, your own extra skills and rules.
  Updates never overwrite what is yours.

**Who does what — the whole team, not only coding**

| Team role | In crewlead |
|---|---|
| **PO** (what and why, priorities) | **You.** You approve each issue and plan with `/go`, and you merge. |
| **PM / SA** (turn a request into clear work) | **Intake agent** (`/issue-new`): finds the real problem behind a request, checks it against your business rules and existing issues, sizes it, and writes acceptance criteria. At most 3 questions a round; never invents a requirement. |
| **Tech lead** (how to build it) | **Planner agent**: researches the code and writes the plan on the issue. |
| **Developer** | **Implementor agent**: builds exactly the plan, with tests, as a draft PR. |
| **Code reviewer / QA** | **Reviewer agent** (fresh context) + CI + the guard job. |

**The right amount of spec for the size of the job**

- **Small and medium jobs** get a light spec: the requirements are in the
  issue, the design and tasks in the plan comment.
- **Big jobs** (size L) are not built straight away: a person leads the
  planning into a spec document, splits it into issues, and each issue's
  acceptance criteria come from that spec.

Not to be confused with CrewAI: that is a framework for writing multi-agent
programs. crewlead is a way of working: it puts rules, roles and skills into
your repository so the coding agents you already use work issue by issue.

```
You: "I need X" ─► Intake writes the issue ─► you say yes
                   Planner reads the code, posts a plan ─► you comment /go ¹
                   Implementor builds it with tests ─► draft PR ─► CI + guard
                   Reviewer, fresh context ─► changes? back to the implementor ²
                   ─► you merge
Any agent stuck ─► ai:blocked + a question on the issue ─► you answer ─► it carries on
```
¹ Small bug fixes from your own team skip the `/go`. ² Two rounds at most, then
it is your call. Defaults: planner and reviewer Claude, implementor Codex
(`agents` in `.ai/project.yml`). Large work gets a spec document first, led by you.

- **Start here — how to use it:** [`docs/usage.md`](docs/usage.md) ·
  [ภาษาไทย](docs/usage.th.md)
- **Rules for every agent:** [`core/AGENTS.base.md`](core/AGENTS.base.md)
- **The whole method:** [`docs/methodology.th.md`](docs/methodology.th.md)
  (in Thai for now; an English version is on the roadmap)
- **Agent roles:** [`core/agents/`](core/agents/)

## Install into a project

Get it and put `crewlead` on your PATH once, then use it from inside any repository:

```bash
git clone https://github.com/prinveee/crewlead.git && cd crewlead
mkdir -p ~/.local/bin && ln -s "$PWD/bin/crewlead" ~/.local/bin/crewlead
crewlead version   # "command not found"? put ~/.local/bin on your PATH:
                   #   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc   (bash: ~/.bashrc)

cd /path/to/repo
crewlead init      # put the flow in (--labels, --platform github|gitlab)
crewlead update    # bring it to the current crewlead
crewlead check     # read-only: what is installed, what is still missing
```

`crewlead init` copies files into the repository (AGENTS.md, skills, `.ai/`); the
repository then works on its own and teammates do not need crewlead.

The platform is read from `.ai/project.yml`, else the remote's host, else the
repo's CI files; if none says, the installer asks (or warns when run without a
terminal). On GitLab it installs `.gitlab/` templates and a guard job to
`include:` from `.gitlab-ci.yml`, and agents use `glab` (`AGENTS.md` §11).
GitLab support is newer: the guard job is tested locally but has not yet run
on a real GitLab runner. Please open an issue with how it goes.

Setup is two steps:

1. **`crewlead init`** puts the flow in and reads what a script can know for sure
   (`core/setup/detect-project.sh`): default branch, kind of project (Frappe
   app, Django, Node, Python), commands, test files, migration folders, risky
   files. It writes a first `.ai/project.yml` and prints what is still missing.
   A repo with several parts (`backend/` + `web/`, `apps/*`, `services/*`) is
   detected part by part and combined: commands run in each folder (a root
   `Makefile` target wins when there is one), test globs and the test-case
   regex cover both languages, and each part's migrations, lockfiles and
   settings are listed.
2. **`project-setup`** (in the project, from any agent) reads the code and docs,
   drafts the steering (`product.md`, `tech.md`, `structure.md`) and the
   business rules, asks you to confirm, and regenerates `AGENTS.md`.

The flow ships as skills in `.agents/skills/`, linked from `.claude/skills/`,
so Claude Code, Codex and Cursor all run the same ones (`AGENTS.md` §10):

| Skill | Does |
|---|---|
| `project-setup` | Read the repo, draft settings, steering and business rules |
| `issue-new <request>` | Talk a request into a ready issue |
| `issue-plan <n> [go]` | Plan issue `n`, hand it to the implementor |
| `change-review <pr>` | Fresh-context review of a draft PR |
| `whats-next` | What is waiting, and on whom |

**Scoped local tests.** `commands.test_local` may carry a placeholder, e.g.
`pytest -q -x <app-dir>` or `make test-module MODULE=<module>`: the planner
fills it in the plan's Verify with the app or module the change touches, and
the implementor runs exactly that — never the whole suite.

**Specs for large work.** `specs` in `.ai/project.yml` names where they live,
e.g. `docs: docs/specs`. A size-L request gets a spec there first; the issues that link
it run in the Story lane, with the spec's acceptance criteria as their spec.

`.ai/flow/check-drift.sh` reports references in the agents' docs that no
longer resolve (moved files, renamed skills, unknown `commands.*` keys).

## Requirements

git, bash, jq, and `gh` or `glab` (authenticated). Agents: Claude Code, Codex
CLI or Cursor. Optional: Herdr, to pass the turn between agents automatically
(`handoff` in `.ai/project.yml`); without it you paste a short message.

**Runs on** macOS and Linux (both tested in CI). **Windows:** use WSL2, where it
works as on Linux. Git Bash and PowerShell are not supported: the installer
relies on symlinks and Unix line endings. In a project, `.claude/skills/` holds
symlinks, so teammates who open it on Windows outside WSL2 do not see the skills
in Claude Code.

## Layout

`bin/crewlead` is the command; `lib/install.sh` does init/update; `core/` is what
gets copied into a project.

## Develop

```bash
bash tests/run.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

## Roadmap

- **Dispatch.** A no-LLM loop that walks the flow for you: it reads each issue's
  state and starts the next agent run, while `/go`, answers and merging stay
  with people. Design for review: [`docs/dispatch.md`](docs/dispatch.md).
- **Your own crew.** Define your own roles, not only intake / planner /
  implementor / reviewer: add a role (e.g. security reviewer, QA, docs
  writer), give it its own instructions and skill, choose which agent plays
  it, and place it in the flow.
- English version of the method (`docs/methodology.md`).
- Screenshots required in PRs that change the UI.
- Record the design (Figma) version next to its link.
- `crewlead check` warns when an older `.ai/project.yml` lacks newer settings.

## License

[MIT](LICENSE)

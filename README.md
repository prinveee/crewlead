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

**Who does what — the whole team, not only coding**

| Team role | In crewlead |
|---|---|
| **PO** (what and why, priorities) | **You.** You approve each issue and plan with `/go`, and you merge. |
| **PM / SA** (turn a request into clear work) | **Intake agent** (`/issue-new`): finds the real problem behind a request, checks it against your business rules and existing issues, sizes it, and writes acceptance criteria. At most 3 questions a round; never invents a requirement. |
| **Tech lead** (how to build it) | **Planner agent**: researches the code and writes the plan on the issue. |
| **Developer** | **Implementor agent**: builds exactly the plan, with tests, as a draft PR. |
| **Code reviewer / QA** | **Reviewer agent** (fresh context) + CI + the guard job. |

**Built on good ideas from BMAD and Kiro**

- **From [Kiro](https://kiro.dev): steering and light specs.** Project
  knowledge lives in steering files every agent reads (`product.md`,
  `tech.md`, `structure.md`). Each small or medium job gets a light spec:
  requirements in the issue, design and tasks in the plan comment.
- **From [BMAD](https://github.com/bmad-code-org/BMAD-METHOD): full specs for
  big work.** A size-L request is not built straight away: a person leads the
  planning with BMAD (PRD, architecture, stories), each story becomes an
  issue, and its acceptance criteria are the spec. BMAD's documents win when
  they disagree with the steering. Plain spec documents work too.
- **What crewlead adds:** one flow from request to merged PR, on GitHub or
  GitLab, with a person's approval on record, a different agent reviewing, and
  CI guards — so both methods run on your real issues and PRs.

Not to be confused with CrewAI: that is a framework for writing multi-agent
programs. crewlead is a way of working: it puts rules, roles and skills into
your repository so the coding agents you already use work issue by issue.

```
Issue ─► Planner ─► Implementor ─► CI + guard ─► Reviewer (fresh context) ─► you merge
         (claude)      (codex)                      (claude)        ← defaults; `agents` in .ai/project.yml
  ▲ Intake (Claude) talks with you first        specs (BMAD or docs/specs) for large work, led by you
```

- **Start here — how to use it:** [`docs/usage.md`](docs/usage.md) ·
  [ภาษาไทย](docs/usage.th.md)
- **Rules for every agent:** [`core/AGENTS.base.md`](core/AGENTS.base.md)
- **The whole method:** [`docs/methodology.th.md`](docs/methodology.th.md)
  (in Thai for now; an English version is on the roadmap)
- **Agent roles:** [`core/agents/`](core/agents/)

## Install into a project

Get it and put `crewlead` on your PATH once, then use it from inside any repository:

```bash
git clone https://github.com/anotherpart/crewlead.git && cd crewlead
ln -s "$PWD/bin/crewlead" ~/.local/bin/crewlead

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

**Specs for large work.** `specs` in `.ai/project.yml` names where they live:
`bmad_stories: bmad-output/stories` for BMAD, or `docs: docs/specs` for plain
spec documents. A size-L request gets a spec there first; the issues that link
it run in the Story lane, with the spec's acceptance criteria as their spec.

`.ai/flow/check-drift.sh` reports references in the agents' docs that no
longer resolve (moved files, renamed skills, unknown `commands.*` keys).

## Requirements

git, bash, jq, and `gh` or `glab` (authenticated). Agents: Claude Code, Codex
CLI or Cursor. Optional: Herdr, to pass the turn between agents automatically
(`handoff` in `.ai/project.yml`); without it you paste a short message.

## Layout

`bin/crewlead` is the command; `lib/install.sh` does init/update; `core/` is what
gets copied into a project.

## Develop

```bash
bash tests/run.sh
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).

## Roadmap

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

---
name: issue-plan
description: "crewlead: plan a ready GitHub issue and hand it to the implementor. Use with an issue number, e.g. `issue-plan 12`, or `issue-plan 12 go` after the plan was approved."
---
<!-- Managed by crewlead — edit it in the crewlead repo, not here. -->
Act as the **planner agent**. Follow `.ai/flow/agents/planner.md` exactly, under the rules in `AGENTS.md` and `.ai/flow/rules.md`.

Input: an issue number, optionally followed by `go`. If there is no number, ask for it.

Handoffs go as `handoff` in `.ai/project.yml` says (rules.md §2). When they go through Herdr, give the implementor your pane id for reports: `herdr pane current`.

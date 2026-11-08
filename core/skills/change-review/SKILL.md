---
name: change-review
description: "crewlead: review a draft PR from a fresh context. Use with a PR number, e.g. `change-review 34`."
---
<!-- Managed by crewlead — edit it in the crewlead repo, not here. -->
The reviewer must judge from a **fresh context**: it did not write the plan or
the code, and knows nothing from an earlier conversation. Input: a PR number;
if there is none, ask for it.

Pick the first that applies:

1. **This conversation has no earlier work on this PR or its issue** (it was
   started for this review). You are already fresh: act as the reviewer and
   follow `.ai/flow/agents/reviewer.md` exactly, under the rules in `AGENTS.md` and `.ai/flow/rules.md`.
2. **Your tool can start a subagent with an empty context** (Claude Code can).
   Start one with this prompt, and nothing about this conversation:
   > You are the reviewer agent. Follow `.ai/flow/agents/reviewer.md` exactly,
   > under the rules in `AGENTS.md` and `.ai/flow/rules.md`, for PR #<pr>. Return the verdict you posted
   > and the route you took.

   Then relay its verdict to the person in two or three lines.
3. **Otherwise** (Cursor, Codex, or any tool without such subagents): do not
   review here. Tell the person to open a **new chat** in this repository and
   run `change-review <pr>` there.

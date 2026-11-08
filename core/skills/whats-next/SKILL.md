---
name: whats-next
description: "crewlead: what is waiting, and on whom. Read-only status of the flow's issues, PRs and worktrees. Use when someone asks what is next, what is blocked, or what needs them."
---
<!-- Managed by crewlead — edit it in the crewlead repo, not here. -->
Read-only. Show what is open in this repository's crewlead, grouped by who must act next. Use the commands below (on GitLab, their `glab` equivalents from `.ai/flow/rules.md` §11; label names from `.ai/project.yml` → `labels`):

```bash
gh issue list --label ai:blocked --state open
gh issue list --label ai:awaiting-approval --state open
gh issue list --label ai:ready --state open
gh issue list --label ai:in-review --state open
gh issue list --label ai:implementing --state open
gh issue list --label ai --state open
gh issue list --label owner-task --state open
gh issue list --label ops --state open
gh pr list --state open --json number,title,isDraft,headRefName,statusCheckRollup
git worktree list
```

Report in the person's language, in this order:
1. **Needs you**: `ai:blocked` (with the question), `ai:awaiting-approval` (plan to check, approve with a `/go` comment on the issue; with `needs-lead-review`, name the `approvers` who may), `ai:ready` (check and merge), owner/ops tasks.
2. **AI working**: implementing / in review, with PR and CI state.
3. **Queued**: `ai`.
4. **Loose ends**: worktrees or branches whose PR is merged or closed (offer to remove them).

Change nothing.

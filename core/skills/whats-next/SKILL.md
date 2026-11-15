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
git worktree list --porcelain
```

For each worktree other than the main checkout, on an `ai/<n>-<slug>` branch: look up its PR in any state and its head commit (rules.md §11, *Its state and head commit*), `git -C <worktree> status --porcelain` and `git -C <worktree> rev-parse HEAD`. Apply the *Safe to remove* test in rules.md §9 *Worktree lifecycle*.

Report in the person's language, in this order:
1. **Needs you**: `ai:blocked` (with the question), `ai:awaiting-approval` (plan to check, approve with a `/go` comment on the issue; with `needs-lead-review`, name the `approvers` who may), `ai:ready` (check and merge), owner/ops tasks.
2. **AI working**: implementing / in review, with PR and CI state.
3. **Queued**: `ai`.
4. **Loose ends**: worktrees whose PR is merged or closed.
   - **Safe to remove**: each with its path, branch, PR and the commands from rules.md §9 (unlink a symlinked `node_modules`, `git worktree remove`, `git branch -d`, or `-D` after a squash merge), ready to paste in the main checkout.
   - **Not safe yet**: PR merged or closed but uncommitted changes or commits the PR does not have; say which, and that a person decides.
   - Local `ai/*` branches without a worktree whose PR is merged or closed: `git branch -d` (or `-D` as above).

Change nothing: never remove a worktree or branch yourself. If the person then asks you to remove the ones listed as safe, check each again just before (it may have changed) and run the commands; never `--force`.

## 11. Platform: GitLab

This project lives on **GitLab** (`glab`, which follows the repository's
remote, so self-hosted instances work). The commands in the agent files are
written for GitHub's `gh`: **use the `glab` equivalent below instead.**
Wherever the rules say PR, read **merge request (MR)**; `Closes #<n>` works the
same in an MR description. GitLab issue numbers are the project's `iid`.

| Do | Instead of `gh` | With `glab` |
|---|---|---|
| Who am I | `gh api user` | `glab api user` → `.username` |
| Read an issue with its comments | `gh issue view <n> --comments` | `glab issue view <n> --comments` |
| Issue comments with author, time and URL | `gh issue view --json` | `glab api "projects/:id/issues/<n>/notes?sort=asc&per_page=100"` → `.author.username`, `.created_at`, `.body`; URL = the issue's `web_url` + `#note_<id>` |
| Search issues | `gh issue list --search` | `glab issue list --all --search "<words>" --per-page 20` |
| Create an issue | `gh issue create` | `glab issue create --title "<t>" --description "$(cat <f>)" --label "<a>,<b>" --yes` |
| Comment on an issue | `gh issue comment` | `glab issue note <n> --message "$(cat <f>)"` |
| Move labels | `gh issue edit --add-label/--remove-label` | `glab issue update <n> --label <a> --unlabel <b>` |
| Can a user see the project | `gh api …/collaborators/<user>` | `glab api "projects/:id/members/all?query=<user>"` (non-empty = yes) |
| Can a user approve (write access) | `gh api …/collaborators/<user>/permission` | `glab api "projects/:id/members/all?query=<user>"` → the entry whose `.username` is exactly `<user>` has `.access_level` ≥ 30 (Developer) = yes; no such entry = no |
| Change request for a branch | `gh pr list --head` | `glab mr list --source-branch <branch>` |
| Open a draft change request | `gh pr create --draft` | `glab mr create --draft --title "<t>" --description "$(cat <f>)" --source-branch <branch> --target-branch <default_branch> --yes` |
| Read it, its diff | `gh pr view` · `gh pr diff` | `glab mr view <mr> --comments` · `glab mr diff <mr>` |
| Its pipeline / failed log | `gh pr checks` · `gh run view --log-failed` | `glab ci status --branch <branch>` · `glab ci trace <job-id>` |
| Comment on it | `gh pr comment` | `glab mr note <mr> --message "$(cat <f>)"` |
| Mark ready / request a reviewer | `gh pr ready` · `gh pr edit --add-reviewer` | `glab mr update <mr> --ready` · `glab mr update <mr> --reviewer <user>` |
| Create a label | `gh label create` | `glab label create --name "<name>" --color "#<hex>" --description "<d>"` |

**Approvals on GitLab.** A line starting with `/` is a GitLab quick action, so
an approval comment is `/go` **or** a comment whose first line is `go` or
`APPROVED` — accept any of them (AGENTS.md §4 Approvals). GitLab's own MR
approval rules are not required; the comment is the evidence.

Templates: `.gitlab/issue_templates/`, `.gitlab/merge_request_templates/Default.md`.
Guard: the `ai-guard` job in `.ai/flow/ci/ai-guard.gitlab-ci.yml`, included from
`.gitlab-ci.yml`. It runs in merge request pipelines; after adding or removing a
waiver label, re-run the pipeline. It cannot add `needs-lead-review` itself:
the reviewer adds that label when the job reports protected paths.

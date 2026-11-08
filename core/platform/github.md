## 11. Platform: GitHub

This project lives on **GitHub**. The commands in the agent files are written
for `gh` and apply as they are. A change request is a **pull request (PR)**.

| Do | Command |
|---|---|
| Who am I | `gh api user --jq .login` |
| Read an issue with its comments | `gh issue view <n> --comments` |
| Issue comments with author, time and URL | `gh issue view <n> --json author,comments --jq '{author: .author.login, comments: [.comments[] \| {author: .author.login, createdAt, url, body}]}'` |
| Search issues | `gh issue list --state all --search "<words>" --limit 20` |
| Create an issue | `gh issue create --title "<t>" --body-file <f> --label "<a>,<b>"` |
| Comment on an issue | `gh issue comment <n> --body-file <f>` |
| Edit a comment | `gh api -X PATCH repos/{owner}/{repo}/issues/comments/<id> -F body=@<f>` (`<id>`: the number after `#issuecomment-` in its URL) |
| Move labels | `gh issue edit <n> --add-label <a> --remove-label <b>` |
| Can a user see the repo | `gh api repos/{owner}/{repo}/collaborators/<user>` (204 = yes) |
| Can a user approve (write access) | `gh api repos/{owner}/{repo}/collaborators/<user>/permission --jq .permission` → `admin` or `write` = yes; anything else, or an error = no |
| Change request for a branch | `gh pr list --head <branch>` |
| Open a draft change request | `gh pr create --draft --title "<t>" --body-file <f>` |
| Read it, its diff, its checks | `gh pr view <pr> --comments` · `gh pr diff <pr>` · `gh pr checks <pr>` |
| Wait for checks / failed log | `gh pr checks <pr> --watch` · `gh run view <run-id> --log-failed` |
| Comment on it | `gh pr comment <pr> --body-file <f>` |
| Mark ready / request a reviewer | `gh pr ready <pr>` · `gh pr edit <pr> --add-reviewer <user>` |
| Create a label | `gh label create "<name>" --color <hex> --description "<d>"` |

Templates: `.github/ISSUE_TEMPLATE/`, `.github/pull_request_template.md`.
Guard: `.github/workflows/ai-guard.yml` (re-runs when a label changes).

#!/usr/bin/env bash
# Smoke tests for crewlead, install.sh, guard.sh and the pre-push hook.
# Run: bash tests/run.sh   (needs git, jq; no network)
set -euo pipefail
FLOW="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()   { echo "  ✓ $1"; pass=$((pass+1)); }
bad()  { echo "  ✗ $1"; fail=$((fail+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }
gitc() { git -c user.email=t@t -c user.name=t "$@"; }

new_repo() {
  local d="$TMP/$1"; mkdir -p "$d"; git -C "$d" init -q -b main
  echo x > "$d/README.md"; gitc -C "$d" add -A; gitc -C "$d" commit -qm init; echo "$d"
}

echo "crewlead init"
R=$(new_repo app)
mkdir -p "$R/.github/workflows" && echo "name: theirs" > "$R/.github/pull_request_template.md"
echo '{"permissions":{"allow":["Bash(ls:*)"],"deny":["Bash(rm -rf:*)"]}}' > "$R/.claude.json.tmp"
mkdir -p "$R/.claude" && mv "$R/.claude.json.tmp" "$R/.claude/settings.json"
mkdir -p "$R/.claude/commands" "$R/.claude/skills/mine"
printf '<!-- Managed by crewlead -->\nold\n' > "$R/.claude/commands/flow-plan.md"
echo "# my own" > "$R/.claude/commands/flow-custom.md"
printf -- '---\nname: mine\ndescription: x\n---\n' > "$R/.claude/skills/mine/SKILL.md"
out=$("$FLOW/bin/crewlead" init "$R")
for f in .ai/flow/agents/intake.md .ai/flow/agents/planner.md .ai/flow/agents/implementor.md \
         .ai/flow/agents/reviewer.md .ai/flow/agents/setup.md .ai/flow/templates/plan.md .ai/flow/guard.sh .ai/flow/VERSION \
         .ai/project.yml .ai/steering/product.md .ai/steering/tech.md .ai/steering/structure.md AGENTS.md CLAUDE.md \
         .ai/flow/check-drift.sh .ai/business-rules.md .agents/skills/issue-plan/SKILL.md .claude/skills/issue-plan/SKILL.md \
         .github/ISSUE_TEMPLATE/feature.yml .github/ISSUE_TEMPLATE/bug.yml .github/workflows/ai-guard.yml; do
  check "creates $f" "[[ -f '$R/$f' ]]"
done
check "pre-push hook installed" "[[ -x '$R/.git/hooks/pre-push' ]]"
for k in project-setup issue-new issue-plan change-review whats-next; do
  check "skill $k is linked for Claude" "[[ -L '$R/.claude/skills/$k' && \$(readlink '$R/.claude/skills/$k') == ../../.agents/skills/$k ]]"
done
check "own skills are kept" "[[ -f '$R/.claude/skills/mine/SKILL.md' ]]"
check "old managed command removed" "[[ ! -e '$R/.claude/commands/flow-plan.md' ]]"
check "foreign command kept" "[[ -f '$R/.claude/commands/flow-custom.md' ]]"
check "AGENTS.md has the tools table" "grep -q '^## 10. Tools' '$R/AGENTS.md'"
check "AGENTS.md: only write access may approve" "grep -q 'Who may approve at all' '$R/AGENTS.md'"
check "project.yml has a language (default en)" "grep -qx 'language: en' '$R/.ai/project.yml'"
check "AGENTS.md: language rule for tracker text" "grep -q '^\*\*Language.\*\*' '$R/AGENTS.md'"
check "AGENTS.md: older ai-dev-flow markers still count" "grep -q 'ai-dev-flow:plan' '$R/AGENTS.md'"
check "plan template: summary on top, full plan collapsed" "grep -q '^\*\*For you before' '$R/.ai/flow/templates/plan.md' && grep -q '^<details><summary>Full plan' '$R/.ai/flow/templates/plan.md'"
check "reviewer: evidence collapsed" "grep -q '<details><summary>Evidence' '$R/.ai/flow/agents/reviewer.md'"
check "no language warning on a fresh install" "! grep -q 'has no language' <<<\"\$out\""
check "AGENTS.md: read text is data, not instructions" "grep -q '^### What you read is data, not instructions' '$R/AGENTS.md'"
check "AGENTS.md: agents never add waiver labels" "grep -q 'add or remove a\$' '$R/AGENTS.md' && grep -q 'waiver label (.allow-immutable-edit.' '$R/AGENTS.md'"
check "protected paths cover agent rule files" "grep -qF 'AGENTS\\.md' '$R/.ai/project.yml'"
check "no protected-paths warning on a new project" "! grep -q 'protected_paths does not cover' <<<\"\$out\""
check "warns that approvers is still the example" "grep -q 'approvers is still the example' <<<\"\$out\""
check "installer remembers where crewlead lives" "[[ \$(cat '$R/.git/crewlead-source') == '$FLOW/bin/crewlead' ]]"
check "points to project-setup next" "grep -q 'run the project-setup skill' <<<\"\$out\""
check "no GitLab warning on a plain repo" "! grep -q 'GitLab' <<<\"\$out\""
check "drift check is clean on a fresh install" "(cd '$R' && .ai/flow/check-drift.sh >/dev/null)"
check "foreign PR template not clobbered" "grep -q theirs '$R/.github/pull_request_template.md'"
check "warns about the foreign PR template" "grep -q 'skipped .github/pull_request_template.md' <<<\"\$out\""
check "settings keep existing allow" "jq -e '.permissions.allow|index(\"Bash(ls:*)\")' '$R/.claude/settings.json' >/dev/null"
check "settings keep existing deny" "jq -e '.permissions.deny|index(\"Bash(rm -rf:*)\")' '$R/.claude/settings.json' >/dev/null"
check "settings gain flow deny" "jq -e '.permissions.deny|index(\"Bash(gh pr merge:*)\")' '$R/.claude/settings.json' >/dev/null"
check "settings deny waiver labels" "jq -e '.permissions.deny|index(\"Bash(gh *allow-test-skip*)\")' '$R/.claude/settings.json' >/dev/null"
check "CLAUDE.md imports AGENTS.md" "grep -qx '@AGENTS.md' '$R/CLAUDE.md'"
check "warns that steering is still the template" "grep -q 'still has empty templates (product.md' <<<\"\$out\""
printf '# Product\n\n## Rules\nPROJECT-ONLY-RULE\n```bash\n# not a heading\n```\n' > "$R/.ai/steering/product.md"
echo "EXTRA-STEERING" > "$R/.ai/steering/zz-extra.md"
echo "name: kept" > "$R/.ai/project.yml"
"$FLOW/bin/crewlead" init "$R" >/dev/null
check "re-install keeps project.yml" "grep -qx 'name: kept' '$R/.ai/project.yml'"
check "AGENTS.md includes steering" "grep -q PROJECT-ONLY-RULE '$R/AGENTS.md'"
check "AGENTS.md includes extra steering files" "grep -q EXTRA-STEERING '$R/AGENTS.md'"
check "steering headings are demoted" "grep -qx '## Product' '$R/AGENTS.md' && grep -qx '### Rules' '$R/AGENTS.md'"
check "code-fence comments are not demoted" "grep -qx '# not a heading' '$R/AGENTS.md'"
check "product comes before tech" "[[ \$(grep -n 'steering: .ai/steering/product.md' '$R/AGENTS.md' | cut -d: -f1) -lt \$(grep -n 'steering: .ai/steering/tech.md' '$R/AGENTS.md' | cut -d: -f1) ]]"
check "AGENTS.md has the rule once" "[[ \$(grep -c PROJECT-ONLY-RULE '$R/AGENTS.md') == 1 ]]"
out=$("$FLOW/bin/crewlead" init "$R")
check "old project.yml gets a protected-paths warning" "grep -q 'protected_paths does not cover' <<<\"\$out\""
check "old project.yml gets a business_rules warning" "grep -q 'no business_rules key' <<<\"\$out\""
check "old project.yml gets an approvers warning" "grep -q 'no approvers list' <<<\"\$out\""
check "old project.yml gets a language warning" "grep -q 'has no language' <<<\"\$out\""
check "deny rules not duplicated" "[[ \$(jq '[.permissions.deny[]|select(.==\"Bash(gh pr merge:*)\")]|length' '$R/.claude/settings.json') == 1 ]]"
R2=$(new_repo foreign); echo "# mine" > "$R2/AGENTS.md"
out=$("$FLOW/bin/crewlead" init "$R2")
check "foreign AGENTS.md not clobbered" "grep -qx '# mine' '$R2/AGENTS.md'"

for layout in agents-to-claude claude-to-agents; do
  L=$(new_repo "$layout")
  if [[ $layout == agents-to-claude ]]; then mkdir -p "$L/.claude/skills/intake" "$L/.agents"; ln -s ../.claude/skills "$L/.agents/skills"; d=.claude
  else mkdir -p "$L/.agents/skills/intake" "$L/.claude"; ln -s ../.agents/skills "$L/.claude/skills"; d=.agents; fi
  printf -- '---\nname: intake\ndescription: x\n---\n' > "$L/$d/skills/intake/SKILL.md"
  "$FLOW/bin/crewlead" init "$L" >/dev/null; "$FLOW/bin/crewlead" init "$L" >/dev/null
  check "$layout: skills readable from both folders" "grep -q 'name: issue-plan' '$L/.claude/skills/issue-plan/SKILL.md' && grep -q 'name: issue-plan' '$L/.agents/skills/issue-plan/SKILL.md'"
  check "$layout: project skill kept" "[[ -f '$L/$d/skills/intake/SKILL.md' ]]"
  check "$layout: drift clean" "(cd '$L' && .ai/flow/check-drift.sh >/dev/null)"
done

R4=$(new_repo rules); mkdir -p "$R4/docs"; echo "# ours" > "$R4/docs/business-rules.md"
"$FLOW/bin/crewlead" init "$R4" >/dev/null
check "existing docs/business-rules.md is used" "grep -qx 'business_rules: docs/business-rules.md' '$R4/.ai/project.yml'"
check "existing business rules not clobbered" "grep -qx '# ours' '$R4/docs/business-rules.md' && [[ ! -e '$R4/.ai/business-rules.md' ]]"

echo "crewlead"
mkdir -p "$TMP/path"; ln -s "$FLOW/bin/crewlead" "$TMP/path/crewlead"
check "crewlead works through a PATH link" "PATH='$TMP/path':\$PATH crewlead version | grep -q \"v\$(cat '$FLOW/VERSION')\""
A=$(new_repo crewlead-here); echo '{}' > "$A/package.json"; mkdir -p "$A/.github"
check "crewlead update refuses before init" "! (cd '$A' && '$FLOW/bin/crewlead' update >/dev/null 2>&1)"
(cd "$A" && PATH="$TMP/path:$PATH" crewlead init >/dev/null)
check "crewlead init defaults to the current directory" "[[ -f '$A/.ai/flow/VERSION' && -f '$A/AGENTS.md' ]]"
out=$(cd "$A" && "$FLOW/bin/crewlead" init)
check "crewlead init twice says it updates" "grep -q 'updating instead' <<<\"\$out\""
echo 0.0.1 > "$A/.ai/flow/VERSION"
out=$(cd "$A" && "$FLOW/bin/crewlead" update)
check "crewlead update shows the version change" "grep -q 'v0.0.1 → v' <<<\"\$out\""
out=$(cd "$A" && "$FLOW/bin/crewlead" check 2>&1 || true)
check "crewlead check lists what is missing" "grep -q 'steering still empty' <<<\"\$out\" && grep -q 'approvers is still the example' <<<\"\$out\""
check "crewlead check fails while something is missing" "! (cd '$A' && '$FLOW/bin/crewlead' check >/dev/null 2>&1)"
E=$(new_repo empty-chk)
out=$("$FLOW/bin/crewlead" check "$E" 2>&1 || true)
check "crewlead check on a repo without the flow says so" "grep -q 'not installed' <<<\"\$out\""
check "unknown crewlead command fails" "! '$FLOW/bin/crewlead' frobnicate >/dev/null 2>&1"
O=$(new_repo old-skills); mkdir -p "$O/.agents/skills/flow-plan" "$O/.claude/skills" "$O/.agents/skills/flow-mine"
printf -- '---\nname: flow-plan\ndescription: x\n---\n<!-- Managed by crewlead -->\n' > "$O/.agents/skills/flow-plan/SKILL.md"
ln -s ../../.agents/skills/flow-plan "$O/.claude/skills/flow-plan"
printf -- '---\nname: flow-mine\ndescription: x\n---\n' > "$O/.agents/skills/flow-mine/SKILL.md"
"$FLOW/bin/crewlead" init "$O" >/dev/null
check "v0.3 flow-* skills are removed" "[[ ! -e '$O/.agents/skills/flow-plan' && ! -L '$O/.claude/skills/flow-plan' ]]"
check "a project's own flow-* skill is kept" "[[ -f '$O/.agents/skills/flow-mine/SKILL.md' ]]"
check "renamed skills installed" "[[ -f '$O/.claude/skills/issue-plan/SKILL.md' ]]"

echo "platforms"
check "github: AGENTS.md has the GitHub section" "grep -q '^## 11. Platform: GitHub' '$R/AGENTS.md'"
check "github: AGENTS.md says how to check write access" "grep -q 'collaborators/<user>/permission' '$R/AGENTS.md'"
check "github: no GitLab files" "[[ ! -e '$R/.gitlab' ]]"
R5=$(new_repo gl); echo "stages: [test]" > "$R5/.gitlab-ci.yml"
out=$("$FLOW/bin/crewlead" init "$R5")
check "gitlab: read from .gitlab-ci.yml" "grep -qx 'platform: gitlab' '$R5/.ai/project.yml'"
for f in .gitlab/issue_templates/Feature.md .gitlab/issue_templates/Bug.md .gitlab/merge_request_templates/Default.md .ai/flow/ci/ai-guard.gitlab-ci.yml; do
  check "gitlab: creates $f" "[[ -f '$R5/$f' ]]"
done
check "gitlab: no GitHub files" "[[ ! -e '$R5/.github' ]]"
check "gitlab: AGENTS.md has the GitLab section" "grep -q '^## 11. Platform: GitLab' '$R5/AGENTS.md'"
check "gitlab: AGENTS.md says how to check write access" "grep -q 'access_level. ≥ 30' '$R5/AGENTS.md'"
check "gitlab: protects .gitlab-ci.yml" "grep -qF \"'^\\.gitlab-ci\\.yml\$'\" '$R5/.ai/project.yml'"
check "gitlab: says how to include the guard" "grep -q 'add to .gitlab-ci.yml' <<<\"\$out\""
printf 'include:\n  - local: .ai/flow/ci/ai-guard.gitlab-ci.yml\n' >> "$R5/.gitlab-ci.yml"
out=$("$FLOW/bin/crewlead" init "$R5")
check "gitlab: no include warning once included" "! grep -q 'add to .gitlab-ci.yml' <<<\"\$out\""
check "gitlab: drift clean" "(cd '$R5' && .ai/flow/check-drift.sh >/dev/null)"
R6=$(new_repo remote-gl); git -C "$R6" remote add origin https://gitlab.example.com/a/b.git
"$FLOW/bin/crewlead" init "$R6" >/dev/null
check "gitlab: read from the remote host" "grep -qx 'platform: gitlab' '$R6/.ai/project.yml'"
R7=$(new_repo nowhere)
out=$("$FLOW/bin/crewlead" init "$R7" </dev/null)
check "unknown: warns, no templates" "grep -q 'platform unknown' <<<\"\$out\" && [[ ! -e '$R7/.github' && ! -e '$R7/.gitlab' ]]"
check "unknown: AGENTS.md tells agents to ask" "grep -q '^## 11. Platform: unknown' '$R7/AGENTS.md'"
out=$("$FLOW/bin/crewlead" init --platform github "$R7")
check "unknown + --platform: installs GitHub files" "[[ -f '$R7/.github/workflows/ai-guard.yml' ]] && grep -q 'Platform: GitHub' '$R7/AGENTS.md'"
check "unknown + --platform: asks to record it" "grep -q \"add 'platform: github'\" <<<\"\$out\""
check "bad --platform is refused" "! '$FLOW/bin/crewlead' init --platform bitbucket '$R7' >/dev/null 2>&1"
sed -i.bak 's/^platform: .*/platform: gitlab/' "$R6/.ai/project.yml"; rm "$R6/.ai/project.yml.bak"; git -C "$R6" remote set-url origin https://github.com/a/b.git
"$FLOW/bin/crewlead" init "$R6" >/dev/null
check "project.yml platform wins over the remote" "grep -q 'Platform: GitLab' '$R6/AGENTS.md'"

echo "labels"
BIN="$TMP/bin"; mkdir -p "$BIN"
printf '#!/bin/sh\necho "$(basename "$0") $*" >> "%s/calls"\n' "$TMP" > "$BIN/gh"; cp "$BIN/gh" "$BIN/glab"; chmod +x "$BIN/gh" "$BIN/glab"
sed -i.bak 's/^  in_review: .*/  in_review: Currently reviewing/' "$R5/.ai/project.yml"; rm "$R5/.ai/project.yml.bak"
: > "$TMP/calls"; out=$(PATH="$BIN:$PATH" "$FLOW/bin/crewlead" init --labels "$R5")
check "gitlab labels use glab" "grep -q '^glab label create --name ai:ready --color #0E8A16' '$TMP/calls' && ! grep -q '^gh ' '$TMP/calls'"
check "a board label is never created or changed" "! grep -q 'Currently reviewing\|ai:in-review' '$TMP/calls'"
check "says which board labels are used" "grep -q 'board labels used as they are: Currently reviewing' <<<\"\$out\""
: > "$TMP/calls"; PATH="$BIN:$PATH" "$FLOW/bin/crewlead" init --labels "$R" >/dev/null
check "github labels use gh" "grep -q '^gh label create ai:in-review' '$TMP/calls' && ! grep -q '^glab ' '$TMP/calls'"

echo "detect-project.sh"
DET="$FLOW/core/setup/detect-project.sh"
N=$(new_repo node); mkdir -p "$N/src" "$N/prisma/migrations"
echo '{"scripts":{"lint":"eslint .","typecheck":"tsc --noEmit","test:unit":"vitest run","test":"vitest run && playwright test","build":"next build"}}' > "$N/package.json"
: > "$N/pnpm-lock.yaml"; echo 'it("a",()=>{})' > "$N/src/a.test.ts"; echo x > "$N/src/b.spec.tsx"
y=$("$DET" "$N")
check "agents default to claude plans, codex builds" "grep -qx '  implementor: codex' <<<\"\$y\" && grep -qx '  reviewer: claude' <<<\"\$y\""
check "design defaults to none" "grep -qx 'design: none' <<<\"\$y\""
check "handoff defaults to auto" "grep -qx 'handoff: auto' <<<\"\$y\""
check "node: kind and package manager" "grep -q 'kind: node (package.json (pnpm))' <<<\"\$y\""
check "node: commands from scripts" "grep -qx '  lint: pnpm lint' <<<\"\$y\" && grep -qx '  test_local: pnpm test:unit' <<<\"\$y\" && grep -qx '  test_full: pnpm test' <<<\"\$y\" && grep -qx '  typecheck: pnpm typecheck' <<<\"\$y\""
check "node: test globs from real files" "grep -qx \"  - '\\*.test.ts'\" <<<\"\$y\" && grep -qx \"  - '\\*.spec.tsx'\" <<<\"\$y\""
mkdir -p "$N/drizzle/meta"; y=$("$DET" "$N")
check "drizzle: only the SQL is immutable" "grep -qF \"'^drizzle/.*\\.sql\$'\" <<<\"\$y\""
check "node: migrations are immutable" "grep -qx \"  - '^prisma/migrations/'\" <<<\"\$y\""
check "node: lockfile is protected" "grep -qF \"'^pnpm-lock\\.yaml\$'\" <<<\"\$y\""

F=$(new_repo frappe); mkdir -p "$F/myapp/patches/v1" "$F/myapp/stock"
printf 'app_name = "myapp"\n' > "$F/myapp/hooks.py"; echo "myapp.patches.v1.x" > "$F/myapp/patches.txt"
: > "$F/myapp/patches/v1/x.py"; printf '[tool.ruff]\n' > "$F/pyproject.toml"
printf 'def test_a():\n    pass\n' > "$F/myapp/stock/test_item.py"
y=$("$DET" "$F")
check "frappe: kind" "grep -q 'kind: frappe' <<<\"\$y\""
check "frappe: bench test commands" "grep -q 'test_full: bench --site \\\$SITE run-tests --app myapp' <<<\"\$y\""
check "frappe: ruff lint" "grep -qx '  lint: ruff check .' <<<\"\$y\""
check "frappe: patches are immutable" "grep -qx \"  - '^myapp/patches/'\" <<<\"\$y\""
check "frappe: hooks.py is protected" "grep -qF \"'^myapp/hooks\\.py\$'\" <<<\"\$y\""
mkdir -p "$F/.ai"; echo "$y" > "$F/.ai/project.yml"; gitc -C "$F" add -A; gitc -C "$F" commit -qm base; FB=$(git -C "$F" rev-parse HEAD)
echo "# edit" >> "$F/myapp/patches/v1/x.py"; gitc -C "$F" commit -qam edit
if (cd "$F" && BASE_SHA="$FB" HEAD_SHA=HEAD GITHUB_OUTPUT=/dev/null bash "$FLOW/core/guard/guard.sh" >/dev/null 2>&1); then bad "frappe: guard blocks editing an applied patch"; else ok "frappe: guard blocks editing an applied patch"; fi
gitc -C "$F" reset -q --hard HEAD~1
printf 'def test_b():\n    pass\n' >> "$F/myapp/stock/test_item.py"; gitc -C "$F" commit -qam more
(cd "$F" && BASE_SHA="$FB" HEAD_SHA=HEAD GITHUB_OUTPUT=/dev/null bash "$FLOW/core/guard/guard.sh" 2>&1 | grep -q 'base=1 head=2') && ok "frappe: guard counts python tests" || bad "frappe: guard counts python tests"

P2=$(new_repo py); mkdir -p "$P2/tests" "$P2/app/migrations"
printf '[tool.ruff]\n[tool.mypy]\n' > "$P2/pyproject.toml"; : > "$P2/tests/test_a.py"; : > "$P2/app/migrations/__init__.py"
y=$("$DET" "$P2")
check "python: kind, ruff, mypy, pytest" "grep -q 'kind: python' <<<\"\$y\" && grep -qx '  lint: ruff check .' <<<\"\$y\" && grep -qx '  typecheck: mypy .' <<<\"\$y\" && grep -q 'test_local: python -m pytest' <<<\"\$y\""
check "python: applied migrations are immutable" "grep -qF \"'(^|/)migrations/[0-9]'\" <<<\"\$y\""
check "python: no specs folder, specs left commented" "grep -qx '# specs:' <<<\"\$y\""

DJ=$(new_repo django); mkdir -p "$DJ/shop/settings" "$DJ/orders/migrations"
: > "$DJ/manage.py"; : > "$DJ/shop/settings/__init__.py"; : > "$DJ/orders/migrations/0001_initial.py"
printf 'django>=5.2\n' > "$DJ/requirements.txt"; printf 'from django.test import TestCase\n' > "$DJ/orders/tests.py"
y=$("$DET" "$DJ")
check "django: kind from manage.py" "grep -q 'kind: django (manage.py)' <<<\"\$y\""
check "django: manage.py test without pytest, scoped by app" "grep -qx '  test_local: python manage.py test <app.label>' <<<\"\$y\" && grep -qx '  test_full: python manage.py test' <<<\"\$y\""
check "django: numbered migrations are immutable" "grep -qF \"'(^|/)migrations/[0-9]'\" <<<\"\$y\""
check "django: settings package is protected" "grep -qF \"'^shop/settings/'\" <<<\"\$y\""
check "django: tests.py files are test files" "grep -qF \"'*tests.py'\" <<<\"\$y\""
mkdir -p "$DJ/docs/specs"; : > "$DJ/docs/specs/a.md"; y=$("$DET" "$DJ")
check "specs: docs/specs is used when present" "grep -qx '  docs: docs/specs' <<<\"\$y\""

M=$(new_repo monorepo); mkdir -p "$M/backend/config/settings" "$M/backend/modules/billing/migrations" "$M/backend/modules/billing/tests" "$M/web/src"
: > "$M/backend/manage.py"; : > "$M/backend/config/settings/__init__.py"; : > "$M/backend/uv.lock"; : > "$M/backend/.importlinter"
: > "$M/backend/modules/billing/migrations/__init__.py"; : > "$M/backend/modules/billing/migrations/0001_initial.py"
printf '[project]\ndependencies = ["django>=5.2", "django-ninja"]\n[tool.ruff]\n[tool.mypy]\n[tool.pytest.ini_options]\n' > "$M/backend/pyproject.toml"
printf 'def test_a():\n    pass\n' > "$M/backend/modules/billing/tests/test_x.py"
echo '{"scripts":{"lint":"eslint .","test":"vitest run","build":"next build"}}' > "$M/web/package.json"; : > "$M/web/pnpm-lock.yaml"
echo 'it("a",()=>{})' > "$M/web/src/a.test.tsx"
y=$("$DET" "$M")
check "monorepo: both parts found" "grep -q 'kind: monorepo (backend: django (backend/manage.py); web: node (web/package.json (pnpm)))' <<<\"\$y\""
check "monorepo: commands run in each folder, through uv" "grep -qxF '  lint: (cd backend && uv run ruff check . && uv run lint-imports) && (cd web && pnpm lint)' <<<\"\$y\" && grep -qxF '  test_full: (cd backend && uv run pytest) && (cd web && pnpm test)' <<<\"\$y\""
check "monorepo: local tests scoped by app" "grep -qF 'uv run pytest -q -x <app-dir>' <<<\"\$y\""
check "monorepo: test globs from both parts" "grep -qx \"  - 'backend/\*test_\*.py'\" <<<\"\$y\" && grep -qx \"  - 'web/\*.test.tsx'\" <<<\"\$y\""
check "monorepo: regex counts python and js tests" "grep -qF 'def test_|(it|test)' <<<\"\$y\""
check "monorepo: migrations of every app are immutable" "grep -qF \"'^backend/(.*/)?migrations/[0-9]'\" <<<\"\$y\""
check "monorepo: lockfiles, settings, import contracts protected" "grep -qF \"'^backend/uv\\.lock\$'\" <<<\"\$y\" && grep -qF \"'^web/pnpm-lock\\.yaml\$'\" <<<\"\$y\" && grep -qF \"'^backend/config/settings/'\" <<<\"\$y\" && grep -qF \"'^backend/\\.importlinter\$'\" <<<\"\$y\""
printf 'lint:\n\ttrue\ntest:\n\ttrue\n' > "$M/Makefile"; y=$("$DET" "$M")
check "monorepo: a root Makefile target wins" "grep -qx '  lint: make lint' <<<\"\$y\" && grep -qx '  test_full: make test' <<<\"\$y\""
mkdir -p "$M/.ai"; echo "$y" > "$M/.ai/project.yml"; gitc -C "$M" add -A; gitc -C "$M" commit -qm base; MB=$(git -C "$M" rev-parse HEAD)
echo "# edit" >> "$M/backend/modules/billing/migrations/0001_initial.py"; gitc -C "$M" commit -qam edit
if (cd "$M" && BASE_SHA="$MB" HEAD_SHA=HEAD GITHUB_OUTPUT=/dev/null bash "$FLOW/core/guard/guard.sh" >/dev/null 2>&1); then bad "monorepo: guard blocks editing an applied migration"; else ok "monorepo: guard blocks editing an applied migration"; fi
gitc -C "$M" reset -q --hard HEAD~1
echo "# edit" >> "$M/backend/modules/billing/migrations/__init__.py"
printf 'def test_b():\n    pass\n' >> "$M/backend/modules/billing/tests/test_x.py"; echo 'test("b",()=>{})' >> "$M/web/src/a.test.tsx"; gitc -C "$M" commit -qam more
(cd "$M" && BASE_SHA="$MB" HEAD_SHA=HEAD GITHUB_OUTPUT=/dev/null bash "$FLOW/core/guard/guard.sh" 2>&1 | grep -q 'base=2 head=4') && ok "monorepo: guard counts both kinds of tests, allows migrations/__init__.py" || bad "monorepo: guard counts both kinds of tests, allows migrations/__init__.py"


U=$(new_repo unknown)
y=$("$DET" "$U")
check "unknown: empty commands, no guessing" "grep -q 'kind: unknown' <<<\"\$y\" && grep -q 'test_local: \"\"' <<<\"\$y\""
git -C "$U" branch -q develop; git -C "$U" update-ref refs/remotes/origin/develop HEAD
git -C "$U" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
y=$("$DET" "$U")
check "default branch from origin/HEAD" "grep -qx 'default_branch: develop' <<<\"\$y\""

echo "check-drift.sh"
D="$R4"
(cd "$D" && .ai/flow/check-drift.sh >/dev/null) && ok "clean install has no drift" || bad "clean install has no drift"
echo 'See `.ai/flow/agents/gone.md` and `src/example.ts` and `.ai/steering/<file>.md`.' >> "$D/.ai/steering/tech.md"
out=$(cd "$D" && .ai/flow/check-drift.sh 2>&1 || true)
check "drift finds a missing path" "grep -q 'gone.md. does not exist' <<<\"\$out\""
check "drift skips example folders" "! grep -q 'src/example.ts' <<<\"\$out\""
check "drift skips placeholders" "! grep -q '<file>' <<<\"\$out\""
echo 'Run `commands.nope` first.' >> "$D/.ai/steering/tech.md"
out=$(cd "$D" && .ai/flow/check-drift.sh 2>&1 || true)
check "drift finds an unknown command key" "grep -q 'commands.nope. is not in' <<<\"\$out\""
sed -i.bak 's/^name: whats-next/name: whats-nxt/' "$D/.agents/skills/whats-next/SKILL.md"; rm "$D/.agents/skills/whats-next/SKILL.md.bak"
out=$(cd "$D" && .ai/flow/check-drift.sh 2>&1 || true)
check "drift finds a skill name mismatch" "grep -q \"name is 'whats-nxt'\" <<<\"\$out\""
rm -rf "$D/.agents/skills/issue-new"
out=$(cd "$D" && .ai/flow/check-drift.sh 2>&1 || true)
check "drift finds a broken skill link" "grep -q 'issue-new: broken link' <<<\"\$out\""

echo "planner worktree"
W=$(new_repo wt); git -C "$W" remote add origin "$W"; git -C "$W" fetch -q origin
(cd "$W" && git worktree add -q --no-track -b ai/1-x ../wt-ai-1 origin/main)
check "issue branch does not track the default branch" "[[ -z \$(git -C '$W' config --get branch.ai/1-x.merge || true) ]]"

R3=$(new_repo legacy); mkdir -p "$R3/.ai"; echo old > "$R3/.ai/project-rules.md"
out=$("$FLOW/bin/crewlead" init "$R3")
check "warns about a v0.1 project-rules.md" "grep -q 'project-rules.md is from v0.1' <<<\"\$out\""

echo "guard.sh"
G=$(new_repo guard)
mkdir -p "$G/.ai" "$G/db/migrations" "$G/tests" "$G/src/auth"
echo '{"scripts":{"test":"vitest"}}' > "$G/package.json"
echo "create table a();" > "$G/db/migrations/0001.sql"
printf 'it("a", () => {});\nit("b", () => {});\n' > "$G/tests/x.test.ts"
echo "x" > "$G/src/auth/s.ts"
"$FLOW/core/setup/detect-project.sh" "$G" > "$G/.ai/project.yml"
sed -i.bak "s#  - '^\\\\.ai/'#  - '^\\\\.ai/'\n  - '^src/auth/'#" "$G/.ai/project.yml"; rm "$G/.ai/project.yml.bak"
gitc -C "$G" add -A; gitc -C "$G" commit -qm base; B=$(git -C "$G" rev-parse HEAD)
run_guard() { (cd "$G" && BASE_SHA="$B" HEAD_SHA=HEAD PR_LABELS="${1:-}" GITHUB_OUTPUT="$TMP/out" bash "$FLOW/core/guard/guard.sh" >"$TMP/log" 2>&1); }
run_guard; check "clean PR passes" "[[ \$? == 0 ]]"
echo "create table b();" > "$G/db/migrations/0002.sql"; gitc -C "$G" add -A; gitc -C "$G" commit -qm add
if run_guard; then ok "adding a migration passes"; else bad "adding a migration passes"; fi
echo "-- edit" >> "$G/db/migrations/0001.sql"; gitc -C "$G" commit -qam edit
if run_guard; then bad "editing a migration fails"; else ok "editing a migration fails"; fi
if run_guard allow-immutable-edit; then ok "waiver label accepts it"; else bad "waiver label accepts it"; fi
gitc -C "$G" reset -q --hard HEAD~1
printf 'it.only("c", () => {});\n' >> "$G/tests/x.test.ts"; gitc -C "$G" commit -qam only
if run_guard; then bad "it.only fails"; else ok "it.only fails"; fi
gitc -C "$G" reset -q --hard HEAD~1
printf 'it("a", () => {});\n' > "$G/tests/x.test.ts"; gitc -C "$G" commit -qam drop
if run_guard; then bad "fewer tests fails"; else ok "fewer tests fails"; fi
gitc -C "$G" reset -q --hard HEAD~1
echo y >> "$G/src/auth/s.ts"; gitc -C "$G" commit -qam auth; : > "$TMP/out"
run_guard || true
check "protected path flags lead review" "grep -qx 'needs_lead_review=true' '$TMP/out'"
gitc -C "$G" reset -q --hard HEAD~1
for f in AGENTS.md lib/AGENTS.md CLAUDE.md .agents/skills/x/SKILL.md .cursor/rules/x.mdc .codex/config.toml; do
  mkdir -p "$G/$(dirname "$f")"; echo x > "$G/$f"; gitc -C "$G" add -A; gitc -C "$G" commit -qm "$f"; : > "$TMP/out"
  run_guard || true
  check "agent file $f flags lead review" "grep -qx 'needs_lead_review=true' '$TMP/out'"
  gitc -C "$G" reset -q --hard HEAD~1
done

echo "gitlab guard job"
GL=$(new_repo gljob); mkdir -p "$GL/.ai/flow" "$GL/tests"
cp "$FLOW/core/guard/guard.sh" "$GL/.ai/flow/guard.sh"
printf 'it("a",()=>{})\nit("b",()=>{})\n' > "$GL/tests/x.test.ts"; echo '{}' > "$GL/package.json"
PLATFORM=gitlab "$FLOW/core/setup/detect-project.sh" "$GL" > "$GL/.ai/project.yml"
gitc -C "$GL" add -A; gitc -C "$GL" commit -qm base; GB=$(git -C "$GL" rev-parse HEAD)
printf 'it("a",()=>{})\n' > "$GL/tests/x.test.ts"; gitc -C "$GL" commit -qam drop
awk '/bash -euo pipefail <<.SH./{f=1;next} /^      SH$/{f=0} f{sub(/^      /,"");print}' "$FLOW/core/gitlab/ci/ai-guard.gitlab-ci.yml" | sed "s#/tmp/#$TMP/gl-#g" > "$TMP/gljob.sh"
gljob() { (cd "$GL" && CI_MERGE_REQUEST_DIFF_BASE_SHA="$GB" CI_COMMIT_SHA=$(git rev-parse HEAD) CI_MERGE_REQUEST_LABELS="$1" bash -euo pipefail "$TMP/gljob.sh" >/dev/null 2>&1); }
if gljob ""; then bad "gitlab job fails when tests are removed"; else ok "gitlab job fails when tests are removed"; fi
if gljob "x,allow-test-removal"; then ok "gitlab job accepts the waiver label"; else bad "gitlab job accepts the waiver label"; fi

echo "pre-push"
H="$FLOW/core/hooks/pre-push"; P=$(new_repo push); Z=0000000000000000000000000000000000000000
S1=$(git -C "$P" rev-parse HEAD)
echo y > "$P/f"; gitc -C "$P" add -A; gitc -C "$P" commit -qm two; S2=$(git -C "$P" rev-parse HEAD)
gitc -C "$P" checkout -q --orphan other; echo z > "$P/g"; gitc -C "$P" add -A; gitc -C "$P" commit -qm orphan; S3=$(git -C "$P" rev-parse HEAD)
hp() { (cd "$P" && printf '%s\n' "$1" | env $2 bash "$H" >/dev/null 2>&1); }
if hp "refs/heads/x $S2 refs/heads/main $S1" ""; then bad "blocks push to main"; else ok "blocks push to main"; fi
if hp "refs/heads/x $S2 refs/heads/main $S1" "ALLOW_PUSH_TO_MAIN=1"; then ok "person can override main"; else bad "person can override main"; fi
if hp "refs/heads/ai/1 $S2 refs/heads/ai/1 $S1" ""; then ok "allows fast-forward to ai/*"; else bad "allows fast-forward to ai/*"; fi
if hp "refs/heads/ai/1 $S2 refs/heads/ai/1 $Z" ""; then ok "allows new ai/* branch"; else bad "allows new ai/* branch"; fi
if hp "refs/heads/ai/1 $S3 refs/heads/ai/1 $S2" ""; then bad "blocks force push"; else ok "blocks force push"; fi

echo "rename from ai-dev-flow"
U=$(new_repo old-name); "$FLOW/bin/crewlead" init --platform github "$U" >/dev/null
grep -rlE "crewlead" "$U/.ai/flow" "$U/AGENTS.md" "$U/.agents" "$U/.github" "$U/.git/hooks/pre-push" | xargs perl -i -pe "s/crewlead/ai-dev-flow/g"
out=$("$FLOW/bin/crewlead" init "$U" 2>&1)
check "old install is upgraded, nothing skipped" "! grep -q skipped <<<\"\$out\""
check "AGENTS.md now says crewlead" "grep -q 'Generated by crewlead' '$U/AGENTS.md'"
check "skill now says crewlead" "grep -q crewlead '$U/.agents/skills/issue-plan/SKILL.md'"

echo; echo "passed $pass, failed $fail"; (( fail == 0 ))

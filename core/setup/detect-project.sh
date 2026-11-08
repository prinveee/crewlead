#!/usr/bin/env bash
# crewlead project detection — reads a repository and prints a first
# .ai/project.yml for it. `crewlead init` runs this once, when the project has no
# project.yml yet; after that the file belongs to the project.
#
#   detect-project.sh <repo>              print a first project.yml
#   detect-project.sh --platform <repo>   print only the platform (github, gitlab or nothing)
#
# PLATFORM=github|gitlab in the environment overrides the detected platform
# (crewlead sets it from --platform or from the person's answer).
#
# Only what a script can know for sure: the default branch, the kind of
# project (Frappe app, Django, Node, Python — at the root or in subfolders
# such as backend/ + web/), its commands, test files, migration
# folders and the files whose change costs the most. Anything it cannot find is
# left empty. The project-setup skill reviews every value with a person.
set -euo pipefail

only_platform=0
if [[ "${1:-}" == --platform ]]; then only_platform=1; shift; fi
repo="$(cd "${1:?usage: detect-project.sh [--platform] <repo>}" && pwd)"
cd "$repo"

# Tracked and untracked-but-not-ignored files: never node_modules or build output.
files() { git ls-files --cached --others --exclude-standard -- "$@" 2>/dev/null | sort -u; }
first() { local f; for f in "$@"; do [[ -e "$f" ]] && { echo "$f"; return; }; done; return 0; }
re_escape() { sed 's/[.[\*^$()+?{}|]/\\&/g' <<<"$1"; }

name="$(basename "$repo")"

default_branch=""
if ref="$(git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null)"; then
  default_branch="${ref#origin/}"
fi
if [[ -z "$default_branch" ]]; then
  for b in main master develop; do
    if git show-ref -q --verify "refs/heads/$b"; then default_branch="$b"; break; fi
  done
fi
default_branch="${default_branch:-main}"

# Platform: the remote's host first, then the CI files the repo carries.
platform="${PLATFORM:-}"
if [[ -z "$platform" ]]; then
  remote="$(git remote get-url origin 2>/dev/null || git remote -v 2>/dev/null | awk 'NR == 1 { print $2 }')"
  case "$remote" in
    *github.com*) platform=github ;;
    *gitlab*)     platform=gitlab ;;
  esac
fi
if [[ -z "$platform" ]]; then
  if [[ -f .gitlab-ci.yml || -d .gitlab ]]; then platform=gitlab
  elif [[ -d .github ]]; then platform=github
  fi
fi
if (( only_platform )); then echo "$platform"; exit 0; fi

kind=unknown
evidence="nothing recognised"
lint="" typecheck="" test_local="" test_full="" build=""
test_globs=()
immutable=()
protected=()
langs=""            # py, js: which test-case regex the project needs

# A project may live at the root or in a subfolder (backend/, web/, apps/api/).
# Each detector reads one folder <d> and adds what it finds; paths it emits are
# repo-relative, commands run from the repo root ("cd <d> && …").
at()     { if [[ "$d" == . ]]; then echo "$1"; else echo "$d/$1"; fi; }     # path in <d>
re_at()  { if [[ "$d" == . ]]; then echo "^$1"; else echo "^$(re_escape "$d")/$1"; fi; }
in_dir() { [[ -z "$1" ]] && return 0; if [[ "$d" == . ]]; then echo "$1"; else echo "cd $d && $1"; fi; }
has_in() { local f="$(at "$1")"; [[ -f "$f" ]] && grep -qiE "$2" "$f"; }

# Parts found, one entry per project: "<dir>|<kind>|<evidence>" and its commands.
parts=() p_lint=() p_typecheck=() p_test_local=() p_test_full=() p_build=()
add_part() {   # dir kind evidence lint typecheck test_local test_full build
  parts+=("$1|$2|$3")
  p_lint+=("$(in_dir "$4")"); p_typecheck+=("$(in_dir "$5")")
  p_test_local+=("$(in_dir "$6")"); p_test_full+=("$(in_dir "$7")"); p_build+=("$(in_dir "$8")")
}

ruff_configured() {
  [[ -f "$(at ruff.toml)" || -f "$(at .ruff.toml)" ]] || has_in pyproject.toml '^\[tool\.ruff'
}

detect_node() {
  local pj; pj="$(at package.json)"
  local pm=npm run="npm run"
  if   [[ -f "$(at pnpm-lock.yaml)" ]]; then pm=pnpm run="pnpm"
  elif [[ -f "$(at yarn.lock)" ]];      then pm=yarn run="yarn"
  elif [[ -f "$(at bun.lockb)" || -f "$(at bun.lock)" ]]; then pm=bun run="bun run"
  fi
  script() {
    command -v jq >/dev/null || return 0
    local s; for s in "$@"; do
      if jq -e --arg s "$s" '.scripts[$s] // empty' "$pj" >/dev/null 2>&1; then echo "$run $s"; return; fi
    done
  }
  add_part "$d" node "$(at package.json) ($pm)" \
    "$(script lint)" "$(script typecheck type-check check-types tsc)" \
    "$(script test:unit test:local unit test)" "$(script test)" "$(script build)"
  local suffix
  while IFS= read -r suffix; do
    [[ -n "$suffix" ]] && test_globs+=("'$(at "*$suffix")'")
  done < <(files "$(at '*.test.*')" "$(at '*.spec.*')" | grep -oE '\.(test|spec)\.[cm]?[jt]sx?$' | sort -u)
  local m
  for m in prisma/migrations db/migrations migrations supabase/migrations; do
    [[ -d "$(at "$m")" ]] && immutable+=("'$(re_at "$(re_escape "$m")/")'")
  done
  # drizzle-kit rewrites drizzle/meta/ on every new migration: lock the SQL only.
  [[ -d "$(at drizzle)" ]] && immutable+=("'$(re_at 'drizzle/.*\.sql$')'")
  protected+=("'$(re_at 'package\.json$')'")
  local lock; lock="$(cd "$d" && first pnpm-lock.yaml yarn.lock bun.lockb bun.lock package-lock.json)"
  [[ -n "$lock" ]] && protected+=("'$(re_at "$(re_escape "$lock")\$")'")
  langs+=" js"
}

detect_python() {
  # The tool that runs commands inside the project's environment.
  local run="" py="python"
  if   [[ -f "$(at uv.lock)" ]];     then run="uv run " py="uv run python"
  elif [[ -f "$(at poetry.lock)" ]]; then run="poetry run " py="poetry run python"
  fi
  local deps='(^|[^a-z0-9_-])django([^a-z0-9_-]|$)'
  local django=0 why=""
  if [[ -f "$(at manage.py)" ]]; then django=1 why="manage.py"
  elif has_in pyproject.toml "$deps" || has_in uv.lock '^name = "django"$' || has_in poetry.lock '^name = "django"$'; then django=1 why="django in dependencies"
  else
    local r; for r in $(files "$(at 'requirements*.txt')"); do grep -qiE "^django([^a-z0-9_-]|$)" "$r" && { django=1 why="django in $r"; break; }; done
  fi
  if (( ! django )); then
    local s; s="$(files "$(at '*settings*.py')" | head -50 | xargs grep -l 'INSTALLED_APPS' 2>/dev/null | head -1 || true)"
    [[ -n "$s" ]] && django=1 why="INSTALLED_APPS in $s"
  fi

  local pytest=0
  if [[ -f "$(at pytest.ini)" || -n "$(files "$(at conftest.py)" "$(at '*/conftest.py')" | head -1)" ]] \
     || has_in pyproject.toml '(^\[tool\.pytest|pytest)' || has_in setup.cfg '^\[tool:pytest' \
     || [[ -n "$(files "$(at 'requirements*.txt')" | xargs grep -li '^pytest' 2>/dev/null | head -1 || true)" ]]; then
    pytest=1
  fi

  local lint="" typecheck="" tl="" tf=""
  ruff_configured && lint="${run}ruff check ."
  # import-linter keeps module boundaries: part of lint when configured.
  if [[ -f "$(at .importlinter)" ]] || has_in pyproject.toml '^\[tool\.importlinter' || has_in setup.cfg '^\[importlinter'; then
    lint="${lint:+$lint && }${run}lint-imports"
    [[ -f "$(at .importlinter)" ]] && protected+=("'$(re_at '\.importlinter$')'")
  fi
  if [[ -f "$(at mypy.ini)" || -f "$(at .mypy.ini)" ]] || has_in pyproject.toml '^\[tool\.mypy' || has_in setup.cfg '^\[mypy'; then
    typecheck="${run}mypy ."
  fi

  if (( django )); then
    if (( pytest )); then
      tl="${run}pytest -q -x <app-dir>" tf="${run}pytest"
    else
      tl="$py manage.py test <app.label>" tf="$py manage.py test"
    fi
    add_part "$d" django "$(at "$why")" "$lint" "$typecheck" "$tl" "$tf" ""
    test_globs+=("'$(at '*test_*.py')'" "'$(at '*tests.py')'")
    # Django names applied migrations 0001_…: those only grow. __init__.py may change.
    if [[ "$d" == . ]]; then immutable+=("'(^|/)migrations/[0-9]'")
    else immutable+=("'$(re_at '(.*/)?migrations/[0-9]')'"); fi
    local f
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      case "$f" in
        */settings/__init__.py) protected+=("'^$(re_escape "${f%__init__.py}")'") ;;
        *)                      protected+=("'^$(re_escape "$f")\$'") ;;
      esac
    done < <(files "$(at '*settings.py')" "$(at '*/settings/__init__.py')" | grep -vE '/tests?/' | head -5)
  else
    if [[ -n "$(files "$(at '*test_*.py')" "$(at '*_test.py')" | head -1)" ]]; then
      if [[ -n "$run" ]]; then tl="${run}pytest -q -x" tf="${run}pytest"
      else tl="python -m pytest -q -x" tf="python -m pytest"; fi
    fi
    add_part "$d" python "$(at "$(cd "$d" && first pyproject.toml setup.py requirements.txt)")" "$lint" "$typecheck" "$tl" "$tf" ""
    test_globs+=("'$(at '*test_*.py')'" "'$(at '*_test.py')'")
    [[ -d "$(at alembic/versions)" ]] && immutable+=("'$(re_at 'alembic/versions/')'")
    if [[ -n "$(files "$(at '*/migrations/__init__.py')" | head -1)" ]]; then
      if [[ "$d" == . ]]; then immutable+=("'(^|/)migrations/[0-9]'")
      else immutable+=("'$(re_at '(.*/)?migrations/[0-9]')'"); fi
    fi
  fi
  local f
  for f in pyproject.toml setup.py requirements.txt poetry.lock uv.lock; do
    [[ -f "$(at "$f")" ]] && protected+=("'$(re_at "$(re_escape "$f")\$")'")
  done
  langs+=" py"
}

is_python_dir() { [[ -f "$(at pyproject.toml)" || -f "$(at setup.py)" || -f "$(at manage.py)" ]] || { [[ "$d" == . ]] && [[ -f requirements.txt ]]; }; }

# --- Frappe app: <app>/hooks.py with app_name, next to <app>/patches.txt ------
frappe_app=""
while IFS= read -r h; do
  [[ "$h" == */*/* ]] && continue                 # only <app>/hooks.py
  hd="${h%/hooks.py}"
  if grep -q '^app_name' "$h" && [[ -f "$hd/patches.txt" ]]; then frappe_app="$hd"; break; fi
done < <(files '*/hooks.py')

if [[ -n "$frappe_app" ]]; then
  kind=frappe
  evidence="$frappe_app/hooks.py + $frappe_app/patches.txt"
  d=.
  ruff_configured && lint="ruff check ."
  test_local="bench --site \$SITE run-tests --app $frappe_app --module <dotted.module.of.the.change>"
  test_full="bench --site \$SITE run-tests --app $frappe_app"
  test_globs=("'$frappe_app/*test_*.py'")
  langs=" frappe"
  [[ -d "$frappe_app/patches" ]] && immutable+=("'^$(re_escape "$frappe_app")/patches/'")
  protected+=("'^$(re_escape "$frappe_app")/hooks\\.py\$'" "'^$(re_escape "$frappe_app")/patches\\.txt\$'")
  [[ -f pyproject.toml ]] && protected+=("'^pyproject\\.toml\$'")
else
  # The root first, then subfolders that hold a project of their own. A Node
  # root's subfolders are its workspaces and a Python root's subpackages are its
  # own: only the other language counts there (a Django root + frontend/).
  d=.
  root=""
  if [[ -f package.json ]]; then root=js; detect_node
  elif is_python_dir; then root=py; detect_python
  fi
  while IFS= read -r d; do
    [[ -z "$d" ]] && continue
    if [[ "$root" != py ]] && is_python_dir; then detect_python </dev/null
    elif [[ "$root" != js && -f "$d/package.json" ]]; then detect_node </dev/null
    fi
  done < <(files '*/package.json' '*/pyproject.toml' '*/setup.py' '*/manage.py' \
             | awk -F/ 'NF == 2 || (NF == 3 && $1 ~ /^(apps|services)$/) { sub("/[^/]*$", ""); print }' \
             | sort -u)
  d=.
fi

join_parts() {   # non-empty commands of every part, run one after the other
  local out="" c n=0
  for c in "$@"; do [[ -n "$c" ]] && n=$((n+1)); done
  for c in "$@"; do
    [[ -z "$c" ]] && continue
    [[ $n -gt 1 && "$c" == "cd "* ]] && c="($c)"
    out="${out:+$out && }$c"
  done
  echo "$out"
}
make_target() { local t; for t in "$@"; do grep -qE "^$t:" Makefile 2>/dev/null && { echo "make $t"; return; }; done; return 0; }

if (( ${#parts[@]} == 1 )); then
  IFS='|' read -r _ kind evidence <<<"${parts[0]}"
  lint="${p_lint[0]}" typecheck="${p_typecheck[0]}" test_local="${p_test_local[0]}" test_full="${p_test_full[0]}" build="${p_build[0]}"
elif (( ${#parts[@]} > 1 )); then
  kind=monorepo
  evidence=""
  for p in "${parts[@]}"; do
    IFS='|' read -r pd pk pe <<<"$p"
    [[ "$pd" == . ]] && pd=root
    evidence="${evidence:+$evidence; }$pd: $pk ($pe)"
  done
  lint="$(join_parts "${p_lint[@]}")"
  typecheck="$(join_parts "${p_typecheck[@]}")"
  test_local="$(join_parts "${p_test_local[@]}")"
  test_full="$(join_parts "${p_test_full[@]}")"
  build="$(join_parts "${p_build[@]}")"
  # A root Makefile that already ties the parts together wins.
  if [[ -f Makefile ]]; then
    t="$(make_target lint)";            [[ -n "$t" ]] && lint="$t"
    t="$(make_target typecheck type-check)"; [[ -n "$t" ]] && typecheck="$t"
    t="$(make_target test-local test-unit)"; [[ -n "$t" ]] && test_local="$t"
    t="$(make_target test)";            [[ -n "$t" ]] && test_full="$t"
    t="$(make_target build)";           [[ -n "$t" ]] && build="$t"
  fi
fi

case "$langs" in
  *frappe*)        test_case_regex='^[[:space:]]*def test_' ;;
  *py*js*|*js*py*) test_case_regex='^[[:space:]]*((async[[:space:]]+)?def test_|(it|test)(\.each\(.*\))?\()' ;;
  *py*)            test_case_regex='^[[:space:]]*(async[[:space:]]+)?def test_' ;;
  *)               test_case_regex='^[[:space:]]*(it|test)(\.each\(.*\))?\(' ;;
esac

business_rules=".ai/business-rules.md"
[[ -f docs/business-rules.md ]] && business_rules="docs/business-rules.md"

# How to start CI on a pushed branch before its PR exists (planner.md §4:
# red evidence for tests that only CI may run). GitHub: the one workflow with
# both workflow_dispatch and pull_request triggers, other than the guard.
ci_run=""
if [[ "$platform" == gitlab ]]; then
  ci_run='glab ci run --branch <branch>'
elif [[ "$platform" == github && -d .github/workflows ]]; then
  wfs=()
  for f in .github/workflows/*.yml .github/workflows/*.yaml; do
    [[ -f "$f" && "$(basename "$f")" != ai-guard.yml ]] || continue
    grep -qE '^[[:space:]]+workflow_dispatch:' "$f" && grep -qE '^[[:space:]]+pull_request:' "$f" && wfs+=("$(basename "$f")")
  done
  (( ${#wfs[@]} == 1 )) && ci_run="gh workflow run ${wfs[0]} --ref <branch>"
fi

platform_protected() {
  [[ "$platform" != gitlab ]] && echo "  - '^\\.github/'"
  [[ "$platform" != github ]] && printf "  - '^\\.gitlab/'\n  - '^\\.gitlab-ci\\.yml\$'\n"
  return 0
}

# Where specs for large work live (rules.md §3 Large): BMAD story files, or
# plain spec documents in a folder.
specs_block() {
  if [[ -d bmad-output ]]; then
    printf '# Large-work specs: BMAD story files.\nspecs:\n  bmad_stories: bmad-output/stories\n'
  elif [[ -d docs/specs ]]; then
    printf '# Large-work specs: one document per spec, each with its acceptance criteria.\nspecs:\n  docs: docs/specs\n'
  else
    printf '# Large-work specs (rules.md §3): none yet. Uncomment one when you have them.\n# specs:\n#   docs: docs/specs                  # plain spec documents\n#   bmad_stories: bmad-output/stories # or BMAD story files\n'
  fi
}

yaml_value() { if [[ -n "$1" ]]; then echo "$1"; else echo '""   # none found — fill in, or leave empty'; fi; }
yaml_list() {
  if (( $# == 0 )); then echo "  []   # none found"; return; fi
  local v; for v in "$@"; do echo "  - $v"; done
}

cat <<EOF
# crewlead project settings: what machines read (commands, paths, globs).
# Knowledge for agents lives in .ai/steering/ (product, tech, structure).
# This file belongs to the project: crewlead creates it once and never
# overwrites it.
#
# Detected by crewlead — kind: $kind ($evidence).
# Every value is a first guess: run the project-setup skill to review them with
# an agent, or check them by hand.
#
# Lists use one item per line ("  - value"); the CI guard reads them with a
# small parser, so keep this flat — no nested lists under these keys.
# Write regexes in SINGLE quotes: inside them a backslash is literal.

name: $name
default_branch: $default_branch

# Where issues and change requests live: github (gh, pull requests) or gitlab
# (glab, merge requests). rules.md §11 gives the commands for it.
platform: $(yaml_value "$platform")

# Commands agents run. test_local is the ONLY test command agents may run on a
# developer machine; CI runs test_full.
commands:
  lint: $(yaml_value "$lint")
  typecheck: $(yaml_value "$typecheck")
  test_local: $(yaml_value "$test_local")
  test_full: $(yaml_value "$test_full")
  build: $(yaml_value "$build")

# Starts CI on a pushed branch without a PR, for tests that only CI may run
# (not covered by test_local): the plan's red step pushes the tests alone and
# runs this. Empty: the implementor opens the draft PR early instead.
ci_run: $(yaml_value "$ci_run")

# Git pathspecs of test files ("*" also matches "/"). The guard counts test
# cases in these and rejects new skip/only markers in them.
test_globs:
$(yaml_list ${test_globs[@]+"${test_globs[@]}"})

# Regex (POSIX ERE) of one test case line, used to count cases.
test_case_regex: '$test_case_regex'

# Regexes (POSIX ERE) of repo paths whose committed files may only be ADDED,
# never edited, renamed or deleted.
immutable_paths:
$(yaml_list ${immutable[@]+"${immutable[@]}"})

# Regexes of paths where a wrong change costs the most. Touching one caps
# autonomy at A2 and labels the PR needs-lead-review.
# The first group protects the rules agents follow, for every tool: loosening a
# rule is a change a lead must see, in its own PR.
protected_paths:
  - '^\\.ai/'
  - '(^|/)AGENTS\\.md\$'
  - '(^|/)CLAUDE\\.md\$'
  - '^\\.(agents|claude|cursor|codex)/'
$(platform_protected)
$(yaml_list ${protected[@]+"${protected[@]}"} | grep -v '\[\]')

# Where screens come from (rules.md §5 Designs). none: agents design UI
# themselves, following the existing UI. figma (or another tool, with its link):
# the design is the contract. project-setup asks.
design: none
design_link: ""

# Which agent plays each role, by Herdr's agent names (claude, codex, cursor,
# gemini, …). One agent may play them all, each in its own session; the
# reviewer always starts from a fresh context.
agents:
  planner: claude
  implementor: codex
  reviewer: claude

# How agents pass the turn to each other (rules.md §2 Handoffs): auto (Herdr
# when it is running, otherwise the person pastes a short message), herdr, or
# manual.
handoff: auto

# Language of text written for people on issues and PRs: issue bodies, plans,
# stop reports, reviews, PR descriptions (en, th, …). Code, commits, files and
# machine markers stay in English. project-setup asks.
language: en

# Usernames (GitHub or GitLab) who may approve work on a protected path (a /go comment on the
# issue, and the PR review before merge). Never the developer driving the work
# or the issue's author: keep at least two people here. A team of one sets
# solo: true and lists only themselves (see rules.md §4 Approvals).
solo: false
approvers:
  - your-lead-login

# The full business rules, each with an ID (BR-<AREA>-<nn>). Intake, planner
# and reviewer read it; a PR that changes a rule updates it.
business_rules: $business_rules

# Label names for the flow's states. Rename one to use a label your board
# already has (e.g. in_review: Currently reviewing); the installer creates only
# the labels still named as below, and never changes a board's own label.
labels:
  queued: ai
  awaiting_approval: ai:awaiting-approval
  implementing: ai:implementing
  in_review: ai:in-review
  ready: ai:ready
  blocked: ai:blocked
  lead_review: needs-lead-review

$(specs_block)
EOF

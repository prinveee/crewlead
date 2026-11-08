#!/usr/bin/env bash
# crewlead PR guard — rules that must hold whoever (person or AI agent)
# wrote the change. Run by .github/workflows/ai-guard.yml on every PR, with
# this script AND the config taken from the PR's BASE commit, so a PR cannot
# loosen the rules it is checked against.
#
#   BASE_SHA   the PR's base commit          (required)
#   HEAD_SHA   the PR's head commit          (required)
#   PR_LABELS  comma-separated PR labels     (optional)
#   CONFIG     path to project.yml           (default .ai/project.yml)
#
# Hard failures, each waivable by a person adding the named label:
#   1. A committed file under immutable_paths changed        [allow-immutable-edit]
#   2. Added lines in test files skip or focus a test         [allow-test-skip]
#   3. The number of test cases went down                     [allow-test-removal]
# Soft signal: protected_paths touched → needs_lead_review=true in $GITHUB_OUTPUT.
set -euo pipefail

: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:?HEAD_SHA is required}"
CONFIG="${CONFIG:-.ai/project.yml}"
LABELS=",${PR_LABELS:-},"
OUT="${GITHUB_OUTPUT:-/dev/null}"
failed=0

[[ -f "$CONFIG" ]] || { echo "::error::guard config not found: $CONFIG"; exit 1; }

# Items of a flat top-level YAML list: `key:` followed by `  - value` lines.
# Strips one pair of surrounding quotes and trailing comments.
yaml_list() {
  awk -v key="$1" '
    $0 ~ "^" key ":[[:space:]]*$" { inlist = 1; next }
    inlist && /^[^[:space:]#]/ { inlist = 0 }
    inlist && /^[[:space:]]+-[[:space:]]+/ {
      sub(/^[[:space:]]+-[[:space:]]+/, "")
      if ($0 ~ /^\x27/) { sub(/^\x27/, ""); sub(/\x27[[:space:]]*(#.*)?$/, "") }
      else if ($0 ~ /^"/) { sub(/^"/, ""); sub(/"[[:space:]]*(#.*)?$/, "") }
      else { sub(/[[:space:]]+#.*$/, "") }
      print
    }' "$CONFIG"
}

# A top-level scalar `key: value`, quotes stripped.
yaml_scalar() {
  awk -v key="$1" '
    $0 ~ "^" key ":[[:space:]]" {
      sub("^" key ":[[:space:]]+", "")
      if ($0 ~ /^\x27/) { sub(/^\x27/, ""); sub(/\x27[[:space:]]*(#.*)?$/, "") }
      else if ($0 ~ /^"/) { sub(/^"/, ""); sub(/"[[:space:]]*(#.*)?$/, "") }
      print; exit
    }' "$CONFIG"
}

join_regex() { paste -sd'|' -; }

has_label() { [[ "$LABELS" == *",$1,"* ]]; }

fail() {
  local waiver="$1"; shift
  if has_label "$waiver"; then
    echo "::warning::$* (waived by label '$waiver')"
  else
    echo "::error::$* — fix it, or a person adds the label '$waiver' to accept it."
    failed=1
  fi
}

range="$BASE_SHA...$HEAD_SHA"
immutable_re=$(yaml_list immutable_paths | join_regex)
protected_re=$(yaml_list protected_paths | join_regex)
test_case_re=$(yaml_scalar test_case_regex)
test_case_re=${test_case_re:-'^[[:space:]]*(it|test)(\.each\(.*\))?\('}
test_globs=()
while IFS= read -r g; do [[ -n "$g" ]] && test_globs+=("$g"); done < <(yaml_list test_globs)

# 1. Immutable paths: committed files may only be added.
if [[ -n "$immutable_re" ]]; then
  changed=$(git diff --name-only --diff-filter=MDR "$range" | grep -E "$immutable_re" || true)
  if [[ -n "$changed" ]]; then
    fail allow-immutable-edit "Committed files under an immutable path were changed: $(echo "$changed" | tr '\n' ' ')"
  fi
fi

if (( ${#test_globs[@]} > 0 )); then
  # 2. No new skipped or focused tests.
  #    JS/TS: it/test/describe.skip|only|todo, xit, fit … · Python: unittest
  #    and Django (@skip, @skipIf, @skipUnless, @expectedFailure, self.skipTest),
  #    pytest (mark.skip/skipif/xfail, pytest.skip/xfail) · Go: t.Skip.
  skip_re='(\b(it|test|describe)\.(skip|only|todo|skipIf|runIf)\b|\b(xit|xtest|xdescribe|fit|fdescribe)\(|@pytest\.mark\.(skip|xfail)|\bpytest\.(skip|xfail)\(|@(unittest\.)?(skip|skipIf|skipUnless|expectedFailure)\b|\.skipTest\(|\bt\.Skip\()'
  added=$(git diff -U0 "$range" -- "${test_globs[@]}" | grep -E '^\+[^+]' | grep -E "$skip_re" || true)
  if [[ -n "$added" ]]; then
    fail allow-test-skip "Added lines skip or focus tests:
$added"
  fi

  # 3. The test-case count must not drop. A count, not a proof: it catches a
  #    deleted test file or a gutted describe block. Count from where the PR
  #    branched (the merge-base), not the base's tip: tests merged into the
  #    base after the branch was cut are not the PR's to lose.
  count() { { git grep -hE "$test_case_re" "$1" -- "${test_globs[@]}" || true; } | wc -l | tr -d ' '; }
  fork=$(git merge-base "$BASE_SHA" "$HEAD_SHA" 2>/dev/null || echo "$BASE_SHA")
  base_n=$(count "$fork")
  head_n=$(count "$HEAD_SHA")
  echo "Test cases: base=$base_n head=$head_n"
  if (( head_n < base_n )); then
    fail allow-test-removal "Test cases went down from $base_n to $head_n"
  fi
fi

# Protected paths → lead review.
touched=""
if [[ -n "$protected_re" ]]; then
  touched=$(git diff --name-only "$range" | grep -E "$protected_re" || true)
fi
if [[ -n "$touched" ]]; then
  echo "::notice::Protected paths touched — a lead review is required:"
  echo "$touched" | sed 's/^/  /'
  echo "needs_lead_review=true" >> "$OUT"
else
  echo "needs_lead_review=false" >> "$OUT"
fi

exit "$failed"

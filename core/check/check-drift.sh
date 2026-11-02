#!/usr/bin/env bash
# crewlead drift check — finds references in the agents' docs that no
# longer resolve, so rules and skills do not quietly point at moved files.
#
#   .ai/flow/check-drift.sh [file.md …]     (run from anywhere in the repo)
#
# Default files: AGENTS.md and CLAUDE.md (root and nested), .ai/**/*.md, and
# every SKILL.md under .agents/skills and .claude/skills. Checks:
#   1. A backticked path whose first folder exists in the repo must exist.
#      Placeholders (<…>, *, …, {…}) and paths under folders the repo does not
#      have (examples like `src/x.ts`) are skipped.
#   2. Every skill folder has a SKILL.md whose frontmatter has `name:` equal to
#      the folder name and a `description:`; no broken skill links.
#   3. Every backticked `commands.<key>` exists in .ai/project.yml, and the
#      file named by `business_rules` exists.
# Prints `file:line: problem` per finding; exits 1 if there is any.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
CONFIG=".ai/project.yml"
findings=0
report() { echo "$1"; findings=$((findings + 1)); }

files=()
if (( $# )); then
  files=("$@")
else
  while IFS= read -r f; do files+=("$f"); done < <(
    { find . \( -name AGENTS.md -o -name CLAUDE.md \) -not -path './.git/*' -not -path '*/node_modules/*'
      [[ -d .ai ]] && find .ai -name '*.md'
      for d in .agents/skills .claude/skills; do [[ -d $d ]] && find -L "$d" -name SKILL.md; done
    } 2>/dev/null | sed 's#^\./##' | sort -u)
fi

# Backticked tokens outside code fences: file<TAB>line<TAB>token
tokens() {
  awk '
    /^[[:space:]]*```/ { fence = !fence; next }
    fence { next }
    {
      line = $0
      while (match(line, /`[^`]+`/)) {
        printf "%s\t%d\t%s\n", FILENAME, FNR, substr(line, RSTART + 1, RLENGTH - 2)
        line = substr(line, RSTART + RLENGTH)
      }
    }' "$@"
}

yaml_scalar() {
  [[ -f "$CONFIG" ]] || return 0
  awk -v key="$1" '$0 ~ "^" key ":[[:space:]]" { sub("^" key ":[[:space:]]+", ""); sub(/[[:space:]]+#.*$/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit }' "$CONFIG"
}

# 1 + 3a. Paths and commands.<key> references.
if (( ${#files[@]} )); then
  while IFS=$'\t' read -r file line tok; do
    if [[ "$tok" =~ ^commands\.([a-z_]+)$ ]]; then
      key="${BASH_REMATCH[1]}"
      if [[ -f "$CONFIG" ]] && ! grep -qE "^[[:space:]]+$key:" "$CONFIG"; then
        report "$file:$line: \`$tok\` is not in $CONFIG"
      fi
      continue
    fi
    case "$tok" in
      *'<'*|*'*'*|*'…'*|*'{'*|*' '*|http*|-*|/*|~*|*'$'*) continue ;;
    esac
    [[ "$tok" =~ ^[A-Za-z0-9_.@/-]+$ ]] || continue
    [[ "$tok" == */* || "$tok" =~ \.(md|ya?ml|json|sh|tsv)$ ]] || continue
    path="${tok#./}"; path="${path%/}"
    top="${path%%/*}"
    [[ -e "$top" ]] || continue          # an example, or another repo's path
    [[ -e "$path" ]] || report "$file:$line: \`$tok\` does not exist"
  done < <(tokens "${files[@]}")
fi

# 2. Skills.
for d in .agents/skills .claude/skills; do
  [[ -d "$d" ]] || continue
  for s in "$d"/*; do
    [[ -e "$s" || -L "$s" ]] || continue
    name="$(basename "$s")"
    if [[ -L "$s" && ! -e "$s" ]]; then report "$s: broken link"; continue; fi
    [[ -d "$s" ]] || continue
    if [[ ! -f "$s/SKILL.md" ]]; then report "$s: no SKILL.md"; continue; fi
    fm="$(awk 'NR == 1 && !/^---[[:space:]]*$/ { exit } NR > 1 && /^---[[:space:]]*$/ { exit } NR > 1 { print }' "$s/SKILL.md")"
    if [[ -z "$fm" ]]; then report "$s/SKILL.md:1: no frontmatter"; continue; fi
    fm_name="$(sed -n 's/^name:[[:space:]]*//p' <<<"$fm" | tr -d "\"'" | head -1)"
    [[ "$fm_name" == "$name" ]] || report "$s/SKILL.md: name is '${fm_name:-missing}', expected '$name'"
    grep -q '^description:[[:space:]]*[^[:space:]]' <<<"$fm" || report "$s/SKILL.md: no description"
  done
done

# 3b. The business rules file.
br="$(yaml_scalar business_rules)"
if [[ -n "$br" && ! -e "$br" ]]; then
  report "$CONFIG: business_rules points at '$br', which does not exist"
fi

if (( findings )); then
  echo "drift: $findings finding(s)"
  exit 1
fi
echo "drift: none"

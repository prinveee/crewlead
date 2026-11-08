#!/usr/bin/env bash
# Install or update crewlead in a project repository.
#
#   Run through `crewlead init` / `crewlead update` (bin/crewlead), or directly:
#   lib/install.sh [--labels] [--platform github|gitlab] <target-repo>
#
#   --labels     also create the flow's labels (needs `gh` or `glab` auth)
#   --platform   where issues and change requests live. Without it the
#                installer reads it (project.yml, the remote, CI files) and,
#                when it cannot tell, asks — or warns when nobody can answer.
#
# Safe to re-run: managed files are replaced with this version; files the
# project owns (.ai/project.yml, .ai/steering/*.md) are created once and
# never overwritten; a project file that crewlead did not create is never
# clobbered — the installer warns and skips it instead.
set -euo pipefail

FLOW_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CORE="$FLOW_DIR/core"
VERSION="$(cat "$FLOW_DIR/VERSION")"
MARKER="crewlead"
# Files written before the rename say ai-dev-flow; they are still ours.
OWNED="(crewlead|ai-dev-flow)"

labels=0
target=""
platform_arg=""
while (( $# )); do
  case "$1" in
    --labels) labels=1 ;;
    --platform) platform_arg="${2:-}"; shift ;;
    --platform=*) platform_arg="${1#--platform=}" ;;
    -h|--help) sed -n 2,16p "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) target="$1" ;;
  esac
  shift
done
[[ -n "$target" ]] || { echo "usage: crewlead init|update [--labels] [--platform github|gitlab] <target-repo>" >&2; exit 2; }
case "$platform_arg" in ""|github|gitlab) ;; *) echo "--platform must be github or gitlab" >&2; exit 2 ;; esac
target="$(cd "$target" && pwd)"
git -C "$target" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "not a git repository: $target" >&2; exit 1; }
if [[ "$target" == "$FLOW_DIR" ]]; then
  echo "refusing to install crewlead into itself" >&2; exit 1
fi

warnings=()
warn() { warnings+=("$*"); }
done_items=()
note() { done_items+=("$*"); }

# Copy a managed file unless the target already has a file that is not ours.
copy_managed() {
  local src="$1" rel="$2" dst="$target/$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]] && ! grep -qE "$OWNED" "$dst"; then
    warn "skipped $rel — it exists and was not created by crewlead (merge by hand)"
    return
  fi
  cp "$src" "$dst"
  note "$rel"
}

# Create a project-owned file once.
create_once() {
  local src="$1" rel="$2" dst="$target/$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" ]]; then return; fi
  cp "$src" "$dst"
  note "$rel (new — fill it in)"
}

# 1. .ai/flow — wholly managed, replaced every time.
rm -rf "$target/.ai/flow"
mkdir -p "$target/.ai/flow/agents" "$target/.ai/flow/templates" "$target/.ai/flow/hooks"
cp "$CORE"/agents/*.md "$target/.ai/flow/agents/"
cp "$CORE/templates/plan.md" "$target/.ai/flow/templates/"
cp "$CORE/templates/business-rules.md" "$target/.ai/flow/templates/"
cp "$CORE/guard/guard.sh" "$target/.ai/flow/guard.sh"
cp "$CORE/check/check-drift.sh" "$target/.ai/flow/check-drift.sh"
cp "$CORE/hooks/pre-push" "$target/.ai/flow/hooks/pre-push"
chmod +x "$target/.ai/flow/guard.sh" "$target/.ai/flow/check-drift.sh" "$target/.ai/flow/hooks/pre-push"
cat > "$target/.ai/flow/README.md" <<EOF
# .ai/flow — managed by crewlead v$VERSION

Do not edit files in this folder: they are replaced on every install.
Change them in the crewlead repository, then run \`crewlead update\` here.
This project's own files are \`.ai/project.yml\` (settings) and \`.ai/steering/\` (knowledge).
EOF
echo "$VERSION" > "$target/.ai/flow/VERSION"
printf '# Managed by crewlead: scripts and hooks here keep Unix line endings on Windows.\n* text eol=lf\n' > "$target/.ai/flow/.gitattributes"
note ".ai/flow/ (agents, templates, guard, drift check, pre-push hook) v$VERSION"

# 2. Project-owned settings and steering (Kiro-style: product, tech, structure).
config_scalar() {
  [[ -f "$target/.ai/project.yml" ]] || return 0
  awk -v key="$1" '$0 ~ "^" key ":[[:space:]]" { sub("^" key ":[[:space:]]+", ""); sub(/[[:space:]]+#.*$/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit }' "$target/.ai/project.yml"
}
# A value under a top-level map, e.g. config_nested labels in_review.
config_nested() {
  [[ -f "$target/.ai/project.yml" ]] || return 0
  awk -v map="$1" -v key="$2" '
    $0 ~ "^" map ":[[:space:]]*$" { inmap = 1; next }
    inmap && /^[^[:space:]#]/ { inmap = 0 }
    inmap && $0 ~ "^[[:space:]]+" key ":[[:space:]]" {
      sub("^[[:space:]]+" key ":[[:space:]]+", ""); sub(/[[:space:]]+#.*$/, ""); gsub(/^["\x27]|["\x27]$/, ""); print; exit
    }' "$target/.ai/project.yml"
}

# Platform: what the person said, else what the project says, else what the
# repo shows, else ask. Unknown → install nothing platform-specific, and warn.
platform="$platform_arg"
[[ -z "$platform" ]] && platform="$(config_scalar platform)"
[[ -z "$platform" ]] && platform="$("$CORE/setup/detect-project.sh" --platform "$target")"
if [[ -z "$platform" && -t 0 && -t 1 ]]; then
  read -r -p "Where do this project's issues and change requests live? [github/gitlab] " platform </dev/tty || true
fi
case "$platform" in github|gitlab) ;; *) platform="" ;; esac

# project.yml is written once, from what the repo shows (core/setup/detect-project.sh).
if [[ ! -e "$target/.ai/project.yml" ]]; then
  mkdir -p "$target/.ai"
  PLATFORM="$platform" "$CORE/setup/detect-project.sh" "$target" > "$target/.ai/project.yml"
  note ".ai/project.yml (new — detected: $(sed -n 's/^# Detected by crewlead — kind: \(.*\)\.$/\1/p' "$target/.ai/project.yml"), platform: ${platform:-unknown}; review it with project-setup)"
elif [[ -n "$platform" && -z "$(config_scalar platform)" ]]; then
  warn ".ai/project.yml has no platform — add 'platform: $platform' so agents and the next install know it"
fi
if [[ -z "$platform" ]]; then
  warn "platform unknown — no issue/PR templates, guard or label steps were installed; run 'crewlead update --platform github|gitlab'"
fi
business_rules="$(config_scalar business_rules)"
if [[ -z "$business_rules" ]]; then
  warn ".ai/project.yml has no business_rules key — add 'business_rules: .ai/business-rules.md' (or where your rules live) and re-run"
else
  create_once "$CORE/templates/business-rules.md" "$business_rules"
fi
if ! grep -q '^approvers:' "$target/.ai/project.yml"; then
  warn ".ai/project.yml has no approvers list — work on protected paths cannot be approved until you add one (see AGENTS.md §4)"
elif grep -q 'your-lead-login' "$target/.ai/project.yml"; then
  warn ".ai/project.yml: approvers is still the example — put real usernames there"
fi
if ! grep -q '^language:' "$target/.ai/project.yml"; then
  warn ".ai/project.yml has no language — agents write issues, plans and reviews in English; add e.g. 'language: th' for another one"
fi
if ! grep -qF 'AGENTS\.md' "$target/.ai/project.yml"; then
  warn ".ai/project.yml: protected_paths does not cover the agents' rule files — add '(^|/)AGENTS\.md\$', '(^|/)CLAUDE\.md\$' and '^\.(agents|claude|cursor|codex)/'"
fi
for f in product tech structure; do
  create_once "$CORE/templates/steering/$f.md" ".ai/steering/$f.md"
done
if [[ -e "$target/.ai/project-rules.md" ]]; then
  warn ".ai/project-rules.md is from v0.1 and no longer read — move its content into .ai/steering/ and delete it"
fi

# Steering files in load order: the three core files, then any others.
steering_files=()
for f in product tech structure; do
  [[ -e "$target/.ai/steering/$f.md" ]] && steering_files+=("$target/.ai/steering/$f.md")
done
for f in "$target"/.ai/steering/*.md; do
  case "$(basename "$f")" in product.md|tech.md|structure.md) ;; *) [[ -e "$f" ]] && steering_files+=("$f") ;; esac
done

unfilled=()
for f in product tech structure; do
  cmp -s "$CORE/templates/steering/$f.md" "$target/.ai/steering/$f.md" && unfilled+=("$f.md")
done
if (( ${#unfilled[@]} )); then
  warn ".ai/steering/ still has empty templates (${unfilled[*]}) — run the project-setup skill in the project to draft them from the code"
fi

# Remember where crewlead lives, per clone and outside git, so project-setup can
# run `crewlead update` after it writes the steering even when crewlead is not on PATH.
src_file="$(cd "$target" && git rev-parse --git-path crewlead-source)"
[[ "$src_file" = /* ]] || src_file="$target/$src_file"
echo "$FLOW_DIR/bin/crewlead" > "$src_file"


# 3. AGENTS.md — generated from the base rules + the project's steering.
agents="$target/AGENTS.md"
if [[ -e "$agents" ]] && ! grep -qE "Generated by $OWNED" "$agents"; then
  warn "AGENTS.md exists and was not generated by crewlead — move its content into .ai/steering/, delete AGENTS.md, and re-run"
else
  {
    echo "<!-- Generated by $MARKER v$VERSION. Do not edit: change .ai/steering/*.md"
    echo "     (this project) or crewlead (every project), then run \`crewlead update\`. -->"
    echo
    cat "$CORE/AGENTS.base.md"
    echo
    if [[ -n "$platform" ]]; then
      cat "$CORE/platform/$platform.md"
    else
      echo "## 11. Platform: unknown"
      echo
      echo "\`.ai/project.yml\` does not say whether this project is on GitHub or GitLab."
      echo "Ask the person before any issue or change-request step, and suggest running \`crewlead update --platform github|gitlab\`."
    fi
    echo
    echo "---"
    echo
    echo "# Project steering"
    echo
    echo "Generated from \`.ai/steering/\`. Machine settings (commands, test globs,"
    echo "immutable and protected paths) are in \`.ai/project.yml\`."
    for f in ${steering_files[@]+"${steering_files[@]}"}; do
      echo
      echo "<!-- steering: .ai/steering/$(basename "$f") -->"
      # Demote headings one level (outside code fences) so each file nests
      # under "Project steering".
      awk '/^```/ { fence = !fence } !fence && /^#{1,5} / { $0 = "#" $0 } { print }' "$f"
    done
  } > "$agents"
  note "AGENTS.md (generated)"
fi

# 4. CLAUDE.md imports AGENTS.md, so Claude and Codex follow one set of rules.
claude_md="$target/CLAUDE.md"
if [[ ! -e "$claude_md" ]]; then
  printf '@AGENTS.md\n' > "$claude_md"
  note "CLAUDE.md (imports AGENTS.md)"
elif ! grep -qx '@AGENTS.md' "$claude_md"; then
  warn "CLAUDE.md exists without an '@AGENTS.md' line — add it so Claude reads the flow rules"
fi

# 5. Skills — one copy in .agents/skills (Codex, Cursor, any agent), linked
#    from .claude/skills (Claude Code). See AGENTS.md §10. A project may already
#    have made the two folders one (either one a link to the other): then the
#    copy is enough, and a per-skill link would point at itself.
mkdir -p "$target/.agents/skills" "$target/.claude/skills"
same_dir=0
[[ "$(cd -P "$target/.agents/skills" && pwd)" == "$(cd -P "$target/.claude/skills" && pwd)" ]] && same_dir=1
for src in "$CORE"/skills/*/; do
  name="$(basename "$src")"
  dst="$target/.agents/skills/$name"
  if [[ -L "$dst" ]] && (( same_dir )); then rm -f "$dst"; fi   # a self-link from v0.3.0
  if [[ -e "$dst" ]] && ! grep -qE "$OWNED" "$dst/SKILL.md" 2>/dev/null; then
    warn "skipped .agents/skills/$name — it exists and was not created by crewlead (merge by hand)"
    continue
  fi
  rm -rf "$dst"; mkdir -p "$dst"; cp -R "$src". "$dst/"
  (( same_dir )) && continue
  link="$target/.claude/skills/$name"
  if [[ -L "$link" || ! -e "$link" ]]; then
    rm -f "$link"; ln -s "../../.agents/skills/$name" "$link"
  elif grep -qE "$OWNED" "$link/SKILL.md" 2>/dev/null; then
    rm -rf "$link"; ln -s "../../.agents/skills/$name" "$link"
  else
    warn "skipped .claude/skills/$name — it exists and was not created by crewlead (merge by hand)"
  fi
done
if (( same_dir )); then
  note ".agents/skills/ ($(cd "$CORE/skills" && echo *)) — .agents/skills and .claude/skills are one folder here"
else
  note ".agents/skills/ ($(cd "$CORE/skills" && echo *)), linked from .claude/skills/"
fi
# v0.3 named the skills flow-*; remove those this flow made.
for old in flow-setup flow-intake flow-plan flow-review flow-next; do
  for d in .claude/skills .agents/skills; do
    p="$target/$d/$old"
    if [[ -L "$p" ]]; then rm -f "$p"
    elif [[ -f "$p/SKILL.md" ]] && grep -qE "$OWNED" "$p/SKILL.md"; then rm -rf "$p"; note "removed $d/$old (renamed)"
    fi
  done
done
# v0.2 shipped Claude-only slash commands; the skills replace them.
for f in "$target"/.claude/commands/flow-*.md; do
  [[ -e "$f" ]] && grep -qE "$OWNED" "$f" && rm "$f" && note "removed .claude/commands/$(basename "$f") (now a skill)"
done
rmdir "$target/.claude/commands" 2>/dev/null || true

# Claude Code deny rules.
settings="$target/.claude/settings.json"
mkdir -p "$target/.claude"
if [[ ! -e "$settings" ]]; then
  cp "$CORE/claude/settings.json" "$settings"
  note ".claude/settings.json (deny rules)"
elif command -v jq >/dev/null; then
  tmp="$(mktemp)"
  jq -s '.[0] * {permissions: ((.[0].permissions // {}) + {deny: (((.[0].permissions.deny // []) + .[1].permissions.deny) | unique)})}' \
    "$settings" "$CORE/claude/settings.json" > "$tmp" && mv "$tmp" "$settings"
  note ".claude/settings.json (deny rules merged)"
else
  warn "jq not found — merge core/claude/settings.json deny rules into .claude/settings.json by hand"
fi

# 6. Issue / change-request templates and the guard, for the project's platform.
if [[ "$platform" == github ]]; then
  for f in "$CORE"/github/ISSUE_TEMPLATE/*.yml; do
    copy_managed "$f" ".github/ISSUE_TEMPLATE/$(basename "$f")"
  done
  copy_managed "$CORE/github/pull_request_template.md" ".github/pull_request_template.md"
  copy_managed "$CORE/github/workflows/ai-guard.yml" ".github/workflows/ai-guard.yml"
elif [[ "$platform" == gitlab ]]; then
  for f in "$CORE"/gitlab/issue_templates/*.md; do
    copy_managed "$f" ".gitlab/issue_templates/$(basename "$f")"
  done
  copy_managed "$CORE/gitlab/merge_request_templates/Default.md" ".gitlab/merge_request_templates/Default.md"
  mkdir -p "$target/.ai/flow/ci"
  cp "$CORE/gitlab/ci/ai-guard.gitlab-ci.yml" "$target/.ai/flow/ci/"
  note ".ai/flow/ci/ai-guard.gitlab-ci.yml (guard job for merge request pipelines)"
  if ! grep -qs 'ai-guard.gitlab-ci.yml' "$target/.gitlab-ci.yml"; then
    warn "the guard does not run yet — add to .gitlab-ci.yml:  include: [{ local: .ai/flow/ci/ai-guard.gitlab-ci.yml }]"
  fi
fi

# 7. pre-push hook in this clone (hooks are not versioned; every clone runs install).
if [[ -n "$(git -C "$target" config --get core.hooksPath || true)" ]]; then
  warn "core.hooksPath is set — install .ai/flow/hooks/pre-push into that folder by hand"
else
  hook="$(cd "$target" && git rev-parse --git-path hooks)"
  [[ "$hook" = /* ]] || hook="$target/$hook"
  mkdir -p "$hook"
  if [[ -e "$hook/pre-push" ]] && ! grep -qE "$OWNED" "$hook/pre-push"; then
    warn "a pre-push hook already exists and is not crewlead's — chain .ai/flow/hooks/pre-push into it by hand"
  else
    cp "$CORE/hooks/pre-push" "$hook/pre-push"
    chmod +x "$hook/pre-push"
    note "git pre-push hook (blocks pushes to main and force pushes)"
  fi
fi

# 8. Labels. A state label the project renamed (project.yml → labels) is the
#    board's own: it is never created or changed here.
if (( labels )); then
  [[ -n "$platform" ]] || { echo "platform unknown — cannot create labels; pass --platform" >&2; exit 1; }
  cli=gh; [[ "$platform" == gitlab ]] && cli=glab
  command -v "$cli" >/dev/null || { echo "$cli not found — cannot create labels" >&2; exit 1; }
  created=0; kept=()
  while IFS=$'\t' read -r key name color desc; do
    [[ -z "$name" ]] && continue
    if [[ "$key" != - ]]; then
      mapped="$(config_nested labels "$key")"
      if [[ -n "$mapped" && "$mapped" != "$name" ]]; then kept+=("$mapped"); continue; fi
    fi
    if [[ "$cli" == gh ]]; then
      (cd "$target" && gh label create "$name" --color "$color" --description "$desc" --force >/dev/null)
    else
      (cd "$target" && glab label create --name "$name" --color "#$color" --description "$desc" >/dev/null 2>&1) || true
    fi
    created=$((created + 1))
  done < "$CORE/labels.tsv"
  note "$platform labels: $created created/updated${kept[0]+; board labels used as they are: ${kept[*]}}"
fi

echo "crewlead v$VERSION → $target"
for i in "${done_items[@]}"; do echo "  ✓ $i"; done
if (( ${#warnings[@]} )); then
  for w in "${warnings[@]}"; do echo "  ! $w"; done
fi
if (( ${#unfilled[@]} )); then
  echo
  echo "Next: open $target in Claude Code, Codex or Cursor and run the project-setup skill."
fi

#!/usr/bin/env bash
# Prints the local facts `check` needs, in one call instead of a dozen.
# Read-only: it changes nothing in the repository and makes no network call.
#
# Usage: gather.sh [--base <commit>] [--remote-head <commit>] [--committed]
#
# Without --base: the repository, the working tree, the review files, the
# guidelines and the repository's rule files.
# With --base: the merge-base, every changed file with its size and marks, and
# the scope against the existing report.

set -u
export GIT_OPTIONAL_LOCKS=0

base=''
remote_head=''
committed=''
while [ $# -gt 0 ]; do
  case $1 in
    --base) base=${2:?--base needs a commit}; shift 2 ;;
    --remote-head) remote_head=${2:?--remote-head needs a commit}; shift 2 ;;
    --committed) committed=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

g() { git -c core.quotePath=false "$@"; }
section() { printf '\n## %s\n' "$1"; }
lines() { grep -v '^$' | sort -u; }

top=$(g rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repository"; exit 1; }
cd "$top" || exit 1

branch=$(g branch --show-current)
head=$(g rev-parse HEAD)
common=$(g rev-parse --path-format=absolute --git-common-dir)
case $common in
  */.git) main_worktree=${common%/.git}; shared=yes ;;
  *) main_worktree=$top; shared=no ;;
esac
report=.review/branch-$(printf %s "$branch" | tr / -).md
guidelines=$HOME/.claude/pr-buddy/guidelines.md
untracked() { [ -n "$committed" ] || g ls-files --others --exclude-standard; }

if [ -z "$base" ]; then
  section Repository
  echo "root: $top"
  echo "branch: ${branch:-(detached HEAD)}"
  echo "head: $head"
  echo "origin: $(g remote get-url origin 2>/dev/null || echo none)"
  remote=$(g config --get "branch.$branch.remote")
  echo "branch remote: ${remote:-none}"
  [ -n "$remote" ] && echo "branch remote url: $(g remote get-url "$remote" 2>/dev/null)"
  echo "upstream: $(g rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || echo none)"
  default=$(g symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
  echo "default branch: ${default#origin/}"
  echo "now: $(date '+%Y-%m-%d %H:%M')"

  section "Working tree"
  status=$(g status --short --untracked-files=all)
  printf '%s\n' "${status:-clean}" | head -200
  [ "$(printf '%s\n' "$status" | wc -l)" -gt 200 ] && echo "(more than 200 entries, cut)"

  section "Review files"
  echo "report: $top/$report"
  g check-ignore -q "$report" && echo "report ignored: yes" || echo "report ignored: no"
  echo "waivers: $main_worktree/.review/waivers.md"
  echo "waivers shared across worktrees: $shared"
  g -C "$main_worktree" check-ignore -q .review/waivers.md && echo "waivers ignored: yes" || echo "waivers ignored: no"
  echo "global excludes file: $(g config --global core.excludesFile || echo none)"
  echo "clone excludes file: $(g rev-parse --path-format=absolute --git-path info/exclude)"
  for f in "$top/$report" "$main_worktree/.review/waivers.md"; do
    if [ -f "$f" ]; then printf '\n### %s\n\n' "$f"; cat "$f"; fi
  done

  section Guidelines
  if [ -s "$guidelines" ]; then
    echo "modified: $(date -r "$guidelines" '+%Y-%m-%d %H:%M')"
    echo
    cat "$guidelines"
  else
    echo "missing or empty: $guidelines"
  fi

  section "Repository rule files"
  g ls-files -- '*CONTRIBUTING*' '*CLAUDE.md' '*AGENTS.md' '*.editorconfig' \
    '*eslint*' '*prettier*' '*biome.json*' '*checkstyle*' '*detekt*' '*ktlint*' \
    '*.flake8' '*ruff.toml' '*pyproject.toml' '*setup.cfg' '*.golangci*' '*.rubocop.yml' \
    '*codecov.y*ml' '*jest.config*' '*vitest.config*' '*pom.xml' '*build.gradle*' \
    '.github/workflows/*' '.gitlab-ci.yml' | head -60
  exit 0
fi

section Diff
if ! g cat-file -e "$base^{commit}" 2>/dev/null; then
  echo "base missing locally: $base"
  exit 0
fi
mb=$(g merge-base "$base" HEAD)
echo "merge-base: $mb"
if [ -n "$committed" ]; then range="$mb HEAD"; else range=$mb; fi

changed=$( { g diff --name-only $range; untracked; } | lines)
uncommitted=''
[ -n "$committed" ] || uncommitted=$( { g diff --name-only HEAD; untracked; } | lines)
pushed=${remote_head:-$(g rev-parse -q --verify '@{upstream}')}
if [ -n "$pushed" ] && g cat-file -e "$pushed^{commit}" 2>/dev/null; then
  unpushed=$(g diff --name-only "$pushed" HEAD | lines)
else
  unpushed=$(g diff --name-only "$mb" HEAD | lines)
fi
has() { printf '%s\n' "$2" | grep -Fxq -- "$1"; }

echo "changed files: $(printf '%s\n' "$changed" | grep -c .)"
echo
echo "path | lines now | +added -removed | marks"
numstat=$(g diff --numstat $range)
printf '%s\n' "$changed" | grep . | while IFS= read -r path; do
  if [ -f "$path" ]; then size=$(wc -l < "$path" | tr -d ' '); else size=gone; fi
  delta=$(printf '%s\n' "$numstat" | awk -F'\t' -v p="$path" '$3 == p { print ($1 == "-" ? "binary" : "+" $1 " -" $2) }')
  marks=''
  has "$path" "$uncommitted" && marks=uncommitted
  has "$path" "$unpushed" && marks=${marks:+$marks,}unpushed
  echo "$path | $size | ${delta:-untracked} | ${marks:--}"
done

section Scope
if [ ! -f "$report" ]; then
  echo "full: no report yet"
  exit 0
fi
report_head=$(sed -n 's/^- Head: \([0-9a-f]\{40\}\).*/\1/p' "$report" | head -1)
last_checked=$(sed -n 's/^- Last checked: //p' "$report" | head -1)
if [ -s "$guidelines" ] && [ -n "$last_checked" ] && [[ $(date -r "$guidelines" '+%Y-%m-%d %H:%M') > $last_checked ]]; then
  echo "full: the guidelines changed after the last check ($last_checked)"
elif [ -z "$report_head" ] || ! g merge-base --is-ancestor "$report_head" HEAD 2>/dev/null; then
  echo "full: the report head ${report_head:-(none)} is not an ancestor of HEAD"
else
  if [ -n "$committed" ]; then since="$report_head HEAD"; else since=$report_head; fi
  touched=$( { g diff --name-only $since; untracked; } | lines)
  scope=$(printf '%s\n' "$changed" | grep -Fx -f <(printf '%s\n' "$touched" | grep .))
  echo "incremental since $report_head: $(printf '%s\n' "$scope" | grep -c .) of $(printf '%s\n' "$changed" | grep -c .) changed files"
  printf '%s\n' "$scope" | grep .
fi
exit 0

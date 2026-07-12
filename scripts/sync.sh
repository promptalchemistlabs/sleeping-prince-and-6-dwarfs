#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

REMOTE="${PAL_GIT_REMOTE:-origin}"
BRANCH="${PAL_GIT_BRANCH:-main}"

usage() {
  cat <<'EOF'
Usage: ./scripts/sync.sh [--remote NAME] [--branch NAME]

Fast-forward the parent repository and restore every submodule to the exact
commit recorded by the parent. Local commits, divergence, and dirty files are
rejected instead of being overwritten.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --remote)
      [[ $# -ge 2 ]] || die "--remote requires a value"
      REMOTE="$2"
      shift
      ;;
    --branch)
      [[ $# -ge 2 ]] || die "--branch requires a value"
      BRANCH="$2"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown sync option: $1" ;;
  esac
  shift
done

require_command git
assert_repo_root
assert_clean_worktree

current_branch="$(git -C "$REPO_ROOT" symbolic-ref --quiet --short HEAD || true)"
[[ "$current_branch" == "$BRANCH" ]] ||
  die "expected branch $BRANCH, found ${current_branch:-detached HEAD}"

git -C "$REPO_ROOT" remote get-url "$REMOTE" >/dev/null 2>&1 ||
  die "Git remote does not exist: $REMOTE"

log "fetching $REMOTE/$BRANCH"
git -C "$REPO_ROOT" fetch --prune "$REMOTE" "$BRANCH"

target="$REMOTE/$BRANCH"
git -C "$REPO_ROOT" rev-parse --verify "$target^{commit}" >/dev/null 2>&1 ||
  die "remote branch was not fetched: $target"

if ! git -C "$REPO_ROOT" merge-base --is-ancestor HEAD "$target"; then
  die "local branch contains commits or divergence not present on $target"
fi

log "fast-forwarding to $target"
git -C "$REPO_ROOT" merge --ff-only "$target"

log "synchronising submodule URLs and pinned revisions"
git -C "$REPO_ROOT" submodule sync --recursive
git -C "$REPO_ROOT" submodule update --init --recursive

assert_submodules_ready
assert_clean_worktree

head_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
remote_sha="$(git -C "$REPO_ROOT" rev-parse "$target")"
[[ "$head_sha" == "$remote_sha" ]] || die "local HEAD does not match $target after sync"

log "sync complete at $head_sha"

#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEBSITE_DIR="$REPO_ROOT/website"
DEPLOY_ROOT="${PAL_DEPLOY_ROOT:-$REPO_ROOT/.deploy}"

log() {
  printf '[pal] %s\n' "$*"
}

die() {
  printf '[pal] error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

assert_repo_root() {
  git -C "$REPO_ROOT" rev-parse --show-toplevel >/dev/null 2>&1 ||
    die "$REPO_ROOT is not a Git repository"
}

assert_clean_worktree() {
  local status
  status="$(git -C "$REPO_ROOT" status --porcelain --untracked-files=normal)"
  if [[ -n "$status" ]]; then
    printf '%s\n' "$status" >&2
    die "refusing to sync a dirty worktree; commit, stash, or remove the changes first"
  fi
}

assert_submodules_ready() {
  local line

  while IFS= read -r line; do
    case "$line" in
      -*) die "submodule is not initialised: $line" ;;
      +*) die "submodule is not at the commit recorded by the parent repository: $line" ;;
      U*) die "submodule has unresolved conflicts: $line" ;;
    esac
  done < <(git -C "$REPO_ROOT" submodule status --recursive)
}

activate_release() {
  local target="$1"
  local current_link="$DEPLOY_ROOT/current"
  local next_link="$DEPLOY_ROOT/current.next"

  rm -f "$next_link"
  ln -s "$target" "$next_link"

  case "$(uname -s)" in
    Linux) mv -Tf "$next_link" "$current_link" ;;
    Darwin) mv -fh "$next_link" "$current_link" ;;
    *)
      rm -f "$current_link"
      mv -f "$next_link" "$current_link"
      ;;
  esac
}

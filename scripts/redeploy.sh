#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

RUN_SYNC=1
SKIP_INSTALL=0

usage() {
  cat <<'EOF'
Usage: ./scripts/redeploy.sh [--skip-sync] [--skip-install]

Safely sync, validate, build, and atomically activate a static release.

Options:
  --skip-sync     Build the current checkout without pulling from Git.
  --skip-install  Reuse website/node_modules instead of running npm ci.
  -h, --help      Show this help.

Optional environment variables:
  PAL_DEPLOY_ROOT       Release directory (default: .deploy in the repo).
  PAL_DEPLOY_COMMAND    Provider-specific publish/restart command to run after
                        the release is activated.
  PAL_HEALTHCHECK_URL   URL that must return HTTP 2xx/3xx after activation.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-sync) RUN_SYNC=0 ;;
    --skip-install) SKIP_INSTALL=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "unknown redeploy option: $1" ;;
  esac
  shift
done

require_command git
require_command cp
require_command ln
require_command mv

healthcheck_tool=""
if [[ -n "${PAL_HEALTHCHECK_URL:-}" ]]; then
  if command -v curl >/dev/null 2>&1; then
    healthcheck_tool="curl"
  elif command -v python3 >/dev/null 2>&1; then
    healthcheck_tool="python3"
  else
    die "PAL_HEALTHCHECK_URL requires curl or python3"
  fi
fi

mkdir -p "$DEPLOY_ROOT/releases"
lock_dir="$DEPLOY_ROOT/redeploy.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  die "another redeploy appears to be running: $lock_dir"
fi
trap 'rm -rf "$lock_dir"' EXIT INT TERM

if [[ "$RUN_SYNC" -eq 1 ]]; then
  "$SCRIPT_DIR/sync.sh"
else
  log "sync skipped; deploying the current checkout"
fi

build_args=()
if [[ "$SKIP_INSTALL" -eq 1 ]]; then
  build_args+=(--skip-install)
fi
"$SCRIPT_DIR/build.sh" "${build_args[@]}"

release_id="$(date -u +%Y%m%dT%H%M%SZ)-$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD)-$$"
release_dir="$DEPLOY_ROOT/releases/$release_id"
current_link="$DEPLOY_ROOT/current"
previous_target=""

if [[ -L "$current_link" ]]; then
  previous_target="$(readlink "$current_link")"
fi

log "staging release $release_id"
mkdir "$release_dir"
cp -R "$WEBSITE_DIR/dist/." "$release_dir/"
printf '%s\n' "$(git -C "$REPO_ROOT" rev-parse HEAD)" >"$release_dir/REVISION"

activate_release "$release_dir"
log "activated $release_dir"

rollback() {
  if [[ -n "$previous_target" && -d "$previous_target" ]]; then
    activate_release "$previous_target"
    log "rolled back to $previous_target"
  else
    rm -f "$current_link"
    log "removed the failed release because no previous release exists"
  fi
}

if [[ -n "${PAL_DEPLOY_COMMAND:-}" ]]; then
  log "running the configured deployment hook"
  if ! (cd "$REPO_ROOT" && bash -lc "$PAL_DEPLOY_COMMAND"); then
    rollback
    die "deployment hook failed"
  fi
fi

if [[ -n "${PAL_HEALTHCHECK_URL:-}" ]]; then
  log "checking $PAL_HEALTHCHECK_URL"
  healthcheck_ok=0

  if [[ "$healthcheck_tool" == "curl" ]]; then
    if curl --fail --silent --show-error --location \
      --retry 5 --retry-delay 2 --retry-connrefused \
      "$PAL_HEALTHCHECK_URL" >/dev/null; then
      healthcheck_ok=1
    fi
  elif python3 - "$PAL_HEALTHCHECK_URL" <<'PY'
import sys
import time
from urllib.request import urlopen

url = sys.argv[1]
for attempt in range(6):
    try:
        with urlopen(url, timeout=10) as response:
            if 200 <= response.status < 400:
                raise SystemExit(0)
    except Exception as error:
        if attempt == 5:
            print(f"health check failed: {error}", file=sys.stderr)
            raise SystemExit(1)
        time.sleep(2)
raise SystemExit(1)
PY
  then
    healthcheck_ok=1
  fi

  if [[ "$healthcheck_ok" -ne 1 ]]; then
    rollback
    die "health check failed"
  fi
fi

log "redeploy complete: $release_id"

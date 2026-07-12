#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

require_command python3

current_link="$DEPLOY_ROOT/current"
[[ -d "$current_link" ]] ||
  die "no active release; run ./scripts/redeploy.sh first"

port="${PORT:-4321}"
case "$port" in
  '' | *[!0-9]*) die "PORT must be a number" ;;
esac

log "serving $current_link on 0.0.0.0:$port"
exec python3 -m http.server "$port" --bind 0.0.0.0 --directory "$current_link"

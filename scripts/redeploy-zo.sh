#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# This URL belongs to the public Zo HTTP service named `kingdom-of-pal`.
# Override it only when deploying an intentionally different Zo service.
export PAL_ZO_PUBLIC_URL="${PAL_ZO_PUBLIC_URL:-https://kingdom-of-pal-sayyidkhan.zocomputer.io}"
export PAL_HEALTHCHECK_URL="${PAL_HEALTHCHECK_URL:-${PAL_ZO_PUBLIC_URL%/}/}"

exec "$SCRIPT_DIR/redeploy.sh" "$@"

#!/usr/bin/env bash
# Launch Isaac Sim through the `isaacsim` entry point of the pip package.
#
#   bash scripts/launch_isaacsim.sh                         # full GUI app
#   bash scripts/launch_isaacsim.sh isaacsim.exp.full.kit --no-window
#   bash scripts/launch_isaacsim.sh --/app/window/width=1920
#
# The first argument is taken as the Kit experience file only if it ends in
# .kit; everything else passes straight through to Kit.
set -euo pipefail

EXPERIENCE="isaacsim.exp.full.kit"
if [[ $# -ge 1 && "$1" == *.kit ]]; then
    EXPERIENCE="$1"
    shift
fi

if ! command -v isaacsim >/dev/null 2>&1; then
    echo "error: 'isaacsim' not found. Run this through pixi: pixi run isaacsim" >&2
    exit 1
fi

exec isaacsim "$EXPERIENCE" "$@"

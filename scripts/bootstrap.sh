#!/usr/bin/env bash
# One-time setup on a fresh machine. Needs only git - no pixi environment yet.
# Safe to re-run: an existing checkout is left alone.
#
#   bash scripts/bootstrap.sh
#   pixi install
#
# Fetches the Isaac Lab sources that pixi.toml installs as editable packages.
# pixi resolves every environment in the manifest, so these must be on disk
# even for `pixi install` of the default (Isaac Sim only) environment.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -d IsaacLab/.git ]]; then
    # --match: other tags (e.g. perf-*) can sit on the same commit as the release.
    ref="$(git -C IsaacLab describe --tags --exact-match --match 'v*' 2>/dev/null \
        || git -C IsaacLab rev-parse --short HEAD)"
    echo "IsaacLab/ already present at $ref, leaving it alone."
    echo "To re-sync it to the pinned tag: bash scripts/isaaclab_setup.sh clone"
else
    bash scripts/isaaclab_setup.sh clone
fi

echo
echo "Sources ready. Next:"
echo "    pixi install           # Isaac Sim          -> .pixi/envs/default"
echo "    pixi install -e lab    # + Isaac Lab        -> .pixi/envs/lab (optional)"

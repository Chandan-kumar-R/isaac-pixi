#!/usr/bin/env bash
# Isaac Lab checkout and script runner. The pinned tag lives here and only here.
#
#   bash scripts/isaaclab_setup.sh clone          # clone, or re-sync to ISAACLAB_REF
#   bash scripts/isaaclab_setup.sh run train ...  # IsaacLab/scripts/reinforcement_learning/train.py
#   bash scripts/isaaclab_setup.sh run play ...   # IsaacLab/scripts/reinforcement_learning/play.py
#   bash scripts/isaaclab_setup.sh run <file.py>  # any script, relative to IsaacLab/ or this repo
#
# `clone` needs only git, so bootstrap.sh can call it before any pixi
# environment exists. `run` is meant for `pixi run -e lab isaaclab ...`.
set -euo pipefail
cd "$(dirname "$0")/.."

ISAACLAB_REF="${ISAACLAB_REF:-v3.0.0-beta2}"
ISAACLAB_URL="https://github.com/isaac-sim/IsaacLab.git"
ISAACLAB_DIR="IsaacLab"

usage() {
    sed -n '4,7p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

clone() {
    if [[ ! -d "$ISAACLAB_DIR/.git" ]]; then
        echo "Cloning Isaac Lab $ISAACLAB_REF into $ISAACLAB_DIR/"
        git -c advice.detachedHead=false clone --branch "$ISAACLAB_REF" --depth 1 "$ISAACLAB_URL" "$ISAACLAB_DIR"
        return
    fi

    # Editable installs point into this checkout, so local edits are live code.
    # Refuse to throw them away silently.
    if [[ -n "$(git -C "$ISAACLAB_DIR" status --porcelain --untracked-files=no)" ]]; then
        echo "error: $ISAACLAB_DIR/ has local changes. Commit, stash or discard them first." >&2
        exit 1
    fi

    echo "Re-syncing $ISAACLAB_DIR/ to $ISAACLAB_REF"
    git -C "$ISAACLAB_DIR" fetch --depth 1 origin "refs/tags/$ISAACLAB_REF:refs/tags/$ISAACLAB_REF"
    git -C "$ISAACLAB_DIR" -c advice.detachedHead=false checkout "$ISAACLAB_REF"
}

run() {
    [[ $# -ge 1 ]] || usage 1
    if [[ ! -d "$ISAACLAB_DIR/scripts" ]]; then
        echo "error: $ISAACLAB_DIR/ is missing. Run: bash scripts/bootstrap.sh" >&2
        exit 1
    fi

    local target="$1"
    shift
    case "$target" in
        train|play) target="$ISAACLAB_DIR/scripts/reinforcement_learning/$target.py" ;;
        *)
            if [[ ! -f "$target" && -f "$ISAACLAB_DIR/$target" ]]; then
                target="$ISAACLAB_DIR/$target"
            fi
            ;;
    esac

    if [[ ! -f "$target" ]]; then
        echo "error: no such script: $target" >&2
        exit 1
    fi
    exec python "$target" "$@"
}

case "${1:-}" in
    clone) shift; clone "$@" ;;
    run) shift; run "$@" ;;
    -h|--help|help) usage 0 ;;
    *) usage 1 ;;
esac

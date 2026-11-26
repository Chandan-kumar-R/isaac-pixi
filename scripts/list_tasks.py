"""List the gym environments registered by Isaac Lab.

    pixi run -e lab tasks-list          # every Isaac-* task
    pixi run -e lab tasks-list spot     # only ids containing "spot" (any case)

A lighter version of IsaacLab/scripts/environments/list_envs.py: one id per
line, case-insensitive filter, no preset enumeration.
"""

import argparse
import sys

parser = argparse.ArgumentParser(description="List registered Isaac Lab gym environments.")
parser.add_argument("filter", nargs="?", default="", help="Case-insensitive substring of the task id.")
args = parser.parse_args()

# Isaac Lab's task modules import Kit extensions, so the app must be up first.
from isaaclab.app import AppLauncher  # noqa: E402

simulation_app = AppLauncher(headless=True).app

import gymnasium as gym  # noqa: E402

import isaaclab_tasks  # noqa: E402, F401


def main():
    needle = args.filter.lower()
    ids = sorted(
        spec.id for spec in gym.registry.values() if spec.id.startswith("Isaac") and needle in spec.id.lower()
    )
    for task_id in ids:
        print(task_id)
    suffix = f' matching "{args.filter}"' if args.filter else ""
    print(f"\n{len(ids)} task(s){suffix}", file=sys.stderr)
    return 0 if ids else 1


if __name__ == "__main__":
    code = 1
    try:
        code = main()
    finally:
        simulation_app.close()
    sys.exit(code)

#!/usr/bin/env python3
"""Verify that each release checkout is the exact pinned clean commit."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "components.lock.json"


def git(checkout: Path, *args: str, capture: bool = False) -> str:
    result = subprocess.run(
        ["git", "-C", str(checkout), *args],
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
    )
    return result.stdout.strip() if capture else ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--component-root",
        type=Path,
        default=ROOT / "components",
        help="directory containing the component checkouts",
    )
    args = parser.parse_args()

    manifest = json.loads(LOCK.read_text())
    failures: list[str] = []
    for component in manifest["components"]:
        checkout = args.component_root / component["directory"]
        if not (checkout / ".git").exists():
            failures.append(f"{component['name']}: missing checkout {checkout}")
            continue
        try:
            head = git(checkout, "rev-parse", "HEAD", capture=True)
            git(checkout, "cat-file", "-e", f"{component['base_commit']}^{{commit}}")
            git(
                checkout,
                "merge-base",
                "--is-ancestor",
                component["base_commit"],
                component["release_commit"],
            )
            status = git(checkout, "status", "--porcelain", "--untracked-files=no", capture=True)
        except subprocess.CalledProcessError:
            failures.append(f"{component['name']}: commit ancestry verification failed")
            continue

        if head != component["release_commit"]:
            failures.append(
                f"{component['name']}: HEAD {head} != {component['release_commit']}"
            )
        if status:
            failures.append(f"{component['name']}: tracked worktree is dirty")
        if head == component["release_commit"] and not status:
            print(f"{component['name']}: {head} OK")

    if failures:
        raise SystemExit("\n".join(failures))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


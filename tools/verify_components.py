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
    expected_paths = {
        f"components/{component['directory']}": component
        for component in manifest["components"]
    }

    indexed_gitlinks: dict[str, str] = {}
    try:
        entries = git(ROOT, "ls-files", "--stage", "--", "components", capture=True)
    except subprocess.CalledProcessError:
        entries = ""
        failures.append("unable to read component gitlinks from the superproject index")

    for line in entries.splitlines():
        mode, object_id, stage, path = line.split(maxsplit=3)
        if mode != "160000" or stage != "0":
            failures.append(f"{path}: expected a stage-0 submodule gitlink")
            continue
        indexed_gitlinks[path] = object_id

    missing_gitlinks = sorted(set(expected_paths) - set(indexed_gitlinks))
    unexpected_gitlinks = sorted(set(indexed_gitlinks) - set(expected_paths))
    for path in missing_gitlinks:
        failures.append(f"{path}: missing submodule gitlink")
    for path in unexpected_gitlinks:
        failures.append(f"{path}: unexpected submodule gitlink")

    for component in manifest["components"]:
        relative_path = f"components/{component['directory']}"
        checkout = args.component_root / component["directory"]
        expected_url = f"../{component['repository'].rsplit('/', 1)[-1]}"

        if indexed_gitlinks.get(relative_path) != component["release_commit"]:
            failures.append(
                f"{component['name']}: gitlink {indexed_gitlinks.get(relative_path, 'missing')} "
                f"!= {component['release_commit']}"
            )

        try:
            module_path = git(
                ROOT,
                "config",
                "-f",
                ".gitmodules",
                "--get",
                f"submodule.{relative_path}.path",
                capture=True,
            )
            module_url = git(
                ROOT,
                "config",
                "-f",
                ".gitmodules",
                "--get",
                f"submodule.{relative_path}.url",
                capture=True,
            )
        except subprocess.CalledProcessError:
            failures.append(f"{component['name']}: missing .gitmodules entry")
            module_path = ""
            module_url = ""

        if module_path and module_path != relative_path:
            failures.append(
                f"{component['name']}: .gitmodules path {module_path} != {relative_path}"
            )
        if module_url and module_url != expected_url:
            failures.append(
                f"{component['name']}: .gitmodules URL {module_url} != {expected_url}"
            )

        if not (checkout / ".git").exists():
            failures.append(
                f"{component['name']}: uninitialized submodule {checkout}; "
                "run git submodule update --init --recursive"
            )
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

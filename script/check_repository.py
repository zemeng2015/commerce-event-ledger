#!/usr/bin/env python3
"""Check the tracked repository foundation without application dependencies."""

from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = (
    "README.md", "AGENTS.md", "LICENSE", "CONTRIBUTING.md",
    "CODE_OF_CONDUCT.md", "SECURITY.md", "CHANGELOG.md",
    "docs/project-charter.md", "docs/long-term-goal.md", "docs/roadmap.md",
    "docs/architecture.md", "docs/adr/0001-modular-monolith.md",
    "docs/adr/0002-acceptance-and-recovery.md",
    ".github/workflows/foundation.yml", ".github/dependabot.yml",
    ".github/pull_request_template.md",
    ".github/ISSUE_TEMPLATE/bug_report.yml",
    ".github/ISSUE_TEMPLATE/work_item.yml", ".github/ISSUE_TEMPLATE/config.yml",
)
TEXT_SUFFIXES = {".md", ".yml", ".yaml", ".py", ".json", ".toml"}
TEXT_NAMES = {"LICENSE", ".gitignore", ".gitattributes", ".editorconfig"}
LINK = re.compile(r"(?<!!)\[[^\]\n]+\]\(([^)\n]+)\)")


def main():
    tracked = subprocess.run(
        ["git", "ls-files", "-z"], cwd=ROOT,
        check=True, capture_output=True,
    ).stdout.decode("utf-8").split("\0")
    files = {name for name in tracked if name}
    errors = []
    checked_links = 0

    for name in REQUIRED:
        if name not in files or not (ROOT / name).is_file():
            errors.append(f"Required tracked file missing: {name}")

    for name in sorted(files):
        path = ROOT / name
        if path.suffix not in TEXT_SUFFIXES and path.name not in TEXT_NAMES:
            continue
        if not path.is_file():
            errors.append(f"Tracked file missing: {name}")
            continue
        try:
            content = path.read_bytes().decode("utf-8")
        except UnicodeDecodeError:
            errors.append(f"Invalid UTF-8: {name}")
            continue
        if content and not content.endswith("\n"):
            errors.append(f"Missing final newline: {name}")
        if re.search(r"^(?:<{7}|={7}|>{7})(?: |$)", content, re.MULTILINE):
            errors.append(f"Possible unresolved merge marker: {name}")
        if path.suffix != ".md":
            continue
        # This is a relative-file check, not a Markdown renderer or URL checker.
        content = re.sub(r"```.*?```", "", content, flags=re.DOTALL)
        for match in LINK.finditer(content):
            target = match.group(1).strip().split(' "', 1)[0].strip("<>")
            parsed = urlsplit(target)
            if parsed.scheme or target.startswith(("#", "//")):
                continue
            relative = unquote(parsed.path)
            if not relative:
                continue
            resolved = (path.parent / relative).resolve()
            if not resolved.is_relative_to(ROOT):
                errors.append(f"Link escapes repository: {name} -> {target}")
                continue
            repo_name = resolved.relative_to(ROOT).as_posix()
            if not resolved.is_file() or repo_name not in files:
                errors.append(f"Untracked or missing link target: {name} -> {target}")
            checked_links += 1

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"PASS: {len(files)} tracked files; {checked_links} relative file links checked.")
    print("Repository checks only; use Application CI to validate Rails/MySQL behavior.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

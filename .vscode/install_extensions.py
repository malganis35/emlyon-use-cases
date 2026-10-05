# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Install the extensions listed in .vscode/extensions.json if they are missing."""

import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


def load_recommendations(path: Path) -> list[str]:
    """Read extensions.json (JSONC), stripping // comments outside of strings."""
    raw = path.read_text(encoding="utf-8-sig")
    raw = re.sub(r'(?m)^\s*//.*$', "", raw)  # full-line comments
    raw = re.sub(r',(\s*[}\]])', r"\1", raw)  # trailing commas
    return json.loads(raw)["recommendations"]


def main() -> int:
    # On Windows, plain "code" may resolve to a non-executable shell script: prefer code.cmd.
    code = shutil.which("code.cmd") or shutil.which("code")
    if code is None:
        print("'code' CLI not found in PATH, skipping installation.")
        return 0

    try:
        wanted = load_recommendations(Path(__file__).parent / "extensions.json")
    except (OSError, json.JSONDecodeError, KeyError) as exc:
        print(f"Unable to read extensions.json: {exc}")
        return 1

    result = subprocess.run(
        [code, "--list-extensions"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=False,
    )
    installed = {line.strip().lower() for line in result.stdout.splitlines()}

    missing = [ext for ext in wanted if ext.lower() not in installed]
    if not missing:
        print("All extensions are already installed.")
        return 0

    failed = []
    for ext in missing:
        print(f"Installing {ext}...")
        proc = subprocess.run([code, "--install-extension", ext], check=False)
        if proc.returncode != 0:
            failed.append(ext)

    if failed:
        print(f"Failed: {', '.join(failed)}")
        return 1

    print("Done. Reload the window if some extensions are not active.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

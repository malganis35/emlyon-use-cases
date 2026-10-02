import csv
import subprocess
import sys
from pathlib import Path

FIXTURES = Path(__file__).parent / "fixtures"


def run(*args):
    return subprocess.run(
        [sys.executable, "-m", "emlyon_use_cases.cli", *args],
        capture_output=True,
        text=True,
        check=False,
    )


def read(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.reader(f, delimiter=";"))


def test_degrade_builds_expected_csvs(tmp_path):
    result = run(
        "degrade", "--manifest", str(FIXTURES / "manifest.yaml"), "--dst", str(tmp_path)
    )
    assert result.returncode == 0, result.stderr
    part1 = read(tmp_path / "retail_sales_part1.csv")
    part2 = read(tmp_path / "retail_sales_part2.csv")
    assert part1[0] == [
        "Order ID",
        "Channel",
        "Product",
        "Price",
        "Note",
        "Empty 1",
        "Empty 2",
    ]
    assert len(part1) == 1 + 2 + 3  # header + junk + 3 data rows
    assert part1[1][0] == part1[2][0] == "zz_test"
    assert part1[3][1].startswith("Sales Channel: ")
    assert part1[3][2] == "1-Ball"
    assert part1[3][4] == "a, b"  # embedded comma survives quoting
    assert len(part2) == 1 + 3 and part2[0] == [
        "Order ID",
        "Channel",
        "Product",
        "Price",
        "Note",
    ]


def test_degrade_is_reproducible_and_clean(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    for dst in (a, b):
        assert (
            run(
                "degrade",
                "--manifest",
                str(FIXTURES / "manifest.yaml"),
                "--dst",
                str(dst),
            ).returncode
            == 0
        )
    for name in ("retail_sales_part1.csv", "retail_sales_part2.csv"):
        raw = (a / name).read_bytes()
        assert raw == (b / name).read_bytes()
        assert not raw.startswith(b"\xef\xbb\xbf") and b"\r" not in raw


def test_degrade_missing_column_fails(tmp_path):
    manifest = tmp_path / "manifest.yaml"
    manifest.write_text(
        f"use_case: r\ntables:\n  - name: t\n    source: {FIXTURES / 'sales.csv'}\n"
        "    disqualities:\n      - {type: value_prefix, column: Nope, prefix: x}\n"
    )
    result = run("degrade", "--manifest", str(manifest), "--dst", str(tmp_path / "out"))
    assert result.returncode == 1 and "Unknown column 'Nope'" in result.stderr


def test_profile_outputs_columns():
    import json

    result = run("profile", "--src", str(FIXTURES / "sales.csv"))
    assert result.returncode == 0, result.stderr
    info = json.loads(result.stdout)
    kinds = {c["name"]: c["kind"] for c in info["columns"]}
    assert info["rows"] == 6
    assert kinds["Price"] == "numeric" and kinds["Channel"] == "text"
    assert next(c for c in info["columns"] if c["name"] == "Price")["has_decimals"]

from pathlib import Path

import pytest

from emlyon_use_cases.manifest import load_manifest

VALID = """
use_case: retail
seed: 7
tables:
  - name: sales_part1
    source: sales.csv
    rows: [0, 5]
    disqualities:
      - {type: junk_rows, column: id, count: 2}
      - {type: value_prefix, column: channel, prefix: "Sales Channel: "}
  - name: team
    source: book.xlsx
    sheet: Team
"""


def write(tmp_path: Path, text: str) -> Path:
    p = tmp_path / "manifest.yaml"
    p.write_text(text, encoding="utf-8")
    return p


def test_valid_manifest(tmp_path):
    uc = load_manifest(write(tmp_path, VALID))
    assert uc.name == "retail" and uc.seed == 7
    assert [t.name for t in uc.tables] == ["sales_part1", "team"]
    assert uc.tables[0].kind == "csv" and uc.tables[0].rows == (0, 5)
    assert uc.tables[0].source == tmp_path / "sales.csv"
    assert uc.tables[1].kind == "xlsx" and uc.tables[1].sheet == "Team"
    assert uc.tables[0].disqualities[0] == ("junk_rows", {"column": "id", "count": 2})


@pytest.mark.parametrize(
    "bad, message",
    [
        (
            "use_case: r\ntables:\n  - {name: a, source: a.csv}\n  - {name: a, source: b.csv}\n",
            "duplicate",
        ),
        (
            "use_case: r\ntables:\n  - {name: a, source: a.csv, disqualities: [{type: nope}]}\n",
            "Unknown disquality",
        ),
        (
            "use_case: r\ntables:\n  - {name: a, source: a.csv, disqualities: [{type: junk_rows}]}\n",
            "missing params",
        ),
        ("use_case: r\ntables:\n  - {name: A b, source: a.csv}\n", "must match"),
        ("use_case: r\ntables:\n  - {name: a, source: a.txt}\n", ".xlsx or .csv"),
        ("use_case: r\ntables: []\n", "at least one table"),
    ],
)
def test_invalid_manifest(tmp_path, bad, message):
    with pytest.raises(ValueError, match=message):
        load_manifest(write(tmp_path, bad))


@pytest.mark.parametrize(
    "bad, message",
    [
        ("use_case: gdp\ntables:\n  - {name: a, source: a.csv}\n", "reserved"),
        (
            "use_case: superstore\ntables:\n  - {name: part1, source: a.csv}\n",
            "reserved",
        ),
        ("use_case: r\ntables:\n  - {name: order, source: a.csv}\n", "reserved word"),
        (
            "use_case: r\ntables:\n  - {name: a, source: a.csv, disqualities: [{type: null_columns, names: Empty}]}\n",
            "non-empty list",
        ),
        (
            "use_case: r\ntables:\n  - {name: a, source: a.csv, disqualities: [{type: null_columns, names: [E, E]}]}\n",
            "unique",
        ),
        (
            "use_case: r\ntables:\n  - {name: a, source: a.csv, disqualities: [{type: null_columns, names: [E], position: middle}]}\n",
            "position",
        ),
        (
            "use_case: r\ntables:\n  - {name: a, source: a.csv, disqualities: [{type: mixed_decimal, column: p, ratio: 3}]}\n",
            "ratio",
        ),
    ],
)
def test_reserved_and_invalid_values(tmp_path, bad, message):
    with pytest.raises(ValueError, match=message):
        load_manifest(write(tmp_path, bad))

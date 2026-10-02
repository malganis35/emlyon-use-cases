"""Use case manifest: one YAML file describing sources, tables and disqualities."""

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from emlyon_use_cases.disqualities import check_params

_IDENTIFIER = re.compile(r"^[a-z][a-z0-9_]*$")
_TABLE_KEYS = {"name", "source", "sheet", "rows", "disqualities"}
_USE_CASE_KEYS = {"use_case", "seed", "tables"}


# The three original datasets are managed by the hand-written scripts: a manifest must never
# target their schemas or overwrite their CSVs.
RESERVED_USE_CASES = {"gdp", "superstore", "allsales"}
EXISTING_CSVS = {
    "life_expectancy.csv",
    "continent_mapping.csv",
    "superstore_part1.csv",
    "superstore_part2.csv",
    "nomenclature.csv",
    "allsales_part1.csv",
    "allsales_part2.csv",
    "allsales_team.csv",
    "allsales_store.csv",
}

# Snowflake reserved keywords (unquoted identifiers must not use them)
SNOWFLAKE_RESERVED = {
    "ACCOUNT", "ALL", "ALTER", "AND", "ANY", "AS", "BETWEEN", "BY", "CASE", "CAST", "CHECK",
    "COLUMN", "CONNECT", "CONNECTION", "CONSTRAINT", "CREATE", "CROSS", "CURRENT",
    "CURRENT_DATE", "CURRENT_TIME", "CURRENT_TIMESTAMP", "CURRENT_USER", "DATABASE", "DELETE",
    "DISTINCT", "DROP", "ELSE", "EXISTS", "FALSE", "FOLLOWING", "FOR", "FROM", "FULL", "GRANT",
    "GROUP", "GSCLUSTER", "HAVING", "ILIKE", "IN", "INCREMENT", "INNER", "INSERT", "INTERSECT",
    "INTO", "IS", "ISSUE", "JOIN", "LATERAL", "LEFT", "LIKE", "LOCALTIME", "LOCALTIMESTAMP",
    "MINUS", "NATURAL", "NOT", "NULL", "OF", "ON", "OR", "ORDER", "ORGANIZATION", "QUALIFY",
    "REGEXP", "REVOKE", "RIGHT", "RLIKE", "ROW", "ROWS", "SAMPLE", "SCHEMA", "SELECT", "SET",
    "SOME", "START", "TABLE", "TABLESAMPLE", "THEN", "TO", "TRIGGER", "TRUE", "TRY_CAST",
    "UNION", "UNIQUE", "UPDATE", "USING", "VALUES", "VIEW", "WHEN", "WHENEVER", "WHERE", "WITH",
}  # fmt: skip


def csv_filename(use_case: str, table: str) -> str:
    """Name of the generated CSV (flat ./data directory, so prefixed by the use case)."""
    return f"{use_case}_{table}.csv"


@dataclass
class Table:
    name: str
    source: Path
    kind: str  # "xlsx" | "csv"
    sheet: str | None = None
    rows: tuple[int, int] | None = (
        None  # [start, end) slice of data rows (Part 1 / Part 2)
    )
    disqualities: list[tuple[str, dict[str, Any]]] = field(default_factory=list)


@dataclass
class UseCase:
    name: str
    seed: int
    tables: list[Table]


def _fail(path: Path, message: str) -> ValueError:
    return ValueError(f"{path}: {message}")


def _parse_table(raw: Any, base_dir: Path, path: Path) -> Table:
    if not isinstance(raw, dict):
        raise _fail(path, "each table must be a mapping")
    unknown = raw.keys() - _TABLE_KEYS
    if unknown:
        raise _fail(path, f"table has unknown keys {sorted(unknown)}")
    for key in ("name", "source"):
        if key not in raw:
            raise _fail(path, f"table is missing '{key}'")
    name = str(raw["name"])
    if not _IDENTIFIER.match(name):
        raise _fail(path, f"table name '{name}' must match {_IDENTIFIER.pattern}")

    source = base_dir / str(raw["source"])
    suffix = source.suffix.lower()
    if suffix == ".xlsx":
        kind = "xlsx"
    elif suffix == ".csv":
        kind = "csv"
    else:
        raise _fail(path, f"table '{name}': source must be .xlsx or .csv")

    rows = raw.get("rows")
    if rows is not None:
        if not (isinstance(rows, list) and len(rows) == 2 and 0 <= rows[0] < rows[1]):
            raise _fail(
                path, f"table '{name}': rows must be [start, end] with 0 <= start < end"
            )
        rows = (int(rows[0]), int(rows[1]))

    disqualities = []
    for item in raw.get("disqualities") or []:
        if not isinstance(item, dict) or "type" not in item:
            raise _fail(path, f"table '{name}': each disquality needs a 'type'")
        params = {k: v for k, v in item.items() if k != "type"}
        try:
            check_params(item["type"], params)
        except ValueError as e:
            raise _fail(path, f"table '{name}': {e}") from None
        disqualities.append((item["type"], params))

    return Table(name, source, kind, raw.get("sheet"), rows, disqualities)


def load_manifest(path: Path) -> UseCase:
    """Load and validate a manifest. Sources are resolved relative to the manifest's folder."""
    path = Path(path)
    raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise _fail(path, "manifest must be a mapping")
    unknown = raw.keys() - _USE_CASE_KEYS
    if unknown:
        raise _fail(path, f"unknown keys {sorted(unknown)}")
    name = str(raw.get("use_case", ""))
    if not _IDENTIFIER.match(name):
        raise _fail(path, f"use_case '{name}' must match {_IDENTIFIER.pattern}")
    if not raw.get("tables"):
        raise _fail(path, "at least one table is required")

    if name in RESERVED_USE_CASES or name.upper() in SNOWFLAKE_RESERVED:
        raise _fail(path, f"use_case '{name}' is reserved, choose another name")
    tables = [_parse_table(t, path.parent, path) for t in raw["tables"]]
    for t in tables:
        if t.name.upper() in SNOWFLAKE_RESERVED:
            raise _fail(path, f"table name '{t.name}' is a Snowflake reserved word")
        if csv_filename(name, t.name) in EXISTING_CSVS:
            raise _fail(
                path, f"table '{t.name}' would overwrite an existing dataset CSV"
            )
    names = [t.name for t in tables]
    duplicates = {n for n in names if names.count(n) > 1}
    if duplicates:
        raise _fail(path, f"duplicate table names {sorted(duplicates)}")
    return UseCase(name, int(raw.get("seed", 0)), tables)

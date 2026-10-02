"""Build the degraded CSVs of a use case from its manifest, and profile raw sources."""

import csv
import tempfile
from pathlib import Path

from emlyon_use_cases.converter import convert_xlsx_to_csv, normalize_and_copy_csv
from emlyon_use_cases.disqualities import apply_all
from emlyon_use_cases.manifest import Table, UseCase, csv_filename

_DELIMITERS = ";,\t|"


def read_table(
    source: Path, kind: str, sheet: str | None = None
) -> tuple[list[str], list[list[str]]]:
    """Read a CSV or an .xlsx sheet as (header, rows), all values as strings."""
    if not source.exists():
        raise FileNotFoundError(f"Source file not found: {source}")
    with tempfile.TemporaryDirectory() as tmp:
        staged = Path(tmp) / "staged.csv"
        if kind == "xlsx":
            convert_xlsx_to_csv(source, staged, sheet)
            delimiter = ";"
        else:
            normalize_and_copy_csv(source, staged)
            first_line = staged.read_text(encoding="utf-8").split("\n", 1)[0]
            delimiter = max(_DELIMITERS, key=first_line.count)
        with open(staged, newline="", encoding="utf-8") as f:
            data = list(csv.reader(f, delimiter=delimiter))
    if not data:
        raise ValueError(f"Source is empty: {source}")
    header, rows = data[0], data[1:]
    width = len(header)
    return header, [r + [""] * (width - len(r)) if len(r) < width else r for r in rows]


def write_csv(path: Path, header: list[str], rows: list[list[str]]) -> None:
    """Write a ';'-delimited, UTF-8 (no BOM), LF CSV."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=";", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def build_table(table: Table, seed: int) -> tuple[list[str], list[list[str]]]:
    header, rows = read_table(table.source, table.kind, table.sheet)
    source = (header, rows)
    if table.rows:
        rows = rows[table.rows[0] : table.rows[1]]
    return apply_all(header, rows, table.disqualities, seed, table.name, source)


def degrade_use_case(
    use_case: UseCase, dst_dir: Path
) -> dict[str, tuple[list[str], int]]:
    """Write one CSV per table in dst_dir. Returns {table: (header, data row count)}."""
    result = {}
    for table in use_case.tables:
        header, rows = build_table(table, use_case.seed)
        filename = csv_filename(use_case.name, table.name)
        write_csv(dst_dir / filename, header, rows)
        result[table.name] = (header, len(rows))
        print(f"-> {filename}: {len(rows)} rows, {len(header)} columns")
    return result


def _is_number(value: str) -> bool:
    try:
        float(value.replace(",", "."))
    except ValueError:
        return False
    return True


def profile_source(source: Path, sheet: str | None = None) -> dict:
    """Describe the columns of a raw source so disqualities can target suitable ones."""
    kind = "xlsx" if source.suffix.lower() == ".xlsx" else "csv"
    header, rows = read_table(source, kind, sheet)
    columns = []
    for i, name in enumerate(header):
        values = [r[i] for r in rows]
        filled = [v for v in values if v != ""]
        distinct = sorted(set(filled))
        columns.append(
            {
                "name": name,
                "kind": "numeric"
                if filled and all(_is_number(v) for v in filled)
                else "text",
                "has_decimals": any("." in v or "," in v for v in filled),
                "empty": len(values) - len(filled),
                "distinct": len(distinct),
                "samples": distinct[:3],
            }
        )
    return {"source": str(source), "rows": len(rows), "columns": columns}

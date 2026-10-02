"""Pedagogical data disqualities injected into the generated CSVs.

Each disquality is a pure function ``(header, rows, params, rng) -> (header, rows)``.
They are idempotent: applying one to a table that already carries it is a no-op,
so already degraded sources (e.g. ``allsales_team`` with its ``zz_test`` rows) are safe.
"""

import random
import re
from collections.abc import Callable
from typing import Any

Header = list[str]
Rows = list[list[str]]

_NUMERIC_COMMA = re.compile(r"^-?\d+,\d+$")


def _index(header: Header, column: str) -> int:
    try:
        return header.index(column)
    except ValueError:
        raise ValueError(f"Unknown column '{column}' (available: {header})") from None


def junk_rows(header: Header, rows: Rows, params: dict[str, Any], rng: random.Random):
    """Insert rows right after the header: only one column filled with a marker."""
    col = _index(header, params["column"])
    marker = str(params.get("marker", "zz_test"))
    count = int(params.get("count", 3))
    if any(len(r) > col and r[col] == marker for r in rows[:count]):
        return header, rows
    junk = []
    for _ in range(count):
        row = [""] * len(header)
        row[col] = marker
        junk.append(row)
    return header, junk + rows


def null_columns(
    header: Header, rows: Rows, params: dict[str, Any], rng: random.Random
):
    """Add explicitly named, empty columns (named so both platforms agree on names)."""
    names = [n for n in params["names"] if n not in header]
    if not names:
        return header, rows
    if params.get("position", "end") == "start":
        return names + header, [[""] * len(names) + r for r in rows]
    return header + names, [r + [""] * len(names) for r in rows]


def value_prefix(
    header: Header, rows: Rows, params: dict[str, Any], rng: random.Random
):
    """Prefix every non-empty value of a column with a constant string."""
    col = _index(header, params["column"])
    prefix = str(params["prefix"])
    out = [
        r[:col]
        + [prefix + r[col] if r[col] and not r[col].startswith(prefix) else r[col]]
        + r[col + 1 :]
        for r in rows
    ]
    return header, out


def code_prefix(
    header: Header,
    rows: Rows,
    params: dict[str, Any],
    rng: random.Random,
    source: tuple[Header, Rows] | None = None,
):
    """Prefix values with a stable code per distinct value: ``1-Foo``, ``2-Bar``, ``11-Baz``.

    Codes are computed on the full source (before any Part 1 / Part 2 split), so the same
    value gets the same code in every part. Apply it before ``junk_rows`` on the same column.
    """
    col = _index(header, params["column"])
    sep = str(params.get("separator", "-"))
    values = {r[col] for r in rows if r[col]}
    already = re.compile(rf"^\d+{re.escape(sep)}")
    matching = [v for v in values if already.match(v)]
    if matching and len(matching) == len(values):
        return header, rows
    if matching:
        raise ValueError(
            f"Column '{params['column']}' is partially prefixed (e.g. '{matching[0]}'): "
            "apply code_prefix before junk_rows on the same column"
        )
    universe = values
    if source is not None and params["column"] in source[0]:
        src_col = source[0].index(params["column"])
        universe = {r[src_col] for r in source[1] if r[src_col]}
    start = int(params.get("start", 1))
    codes = {v: start + i for i, v in enumerate(sorted(universe))}
    out = [
        r[:col] + [f"{codes[r[col]]}{sep}{r[col]}" if r[col] else r[col]] + r[col + 1 :]
        for r in rows
    ]
    return header, out


def mixed_decimal(
    header: Header, rows: Rows, params: dict[str, Any], rng: random.Random
):
    """Turn the decimal point into a comma on a fraction of a numeric column's values."""
    col = _index(header, params["column"])
    ratio = float(params.get("ratio", 0.5))
    if any(_NUMERIC_COMMA.match(r[col]) for r in rows):
        return header, rows
    if not any("." in r[col] for r in rows):
        raise ValueError(
            f"Column '{params['column']}' has no '.' decimal values to mix"
        )
    out = []
    for r in rows:
        value = r[col]
        if "." in value and rng.random() < ratio:
            value = value.replace(".", ",")
        out.append(r[:col] + [value] + r[col + 1 :])
    return header, out


# type -> (function, required params, optional params)
REGISTRY: dict[str, tuple[Callable, set[str], set[str]]] = {
    "junk_rows": (junk_rows, {"column"}, {"count", "marker"}),
    "null_columns": (null_columns, {"names"}, {"position"}),
    "value_prefix": (value_prefix, {"column", "prefix"}, set()),
    "code_prefix": (code_prefix, {"column"}, {"start", "separator"}),
    "mixed_decimal": (mixed_decimal, {"column"}, {"ratio"}),
}


def check_params(kind: str, params: dict[str, Any]) -> None:
    """Raise ValueError if the type is unknown or the params are missing / unexpected."""
    if kind not in REGISTRY:
        raise ValueError(
            f"Unknown disquality type '{kind}' (known: {sorted(REGISTRY)})"
        )
    _, required, optional = REGISTRY[kind]
    missing = required - params.keys()
    unexpected = params.keys() - required - optional
    if missing:
        raise ValueError(f"Disquality '{kind}': missing params {sorted(missing)}")
    if unexpected:
        raise ValueError(f"Disquality '{kind}': unexpected params {sorted(unexpected)}")
    _validate_values(kind, params)


def _validate_values(kind: str, params: dict[str, Any]) -> None:
    if kind == "null_columns":
        names = params["names"]
        if not (
            isinstance(names, list)
            and names
            and all(isinstance(n, str) and n.strip() for n in names)
            and len(set(names)) == len(names)
        ):
            raise ValueError(
                "Disquality 'null_columns': names must be a non-empty list of unique, non-empty strings"
            )
        if params.get("position", "end") not in ("start", "end"):
            raise ValueError(
                "Disquality 'null_columns': position must be 'start' or 'end'"
            )
    elif kind == "mixed_decimal":
        if not 0 < float(params.get("ratio", 0.5)) <= 1:
            raise ValueError("Disquality 'mixed_decimal': ratio must be in ]0, 1]")
    elif kind == "junk_rows":
        if int(params.get("count", 3)) < 1:
            raise ValueError("Disquality 'junk_rows': count must be >= 1")


def apply_all(
    header: Header,
    rows: Rows,
    disqualities: list[tuple[str, dict[str, Any]]],
    seed: int,
    table: str,
    source: tuple[Header, Rows] | None = None,
) -> tuple[Header, Rows]:
    """Apply disqualities in order, each with its own reproducible random generator.

    ``source`` is the full (header, rows) before slicing, used by disqualities that must
    be consistent across the parts of a split table (``code_prefix``).
    """
    junk_columns: set[str] = set()
    for i, (kind, params) in enumerate(disqualities):
        check_params(kind, params)
        if kind == "junk_rows":
            junk_columns.add(params["column"])
        elif (
            kind in ("value_prefix", "code_prefix") and params["column"] in junk_columns
        ):
            raise ValueError(
                f"Disquality '{kind}' on '{params['column']}' must come before junk_rows "
                "on the same column (the marker would be prefixed too)"
            )
        rng = random.Random(f"{seed}:{table}:{i}")
        extra = {"source": source} if kind == "code_prefix" else {}
        header, rows = REGISTRY[kind][0](header, rows, params, rng, **extra)
    return header, rows

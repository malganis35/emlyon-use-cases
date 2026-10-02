import pytest

from emlyon_use_cases.disqualities import apply_all

HEADER = ["id", "channel", "product", "price"]
ROWS = [
    ["1", "Online", "Ball", "10.5"],
    ["2", "Store", "Bat", "3.25"],
    ["3", "Online", "Ball", "7.0"],
    ["4", "Store", "Glove", "2"],
]


def run(disqualities, seed=0, header=HEADER, rows=ROWS):
    return apply_all(list(header), [list(r) for r in rows], disqualities, seed, "t")


def test_junk_rows():
    header, rows = run([("junk_rows", {"column": "id", "count": 3})])
    assert header == HEADER and len(rows) == len(ROWS) + 3
    assert rows[0] == ["zz_test", "", "", ""] and rows[3] == ROWS[0]


def test_null_columns():
    header, rows = run([("null_columns", {"names": ["Empty 1", "Empty 2"]})])
    assert header == HEADER + ["Empty 1", "Empty 2"]
    assert all(r[-2:] == ["", ""] and len(r) == 6 for r in rows)


def test_null_columns_start():
    header, rows = run([("null_columns", {"names": ["E"], "position": "start"})])
    assert header[0] == "E" and rows[0][0] == "" and rows[0][1] == "1"


def test_value_prefix():
    _, rows = run(
        [("value_prefix", {"column": "channel", "prefix": "Sales Channel: "})]
    )
    assert [r[1] for r in rows] == ["Sales Channel: Online", "Sales Channel: Store"] * 2


def test_code_prefix_is_stable_per_value():
    _, rows = run([("code_prefix", {"column": "product", "start": 1})])
    assert [r[2] for r in rows] == ["1-Ball", "2-Bat", "1-Ball", "3-Glove"]


def test_mixed_decimal_mixes_both_separators():
    header = ["price"]
    data = [[f"{i}.5"] for i in range(200)]
    _, rows = run(
        [("mixed_decimal", {"column": "price", "ratio": 0.5})], header=header, rows=data
    )
    commas = sum("," in r[0] for r in rows)
    dots = sum("." in r[0] for r in rows)
    assert commas > 0 and dots > 0 and commas + dots == 200


def test_mixed_decimal_requires_decimal_values():
    with pytest.raises(ValueError, match="no '.' decimal"):
        run([("mixed_decimal", {"column": "id"})])


def test_unknown_column():
    with pytest.raises(ValueError, match="Unknown column"):
        run([("value_prefix", {"column": "nope", "prefix": "x"})])


ALL = [
    ("junk_rows", {"column": "id", "count": 2}),
    ("null_columns", {"names": ["E1", "E2"]}),
    ("value_prefix", {"column": "channel", "prefix": "Sales Channel: "}),
    ("code_prefix", {"column": "product"}),
    ("mixed_decimal", {"column": "price", "ratio": 1.0}),
]


def test_idempotent():
    once = run(ALL)
    twice = apply_all(once[0], [list(r) for r in once[1]], ALL, 0, "t")
    assert twice == once


def test_same_seed_same_output_and_inputs_untouched():
    data = [[f"{i}.5"] for i in range(50)]
    spec = [("mixed_decimal", {"column": "price"})]
    a = run(spec, seed=3, header=["price"], rows=data)
    b = run(spec, seed=3, header=["price"], rows=data)
    c = run(spec, seed=4, header=["price"], rows=data)
    assert a == b and a != c
    assert data[0] == ["0.5"]


def test_code_prefix_consistent_across_parts():
    source = (HEADER, ROWS)
    spec = [("code_prefix", {"column": "product"})]
    part1 = apply_all(list(HEADER), [list(r) for r in ROWS[:2]], spec, 0, "t", source)[
        1
    ]
    part2 = apply_all(list(HEADER), [list(r) for r in ROWS[2:]], spec, 0, "t", source)[
        1
    ]
    assert [r[2] for r in part1 + part2] == ["1-Ball", "2-Bat", "1-Ball", "3-Glove"]


def test_code_prefix_partial_prefix_is_an_error():
    rows = [["1", "x", "1-Ball", "1"], ["2", "x", "Bat", "1"]]
    with pytest.raises(ValueError, match="partially prefixed"):
        run([("code_prefix", {"column": "product"})], rows=rows)


def test_prefix_after_junk_rows_on_same_column_is_an_error():
    spec = [
        ("junk_rows", {"column": "product"}),
        ("code_prefix", {"column": "product"}),
    ]
    with pytest.raises(ValueError, match="before junk_rows"):
        run(spec)

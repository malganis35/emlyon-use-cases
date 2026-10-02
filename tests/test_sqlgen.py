import re
import subprocess
import sys
from pathlib import Path

import pytest

from emlyon_use_cases.sqlgen import databricks_schema, snowflake_column_names

ROOT = Path(__file__).parent.parent
FIXTURES = Path(__file__).parent / "fixtures"


def existing_tables():
    """(table, databricks schema string, snowflake columns) of the 9 hand-written tables."""
    dbx = (ROOT / "script/databricks/03_load_tables.sql").read_text(encoding="utf-8")
    snow = (ROOT / "script/snowflake/03_load_tables.sql").read_text(encoding="utf-8")
    dbx_tables = re.findall(
        r"CREATE OR REPLACE TABLE (\w+)\.(\w+).*?schema => '(.*?)'\n\);", dbx, re.DOTALL
    )
    snow_tables = re.findall(
        r"CREATE OR REPLACE TABLE (\w+)\.(\w+) \((.*?)\n\)", snow, re.DOTALL
    )
    assert len(dbx_tables) == len(snow_tables) == 9
    out = []
    for (_, name, schema), (_, snow_name, cols) in zip(
        dbx_tables, snow_tables, strict=True
    ):
        assert name.upper() == snow_name
        out.append((name, schema, re.findall(r"^\s+(\w+) STRING", cols, re.MULTILINE)))
    return out


@pytest.mark.parametrize("name, schema, snow_cols", existing_tables())
def test_matches_existing_scripts(name, schema, snow_cols):
    header = [
        "" if re.fullmatch(r"_c\d+", n) else n
        for n in re.findall(r"`(.*?)` STRING", schema)
    ]
    assert databricks_schema(header) == schema
    assert snowflake_column_names(header) == snow_cols


def test_snowflake_names_edge_cases():
    assert snowflake_column_names(
        ["", "", "a b", "A_B", "1st", "SalesAgentID", "Order qty"]
    ) == [
        "COLUMN_1",
        "COLUMN_2",
        "A_B",
        "A_B_2",
        "COL_1ST",
        "SALES_AGENT_ID",
        "ORDER_QTY",
    ]


@pytest.fixture
def generated(tmp_path):
    manifest = str(FIXTURES / "manifest.yaml")
    base = [sys.executable, "-m", "emlyon_use_cases.cli"]
    data, script = tmp_path / "data", tmp_path / "script"
    run = lambda *a: subprocess.run(
        base + list(a), capture_output=True, text=True, check=False
    )
    assert run("degrade", "--manifest", manifest, "--dst", str(data)).returncode == 0
    result = run(
        "generate-sql",
        "--manifest",
        manifest,
        "--data",
        str(data),
        "--dst",
        str(script),
    )
    assert result.returncode == 0, result.stderr
    return script, run, manifest, data


def test_generated_sql_content(generated):
    script, *_ = generated
    dbx = (script / "databricks/generated/retail/03_load_tables.sql").read_text()
    snow = (script / "snowflake/generated/retail/03_load_tables.sql").read_text()
    # part1: 3 data rows + 2 junk rows; part2: 3 rows
    assert "5 AS expected FROM retail.sales_part1" in dbx
    assert "3 AS expected FROM retail.sales_part2" in dbx
    assert "5 AS expected FROM RETAIL.SALES_PART1" in snow
    assert "`Empty 1` STRING, `Empty 2` STRING" in dbx
    assert "  EMPTY_1 STRING,\n  EMPTY_2 STRING\n)" in snow
    assert "CAST(" not in dbx.upper() and "CAST(" not in snow.upper()


def test_generated_sql_rules(generated):
    script, *_ = generated
    for path in script.rglob("*.sql"):
        text = "\n".join(
            line for line in path.read_text().splitlines() if not line.startswith("--")
        )
        assert not re.search(
            r"CREATE (TABLE|SCHEMA|VOLUME|STAGE|DATABASE|WAREHOUSE|ROLE)(?! (OR REPLACE|IF NOT EXISTS))",
            text,
        ), path
        assert not re.search(
            r"GRANT\s+(ALL|MODIFY|WRITE|CREATE|INSERT|UPDATE|DELETE|OWNERSHIP)",
            text,
            re.IGNORECASE,
        ), path
        assert "WRITE VOLUME" not in text.upper(), path


def test_generation_is_idempotent(generated):
    script, run, manifest, data = generated
    before = {p: p.read_text() for p in script.rglob("*.sql")}
    assert (
        run(
            "generate-sql",
            "--manifest",
            manifest,
            "--data",
            str(data),
            "--dst",
            str(script),
        ).returncode
        == 0
    )
    assert {p: p.read_text() for p in script.rglob("*.sql")} == before


def test_generate_sql_requires_degraded_csvs(tmp_path):
    result = subprocess.run(
        [
            sys.executable,
            "-m",
            "emlyon_use_cases.cli",
            "generate-sql",
            "--manifest",
            str(FIXTURES / "manifest.yaml"),
            "--data",
            str(tmp_path),
            "--dst",
            str(tmp_path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 1 and "run 'degrade' first" in result.stderr


def test_generated_upload_scripts(generated):
    script, *_ = generated
    dbx = script / "databricks/generated/retail/02_upload_files.sh"
    snow = script / "snowflake/generated/retail/02_upload_files.sh"
    for path in (dbx, snow):
        assert subprocess.run(["bash", "-n", str(path)], check=False).returncode == 0, (
            path
        )
        text = path.read_text()
        assert "retail_sales_part1.csv" in text and "retail_sales_part2.csv" in text
        assert "2 files transferred" in text and "@" not in text.replace(
            "@RAW_STAGE", ""
        ).replace("@retail", "")
    assert dbx.read_text().count("upload retail_sales_") == 2
    assert "dbfs:/Volumes/$CATALOG/$SCHEMA/raw_files/$file" in dbx.read_text()
    # embedded Python of the Snowflake script must compile once the shell variables are substituted
    body = snow.read_text().split('python3 -c "', 1)[1].rsplit('"\n', 1)[0]
    compile(
        body.replace("$SRC_DIR", "d").replace("$CONNECTION", "c"),
        "snowflake_upload",
        "exec",
    )
    assert "('retail_sales_part1.csv', 'RETAIL')," in body


def test_snowflake_reserved_words_get_suffix():
    assert snowflake_column_names(["Order", "Group", "Name"]) == [
        "ORDER_COL",
        "GROUP_COL",
        "NAME",
    ]


def test_snowflake_grants_include_database_and_warehouse(generated):
    script, *_ = generated
    text = (script / "snowflake/generated/retail/04_grants_bi.sql").read_text()
    assert "GRANT USAGE ON WAREHOUSE EMLYON_WH TO ROLE BI_STUDENT_ROLE" in text
    assert "GRANT USAGE ON DATABASE EMLYON_USE_CASES TO ROLE BI_STUDENT_ROLE" in text

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
Pedagogical data pipeline for emlyon Business School BI & DataViz courses (Power BI / Tableau). Raw source files in `use_cases/{gdp,superstore,allsales}/` are converted into 9 `;`-delimited CSVs in `data/` (gitignored, regenerated locally), then loaded into two parallel warehouses: **Databricks Unity Catalog** (`script/databricks/`) and **Snowflake** (`script/snowflake/`). `README.md` is the instructor deployment tutorial and documents the student connection settings.

## Commands
- Install: `uv sync`
- Generate `data/`: `uv run emlyon-use-cases prepare` (options `--src ./use_cases --dst ./data`; with no subcommand it runs `prepare`)
- Upload to Databricks volumes: `bash script/databricks/02_upload_files.sh ./data` (profile from `$DATABRICKS_PROFILE`, default `emlyon`)
- Upload to Snowflake stages: `bash script/snowflake/02_upload_files.sh ./data` (connection from `$SNOWSQL_CONN`, default `emlyon`, read from `~/.snowflake/connections.toml`)
- The `01_`, `03_`, `04_` and `99_` SQL scripts run manually in the Databricks SQL Editor or Snowsight, in numeric order. `03_load_tables.sql` ends with a row-count check query that compares each table to its expected count.

- New use case with disqualities: run the `/nouveau-dataset` skill, or by hand `uv run emlyon-use-cases degrade --manifest use_cases/<name>/manifest.yaml --dst ./data`, then `generate-sql --manifest ... --data ./data --dst ./script`. `profile --src <file>` prints the columns of a raw source as JSON.
- Check or prepare an instructor machine (uv, Node, git, Databricks and Snowflake CLIs and connections): run the `/setup-instructeur` skill.
- Lint / format Python: `uv run ruff check src/` and `uv run ruff format src/`. Ruff is a dev dependency, and a `.claude/` PostToolUse hook runs it automatically on every `.py` file Claude edits.

Tests: `uv run pytest` (covers the manifest, disqualities, CLI and SQL generation). Single test: `uv run pytest tests/test_sqlgen.py::test_name -q`. Fixtures live in `tests/fixtures/`. There is no CI.

## Architecture
- **Python CLI** (`src/emlyon_use_cases/`): `converter.prepare_datasets()` holds a hardcoded `mappings` list of (source path, output CSV, `xlsx`|`csv`, sheet name). XLSX sheets are exported with `openpyxl` (`data_only=True`, empty rows skipped). CSV sources are copied with the UTF-8 BOM removed and CRLF converted to LF. The Databricks upload script normalizes BOM and CRLF a second time with `sed`.
- **One layer per warehouse: 1 CSV = 1 table**, built in `03_load_tables.sql` (9 tables: `life_expectancy`, `continent_mapping`, `superstore_part1`, `superstore_part2`, `nomenclature`, `allsales_part1`, `allsales_part2`, `allsales_team`, `allsales_store`). Every column is a STRING, **all** CSV columns are kept, with no union, no rename, no cast and no constraints, so students get the same data as the CSVs and preprocess it themselves. Databricks keeps the original column names; Snowflake uses snake_case uppercase names. Each `03_` script starts with `DROP TABLE IF EXISTS` for the legacy `raw_*` / `fact_*` / `dim_*` tables.
- **Platform loading differs. Watch for this when editing:**
  - Databricks uses `SELECT * FROM read_files(..., header => true, inferColumnTypes => false)`, so column order and names come from the CSV header (an empty header becomes `_c0`).
  - Snowflake uses `COPY INTO` straight into tables with `SKIP_HEADER = 1`, loading columns **by position** in file order. Any change to a source file's column order or set must be mirrored in the Snowflake `CREATE TABLE` column lists (including the unnamed first column of `allsales_team.csv` and `allsales_store.csv`, named `COLUMN_1`).
  - Superstore part1 and part2 have different column orders (the "union by name" trap). They are two separate tables on both platforms, and each Snowflake table follows its own file's order.
- **Naming**: Databricks uses lowercase schemas `gdp`, `superstore`, `allsales` in catalog `emlyon_use_cases`, with a `raw_files` volume per schema. Snowflake uses uppercase `GDP`/`SUPERSTORE`/`ALLSALES` in `EMLYON_USE_CASES`, with an `@RAW_STAGE` stage and a `CSV_FORMAT_SEMICOLON` file format per schema, on warehouse `EMLYON_WH`.

- **Manifest-driven use cases** (new datasets): `use_cases/<name>/manifest.yaml` is the single source. `manifest.py` loads it, `disqualities.py` holds the pure, idempotent, seeded disquality functions (`junk_rows`, `null_columns`, `value_prefix`, `code_prefix`, `mixed_decimal`), `degrade.py` builds the CSVs (`<use_case>_<table>.csv`, `;`, UTF-8 without BOM, LF), and `sqlgen.py` generates the `01_`/`02_`/`03_`/`04_` scripts of both platforms under `script/<platform>/generated/<use_case>/` from the real CSV headers and row counts. Generated files must never be edited by hand: fix the manifest or `sqlgen.py` and regenerate. The three original datasets (`gdp`, `superstore`, `allsales`) still use the hand-written scripts below.

### Adding or changing one of the three original datasets
The file list is duplicated in several places, so update all of them together:
- the `mappings` list in `converter.py`
- the file lists in both `02_upload_files.sh` scripts
- the schema, volume or stage setup in both `01_` scripts (only for a new use case)
- the table and row-count check in both `03_load_tables.sql` scripts
- the grants in both `04_` scripts (only for a new schema)
- the hardcoded "9 files" messages and the README file list and traps table

## Principles & Rules
1. **Pedagogical traps**: Do NOT clean intentional raw-data anomalies in SQL. These include the incomplete continent mapping (Europe, Asia, Mars), decimal commas, prefixed categories (`1-Office Supplies`), junk columns (`Remove Inc ?`), and the differing Superstore column orders. They are student exercises; the README "Pedagogical Data Traps" table lists them.
2. **Read-only BI permissions**: Student principals (Databricks service principal `db-invite-bi`; Snowflake `BI_STUDENT_ROLE` / `STUDENT_BI_USER`) must never get WRITE, CREATE, or MODIFY privileges.
3. **Idempotence**: Every SQL statement must use `IF NOT EXISTS` or `CREATE OR REPLACE` so scripts can be re-run safely.
4. **No transformation in SQL**: Tables load the CSV values as is (STRING). Do not add casts, unions, renames or constraints; typing and cleaning are student exercises.
5. **Keep platforms in sync**: Any table, column, or expected row count changed on one platform must be changed identically on the other.

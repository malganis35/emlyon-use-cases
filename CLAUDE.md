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

- Check or prepare an instructor machine (uv, Node, git, Databricks and Snowflake CLIs and connections): run the `/setup-instructeur` skill.
- Lint / format Python: `uv run ruff check src/` and `uv run ruff format src/`. Ruff is a dev dependency, and a `.claude/` PostToolUse hook runs it automatically on every `.py` file Claude edits.

There is no test suite or CI.

## Architecture
- **Python CLI** (`src/emlyon_use_cases/`): `converter.prepare_datasets()` holds a hardcoded `mappings` list of (source path, output CSV, `xlsx`|`csv`, sheet name). XLSX sheets are exported with `openpyxl` (`data_only=True`, empty rows skipped). CSV sources are copied with the UTF-8 BOM removed and CRLF converted to LF. The Databricks upload script normalizes BOM and CRLF a second time with `sed`.
- **Two layers per warehouse**, built in `03_load_tables.sql`:
  - `raw_*`: every column is a STRING. Databricks keeps the original column names; Snowflake uses snake_case uppercase names.
  - `fact_*` / `dim_*`: typed and renamed to snake_case, with PK/FK constraints and column comments. Values are deliberately left uncleaned.
- **Platform loading differs. Watch for this when editing:**
  - Databricks uses `read_files(..., header => true)` and selects columns **by header name**, so column order in the CSV doesn't matter.
  - Snowflake uses `COPY INTO` with `SKIP_HEADER = 1` and selects columns **by position** (`$1..$N`). For example, the Excel exports `allsales_team.csv` and `allsales_store.csv` have an unnamed first column and extra columns, so their positional selects skip those columns. Any change to a source file's column order or set must be mirrored in the Snowflake positional selects.
  - Superstore part1 and part2 have different column orders (the "union by name" trap). Databricks unions them by name. Snowflake loads both with the same positional mapping.
- **Naming**: Databricks uses lowercase schemas `gdp`, `superstore`, `allsales` in catalog `emlyon_use_cases`, with a `raw_files` volume per schema. Snowflake uses uppercase `GDP`/`SUPERSTORE`/`ALLSALES` in `EMLYON_USE_CASES`, with an `@RAW_STAGE` stage and a `CSV_FORMAT_SEMICOLON` file format per schema, on warehouse `EMLYON_WH`.

### Adding or changing a dataset
The file list is duplicated in several places, so update all of them together:
- the `mappings` list in `converter.py`
- the file lists in both `02_upload_files.sh` scripts
- the schema, volume or stage setup in both `01_` scripts (only for a new use case)
- the raw table, typed table and row-count check in both `03_load_tables.sql` scripts
- the grants in both `04_` scripts (only for a new schema)
- the hardcoded "9 files" messages and the README file list and traps table

## Principles & Rules
1. **Pedagogical traps**: Do NOT clean intentional raw-data anomalies in SQL. These include the incomplete continent mapping (Europe, Asia, Mars), decimal commas, prefixed categories (`1-Office Supplies`), junk columns (`Remove Inc ?`), and the differing Superstore column orders. They are student exercises; the README "Pedagogical Data Traps" table lists them.
2. **Read-only BI permissions**: Student principals (Databricks service principal `db-invite-bi`; Snowflake `BI_STUDENT_ROLE` / `STUDENT_BI_USER`) must never get WRITE, CREATE, or MODIFY privileges.
3. **Idempotence**: Every SQL statement must use `IF NOT EXISTS` or `CREATE OR REPLACE` so scripts can be re-run safely.
4. **ANSI safety**: Cast dirty strings with `TRY_CAST`, `TRY_TO_DATE` (Snowflake) or `try_to_timestamp` (Databricks), never with a plain cast.
5. **Keep platforms in sync**: Any table, column, or expected row count changed on one platform must be changed identically on the other.

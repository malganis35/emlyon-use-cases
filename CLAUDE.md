# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Teaching-data pipeline for an emlyon BI & DataViz course (Power BI / Tableau). It loads two
pedagogical datasets into Databricks Free Edition (Unity Catalog) and grants read-only access to
students via a service principal. The Python package (`src/emlyon_use_cases`) is a placeholder
stub, not the focus of the repo — almost all the real logic lives in `script/databricks/*.sql`
and `.sh`.

## Repository layout

- `script/databricks/` — the pipeline, run in strict numeric order (01 → 04); see below.
- `script/snowflake/` — currently empty; mirrors the Databricks pipeline if/when a Snowflake
  variant is added.
- `use_cases/` — raw source files for the two datasets (`gdp/`, `superstore/`, plus an unused
  `allsales/`), consumed by `02_upload_files.sh` after manual export to CSV.
- `src/emlyon_use_cases/` — minimal Python package stub (`main()` prints a greeting); not part of
  the data pipeline.

## The Databricks pipeline (`script/databricks/`)

Run in this order, documented in `README.md` (French):

| # | File | Where | What it does |
|---|------|-------|---------------|
| 1 | `01_setup_unity_catalog.sql` | Databricks SQL Editor | Creates catalog `emlyon_use_cases`, schemas `gdp`/`superstore`, and a managed `raw_files` volume per schema. Idempotent (`IF NOT EXISTS`). |
| 2 | `02_upload_files.sh` | local terminal, authenticated Databricks CLI | Strips UTF-8 BOM and CRLF from the 5 source files, then `databricks fs cp`s them into the volumes created in step 1. Takes the source folder as `$1` (default `./data`); requires exact filenames — see the file list in `README.md`. Uses `DATABRICKS_PROFILE` env var (default `emlyon`). |
| 3 | `03_load_tables.sql` | Databricks SQL Editor | Loads volume files into Delta tables, two layers per use case: `raw_*` (all-STRING, original column names, `delta.columnMapping.mode='name'`) and typed `fact_*`/`dim_*` tables. Idempotent (`CREATE OR REPLACE`). Ends with row-count and NULL-count checks. |
| 4 | `04_grants_bi.sql` | Databricks SQL Editor | Grants read-only access (`USE CATALOG`/`USE SCHEMA`/`SELECT`/`READ VOLUME`) to a service-principal client ID. Requires manually creating the service principal in the workspace UI first (documented inline in the file) and substituting `<<CLIENT_ID>>`. |
| 99 | `99_reset.sql` | Databricks SQL Editor | Destructive: drops catalog/schemas/volumes/tables. Statements are commented out by design — uncomment deliberately before running. |

Key conventions to preserve when editing these scripts:

- **Two-layer pattern per use case**: a `raw_*` table (untyped, original headers, kept via
  `delta.columnMapping.mode='name'`) feeds a typed `fact_*`/`dim_*` table. Cleaning logic (decimal
  comma → dot, `dd/MM/yyyy` date parsing, etc.) belongs only in the typed layer — the raw layer
  must stay a faithful, unmodified copy of the source file.
- **Intentional data-quality "gotchas" are pedagogical, not bugs** — do not silently clean them up.
  Documented in `README.md`'s "Pièges pédagogiques" table, e.g.: the continent reference table only
  covers Europe/Asia/Mars (forces an outer-join exercise), `Category` values are prefixed
  `1-`/`10-`/`100-` (forces a split/parse exercise), Superstore's two source files have different
  column orders (forces union-by-name instead of union-by-position), and `Remove Inc ?` /
  `Remove Inc 2?` junk columns must be dropped by students, not by the pipeline.
  If asked to "fix" one of these, confirm with the user first — it may be intentional.
  See `use_cases/gdp/` and `use_cases/superstore/` for the underlying source files.
  See `script/databricks/03_load_tables.sql` for the exact fields.
- **Idempotency**: SQL scripts (except `99_reset.sql`) are written to be safely re-run
  (`IF NOT EXISTS` / `CREATE OR REPLACE`). Keep new statements idempotent too.
- **Least privilege**: `04_grants_bi.sql`'s verification block expects to see *only*
  `USE CATALOG`/`USE SCHEMA`/`SELECT`/`READ VOLUME` in `SHOW GRANTS` output — never
  `MODIFY`/`CREATE TABLE`/`ALL PRIVILEGES`. Preserve this when adding grants.
- Source CSVs use `;` as the delimiter and are read with `read_files(...)`.

## Environment constraints (Databricks Free Edition)

These limits shape the design choices above — keep them in mind when changing the pipeline:

- Single workspace, single metastore, single SQL warehouse (2X-Small only).
- A user once added to the workspace cannot be removed — hence using a **service principal**
  (not a `db_invite` account) for student BI access.
- No password auth: email OTP, Google, or Microsoft sign-in only.
- Quota overrun cuts off compute until the next day — test the pipeline the day before a class,
  not the morning of.
- Non-commercial use only.
- Only one SQL warehouse means BI tools must use **Import (Power BI) / Extract (Tableau)** mode,
  never DirectQuery/Live Connection, or concurrent student queries will saturate it.

## Working with this repo

- There is no build/lint/test tooling configured beyond `uv` packaging metadata
  (`pyproject.toml`, Python ≥3.12). There are no tests.
- Changes to the SQL/shell pipeline can't be executed or verified locally — there's no Databricks
  connection in this environment. Validate by careful reading against the conventions above, not
  by running the scripts.
- `README.md` (French) is the source of truth for the data model, execution order, and the file
  names expected in the `./data` directory passed to `02_upload_files.sh`. Keep it in sync with
  any pipeline changes.

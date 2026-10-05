# 🎓 Deployment Guide — Databricks & Snowflake for BI & DataViz Courses

Welcome to the **emlyon-use-cases** repository. This project provides an automated data pipeline for three pedagogical datasets (**GDP**, **EU Superstore**, and **Allsales**) designed for Business Intelligence and Data Visualization courses (Power BI / Tableau).

The repository supports two ready-to-use Cloud platforms:
- **Databricks Free Edition (Unity Catalog)** in [`script/databricks/`](script/databricks/)
- **Snowflake** in [`script/snowflake/`](script/snowflake/)

This step-by-step guide is designed to allow any instructor or TA to deploy the complete environment in **15 to 20 minutes**.

> 💡 **Fastest path:** open the project in [Claude Code](https://code.claude.com/docs) (`claude` at the repo root) and let the project skills do the heavy lifting — see [Quick Start with Claude Code](#quick-start-with-claude-code). Everything is also documented manually below.

---

## 📋 Table of Contents

- [Quick Start with Claude Code](#quick-start-with-claude-code)
- [1. Prerequisites & Local Setup](#1-prerequisites--local-setup)
- [2. Step 1: Raw Data Preparation](#2-step-1-raw-data-preparation)
- [3. Databricks Free Edition Deployment](#3-databricks-free-edition-deployment)
- [4. Snowflake Deployment](#4-snowflake-deployment)
- [5. 🔑 Student Connection Cheatsheets (Power BI / Tableau)](#5--student-connection-cheatsheets-power-bi--tableau)
- [6. 🎯 Pedagogical Data Traps](#6--pedagogical-data-traps)
- [7. 🧹 Inter-Cohort Reset Procedure](#7--inter-cohort-reset-procedure)

---

## Quick Start with Claude Code

The repository ships Claude Code skills and an agent (in [`.claude/`](.claude/), see [`.claude/README.md`](.claude/README.md)) that automate the setup. Nothing to configure: run `claude` at the repo root and accept the permission prompts.

| Goal | Command | What it does |
| :--- | :--- | :--- |
| Prepare a new machine | `/setup-instructeur` | Checks/installs `uv`, Node, `git`, Databricks CLI and `snowsql`, then tests the Databricks and Snowflake connections. Use it first, or when an upload or connection fails. |
| Add a dataset | `/nouveau-dataset` | Picks disqualities from a reference file in [`docs/`](docs/), writes the manifest, generates degraded CSVs and both platforms' SQL scripts. |
| Review before committing | `code-quality-reviewer` agent | Reviews Python, SQL and upload-script changes for quality and platform consistency. |
| Write a PR | `/pr-description` | Drafts the pull request description. |

Typical first deployment: `/setup-instructeur` → `uv sync` → `uv run emlyon-use-cases prepare` → follow sections 3 and/or 4.

New to the terminal (Windows / macOS)? See [`.vscode/ReadMe.MD`](.vscode/ReadMe.MD) for step-by-step installs of VS Code, `uv` and `git`, and run `uv run .vscode/install_extensions.py` to install the recommended editor extensions.

---

## 1. Prerequisites & Local Setup

> Shortcut: the `/setup-instructeur` skill checks all of this for you.

Before starting, ensure your machine has the following tools installed:
1. **Python 3.12+** and the **`uv`** package manager (then run `uv sync` once to install dependencies):
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh   # Windows: see .vscode/ReadMe.MD
   ```
2. **Platform CLI**:
   - **Databricks CLI v0.205+**: `databricks auth login --host https://<workspace>.cloud.databricks.com -p emlyon`
   - **Snowflake CLI (`snowsql`)**: Configured in `~/.snowflake/connections.toml` (under `[emlyon]`) or `~/.snowsql/config`

---

## 2. Step 1: Raw Data Preparation

Raw source files (Excel `.xlsx` and CSV) are located in [`use_cases/`](use_cases/) (`gdp/`, `superstore/`, and `allsales/`).

Run the project's Python CLI to convert Excel sheets to `;`-delimited CSVs, strip UTF-8 BOM / CRLF line endings, and generate the `./data/` folder:

```bash
uv run emlyon-use-cases prepare
```

**Generated files in `./data/` (9 total, each loaded as one table of the same name)**:
- **GDP**: `life_expectancy.csv`, `continent_mapping.csv`
- **Superstore**: `superstore_part1.csv`, `superstore_part2.csv`, `nomenclature.csv`
- **Allsales**: `allsales_part1.csv`, `allsales_part2.csv`, `allsales_team.csv`, `allsales_store.csv`

---

## 3. Databricks Free Edition Deployment

Execution order in [`script/databricks/`](script/databricks/):

1. **`01_setup_unity_catalog.sql`** (Databricks SQL Editor): Creates catalog `emlyon_use_cases`, schemas `gdp`, `superstore`, `allsales`, and managed volumes `raw_files`.
2. **`02_upload_files.sh`** (Local terminal):
   ```bash
   bash script/databricks/02_upload_files.sh ./data
   ```
3. **`03_load_tables.sql`** (Databricks SQL Editor): Creates the 9 tables, one per CSV, as is (all columns STRING, no union, no cleaning).
4. **`04_grants_bi.sql`** (Databricks SQL Editor): Configures read-only access for the `db-invite-bi` Service Principal.

---

## 4. Snowflake Deployment

Execution order in [`script/snowflake/`](script/snowflake/):

1. **`01_setup_snowflake.sql`** (Snowsight UI):
   - Creates database `EMLYON_USE_CASES`, schemas `GDP`, `SUPERSTORE`, and `ALLSALES`.
   - Creates warehouse `EMLYON_WH` (XSMALL), CSV file formats, and internal stages `@RAW_STAGE`.
2. **`02_upload_files.sh`** (Local terminal):
   ```bash
   bash script/snowflake/02_upload_files.sh ./data
   ```
   *Uploads all 9 CSV files into Snowflake internal stages via `snowsql` batch mode.*
3. **`03_load_tables.sql`** (Snowsight UI):
   - Ingests stage CSV files via `COPY INTO`.
   - Creates the 9 tables, one per CSV, as is (all columns STRING, no union, no cleaning).
4. **`04_grants_bi.sql`** (Snowsight UI):
   - Replace `<<STUDENT_PASSWORD>>` with your workshop password.
   - Creates read-only role `BI_STUDENT_ROLE` and user `STUDENT_BI_USER`.

---

## 5. 🔑 Student Connection Cheatsheets (Power BI / Tableau)

### Option A: Databricks Connection
```text
Server hostname : <your-workspace>.cloud.databricks.com
HTTP path       : /sql/1.0/warehouses/<warehouse-id>
Catalog         : emlyon_use_cases
Schema          : gdp  |  superstore  |  allsales

Authentication:
- Power BI: "Databricks" connector -> "Client Credentials" option (Client ID + Secret)
- Tableau : "Databricks" connector -> "Service Principal" method (Client ID + Secret)
Mode          : IMPORT (Power BI) / EXTRACT (Tableau)
```

### Option B: Snowflake Connection
```text
Server / Account : <account_identifier>.snowflakecomputing.com
Warehouse        : EMLYON_WH
Database         : EMLYON_USE_CASES
Schema           : GDP  |  SUPERSTORE  |  ALLSALES
Role             : BI_STUDENT_ROLE

Authentication:
- Username : STUDENT_BI_USER
- Password : <STUDENT_PASSWORD>
Mode       : IMPORT (Power BI) / EXTRACT (Tableau)
```

---

## 6. 🎯 Pedagogical Data Traps

The datasets intentionally contain **deliberate data quality issues** that should **not** be cleaned up in the SQL scripts. They form the core of student Data Preparation exercises:

| Use Case | Data Quality Trap | Student Exercise Objective |
| :--- | :--- | :--- |
| **GDP** | Continent reference table limited to `Europe`, `Asia`, `Mars`. | Outer joins practice (Left Outer Join) and orphan values handling. |
| **GDP** | Decimal commas in `Life exp`. | Data conversion and data typing at import. |
| **Superstore** | `superstore_part1` and `superstore_part2` tables have different column orders. | Union by column name (Union by Name). |
| **Superstore** | Junk columns `Remove Inc ?` and `Remove Inc 2?` filled with `?`. | Data model hygiene by discarding irrelevant columns. |
| **Superstore** | Prefixed categories (`1-Office Supplies`, `10-Technology`, `100-Furniture`). | String extraction (Split / Text Parsing) and custom sorting. |
| **Allsales** | Multi-year order batches (`allsales_part1` 2025 & `allsales_part2` 2026) with 40,000 transactions. `allsales_team` / `allsales_store` have an unnamed first column and extra columns. | Append the 2 batches, star-schema modeling (orders linked to `allsales_team` & `allsales_store`), typing, calculated metrics (sales, cost, profit amounts). |

### Adding a new use case with generated disqualities

An instructor can add a dataset with the `/nouveau-dataset` Claude Code skill. It reads a reference file from `docs/` (e.g. `docs/disquality_cao.md`), asks which disqualities to apply, writes `use_cases/<name>/manifest.yaml`, then generates the degraded CSVs and the scripts under `script/<platform>/generated/<name>/`. The same steps by hand:

```bash
uv run emlyon-use-cases degrade      --manifest use_cases/<name>/manifest.yaml --dst ./data
uv run emlyon-use-cases generate-sql --manifest use_cases/<name>/manifest.yaml --data ./data --dst ./script
```

Then run, per platform, `01_`, `02_upload_files.sh ./data`, `03_` (check that `row_count = expected`) and `04_` (read-only grants), as for the three datasets above.

| Disquality type | What it injects | Student Exercise Objective |
| :--- | :--- | :--- |
| `junk_rows` | Rows after the header with only a `zz_test` marker. | Delete the first rows. |
| `null_columns` | Empty, explicitly named columns. | Delete useless columns. |
| `value_prefix` | A constant prefix on every value (`Sales Channel: Online`). | Replace values. |
| `code_prefix` | `1-`, `2-`, `11-` prefixes. | Split a column by a separator. |
| `mixed_decimal` | `.` and `,` decimal separators mixed in one column. | Locale settings (US / FR) to get decimal numbers. |

---

## 7. 🧹 Inter-Cohort Reset Procedure

- **Databricks**: Run `DROP CATALOG IF EXISTS emlyon_use_cases CASCADE;` via [`script/databricks/99_reset.sql`](script/databricks/99_reset.sql).
- **Snowflake**: Run [`script/snowflake/99_reset.sql`](script/snowflake/99_reset.sql).

*note: Project made with Claude Code and Google Gemini*
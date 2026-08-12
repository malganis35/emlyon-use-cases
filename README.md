# 🎓 Deployment Guide — Databricks & Snowflake for BI & DataViz Courses

Welcome to the **emlyon-use-cases** repository. This project provides an automated data pipeline for two pedagogical datasets (**GDP** and **EU Superstore**) designed for Business Intelligence and Data Visualization courses (Power BI / Tableau).

The repository supports two ready-to-use Cloud platforms:
- **Databricks Free Edition (Unity Catalog)** in [`script/databricks/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/)
- **Snowflake** in [`script/snowflake/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/snowflake/)

This step-by-step guide is designed to allow any instructor or TA to deploy the complete environment in **15 to 20 minutes**.

---

## 📋 Table of Contents

- [🎓 Deployment Guide — Databricks \& Snowflake for BI \& DataViz Courses](#-deployment-guide--databricks--snowflake-for-bi--dataviz-courses)
  - [📋 Table of Contents](#-table-of-contents)
  - [1. Prerequisites \& Local Setup](#1-prerequisites--local-setup)
  - [2. Step 1: Raw Data Preparation](#2-step-1-raw-data-preparation)
  - [3. Databricks Free Edition Deployment](#3-databricks-free-edition-deployment)
  - [4. Snowflake Deployment](#4-snowflake-deployment)
  - [5. 🔑 Student Connection Cheatsheets (Power BI / Tableau)](#5--student-connection-cheatsheets-power-bi--tableau)
    - [Option A: Databricks Connection](#option-a-databricks-connection)
    - [Option B: Snowflake Connection](#option-b-snowflake-connection)
  - [6. 🎯 Pedagogical Data Traps](#6--pedagogical-data-traps)
  - [7. 🧹 Inter-Cohort Reset Procedure](#7--inter-cohort-reset-procedure)

---

## 1. Prerequisites & Local Setup

Before starting, ensure your machine has the following tools installed:
1. **Python 3.12+** and the **`uv`** package manager:
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
2. **Platform CLI**:
   - **Databricks CLI v0.205+**: `databricks auth login --host https://<workspace>.cloud.databricks.com -p emlyon`
   - **Snowflake CLI (`snowsql`)**: Configured in `~/.snowflake/connections.toml` (under `[emlyon]`) or `~/.snowsql/config`

---

## 2. Step 1: Raw Data Preparation

Raw source files (Excel `.xlsx` and CSV) are located in the [`use_cases/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/use_cases/) directory.

Run the project's Python CLI to convert Excel files to `;`-delimited CSVs, strip UTF-8 BOM / CRLF line endings, and generate the `./data/` folder:

```bash
uv run emlyon-use-cases prepare
```

**Generated files in `./data/`**:
- `life_expectancy.csv`
- `continent_mapping.csv`
- `superstore_part1.csv`
- `superstore_part2.csv`
- `nomenclature.csv`

---

## 3. Databricks Free Edition Deployment

Execution order in [`script/databricks/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/):

1. **`01_setup_unity_catalog.sql`** (Databricks SQL Editor): Creates the catalog `emlyon_use_cases`, schemas `gdp` and `superstore`, and managed volumes `raw_files`.
2. **`02_upload_files.sh`** (Local terminal):
   ```bash
   bash script/databricks/02_upload_files.sh ./data
   ```
3. **`03_load_tables.sql`** (Databricks SQL Editor): Creates `raw_*` tables and typed `fact_*` / `dim_*` tables with PK/FK constraints.
4. **`04_grants_bi.sql`** (Databricks SQL Editor): Configures read-only access for the `db-invite-bi` Service Principal.

---

## 4. Snowflake Deployment

Execution order in [`script/snowflake/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/snowflake/):

1. **`01_setup_snowflake.sql`** (Snowsight UI):
   - Creates database `EMLYON_USE_CASES`, schemas `GDP` and `SUPERSTORE`.
   - Creates warehouse `EMLYON_WH` (XSMALL), CSV file formats, and internal stages `@RAW_STAGE`.
2. **`02_upload_files.sh`** (Local terminal):
   ```bash
   bash script/snowflake/02_upload_files.sh ./data
   ```
   *Uploads all 5 CSV files into Snowflake internal stages via `snowsql`.*
3. **`03_load_tables.sql`** (Snowsight UI):
   - Ingests stage CSV files via `COPY INTO`.
   - Creates `RAW_*` tables and typed `FACT_*` / `DIM_*` tables with informational constraints.
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
Schema          : gdp   or   superstore

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
Schema           : GDP   or   SUPERSTORE
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
| **Superstore** | `part1` and `part2` CSVs have different column orders. | Union by column name (Union by Name). |
| **Superstore** | Junk columns `Remove Inc ?` and `Remove Inc 2?` filled with `?`. | Data model hygiene by discarding irrelevant columns. |
| **Superstore** | Prefixed categories (`1-Office Supplies`, `10-Technology`, `100-Furniture`). | String extraction (Split / Text Parsing) and custom sorting. |

---

## 7. 🧹 Inter-Cohort Reset Procedure

- **Databricks**: Run `DROP CATALOG IF EXISTS emlyon_use_cases CASCADE;` via [`script/databricks/99_reset.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/99_reset.sql).
- **Snowflake**: Run [`script/snowflake/99_reset.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/snowflake/99_reset.sql).

*note: Project made with Claude Code and Google Gemini*
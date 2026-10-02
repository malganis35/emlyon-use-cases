"""Generate the Databricks and Snowflake SQL scripts of a use case from its generated CSVs.

Same conventions as the hand-written scripts in script/*/:
1 CSV = 1 table, every column STRING, all columns kept in file order, no cast, no union,
no rename (Databricks) / snake_case uppercase names (Snowflake), idempotent statements,
read-only student grants.
"""

import csv
import re
from dataclasses import dataclass
from pathlib import Path

from emlyon_use_cases.manifest import SNOWFLAKE_RESERVED, UseCase, csv_filename

CATALOG = "emlyon_use_cases"
DATABASE = "EMLYON_USE_CASES"
WAREHOUSE = "EMLYON_WH"


@dataclass
class TableInfo:
    name: str
    filename: str
    header: list[str]
    rows: int


def read_table_info(use_case: UseCase, data_dir: Path) -> list[TableInfo]:
    """Read header and data row count of each generated CSV (the SQL follows the real files)."""
    infos = []
    for table in use_case.tables:
        filename = csv_filename(use_case.name, table.name)
        path = data_dir / filename
        if not path.exists():
            raise FileNotFoundError(f"{path} not found: run 'degrade' first")
        with open(path, newline="", encoding="utf-8") as f:
            reader = csv.reader(f, delimiter=";")
            header = next(reader)
            infos.append(
                TableInfo(table.name, filename, header, sum(1 for _ in reader))
            )
    return infos


def snowflake_column_names(header: list[str]) -> list[str]:
    """Uppercase snake_case names: 'SalesAgentID' -> SALES_AGENT_ID, '' -> COLUMN_<position>.

    Reserved words get a ``_COL`` suffix ('Order' -> ORDER_COL); loading is by position."""
    names: list[str] = []
    for i, raw in enumerate(header):
        name = re.sub(r"([a-z])([A-Z])", r"\1_\2", raw)
        name = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1_\2", name)
        name = re.sub(r"[^0-9A-Za-z]+", "_", name).strip("_").upper()
        if not name:
            name = f"COLUMN_{i + 1}"
        elif name in SNOWFLAKE_RESERVED:
            name = f"{name}_COL"
        elif name[0].isdigit():
            name = f"COL_{name}"
        base, n = name, 1
        while name in names:
            n += 1
            name = f"{base}_{n}"
        names.append(name)
    return names


def databricks_schema(header: list[str]) -> str:
    """`read_files` schema string: original names (empty header -> _c<index>), all STRING."""
    parts = []
    for i, raw in enumerate(header):
        name = raw if raw.strip() else f"_c{i}"
        name = name.replace("`", "``").replace("'", "\\'")
        parts.append(f"`{name}` STRING")
    return ", ".join(parts)


def _quote(text: str) -> str:
    return text.replace("'", "''")


def _title(name: str) -> str:
    return name.replace("_", " ").capitalize()


def render_databricks_setup(uc: UseCase) -> str:
    s = uc.name
    return f"""-- =============================================================================
-- 01_setup_unity_catalog.sql ({s}) - GENERATED, do not edit by hand
-- Object : Catalog, schema and volume for the '{s}' use case
-- Idempotent : Yes (safe to re-run)
-- =============================================================================

CREATE CATALOG IF NOT EXISTS {CATALOG}
  COMMENT 'Pedagogical datasets for emlyon BI & DataViz course (Power BI / Tableau)';

CREATE SCHEMA IF NOT EXISTS {CATALOG}.{s}
  COMMENT 'Use case {s}';

CREATE VOLUME IF NOT EXISTS {CATALOG}.{s}.raw_files
  COMMENT 'Staging area for raw flat CSV files ({s} use case)';

SHOW VOLUMES IN {CATALOG}.{s};

-- >>> NEXT STEP: run 02_upload_files.sh from local terminal
"""


def render_databricks_load(uc: UseCase, tables: list[TableInfo]) -> str:
    s = uc.name
    blocks = []
    for i, t in enumerate(tables, 1):
        blocks.append(f"""-- {i}. {_title(t.name)} ({t.rows:,} rows expected) ---------------------------------
CREATE OR REPLACE TABLE {s}.{t.name}
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file {t.filename}, as is.'
AS
SELECT * FROM read_files(
  '/Volumes/{CATALOG}/{s}/raw_files/{t.filename}',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '{databricks_schema(t.header)}'
);
""")
    checks = "\nUNION ALL ".join(
        f"SELECT '{s}.{t.name}' AS table_name, COUNT(*) AS row_count, {t.rows} AS expected FROM {s}.{t.name}"
        for t in tables
    )
    return f"""-- =============================================================================
-- 03_load_tables.sql ({s}) - GENERATED, do not edit by hand
-- Object : Loads the {len(tables)} volume files into {len(tables)} Delta tables, strictly 1 CSV = 1 table
--          Every column is STRING, original column names, ALL columns kept (unnamed header = _c<index>),
--          no union, no rename, no cast, no constraints.
-- Idempotent : Yes (CREATE OR REPLACE)
-- =============================================================================

USE CATALOG {CATALOG};

{chr(10).join(blocks)}
-- Row count check (row_count must equal expected) -----------------------------
{checks};
"""


def render_databricks_grants(uc: UseCase) -> str:
    s = uc.name
    return f"""-- =============================================================================
-- 04_grants_bi.sql ({s}) - GENERATED, do not edit by hand
-- Object : READ-ONLY access of the student service principal to the '{s}' schema.
--          Never grant WRITE / CREATE / MODIFY here.
--
-- REPLACE <<CLIENT_ID>> with the application ID of the service principal (db-invite-bi).
-- =============================================================================

GRANT USE CATALOG ON CATALOG {CATALOG} TO `<<CLIENT_ID>>`;
GRANT USE SCHEMA ON SCHEMA {CATALOG}.{s} TO `<<CLIENT_ID>>`;
GRANT SELECT ON SCHEMA {CATALOG}.{s} TO `<<CLIENT_ID>>`;
GRANT READ VOLUME ON VOLUME {CATALOG}.{s}.raw_files TO `<<CLIENT_ID>>`;

SHOW GRANTS ON SCHEMA {CATALOG}.{s};
"""


def render_snowflake_setup(uc: UseCase) -> str:
    s = uc.name.upper()
    return f"""-- =============================================================================
-- 01_setup_snowflake.sql ({s}) - GENERATED, do not edit by hand
-- Object : Database, schema, warehouse, file format and stage for the '{uc.name}' use case
-- Idempotent : Yes (safe to re-run)
-- =============================================================================

CREATE DATABASE IF NOT EXISTS {DATABASE}
  COMMENT = 'Pedagogical datasets for emlyon BI & DataViz course (Power BI / Tableau)';

USE DATABASE {DATABASE};

CREATE SCHEMA IF NOT EXISTS {s}
  COMMENT = 'Use case {uc.name}';

CREATE WAREHOUSE IF NOT EXISTS {WAREHOUSE}
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse dedicated to emlyon BI course';

CREATE OR REPLACE FILE FORMAT {s}.CSV_FORMAT_SEMICOLON
  TYPE = 'CSV' FIELD_DELIMITER = ';' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"' NULL_IF = ('', 'NULL') EMPTY_FIELD_AS_NULL = TRUE ENCODING = 'UTF8';

CREATE STAGE IF NOT EXISTS {s}.RAW_STAGE FILE_FORMAT = {s}.CSV_FORMAT_SEMICOLON;

SHOW STAGES IN SCHEMA {s};

-- >>> NEXT STEP: run 02_upload_files.sh from local terminal
"""


def render_snowflake_load(uc: UseCase, tables: list[TableInfo]) -> str:
    s = uc.name.upper()
    blocks = []
    for i, t in enumerate(tables, 1):
        columns = ",\n".join(f"  {c} STRING" for c in snowflake_column_names(t.header))
        blocks.append(f"""-- {i}. {_title(t.name)} ({t.rows:,} rows expected) ---------------------------------
CREATE OR REPLACE TABLE {s}.{t.name.upper()} (
{columns}
)
COMMENT = '{_quote(f"Source file {t.filename}, as is.")}';

COPY INTO {s}.{t.name.upper()}
FROM @{s}.RAW_STAGE
FILES = ('{t.filename}')
FILE_FORMAT = (FORMAT_NAME = '{s}.CSV_FORMAT_SEMICOLON')
ON_ERROR = 'CONTINUE';
""")
    checks = "\nUNION ALL ".join(
        f"SELECT '{s}.{t.name.upper()}' AS table_name, COUNT(*) AS row_count, {t.rows} AS expected FROM {s}.{t.name.upper()}"
        for t in tables
    )
    return f"""-- =============================================================================
-- 03_load_tables.sql ({s}) - GENERATED, do not edit by hand
-- Object : Loads the {len(tables)} stage files into {len(tables)} tables, strictly 1 CSV = 1 table
--          Every column is STRING, ALL columns kept in file order (loaded by position),
--          no union, no cast, no constraints.
-- Idempotent : Yes (CREATE OR REPLACE)
-- =============================================================================

USE DATABASE {DATABASE};
USE WAREHOUSE {WAREHOUSE};

{chr(10).join(blocks)}
-- Row count check (row_count must equal expected) -----------------------------
{checks};
"""


def render_snowflake_grants(uc: UseCase) -> str:
    s = uc.name.upper()
    return f"""-- =============================================================================
-- 04_grants_bi.sql ({s}) - GENERATED, do not edit by hand
-- Object : READ-ONLY access of BI_STUDENT_ROLE to the '{uc.name}' schema.
--          Never grant INSERT / UPDATE / DELETE / CREATE here.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE {DATABASE};

CREATE ROLE IF NOT EXISTS BI_STUDENT_ROLE
  COMMENT = 'Restricted read-only role for students (Power BI / Tableau)';

GRANT USAGE ON WAREHOUSE {WAREHOUSE} TO ROLE BI_STUDENT_ROLE;
GRANT USAGE ON DATABASE {DATABASE} TO ROLE BI_STUDENT_ROLE;
GRANT USAGE ON SCHEMA {DATABASE}.{s} TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA {DATABASE}.{s} TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA {DATABASE}.{s} TO ROLE BI_STUDENT_ROLE;

SHOW GRANTS TO ROLE BI_STUDENT_ROLE;
"""


_DATABRICKS_UPLOAD = r"""#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh (@USE_CASE@) - GENERATED, do not edit by hand
# Object : Normalizes (BOM + CRLF) then uploads the @COUNT@ raw files of the '@USE_CASE@'
#          use case into the Unity Catalog volume created by 01_setup_unity_catalog.sql
# Prerequisites : Databricks CLI v0.205+ authenticated (databricks auth login)
# =============================================================================
set -euo pipefail

command -v databricks >/dev/null 2>&1 || {
  echo "ERROR: Databricks CLI 'databricks' is not installed or not available in PATH."
  exit 1
}

PROFILE="${DATABRICKS_PROFILE:-emlyon}"
SRC_DIR="${1:-./data}"
CATALOG="@CATALOG@"
SCHEMA="@USE_CASE@"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: Source directory '$SRC_DIR' does not exist."
  echo "Usage: $0 [data_directory]"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== Databricks File Preparation and Upload ==="
echo "Source directory : $SRC_DIR"
echo "CLI Profile      : $PROFILE"
echo "Target           : $CATALOG.$SCHEMA.raw_files"
echo

normalize() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || { echo "ERROR: Missing source file: $src"; exit 1; }
  echo "-> Normalizing (BOM/CRLF): $(basename "$src") -> $(basename "$dst")"
  sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$src" > "$dst"
}

upload() {
  local file="$1"
  echo "-> Uploading: $file  =>  $CATALOG.$SCHEMA.raw_files"
  databricks fs cp "$TMP_DIR/$file" "dbfs:/Volumes/$CATALOG/$SCHEMA/raw_files/$file" --overwrite -p "$PROFILE"
}

@NORMALIZE@

echo

@UPLOAD@

echo
echo "=== Success: @COUNT@ files transferred to /Volumes/$CATALOG/$SCHEMA/raw_files/ ==="
echo "NEXT STEP: Run 03_load_tables.sql"
"""

_SNOWFLAKE_UPLOAD = r"""#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh (@USE_CASE@) - GENERATED, do not edit by hand
# Object : Uploads the @COUNT@ source files of the '@USE_CASE@' use case into its Snowflake stage
# Prerequisites : SnowSQL (snowsql CLI) installed and configured
# =============================================================================
set -euo pipefail

command -v snowsql >/dev/null 2>&1 || {
  echo "ERROR: Snowflake CLI 'snowsql' is not installed or not available in PATH."
  exit 1
}

SRC_DIR="${1:-./data}"
CONNECTION="${SNOWSQL_CONN:-emlyon}"

python3 -c "
import os, sys, subprocess, tomllib

src_dir = os.path.abspath('$SRC_DIR')
conn = '$CONNECTION'
p = os.path.expanduser('~/.snowflake/connections.toml')

cfg = {}
if os.path.exists(p):
    try:
        data = tomllib.load(open(p, 'rb'))
        if conn in data:
            cfg = data[conn]
    except Exception:
        pass

env = os.environ.copy()
if cfg.get('password'):
    env['SNOWSQL_PWD'] = cfg['password']

uploads = [
@UPLOADS@
]

print('=== Snowflake File Upload Process ===')
print(f'Source directory : {src_dir}')
print(f'Connection       : {conn}')
print(f'Database         : @DATABASE@')
print()

lines = ['USE DATABASE @DATABASE@;']
for filename, schema in uploads:
    filepath = os.path.join(src_dir, filename)
    if not os.path.exists(filepath):
        print(f'ERROR: Missing file {filepath}', file=sys.stderr)
        sys.exit(1)
    lines.append(f'USE SCHEMA {schema};')
    lines.append(f'PUT file://{filepath} @RAW_STAGE OVERWRITE=TRUE AUTO_COMPRESS=FALSE;')

batch_sql = os.path.join(src_dir, '_upload_batch.sql')
with open(batch_sql, 'w') as f:
    f.write('\n'.join(lines) + '\n')

cmd = ['snowsql']
if cfg.get('account') and cfg.get('user'):
    cmd.extend(['-a', cfg['account'], '-u', cfg['user']])
    if cfg.get('warehouse'):
        cmd.extend(['-w', cfg['warehouse']])
    if cfg.get('role'):
        cmd.extend(['-r', cfg['role']])
else:
    cmd.extend(['-c', conn])

cmd.extend(['-f', batch_sql, '-o', 'exit_on_error=true', '-o', 'quiet=true'])

res = subprocess.run(cmd, env=env, capture_output=True, text=True)

if os.path.exists(batch_sql):
    os.remove(batch_sql)

if res.returncode != 0:
    print(f'ERROR: {res.stderr.strip() or res.stdout.strip()}', file=sys.stderr)
    sys.exit(res.returncode)

print('=== Success: @COUNT@ files transferred to Snowflake internal stage @SCHEMA@.RAW_STAGE ===')
print('NEXT STEP: Run 03_load_tables.sql')
"
"""


def _fill(template: str, **values: str) -> str:
    for key, value in values.items():
        template = template.replace(f"@{key}@", value)
    return template


def render_databricks_upload(uc: UseCase, tables: list[TableInfo]) -> str:
    return _fill(
        _DATABRICKS_UPLOAD,
        USE_CASE=uc.name,
        COUNT=str(len(tables)),
        CATALOG=CATALOG,
        NORMALIZE="\n".join(
            f'normalize "$SRC_DIR/{t.filename}" "$TMP_DIR/{t.filename}"' for t in tables
        ),
        UPLOAD="\n".join(f"upload {t.filename}" for t in tables),
    )


def render_snowflake_upload(uc: UseCase, tables: list[TableInfo]) -> str:
    return _fill(
        _SNOWFLAKE_UPLOAD,
        USE_CASE=uc.name,
        COUNT=str(len(tables)),
        DATABASE=DATABASE,
        SCHEMA=uc.name.upper(),
        UPLOADS="\n".join(
            f"    ('{t.filename}', '{uc.name.upper()}')," for t in tables
        ),
    )


def generate_sql(use_case: UseCase, data_dir: Path, script_dir: Path) -> list[Path]:
    """Write the 01/02/03/04 scripts of both platforms under script_dir/<platform>/generated/<use case>/."""
    tables = read_table_info(use_case, data_dir)
    files = {
        ("databricks", "01_setup_unity_catalog.sql"): render_databricks_setup(use_case),
        ("databricks", "03_load_tables.sql"): render_databricks_load(use_case, tables),
        ("databricks", "02_upload_files.sh"): render_databricks_upload(
            use_case, tables
        ),
        ("databricks", "04_grants_bi.sql"): render_databricks_grants(use_case),
        ("snowflake", "01_setup_snowflake.sql"): render_snowflake_setup(use_case),
        ("snowflake", "03_load_tables.sql"): render_snowflake_load(use_case, tables),
        ("snowflake", "02_upload_files.sh"): render_snowflake_upload(use_case, tables),
        ("snowflake", "04_grants_bi.sql"): render_snowflake_grants(use_case),
    }
    written = []
    for (platform, name), content in files.items():
        path = script_dir / platform / "generated" / use_case.name / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        if path.suffix == ".sh":
            path.chmod(0o755)
        written.append(path)
    return written

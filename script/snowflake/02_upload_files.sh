#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh (Snowflake)
# Object : Uploads the 5 source files into Snowflake internal stages
# Prerequisites : SnowSQL (snowsql CLI) installed and configured
# Duration : ~45 seconds
# =============================================================================
set -euo pipefail

# --- Verify SnowSQL availability ----------------------------------------------
command -v snowsql >/dev/null 2>&1 || {
  echo "ERROR: Snowflake CLI 'snowsql' is not installed or not available in PATH."
  echo "Please install it: https://docs.snowflake.com/en/user-guide/snowsql-install-config"
  exit 1
}

# --- Parameters ---------------------------------------------------------------
SRC_DIR="${1:-./data}"
CONNECTION="${SNOWSQL_CONN:-emlyon}"
DATABASE="EMLYON_USE_CASES"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERROR: Source directory '$SRC_DIR' does not exist."
  echo "Usage: $0 [data_directory]"
  exit 1
fi

echo "=== Snowflake File Upload Process ==="
echo "Source directory : $SRC_DIR"
echo "Connection       : $CONNECTION"
echo "Database         : $DATABASE"
echo

# --- Automatic detection of connection in ~/.snowflake/connections.toml -------
CFG_ACCOUNT=""
CFG_USER=""
CFG_PASSWORD=""
CFG_WAREHOUSE=""
CFG_ROLE=""

if command -v python3 >/dev/null 2>&1; then
  eval "$(python3 -c "
import os, sys, tomllib
conn = '$CONNECTION'
p = os.path.expanduser('~/.snowflake/connections.toml')
if os.path.exists(p):
    try:
        data = tomllib.load(open(p, 'rb'))
        if conn in data:
            c = data[conn]
            print(f'CFG_ACCOUNT=\"{c.get(\"account\", \"\")}\"')
            print(f'CFG_USER=\"{c.get(\"user\", \"\")}\"')
            print(f'CFG_PASSWORD=\"{c.get(\"password\", \"\")}\"')
            print(f'CFG_WAREHOUSE=\"{c.get(\"warehouse\", \"\")}\"')
            print(f'CFG_ROLE=\"{c.get(\"role\", \"\")}\"')
    except Exception:
        pass
" 2>/dev/null || true)"
fi

if [[ -n "${CFG_PASSWORD:-}" ]]; then
  export SNOWSQL_PWD="$CFG_PASSWORD"
fi

# --- Function: PUT file to Snowflake stage -----------------------------------
upload_stage() {
  local file="$1" schema="$2"
  local src_path="$SRC_DIR/$file"

  [[ -f "$src_path" ]] || { echo "ERROR: Missing source file: $src_path"; exit 1; }

  echo "-> Uploading: $file  =>  @$DATABASE.$schema.RAW_STAGE"

  if [[ -n "$CFG_ACCOUNT" && -n "$CFG_USER" ]]; then
    snowsql \
      -a "$CFG_ACCOUNT" \
      -u "$CFG_USER" \
      ${CFG_WAREHOUSE:+-w "$CFG_WAREHOUSE"} \
      ${CFG_ROLE:+-r "$CFG_ROLE"} \
      -d "$DATABASE" \
      -s "$schema" \
      -q "PUT file://$src_path @RAW_STAGE OVERWRITE = TRUE; !exit" \
      -o quiet=true
  else
    snowsql -c "$CONNECTION" \
      -d "$DATABASE" \
      -s "$schema" \
      -q "PUT file://$src_path @RAW_STAGE OVERWRITE = TRUE; !exit" \
      -o quiet=true
  fi
}

# --- Upload GDP Files ---------------------------------------------------------
upload_stage "life_expectancy.csv"   "GDP"
upload_stage "continent_mapping.csv" "GDP"

# --- Upload Superstore Files --------------------------------------------------
upload_stage "superstore_part1.csv"  "SUPERSTORE"
upload_stage "superstore_part2.csv"  "SUPERSTORE"
upload_stage "nomenclature.csv"      "SUPERSTORE"

echo
echo "=== Success: 5 files transferred to Snowflake internal stages ==="
echo "NEXT STEP: Run 03_load_tables.sql"

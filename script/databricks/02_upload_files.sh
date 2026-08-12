#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh
# Object : Normalizes (BOM + CRLF) then uploads the 9 raw files into Unity Catalog
#          volumes created by 01_setup_unity_catalog.sql
# Prerequisites : Databricks CLI v0.205+ authenticated (databricks auth login)
# Duration : ~1-2 minutes
# =============================================================================
set -euo pipefail

# --- Verify Databricks CLI availability ---------------------------------------
command -v databricks >/dev/null 2>&1 || {
  echo "ERROR: Databricks CLI 'databricks' is not installed or not available in PATH."
  echo "Please install it: https://docs.databricks.com/en/dev-tools/cli/databricks-cli.html"
  exit 1
}

# --- Parameters ---------------------------------------------------------------
PROFILE="${DATABRICKS_PROFILE:-emlyon}"
SRC_DIR="${1:-./data}"          # directory containing prepared source files
CATALOG="emlyon_use_cases"

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
echo "Catalog          : $CATALOG"
echo

# --- Function: Strip UTF-8 BOM + CRLF -> LF conversion -----------------------
normalize() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || { echo "ERROR: Missing source file: $src"; exit 1; }
  echo "-> Normalizing (BOM/CRLF): $(basename "$src") -> $(basename "$dst")"
  sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$src" > "$dst"
}

# --- GDP Use Case -------------------------------------------------------------
normalize "$SRC_DIR/life_expectancy.csv"    "$TMP_DIR/life_expectancy.csv"
normalize "$SRC_DIR/continent_mapping.csv"  "$TMP_DIR/continent_mapping.csv"

# --- Superstore Use Case ------------------------------------------------------
normalize "$SRC_DIR/superstore_part1.csv"   "$TMP_DIR/superstore_part1.csv"
normalize "$SRC_DIR/superstore_part2.csv"   "$TMP_DIR/superstore_part2.csv"
normalize "$SRC_DIR/nomenclature.csv"       "$TMP_DIR/nomenclature.csv"

# --- Allsales Use Case --------------------------------------------------------
normalize "$SRC_DIR/allsales_part1.csv"     "$TMP_DIR/allsales_part1.csv"
normalize "$SRC_DIR/allsales_part2.csv"     "$TMP_DIR/allsales_part2.csv"
normalize "$SRC_DIR/allsales_team.csv"      "$TMP_DIR/allsales_team.csv"
normalize "$SRC_DIR/allsales_store.csv"     "$TMP_DIR/allsales_store.csv"

echo

# --- Upload -------------------------------------------------------------------
upload() {
  local file="$1" schema="$2"
  local target_path="dbfs:/Volumes/$CATALOG/$schema/raw_files/$file"
  echo "-> Uploading: $file  =>  $CATALOG.$schema.raw_files"
  databricks fs cp "$TMP_DIR/$file" "$target_path" --overwrite -p "$PROFILE"
}

upload life_expectancy.csv    gdp
upload continent_mapping.csv  gdp
upload superstore_part1.csv   superstore
upload superstore_part2.csv   superstore
upload nomenclature.csv       superstore
upload allsales_part1.csv     allsales
upload allsales_part2.csv     allsales
upload allsales_team.csv      allsales
upload allsales_store.csv     allsales

echo
echo "=== Success: 9 files transferred to /Volumes/$CATALOG/{gdp,superstore,allsales}/raw_files/ ==="
echo "NEXT STEP: Run 03_load_tables.sql"

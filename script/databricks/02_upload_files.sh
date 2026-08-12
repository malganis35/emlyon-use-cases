#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh
# Objet : normalise (BOM + CRLF) puis uploade les 5 fichiers sources dans les
#         volumes Unity Catalog créés par 01_setup_unity_catalog.sql
# Prérequis : Databricks CLI v0.205+ authentifiée (databricks auth login)
# Durée : ~1 minute
# =============================================================================
set -euo pipefail

# --- Paramètres ---------------------------------------------------------------
PROFILE="${DATABRICKS_PROFILE:-DEFAULT}"
SRC_DIR="${1:-./data}"          # dossier contenant les fichiers d'origine
CATALOG="emlyon_use_cases"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# --- Fonction : strip BOM UTF-8 + conversion CRLF -> LF ------------------------
normalize() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || { echo "MANQUANT : $src"; exit 1; }
  sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$src" > "$dst"
}

# --- Use case GDP -------------------------------------------------------------
normalize "$SRC_DIR/life-expectancy-vs-gdp-per-capita_-_cleaned.csv" "$TMP_DIR/life_expectancy.csv"
normalize "$SRC_DIR/continent_mapping.csv"                           "$TMP_DIR/continent_mapping.csv"

# --- Use case Superstore ------------------------------------------------------
normalize "$SRC_DIR/Sample_-_EU_Superstore_Migrated_Data_-_Part_1.csv" "$TMP_DIR/superstore_part1.csv"
normalize "$SRC_DIR/Sample_-_EU_Superstore_Migrated_Data_-_Part_2.csv" "$TMP_DIR/superstore_part2.csv"
normalize "$SRC_DIR/nomenclature.csv"                                  "$TMP_DIR/nomenclature.csv"

# --- Upload -------------------------------------------------------------------
upload() {
  echo "-> $2"
  databricks fs cp "$TMP_DIR/$1" "dbfs:/Volumes/$CATALOG/$2/raw_files/$1" --overwrite -p "$PROFILE"
}

upload life_expectancy.csv    gdp
upload continent_mapping.csv  gdp
upload superstore_part1.csv   superstore
upload superstore_part2.csv   superstore
upload nomenclature.csv       superstore

echo
echo "OK : 5 fichiers dans /Volumes/$CATALOG/{gdp,superstore}/raw_files/"
echo "ÉTAPE SUIVANTE : exécuter 03_load_tables.sql"

#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh
# Objet : normalise (BOM + CRLF) puis uploade les 5 fichiers sources dans les
#         volumes Unity Catalog créés par 01_setup_unity_catalog.sql
# Prérequis : Databricks CLI v0.205+ authentifiée (databricks auth login)
# Durée : ~1 minute
# =============================================================================
set -euo pipefail

# --- Controler la présence de la CLI Databricks -------------------------------
command -v databricks >/dev/null 2>&1 || {
  echo "ERREUR : La CLI Databricks 'databricks' n'est pas installée ou pas disponible dans le PATH."
  echo "Veuillez l'installer : https://docs.databricks.com/en/dev-tools/cli/databricks-cli.html"
  exit 1
}

# --- Paramètres ---------------------------------------------------------------
PROFILE="${DATABRICKS_PROFILE:-DEFAULT}"
SRC_DIR="${1:-./data}"          # dossier contenant les fichiers d'origine
CATALOG="emlyon_use_cases"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERREUR : Le dossier source '$SRC_DIR' n'existe pas."
  echo "Usage : $0 [dossier_data]"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== Début de la préparation et de l'upload des fichiers ==="
echo "Dossier source : $SRC_DIR"
echo "Profil CLI     : $PROFILE"
echo "Catalogue      : $CATALOG"
echo

# --- Fonction : strip BOM UTF-8 + conversion CRLF -> LF ------------------------
normalize() {
  local src="$1" dst="$2"
  [[ -f "$src" ]] || { echo "ERREUR : Fichier source manquant : $src"; exit 1; }
  echo "-> Normalisation (BOM/CRLF) : $(basename "$src") -> $(basename "$dst")"
  sed -e '1s/^\xEF\xBB\xBF//' -e 's/\r$//' "$src" > "$dst"
}

# --- Use case GDP -------------------------------------------------------------
normalize "$SRC_DIR/life_expectancy.csv"    "$TMP_DIR/life_expectancy.csv"
normalize "$SRC_DIR/continent_mapping.csv"  "$TMP_DIR/continent_mapping.csv"

# --- Use case Superstore ------------------------------------------------------
normalize "$SRC_DIR/superstore_part1.csv"   "$TMP_DIR/superstore_part1.csv"
normalize "$SRC_DIR/superstore_part2.csv"   "$TMP_DIR/superstore_part2.csv"
normalize "$SRC_DIR/nomenclature.csv"       "$TMP_DIR/nomenclature.csv"

echo

# --- Upload -------------------------------------------------------------------
upload() {
  local file="$1" schema="$2"
  local target_path="dbfs:/Volumes/$CATALOG/$schema/raw_files/$file"
  echo "-> Upload : $file  =>  $CATALOG.$schema.raw_files"
  databricks fs cp "$TMP_DIR/$file" "$target_path" --overwrite -p "$PROFILE"
}

upload life_expectancy.csv    gdp
upload continent_mapping.csv  gdp
upload superstore_part1.csv   superstore
upload superstore_part2.csv   superstore
upload nomenclature.csv       superstore

echo
echo "=== Succès : 5 fichiers transférés dans /Volumes/$CATALOG/{gdp,superstore}/raw_files/ ==="
echo "ÉTAPE SUIVANTE : exécuter 03_load_tables.sql"

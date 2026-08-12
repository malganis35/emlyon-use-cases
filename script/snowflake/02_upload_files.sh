#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh (Snowflake)
# Objet : uploade les 5 fichiers sources dans les stages internes Snowflake
# Prérequis : SnowSQL (snowsql CLI) configuré et authentifié
# Durée : ~45 secondes
# =============================================================================
set -euo pipefail

# --- Contrôler la présence de SnowSQL -----------------------------------------
command -v snowsql >/dev/null 2>&1 || {
  echo "ERREUR : La CLI Snowflake 'snowsql' n'est pas installée ou pas disponible dans le PATH."
  echo "Veuillez l'installer : https://docs.snowflake.com/en/user-guide/snowsql-install-config"
  exit 1
}

# --- Paramètres ---------------------------------------------------------------
SRC_DIR="${1:-./data}"
CONNECTION="${SNOWSQL_CONN:-emlyon}"
DATABASE="EMLYON_USE_CASES"

if [[ ! -d "$SRC_DIR" ]]; then
  echo "ERREUR : Le dossier source '$SRC_DIR' n'existe pas."
  echo "Usage : $0 [dossier_data]"
  exit 1
fi

echo "=== Début du chargement des fichiers vers Snowflake ==="
echo "Dossier source : $SRC_DIR"
echo "Connexion      : $CONNECTION"
echo "Database       : $DATABASE"
echo

# --- Fonction : PUT vers un stage Snowflake -----------------------------------
upload_stage() {
  local file="$1" schema="$2"
  local src_path="$SRC_DIR/$file"

  [[ -f "$src_path" ]] || { echo "ERREUR : Fichier source manquant : $src_path"; exit 1; }

  echo "-> Upload : $file  =>  @$DATABASE.$schema.RAW_STAGE"
  snowsql -c "$CONNECTION" \
    -d "$DATABASE" \
    -s "$schema" \
    -q "PUT file://$src_path @RAW_STAGE OVERWRITE = TRUE AUTO_COMPRESS = FALSE;" \
    --o quiet=true
}

# --- Upload des fichiers GDP --------------------------------------------------
upload_stage "life_expectancy.csv"   "GDP"
upload_stage "continent_mapping.csv" "GDP"

# --- Upload des fichiers Superstore -------------------------------------------
upload_stage "superstore_part1.csv"  "SUPERSTORE"
upload_stage "superstore_part2.csv"  "SUPERSTORE"
upload_stage "nomenclature.csv"      "SUPERSTORE"

echo
echo "=== Succès : 5 fichiers transférés dans les stages Snowflake ==="
echo "ÉTAPE SUIVANTE : exécuter 03_load_tables.sql"

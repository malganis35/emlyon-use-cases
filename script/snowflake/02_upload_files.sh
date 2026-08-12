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

# --- Détection automatique de la connexion dans ~/.snowflake/connections.toml --
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

# --- Fonction : PUT vers un stage Snowflake -----------------------------------
upload_stage() {
  local file="$1" schema="$2"
  local src_path="$SRC_DIR/$file"

  [[ -f "$src_path" ]] || { echo "ERREUR : Fichier source manquant : $src_path"; exit 1; }

  echo "-> Upload : $file  =>  @$DATABASE.$schema.RAW_STAGE"

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

---
name: setup-instructeur
description: Vérifie et prépare la machine d'un instructeur pour ce projet (uv, Node/npm, git, CLI Databricks, snowsql) et teste les connexions Databricks et Snowflake. À utiliser pour un premier setup, une machine neuve, ou quand un upload ou une connexion échoue.
---

Public : instructeur qui déploie les données (droits admin). Pour la connexion étudiante en lecture seule, renvoyer au README, section 1 « Prerequisites & Local Setup », sans la recopier.

## Règles
- Diagnostic en lecture seule d'abord. Aucune installation ni écriture dans `~/.gitconfig` sans `AskUserQuestion` préalable, une confirmation par outil.
- Jamais de `sudo` sans accord explicite.
- Ne jamais afficher, journaliser ni passer en argument un mot de passe ou un token. Masquer `password` et `token` quand on lit un fichier de connexion.
- Ne jamais toucher aux droits étudiants (`BI_STUDENT_ROLE`, `STUDENT_BI_USER`, `db-invite-bi`).
- Chaque commande Bash tourne dans un shell séparé : passer `--profile` explicitement, ne pas compter sur un `export` précédent. `nvm` n'est pas dans le PATH d'un shell non interactif, ce qui ne veut pas dire que Node est absent.

## Étapes

### 1. Outils locaux
Lancer `uv --version`, `node -v`, `npm -v`, `git --version`, `databricks --version`, `snowsql --version` et `git config --global --get-regexp '^(user\.|init\.|pull\.)'`.
Lister ce qui manque, puis demander avant d'installer chaque outil. Pour git, demander nom, email et stratégie `pull.rebase` avant de configurer.

### 2. Databricks
- Profil attendu : `$DATABRICKS_PROFILE`, `emlyon` par défaut. Ne jamais choisir un profil à la place de l'utilisateur : lister avec `databricks auth profiles` et laisser choisir. Les autres profils peuvent être invalides sans conséquence pour ce projet.
- Profil absent ou invalide : proposer le skill `databricks:setup`. Pour un diagnostic plus large : `databricks:doctor`.
- Contrôles (lecture seule) : `databricks current-user me`, `catalogs list`, `schemas list emlyon_use_cases`, `volumes list emlyon_use_cases <gdp|superstore|allsales>`, `warehouses list`, tous avec `--profile`.

### 3. Snowflake
- Connexion : section `$SNOWSQL_CONN` (défaut `emlyon`) de `~/.snowflake/connections.toml`.
- `snowsql -c <nom>` ne lit pas ce fichier et échoue avec « No connection could be found ». Reproduire l'appel de `script/snowflake/02_upload_files.sh` : lire le TOML en Python, passer `-a`, `-u`, `-w`, `-r` en arguments et le mot de passe dans la variable d'environnement `SNOWSQL_PWD`.
- Contrôles (lecture seule) : `SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE()`, `SHOW SCHEMAS IN DATABASE EMLYON_USE_CASES`, `SHOW STAGES IN DATABASE EMLYON_USE_CASES`, `SHOW WAREHOUSES LIKE 'EMLYON_WH'`.

### 4. Projet
`uv sync`, puis `uv run emlyon-use-cases --help`.

### 5. Rapport
Tableau outil / version / statut, puis la liste des points restants. Ne pas conclure que tout est bon sans avoir exécuté les contrôles.

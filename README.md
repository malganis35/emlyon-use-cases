# 🎓 Guide de Déploiement — Databricks & Snowflake pour cours BI & DataViz

Bienvenue sur le projet **emlyon-use-cases**. Ce dépôt contient le pipeline d'alimentation des jeux de données pédagogiques (**GDP** et **EU Superstore**) pour les cours de Business Intelligence et Data Visualization (Power BI / Tableau).

Le projet propose deux déclinaisons Cloud prêtes à l'emploi :
- **Databricks Free Edition (Unity Catalog)** dans [`script/databricks/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/)
- **Snowflake** dans [`script/snowflake/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/snowflake/)

Ce guide pas-à-pas est conçu pour qu'un nouvel intervenant puisse déployer l'environnement complet en **15 à 20 minutes**.

---

## 📋 Table des Matières

- [1. Prérequis & Installation locale](#1-prérequis--installation-locale)
- [2. Étape 1 : Préparation des données brutes](#2-étape-1--préparation-des-données-brutes)
- [3. Déploiement sur Databricks Free Edition](#3-déploiement-sur-databricks-free-edition)
- [4. Déploiement sur Snowflake](#4-déploiement-sur-snowflake)
- [5. 🔑 Fiches de Connexion Étudiants (Power BI / Tableau)](#5--fiches-de-connexion-étudiants-power-bi--tableau)
- [6. 🎯 Pièges Pédagogiques Intégrés](#6--pièges-pédagogiques-intégrés)
- [7. 🧹 Réinitialisation Inter-promotions](#7--réinitialisation-inter-promotions)

---

## 1. Prérequis & Installation locale

Avant de commencer, vérifiez que votre poste dispose de :
1. **Python 3.12+** et du gestionnaire de paquets **`uv`** :
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
2. **CLI de votre plateforme Cloud** :
   - **Databricks CLI v0.205+** : `databricks auth login --host https://<workspace>.cloud.databricks.com -p emlyon`
   - **Snowflake CLI (`snowsql`)** : `snowsql -a <account_identifier> -u <admin_user>`

---

## 2. Étape 1 : Préparation des données brutes

Les fichiers sources bruts (Excel `.xlsx` et CSV) sont situés dans le dossier [`use_cases/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/use_cases/).

Lancez la CLI Python du projet pour convertir automatiquement les Excel en CSV avec séparateur `;`, nettoyer les BOM UTF-8 / CRLF et générer le dossier `./data/` :

```bash
uv run emlyon-use-cases prepare
```

**Fichiers générés dans `./data/`** :
- `life_expectancy.csv`
- `continent_mapping.csv`
- `superstore_part1.csv`
- `superstore_part2.csv`
- `nomenclature.csv`

---

## 3. Déploiement sur Databricks Free Edition

Ordre d'exécution dans [`script/databricks/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/) :

1. **`01_setup_unity_catalog.sql`** (SQL Editor Databricks) : Crée le catalogue `emlyon_use_cases`, les schémas `gdp` et `superstore`, et les volumes `raw_files`.
2. **`02_upload_files.sh`** (Terminal local) : 
   ```bash
   bash script/databricks/02_upload_files.sh ./data
   ```
3. **`03_load_tables.sql`** (SQL Editor Databricks) : Crée les tables `raw_*` et les tables typées `fact_*` / `dim_*` avec contraintes PK/FK.
4. **`04_grants_bi.sql`** (SQL Editor Databricks) : Configure l'accès en lecture seule pour le Service Principal `db-invite-bi`.

---

## 4. Déploiement sur Snowflake

Ordre d'exécution dans [`script/snowflake/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/snowflake/) :

1. **`01_setup_snowflake.sql`** (Interface Snowsight) :
   - Crée la base de données `EMLYON_USE_CASES`, les schémas `GDP` et `SUPERSTORE`.
   - Crée le warehouse `EMLYON_WH` (XSMALL), les formats de fichiers CSV et les stages internes `@RAW_STAGE`.
2. **`02_upload_files.sh`** (Terminal local) :
   ```bash
   bash script/snowflake/02_upload_files.sh ./data
   ```
   *Envoie les 5 fichiers CSV dans les stages internes Snowflake via `snowsql`.*
3. **`03_load_tables.sql`** (Interface Snowsight) :
   - Ingeste les CSV depuis les stages via `COPY INTO`.
   - Crée les tables `raw_*` et les tables typées `fact_*` / `dim_*` avec contraintes informatives.
4. **`04_grants_bi.sql`** (Interface Snowsight) :
   - Remplacez `<<STUDENT_PASSWORD>>` par le mot de passe du TP.
   - Crée le rôle `BI_STUDENT_ROLE` (lecture seule) et l'utilisateur `STUDENT_BI_USER`.

---

## 5. 🔑 Fiches de Connexion Étudiants (Power BI / Tableau)

### Option A : Connexion à Databricks
```text
Server hostname : <votre-workspace>.cloud.databricks.com
HTTP path       : /sql/1.0/warehouses/<id-warehouse>
Catalogue       : emlyon_use_cases
Schéma          : gdp   ou   superstore

Authentification :
- Power BI : Connexion "Databricks" -> Option "Client Credentials" (ID Client + Secret)
- Tableau  : Connecteur "Databricks" -> Méthode "Service Principal" (ID Client + Secret)
Mode            : IMPORT (Power BI) / EXTRACT (Tableau)
```

### Option B : Connexion à Snowflake
```text
Serveur / Compte : <account_identifier>.snowflakecomputing.com
Warehouse        : EMLYON_WH
Base de données  : EMLYON_USE_CASES
Schéma           : GDP   ou   SUPERSTORE
Rôle             : BI_STUDENT_ROLE

Authentification :
- Utilisateur : STUDENT_BI_USER
- Mot de passe: <STUDENT_PASSWORD>
Mode            : IMPORT (Power BI) / EXTRACT (Tableau)
```

---

## 6. 🎯 Pièges Pédagogiques Intégrés

Les données contiennent des anomalies **délibérées** qu'il ne faut **pas** corriger dans les scripts SQL. Elles constituent le cœur des exercices de Data Preparation pour les étudiants :

| Use Case | Piège pédagogique | Exercice visé pour les étudiants |
| :--- | :--- | :--- |
| **GDP** | Référentiel continents limité à `Europe`, `Asia`, `Mars`. | Pratique des jointures externes (Left Outer Join) et détection des valeurs orphelines. |
| **GDP** | Décimales avec virgules dans `Life exp`. | Conversion et typage de données à l'importation. |
| **Superstore** | Les fichiers `part1` et `part2` ont des ordres de colonnes différents. | Nécessité de réaliser une union par nom de colonne (Union by Name). |
| **Superstore** | Colonnes `Remove Inc ?` et `Remove Inc 2?` remplies de `?`. | Nettoyage du modèle en supprimant les colonnes parasites. |
| **Superstore** | Catégories préfixées (`1-Office Supplies`, `10-Technology`, `100-Furniture`). | Extraction de sous-chaînes (Split/Text Parsing) et tri personnalisé. |

---

## 7. 🧹 Réinitialisation Inter-promotions

- **Databricks** : Exécuter `DROP CATALOG IF EXISTS emlyon_use_cases CASCADE;` via [`script/databricks/99_reset.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/99_reset.sql).
- **Snowflake** : Exécuter le script [`script/snowflake/99_reset.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/snowflake/99_reset.sql).

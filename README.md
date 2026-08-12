# 🎓 Guide de Déploiement — Databricks Free Edition pour cours BI & DataViz

Bienvenue sur le projet **emlyon-use-cases**. Ce dépôt contient le pipeline d'alimentation des jeux de données pédagogiques (**GDP** et **EU Superstore**) sur **Databricks Free Edition (Unity Catalog)** pour les cours de Business Intelligence et Data Visualization (Power BI / Tableau).

Ce guide pas-à-pas est conçu pour qu'un nouvel intervenant puisse déployer l'environnement complet en **15 à 20 minutes**.

---

## 📋 Table des Matières

- [1. Prérequis & Installation locale](#1-prérequis--installation-locale)
- [2. Étape 1 : Préparation des données brutes](#2-étape-1--préparation-des-données-brutes)
- [3. Étape 2 : Initialisation d'Unity Catalog](#3-étape-2--initialisation-dunity-catalog)
- [4. Étape 3 : Upload des fichiers vers Databricks](#4-étape-3--upload-des-fichiers-vers-databricks)
- [5. Étape 4 : Ingestion des tables Delta](#5-étape-4--ingestion-des-tables-delta)
- [6. Étape 5 : Service Principal & Gestion des Accès (Lecture seule)](#6-étape-5--service-principal--gestion-des-accès-lecture-seule)
- [7. 🔑 Fiche de Connexion Étudiants (Power BI / Tableau)](#7--fiche-de-connexion-étudiants-power-bi--tableau)
- [8. 🎯 Pièges Pédagogiques Intégrés](#8--pièges-pédagogiques-intégrés)
- [9. 🧹 Réinitialisation Inter-promotions](#9--réinitialisation-inter-promotions)
- [10. ⚠️ Limites & Conseils Databricks Free Edition](#10-️-limites--conseils-databricks-free-edition)

---

## 1. Prérequis & Installation locale

Avant de commencer, vérifiez que votre poste dispose de :
1. **Python 3.12+** et du gestionnaire de paquets **`uv`** :
   ```bash
   curl -LsSf https://astral.sh/uv/install.sh | sh
   ```
2. **Databricks CLI v0.205+** ([Guide d'installation officiel](https://docs.databricks.com/en/dev-tools/cli/databricks-cli.html)) :
   ```bash
   # Sur Linux/macOS
   curl -fsSL https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh | sh
   ```
3. Authentification de votre CLI avec le profil `emlyon` :
   ```bash
   databricks auth login --host https://<votre-workspace>.cloud.databricks.com -p emlyon
   ```

---

## 2. Étape 1 : Préparation des données brutes

Les fichiers sources bruts (Excel `.xlsx` et CSV) sont situés dans le dossier [`use_cases/`](file:///home/ctdo/emlyon/project/emlyon-use-cases/use_cases/).

Lancez la CLI Python du projet pour convertir automatiquement les Excel en CSV avec séparateur `;`, nettoyer les BOM UTF-8 / CRLF et générer le dossier `./data/` :

```bash
uv run emlyon-use-cases prepare
```

**Résultat attendu** dans `./data/` :
- `life_expectancy.csv`
- `continent_mapping.csv`
- `superstore_part1.csv`
- `superstore_part2.csv`
- `nomenclature.csv`

---

## 3. Étape 2 : Initialisation d'Unity Catalog

1. Connectez-vous à votre espace **Databricks (SQL Editor)**.
2. Ouvrez le fichier [`script/databricks/01_setup_unity_catalog.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/01_setup_unity_catalog.sql).
3. Copiez-collez l'intégralité du script dans le SQL Editor et cliquez sur **Run**.

**Ce que fait ce script (~30 secondes)** :
- Crée le catalogue `emlyon_use_cases`.
- Crée les schémas `gdp` et `superstore`.
- Crée les volumes managés `raw_files` pour stocker les fichiers CSV bruts.

---

## 4. Étape 3 : Upload des fichiers vers Databricks

Dans votre terminal local, à la racine du projet, lancez le script Shell d'upload :

```bash
bash script/databricks/02_upload_files.sh ./data
```

**Ce que fait ce script (~1 minute)** :
- Vérifie la présence de la CLI Databricks.
- Téléverse les 5 fichiers du dossier `./data/` vers les volumes Unity Catalog :
  - `dbfs:/Volumes/emlyon_use_cases/gdp/raw_files/`
  - `dbfs:/Volumes/emlyon_use_cases/superstore/raw_files/`

---

## 5. Étape 4 : Ingestion des tables Delta

1. Dans le SQL Editor Databricks, ouvrez le script [`script/databricks/03_load_tables.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/03_load_tables.sql).
2. Exécutez le script complet (**Run**).

**Ce que fait ce script (~2 minutes)** :
- **Couche `raw_*`** : Ingeste les CSV bruts sans modification (`raw_life_expectancy`, `raw_orders`, etc.).
- **Couche `fact_*` / `dim_*`** : Crée les tables typées (`fact_life_expectancy`, `dim_continent`, `fact_orders`, `dim_category`) avec gestion sécurisée des types (`TRY_CAST`), tout en conservant les anomalies de données pédagogiques.
- **Modélisation BI** : Ajoute les contraintes `PRIMARY KEY` et `FOREIGN KEY` (mode `RELY DISABLE`) lues automatiquement par Power BI.
- **Contrôles de volumétrie** : Affiche les nombres de lignes attendus (12 744 lignes pour GDP, 10 000 lignes pour Superstore).

---

## 6. Étape 5 : Service Principal & Gestion des Accès (Lecture seule)

Pour permettre aux étudiants de se connecter sans compromettre la sécurité du workspace :

### A. Configuration dans l'interface Databricks (~5 minutes)
1. **Création du Service Principal** :
   - Allez dans **Settings** > **Identity and access** > **Service principals** > **Add service principal**.
   - Nom : `db-invite-bi`.
2. **Entitlements** :
   - Dans la fiche du Service Principal, cochez **Workspace access** et **Databricks SQL access**.
   - ⚠️ Ne **PAS** cocher *Allow unrestricted cluster creation* ni *Admin*.
3. **Génération des identifiants** :
   - Onglet **Secrets** > **Generate secret**.
   - **Copiez et conservez immédiatement** l'**Application ID** (Client ID) et le **Client Secret** (le secret ne sera plus réaffiché).
4. **Droits sur le Warehouse SQL** :
   - Allez dans **SQL Warehouses** > sélectionnez votre warehouse > **Permissions**.
   - Ajoutez `db-invite-bi` avec le droit **CAN USE**.
   - Dans l'onglet **Connection details**, notez le **Server hostname** et le **HTTP path**.

### B. Attribution des droits Unity Catalog
1. Ouvrez le fichier [`script/databricks/04_grants_bi.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/04_grants_bi.sql).
2. Remplacez toutes les occurrences de `<<CLIENT_ID>>` par l'Application ID de votre Service Principal (format UUID).
3. Exécutez le script dans le SQL Editor.

---

## 7. 🔑 Fiche de Connexion Étudiants (Power BI / Tableau)

Distribuez les paramètres suivants aux étudiants lors des travaux pratiques :

```text
===================================================================
PARAMÈTRES DE CONNEXION DATABRICKS — COURS BI & DATAVIZ
===================================================================
Server hostname : <votre-workspace>.cloud.databricks.com
HTTP path       : /sql/1.0/warehouses/<id-warehouse>
Catalogue       : emlyon_use_cases
Schéma          : gdp   (Use Case 1)   ou   superstore   (Use Case 2)

Authentification :
- Power BI : Connexion "Databricks" -> Option "Client Credentials"
             ID Client : <CLIENT_ID_DU_SERVICE_PRINCIPAL>
             Secret    : <CLIENT_SECRET_DU_SERVICE_PRINCIPAL>
- Tableau  : Connecteur "Databricks" -> Méthode "Service Principal"
             ID Client : <CLIENT_ID_DU_SERVICE_PRINCIPAL>
             Secret    : <CLIENT_SECRET_DU_SERVICE_PRINCIPAL>

Mode d'importation :
- Power BI : IMPORT (Ne PAS utiliser DirectQuery)
- Tableau  : EXTRACT (Ne PAS utiliser Live Connection)
===================================================================
```

---

## 8. 🎯 Pièges Pédagogiques Intégrés

Les données contiennent des anomalies **délibérées** qu'il ne faut **pas** corriger dans les scripts SQL Databricks. Elles constituent le cœur des exercices de Data Preparation pour les étudiants :

| Use Case | Piège pédagogique | Exercice visé pour les étudiants |
| :--- | :--- | :--- |
| **GDP** | Référentiel continents limité à `Europe`, `Asia`, `Mars`. | Pratique des jointures externes (Left Outer Join) et détection des valeurs orphelines. |
| **GDP** | Décimales avec virgules dans `Life exp`. | Conversion et typage de données à l'importation. |
| **Superstore** | Les fichiers `part1` et `part2` ont des ordres de colonnes différents. | Nécessité de réaliser une union par nom de colonne (Union by Name). |
| **Superstore** | Colonnes `Remove Inc ?` et `Remove Inc 2?` remplies de `?`. | Nettoyage du modèle en supprimant les colonnes parasites. |
| **Superstore** | Catégories préfixées (`1-Office Supplies`, `10-Technology`, `100-Furniture`). | Extraction de sous-chaînes (Split/Text Parsing) et tri personnalisé. |

---

## 9. 🧹 Réinitialisation Inter-promotions

Pour nettoyer complètement l'environnement avant une nouvelle année ou entre deux promotions :

1. Ouvrez [`script/databricks/99_reset.sql`](file:///home/ctdo/emlyon/project/emlyon-use-cases/script/databricks/99_reset.sql).
2. Décommentez la ligne de suppression :
   ```sql
   DROP CATALOG IF EXISTS emlyon_use_cases CASCADE;
   ```
3. Exécutez le script dans le SQL Editor. Tout le catalogue, les schémas, les tables Delta et les volumes seront supprimés.

---

## 10. ⚠️ Limites & Conseils Databricks Free Edition

1. **Un seul SQL Warehouse (2X-Small)** :
   C'est la raison pour laquelle **Import (Power BI)** / **Extract (Tableau)** est **obligatoire**. 30 étudiants envoyant des requêtes en DirectQuery simultanées saturent instantanément le warehouse.
2. **Quota d'heures de calcul** :
   En cas de dépassement de quota, le warehouse est coupé jusqu'au lendemain. Testez toujours le déploiement **la veille du cours**, jamais le matin même.
3. **Utilisateurs non supprimables** :
   Dans l'offre Free Edition, un compte utilisateur ajouté au workspace ne peut pas être supprimé. L'usage du **Service Principal** permet d'éviter de polluer le workspace avec des comptes étudiants éphémères.

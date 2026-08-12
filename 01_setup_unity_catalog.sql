-- =============================================================================
-- 01_setup_unity_catalog.sql
-- Cible : Databricks Free Edition (serverless) - SQL Editor ou notebook SQL
-- Objet : catalogue, schémas et volumes du cours Power BI / Tableau
-- Idempotent : oui (relançable sans effet de bord)
-- Durée d'exécution : ~30 secondes
-- =============================================================================

-- 1. Catalogue -----------------------------------------------------------------
CREATE CATALOG IF NOT EXISTS emlyon_use_cases
COMMENT 'Jeux de données pédagogiques emlyon - cours BI & DataViz (Power BI / Tableau)';

-- 2. Schémas (1 par use case) --------------------------------------------------
CREATE SCHEMA IF NOT EXISTS emlyon_use_cases.gdp
COMMENT 'Use case 1 - Espérance de vie vs PIB par habitant (Our World in Data). Exercices : jointure incomplète, décimales à virgule, dimension manquante.';

CREATE SCHEMA IF NOT EXISTS emlyon_use_cases.superstore
COMMENT 'Use case 2 - EU Superstore migré en 2 lots. Exercices : union de fichiers, colonnes parasites, nomenclature préfixée, dates dd/MM/yyyy.';

-- 3. Volumes managés (dépôt des fichiers sources) ------------------------------
CREATE VOLUME IF NOT EXISTS emlyon_use_cases.gdp.raw_files
COMMENT 'Fichiers plats sources du use case GDP';

CREATE VOLUME IF NOT EXISTS emlyon_use_cases.superstore.raw_files
COMMENT 'Fichiers plats sources du use case Superstore';

-- 4. Vérification --------------------------------------------------------------
SHOW VOLUMES IN emlyon_use_cases.gdp;
SHOW VOLUMES IN emlyon_use_cases.superstore;

-- >>> ÉTAPE SUIVANTE : exécuter 02_upload_files.sh (les volumes doivent exister)

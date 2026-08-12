-- =============================================================================
-- 01_setup_snowflake.sql
-- Cible : Snowflake - Web Interface (Snowsight) ou SnowSQL
-- Objet : Database, schémas, warehouse, formats de fichier et stages pour le cours BI
-- Idempotent : oui (relançable sans effet de bord)
-- Durée d'exécution : ~15 secondes
-- =============================================================================

-- 1. Database ------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS EMLYON_USE_CASES
  COMMENT = 'Jeux de données pédagogiques emlyon - cours BI & DataViz (Power BI / Tableau)';

USE DATABASE EMLYON_USE_CASES;

-- 2. Schémas (1 par use case) --------------------------------------------------
CREATE SCHEMA IF NOT EXISTS GDP
  COMMENT = 'Use case 1 - Espérance de vie vs PIB par habitant (Our World in Data)';

CREATE SCHEMA IF NOT EXISTS SUPERSTORE
  COMMENT = 'Use case 2 - EU Superstore migré en 2 lots';

-- 3. Virtual Warehouse (Taille minimale XSMALL) ---------------------------------
CREATE WAREHOUSE IF NOT EXISTS EMLYON_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse dédié au cours BI emlyon';

-- 4. Formats de fichiers (CSV avec séparateur point-virgule) -------------------
CREATE OR REPLACE FILE FORMAT GDP.CSV_FORMAT_SEMICOLON
  TYPE = 'CSV'
  FIELD_DELIMITER = ';'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE
  ENCODING = 'UTF8'
  COMMENT = 'Format CSV point-virgule avec en-tête pour le schema GDP';

CREATE OR REPLACE FILE FORMAT SUPERSTORE.CSV_FORMAT_SEMICOLON
  TYPE = 'CSV'
  FIELD_DELIMITER = ';'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE
  ENCODING = 'UTF8'
  COMMENT = 'Format CSV point-virgule avec en-tête pour le schema SUPERSTORE';

-- 5. Stages internes (dépôt des fichiers sources) -----------------------------
CREATE STAGE IF NOT EXISTS GDP.RAW_STAGE
  FILE_FORMAT = GDP.CSV_FORMAT_SEMICOLON
  COMMENT = 'Stage interne pour les fichiers sources GDP';

CREATE STAGE IF NOT EXISTS SUPERSTORE.RAW_STAGE
  FILE_FORMAT = SUPERSTORE.CSV_FORMAT_SEMICOLON
  COMMENT = 'Stage interne pour les fichiers sources Superstore';

-- 6. Vérification --------------------------------------------------------------
SHOW STAGES IN DATABASE EMLYON_USE_CASES;

-- >>> ÉTAPE SUIVANTE : exécuter 02_upload_files.sh depuis le terminal local

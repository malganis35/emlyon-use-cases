-- =============================================================================
-- 01_setup_snowflake.sql
-- Target : Snowflake - Web Interface (Snowsight) or SnowSQL
-- Object : Database, schemas, warehouse, file formats, and stages for BI course
-- Idempotent : Yes (safe to re-run)
-- Execution time : ~15 seconds
-- =============================================================================

-- 1. Database ------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS EMLYON_USE_CASES
  COMMENT = 'Pedagogical datasets for emlyon BI & DataViz course (Power BI / Tableau)';

USE DATABASE EMLYON_USE_CASES;

-- 2. Schemas (1 per use case) --------------------------------------------------
CREATE SCHEMA IF NOT EXISTS GDP
  COMMENT = 'Use case 1 - Life Expectancy vs GDP per capita (Our World in Data)';

CREATE SCHEMA IF NOT EXISTS SUPERSTORE
  COMMENT = 'Use case 2 - EU Superstore migrated in 2 batches';

-- 3. Virtual Warehouse (Minimum size XSMALL) ----------------------------------
CREATE WAREHOUSE IF NOT EXISTS EMLYON_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse dedicated to emlyon BI course';

-- 4. File Formats (Semicolon-delimited CSV) -----------------------------------
CREATE OR REPLACE FILE FORMAT GDP.CSV_FORMAT_SEMICOLON
  TYPE = 'CSV'
  FIELD_DELIMITER = ';'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE
  ENCODING = 'UTF8'
  COMMENT = 'Semicolon-delimited CSV format with header for GDP schema';

CREATE OR REPLACE FILE FORMAT SUPERSTORE.CSV_FORMAT_SEMICOLON
  TYPE = 'CSV'
  FIELD_DELIMITER = ';'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL')
  EMPTY_FIELD_AS_NULL = TRUE
  ENCODING = 'UTF8'
  COMMENT = 'Semicolon-delimited CSV format with header for SUPERSTORE schema';

-- 5. Internal Stages (Raw files staging area) ---------------------------------
CREATE STAGE IF NOT EXISTS GDP.RAW_STAGE
  FILE_FORMAT = GDP.CSV_FORMAT_SEMICOLON
  COMMENT = 'Internal stage for raw GDP source files';

CREATE STAGE IF NOT EXISTS SUPERSTORE.RAW_STAGE
  FILE_FORMAT = SUPERSTORE.CSV_FORMAT_SEMICOLON
  COMMENT = 'Internal stage for raw Superstore source files';

-- 6. Verification --------------------------------------------------------------
SHOW STAGES IN DATABASE EMLYON_USE_CASES;

-- >>> NEXT STEP: Run 02_upload_files.sh from local terminal

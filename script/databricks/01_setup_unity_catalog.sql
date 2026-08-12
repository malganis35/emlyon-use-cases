-- =============================================================================
-- 01_setup_unity_catalog.sql
-- Target : Databricks Free Edition (serverless) - SQL Editor or SQL notebook
-- Object : Catalog, schemas, and managed volumes for emlyon BI & DataViz course
-- Idempotent : Yes (safe to re-run)
-- Execution time : ~30 seconds
-- =============================================================================

-- 1. Catalog ------------------------------------------------------------------
CREATE CATALOG IF NOT EXISTS emlyon_use_cases
COMMENT 'Pedagogical datasets for emlyon BI & DataViz course (Power BI / Tableau)';

-- 2. Schemas (1 per use case) --------------------------------------------------
CREATE SCHEMA IF NOT EXISTS emlyon_use_cases.gdp
COMMENT 'Use case 1 - Life Expectancy vs GDP per capita (Our World in Data). Exercises: incomplete join, decimal commas, missing dimension.';

CREATE SCHEMA IF NOT EXISTS emlyon_use_cases.superstore
COMMENT 'Use case 2 - EU Superstore migrated in 2 batches. Exercises: file union, junk columns, prefixed categories, dd/MM/yyyy dates.';

CREATE SCHEMA IF NOT EXISTS emlyon_use_cases.allsales
COMMENT 'Use case 3 - Global Allsales workshop datasets (40,000 order line items across 2025-2026, Sales Team, Store Locations).';

-- 3. Managed Volumes (staging area for raw files) -----------------------------
CREATE VOLUME IF NOT EXISTS emlyon_use_cases.gdp.raw_files
COMMENT 'Staging area for raw flat CSV files (GDP use case)';

CREATE VOLUME IF NOT EXISTS emlyon_use_cases.superstore.raw_files
COMMENT 'Staging area for raw flat CSV files (Superstore use case)';

CREATE VOLUME IF NOT EXISTS emlyon_use_cases.allsales.raw_files
COMMENT 'Staging area for raw flat CSV files (Allsales use case)';

-- 4. Verification --------------------------------------------------------------
SHOW VOLUMES IN emlyon_use_cases.gdp;
SHOW VOLUMES IN emlyon_use_cases.superstore;
SHOW VOLUMES IN emlyon_use_cases.allsales;

-- >>> NEXT STEP: Run 02_upload_files.sh (Volumes must exist before uploading)

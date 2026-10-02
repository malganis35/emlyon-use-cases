-- =============================================================================
-- 03_load_tables.sql
-- Object : Loads the 9 volume files into 9 Delta tables, strictly 1 CSV = 1 table
--          Every column is STRING (explicit schema: no inference, no _rescued_data),
--          original column names, ALL columns kept (unnamed header = _c0),
--          no union, no rename, no cast, no constraints.
--          Students pre-process the data themselves (Power Query / Tableau Prep).
-- Idempotent : Yes (CREATE OR REPLACE / DROP TABLE IF EXISTS)
-- Duration : ~1-2 minutes on 2X-Small SQL Warehouse
-- =============================================================================

USE CATALOG emlyon_use_cases;

-- =============================================================================
-- 0. LEGACY CLEANUP (previous raw_* / fact_* / dim_* layers)
-- =============================================================================
DROP TABLE IF EXISTS gdp.fact_life_expectancy;
DROP TABLE IF EXISTS gdp.dim_continent;
DROP TABLE IF EXISTS gdp.raw_life_expectancy;
DROP TABLE IF EXISTS gdp.raw_continent_mapping;
DROP TABLE IF EXISTS superstore.fact_orders;
DROP TABLE IF EXISTS superstore.dim_category;
DROP TABLE IF EXISTS superstore.raw_orders;
DROP TABLE IF EXISTS superstore.raw_nomenclature;
DROP TABLE IF EXISTS allsales.fact_orders;
DROP TABLE IF EXISTS allsales.dim_sales_team;
DROP TABLE IF EXISTS allsales.dim_store;
DROP TABLE IF EXISTS allsales.raw_orders;
DROP TABLE IF EXISTS allsales.raw_team;
DROP TABLE IF EXISTS allsales.raw_store;

-- =============================================================================
-- USE CASE 1 : GDP
-- =============================================================================

-- 1.1 Life Expectancy vs GDP (12,744 rows expected) ---------------------------
CREATE OR REPLACE TABLE gdp.life_expectancy
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file life_expectancy.csv, as is. Decimal commas on Life exp, empty Annotations column.'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/gdp/raw_files/life_expectancy.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`Code` STRING, `Continent` STRING, `Country` STRING, `GDP per capita (Annotations)` STRING, `Year` STRING, `GDP` STRING, `Life exp` STRING, `Population` STRING'
);

-- 1.2 Continent mapping (3 rows expected) -------------------------------------
CREATE OR REPLACE TABLE gdp.continent_mapping
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file continent_mapping.csv, as is. INTENTIONALLY INCOMPLETE (Europe, Asia, Mars).'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/gdp/raw_files/continent_mapping.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`Continent` STRING, `Code Continent` STRING'
);

-- =============================================================================
-- USE CASE 2 : SUPERSTORE
-- =============================================================================

-- 2.1 Migration batch 1 (3,895 rows expected) ---------------------------------
CREATE OR REPLACE TABLE superstore.superstore_part1
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file superstore_part1.csv, as is. Column order differs from part2.'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/superstore_part1.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`City` STRING, `Country/Region` STRING, `Customer Name` STRING, `Manufacturer` STRING, `Order Date` STRING, `Order ID` STRING, `Product Name` STRING, `Remove Inc ?` STRING, `Remove Inc 2?` STRING, `Region` STRING, `Segment` STRING, `Ship Date` STRING, `Ship Mode` STRING, `State/Province` STRING, `Sub-Category` STRING, `Discount` STRING, `Profit` STRING, `Quantity` STRING, `Sales` STRING'
);

-- 2.2 Migration batch 2 (6,105 rows expected) ---------------------------------
CREATE OR REPLACE TABLE superstore.superstore_part2
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file superstore_part2.csv, as is. Column order differs from part1.'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/superstore_part2.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`Country/Region` STRING, `City` STRING, `Customer Name` STRING, `Manufacturer` STRING, `Order Date` STRING, `Order ID` STRING, `Product Name` STRING, `Region` STRING, `Remove Inc ?` STRING, `Remove Inc 2?` STRING, `Segment` STRING, `Ship Date` STRING, `Ship Mode` STRING, `State/Province` STRING, `Sub-Category` STRING, `Discount` STRING, `Profit` STRING, `Quantity` STRING, `Sales` STRING'
);

-- 2.3 Category nomenclature (17 rows expected) --------------------------------
CREATE OR REPLACE TABLE superstore.nomenclature
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file nomenclature.csv, as is. Prefixed categories (1-Office Supplies).'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/nomenclature.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`Category` STRING, `Sub-Category` STRING'
);

-- =============================================================================
-- USE CASE 3 : ALLSALES
-- =============================================================================

-- 3.1 Sales batch 2025 (20,000 rows expected) ---------------------------------
CREATE OR REPLACE TABLE allsales.allsales_part1
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file allsales_part1.csv, as is (2025 batch).'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_part1.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`Order Number` STRING, `Source` STRING, `Company` STRING, `Sales Date` STRING, `Sales Channel` STRING, `Currency` STRING, `SalesAgentID` STRING, `StoreID` STRING, `Product` STRING, `Order qty` STRING, `unit price` STRING, `unit cost` STRING'
);

-- 3.2 Sales batch 2026 (20,000 rows expected) ---------------------------------
CREATE OR REPLACE TABLE allsales.allsales_part2
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file allsales_part2.csv, as is (2026 batch).'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_part2.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`Order Number` STRING, `Source` STRING, `Company` STRING, `Sales Date` STRING, `Sales Channel` STRING, `Currency` STRING, `SalesAgentID` STRING, `StoreID` STRING, `Product` STRING, `Order qty` STRING, `unit price` STRING, `unit cost` STRING'
);

-- 3.3 Sales team (31 rows expected) -------------------------------------------
CREATE OR REPLACE TABLE allsales.allsales_team
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file allsales_team.csv, as is. Unnamed first column (_c0).'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_team.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`_c0` STRING, `Index` STRING, `Sales Team` STRING, `Region` STRING'
);

-- 3.4 Store locations (367 rows expected) -------------------------------------
CREATE OR REPLACE TABLE allsales.allsales_store
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source file allsales_store.csv, as is. Unnamed first column (_c0) and extra columns.'
AS
SELECT * FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_store.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8',
  schema => '`_c0` STRING, `id` STRING, `name` STRING, `Colonne1` STRING, `county` STRING, `region` STRING, `state_code` STRING, `state` STRING, `type` STRING, `latitude` STRING, `longitude` STRING, `area_code` STRING, `population` STRING, `households` STRING, `median_income` STRING, `land_area` STRING, `water_area` STRING, `time_zone` STRING, `state_geo` STRING'
);

-- =============================================================================
-- 4. CHECKS (all 9 rows should return expected volumes)
-- =============================================================================
SELECT 'gdp.life_expectancy'         AS table_name, COUNT(*) AS row_count, 12744 AS expected FROM gdp.life_expectancy
UNION ALL SELECT 'gdp.continent_mapping',        COUNT(*),     3 FROM gdp.continent_mapping
UNION ALL SELECT 'superstore.superstore_part1',  COUNT(*),  3895 FROM superstore.superstore_part1
UNION ALL SELECT 'superstore.superstore_part2',  COUNT(*),  6105 FROM superstore.superstore_part2
UNION ALL SELECT 'superstore.nomenclature',      COUNT(*),    17 FROM superstore.nomenclature
UNION ALL SELECT 'allsales.allsales_part1',      COUNT(*), 20000 FROM allsales.allsales_part1
UNION ALL SELECT 'allsales.allsales_part2',      COUNT(*), 20000 FROM allsales.allsales_part2
UNION ALL SELECT 'allsales.allsales_team',       COUNT(*),    31 FROM allsales.allsales_team
UNION ALL SELECT 'allsales.allsales_store',      COUNT(*),   367 FROM allsales.allsales_store;

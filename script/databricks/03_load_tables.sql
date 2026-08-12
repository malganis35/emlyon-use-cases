-- =============================================================================
-- 03_load_tables.sql
-- Object : Loads the 5 volume files into Delta tables
--          RAW Layer   = all STRING, original column names (for student exercises)
--          CLEAN Layer = proper types, snake_case names, UNCLEANED VALUES (by design)
-- Idempotent : Yes (CREATE OR REPLACE)
-- Duration : ~2 minutes on 2X-Small SQL Warehouse
-- =============================================================================

USE CATALOG emlyon_use_cases;

-- =============================================================================
-- USE CASE 1 : GDP
-- =============================================================================

-- 1.1 RAW : Life Expectancy vs GDP (12,744 rows expected) --------------------
CREATE OR REPLACE TABLE gdp.raw_life_expectancy
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Raw source Our World in Data. Decimal commas on Life exp, empty Annotations column.'
AS
SELECT
  `Code`,
  `Continent`,
  `Country`,
  `GDP per capita (Annotations)`,
  `Year`,
  `GDP`,
  `Life exp`,
  `Population`
FROM read_files(
  '/Volumes/emlyon_use_cases/gdp/raw_files/life_expectancy.csv',
  format => 'csv',
  sep    => ';',
  header => true,
  encoding => 'UTF-8'
);

-- 1.2 RAW : Continent mapping reference table (3 rows expected) ---------------
CREATE OR REPLACE TABLE gdp.raw_continent_mapping
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Continent reference table INTENTIONALLY INCOMPLETE (Europe, Asia, Mars): used for outer join and orphan value exercises.'
AS
SELECT `Continent`, `Code Continent`
FROM read_files(
  '/Volumes/emlyon_use_cases/gdp/raw_files/continent_mapping.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 1.3 CLEAN : Typed fact table ------------------------------------------------
CREATE OR REPLACE TABLE gdp.fact_life_expectancy
COMMENT 'Life expectancy and GDP per capita, per country and per year (1 row = 1 country x 1 year).'
AS
SELECT
  `Code`                                                   AS country_code,
  `Country`                                                AS country,
  `Continent`                                              AS continent,
  TRY_CAST(`Year` AS INT)                                  AS year,
  TRY_CAST(REPLACE(`GDP`, ',', '.') AS DOUBLE)             AS gdp_per_capita,
  TRY_CAST(REPLACE(`Life exp`, ',', '.') AS DOUBLE)        AS life_expectancy,
  TRY_CAST(`Population` AS BIGINT)                         AS population
FROM gdp.raw_life_expectancy;

-- 1.4 CLEAN : Continent dimension ---------------------------------------------
CREATE OR REPLACE TABLE gdp.dim_continent
COMMENT 'Continent reference dimension (partially complete by pedagogical design).'
AS
SELECT `Continent` AS continent, `Code Continent` AS continent_code
FROM gdp.raw_continent_mapping;

ALTER TABLE gdp.dim_continent ALTER COLUMN continent SET NOT NULL;
ALTER TABLE gdp.dim_continent ADD CONSTRAINT pk_dim_continent PRIMARY KEY (continent);
ALTER TABLE gdp.fact_life_expectancy ADD CONSTRAINT fk_fact_life_expectancy_continent FOREIGN KEY (continent) REFERENCES gdp.dim_continent(continent);

-- 1.5 Column Comments (automatically picked up by Power BI) -------------------
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN country_code    COMMENT 'ISO-3 country code';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN gdp_per_capita  COMMENT 'GDP per capita, constant USD';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN life_expectancy COMMENT 'Life expectancy at birth, in years';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN population      COMMENT 'Total country population';
ALTER TABLE gdp.dim_continent        ALTER COLUMN continent_code  COMMENT 'Short continent code (partial reference table)';

-- =============================================================================
-- USE CASE 2 : SUPERSTORE
-- =============================================================================

-- 2.1 RAW : Union of the 2 migration batches (3,895 + 6,105 = 10,000 rows expected)
-- ATTENTION: The 2 CSV files do NOT have the same column order.
-- The union is performed via an explicit SELECT column list, never SELECT *.
CREATE OR REPLACE TABLE superstore.raw_orders
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'EU Superstore orders, union of 2 migration batches. Remove Inc ? columns to discard, dd/MM/yyyy date format.'
AS
SELECT
  'part1' AS `_source_file`,
  `City`, `Country/Region`, `Customer Name`, `Manufacturer`, `Order Date`, `Order ID`,
  `Product Name`, `Remove Inc ?`, `Remove Inc 2?`, `Region`, `Segment`, `Ship Date`,
  `Ship Mode`, `State/Province`, `Sub-Category`, `Discount`, `Profit`, `Quantity`, `Sales`
FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/superstore_part1.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
)
UNION ALL
SELECT
  'part2' AS `_source_file`,
  `City`, `Country/Region`, `Customer Name`, `Manufacturer`, `Order Date`, `Order ID`,
  `Product Name`, `Remove Inc ?`, `Remove Inc 2?`, `Region`, `Segment`, `Ship Date`,
  `Ship Mode`, `State/Province`, `Sub-Category`, `Discount`, `Profit`, `Quantity`, `Sales`
FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/superstore_part2.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 2.2 RAW : Category nomenclature (17 rows expected) --------------------------
CREATE OR REPLACE TABLE superstore.raw_nomenclature
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Category / Sub-Category nomenclature. The numeric prefix (1-, 10-, 100-) is intentional: cleaning exercise.'
AS
SELECT `Category`, `Sub-Category`
FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/nomenclature.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 2.3 CLEAN : Typed fact table (values unchanged) -----------------------------
CREATE OR REPLACE TABLE superstore.fact_orders
COMMENT 'EU Superstore order line items (1 row = 1 product in an order).'
AS
SELECT
  `Order ID`                                                        AS order_id,
  TRY_CAST(try_to_timestamp(`Order Date`, 'dd/MM/yyyy') AS DATE)    AS order_date,
  TRY_CAST(try_to_timestamp(`Ship Date`,  'dd/MM/yyyy') AS DATE)    AS ship_date,
  `Ship Mode`                                                       AS ship_mode,
  `Customer Name`                                                   AS customer_name,
  `Segment`                                                         AS segment,
  `Country/Region`                                                  AS country,
  `State/Province`                                                  AS state_province,
  `City`                                                            AS city,
  `Region`                                                          AS region,
  `Manufacturer`                                                    AS manufacturer,
  `Product Name`                                                    AS product_name,
  `Sub-Category`                                                    AS sub_category,
  TRY_CAST(REPLACE(`Quantity`, ',', '.') AS INT)                    AS quantity,
  TRY_CAST(REPLACE(`Sales`,    ',', '.') AS DOUBLE)                 AS sales,
  TRY_CAST(REPLACE(`Profit`,   ',', '.') AS DOUBLE)                 AS profit,
  TRY_CAST(REPLACE(`Discount`, ',', '.') AS DOUBLE)                 AS discount,
  `_source_file`                                                    AS source_file
FROM superstore.raw_orders;

-- 2.4 CLEAN : Category dimension ----------------------------------------------
CREATE OR REPLACE TABLE superstore.dim_category
COMMENT 'Category dimension. The category label preserves its numeric prefix.'
AS
SELECT `Sub-Category` AS sub_category, `Category` AS category
FROM superstore.raw_nomenclature;

ALTER TABLE superstore.dim_category ALTER COLUMN sub_category SET NOT NULL;
ALTER TABLE superstore.dim_category ADD CONSTRAINT pk_dim_category PRIMARY KEY (sub_category);
ALTER TABLE superstore.fact_orders ADD CONSTRAINT fk_fact_orders_category FOREIGN KEY (sub_category) REFERENCES superstore.dim_category(sub_category);

ALTER TABLE superstore.fact_orders ALTER COLUMN sales       COMMENT 'Line item sales revenue, EUR';
ALTER TABLE superstore.fact_orders ALTER COLUMN profit      COMMENT 'Line item profit margin, EUR';
ALTER TABLE superstore.fact_orders ALTER COLUMN discount    COMMENT 'Applied discount rate (0 to 1)';
ALTER TABLE superstore.fact_orders ALTER COLUMN source_file COMMENT 'Original migration batch: part1 or part2';

-- =============================================================================
-- 3. CHECKS (all 4 rows should return expected volumes)
-- =============================================================================
SELECT 'gdp.fact_life_expectancy'    AS table_name, COUNT(*) AS rows, 12744 AS expected FROM gdp.fact_life_expectancy
UNION ALL SELECT 'gdp.dim_continent',            COUNT(*),     3 FROM gdp.dim_continent
UNION ALL SELECT 'superstore.fact_orders',       COUNT(*), 10000 FROM superstore.fact_orders
UNION ALL SELECT 'superstore.dim_category',      COUNT(*),    17 FROM superstore.dim_category;

-- Type check: no unexpected NULL values
SELECT
  SUM(CASE WHEN life_expectancy IS NULL THEN 1 ELSE 0 END) AS ko_life_exp,
  SUM(CASE WHEN year IS NULL            THEN 1 ELSE 0 END) AS ko_year
FROM gdp.fact_life_expectancy;

SELECT
  SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS ko_order_date,
  SUM(CASE WHEN sales      IS NULL THEN 1 ELSE 0 END) AS ko_sales
FROM superstore.fact_orders;

-- >>> NEXT STEP: Run 04_grants_bi.sql

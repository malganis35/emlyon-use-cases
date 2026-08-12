-- =============================================================================
-- 03_load_tables.sql
-- Object : Loads the 9 volume files into Delta tables across 3 use cases
--          RAW Layer   = all STRING, original column names (for student exercises)
--          CLEAN Layer = proper types, snake_case names, UNCLEANED VALUES (by design)
-- Idempotent : Yes (CREATE OR REPLACE)
-- Duration : ~2-3 minutes on 2X-Small SQL Warehouse
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
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 1.2 RAW : Continent mapping reference table (3 rows expected) ---------------
CREATE OR REPLACE TABLE gdp.raw_continent_mapping
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Continent reference table INTENTIONALLY INCOMPLETE (Europe, Asia, Mars).'
AS
SELECT `Continent`, `Code Continent`
FROM read_files(
  '/Volumes/emlyon_use_cases/gdp/raw_files/continent_mapping.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 1.3 CLEAN : Typed fact table ------------------------------------------------
CREATE OR REPLACE TABLE gdp.fact_life_expectancy
COMMENT 'Life expectancy and GDP per capita, per country and per year.'
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

ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN country_code    COMMENT 'ISO-3 country code';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN gdp_per_capita  COMMENT 'GDP per capita, constant USD';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN life_expectancy COMMENT 'Life expectancy at birth, in years';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN population      COMMENT 'Total country population';
ALTER TABLE gdp.dim_continent        ALTER COLUMN continent_code  COMMENT 'Short continent code (partial reference table)';

-- =============================================================================
-- USE CASE 2 : SUPERSTORE
-- =============================================================================

-- 2.1 RAW : Union of the 2 migration batches (3,895 + 6,105 = 10,000 rows expected)
CREATE OR REPLACE TABLE superstore.raw_orders
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'EU Superstore orders, union of 2 migration batches.'
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
COMMENT 'Category / Sub-Category nomenclature.'
AS
SELECT `Category`, `Sub-Category`
FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/nomenclature.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 2.3 CLEAN : Typed fact table ------------------------------------------------
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
COMMENT 'Category dimension.'
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
-- USE CASE 3 : ALLSALES
-- =============================================================================

-- 3.1 RAW : Union of the 2 sales batches (20,000 + 20,000 = 40,000 rows expected)
CREATE OR REPLACE TABLE allsales.raw_orders
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Global sales transactions, union of 2025 and 2026 batches.'
AS
SELECT
  'part1' AS `_source_file`,
  `Order Number`, `Source`, `Company`, `Sales Date`, `Sales Channel`, `Currency`,
  `SalesAgentID`, `StoreID`, `Product`, `Order qty`, `unit price`, `unit cost`
FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_part1.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
)
UNION ALL
SELECT
  'part2' AS `_source_file`,
  `Order Number`, `Source`, `Company`, `Sales Date`, `Sales Channel`, `Currency`,
  `SalesAgentID`, `StoreID`, `Product`, `Order qty`, `unit price`, `unit cost`
FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_part2.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 3.2 RAW : Sales team reference table (31 rows expected) --------------------
CREATE OR REPLACE TABLE allsales.raw_team
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Sales agents reference table.'
AS
SELECT `Index`, `Sales Team`, `Region`
FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_team.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 3.3 RAW : Store locations reference table (367 rows expected) ---------------
CREATE OR REPLACE TABLE allsales.raw_store
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Store locations and demographic metadata.'
AS
SELECT
  `id`, `name`, `county`, `region`, `state_code`, `state`, `type`,
  `latitude`, `longitude`, `area_code`, `population`, `households`,
  `median_income`, `land_area`
FROM read_files(
  '/Volumes/emlyon_use_cases/allsales/raw_files/allsales_store.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 3.4 CLEAN : Typed fact table ------------------------------------------------
CREATE OR REPLACE TABLE allsales.fact_orders
COMMENT 'Sales order line items with calculated sales, cost, and profit amounts.'
AS
SELECT
  `Order Number`                                                    AS order_number,
  TRY_CAST(try_to_timestamp(`Sales Date`, 'yyyy-MM-dd HH:mm:ss') AS DATE) AS sales_date,
  `Sales Channel`                                                   AS sales_channel,
  `Company`                                                         AS company,
  `Currency`                                                        AS currency,
  TRY_CAST(`SalesAgentID` AS INT)                                   AS sales_agent_id,
  TRY_CAST(`StoreID` AS INT)                                        AS store_id,
  `Product`                                                         AS product,
  TRY_CAST(REPLACE(`Order qty`, ',', '.') AS INT)                   AS order_quantity,
  TRY_CAST(REPLACE(`unit price`, ',', '.') AS DOUBLE)              AS unit_price,
  TRY_CAST(REPLACE(`unit cost`,  ',', '.') AS DOUBLE)              AS unit_cost,
  TRY_CAST(REPLACE(`Order qty`, ',', '.') AS INT) * TRY_CAST(REPLACE(`unit price`, ',', '.') AS DOUBLE) AS sales_amount,
  TRY_CAST(REPLACE(`Order qty`, ',', '.') AS INT) * TRY_CAST(REPLACE(`unit cost`,  ',', '.') AS DOUBLE) AS cost_amount,
  (TRY_CAST(REPLACE(`Order qty`, ',', '.') AS INT) * TRY_CAST(REPLACE(`unit price`, ',', '.') AS DOUBLE)) - 
  (TRY_CAST(REPLACE(`Order qty`, ',', '.') AS INT) * TRY_CAST(REPLACE(`unit cost`,  ',', '.') AS DOUBLE)) AS profit_amount,
  `_source_file`                                                    AS source_file
FROM allsales.raw_orders;

-- 3.5 CLEAN : Typed dimension tables ------------------------------------------
CREATE OR REPLACE TABLE allsales.dim_sales_team
COMMENT 'Sales team dimension.'
AS
SELECT
  TRY_CAST(`Index` AS INT) AS sales_agent_id,
  `Sales Team`             AS sales_team_name,
  `Region`                 AS sales_region
FROM allsales.raw_team;

ALTER TABLE allsales.dim_sales_team ALTER COLUMN sales_agent_id SET NOT NULL;
ALTER TABLE allsales.dim_sales_team ADD CONSTRAINT pk_dim_sales_team PRIMARY KEY (sales_agent_id);

CREATE OR REPLACE TABLE allsales.dim_store
COMMENT 'Store locations dimension.'
AS
SELECT
  TRY_CAST(`id` AS INT)                                      AS store_id,
  `name`                                                     AS store_name,
  `county`                                                   AS county,
  `region`                                                   AS region,
  `state_code`                                               AS state_code,
  `state`                                                    AS state,
  `type`                                                     AS store_type,
  TRY_CAST(REPLACE(`latitude`, ',', '.') AS DOUBLE)          AS latitude,
  TRY_CAST(REPLACE(`longitude`, ',', '.') AS DOUBLE)         AS longitude,
  TRY_CAST(`area_code` AS INT)                               AS area_code,
  TRY_CAST(REPLACE(`population`, ',', '.') AS BIGINT)        AS population,
  TRY_CAST(REPLACE(`households`, ',', '.') AS BIGINT)        AS households,
  TRY_CAST(REPLACE(`median_income`, ',', '.') AS DOUBLE)     AS median_income,
  TRY_CAST(REPLACE(`land_area`, ',', '.') AS DOUBLE)         AS land_area
FROM allsales.raw_store;

ALTER TABLE allsales.dim_store ALTER COLUMN store_id SET NOT NULL;
ALTER TABLE allsales.dim_store ADD CONSTRAINT pk_dim_store PRIMARY KEY (store_id);

ALTER TABLE allsales.fact_orders ADD CONSTRAINT fk_fact_orders_sales_agent FOREIGN KEY (sales_agent_id) REFERENCES allsales.dim_sales_team(sales_agent_id);
ALTER TABLE allsales.fact_orders ADD CONSTRAINT fk_fact_orders_store FOREIGN KEY (store_id) REFERENCES allsales.dim_store(store_id);

-- =============================================================================
-- 4. CHECKS (all 7 rows should return expected volumes)
-- =============================================================================
SELECT 'gdp.fact_life_expectancy'    AS table_name, COUNT(*) AS row_count, 12744 AS expected FROM gdp.fact_life_expectancy
UNION ALL SELECT 'gdp.dim_continent',            COUNT(*),     3 FROM gdp.dim_continent
UNION ALL SELECT 'superstore.fact_orders',       COUNT(*), 10000 FROM superstore.fact_orders
UNION ALL SELECT 'superstore.dim_category',      COUNT(*),    17 FROM superstore.dim_category
UNION ALL SELECT 'allsales.fact_orders',         COUNT(*), 40000 FROM allsales.fact_orders
UNION ALL SELECT 'allsales.dim_sales_team',      COUNT(*),    31 FROM allsales.dim_sales_team
UNION ALL SELECT 'allsales.dim_store',           COUNT(*),   367 FROM allsales.dim_store;

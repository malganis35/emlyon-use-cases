-- =============================================================================
-- 03_load_tables.sql
-- Objet : charge les 5 fichiers des volumes vers des tables Delta
--         Couche RAW  = tout en STRING, noms de colonnes d'origine (exercices)
--         Couche CLEAN = types corrects, noms snake_case, VALEURS NON NETTOYÉES
-- Idempotent : oui (CREATE OR REPLACE)
-- Durée : ~2 minutes sur SQL Warehouse 2X-Small
-- =============================================================================

USE CATALOG emlyon_use_cases;

-- =============================================================================
-- USE CASE 1 : GDP
-- =============================================================================

-- 1.1 RAW : espérance de vie vs PIB (12 744 lignes attendues) ------------------
CREATE OR REPLACE TABLE gdp.raw_life_expectancy
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Source brute Our World in Data. Décimales à virgule sur Life exp, colonne Annotations vide.'
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

-- 1.2 RAW : table de correspondance continent (3 lignes attendues) -------------
CREATE OR REPLACE TABLE gdp.raw_continent_mapping
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Référentiel continent volontairement INCOMPLET (Europe, Asia, Mars) : sert aux exercices de jointure et de valeurs orphelines.'
AS
SELECT `Continent`, `Code Continent`
FROM read_files(
  '/Volumes/emlyon_use_cases/gdp/raw_files/continent_mapping.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 1.3 CLEAN : table de faits typée --------------------------------------------
CREATE OR REPLACE TABLE gdp.fact_life_expectancy
COMMENT 'Espérance de vie et PIB par habitant, par pays et par année (1 ligne = 1 pays x 1 année).'
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

-- 1.4 CLEAN : dimension continent ---------------------------------------------
CREATE OR REPLACE TABLE gdp.dim_continent
COMMENT 'Référentiel continent (incomplet par construction pédagogique).'
AS
SELECT `Continent` AS continent, `Code Continent` AS continent_code
FROM gdp.raw_continent_mapping;

ALTER TABLE gdp.dim_continent ALTER COLUMN continent SET NOT NULL;
ALTER TABLE gdp.dim_continent ADD CONSTRAINT pk_dim_continent PRIMARY KEY (continent);
ALTER TABLE gdp.fact_life_expectancy ADD CONSTRAINT fk_fact_life_expectancy_continent FOREIGN KEY (continent) REFERENCES gdp.dim_continent(continent) RELY DISABLE;

-- 1.5 Commentaires de colonnes (repris automatiquement par Power BI) ----------
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN country_code    COMMENT 'Code ISO-3 du pays';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN gdp_per_capita  COMMENT 'PIB par habitant, USD constants';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN life_expectancy COMMENT 'Espérance de vie à la naissance, en années';
ALTER TABLE gdp.fact_life_expectancy ALTER COLUMN population      COMMENT 'Population totale du pays';
ALTER TABLE gdp.dim_continent        ALTER COLUMN continent_code  COMMENT 'Code court du continent (référentiel partiel)';

-- =============================================================================
-- USE CASE 2 : SUPERSTORE
-- =============================================================================

-- 2.1 RAW : union des 2 lots (3 895 + 6 105 = 10 000 lignes attendues) ---------
-- ATTENTION : les 2 fichiers n'ont PAS le même ordre de colonnes.
-- L'union se fait donc par liste explicite, jamais par SELECT *.
CREATE OR REPLACE TABLE superstore.raw_orders
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Commandes EU Superstore, union des 2 lots de migration. Colonnes Remove Inc ? à écarter, dates au format dd/MM/yyyy.'
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

-- 2.2 RAW : nomenclature catégories (17 lignes attendues) ---------------------
CREATE OR REPLACE TABLE superstore.raw_nomenclature
TBLPROPERTIES ('delta.columnMapping.mode' = 'name')
COMMENT 'Nomenclature Category / Sub-Category. Le préfixe numérique (1-, 10-, 100-) est volontaire : exercice de nettoyage.'
AS
SELECT `Category`, `Sub-Category`
FROM read_files(
  '/Volumes/emlyon_use_cases/superstore/raw_files/nomenclature.csv',
  format => 'csv', sep => ';', header => true, encoding => 'UTF-8'
);

-- 2.3 CLEAN : table de faits typée (valeurs inchangées) -----------------------
CREATE OR REPLACE TABLE superstore.fact_orders
COMMENT 'Lignes de commande EU Superstore (1 ligne = 1 produit d''une commande).'
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

-- 2.4 CLEAN : dimension catégorie ---------------------------------------------
CREATE OR REPLACE TABLE superstore.dim_category
COMMENT 'Dimension catégorie. Le libellé category conserve son préfixe numérique.'
AS
SELECT `Sub-Category` AS sub_category, `Category` AS category
FROM superstore.raw_nomenclature;

ALTER TABLE superstore.dim_category ALTER COLUMN sub_category SET NOT NULL;
ALTER TABLE superstore.dim_category ADD CONSTRAINT pk_dim_category PRIMARY KEY (sub_category);
ALTER TABLE superstore.fact_orders ADD CONSTRAINT fk_fact_orders_category FOREIGN KEY (sub_category) REFERENCES superstore.dim_category(sub_category) RELY DISABLE;

ALTER TABLE superstore.fact_orders ALTER COLUMN sales    COMMENT 'Chiffre d''affaires de la ligne, EUR';
ALTER TABLE superstore.fact_orders ALTER COLUMN profit   COMMENT 'Marge de la ligne, EUR';
ALTER TABLE superstore.fact_orders ALTER COLUMN discount COMMENT 'Taux de remise appliqué (0 à 1)';
ALTER TABLE superstore.fact_orders ALTER COLUMN source_file COMMENT 'Lot de migration d''origine : part1 ou part2';

-- =============================================================================
-- 3. CONTRÔLES (les 4 lignes doivent renvoyer les volumes attendus)
-- =============================================================================
SELECT 'gdp.fact_life_expectancy'    AS table_name, COUNT(*) AS lignes, 12744 AS attendu FROM gdp.fact_life_expectancy
UNION ALL SELECT 'gdp.dim_continent',            COUNT(*),     3 FROM gdp.dim_continent
UNION ALL SELECT 'superstore.fact_orders',       COUNT(*), 10000 FROM superstore.fact_orders
UNION ALL SELECT 'superstore.dim_category',      COUNT(*),    17 FROM superstore.dim_category;

-- Contrôle de typage : aucune valeur NULL inattendue
SELECT
  SUM(CASE WHEN life_expectancy IS NULL THEN 1 ELSE 0 END) AS ko_life_exp,
  SUM(CASE WHEN year IS NULL            THEN 1 ELSE 0 END) AS ko_year
FROM gdp.fact_life_expectancy;

SELECT
  SUM(CASE WHEN order_date IS NULL THEN 1 ELSE 0 END) AS ko_order_date,
  SUM(CASE WHEN sales      IS NULL THEN 1 ELSE 0 END) AS ko_sales
FROM superstore.fact_orders;

-- >>> ÉTAPE SUIVANTE : exécuter 04_grants_bi.sql

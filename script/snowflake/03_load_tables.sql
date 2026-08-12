-- =============================================================================
-- 03_load_tables.sql (Snowflake)
-- Objet : charge les 5 fichiers des stages Snowflake vers des tables
--         Couche RAW  = tout en STRING, noms de colonnes d'origine (exercices)
--         Couche CLEAN = types corrects, noms snake_case, VALEURS NON NETTOYÉES
-- Idempotent : oui (CREATE OR REPLACE)
-- Durée : ~30 secondes sur Warehouse XSMALL
-- =============================================================================

USE DATABASE EMLYON_USE_CASES;
USE WAREHOUSE EMLYON_WH;

-- =============================================================================
-- USE CASE 1 : GDP
-- =============================================================================

-- 1.1 RAW : espérance de vie vs PIB (12 744 lignes attendues) ------------------
CREATE OR REPLACE TABLE GDP.RAW_LIFE_EXPECTANCY (
  CODE STRING,
  CONTINENT STRING,
  COUNTRY STRING,
  GDP_PER_CAPITA_ANNOTATIONS STRING,
  YEAR STRING,
  GDP STRING,
  LIFE_EXP STRING,
  POPULATION STRING
)
COMMENT = 'Source brute Our World in Data. Décimales à virgule sur Life exp.';

COPY INTO GDP.RAW_LIFE_EXPECTANCY
FROM @GDP.RAW_STAGE/life_expectancy.csv
FILE_FORMAT = (FORMAT_NAME = 'GDP.CSV_FORMAT_SEMICOLON')
ON_ERROR = 'CONTINUE';

-- 1.2 RAW : table de correspondance continent (3 lignes attendues) -------------
CREATE OR REPLACE TABLE GDP.RAW_CONTINENT_MAPPING (
  CONTINENT STRING,
  CODE_CONTINENT STRING
)
COMMENT = 'Référentiel continent volontairement INCOMPLET (Europe, Asia, Mars)';

COPY INTO GDP.RAW_CONTINENT_MAPPING
FROM @GDP.RAW_STAGE/continent_mapping.csv
FILE_FORMAT = (FORMAT_NAME = 'GDP.CSV_FORMAT_SEMICOLON')
ON_ERROR = 'CONTINUE';

-- 1.3 CLEAN : table de faits typée --------------------------------------------
CREATE OR REPLACE TABLE GDP.FACT_LIFE_EXPECTANCY
COMMENT = 'Espérance de vie et PIB par habitant, par pays et par année.'
AS
SELECT
  CODE                                                   AS COUNTRY_CODE,
  COUNTRY                                                AS COUNTRY,
  CONTINENT                                              AS CONTINENT,
  TRY_CAST(YEAR AS INT)                                  AS YEAR,
  TRY_CAST(REPLACE(GDP, ',', '.') AS DOUBLE)             AS GDP_PER_CAPITA,
  TRY_CAST(REPLACE(LIFE_EXP, ',', '.') AS DOUBLE)        AS LIFE_EXPECTANCY,
  TRY_CAST(POPULATION AS BIGINT)                         AS POPULATION
FROM GDP.RAW_LIFE_EXPECTANCY;

-- 1.4 CLEAN : dimension continent ---------------------------------------------
CREATE OR REPLACE TABLE GDP.DIM_CONTINENT
COMMENT = 'Référentiel continent (incomplet par construction pédagogique).'
AS
SELECT CONTINENT AS CONTINENT, CODE_CONTINENT AS CONTINENT_CODE
FROM GDP.RAW_CONTINENT_MAPPING;

ALTER TABLE GDP.DIM_CONTINENT ADD CONSTRAINT PK_DIM_CONTINENT PRIMARY KEY (CONTINENT);
ALTER TABLE GDP.FACT_LIFE_EXPECTANCY ADD CONSTRAINT FK_FACT_LIFE_EXPECTANCY_CONTINENT FOREIGN KEY (CONTINENT) REFERENCES GDP.DIM_CONTINENT(CONTINENT);

-- Commentaires de colonnes
COMMENT ON COLUMN GDP.FACT_LIFE_EXPECTANCY.COUNTRY_CODE    IS 'Code ISO-3 du pays';
COMMENT ON COLUMN GDP.FACT_LIFE_EXPECTANCY.GDP_PER_CAPITA  IS 'PIB par habitant, USD constants';
COMMENT ON COLUMN GDP.FACT_LIFE_EXPECTANCY.LIFE_EXPECTANCY IS 'Espérance de vie à la naissance, en années';
COMMENT ON COLUMN GDP.FACT_LIFE_EXPECTANCY.POPULATION      IS 'Population totale du pays';
COMMENT ON COLUMN GDP.DIM_CONTINENT.CONTINENT_CODE         IS 'Code court du continent (référentiel partiel)';

-- =============================================================================
-- USE CASE 2 : SUPERSTORE
-- =============================================================================

-- 2.1 RAW : union des 2 lots (3 895 + 6 105 = 10 000 lignes attendues) ---------
CREATE OR REPLACE TABLE SUPERSTORE.RAW_ORDERS (
  SOURCE_FILE STRING,
  CITY STRING,
  COUNTRY_REGION STRING,
  CUSTOMER_NAME STRING,
  MANUFACTURER STRING,
  ORDER_DATE STRING,
  ORDER_ID STRING,
  PRODUCT_NAME STRING,
  REMOVE_INC STRING,
  REMOVE_INC_2 STRING,
  REGION STRING,
  SEGMENT STRING,
  SHIP_DATE STRING,
  SHIP_MODE STRING,
  STATE_PROVINCE STRING,
  SUB_CATEGORY STRING,
  DISCOUNT STRING,
  PROFIT STRING,
  QUANTITY STRING,
  SALES STRING
)
COMMENT = 'Commandes EU Superstore, union des 2 lots de migration.';

COPY INTO SUPERSTORE.RAW_ORDERS
FROM (
  SELECT 'part1', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
  FROM @SUPERSTORE.RAW_STAGE/superstore_part1.csv
)
FILE_FORMAT = (FORMAT_NAME = 'SUPERSTORE.CSV_FORMAT_SEMICOLON')
ON_ERROR = 'CONTINUE';

COPY INTO SUPERSTORE.RAW_ORDERS
FROM (
  SELECT 'part2', $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19
  FROM @SUPERSTORE.RAW_STAGE/superstore_part2.csv
)
FILE_FORMAT = (FORMAT_NAME = 'SUPERSTORE.CSV_FORMAT_SEMICOLON')
ON_ERROR = 'CONTINUE';

-- 2.2 RAW : nomenclature catégories (17 lignes attendues) ---------------------
CREATE OR REPLACE TABLE SUPERSTORE.RAW_NOMENCLATURE (
  CATEGORY STRING,
  SUB_CATEGORY STRING
)
COMMENT = 'Nomenclature Category / Sub-Category.';

COPY INTO SUPERSTORE.RAW_NOMENCLATURE
FROM @SUPERSTORE.RAW_STAGE/nomenclature.csv
FILE_FORMAT = (FORMAT_NAME = 'SUPERSTORE.CSV_FORMAT_SEMICOLON')
ON_ERROR = 'CONTINUE';

-- 2.3 CLEAN : table de faits typée --------------------------------------------
CREATE OR REPLACE TABLE SUPERSTORE.FACT_ORDERS
COMMENT = 'Lignes de commande EU Superstore.'
AS
SELECT
  ORDER_ID                                                      AS ORDER_ID,
  TRY_TO_DATE(ORDER_DATE, 'DD/MM/YYYY')                         AS ORDER_DATE,
  TRY_TO_DATE(SHIP_DATE,  'DD/MM/YYYY')                         AS SHIP_DATE,
  SHIP_MODE                                                     AS SHIP_MODE,
  CUSTOMER_NAME                                                 AS CUSTOMER_NAME,
  SEGMENT                                                       AS SEGMENT,
  COUNTRY_REGION                                                AS COUNTRY,
  STATE_PROVINCE                                                AS STATE_PROVINCE,
  CITY                                                          AS CITY,
  REGION                                                        AS REGION,
  MANUFACTURER                                                  AS MANUFACTURER,
  PRODUCT_NAME                                                  AS PRODUCT_NAME,
  SUB_CATEGORY                                                  AS SUB_CATEGORY,
  TRY_CAST(REPLACE(QUANTITY, ',', '.') AS INT)                  AS QUANTITY,
  TRY_CAST(REPLACE(SALES,    ',', '.') AS DOUBLE)               AS SALES,
  TRY_CAST(REPLACE(PROFIT,   ',', '.') AS DOUBLE)               AS PROFIT,
  TRY_CAST(REPLACE(DISCOUNT, ',', '.') AS DOUBLE)               AS DISCOUNT,
  SOURCE_FILE                                                   AS SOURCE_FILE
FROM SUPERSTORE.RAW_ORDERS;

-- 2.4 CLEAN : dimension catégorie ---------------------------------------------
CREATE OR REPLACE TABLE SUPERSTORE.DIM_CATEGORY
COMMENT = 'Dimension catégorie.'
AS
SELECT SUB_CATEGORY AS SUB_CATEGORY, CATEGORY AS CATEGORY
FROM SUPERSTORE.RAW_NOMENCLATURE;

ALTER TABLE SUPERSTORE.DIM_CATEGORY ADD CONSTRAINT PK_DIM_CATEGORY PRIMARY KEY (SUB_CATEGORY);
ALTER TABLE SUPERSTORE.FACT_ORDERS ADD CONSTRAINT FK_FACT_ORDERS_CATEGORY FOREIGN KEY (SUB_CATEGORY) REFERENCES SUPERSTORE.DIM_CATEGORY(SUB_CATEGORY);

COMMENT ON COLUMN SUPERSTORE.FACT_ORDERS.SALES       IS 'Chiffre d''affaires de la ligne, EUR';
COMMENT ON COLUMN SUPERSTORE.FACT_ORDERS.PROFIT      IS 'Marge de la ligne, EUR';
COMMENT ON COLUMN SUPERSTORE.FACT_ORDERS.DISCOUNT    IS 'Taux de remise appliqué (0 à 1)';
COMMENT ON COLUMN SUPERSTORE.FACT_ORDERS.SOURCE_FILE IS 'Lot de migration d''origine : part1 ou part2';

-- =============================================================================
-- 3. CONTRÔLES DE VOLUMÉTRIE
-- =============================================================================
SELECT 'GDP.FACT_LIFE_EXPECTANCY'    AS TABLE_NAME, COUNT(*) AS LIGNES, 12744 AS ATTENDU FROM GDP.FACT_LIFE_EXPECTANCY
UNION ALL SELECT 'GDP.DIM_CONTINENT',            COUNT(*),     3 FROM GDP.DIM_CONTINENT
UNION ALL SELECT 'SUPERSTORE.FACT_ORDERS',       COUNT(*), 10000 FROM SUPERSTORE.FACT_ORDERS
UNION ALL SELECT 'SUPERSTORE.DIM_CATEGORY',      COUNT(*),    17 FROM SUPERSTORE.DIM_CATEGORY;

-- >>> ÉTAPE SUIVANTE : exécuter 04_grants_bi.sql

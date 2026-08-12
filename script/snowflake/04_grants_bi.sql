-- =============================================================================
-- 04_grants_bi.sql (Snowflake)
-- Object : Creation of BI_STUDENT_ROLE role and STUDENT_BI_USER student user.
--          READ-ONLY privileges for Power BI and Tableau across all 3 use cases.
-- Duration : ~10 seconds
--
-- REPLACE <<STUDENT_PASSWORD>> with a secure password for students.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE EMLYON_USE_CASES;

-- 1. Create dedicated student role --------------------------------------------
CREATE ROLE IF NOT EXISTS BI_STUDENT_ROLE
  COMMENT = 'Restricted read-only role for students (Power BI / Tableau)';

-- 2. Privileges on Snowflake objects ------------------------------------------

-- Warehouse usage
GRANT USAGE ON WAREHOUSE EMLYON_WH TO ROLE BI_STUDENT_ROLE;

-- Database and schema traversal
GRANT USAGE ON DATABASE EMLYON_USE_CASES TO ROLE BI_STUDENT_ROLE;
GRANT USAGE ON SCHEMA EMLYON_USE_CASES.GDP TO ROLE BI_STUDENT_ROLE;
GRANT USAGE ON SCHEMA EMLYON_USE_CASES.SUPERSTORE TO ROLE BI_STUDENT_ROLE;
GRANT USAGE ON SCHEMA EMLYON_USE_CASES.ALLSALES TO ROLE BI_STUDENT_ROLE;

-- Read-only SELECT on existing tables
GRANT SELECT ON ALL TABLES IN SCHEMA EMLYON_USE_CASES.GDP TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA EMLYON_USE_CASES.SUPERSTORE TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA EMLYON_USE_CASES.ALLSALES TO ROLE BI_STUDENT_ROLE;

-- Read-only SELECT on future tables
GRANT SELECT ON FUTURE TABLES IN SCHEMA EMLYON_USE_CASES.GDP TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA EMLYON_USE_CASES.SUPERSTORE TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA EMLYON_USE_CASES.ALLSALES TO ROLE BI_STUDENT_ROLE;

-- 3. Create student user and assign role --------------------------------------
CREATE USER IF NOT EXISTS STUDENT_BI_USER
  PASSWORD = '<<STUDENT_PASSWORD>>'
  DEFAULT_ROLE = BI_STUDENT_ROLE
  DEFAULT_WAREHOUSE = EMLYON_WH
  DEFAULT_NAMESPACE = EMLYON_USE_CASES.GDP
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'Shared student user account for BI workshops';

GRANT ROLE BI_STUDENT_ROLE TO USER STUDENT_BI_USER;

-- 4. Verification -------------------------------------------------------------
SHOW GRANTS TO ROLE BI_STUDENT_ROLE;
SHOW GRANTS TO USER STUDENT_BI_USER;

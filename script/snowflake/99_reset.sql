-- =============================================================================
-- 99_reset.sql (Snowflake)
-- DESTRUCTIF : supprime la base de données, le warehouse, le rôle et l'utilisateur.
-- À utiliser entre deux promotions.
-- Décommenter les lignes pour l'exécuter.
-- =============================================================================

-- USE ROLE ACCOUNTADMIN;

-- DROP DATABASE IF EXISTS EMLYON_USE_CASES CASCADE;
-- DROP WAREHOUSE IF EXISTS EMLYON_WH;
-- DROP USER IF EXISTS STUDENT_BI_USER;
-- DROP ROLE IF EXISTS BI_STUDENT_ROLE;

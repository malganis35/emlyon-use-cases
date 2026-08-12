-- =============================================================================
-- 04_grants_bi.sql (Snowflake)
-- Objet : Création du rôle BI_STUDENT_ROLE et de l'utilisateur étudiant STUDENT_BI_USER
--         Droits LECTURE SEULE pour Power BI et Tableau.
-- Durée : ~10 secondes
--
-- REMPLACER <<STUDENT_PASSWORD>> par un mot de passe sécurisé pour les étudiants.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE EMLYON_USE_CASES;

-- 1. Création du rôle dédié aux étudiants ------------------------------------
CREATE ROLE IF NOT EXISTS BI_STUDENT_ROLE
  COMMENT = 'Rôle restreint en lecture seule pour les étudiants (Power BI / Tableau)';

-- 2. Privilèges sur les objets Snowflake ---------------------------------------

-- Usage du Warehouse
GRANT USAGE ON WAREHOUSE EMLYON_WH TO ROLE BI_STUDENT_ROLE;

-- Traversée de la base et des schémas
GRANT USAGE ON DATABASE EMLYON_USE_CASES TO ROLE BI_STUDENT_ROLE;
GRANT USAGE ON SCHEMA EMLYON_USE_CASES.GDP TO ROLE BI_STUDENT_ROLE;
GRANT USAGE ON SCHEMA EMLYON_USE_CASES.SUPERSTORE TO ROLE BI_STUDENT_ROLE;

-- Lecture seule sur les tables existantes
GRANT SELECT ON ALL TABLES IN SCHEMA EMLYON_USE_CASES.GDP TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA EMLYON_USE_CASES.SUPERSTORE TO ROLE BI_STUDENT_ROLE;

-- Lecture seule sur les tables futures
GRANT SELECT ON FUTURE TABLES IN SCHEMA EMLYON_USE_CASES.GDP TO ROLE BI_STUDENT_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA EMLYON_USE_CASES.SUPERSTORE TO ROLE BI_STUDENT_ROLE;

-- 3. Création de l'utilisateur étudiant et attribution du rôle ---------------
CREATE USER IF NOT EXISTS STUDENT_BI_USER
  PASSWORD = '<<STUDENT_PASSWORD>>'
  DEFAULT_ROLE = BI_STUDENT_ROLE
  DEFAULT_WAREHOUSE = EMLYON_WH
  DEFAULT_NAMESPACE = EMLYON_USE_CASES.GDP
  MUST_CHANGE_PASSWORD = FALSE
  COMMENT = 'Compte utilisateur partagé pour les étudiants en TP BI';

GRANT ROLE BI_STUDENT_ROLE TO USER STUDENT_BI_USER;

-- 4. Vérification des privilèges ----------------------------------------------
SHOW GRANTS TO ROLE BI_STUDENT_ROLE;
SHOW GRANTS TO USER STUDENT_BI_USER;

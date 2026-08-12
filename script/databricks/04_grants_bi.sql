-- =============================================================================
-- 04_grants_bi.sql
-- Objet : droits LECTURE SEULE pour le service principal utilise par les
--         etudiants dans Power BI et Tableau.
-- Duree : ~15 secondes
--
-- PREREQUIS : le service principal doit exister AVANT de lancer ce script.
--             Voir la section A ci-dessous (interface, ~5 minutes).
--
-- REMPLACER <<CLIENT_ID>> par l'Application ID du service principal
-- (un UUID du type 12ab34cd-5678-90ef-1234-567890abcdef).
-- /!\ Unity Catalog attend l'Application ID, PAS le nom d'affichage.
-- =============================================================================

-- =============================================================================
-- A. A FAIRE DANS L'INTERFACE AVANT CE SCRIPT
--
--  1. Settings > Identity and access > Service principals > Add service principal
--     Nom : db-invite-bi
--  2. Onglet Configurations du SP : cocher les entitlements
--       - Workspace access
--       - Databricks SQL access
--     Ne PAS cocher Allow unrestricted cluster creation ni Admin.
--  3. Onglet Secrets : Generate secret
--     Noter Client ID et Client secret : le secret n'est affiche qu'une fois.
--  4. SQL Warehouse > Permissions > ajouter db-invite-bi en CAN USE
--  5. SQL Warehouse > Connection details : noter Server hostname et HTTP path
-- =============================================================================

-- =============================================================================
-- B. DROITS UNITY CATALOG (lecture seule)
-- =============================================================================

-- B.1 Traversee du catalogue et des schemas ------------------------------------
GRANT USE CATALOG ON CATALOG emlyon_use_cases            TO `<<CLIENT_ID>>`;
GRANT USE SCHEMA  ON SCHEMA  emlyon_use_cases.gdp        TO `<<CLIENT_ID>>`;
GRANT USE SCHEMA  ON SCHEMA  emlyon_use_cases.superstore TO `<<CLIENT_ID>>`;

-- B.2 Lecture des tables (SELECT au niveau schema : couvre les tables futures) --
GRANT SELECT ON SCHEMA emlyon_use_cases.gdp        TO `<<CLIENT_ID>>`;
GRANT SELECT ON SCHEMA emlyon_use_cases.superstore TO `<<CLIENT_ID>>`;

-- B.3 Lecture des fichiers sources (exercice "connexion au CSV brut") ----------
GRANT READ VOLUME ON VOLUME emlyon_use_cases.gdp.raw_files        TO `<<CLIENT_ID>>`;
GRANT READ VOLUME ON VOLUME emlyon_use_cases.superstore.raw_files TO `<<CLIENT_ID>>`;

-- =============================================================================
-- C. VERIFICATION
--    Attendu : uniquement USE CATALOG / USE SCHEMA / SELECT / READ VOLUME.
--    Aucun MODIFY, CREATE TABLE, ALL PRIVILEGES ne doit apparaitre.
-- =============================================================================
SHOW GRANTS `<<CLIENT_ID>>` ON CATALOG emlyon_use_cases;
SHOW GRANTS `<<CLIENT_ID>>` ON SCHEMA  emlyon_use_cases.gdp;
SHOW GRANTS `<<CLIENT_ID>>` ON SCHEMA  emlyon_use_cases.superstore;

-- =============================================================================
-- D. REVOCATION EN FIN DE SEMESTRE (decommenter)
-- =============================================================================
-- REVOKE ALL PRIVILEGES ON CATALOG emlyon_use_cases FROM `<<CLIENT_ID>>`;
-- Puis supprimer le secret dans Settings > Identity and access > Service principals.
-- =============================================================================

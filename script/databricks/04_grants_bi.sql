-- =============================================================================
-- 04_grants_bi.sql
-- Object : READ-ONLY privileges for the service principal used by students
--          in Power BI and Tableau.
-- Duration : ~15 seconds
--
-- PREREQUISITE : The service principal MUST be created in the UI BEFORE running this script.
--                See Section A below (~5 minutes UI setup).
--
-- REPLACE <<CLIENT_ID>> with the Application ID of the service principal
-- (a UUID like 12ab34cd-5678-90ef-1234-567890abcdef).
-- /!\ Unity Catalog expects the Application ID, NOT the display name.
-- =============================================================================

-- =============================================================================
-- A. UI STEPS BEFORE RUNNING THIS SCRIPT
--
--  1. Settings > Identity and access > Service principals > Add service principal
--     Name: db-invite-bi
2. Service Principal Configurations tab: check entitlements
--       - Workspace access
--       - Databricks SQL access
--     Do NOT check Allow unrestricted cluster creation or Admin.
--  3. Secrets tab: Generate secret
--     Note Client ID and Client secret (the secret is shown only once).
--  4. SQL Warehouse > Permissions > add db-invite-bi as CAN USE
--  5. SQL Warehouse > Connection details: note Server hostname and HTTP path
-- =============================================================================

-- =============================================================================
-- B. UNITY CATALOG PRIVILEGES (Read-Only)
-- =============================================================================

-- B.1 Catalog and Schema Traversal --------------------------------------------
GRANT USE CATALOG ON CATALOG emlyon_use_cases            TO `<<CLIENT_ID>>`;
GRANT USE SCHEMA  ON SCHEMA  emlyon_use_cases.gdp        TO `<<CLIENT_ID>>`;
GRANT USE SCHEMA  ON SCHEMA  emlyon_use_cases.superstore TO `<<CLIENT_ID>>`;

-- B.2 Table Select Privileges (Schema-level SELECT covers future tables) -------
GRANT SELECT ON SCHEMA emlyon_use_cases.gdp        TO `<<CLIENT_ID>>`;
GRANT SELECT ON SCHEMA emlyon_use_cases.superstore TO `<<CLIENT_ID>>`;

-- B.3 Raw Volume Read Privileges ("Raw CSV connection" exercise) ---------------
GRANT READ VOLUME ON VOLUME emlyon_use_cases.gdp.raw_files        TO `<<CLIENT_ID>>`;
GRANT READ VOLUME ON VOLUME emlyon_use_cases.superstore.raw_files TO `<<CLIENT_ID>>`;

-- =============================================================================
-- C. VERIFICATION
--    Expected: ONLY USE CATALOG / USE SCHEMA / SELECT / READ VOLUME.
--    No MODIFY, CREATE TABLE, or ALL PRIVILEGES should appear.
-- =============================================================================
SHOW GRANTS `<<CLIENT_ID>>` ON CATALOG emlyon_use_cases;
SHOW GRANTS `<<CLIENT_ID>>` ON SCHEMA  emlyon_use_cases.gdp;
SHOW GRANTS `<<CLIENT_ID>>` ON SCHEMA  emlyon_use_cases.superstore;

-- =============================================================================
-- D. END-OF-SEMESTER REVOCATION (uncomment)
-- =============================================================================
-- REVOKE ALL PRIVILEGES ON CATALOG emlyon_use_cases FROM `<<CLIENT_ID>>`;
-- Then delete secret in Settings > Identity and access > Service principals.
-- =============================================================================

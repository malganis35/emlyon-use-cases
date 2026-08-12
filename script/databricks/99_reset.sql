-- =============================================================================
-- 99_reset.sql
-- DESTRUCTIVE: Drops catalog, schemas, volumes, tables AND uploaded files.
-- To be used between academic cohorts.
-- Uncomment the line to execute.
-- =============================================================================

-- DROP CATALOG IF EXISTS emlyon_use_cases CASCADE;

-- Targeted cleanup of a single use case:
-- DROP SCHEMA IF EXISTS emlyon_use_cases.gdp        CASCADE;
-- DROP SCHEMA IF EXISTS emlyon_use_cases.superstore CASCADE;

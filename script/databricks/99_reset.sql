-- =============================================================================
-- 99_reset.sql
-- DESTRUCTIF : supprime le catalogue, les schémas, les volumes, les tables ET
-- les fichiers uploadés. À utiliser entre deux promotions.
-- Décommenter la ligne pour l'exécuter.
-- =============================================================================

-- DROP CATALOG IF EXISTS emlyon_use_cases CASCADE;

-- Suppression ciblée d'un seul use case :
-- DROP SCHEMA IF EXISTS emlyon_use_cases.gdp        CASCADE;
-- DROP SCHEMA IF EXISTS emlyon_use_cases.superstore CASCADE;

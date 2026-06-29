-- db/fixtures/playwright_blocked_omim_job.sql
-- Idempotent seed: one completed omim_update job in "blocked" state.
--
-- Purpose
-- -------
-- Enables the admin.ontology-blocked-banner Playwright spec (test 1: admin
-- sees the persistent blocked banner on ManageAnnotations load).
--
-- How it works
-- ------------
-- The /api/admin/ontology/dictionary-status endpoint calls
-- ontology_dictionary_status() in api/functions/ontology-status-service.R,
-- which:
--   1. Reads async_jobs history for completed omim_update / force_apply_ontology rows.
--   2. Parses each row's result_json to extract result_status and pending_csv_path.
--   3. Marks the job as "fresh_blocked" when:
--         result_json.status === "blocked"
--         AND file at result_json.pending_csv_path exists AND is ≤ 48 h old.
--   4. Returns blocked=true + blocked_job_id when a fresh_blocked row is found.
--
-- The frontend ManageAnnotations.vue fetches this status on mount and, when
-- blocked is true, calls fetchOntologyJobResult(blocked_job_id) to populate
-- the OntologyBlockedState that drives the <BAlert v-if="blocked"> banner.
--
-- Requirements after inserting this row
-- --------------------------------------
-- The pending CSV file must exist inside the API container AND be ≤ 48 h old.
-- Run the seed helper:
--
--   docker exec sysndd_playwright_api mkdir -p /app/data/pending_ontology
--   docker cp /path/to/pending_ontology_update.2026-06-29.csv \
--     sysndd_playwright_api:/app/data/pending_ontology/pending_ontology_update.2026-06-29.csv
--
-- Or use the full automated seed script:
--   bash app/tests/e2e/fixtures/seed-blocked-ontology.sh
--
-- The pending_csv_path in result_json ("data/pending_ontology/...") is relative
-- to the API container working directory (/app), so the absolute path inside
-- the container is /app/data/pending_ontology/pending_ontology_update.2026-06-29.csv.
--
-- Idempotency
-- -----------
-- DELETE before INSERT — safe to run multiple times without violating uniqueness.
-- The active_request_hash generated column is NULL for status='completed'
-- (CASE falls to ELSE NULL), so the UNIQUE KEY on (job_type, active_request_hash)
-- is not violated regardless of how many completed rows exist.

DELETE FROM async_jobs
WHERE job_id = 'a7f3c8e2-1b4d-4e9f-a0b2-3c5d6e7f8a9b';

INSERT INTO async_jobs (
    job_id,
    job_type,
    queue_name,
    priority,
    status,
    request_hash,
    request_payload_json,
    submitted_by,
    submitted_at,
    scheduled_at,
    completed_at,
    attempt_count,
    max_attempts,
    result_json
) VALUES (
    'a7f3c8e2-1b4d-4e9f-a0b2-3c5d6e7f8a9b',
    'omim_update',
    'default',
    100,
    'completed',
    -- 64-character hex request_hash (CHAR(64) NOT NULL).
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    '{}',
    NULL,   -- submitted_by: FK to user(user_id), nullable
    NOW(6),
    NOW(6),
    NOW(6),
    1,  -- attempt_count
    1,  -- max_attempts
    -- result_json must contain:
    --   status           "blocked"  — triggers the banner
    --   pending_csv_path path relative to /app inside the API container
    --   critical_count   drives the red badge in OntologyAnnotationsCard
    --   auto_fixable_count drives the blue badge
    --   additive_applied read by derive_ontology_dictionary_status for out$additive_applied
    --   total_affected   exposed via OntologyBlockedState to the frontend
    --   critical_entities array shown in the BTable inside the banner alert
    --   auto_fixes       empty array (no auto-fixable remappings in this fixture)
    '{"status":"blocked","pending_csv_path":"data/pending_ontology/pending_ontology_update.2026-06-29.csv","critical_count":5,"auto_fixable_count":1,"additive_applied":12,"total_affected":18,"critical_entities":[{"disease_ontology_id_version":"OMIM:111111","disease_ontology_name":"Example NDD","hgnc_id":"HGNC:1","hpo_mode_of_inheritance_term":"Autosomal dominant"}],"auto_fixes":[]}'
);

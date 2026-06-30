-- db/migrations/037_add_analysis_snapshot_validation.sql
-- Partition-level cluster-validation metrics + human-facing DB release label on snapshots.
ALTER TABLE analysis_snapshot_manifest
  ADD COLUMN validation_json    JSON         DEFAULT NULL,
  ADD COLUMN db_release_version VARCHAR(64)  DEFAULT NULL,
  ADD COLUMN db_release_commit  VARCHAR(64)  DEFAULT NULL;

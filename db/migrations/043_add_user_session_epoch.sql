-- Migration 043: add user.session_epoch for revocable, role-current token refresh (#535 P0-2)
--
-- Every issued JWT carries the user's session_epoch as a `sepoch` claim. auth_refresh() rejects a
-- token whose sepoch != the user's current session_epoch. Privilege/state mutations increment the
-- epoch in the same statement, so demotion/deactivation/password-change/role-change immediately
-- revoke outstanding refresh capability. Additive, idempotent (restore-drift safe).
SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user' AND COLUMN_NAME = 'session_epoch'
);
SET @ddl := IF(@col_exists = 0,
  'ALTER TABLE `user` ADD COLUMN `session_epoch` INT NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Migration 056: add last_used_at to table_hash for LRU pruning (#670)
--
-- Enables pruning stale hashed filter payloads while retaining frequently-accessed
-- search presets regardless of entry_date.
SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'table_hash' AND COLUMN_NAME = 'last_used_at'
);
SET @ddl := IF(@col_exists = 0,
  'ALTER TABLE `table_hash` ADD COLUMN `last_used_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, ADD INDEX `idx_table_hash_last_used` (`last_used_at`)',
  'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

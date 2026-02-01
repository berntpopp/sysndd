-- Migration: 008_hgnc_symbol_lookup
-- Description: Create normalized symbol lookup table for fast HGNC resolution
-- Performance fix for comparisons update job (reduces O(n*m) to O(n) with index)

-- Create normalized lookup table that explodes pipe-separated symbols into rows
-- Using utf8mb3 to match non_alt_loci_set charset
CREATE TABLE IF NOT EXISTS hgnc_symbol_lookup (
    id INT AUTO_INCREMENT PRIMARY KEY,
    lookup_symbol VARCHAR(50) NOT NULL,
    hgnc_id VARCHAR(10) NOT NULL,
    symbol_type ENUM('current', 'previous', 'alias') NOT NULL,
    INDEX idx_lookup_symbol (lookup_symbol),
    INDEX idx_hgnc_id (hgnc_id),
    FOREIGN KEY (hgnc_id) REFERENCES non_alt_loci_set(hgnc_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

-- Add index on non_alt_loci_set.symbol for direct lookups (if not exists)
-- Using CREATE INDEX with IF NOT EXISTS syntax (MySQL 8.0.29+)
SET @index_exists = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.STATISTICS
                     WHERE table_schema = DATABASE()
                     AND table_name = 'non_alt_loci_set'
                     AND index_name = 'idx_symbol');
SET @sql = IF(@index_exists = 0,
              'ALTER TABLE non_alt_loci_set ADD INDEX idx_symbol (symbol)',
              'SELECT "Index already exists"');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Populate lookup table with current symbols
INSERT INTO hgnc_symbol_lookup (lookup_symbol, hgnc_id, symbol_type)
SELECT UPPER(symbol), hgnc_id, 'current'
FROM non_alt_loci_set
WHERE symbol IS NOT NULL AND symbol != '';

-- Populate with previous symbols (exploding pipe-separated values)
-- Using recursive CTE (MySQL 8.0+) to split pipe-delimited values
INSERT INTO hgnc_symbol_lookup (lookup_symbol, hgnc_id, symbol_type)
WITH RECURSIVE split_prev AS (
    SELECT
        hgnc_id,
        TRIM(SUBSTRING_INDEX(prev_symbol, '|', 1)) AS prev_sym,
        CASE
            WHEN LOCATE('|', prev_symbol) > 0
            THEN SUBSTRING(prev_symbol, LOCATE('|', prev_symbol) + 1)
            ELSE NULL
        END AS remaining
    FROM non_alt_loci_set
    WHERE prev_symbol IS NOT NULL AND prev_symbol != ''

    UNION ALL

    SELECT
        hgnc_id,
        TRIM(SUBSTRING_INDEX(remaining, '|', 1)) AS prev_sym,
        CASE
            WHEN LOCATE('|', remaining) > 0
            THEN SUBSTRING(remaining, LOCATE('|', remaining) + 1)
            ELSE NULL
        END AS remaining
    FROM split_prev
    WHERE remaining IS NOT NULL AND remaining != ''
)
SELECT UPPER(prev_sym), hgnc_id, 'previous'
FROM split_prev
WHERE prev_sym IS NOT NULL AND prev_sym != '';

-- Populate with alias symbols (exploding pipe-separated values)
INSERT INTO hgnc_symbol_lookup (lookup_symbol, hgnc_id, symbol_type)
WITH RECURSIVE split_alias AS (
    SELECT
        hgnc_id,
        TRIM(SUBSTRING_INDEX(alias_symbol, '|', 1)) AS alias_sym,
        CASE
            WHEN LOCATE('|', alias_symbol) > 0
            THEN SUBSTRING(alias_symbol, LOCATE('|', alias_symbol) + 1)
            ELSE NULL
        END AS remaining
    FROM non_alt_loci_set
    WHERE alias_symbol IS NOT NULL AND alias_symbol != ''

    UNION ALL

    SELECT
        hgnc_id,
        TRIM(SUBSTRING_INDEX(remaining, '|', 1)) AS alias_sym,
        CASE
            WHEN LOCATE('|', remaining) > 0
            THEN SUBSTRING(remaining, LOCATE('|', remaining) + 1)
            ELSE NULL
        END AS remaining
    FROM split_alias
    WHERE remaining IS NOT NULL AND remaining != ''
)
SELECT UPPER(alias_sym), hgnc_id, 'alias'
FROM split_alias
WHERE alias_sym IS NOT NULL AND alias_sym != '';

-- Migration 011: Add indexes to logging table for efficient filtering
--
-- Adds indexes to support database-side filtering for the ViewLogs endpoint.
-- Without these indexes, MySQL performs full table scans which become slow
-- as the table grows to 1M+ rows.
--
-- Indexes created:
-- 1. idx_logging_timestamp - Single-column index for date range queries
-- 2. idx_logging_status - Single-column index for status filtering
-- 3. idx_logging_path - Prefix index (100 chars) for path prefix filtering
-- 4. idx_logging_timestamp_status - Composite index for combined filtering
-- 5. idx_logging_id_desc_status - Composite index for paginated filtered queries
--
-- Uses CREATE INDEX IF NOT EXISTS (MySQL 8.0.19+) for idempotency.

-- IDX-01: Single-column index on timestamp for date range queries
-- Enables efficient: WHERE timestamp BETWEEN ? AND ?
CREATE INDEX IF NOT EXISTS idx_logging_timestamp ON logging(timestamp);

-- IDX-02: Single-column index on status for status filtering
-- Enables efficient: WHERE status = 200, WHERE status >= 400
CREATE INDEX IF NOT EXISTS idx_logging_status ON logging(status);

-- IDX-03: Prefix index on path for path prefix filtering
-- Uses path(100) prefix since path is TEXT type (full-length index too large)
-- Enables efficient: WHERE path LIKE '/api/v1/%'
CREATE INDEX IF NOT EXISTS idx_logging_path ON logging(path(100));

-- IDX-04: Composite index on (timestamp, status) for combined filtering
-- Column order: timestamp first (higher cardinality)
-- Enables efficient: WHERE timestamp BETWEEN ? AND ? AND status = ?
CREATE INDEX IF NOT EXISTS idx_logging_timestamp_status ON logging(timestamp, status);

-- IDX-05: Composite index on (id DESC, status) for paginated filtered queries
-- Enables efficient: SELECT ... WHERE status = ? ORDER BY id DESC LIMIT ? OFFSET ?
CREATE INDEX IF NOT EXISTS idx_logging_id_desc_status ON logging(id DESC, status);

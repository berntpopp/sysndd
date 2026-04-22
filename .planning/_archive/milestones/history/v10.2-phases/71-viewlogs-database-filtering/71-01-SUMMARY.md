---
phase: 71
plan: 01
subsystem: database
tags: [mysql, indexes, logging, performance]

dependency-graph:
  requires: []
  provides: [logging-indexes]
  affects: [71-02, 71-03, 71-04]

tech-stack:
  added: []
  patterns: [prefix-index, composite-index, desc-index]

key-files:
  created:
    - db/migrations/011_logging_indexes.sql
  modified: []

decisions:
  - id: PATH_PREFIX_LENGTH
    choice: "100 characters"
    rationale: "Sufficient for typical API paths while avoiding key length limits"
  - id: COMPOSITE_ORDER
    choice: "timestamp before status"
    rationale: "Higher cardinality column first for better selectivity"
  - id: DESC_INDEX
    choice: "id DESC for pagination"
    rationale: "Matches ORDER BY id DESC pattern in paginated queries"

metrics:
  duration: "~1 min"
  completed: "2026-02-03"
---

# Phase 71 Plan 01: Logging Database Indexes Summary

**One-liner:** MySQL indexes for efficient logging table filtering - timestamp, status, path prefix, and composite indexes for ViewLogs endpoint optimization.

## What Was Built

Created database migration `011_logging_indexes.sql` that adds 5 indexes to the `logging` table:

| Index | Type | Columns | Use Case |
|-------|------|---------|----------|
| idx_logging_timestamp | Single | timestamp | Date range queries |
| idx_logging_status | Single | status | HTTP status filtering |
| idx_logging_path | Prefix(100) | path | API path prefix filtering |
| idx_logging_timestamp_status | Composite | timestamp, status | Combined date+status filter |
| idx_logging_id_desc_status | Composite | id DESC, status | Paginated filtered queries |

## Key Implementation Details

### Prefix Index for TEXT Column
- `path` column is TEXT type (variable length, potentially large)
- Full TEXT index would exceed MySQL key length limits
- Used `path(100)` prefix index - covers typical API paths like `/api/v1/entities/123`
- Supports `WHERE path LIKE '/api/v1/%'` prefix queries

### Composite Index Column Order
- `(timestamp, status)` - timestamp first because it has higher cardinality
- MySQL can use leftmost prefix: queries on timestamp alone will use this index
- Combined queries benefit from both columns in single index scan

### Descending Index for Pagination
- `(id DESC, status)` enables efficient `ORDER BY id DESC LIMIT N OFFSET M`
- Without DESC index, MySQL sorts results after fetching (slow for large offsets)
- With DESC index, rows are already ordered in storage

### Idempotency
- All statements use `CREATE INDEX IF NOT EXISTS` (MySQL 8.0.19+)
- Safe to run migration multiple times
- No stored procedure complexity needed

## Task Completion

| Task | Description | Commit | Status |
|------|-------------|--------|--------|
| 1 | Create logging indexes migration file | 6987811c | Done |
| 2 | Verify migration file syntax | - | Done (verification only) |

## Deviations from Plan

None - plan executed exactly as written.

## Files Changed

```
db/migrations/011_logging_indexes.sql (created)
```

## Requirements Satisfied

- [x] IDX-01: Single-column index on timestamp
- [x] IDX-02: Single-column index on status
- [x] IDX-03: Prefix index on path(100)
- [x] IDX-04: Composite index on timestamp + status
- [x] IDX-05: Composite index on id DESC + status

## Next Phase Readiness

**Phase 71 Plan 02 (Query Builder Functions)** can now proceed:
- Indexes are defined and ready for migration runner
- SQL patterns documented in migration comments
- Query builder can reference these indexes for EXPLAIN validation

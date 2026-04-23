-- Migration: 019_redact_logged_query_strings
-- Description: One-shot scrub of persisted query strings in the logging table

UPDATE logging
SET query = '[redacted]'
WHERE query IS NOT NULL
  AND query <> ''
  AND query <> '-'
  AND query <> '[redacted]';

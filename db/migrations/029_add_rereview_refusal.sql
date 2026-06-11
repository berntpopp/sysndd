-- Migration 029: Add re-reviewer refusal state to re_review_entity_connect
--
-- Issue #54: let a re-reviewer DECLINE/REFUSE a re-review item on a
-- particularly complex or out-of-scope entry, flagging it for specialist /
-- curator attention instead of forcing a review.
--
-- Refusal is a distinct state, NOT "approved" and NOT "rejected":
--   * re_review_refused        -- 1 when the re-reviewer declined the item
--   * re_review_refusal_comment -- optional free-text reason the reviewer gives
--   * re_review_refused_user_id -- the re-reviewer who declined (FK -> user)
--   * re_review_refused_date    -- when the refusal was recorded (UTC)
--
-- A refused item leaves the reviewer's active queue and the curator approve
-- queue, and surfaces in a dedicated "refused / needs specialist" curator
-- view (re_review table endpoint `refused` mode). It never changes the
-- curated SysNDD status or review classification.
--
-- Idempotent: a stored procedure guards each ADD COLUMN / ADD FOREIGN KEY so
-- re-running the migration is safe (mirrors migration 002's pattern).

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS migrate_029_rereview_refusal()
BEGIN
    -- re_review_refused flag
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 're_review_entity_connect'
          AND COLUMN_NAME = 're_review_refused'
    ) THEN
        ALTER TABLE re_review_entity_connect
            ADD COLUMN re_review_refused TINYINT NOT NULL DEFAULT 0
            AFTER re_review_approved;
    END IF;

    -- re_review_refusal_comment (optional reviewer-supplied reason)
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 're_review_entity_connect'
          AND COLUMN_NAME = 're_review_refusal_comment'
    ) THEN
        ALTER TABLE re_review_entity_connect
            ADD COLUMN re_review_refusal_comment VARCHAR(1000) NULL DEFAULT NULL
            AFTER re_review_refused;
    END IF;

    -- re_review_refused_user_id (who declined)
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 're_review_entity_connect'
          AND COLUMN_NAME = 're_review_refused_user_id'
    ) THEN
        ALTER TABLE re_review_entity_connect
            ADD COLUMN re_review_refused_user_id INT NULL DEFAULT NULL
            AFTER re_review_refusal_comment;
    END IF;

    -- re_review_refused_date (when declined)
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 're_review_entity_connect'
          AND COLUMN_NAME = 're_review_refused_date'
    ) THEN
        ALTER TABLE re_review_entity_connect
            ADD COLUMN re_review_refused_date DATETIME NULL DEFAULT NULL
            AFTER re_review_refused_user_id;
    END IF;

    -- Index the flag for the curator "refused" surface query.
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.STATISTICS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 're_review_entity_connect'
          AND INDEX_NAME = 'idx_re_review_refused'
    ) THEN
        ALTER TABLE re_review_entity_connect
            ADD INDEX idx_re_review_refused (re_review_refused);
    END IF;

    -- Foreign key on the refusing user (named so we can guard re-runs).
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 're_review_entity_connect'
          AND CONSTRAINT_NAME = 're_review_entity_connect_refused_user_fk'
          AND CONSTRAINT_TYPE = 'FOREIGN KEY'
    ) THEN
        ALTER TABLE re_review_entity_connect
            ADD CONSTRAINT re_review_entity_connect_refused_user_fk
            FOREIGN KEY (re_review_refused_user_id) REFERENCES user (user_id);
    END IF;
END //

CALL migrate_029_rereview_refusal() //

DROP PROCEDURE IF EXISTS migrate_029_rereview_refusal //

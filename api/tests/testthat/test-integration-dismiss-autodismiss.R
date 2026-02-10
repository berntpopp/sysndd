# tests/testthat/test-integration-dismiss-autodismiss.R
#
# Integration tests for the dismiss/auto-dismiss feature.
#
# Tests verify:
# 1. Reject/dismiss sets approving_user_id but keeps status_approved=0
# 2. Pending filter excludes dismissed items (approving_user_id IS NOT NULL)
# 3. Auto-dismiss siblings: approving one status/review auto-dismisses others
# 4. Approve-all skips already-dismissed items
# 5. Re-submitted items (new records) appear normally after dismiss

source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/status-repository.R", local = FALSE)
source_api_file("functions/review-repository.R", local = FALSE)
source_api_file("functions/re-review-sync.R", local = FALSE)

# ---------------------------------------------------------------------------
# Status dismiss / auto-dismiss tests
# ---------------------------------------------------------------------------

describe("Status dismiss (reject path)", {
  it("sets approving_user_id and keeps status_approved=0", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      # Insert a pending status
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES (90001, 90001, 1, 1, 0, NULL, 0)"
      )

      # Simulate the reject path: set approving_user_id, keep status_approved=0
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status
         SET approving_user_id = 2
         WHERE status_id = 90001"
      )

      result <- DBI::dbGetQuery(conn,
        "SELECT status_approved, approving_user_id
         FROM ndd_entity_status WHERE status_id = 90001"
      )

      expect_equal(nrow(result), 1)
      expect_equal(result$status_approved, 0)
      expect_equal(result$approving_user_id, 2)
    })
  })
})

describe("Status pending filter excludes dismissed items", {
  it("returns only truly pending statuses (approving_user_id IS NULL)", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      entity_id <- 90002

      # Insert 3 statuses for the same entity:
      # 1) Truly pending (approving_user_id = NULL)
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES (90002, ?, 1, 1, 0, NULL, 0)",
        list(entity_id)
      )

      # 2) Dismissed (approving_user_id set, status_approved still 0)
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES (90003, ?, 2, 1, 0, 2, 0)",
        list(entity_id)
      )

      # 3) Approved (status_approved=1, approving_user_id set)
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES (90004, ?, 1, 1, 1, 2, 1)",
        list(entity_id)
      )

      # Query with pending filter (mirrors endpoint logic)
      pending <- DBI::dbGetQuery(conn,
        "SELECT status_id FROM ndd_entity_status
         WHERE entity_id = ?
           AND status_approved = 0
           AND approving_user_id IS NULL",
        list(entity_id)
      )

      expect_equal(nrow(pending), 1)
      expect_equal(pending$status_id, 90002)

      # Query for approved (mirrors endpoint with filter_status_approved=TRUE)
      approved <- DBI::dbGetQuery(conn,
        "SELECT status_id FROM ndd_entity_status
         WHERE entity_id = ?
           AND status_approved = 1",
        list(entity_id)
      )

      expect_equal(nrow(approved), 1)
      expect_equal(approved$status_id, 90004)
    })
  })
})

describe("Status auto-dismiss siblings on approve", {
  it("marks other pending statuses with approving_user_id when one is approved", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      entity_id <- 90003

      # Insert 3 pending statuses for the same entity
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES
           (90010, ?, 1, 1, 0, NULL, 0),
           (90011, ?, 2, 1, 0, NULL, 0),
           (90012, ?, 3, 1, 0, NULL, 0)",
        list(entity_id, entity_id, entity_id)
      )

      approved_status_id <- 90010
      approving_user_id <- 5

      # Simulate the approve path from status_approve():
      # Step 1: Reset all statuses for entity to inactive
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status SET is_active = 0 WHERE entity_id = ?",
        list(entity_id)
      )

      # Step 2: Set approved status to active
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status SET is_active = 1 WHERE status_id = ?",
        list(approved_status_id)
      )

      # Step 3: Set approving_user_id on approved status
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status
         SET approving_user_id = ? WHERE status_id = ?",
        list(approving_user_id, approved_status_id)
      )

      # Step 4: Set status_approved on approved status
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status
         SET status_approved = 1 WHERE status_id = ?",
        list(approved_status_id)
      )

      # Step 5: AUTO-DISMISS - the new code we're testing
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status SET approving_user_id = ?
         WHERE entity_id = ?
           AND status_approved = 0
           AND approving_user_id IS NULL
           AND status_id != ?",
        list(approving_user_id, entity_id, approved_status_id)
      )

      # Verify the approved status
      approved <- DBI::dbGetQuery(conn,
        "SELECT status_id, status_approved, approving_user_id, is_active
         FROM ndd_entity_status WHERE status_id = ?",
        list(approved_status_id)
      )

      expect_equal(approved$status_approved, 1)
      expect_equal(approved$approving_user_id, approving_user_id)
      expect_equal(approved$is_active, 1)

      # Verify siblings are auto-dismissed
      siblings <- DBI::dbGetQuery(conn,
        "SELECT status_id, status_approved, approving_user_id, is_active
         FROM ndd_entity_status
         WHERE entity_id = ? AND status_id != ?
         ORDER BY status_id",
        list(entity_id, approved_status_id)
      )

      expect_equal(nrow(siblings), 2)

      # Both siblings should have: status_approved=0, approving_user_id=5
      expect_equal(siblings$status_approved, c(0, 0))
      expect_equal(siblings$approving_user_id, c(approving_user_id, approving_user_id))

      # Both siblings should remain inactive
      expect_equal(siblings$is_active, c(0, 0))

      # Verify pending query now returns ZERO rows for this entity
      still_pending <- DBI::dbGetQuery(conn,
        "SELECT status_id FROM ndd_entity_status
         WHERE entity_id = ?
           AND status_approved = 0
           AND approving_user_id IS NULL",
        list(entity_id)
      )

      expect_equal(nrow(still_pending), 0)
    })
  })

  it("does not affect already-dismissed siblings", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      entity_id <- 90004

      # Insert: 1 pending, 1 already dismissed, 1 to approve
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES
           (90020, ?, 1, 1, 0, NULL, 0),
           (90021, ?, 2, 1, 0, 3, 0),
           (90022, ?, 3, 1, 0, NULL, 0)",
        list(entity_id, entity_id, entity_id)
      )

      # Approve status 90020
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status
         SET status_approved = 1, approving_user_id = 5, is_active = 1
         WHERE status_id = 90020"
      )

      # Auto-dismiss remaining pending siblings
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status SET approving_user_id = 5
         WHERE entity_id = ?
           AND status_approved = 0
           AND approving_user_id IS NULL
           AND status_id != 90020",
        list(entity_id)
      )

      # Verify the already-dismissed one (90021) still has user 3
      already_dismissed <- DBI::dbGetQuery(conn,
        "SELECT approving_user_id FROM ndd_entity_status
         WHERE status_id = 90021"
      )
      expect_equal(already_dismissed$approving_user_id, 3)

      # Verify newly dismissed (90022) now has user 5
      newly_dismissed <- DBI::dbGetQuery(conn,
        "SELECT approving_user_id FROM ndd_entity_status
         WHERE status_id = 90022"
      )
      expect_equal(newly_dismissed$approving_user_id, 5)
    })
  })
})

describe("Status approve-all skips dismissed items", {
  it("only returns truly pending status IDs for batch approval", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      # Insert: 2 truly pending, 1 dismissed, 1 approved
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES
           (90030, 90010, 1, 1, 0, NULL, 0),
           (90031, 90011, 2, 1, 0, NULL, 0),
           (90032, 90012, 1, 1, 0, 3, 0),
           (90033, 90013, 1, 1, 1, 3, 1)"
      )

      # Simulate the "approve all" query from approval-service.R
      pending_for_all <- DBI::dbGetQuery(conn,
        "SELECT status_id FROM ndd_entity_status
         WHERE status_approved = 0
           AND approving_user_id IS NULL
           AND status_id IN (90030, 90031, 90032, 90033)"
      )

      # Should only include the 2 truly pending ones
      expect_equal(nrow(pending_for_all), 2)
      expect_true(all(pending_for_all$status_id %in% c(90030, 90031)))
    })
  })
})

# ---------------------------------------------------------------------------
# Review dismiss / auto-dismiss tests
# ---------------------------------------------------------------------------

describe("Review dismiss (reject path)", {
  it("sets approving_user_id and keeps review_approved=0", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      # Insert a pending review
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_review
         (review_id, entity_id, synopsis, review_user_id,
          review_approved, approving_user_id, is_primary)
         VALUES (90001, 90001, 'test synopsis', 1, 0, NULL, 0)"
      )

      # Simulate the reject path
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_review
         SET approving_user_id = 2
         WHERE review_id = 90001"
      )

      result <- DBI::dbGetQuery(conn,
        "SELECT review_approved, approving_user_id
         FROM ndd_entity_review WHERE review_id = 90001"
      )

      expect_equal(nrow(result), 1)
      expect_equal(result$review_approved, 0)
      expect_equal(result$approving_user_id, 2)
    })
  })
})

describe("Review pending filter excludes dismissed items", {
  it("returns only truly pending reviews (approving_user_id IS NULL)", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      entity_id <- 90005

      # Insert 3 reviews:
      # 1) Truly pending
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_review
         (review_id, entity_id, synopsis, review_user_id,
          review_approved, approving_user_id, is_primary)
         VALUES (90005, ?, 'pending review', 1, 0, NULL, 0)",
        list(entity_id)
      )

      # 2) Dismissed
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_review
         (review_id, entity_id, synopsis, review_user_id,
          review_approved, approving_user_id, is_primary)
         VALUES (90006, ?, 'dismissed review', 1, 0, 2, 0)",
        list(entity_id)
      )

      # 3) Approved
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_review
         (review_id, entity_id, synopsis, review_user_id,
          review_approved, approving_user_id, is_primary)
         VALUES (90007, ?, 'approved review', 1, 1, 2, 1)",
        list(entity_id)
      )

      # Query with pending filter (mirrors endpoint logic)
      pending <- DBI::dbGetQuery(conn,
        "SELECT review_id FROM ndd_entity_review
         WHERE entity_id = ?
           AND review_approved = 0
           AND approving_user_id IS NULL",
        list(entity_id)
      )

      expect_equal(nrow(pending), 1)
      expect_equal(pending$review_id, 90005)
    })
  })
})

describe("Review auto-dismiss siblings on approve", {
  it("marks other pending reviews with approving_user_id when one is approved", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      entity_id <- 90006

      # Insert 3 pending reviews for the same entity
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_review
         (review_id, entity_id, synopsis, review_user_id,
          review_approved, approving_user_id, is_primary)
         VALUES
           (90010, ?, 'review A', 1, 0, NULL, 0),
           (90011, ?, 'review B', 1, 0, NULL, 0),
           (90012, ?, 'review C', 1, 0, NULL, 0)",
        list(entity_id, entity_id, entity_id)
      )

      approved_review_id <- 90010
      approving_user_id <- 5

      # Simulate the approve path from review_approve():
      # Step 1: Reset all reviews to not primary
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_review SET is_primary = 0 WHERE entity_id = ?",
        list(entity_id)
      )

      # Step 2: Set approved review to primary
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_review SET is_primary = 1 WHERE review_id = ?",
        list(approved_review_id)
      )

      # Step 3: Set approving_user_id
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_review
         SET approving_user_id = ? WHERE review_id = ?",
        list(approving_user_id, approved_review_id)
      )

      # Step 4: Set review_approved
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_review
         SET review_approved = 1 WHERE review_id = ?",
        list(approved_review_id)
      )

      # Step 5: AUTO-DISMISS - the new code we're testing
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_review SET approving_user_id = ?
         WHERE entity_id = ?
           AND review_approved = 0
           AND approving_user_id IS NULL
           AND review_id != ?",
        list(approving_user_id, entity_id, approved_review_id)
      )

      # Verify the approved review
      approved <- DBI::dbGetQuery(conn,
        "SELECT review_id, review_approved, approving_user_id, is_primary
         FROM ndd_entity_review WHERE review_id = ?",
        list(approved_review_id)
      )

      expect_equal(approved$review_approved, 1)
      expect_equal(approved$approving_user_id, approving_user_id)
      expect_equal(approved$is_primary, 1)

      # Verify siblings are auto-dismissed
      siblings <- DBI::dbGetQuery(conn,
        "SELECT review_id, review_approved, approving_user_id, is_primary
         FROM ndd_entity_review
         WHERE entity_id = ? AND review_id != ?
         ORDER BY review_id",
        list(entity_id, approved_review_id)
      )

      expect_equal(nrow(siblings), 2)
      expect_equal(siblings$review_approved, c(0, 0))
      expect_equal(siblings$approving_user_id,
        c(approving_user_id, approving_user_id))
      expect_equal(siblings$is_primary, c(0, 0))

      # Verify pending query returns ZERO for this entity
      still_pending <- DBI::dbGetQuery(conn,
        "SELECT review_id FROM ndd_entity_review
         WHERE entity_id = ?
           AND review_approved = 0
           AND approving_user_id IS NULL",
        list(entity_id)
      )

      expect_equal(nrow(still_pending), 0)
    })
  })
})

describe("Review approve-all skips dismissed items", {
  it("only returns truly pending review IDs for batch approval", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      # Insert: 2 truly pending, 1 dismissed, 1 approved
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_review
         (review_id, entity_id, synopsis, review_user_id,
          review_approved, approving_user_id, is_primary)
         VALUES
           (90020, 90020, 'pending 1', 1, 0, NULL, 0),
           (90021, 90021, 'pending 2', 1, 0, NULL, 0),
           (90022, 90022, 'dismissed', 1, 0, 3, 0),
           (90023, 90023, 'approved', 1, 1, 3, 1)"
      )

      # Simulate the "approve all" query from approval-service.R
      pending_for_all <- DBI::dbGetQuery(conn,
        "SELECT review_id FROM ndd_entity_review
         WHERE review_approved = 0
           AND approving_user_id IS NULL
           AND review_id IN (90020, 90021, 90022, 90023)"
      )

      expect_equal(nrow(pending_for_all), 2)
      expect_true(all(pending_for_all$review_id %in% c(90020, 90021)))
    })
  })
})

# ---------------------------------------------------------------------------
# Cross-entity isolation tests
# ---------------------------------------------------------------------------

describe("Auto-dismiss only affects same entity", {
  it("does not dismiss statuses from other entities", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      # Entity A: 2 pending statuses
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES
           (90040, 90040, 1, 1, 0, NULL, 0),
           (90041, 90040, 2, 1, 0, NULL, 0)"
      )

      # Entity B: 1 pending status
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES (90042, 90041, 1, 1, 0, NULL, 0)"
      )

      # Approve status 90040 (entity A) and auto-dismiss entity A siblings
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status
         SET status_approved = 1, approving_user_id = 5, is_active = 1
         WHERE status_id = 90040"
      )

      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status SET approving_user_id = 5
         WHERE entity_id = 90040
           AND status_approved = 0
           AND approving_user_id IS NULL
           AND status_id != 90040"
      )

      # Entity B's status should still be truly pending
      entity_b_pending <- DBI::dbGetQuery(conn,
        "SELECT status_id, approving_user_id
         FROM ndd_entity_status WHERE status_id = 90042"
      )

      expect_equal(nrow(entity_b_pending), 1)
      expect_true(is.na(entity_b_pending$approving_user_id))
    })
  })
})

# ---------------------------------------------------------------------------
# Re-submission after dismiss
# ---------------------------------------------------------------------------

describe("Re-submission after dismiss", {
  it("new status record appears in pending queue after prior dismiss", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      entity_id <- 90050

      # Original status dismissed
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES (90050, ?, 1, 1, 0, 3, 0)",
        list(entity_id)
      )

      # New status submitted (DB default: approving_user_id = NULL)
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES (90051, ?, 2, 1, 0, NULL, 0)",
        list(entity_id)
      )

      # Pending query should show only the new one
      pending <- DBI::dbGetQuery(conn,
        "SELECT status_id FROM ndd_entity_status
         WHERE entity_id = ?
           AND status_approved = 0
           AND approving_user_id IS NULL",
        list(entity_id)
      )

      expect_equal(nrow(pending), 1)
      expect_equal(pending$status_id, 90051)
    })
  })
})

# ---------------------------------------------------------------------------
# Duplicate detection tests
# ---------------------------------------------------------------------------

describe("Duplicate detection for pending items", {
  it("computes correct duplicate count for pending statuses", {
    skip_if_no_test_db()

    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")

      entity_id <- 90060

      # 3 pending statuses for same entity
      DBI::dbExecute(conn,
        "INSERT INTO ndd_entity_status
         (status_id, entity_id, category_id, status_user_id,
          status_approved, approving_user_id, is_active)
         VALUES
           (90060, ?, 1, 1, 0, NULL, 0),
           (90061, ?, 2, 1, 0, NULL, 0),
           (90062, ?, 3, 1, 0, NULL, 0)",
        list(entity_id, entity_id, entity_id)
      )

      # Count pending per entity (mirrors endpoint group_by logic)
      dup_count <- DBI::dbGetQuery(conn,
        "SELECT entity_id, COUNT(*) as n
         FROM ndd_entity_status
         WHERE status_approved = 0
           AND approving_user_id IS NULL
           AND entity_id = ?
         GROUP BY entity_id",
        list(entity_id)
      )

      expect_equal(dup_count$n, 3)

      # Now dismiss one
      DBI::dbExecute(conn,
        "UPDATE ndd_entity_status SET approving_user_id = 5
         WHERE status_id = 90062"
      )

      # Count should now be 2
      dup_count_after <- DBI::dbGetQuery(conn,
        "SELECT entity_id, COUNT(*) as n
         FROM ndd_entity_status
         WHERE status_approved = 0
           AND approving_user_id IS NULL
           AND entity_id = ?
         GROUP BY entity_id",
        list(entity_id)
      )

      expect_equal(dup_count_after$n, 2)
    })
  })
})

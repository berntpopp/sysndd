# tests/testthat/test-integration-rereview-sync.R
#
# Integration tests for re-review approval synchronization

source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/re-review-sync.R", local = FALSE)

test_that("sync_rereview_approval updates matching rows for review_ids", {
  skip_if_no_test_db()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    # Insert test re_review_entity_connect row
    DBI::dbExecute(conn,
      "INSERT INTO re_review_entity_connect
       (re_review_batch, entity_id, review_id, status_id, re_review_submitted, re_review_approved)
       VALUES (1, 999, 888, 777, 1, 0)"
    )

    # Call sync function
    sync_rereview_approval(
      review_ids = 888,
      approving_user_id = 1,
      conn = conn
    )

    # Verify re_review_approved is now 1
    result <- DBI::dbGetQuery(conn,
      "SELECT re_review_approved, approving_user_id FROM re_review_entity_connect WHERE review_id = 888"
    )

    expect_equal(nrow(result), 1)
    expect_equal(result$re_review_approved, 1)
    expect_equal(result$approving_user_id, 1)
  })
})

test_that("sync_rereview_approval updates matching rows for status_ids", {
  skip_if_no_test_db()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    # Insert test re_review_entity_connect row
    DBI::dbExecute(conn,
      "INSERT INTO re_review_entity_connect
       (re_review_batch, entity_id, review_id, status_id, re_review_submitted, re_review_approved)
       VALUES (2, 998, 887, 776, 1, 0)"
    )

    # Call sync function
    sync_rereview_approval(
      status_ids = 776,
      approving_user_id = 2,
      conn = conn
    )

    # Verify re_review_approved is now 1
    result <- DBI::dbGetQuery(conn,
      "SELECT re_review_approved, approving_user_id FROM re_review_entity_connect WHERE status_id = 776"
    )

    expect_equal(nrow(result), 1)
    expect_equal(result$re_review_approved, 1)
    expect_equal(result$approving_user_id, 2)
  })
})

test_that("sync_rereview_approval skips unsubmitted rows", {
  skip_if_no_test_db()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    # Insert test re_review_entity_connect row with re_review_submitted = 0
    DBI::dbExecute(conn,
      "INSERT INTO re_review_entity_connect
       (re_review_batch, entity_id, review_id, status_id, re_review_submitted, re_review_approved)
       VALUES (3, 997, 886, 775, 0, 0)"
    )

    # Call sync function
    sync_rereview_approval(
      review_ids = 886,
      approving_user_id = 3,
      conn = conn
    )

    # Verify re_review_approved is still 0
    result <- DBI::dbGetQuery(conn,
      "SELECT re_review_approved FROM re_review_entity_connect WHERE review_id = 886"
    )

    expect_equal(nrow(result), 1)
    expect_equal(result$re_review_approved, 0)
  })
})

test_that("sync_rereview_approval with NULL ids returns silently", {
  skip_if_no_test_db()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    # Should not throw error
    expect_silent(
      sync_rereview_approval(
        approving_user_id = 1,
        conn = conn
      )
    )
  })
})

test_that("sync_rereview_approval handles both review_ids and status_ids", {
  skip_if_no_test_db()

  with_test_db_transaction({
    conn <- getOption(".test_db_con")

    # Insert two test rows
    DBI::dbExecute(conn,
      "INSERT INTO re_review_entity_connect
       (re_review_batch, entity_id, review_id, status_id, re_review_submitted, re_review_approved)
       VALUES (4, 996, 885, 774, 1, 0)"
    )
    DBI::dbExecute(conn,
      "INSERT INTO re_review_entity_connect
       (re_review_batch, entity_id, review_id, status_id, re_review_submitted, re_review_approved)
       VALUES (5, 995, 884, 773, 1, 0)"
    )

    # Call sync function with both review_ids and status_ids
    sync_rereview_approval(
      review_ids = 885,
      status_ids = 773,
      approving_user_id = 4,
      conn = conn
    )

    # Verify both rows are updated
    result1 <- DBI::dbGetQuery(conn,
      "SELECT re_review_approved FROM re_review_entity_connect WHERE review_id = 885"
    )
    result2 <- DBI::dbGetQuery(conn,
      "SELECT re_review_approved FROM re_review_entity_connect WHERE status_id = 773"
    )

    expect_equal(result1$re_review_approved, 1)
    expect_equal(result2$re_review_approved, 1)
  })
})

# tests/testthat/helper-wait.R
# Event-based wait helpers for flake-free async assertions
#
# Replaces ad-hoc `Sys.sleep(N)` patterns in integration/E2E tests with
# helpers that poll a probe function and fail loudly on timeout (or on
# unexpected state change, for the "nothing should happen" case).
#
# Two public helpers:
#
#   wait_for(condition, timeout, ..., label, interval)
#     Poll `condition()` until it returns a truthy value. Return that value
#     on success. On timeout, stop() with a clear message naming the label,
#     the timeout, and the last observed probe value.
#
#   wait_stable(probe, duration, ..., label, interval, tolerate = NULL)
#     Poll `probe()` and assert it stays equal to the FIRST observed value
#     for `duration` seconds. Returns the stable value. On change, stop()
#     immediately with a clear message naming the label, the observed
#     transition, and the elapsed time.
#
# Design notes:
#   - Both helpers stop() on failure rather than testthat::fail() so they
#     work from inside helpers (helper-mailpit.R) that do not have a test
#     context, and so they surface as real errors in E2E tests instead of
#     silent failures.
#   - Default interval is 50ms — small enough to make "what the sleep was
#     masking" observable, large enough not to hammer the API/Mailpit.
#   - `label` is REQUIRED in practice (defaulted to a generic string only
#     so tests of the helper itself work): always pass a meaningful label
#     so timeout diagnostics are actionable.

#' Poll a condition until it is truthy or timeout elapses
#'
#' Event-based replacement for `Sys.sleep(N); stopifnot(condition())`.
#' Evaluates `condition()` on a tight interval and returns the condition's
#' value the moment it becomes truthy. On timeout, raises an error whose
#' message identifies the label, elapsed time, and last observed value.
#'
#' A value is considered "truthy" if it is non-NULL, has length > 0, and
#' `isTRUE(as.logical(value))` OR is any non-empty list / non-empty data
#' frame / non-NA single atomic TRUE. The common happy path — the caller
#' returns TRUE or a non-NULL object — is handled directly; the extended
#' list/data.frame handling supports "wait until the DB query returns a
#' non-empty row set" usage.
#'
#' @param condition Zero-arg function returning the value to test.
#' @param timeout Maximum seconds to wait (default 10).
#' @param label Human-readable description of what is being waited on;
#'   surfaces in the timeout error message.
#' @param interval Poll interval in seconds (default 0.05).
#' @return The value returned by `condition()` on the first truthy poll.
#' @examples
#' \dontrun{
#'   msg <- wait_for(
#'     function() {
#'       hits <- mailpit_search("user@example.com")
#'       if (!is.null(hits$total) && hits$total > 0) hits$messages[[1]] else NULL
#'     },
#'     timeout = 10,
#'     label = "mailpit message for user@example.com"
#'   )
#' }
wait_for <- function(
    condition,
    timeout = 10,
    label = "wait_for condition",
    interval = 0.05) {
  if (!is.function(condition)) {
    stop("wait_for: 'condition' must be a zero-arg function")
  }
  if (!is.numeric(timeout) || length(timeout) != 1 || timeout < 0) {
    stop("wait_for: 'timeout' must be a single non-negative number")
  }
  if (!is.numeric(interval) || length(interval) != 1 || interval <= 0) {
    stop("wait_for: 'interval' must be a single positive number")
  }

  start_time <- Sys.time()
  last_value <- NULL
  last_error <- NULL
  attempts <- 0L

  is_truthy <- function(v) {
    if (is.null(v)) return(FALSE)
    if (length(v) == 0) return(FALSE)
    if (is.data.frame(v)) return(nrow(v) > 0)
    if (is.list(v)) return(TRUE)
    if (is.logical(v) && length(v) == 1 && !is.na(v)) return(isTRUE(v))
    if (is.atomic(v)) return(TRUE)
    TRUE
  }

  repeat {
    attempts <- attempts + 1L
    value <- tryCatch(
      condition(),
      error = function(e) {
        last_error <<- e
        NULL
      }
    )
    last_value <- value
    if (is_truthy(value)) {
      return(value)
    }

    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    if (elapsed >= timeout) {
      diag <- paste0(
        "wait_for timeout after ", format(round(elapsed, 3), nsmall = 3),
        "s (limit ", timeout, "s, ", attempts, " polls) ",
        "while waiting for: ", label, ". ",
        "Last observed value: ", .wait_repr(last_value)
      )
      if (!is.null(last_error)) {
        diag <- paste0(
          diag, " Last error while polling: ",
          conditionMessage(last_error)
        )
      }
      stop(diag, call. = FALSE)
    }
    Sys.sleep(interval)
  }
}


#' Assert that a probe value remains stable for a duration
#'
#' Event-based replacement for `Sys.sleep(N); expect_equal(count, 0)`. Polls
#' `probe()` at the given interval; the first observation is treated as the
#' baseline. If any subsequent poll returns a value that is not `identical()`
#' to the baseline, this function fails immediately with a diagnostic naming
#' the observed transition. If the baseline holds for the full `duration`,
#' the baseline value is returned.
#'
#' Use this to replace sleeps that were masking "nothing should happen"
#' assertions — e.g. "no email should be sent", "count should still be zero".
#' The old pattern slept for N seconds and then checked once; this helper
#' catches the violation at the moment it occurs, which is both faster on
#' failure and more informative.
#'
#' @param probe Zero-arg function returning the value to monitor.
#' @param duration Seconds to require the value to remain stable (default 2).
#' @param label Human-readable description of what is being monitored.
#' @param interval Poll interval in seconds (default 0.1).
#' @param tolerate Optional function(old, new) returning TRUE if a transition
#'   should be tolerated (rarely needed). NULL means "any change fails".
#' @return The stable baseline value.
#' @examples
#' \dontrun{
#'   wait_stable(
#'     function() mailpit_message_count(),
#'     duration = 1,
#'     label = "mailpit inbox after invalid signup"
#'   )
#' }
wait_stable <- function(
    probe,
    duration = 2,
    label = "wait_stable probe",
    interval = 0.1,
    tolerate = NULL) {
  if (!is.function(probe)) {
    stop("wait_stable: 'probe' must be a zero-arg function")
  }
  if (!is.numeric(duration) || length(duration) != 1 || duration < 0) {
    stop("wait_stable: 'duration' must be a single non-negative number")
  }
  if (!is.numeric(interval) || length(interval) != 1 || interval <= 0) {
    stop("wait_stable: 'interval' must be a single positive number")
  }
  if (!is.null(tolerate) && !is.function(tolerate)) {
    stop("wait_stable: 'tolerate' must be NULL or a function(old, new)")
  }

  start_time <- Sys.time()
  baseline <- probe()

  repeat {
    Sys.sleep(interval)
    current <- probe()
    if (!identical(current, baseline)) {
      if (!is.null(tolerate) && isTRUE(tolerate(baseline, current))) {
        # Tolerated: update baseline and continue.
        baseline <- current
      } else {
        elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
        stop(
          "wait_stable violation after ",
          format(round(elapsed, 3), nsmall = 3), "s ",
          "(required stability window ", duration, "s) ",
          "while monitoring: ", label, ". ",
          "Baseline: ", .wait_repr(baseline),
          " -> observed: ", .wait_repr(current),
          call. = FALSE
        )
      }
    }
    elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    if (elapsed >= duration) {
      return(baseline)
    }
  }
}


# Internal: produce a short printable representation for diagnostics.
.wait_repr <- function(value) {
  if (is.null(value)) return("NULL")
  if (is.data.frame(value)) {
    return(paste0("<data.frame ", nrow(value), "x", ncol(value), ">"))
  }
  if (is.list(value)) {
    return(paste0("<list length ", length(value), ">"))
  }
  if (is.atomic(value) && length(value) == 1) {
    return(format(value))
  }
  if (is.atomic(value)) {
    head_vals <- utils::head(value, 3)
    tail_marker <- if (length(value) > 3) ", ..." else ""
    return(paste0(
      "<", class(value)[1], " length ", length(value), ": ",
      paste(format(head_vals), collapse = ", "), tail_marker, ">"
    ))
  }
  paste0("<", class(value)[1], ">")
}


# ---------------------------------------------------------------------------
# Self-tests for the helpers above. Guarded so they only run inside a
# testthat session (TESTTHAT=true is set by testthat::test_file()). Other
# test files can rely on wait_for / wait_stable being defined without
# re-running these smoke assertions.
# ---------------------------------------------------------------------------

if (identical(Sys.getenv("TESTTHAT"), "true")) {
  local({
    testthat::test_that("wait_for returns immediately on a truthy probe", {
      start <- Sys.time()
      result <- wait_for(function() TRUE, timeout = 5, label = "instant truthy")
      elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
      testthat::expect_true(isTRUE(result))
      testthat::expect_lt(elapsed, 0.5)
    })

    testthat::test_that("wait_for returns the condition value (not just TRUE)", {
      result <- wait_for(
        function() list(id = 42, name = "grin2b"),
        timeout = 1,
        label = "list return value"
      )
      testthat::expect_equal(result$id, 42)
      testthat::expect_equal(result$name, "grin2b")
    })

    testthat::test_that("wait_for polls until the condition becomes truthy", {
      counter <- 0L
      result <- wait_for(
        function() {
          counter <<- counter + 1L
          if (counter >= 3L) TRUE else NULL
        },
        timeout = 2,
        label = "counter probe",
        interval = 0.01
      )
      testthat::expect_true(isTRUE(result))
      testthat::expect_gte(counter, 3L)
    })

    testthat::test_that("wait_for fails loudly on timeout with a clear message", {
      start <- Sys.time()
      err <- tryCatch(
        wait_for(
          function() FALSE,
          timeout = 0.1,
          label = "always-false",
          interval = 0.02
        ),
        error = function(e) e
      )
      elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
      testthat::expect_s3_class(err, "error")
      testthat::expect_match(conditionMessage(err), "wait_for timeout")
      testthat::expect_match(conditionMessage(err), "always-false")
      testthat::expect_match(conditionMessage(err), "0.1")
      # Should give up soon after the timeout (allow generous slack).
      testthat::expect_lt(elapsed, 0.5)
    })

    testthat::test_that("wait_for surfaces probe errors in the timeout message", {
      err <- tryCatch(
        wait_for(
          function() stop("probe exploded"),
          timeout = 0.1,
          label = "error probe",
          interval = 0.02
        ),
        error = function(e) e
      )
      testthat::expect_s3_class(err, "error")
      testthat::expect_match(conditionMessage(err), "probe exploded")
    })

    testthat::test_that("wait_stable returns baseline when probe stays constant", {
      start <- Sys.time()
      result <- wait_stable(
        function() 0L,
        duration = 0.2,
        label = "zero probe",
        interval = 0.05
      )
      elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
      testthat::expect_equal(result, 0L)
      testthat::expect_gte(elapsed, 0.2)
    })

    testthat::test_that("wait_stable fails immediately when probe value changes", {
      counter <- 0L
      start <- Sys.time()
      err <- tryCatch(
        wait_stable(
          function() {
            counter <<- counter + 1L
            if (counter == 1L) 0L else 1L
          },
          duration = 5,
          label = "changing probe",
          interval = 0.01
        ),
        error = function(e) e
      )
      elapsed <- as.numeric(difftime(Sys.time(), start, units = "secs"))
      testthat::expect_s3_class(err, "error")
      testthat::expect_match(conditionMessage(err), "wait_stable violation")
      testthat::expect_match(conditionMessage(err), "changing probe")
      # Should fail long before the 5s duration.
      testthat::expect_lt(elapsed, 1)
    })
  })
}

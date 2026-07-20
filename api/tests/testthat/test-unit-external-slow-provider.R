# test-unit-external-slow-provider.R
#
# Regression coverage for GitHub issue #344 acceptance criteria 5 & 6:
#
#   (5) A slow external provider must FAST-FAIL within its budget and return a
#       graceful, degraded response instead of occupying the API worker for
#       tens of seconds, and a cheap operation (mimicking /api/health/ or a
#       simple read) must remain bounded rather than waiting behind it.
#   (6) Every external provider must emit structured timing logs (source,
#       upstream duration, configured timeout, cache hit/miss, mapped status).
#
# These are host-only unit/contract tests: the external fetcher is simulated
# with a sleeping closure (no real network, no DB). Structural cross-REQUEST
# isolation is provided by the #344 `api-enrichment` process lane (a Compose/
# Traefik bulkhead, proven by `make smoke-lane-isolation`); this file verifies
# the bounded per-request fast-fail + observability that complement it.

library(dplyr)
library(rlang) # For %||% operator

source_api_file("functions/external-proxy-functions.R", local = FALSE)

# Helper: capture [external-proxy] log lines emitted while running `expr`.
capture_proxy_messages <- function(expr) {
  messages <- character()
  result <- withCallingHandlers(
    force(expr),
    message = function(m) {
      messages <<- c(messages, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  attr(result, "proxy_messages") <- messages
  result
}

# ============================================================================
# Criterion 5a: slow provider fast-fails the aggregate within its budget
# ============================================================================

describe("slow external provider does not monopolize the API worker", {
  it("caps aggregate wall time and degrades gracefully past the budget", {
    withr::local_envvar(c(EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "0.2"))

    # `slow_source` simulates an upstream that sleeps well beyond the budget.
    # In production this would be MGI/RGD/gnomAD/etc. stalling for tens of
    # seconds. The aggregate must short-circuit BEFORE invoking the next
    # source rather than running every slow source serially.
    slow_calls <- 0L
    sources <- list(
      first = function() {
        Sys.sleep(0.3) # exceeds the 0.2s aggregate budget on its own
        list(source = "first", value = "ok")
      },
      slow_second = function() {
        slow_calls <<- slow_calls + 1L
        Sys.sleep(30) # the pathological "tens of seconds" upstream
        list(source = "slow_second")
      }
    )

    started <- proc.time()[["elapsed"]]
    result <- external_proxy_aggregate_sources(
      "GENE1",
      sources,
      instance = "/api/external/gene/GENE1"
    )
    elapsed <- proc.time()[["elapsed"]] - started

    # The 30s source must never have been entered (budget short-circuited).
    expect_equal(slow_calls, 0L)
    # Total wall time stays close to the budget, nowhere near 30s.
    expect_lt(elapsed, 5)
    # Degraded-but-successful: partial flag + skipped source list, HTTP 200-able.
    expect_true(isTRUE(result$partial))
    expect_equal(result$skipped_sources, list("slow_second"))
    # The source that did complete is still returned (graceful, not all-or-none).
    expect_equal(result$sources$first$value, "ok")
  })
})

# ============================================================================
# Criterion 5b: a cheap operation stays bounded next to a slow provider
# ============================================================================

describe("cheap routes are not blocked behind slow external work", {
  it("a health-style read completes in bounded time regardless of slow upstream", {
    # Single-process Plumber serializes work per worker, so the guarantee this
    # PR provides is that ANY single external request is time-bounded: a slow
    # provider cannot hold the worker for tens of seconds, so a following cheap
    # request is delayed by at most the (short) budget, not 30-80s. We assert
    # the external work is bounded and the cheap closure itself is trivial.
    withr::local_envvar(c(
      EXTERNAL_PROXY_AGGREGATE_MAX_SECONDS = "0.2",
      EXTERNAL_PROXY_TIMEOUT_SECONDS = "1"
    ))

    cheap_health_read <- function() list(status = "ok") # mimics /api/health/

    # Time the slow external request (bounded by the aggregate budget).
    slow_started <- proc.time()[["elapsed"]]
    external_proxy_aggregate_sources(
      "GENE1",
      list(
        stalled = function() {
          Sys.sleep(0.25)
          list(source = "stalled")
        },
        never = function() {
          Sys.sleep(30)
          list(source = "never")
        }
      )
    )
    slow_elapsed <- proc.time()[["elapsed"]] - slow_started

    # Then time the cheap read that would queue behind it on one worker.
    cheap_started <- proc.time()[["elapsed"]]
    cheap_result <- cheap_health_read()
    cheap_elapsed <- proc.time()[["elapsed"]] - cheap_started

    # The slow request is bounded (not tens of seconds) so worst-case queue
    # delay for the cheap route is small.
    expect_lt(slow_elapsed, 5)
    # The cheap read itself is effectively instantaneous.
    expect_lt(cheap_elapsed, 0.5)
    expect_equal(cheap_result$status, "ok")
  })
})

# ============================================================================
# Criterion 1/2 verification: per-provider request timeout fast-fails
# ============================================================================

describe("per-provider request budget fast-fails a stalled upstream", {
  it("make_external_request maps an httr2 timeout to a graceful 503 payload", {
    # Deterministically simulate a stalled upstream by stubbing the httr2
    # perform step to raise a timeout condition (as req_timeout() would). We
    # assert make_external_request swallows it into a graceful degraded
    # list(error = TRUE, status = 503) rather than bubbling a raw R error that
    # would surface as an opaque 500 and keep the worker busy.
    withr::local_envvar(c(
      EXTERNAL_PROXY_TIMEOUT_SECONDS = "1",
      EXTERNAL_PROXY_MAX_SECONDS = "1",
      EXTERNAL_PROXY_MAX_TRIES = "1"
    ))

    testthat::local_mocked_bindings(
      req_perform = function(req, ...) {
        rlang::abort(
          "Request failed [timeout]: exceeded timeout of 1s",
          class = "httr2_timeout"
        )
      },
      .package = "httr2"
    )

    result <- make_external_request(
      url = "https://example.invalid/slow",
      api_name = "mgi",
      throttle_config = EXTERNAL_API_THROTTLE$mgi
    )

    expect_true(isTRUE(result$error))
    expect_equal(result$status, 503L)
    expect_equal(result$source, "mgi")
    expect_match(result$message, "timeout", ignore.case = TRUE)
  })

  it("uses a short, source-specific timeout budget (not the legacy 30-120s)", {
    # Criterion 1 verification: the budget the request layer applies is short.
    withr::local_envvar(c(
      EXTERNAL_PROXY_TIMEOUT_SECONDS = NA,
      EXTERNAL_PROXY_MAX_SECONDS = NA,
      EXTERNAL_PROXY_MAX_TRIES = NA
    ))
    for (provider in c("mgi", "rgd", "gnomad", "uniprot", "alphafold", "ensembl")) {
      budget <- external_proxy_budget(provider)
      expect_lte(budget$timeout_seconds, 10, label = paste0(provider, " timeout_seconds"))
      expect_lte(budget$max_seconds, 15, label = paste0(provider, " max_seconds"))
    }
  })
})

# ============================================================================
# Criterion 6: structured timing logs from the memoise chokepoint
# ============================================================================

describe("external provider memoise wrapper emits structured timing logs", {
  it("logs cache=miss then cache=hit with elapsed and status", {
    cache <- cachem::cache_mem()
    calls <- 0L
    fetcher <- function(symbol) {
      calls <<- calls + 1L
      list(source = "gnomad", gene_symbol = symbol, value = 42)
    }
    mem <- memoise_external_success_only(fetcher, cache = cache, source = "gnomad")

    miss <- capture_proxy_messages(mem("BRCA1"))
    hit <- capture_proxy_messages(mem("BRCA1"))

    miss_msgs <- attr(miss, "proxy_messages")
    hit_msgs <- attr(hit, "proxy_messages")

    # The underlying fetcher ran exactly once (second call is a cache hit).
    expect_equal(calls, 1L)
    # Miss path: structured complete log with source, status, elapsed, cache.
    expect_true(any(grepl("event=complete", miss_msgs, fixed = TRUE)))
    expect_true(any(grepl("source=gnomad", miss_msgs, fixed = TRUE)))
    expect_true(any(grepl("status=200", miss_msgs, fixed = TRUE)))
    expect_true(any(grepl("elapsed_ms=", miss_msgs, fixed = TRUE)))
    expect_true(any(grepl("cache=miss", miss_msgs, fixed = TRUE)))
    # Hit path: same shape but cache=hit.
    expect_true(any(grepl("cache=hit", hit_msgs, fixed = TRUE)))
  })

  it("does not cache transient errors and logs them as not-cached", {
    cache <- cachem::cache_mem()
    calls <- 0L
    flaky <- function(symbol) {
      calls <<- calls + 1L
      list(error = TRUE, status = 503L, source = "uniprot", message = "upstream timeout")
    }
    mem <- memoise_external_success_only(flaky, cache = cache, source = "uniprot")

    first <- capture_proxy_messages(mem("BRCA1"))
    mem("BRCA1")

    first_msgs <- attr(first, "proxy_messages")
    # Error path emits the error_not_cached event AND the timing complete event.
    expect_true(any(grepl("event=error_not_cached", first_msgs, fixed = TRUE)))
    expect_true(any(grepl("event=complete", first_msgs, fixed = TRUE)))
    expect_true(any(grepl("status=503", first_msgs, fixed = TRUE)))
    # Because the error was forgotten, the second call re-invokes the fetcher.
    expect_equal(calls, 2L)
  })

  it("stays silent (legacy behaviour) when no source label is supplied", {
    cache <- cachem::cache_mem()
    mem <- memoise_external_success_only(
      function(symbol) list(source = "ensembl", value = 1),
      cache = cache
    )

    out <- capture_proxy_messages(mem("BRCA1"))
    msgs <- attr(out, "proxy_messages")
    expect_false(any(grepl("event=complete", msgs, fixed = TRUE)))
  })
})

# ============================================================================
# Criterion 6 wiring guard: every provider fetcher emits timing
# ============================================================================

describe("all external providers are wired for timing observability", {
  it("each provider fetcher emits structured timing (memoise source or inline wrapper)", {
    api_dir <- get_api_dir()
    # gnomad / ensembl / uniprot / alphafold log via the memoise `source` arg.
    memoise_source_files <- c(
      "functions/external-proxy-gnomad.R",
      "functions/external-proxy-ensembl.R",
      "functions/external-proxy-uniprot.R",
      "functions/external-proxy-alphafold.R"
    )
    for (rel in memoise_source_files) {
      txt <- paste(readLines(file.path(api_dir, rel), warn = FALSE), collapse = "\n")
      expect_match(txt, "memoise_external_success_only", info = rel)
      expect_match(txt, "source = ", fixed = TRUE, info = rel)
    }

    # mgi / rgd log via the inline external_proxy_with_timing wrapper.
    inline_timing_files <- c(
      "functions/external-proxy-mgi.R",
      "functions/external-proxy-rgd.R"
    )
    for (rel in inline_timing_files) {
      txt <- paste(readLines(file.path(api_dir, rel), warn = FALSE), collapse = "\n")
      expect_match(txt, "external_proxy_with_timing", info = rel)
    }
  })
})

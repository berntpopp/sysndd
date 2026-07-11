# tests/testthat/test-unit-llm-admin-endpoint-service.R
#
# Host-runnable unit tests for the Administrator-only LLM admin endpoint
# service (services/llm-admin-endpoint-service.R, issue #346). Every external
# dependency (functions/llm-*.R repository/config layer) is mocked, so these
# tests need no RMariaDB / live database and no ellmer/Gemini SDK. They cover:
#   - GET /config model resolution + available_models/rate_limit shape
#   - PUT /config model validation (400) and the session-only env var set
#   - GET /cache/stats delegation
#   - GET /cache/summaries + GET /logs: the legacy page/per_page/limit/offset
#     pagination contract and "" -> NULL filter coercion
#   - DELETE /cache: cluster_type validation (400) and cleared_count shape
#   - POST /regenerate: Gemini-not-configured (503), invalid cluster_type
#     (400), snapshot-not-ready (409, no partial regeneration across cluster
#     types), force coercion + forwarding into regenerate_from_snapshot(),
#     and the 202 Accepted envelope — all driven through the injectable
#     `regenerate_from_snapshot` dependency, so clustering is never recomputed
#     inline (#488)
#   - POST /cache/<id>/validate: action validation, repository-failure (500),
#     and validated_by attribution from the caller's user_id
#   - GET /prompts delegation and PUT /prompts/<type> validation

library(testthat)
library(tibble)

# ---------------------------------------------------------------------------
# Test harness: build a fresh, isolated environment with baseline stubs for
# every external dependency the service calls (the functions/llm-*.R
# repository/config layer), then source ONLY the service file into it. This
# mirrors test-unit-llm-regenerate.R's source_batch_generator_env(): it
# exercises the REAL service logic end-to-end against controllable mocks
# without sourcing functions/llm-types.R / llm-judge.R (top-level
# ellmer::type_object() calls that error when ellmer is not installed) or
# functions/db-helpers.R (library(RMariaDB), not installed on host).
# ---------------------------------------------------------------------------

build_llm_admin_service_env <- function() {
  env <- new.env(parent = globalenv())
  env$`%||%` <- function(a, b) if (is.null(a)) b else a

  # --- functions/llm-model-config.R ---
  env$llm_model_config_resolve <- function(config = NULL) {
    list(
      model = "gemini-3.5-flash", source = "default",
      default_model = "gemini-3.5-flash", valid = TRUE,
      operator_allowed = FALSE, warning = NA_character_
    )
  }
  env$llm_model_config_validate <- function(model, config = NULL) {
    list(valid = TRUE, error_code = NA_character_, message = NA_character_)
  }
  env$list_gemini_models <- function(...) c("gemini-3.5-flash", "gemini-2.5-flash")
  env$get_gemini_model_metadata <- function(model_id) {
    list(
      display_name = model_id, description = "desc", rpm_limit = 30L,
      rpd_limit = 1000L, recommended_for = "general", status = "stable",
      allowed = TRUE
    )
  }
  env$is_gemini_configured <- function() TRUE
  env$GEMINI_RATE_LIMIT <- list(
    capacity = 30, fill_time_s = 60, backoff_base = 2, max_retries = 3
  )

  # --- functions/llm-cache-admin-repository.R ---
  env$get_cache_statistics <- function() list(total_entries = 0L)
  env$get_cached_summaries_paginated <- function(cluster_type = NULL, validation_status = NULL,
                                                  page = 1L, per_page = 20L) {
    list(data = tibble::tibble(), total = 0L, page = page, per_page = per_page)
  }
  env$clear_llm_cache <- function(cluster_type = "all") list(count = 0L)
  env$get_generation_logs_paginated <- function(cluster_type = NULL, status = NULL,
                                                 from_date = NULL, to_date = NULL,
                                                 page = 1L, per_page = 50L) {
    list(data = tibble::tibble(), total = 0L, page = page, per_page = per_page)
  }

  # --- functions/llm-cache-repository.R ---
  env$update_validation_status <- function(cache_id, validation_status, validated_by = NULL) TRUE

  # --- functions/llm-service.R ---
  env$get_all_prompt_templates <- function() list(functional_generation = list(version = "1.0"))

  source_api_file("services/llm-admin-endpoint-service.R", local = FALSE, envir = env)
  env
}

# Temporarily override bindings directly in `env`, run `code`, then restore.
with_env_mocks <- function(env, mocks, code) {
  originals <- list()
  had_prev <- list()
  for (name in names(mocks)) {
    had_prev[[name]] <- exists(name, envir = env, inherits = FALSE)
    if (had_prev[[name]]) originals[[name]] <- get(name, envir = env, inherits = FALSE)
    assign(name, mocks[[name]], envir = env)
  }
  on.exit({
    for (name in names(mocks)) {
      if (isTRUE(had_prev[[name]])) {
        assign(name, originals[[name]], envir = env)
      } else if (exists(name, envir = env, inherits = FALSE)) {
        rm(list = name, envir = env)
      }
    }
  }, add = TRUE)
  force(code)
}

# =============================================================================
# Shared helper: svc_llm_admin_runtime_config()
# =============================================================================

test_that("runtime_config returns NULL when no `dw` global exists", {
  env <- build_llm_admin_service_env()
  if (exists("dw", envir = .GlobalEnv, inherits = FALSE)) rm("dw", envir = .GlobalEnv)
  expect_null(env$svc_llm_admin_runtime_config())
})

test_that("runtime_config returns the `dw` global when present", {
  env <- build_llm_admin_service_env()
  assign("dw", list(gemini_model = "gemini-2.5-flash"), envir = .GlobalEnv)
  on.exit(rm("dw", envir = .GlobalEnv), add = TRUE)
  expect_equal(env$svc_llm_admin_runtime_config()$gemini_model, "gemini-2.5-flash")
})

# =============================================================================
# GET /config, PUT /config
# =============================================================================

test_that("get_config returns resolved model, available_models, and rate_limit", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_get_config()

  expect_true(result$gemini_configured)
  expect_equal(result$current_model, "gemini-3.5-flash")
  expect_length(result$available_models, 2)
  expect_equal(result$available_models[[1]]$model_id, "gemini-3.5-flash")
  expect_equal(result$rate_limit$capacity, 30)
})

test_that("update_config returns 400 with available_models on an invalid model", {
  env <- build_llm_admin_service_env()
  with_env_mocks(env, list(
    llm_model_config_validate = function(model, config = NULL) {
      list(valid = FALSE, error_code = "llm_model_invalid", message = "not allowed")
    }
  ), {
    result <- env$svc_llm_admin_update_config("bogus-model")
    expect_equal(result$http_status, 400)
    expect_equal(result$body$error, "INVALID_MODEL")
    expect_equal(result$body$error_code, "llm_model_invalid")
    expect_true("gemini-3.5-flash" %in% result$body$available_models)
  })
})

test_that("update_config sets GEMINI_MODEL and returns 200 on a valid model", {
  env <- build_llm_admin_service_env()
  old_env <- Sys.getenv("GEMINI_MODEL", unset = NA_character_)
  on.exit({
    if (is.na(old_env)) Sys.unsetenv("GEMINI_MODEL") else Sys.setenv(GEMINI_MODEL = old_env)
  }, add = TRUE)

  result <- env$svc_llm_admin_update_config("gemini-2.5-flash")
  expect_equal(result$http_status, 200)
  expect_true(result$body$success)
  expect_equal(result$body$model, "gemini-2.5-flash")
  expect_equal(Sys.getenv("GEMINI_MODEL"), "gemini-2.5-flash")
})

# =============================================================================
# GET /cache/stats
# =============================================================================

test_that("cache_stats delegates to get_cache_statistics()", {
  env <- build_llm_admin_service_env()
  with_env_mocks(env, list(
    get_cache_statistics = function() list(total_entries = 42L, by_status = list(pending = 1L))
  ), {
    result <- env$svc_llm_admin_cache_stats()
    expect_equal(result$total_entries, 42L)
  })
})

# =============================================================================
# GET /cache/summaries, GET /logs — legacy pagination contract
# =============================================================================

# NOTE on the calls below: every call supplies BOTH `page` and `per_page`
# (even if only as ""), never omitting one entirely. `as.integer(NULL)`
# (an omitted formal) yields a length-0 integer(0), and this pre-existing
# resolver does `is.na(per_page_val) || ...` / `is.na(page_val) || ...`
# unconditionally on that value BEFORE it ever looks at the limit/offset
# alias — so a length-0 operand crashes `||`/`&&` ("argument is of length
# zero") regardless of whether a valid limit/offset was also supplied. This
# is pre-existing behaviour carried over verbatim from the pre-refactor
# inline handler (identical logic), not something introduced here; see the
# dedicated regression test below that documents it explicitly. The real
# frontend never hits it because it always sends page+per_page together
# (app/src/components/llm/LlmCacheManager.vue, LlmLogViewer.vue).

test_that("cache_summaries treats \"\" filters as NULL with the frontend's real page=1/per_page=50 call shape", {
  env <- build_llm_admin_service_env()
  captured <- new.env()
  with_env_mocks(env, list(
    get_cached_summaries_paginated = function(cluster_type = NULL, validation_status = NULL,
                                               page = 1L, per_page = 20L) {
      captured$cluster_type <- cluster_type
      captured$validation_status <- validation_status
      list(data = tibble::tibble(x = 1:3), total = 3L, page = page, per_page = per_page)
    }
  ), {
    result <- env$svc_llm_admin_cache_summaries(
      cluster_type = "", validation_status = "", page = "1", per_page = "50"
    )
    expect_equal(result$page, 1L)
    expect_equal(result$per_page, 50L)
    expect_equal(result$total, 3L)
    expect_null(captured$cluster_type)
    expect_null(captured$validation_status)
  })
})

test_that("cache_summaries derives page/per_page from the limit/offset alias when page/per_page are blank", {
  env <- build_llm_admin_service_env()
  # page/per_page present-but-blank ("") -> length-1 NA, so the resolver falls
  # through to the limit/offset alias without hitting the length-0 crash.
  result <- env$svc_llm_admin_cache_summaries(page = "", per_page = "", limit = "10", offset = "25")
  expect_equal(result$per_page, 10L)
  # floor(25/10) + 1 = 3
  expect_equal(result$page, 3L)
})

test_that("cache_summaries page/per_page take precedence over limit/offset when both given", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_cache_summaries(page = "2", per_page = "5", limit = "999", offset = "999")
  expect_equal(result$page, 2L)
  expect_equal(result$per_page, 5L)
})

test_that("cache_summaries caps per_page at 500", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_cache_summaries(page = "1", per_page = "9999")
  expect_equal(result$per_page, 500L)
})

test_that("cache_summaries falls back to result$data length when $total is absent", {
  env <- build_llm_admin_service_env()
  with_env_mocks(env, list(
    get_cached_summaries_paginated = function(...) list(data = tibble::tibble(x = 1:4))
  ), {
    result <- env$svc_llm_admin_cache_summaries(page = "1", per_page = "50")
    expect_equal(result$total, 4L)
  })
})

test_that("generation_logs applies the same pagination contract and \"\" -> NULL filters", {
  env <- build_llm_admin_service_env()
  captured <- new.env()
  with_env_mocks(env, list(
    get_generation_logs_paginated = function(cluster_type = NULL, status = NULL,
                                              from_date = NULL, to_date = NULL,
                                              page = 1L, per_page = 50L) {
      captured$status <- status
      captured$from_date <- from_date
      list(data = tibble::tibble(), total = 0L, page = page, per_page = per_page)
    }
  ), {
    result <- env$svc_llm_admin_generation_logs(
      status = "", from_date = "", page = "", per_page = "", limit = "20", offset = "0"
    )
    expect_equal(result$per_page, 20L)
    expect_equal(result$page, 1L)
    expect_null(captured$status)
    expect_null(captured$from_date)
  })
})

test_that("KNOWN PRE-EXISTING BUG: omitting page/per_page while relying only on limit/offset crashes", {
  # Regression-documentation, not a desired behaviour: `.svc_llm_admin_resolve_pagination()`
  # checks `is.na(per_page_val)` / `is.na(page_val)` unconditionally before ever
  # consulting the limit/offset alias, and `as.integer(NULL)` (an omitted
  # formal) is length-0, so `||`/`&&` errors ("argument is of length zero")
  # instead of falling back to the alias. This carries over byte-for-byte from
  # the pre-refactor inline handler (same is.na()||... logic), so it is
  # preserved here rather than silently fixed (out of scope for this
  # behavior-preserving extraction) — flagged for a follow-up issue.
  env <- build_llm_admin_service_env()
  expect_error(env$svc_llm_admin_cache_summaries(limit = "10", offset = "25"))
  expect_error(env$svc_llm_admin_generation_logs(limit = "10", offset = "25"))
})

# =============================================================================
# DELETE /cache
# =============================================================================

test_that("clear_cache rejects an invalid cluster_type with 400", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_clear_cache("bogus")
  expect_equal(result$http_status, 400)
  expect_equal(result$body$error, "INVALID_CLUSTER_TYPE")
})

test_that("clear_cache returns 200 with the cleared_count on a valid cluster_type", {
  env <- build_llm_admin_service_env()
  with_env_mocks(env, list(
    clear_llm_cache = function(cluster_type = "all") list(count = 7L)
  ), {
    result <- env$svc_llm_admin_clear_cache("functional")
    expect_equal(result$http_status, 200)
    expect_true(result$body$success)
    expect_equal(result$body$cleared_count, 7L)
  })
})

# =============================================================================
# POST /regenerate — snapshot-driven (#488)
# =============================================================================

test_that("regenerate returns 503 when Gemini is not configured", {
  env <- build_llm_admin_service_env()
  with_env_mocks(env, list(is_gemini_configured = function() FALSE), {
    result <- env$svc_llm_admin_regenerate(
      regenerate_from_snapshot = function(...) stop("must not be called")
    )
    expect_equal(result$http_status, 503)
    expect_equal(result$body$error, "GEMINI_NOT_CONFIGURED")
  })
})

test_that("regenerate returns 400 for an invalid cluster_type", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_regenerate(
    cluster_type = "nonsense",
    regenerate_from_snapshot = function(...) stop("must not be called")
  )
  expect_equal(result$http_status, 400)
  expect_equal(result$body$error, "INVALID_CLUSTER_TYPE")
})

test_that("regenerate returns 409 and stops at the first cluster type without a public snapshot (no partial regen)", {
  env <- build_llm_admin_service_env()
  calls <- character()
  stub <- function(cluster_type, parent_job_id, force = FALSE) {
    calls <<- c(calls, cluster_type)
    list(ready = FALSE, reason = "snapshot_not_ready")
  }
  result <- env$svc_llm_admin_regenerate(cluster_type = "all", regenerate_from_snapshot = stub)

  expect_equal(result$http_status, 409)
  expect_equal(result$body$error, "SNAPSHOT_NOT_READY")
  expect_equal(result$body$cluster_type, "functional")
  # "all" processes functional then phenotype in order; the 409 on the FIRST
  # (functional) must short-circuit before phenotype is ever attempted.
  expect_equal(calls, "functional")
})

test_that("regenerate forwards force + coerces string \"true\", and returns 202 for both cluster types", {
  env <- build_llm_admin_service_env()
  captured <- list()
  stub <- function(cluster_type, parent_job_id, force = FALSE) {
    captured[[cluster_type]] <<- list(parent_job_id = parent_job_id, force = force)
    list(ready = TRUE, result = list(job_id = paste0("job-", cluster_type)))
  }

  result <- env$svc_llm_admin_regenerate(cluster_type = "all", force = "true", regenerate_from_snapshot = stub)

  expect_equal(result$http_status, 202)
  expect_equal(result$body$status, "accepted")
  expect_equal(result$body$cluster_types, c("functional", "phenotype"))
  expect_true(result$body$force)
  expect_true(is.character(result$body$job_id) && nchar(result$body$job_id) > 0)
  expect_equal(result$body$status_url, paste0("/api/jobs/", result$body$job_id))

  # Both cluster types were driven from the SAME parent job id, and force was
  # forwarded (coerced from the string "true") to both.
  expect_true(captured$functional$force)
  expect_true(captured$phenotype$force)
  expect_equal(captured$functional$parent_job_id, result$body$job_id)
  expect_equal(captured$phenotype$parent_job_id, result$body$job_id)
})

test_that("regenerate defaults force to FALSE and only drives the single requested cluster type", {
  env <- build_llm_admin_service_env()
  calls <- character()
  stub <- function(cluster_type, parent_job_id, force = FALSE) {
    calls <<- c(calls, cluster_type)
    expect_false(force)
    list(ready = TRUE, result = list(job_id = "job-x"))
  }
  result <- env$svc_llm_admin_regenerate(cluster_type = "phenotype", regenerate_from_snapshot = stub)
  expect_equal(result$http_status, 202)
  expect_equal(calls, "phenotype")
})

test_that("regenerate never recomputes clustering: the service source has no direct clustering calls", {
  # Complements the endpoint-level static guard in test-unit-llm-regenerate.R:
  # the actual orchestration now lives in the service, so assert here too that
  # it drives exclusively through the injected regenerate_from_snapshot()
  # dependency rather than calling any clustering-memoise function directly.
  src <- paste(
    readLines(file.path(get_api_dir(), "services", "llm-admin-endpoint-service.R"), warn = FALSE),
    collapse = "\n"
  )
  expect_false(grepl("gen_mca_clust_obj_mem", src, fixed = TRUE))
  expect_false(grepl("gen_string_clust_obj_mem", src, fixed = TRUE))
  expect_true(grepl("regenerate_from_snapshot(ct, parent_job_id = parent_job_id, force = force)", src, fixed = TRUE))
})

test_that("regenerate surfaces a thrown error from regenerate_from_snapshot as a 409 (not a crash)", {
  env <- build_llm_admin_service_env()
  stub <- function(cluster_type, parent_job_id, force = FALSE) stop("boom")
  result <- env$svc_llm_admin_regenerate(cluster_type = "functional", regenerate_from_snapshot = stub)
  expect_equal(result$http_status, 409)
  expect_equal(result$body$reason, "error")
})

# =============================================================================
# POST /cache/<id>/validate — attribution
# =============================================================================

test_that("validate_cache rejects an invalid action with 400", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_validate_cache(5L, "delete", user_id = 1L)
  expect_equal(result$http_status, 400)
  expect_equal(result$body$error, "INVALID_ACTION")
})

test_that("validate_cache returns 500 when the repository update fails", {
  env <- build_llm_admin_service_env()
  with_env_mocks(env, list(
    update_validation_status = function(cache_id, validation_status, validated_by = NULL) FALSE
  ), {
    result <- env$svc_llm_admin_validate_cache(5L, "validate", user_id = 1L)
    expect_equal(result$http_status, 500)
    expect_equal(result$body$error, "UPDATE_FAILED")
  })
})

test_that("validate_cache attributes validated_by to the caller's user_id as a character", {
  env <- build_llm_admin_service_env()
  captured <- new.env()
  with_env_mocks(env, list(
    update_validation_status = function(cache_id, validation_status, validated_by = NULL) {
      captured$cache_id <- cache_id
      captured$validation_status <- validation_status
      captured$validated_by <- validated_by
      TRUE
    }
  ), {
    result <- env$svc_llm_admin_validate_cache("5", "reject", user_id = 42L)
    expect_equal(result$http_status, 200)
    expect_equal(result$body$validation_status, "rejected")
    expect_equal(result$body$cache_id, 5L)
  })
  expect_identical(captured$validated_by, "42")
  expect_equal(captured$validation_status, "rejected")
  expect_equal(captured$cache_id, 5L)
})

test_that("validate_cache leaves validated_by NULL when no user_id is supplied", {
  env <- build_llm_admin_service_env()
  captured <- new.env()
  with_env_mocks(env, list(
    update_validation_status = function(cache_id, validation_status, validated_by = NULL) {
      captured$validated_by <- validated_by
      TRUE
    }
  ), {
    env$svc_llm_admin_validate_cache(1L, "validate", user_id = NULL)
  })
  expect_null(captured$validated_by)
})

# =============================================================================
# GET /prompts, PUT /prompts/<type>
# =============================================================================

test_that("get_prompts delegates to get_all_prompt_templates()", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_get_prompts()
  expect_true("functional_generation" %in% names(result))
})

test_that("update_prompt rejects an unknown type with 400", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_update_prompt("bogus_type", template = "x", version = "1.0")
  expect_equal(result$http_status, 400)
  expect_equal(result$body$error, "INVALID_PROMPT_TYPE")
})

test_that("update_prompt requires a non-empty template", {
  env <- build_llm_admin_service_env()
  r1 <- env$svc_llm_admin_update_prompt("functional_generation", template = NULL, version = "1.0")
  expect_equal(r1$http_status, 400)
  expect_equal(r1$body$error, "MISSING_TEMPLATE")

  r2 <- env$svc_llm_admin_update_prompt("functional_generation", template = "", version = "1.0")
  expect_equal(r2$http_status, 400)
  expect_equal(r2$body$error, "MISSING_TEMPLATE")
})

test_that("update_prompt requires a non-empty version", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_update_prompt("functional_generation", template = "x", version = NULL)
  expect_equal(result$http_status, 400)
  expect_equal(result$body$error, "MISSING_VERSION")
})

test_that("update_prompt returns 200 and echoes type/version on success", {
  env <- build_llm_admin_service_env()
  result <- env$svc_llm_admin_update_prompt(
    "phenotype_judge", template = "new template text", version = "1.1", description = "notes"
  )
  expect_equal(result$http_status, 200)
  expect_true(result$body$success)
  expect_equal(result$body$type, "phenotype_judge")
  expect_equal(result$body$version, "1.1")
})

# =============================================================================
# Service prefix invariant
# =============================================================================

test_that("all exported service functions keep the svc_llm_admin_ prefix", {
  env <- build_llm_admin_service_env()
  exported <- c(
    "svc_llm_admin_runtime_config", "svc_llm_admin_get_config", "svc_llm_admin_update_config",
    "svc_llm_admin_cache_stats", "svc_llm_admin_cache_summaries", "svc_llm_admin_clear_cache",
    "svc_llm_admin_regenerate", "svc_llm_admin_generation_logs", "svc_llm_admin_validate_cache",
    "svc_llm_admin_get_prompts", "svc_llm_admin_update_prompt"
  )
  for (name in exported) {
    expect_true(is.function(get(name, envir = env)), info = name)
  }
})

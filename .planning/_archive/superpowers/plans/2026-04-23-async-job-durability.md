# Async Job Durability Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SysNDD's in-memory async job ownership with a durable MySQL-backed job system and separate worker runtime, while preserving current async behaviors and enabling safe parallel implementation.

**Architecture:** The refactor moves async orchestration to a control-plane / execution-plane split. The API writes durable jobs and serves status/history; a separate worker service claims and executes jobs using MySQL queue semantics; row-level progress and lifecycle events replace process-local and file-based job state; `mirai` remains inside workers for bounded execution only.

**Tech Stack:** R/Plumber, testthat, DBI/RMariaDB, MySQL 8.4, Docker Compose, `mirai`, Vue 3, TypeScript, Vitest, Make-based CI.

---

### Task 1: Preflight And File Map Lock-In

**Files:**
- Modify: `.planning/superpowers/specs/2026-04-23-async-job-durability-design.md`
- Modify: `.planning/superpowers/plans/2026-04-23-async-job-durability.md`
- Test: none

- [ ] **Step 1: Reconfirm the async inventory before code changes**

Run:
```bash
rg -n "create_job\\(|check_duplicate_job\\(|get_job_history\\(|jobs_env|read_job_progress|create_progress_reporter" api/endpoints api/functions | sort
```

Expected:
- all twelve `create_job(...)` call sites are present
- `jobs_env`, `check_duplicate_job()`, `get_job_history()`, and file-based progress functions still exist

- [ ] **Step 2: Record the owned migration set in the plan**

Add a short note to this plan confirming the durable migration covers the twelve current async operations:
```text
clustering
phenotype_clustering
ontology_update
hgnc_update
comparisons_update
pubtator_update
llm_generation
backup_create
backup_restore
omim_update
force_apply_ontology
publication_refresh
```

- [ ] **Step 3: Freeze the implementation file map before parallel work starts**

Document the owned files for the refactor:
```text
db/migrations/020_add_async_job_schema.sql
api/functions/async-job-repository.R
api/functions/async-job-service.R
api/functions/async-job-worker.R
api/functions/async-job-handlers.R
api/functions/async-job-progress.R
api/functions/job-manager.R
api/functions/job-progress.R
api/endpoints/jobs_endpoints.R
api/endpoints/admin_endpoints.R
api/endpoints/backup_endpoints.R
api/endpoints/publication_endpoints.R
api/bootstrap/setup_workers.R
api/bootstrap/mount_endpoints.R
api/start_sysndd_api.R
docker-compose.yml
documentation/08-development.qmd
documentation/09-deployment.qmd
AGENTS.md
app/src/composables/useAsyncJob.ts
```

- [ ] **Step 4: Commit the planning lock-in**

Run:
```bash
git add .planning/superpowers/specs/2026-04-23-async-job-durability-design.md .planning/superpowers/plans/2026-04-23-async-job-durability.md
git commit -m "docs(plan): add async job durability implementation plan"
```


### Task 2: Durable Schema And Repository Tests

**Ownership:** DB schema plus DB-backed repository primitives only

**Files:**
- Create: `db/migrations/020_add_async_job_schema.sql`
- Create: `api/functions/async-job-repository.R`
- Create: `api/tests/testthat/test-unit-async-job-repository.R`
- Modify: `api/start_sysndd_api.R`
- Test: `api/tests/testthat/test-unit-async-job-repository.R`
- Test: `api/tests/testthat/test-unit-migration-runner.R`

- [ ] **Step 1: Write the failing repository tests first**

Add repository-level tests for:
- create job row
- claim next eligible job
- duplicate detection by parameter hash
- progress update on row
- event append
- stale lease recovery
- history read

Representative test shape:
```r
test_that("claim_next_async_job claims only one eligible queued job", {
  async_job_repository_create(list(
    job_id = "job-1",
    job_type = "hgnc_update",
    queue_name = "default",
    priority = 100L,
    request_payload_json = "{\"operation\":\"hgnc_update\"}",
    request_hash = "hash-1",
    submitted_by = 1L,
    scheduled_at = Sys.time()
  ))

  claimed <- async_job_repository_claim_next(
    worker_id = "worker-a",
    worker_hostname = "host-a",
    worker_pid = 1234L,
    lease_seconds = 60L
  )

  expect_equal(claimed$job_id, "job-1")
  stored <- async_job_repository_get("job-1", include_result = TRUE)
  expect_equal(stored$status, "running")
  expect_equal(stored$claimed_by_worker, "worker-a")
  expect_false(is.na(stored$claim_expires_at))
})
```

- [ ] **Step 2: Run the new repository test and confirm failure**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-async-job-repository.R')"
```

Expected:
- FAIL because the repository file and async schema do not exist yet

- [ ] **Step 3: Create the durable schema migration**

Add `db/migrations/020_add_async_job_schema.sql` with:
- `async_jobs`
- `async_job_events`
- indexed claim path
- durable duplicate hash support
- audit-safe `submitted_by`

Target migration skeleton:
```sql
CREATE TABLE async_jobs (
  job_id CHAR(36) NOT NULL PRIMARY KEY,
  job_type VARCHAR(64) NOT NULL,
  queue_name VARCHAR(64) NOT NULL DEFAULT 'default',
  priority INT NOT NULL DEFAULT 100,
  status ENUM('queued','running','completed','failed','cancel_requested','cancelled') NOT NULL,
  request_hash CHAR(64) NOT NULL,
  request_payload_json JSON NOT NULL,
  submitted_by INT NULL,
  submitted_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  scheduled_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  started_at DATETIME(6) NULL,
  completed_at DATETIME(6) NULL,
  claimed_by_worker VARCHAR(128) NULL,
  worker_hostname VARCHAR(255) NULL,
  worker_pid INT NULL,
  last_heartbeat_at DATETIME(6) NULL,
  claim_expires_at DATETIME(6) NULL,
  attempt_count INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 1,
  next_attempt_at DATETIME(6) NULL,
  progress_pct DECIMAL(5,2) NULL,
  progress_message TEXT NULL,
  last_error_code VARCHAR(128) NULL,
  last_error_message TEXT NULL,
  cancelled_by INT NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  result_json JSON NULL,
  CONSTRAINT fk_async_jobs_submitted_by
    FOREIGN KEY (submitted_by) REFERENCES user(user_id) ON DELETE RESTRICT
);

CREATE INDEX idx_async_jobs_claim
  ON async_jobs (status, queue_name, priority, scheduled_at, next_attempt_at, submitted_at);

CREATE UNIQUE INDEX idx_async_jobs_active_request_hash
  ON async_jobs (job_type, request_hash, status);

CREATE TABLE async_job_events (
  event_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  job_id CHAR(36) NOT NULL,
  event_type VARCHAR(64) NOT NULL,
  event_message TEXT NULL,
  event_payload_json JSON NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT fk_async_job_events_job
    FOREIGN KEY (job_id) REFERENCES async_jobs(job_id) ON DELETE CASCADE
);
```

- [ ] **Step 4: Implement the repository file**

Create `api/functions/async-job-repository.R` with focused DB-only functions:
```r
async_job_repository_create <- function(job) { ... }
async_job_repository_get <- function(job_id, include_result = FALSE) { ... }
async_job_repository_find_active_duplicate <- function(job_type, request_hash) { ... }
async_job_repository_claim_next <- function(worker_id, worker_hostname, worker_pid, lease_seconds, queues = "default") { ... }
async_job_repository_update_progress <- function(job_id, progress_pct = NULL, progress_message = NULL) { ... }
async_job_repository_append_event <- function(job_id, event_type, event_message = NULL, event_payload = NULL) { ... }
async_job_repository_complete <- function(job_id, result_json) { ... }
async_job_repository_fail <- function(job_id, error_code, error_message, next_attempt_at = NULL) { ... }
async_job_repository_cancel <- function(job_id, cancelled_by = NULL) { ... }
async_job_repository_heartbeat <- function(job_id, lease_seconds) { ... }
async_job_repository_recover_stale <- function(now = Sys.time()) { ... }
async_job_repository_history <- function(limit = 20L) { ... }
```

- [ ] **Step 5: Source the new repository file at startup**

Update `api/start_sysndd_api.R` so the new repository file is sourced with the other `functions/*` files before services/endpoints.

- [ ] **Step 6: Run the targeted repository and migration tests**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-async-job-repository.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-migration-runner.R')"
```

Expected:
- PASS

- [ ] **Step 7: Commit the schema and repository slice**

Run:
```bash
git add db/migrations/020_add_async_job_schema.sql api/functions/async-job-repository.R api/tests/testthat/test-unit-async-job-repository.R api/start_sysndd_api.R
git commit -m "feat(async-jobs): add durable job schema and repository"
```


### Task 3: Worker Runtime And Durable Progress Plumbing

**Ownership:** worker loop, handler registry shell, row-level progress writer, worker entrypoint only

**Files:**
- Create: `api/functions/async-job-worker.R`
- Create: `api/functions/async-job-handlers.R`
- Create: `api/functions/async-job-progress.R`
- Create: `api/tests/testthat/test-unit-async-job-worker.R`
- Modify: `api/bootstrap/setup_workers.R`
- Modify: `api/functions/job-progress.R`
- Modify: `docker-compose.yml`
- Test: `api/tests/testthat/test-unit-async-job-worker.R`

- [ ] **Step 1: Write the failing worker tests**

Add tests for:
- claim loop dispatches correct handler
- heartbeat updates lease
- progress updates row fields
- shutdown flag stops new claims
- bounded worker lifetime exits cleanly after configured limits

Representative test shape:
```r
test_that("worker exits without claiming new jobs when drain requested", {
  state <- new.env(parent = emptyenv())
  state$draining <- TRUE

  claimed <- async_job_worker_claim_once(
    state = state,
    worker_config = list(worker_id = "worker-a", lease_seconds = 60L)
  )

  expect_null(claimed)
})
```

- [ ] **Step 2: Run the worker test and confirm failure**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-async-job-worker.R')"
```

Expected:
- FAIL because worker runtime files do not exist yet

- [ ] **Step 3: Add durable progress helpers**

Create `api/functions/async-job-progress.R`:
```r
create_async_job_progress_reporter <- function(job_id, throttle_seconds = 2) {
  last_write_time <- 0
  function(step, message, current = NULL, total = NULL) {
    now <- as.numeric(Sys.time())
    if ((now - last_write_time) < throttle_seconds && !identical(current, total)) {
      return(invisible(NULL))
    }
    last_write_time <<- now
    pct <- if (!is.null(current) && !is.null(total) && total > 0) round((current / total) * 100, 2) else NULL
    async_job_repository_update_progress(job_id, progress_pct = pct, progress_message = message)
  }
}
```

- [ ] **Step 4: Implement the handler registry shell**

Create `api/functions/async-job-handlers.R` with:
```r
async_job_handler_registry <- list(
  clustering = list(cancel_mode = "best_effort", run = async_job_handle_clustering, after_success = async_job_after_clustering),
  phenotype_clustering = list(cancel_mode = "best_effort", run = async_job_handle_phenotype_clustering, after_success = async_job_after_phenotype_clustering),
  ontology_update = list(cancel_mode = "non_interruptible", run = async_job_handle_ontology_update),
  hgnc_update = list(cancel_mode = "non_interruptible", run = async_job_handle_hgnc_update),
  comparisons_update = list(cancel_mode = "non_interruptible", run = async_job_handle_comparisons_update),
  pubtator_update = list(cancel_mode = "best_effort", run = async_job_handle_pubtator_update),
  llm_generation = list(cancel_mode = "best_effort", run = async_job_handle_llm_generation),
  backup_create = list(cancel_mode = "non_interruptible", run = async_job_handle_backup_create),
  backup_restore = list(cancel_mode = "non_interruptible", run = async_job_handle_backup_restore),
  omim_update = list(cancel_mode = "non_interruptible", run = async_job_handle_omim_update),
  force_apply_ontology = list(cancel_mode = "non_interruptible", run = async_job_handle_force_apply_ontology),
  publication_refresh = list(cancel_mode = "best_effort", run = async_job_handle_publication_refresh)
)
```

- [ ] **Step 5: Implement the worker loop**

Create `api/functions/async-job-worker.R` with:
```r
async_job_worker_main <- function() {
  config <- async_job_worker_config_from_env()
  state <- async_job_worker_state()

  on.exit(async_job_worker_release_all(state), add = TRUE)

  while (!state$shutdown_requested) {
    if (async_job_worker_should_exit(state, config)) break

    claimed <- async_job_repository_claim_next(
      worker_id = config$worker_id,
      worker_hostname = config$hostname,
      worker_pid = Sys.getpid(),
      lease_seconds = config$lease_seconds,
      queues = config$queues
    )

    if (is.null(claimed)) {
      Sys.sleep(config$idle_sleep_seconds)
      next
    }

    async_job_worker_run_claimed_job(claimed, state, config)
    state$jobs_processed <- state$jobs_processed + 1L
  }
}
```

- [ ] **Step 6: Wire `mirai` lifecycle bounds into worker config**

Use environment-driven bounds such as `MAX_JOBS_PER_WORKER` and `MAX_WORKER_LIFETIME`; the worker contract must explicitly cap both max jobs per worker and total worker lifetime:
```r
async_job_worker_config_from_env <- function() {
  list(
    worker_id = sprintf("%s:%s", Sys.info()[["nodename"]], uuid::UUIDgenerate()),
    hostname = Sys.info()[["nodename"]],
    lease_seconds = as.integer(Sys.getenv("ASYNC_JOB_LEASE_SECONDS", "60")),
    idle_sleep_seconds = as.numeric(Sys.getenv("ASYNC_JOB_IDLE_SLEEP_SECONDS", "2")),
    max_jobs_per_worker = as.integer(Sys.getenv("MAX_JOBS_PER_WORKER", "50")),
    max_worker_lifetime_seconds = as.integer(Sys.getenv("MAX_WORKER_LIFETIME", "3600")),
    queues = strsplit(Sys.getenv("ASYNC_JOB_QUEUES", "default"), ",")[[1]]
  )
}
```

- [ ] **Step 7: Keep legacy file progress as a temporary shim only if tests require sequencing**

Update `api/functions/job-progress.R` to delegate to durable progress in the new path, or mark it transitional and stop new code from depending on it:
```r
create_progress_reporter <- function(job_id, throttle_seconds = 2) {
  create_async_job_progress_reporter(job_id, throttle_seconds = throttle_seconds)
}
```

- [ ] **Step 8: Add worker service to Compose**

Add a separate worker service using the same application image with a different entrypoint and grace period:
```yaml
  sysndd-worker:
    build:
      context: ./api
    command: ["Rscript", "/app/start_async_worker.R"]
    depends_on:
      sysndd-api:
        condition: service_healthy
    stop_grace_period: 60s
```

- [ ] **Step 9: Run worker tests**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-async-job-worker.R')"
```

Expected:
- PASS

- [ ] **Step 10: Commit the worker-runtime slice**

Run:
```bash
git add api/functions/async-job-worker.R api/functions/async-job-handlers.R api/functions/async-job-progress.R api/tests/testthat/test-unit-async-job-worker.R api/bootstrap/setup_workers.R api/functions/job-progress.R docker-compose.yml
git commit -m "feat(async-jobs): add worker runtime and durable progress"
```


### Task 4: Service Layer And Durable Job API Surface

**Ownership:** API-facing service methods, status/history endpoints, durable duplicate checks only

**Files:**
- Create: `api/functions/async-job-service.R`
- Create: `api/tests/testthat/test-unit-async-job-service.R`
- Modify: `api/endpoints/jobs_endpoints.R`
- Modify: `api/functions/job-manager.R`
- Test: `api/tests/testthat/test-unit-async-job-service.R`
- Test: `api/tests/testthat/test-endpoint-jobs.R`

- [ ] **Step 1: Write the failing service and endpoint tests**

Add tests for:
- submit returns durable `job_id`
- duplicate returns existing job info
- status reads DB-backed progress
- history endpoint reads durable rows
- cancel request moves running jobs to `cancel_requested`

Representative expectations:
```r
expect_equal(result$status, "accepted")
expect_match(result$status_url, "/api/jobs/.+/status")
expect_equal(status$progress$percent, 42)
expect_equal(history$data[[1]]$operation, "hgnc_update")
```

- [ ] **Step 2: Run the targeted service tests and confirm failure**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-async-job-service.R')"
```

Expected:
- FAIL because the service file does not exist yet

- [ ] **Step 3: Implement the service layer**

Create `api/functions/async-job-service.R`:
```r
async_job_service_submit <- function(job_type, request_payload, submitted_by = NULL, queue_name = "default", priority = 100L, max_attempts = 1L) { ... }
async_job_service_status <- function(job_id) { ... }
async_job_service_history <- function(limit = 20L) { ... }
async_job_service_request_cancel <- function(job_id, cancelled_by = NULL) { ... }
async_job_service_retry <- function(job_id, requested_by = NULL) { ... }
async_job_service_duplicate <- function(job_type, request_payload) { ... }
```

- [ ] **Step 4: Reduce `job-manager.R` to a compatibility facade during migration**

Change `api/functions/job-manager.R` so existing callers can migrate incrementally:
```r
create_job <- function(operation, params, executor_fn = NULL, timeout_ms = 1800000) {
  async_job_service_submit(
    job_type = operation,
    request_payload = list(params = params, timeout_ms = timeout_ms),
    submitted_by = NULL
  )
}

check_duplicate_job <- function(operation, params) {
  async_job_service_duplicate(operation, params)
}

get_job_history <- function(limit = 20) {
  async_job_service_history(limit)
}
```

- [ ] **Step 5: Make job status and history endpoints durable**

Update `api/endpoints/jobs_endpoints.R`:
```r
#* @get /history
function(req, res, limit = 20) {
  require_role(req, res, "Administrator")
  async_job_service_history(limit)
}

#* @get /<job_id>/status
function(job_id, res) {
  status <- async_job_service_status(job_id)
  if (identical(status$error, "JOB_NOT_FOUND")) {
    res$status <- 404
  }
  status
}
```

- [ ] **Step 6: Run the service and jobs endpoint tests**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-async-job-service.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-jobs.R')"
```

Expected:
- PASS

- [ ] **Step 7: Commit the service-layer slice**

Run:
```bash
git add api/functions/async-job-service.R api/tests/testthat/test-unit-async-job-service.R api/endpoints/jobs_endpoints.R api/functions/job-manager.R
git commit -m "feat(async-jobs): add durable service and job endpoints"
```


### Task 5: Migrate Clustering And Phenotype Clustering First

**Ownership:** representative async family, cache-hit path, post-completion chaining only

**Files:**
- Modify: `api/endpoints/jobs_endpoints.R`
- Modify: `api/functions/async-job-handlers.R`
- Modify: `api/functions/llm-batch-generator.R`
- Create: `api/tests/testthat/test-integration-async-job-clustering.R`
- Test: `api/tests/testthat/test-integration-async-job-clustering.R`

- [ ] **Step 1: Write the failing integration tests for clustering**

Cover:
- queue submission for `clustering`
- duplicate suppression by params hash
- cache-hit path still returns accepted job and triggers LLM chain
- successful completion appends post-completion LLM work

Representative test shape:
```r
test_that("clustering success triggers llm generation hook", {
  calls <- list()
  local_mocked_bindings(
    trigger_llm_batch_generation = function(clusters, cluster_type, parent_job_id) {
      calls <<- append(calls, list(list(cluster_type = cluster_type, parent_job_id = parent_job_id)))
      invisible(TRUE)
    }
  )

  result <- async_job_after_clustering(
    job = list(job_id = "job-1", job_type = "clustering"),
    handler_result = list(clusters = tibble::tibble(cluster = 1))
  )

  expect_length(calls, 1)
  expect_equal(calls[[1]]$cluster_type, "functional")
})
```

- [ ] **Step 2: Run the clustering integration test and confirm failure**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-async-job-clustering.R')"
```

Expected:
- FAIL because the durable handler and after-success hooks are not wired yet

- [ ] **Step 3: Migrate clustering endpoint submission**

Update `api/endpoints/jobs_endpoints.R` so the async path submits durable jobs through the service layer instead of writing directly to `jobs_env`.

Target shape:
```r
result <- async_job_service_submit(
  job_type = "clustering",
  request_payload = list(
    genes = genes_list,
    algorithm = algorithm,
    category_links = category_links,
    string_id_table = string_id_table
  ),
  submitted_by = req$user$user_id,
  queue_name = "analysis",
  priority = 50L,
  max_attempts = 1L
)
```

- [ ] **Step 4: Implement durable clustering handlers and after-success hooks**

In `api/functions/async-job-handlers.R`:
```r
async_job_handle_clustering <- function(job, payload) { ... }
async_job_after_clustering <- function(job, handler_result) {
  if (!is.null(handler_result$clusters) && nrow(handler_result$clusters) > 0) {
    trigger_llm_batch_generation(
      clusters = handler_result$clusters,
      cluster_type = "functional",
      parent_job_id = job$job_id
    )
  }
}
```

Mirror the same pattern for `phenotype_clustering` with `cluster_type = "phenotype"`.

- [ ] **Step 5: Run the clustering integration tests**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-async-job-clustering.R')"
```

Expected:
- PASS

- [ ] **Step 6: Commit the first migrated async family**

Run:
```bash
git add api/endpoints/jobs_endpoints.R api/functions/async-job-handlers.R api/functions/llm-batch-generator.R api/tests/testthat/test-integration-async-job-clustering.R
git commit -m "feat(async-jobs): migrate clustering jobs to durable runtime"
```


### Task 6: Parallel Workstream A — Migrate Update And Publication Handlers

**Ownership:** ontology, HGNC, comparisons, PubTator, OMIM, publication refresh, force-apply ontology

**Files:**
- Modify: `api/endpoints/jobs_endpoints.R`
- Modify: `api/endpoints/admin_endpoints.R`
- Modify: `api/endpoints/publication_endpoints.R`
- Modify: `api/functions/async-job-handlers.R`
- Create: `api/tests/testthat/test-integration-async-job-updates.R`
- Test: `api/tests/testthat/test-integration-async-job-updates.R`

- [ ] **Step 1: Write failing integration tests for update-family migration**

Cover:
- durable submission for each endpoint family
- duplicate suppression remains intact
- progress messages write to row fields
- durable status endpoint reports progress and final states

Representative expectations:
```r
expect_equal(submit$status, "accepted")
expect_equal(duplicate$status, "already_running")
expect_match(status$step, "Updating HGNC")
expect_equal(final_status$status, "completed")
```

- [ ] **Step 2: Run the update integration test and confirm failure**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-async-job-updates.R')"
```

Expected:
- FAIL because endpoints still rely on `create_job()` semantics directly

- [ ] **Step 3: Migrate the endpoints to durable submission**

Update each endpoint family to use:
```r
async_job_service_submit(
  job_type = "hgnc_update",
  request_payload = list(...),
  submitted_by = req$user$user_id,
  queue_name = "maintenance",
  priority = 80L,
  max_attempts = 1L
)
```

Use matching `job_type` values for:
- `ontology_update`
- `hgnc_update`
- `comparisons_update`
- `pubtator_update`
- `omim_update`
- `force_apply_ontology`
- `publication_refresh`

- [ ] **Step 4: Implement the corresponding handlers**

Move each executor body into `api/functions/async-job-handlers.R` as focused handler functions that use `create_async_job_progress_reporter(job$job_id)` instead of file progress writers.

- [ ] **Step 5: Re-run the update integration tests**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-async-job-updates.R')"
```

Expected:
- PASS

- [ ] **Step 6: Commit the update/publication migration slice**

Run:
```bash
git add api/endpoints/jobs_endpoints.R api/endpoints/admin_endpoints.R api/endpoints/publication_endpoints.R api/functions/async-job-handlers.R api/tests/testthat/test-integration-async-job-updates.R
git commit -m "feat(async-jobs): migrate update and publication handlers"
```


### Task 7: Parallel Workstream B — Migrate Backup And LLM Handlers

**Ownership:** backup create/restore and LLM generation handlers only

**Files:**
- Modify: `api/endpoints/backup_endpoints.R`
- Modify: `api/functions/async-job-handlers.R`
- Modify: `api/functions/backup-functions.R`
- Modify: `api/functions/llm-batch-generator.R`
- Create: `api/tests/testthat/test-integration-async-job-backup-llm.R`
- Test: `api/tests/testthat/test-integration-async-job-backup-llm.R`

- [ ] **Step 1: Write failing integration tests for backup and LLM migration**

Cover:
- `backup_create` durable submission and status
- `backup_restore` durable submission and duplicate suppression
- `llm_generation` durable enqueue from trigger path
- row-level progress visibility

Representative test shape:
```r
expect_equal(create_result$status, "accepted")
expect_equal(restore_duplicate$error, "RESTORE_IN_PROGRESS")
expect_equal(llm_enqueue$status, "accepted")
expect_true(is.numeric(status$progress$percent))
```

- [ ] **Step 2: Run the integration test and confirm failure**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-async-job-backup-llm.R')"
```

Expected:
- FAIL because backup and LLM still rely on legacy job semantics

- [ ] **Step 3: Migrate backup endpoints and handlers**

Update `api/endpoints/backup_endpoints.R` and corresponding handler functions to submit durable jobs and use durable progress reporting.

- [ ] **Step 4: Migrate LLM generation enqueue path**

Update `api/functions/llm-batch-generator.R`:
```r
result <- async_job_service_submit(
  job_type = "llm_generation",
  request_payload = list(
    parent_job_id = parent_job_id,
    cluster_type = cluster_type,
    clusters = clusters
  ),
  submitted_by = NULL,
  queue_name = "llm",
  priority = 200L,
  max_attempts = 3L
)
```

- [ ] **Step 5: Re-run the integration test**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-integration-async-job-backup-llm.R')"
```

Expected:
- PASS

- [ ] **Step 6: Commit the backup/LLM migration slice**

Run:
```bash
git add api/endpoints/backup_endpoints.R api/functions/async-job-handlers.R api/functions/backup-functions.R api/functions/llm-batch-generator.R api/tests/testthat/test-integration-async-job-backup-llm.R
git commit -m "feat(async-jobs): migrate backup and llm jobs"
```


### Task 8: Frontend Polling, Docs, Hard Cut Cleanup, And Final Verification

**Ownership:** frontend async polling, durable docs, removal of legacy async state, full verification

**Files:**
- Modify: `app/src/composables/useAsyncJob.ts`
- Modify: `app/src/composables/useAsyncJob.spec.ts`
- Modify: `api/functions/job-manager.R`
- Modify: `api/functions/job-progress.R`
- Modify: `documentation/08-development.qmd`
- Modify: `documentation/09-deployment.qmd`
- Modify: `AGENTS.md`
- Test: `app/src/composables/useAsyncJob.spec.ts`
- Test: `make test-api-fast`
- Test: `make ci-local`

- [ ] **Step 1: Write the failing frontend polling tests**

Add assertions that polling no longer depends on sticky-session correctness comments/behavior:
```ts
it('tracks durable row-level progress from the status endpoint', async () => {
  server.use(
    http.get('/api/jobs/job-1/status', () =>
      HttpResponse.json({
        job_id: 'job-1',
        status: 'running',
        step: 'Updating HGNC data',
        progress: { percent: 42, message: 'Downloading HGNC data...' },
      })
    )
  );

  expect(progress.value.current).toBeGreaterThanOrEqual(0);
  expect(step.value).toContain('HGNC');
});
```

- [ ] **Step 2: Run the frontend polling test and confirm failure**

Run:
```bash
cd app && npx vitest run src/composables/useAsyncJob.spec.ts
```

Expected:
- FAIL because the composable still reflects legacy status/progress assumptions

- [ ] **Step 3: Update the frontend composable for durable status**

Change `app/src/composables/useAsyncJob.ts` to consume row-level durable progress and remove sticky-session correctness commentary from the implementation.

Target shape:
```ts
const response = await axios.get(statusEndpoint(jobId.value), {
  withCredentials: true,
});

const data = response.data;
status.value = unwrapValue(data.status) as JobStatus;
step.value = String(unwrapValue(data.progress?.message ?? data.step ?? ''));
progress.value = {
  current: Number(unwrapValue(data.progress?.percent ?? 0)),
  total: 100,
};
```

- [ ] **Step 4: Remove the legacy hard-cut leftovers**

Make `api/functions/job-manager.R` and `api/functions/job-progress.R` minimal compatibility wrappers or delete them if no repo-local callers remain.

Final target:
```r
create_job <- function(...) {
  stop("Legacy in-memory async job API removed; use async_job_service_submit().")
}
```

If any compatibility wrapper remains temporarily, add a final follow-up step in the same task to remove it before completion.

- [ ] **Step 5: Update durable docs**

Document:
- separate worker service
- readiness gating
- worker restart/drain behavior
- `make ci-local` remains required before handoff
- worker-executed code changes still require restart awareness

Files:
- `documentation/08-development.qmd`
- `documentation/09-deployment.qmd`
- `AGENTS.md`

- [ ] **Step 6: Run targeted frontend verification**

Run:
```bash
cd app && npx vitest run src/composables/useAsyncJob.spec.ts
```

Expected:
- PASS

- [ ] **Step 7: Run fast repo verification**

Run:
```bash
make test-api-fast
make pre-commit
```

Expected:
- PASS

- [ ] **Step 8: Run full verification**

Run:
```bash
make ci-local
```

Expected:
- PASS

- [ ] **Step 9: Commit the cleanup and docs slice**

Run:
```bash
git add app/src/composables/useAsyncJob.ts app/src/composables/useAsyncJob.spec.ts api/functions/job-manager.R api/functions/job-progress.R documentation/08-development.qmd documentation/09-deployment.qmd AGENTS.md
git commit -m "refactor(async-jobs): complete durable worker cutover"
```


### Task 9: Final Review And Merge Readiness

**Files:**
- Modify: pull request description / branch notes if applicable
- Test: `git diff --check`
- Test: GitHub Actions PR run

- [ ] **Step 1: Run formatting/sanity diff checks**

Run:
```bash
git diff --check
git status --short
```

Expected:
- no whitespace errors
- clean working tree after commits

- [ ] **Step 2: Summarize the architectural cutover in the PR**

Update the PR description or merge notes with:
```text
- durable MySQL-backed async queue/state
- separate worker service
- row-level durable progress and job history
- duplicate suppression preserved
- clustering/phenotype -> LLM chaining preserved
- sticky-session correctness removed
```

- [ ] **Step 3: Wait for CI and record exact results**

Required checks:
```text
make test-api-fast
make ci-local
GitHub Actions CI
```

Expected:
- all pass before merge

- [ ] **Step 4: Request code review before merge**

Use the review workflow after local verification and before merge. Address findings before final branch completion.

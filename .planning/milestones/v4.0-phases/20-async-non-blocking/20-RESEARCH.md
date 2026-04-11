# Phase 20: Async/Non-blocking - Research

**Researched:** 2026-01-23
**Domain:** R async job processing with Plumber + mirai
**Confidence:** HIGH

## Summary

Phase 20 converts long-running API operations (functional clustering via STRING-db, phenotype clustering via MCA, and ontology updates) into async jobs that return HTTP 202 immediately with job IDs for polling. The locked decisions mandate using the mirai package for async execution, following RFC 9110 for HTTP 202 Accepted patterns, and implementing in-memory job state storage.

**Core findings:**
- mirai 2.5.3 (released Dec 2025) provides production-ready async evaluation with timeout support, error handling, and daemon connection pooling
- Plumber integrates with mirai via the promises package using the `%...>%` promise pipe
- HTTP 202 Accepted requires `Location` and `Retry-After` headers, plus status endpoint design
- R lacks built-in thread-safe concurrent data structures, requiring careful environment object management
- UUID package (1.2-1) provides cryptographically secure job IDs

**Primary recommendation:** Use mirai daemon pool with dispatcher enabled for variable-length jobs, store job state in R environment objects (not reactiveValues, which are Shiny-specific), implement exponential backoff for transient retries, and set per-job timeouts via mirai's `.timeout` parameter.

## Standard Stack

The established libraries/tools for async R API endpoints:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mirai | 2.5.3 | Async task execution | Official r-lib package, powers Shiny ExtendedTask and tidymodels parallelization. Built on nanonext/NNG for reliable IPC/TCP. |
| promises | Latest | Promise integration | Required bridge between mirai and Plumber. Provides `%...>%` pipe for chaining async results. |
| plumber | Latest | REST API framework | Existing project framework. Native async support since v1.1.0 via promises integration. |
| uuid | 1.2-1 | Job ID generation | Standard CRAN package for UUIDv4 generation. Provides cryptographically secure unguessable IDs. |
| pool | Latest | DB connection pooling | Already in project. Thread-safe connection management for async DB queries. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| R.utils | Latest | Timeout utilities | Fallback for non-mirai timeouts (mirai has native `.timeout` parameter). |
| later | Latest | Scheduled cleanup | Background sweep of expired jobs. Plumber uses this internally for event loop. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| mirai | future + promises | future is more established but mirai is faster (nanonext/NNG backend), has better timeout handling, and is now the recommended backend for Shiny/tidymodels. Decision locked per ASYNC-01. |
| In-memory state | Redis/database | Persistence across restarts, but adds external dependency. Decision locked: in-memory only per CONTEXT.md. |
| Polling | WebSockets | Real-time updates, but requires client changes and connection management. Decision locked: polling pattern. |

**Installation:**
```r
install.packages(c("mirai", "promises", "uuid"))
# plumber and pool already in project
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── endpoints/
│   ├── analysis_endpoints.R      # Convert to async job submission
│   ├── ontology_endpoints.R      # Add async update endpoint
│   └── jobs_endpoints.R          # NEW: Job status polling
├── functions/
│   ├── job-manager.R             # NEW: Job state management
│   └── async-helpers.R           # NEW: mirai + Plumber integration
└── sysndd_plumber.R              # Initialize daemon pool on startup
```

### Pattern 1: Async Job Submission with mirai + Plumber
**What:** Endpoint immediately returns HTTP 202 with job ID, background task executes in mirai daemon.
**When to use:** Any operation taking >2 seconds (clustering, ontology updates, large queries).
**Example:**
```r
# Source: https://mirai.r-lib.org/articles/plumber.html
library(mirai)
library(plumber)
library(promises)

#* @post /jobs/clustering/submit
function(req, res) {
  # Generate job ID
  job_id <- uuid::UUIDgenerate()

  # Extract request data (MUST do before mirai)
  # Connection objects (req$postBody) are not serializable
  genes_list <- req$argsBody$genes

  # Create async task
  m <- mirai(
    {
      # This runs in background daemon
      Sys.sleep(5)  # Simulate long operation
      gen_string_clust_obj(genes)
    },
    genes = genes_list,
    .timeout = 1800000  # 30 min in milliseconds
  )

  # Store job state
  jobs_env[[job_id]] <- list(
    status = "pending",
    mirai_obj = m,
    submitted_at = Sys.time(),
    result = NULL,
    error = NULL
  )

  # Use promise pipe to update state when complete
  m %...>% (function(result) {
    jobs_env[[job_id]]$status <- "completed"
    jobs_env[[job_id]]$result <- result
    jobs_env[[job_id]]$completed_at <- Sys.time()
  })

  # Return HTTP 202 immediately
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", job_id, "/status"))
  res$setHeader("Retry-After", "5")  # Suggest 5-second polling

  list(
    job_id = job_id,
    status = "accepted",
    estimated_seconds = 30,
    status_url = paste0("/api/jobs/", job_id, "/status")
  )
}
```

### Pattern 2: Job Status Polling Endpoint
**What:** Client polls this endpoint with job ID to check progress and retrieve results.
**When to use:** Companion to every async job submission endpoint.
**Example:**
```r
# Combines Azure pattern + mirai status checking
#* @get /jobs/<job_id>/status
function(job_id, res) {
  # Validate job exists
  if (!exists(job_id, envir = jobs_env)) {
    res$status <- 404
    return(list(error = "Job not found"))
  }

  job <- jobs_env[[job_id]]
  m <- job$mirai_obj

  # Check mirai status
  if (unresolved(m)) {
    # Job still running
    res$setHeader("Retry-After", "5")
    return(list(
      job_id = job_id,
      status = "running",
      step = "Processing clustering analysis...",
      estimated_seconds = 15
    ))
  } else {
    # Job finished - check for errors
    if (is_mirai_error(m$data) || is_error_value(m$data)) {
      res$status <- 200  # Not 500 - job completed, just failed
      return(list(
        job_id = job_id,
        status = "failed",
        error_code = "EXECUTION_ERROR",
        message = m$data$message
      ))
    } else {
      # Success - return results inline
      res$status <- 200
      return(list(
        job_id = job_id,
        status = "completed",
        completed_at = job$completed_at,
        result = m$data  # Results inline per CONTEXT.md
      ))
    }
  }
}
```

### Pattern 3: Daemon Pool Initialization
**What:** Set up mirai daemon pool at Plumber startup for request handling.
**When to use:** Once in sysndd_plumber.R startup hooks.
**Example:**
```r
# Source: https://mirai.r-lib.org/articles/mirai.html
library(mirai)

# In sysndd_plumber.R startup
daemons(
  n = 8,              # 8 workers for concurrent jobs (Claude's discretion: 5-10)
  dispatcher = TRUE,  # Enable for variable-length jobs
  autoexit = tools::SIGINT
)

# Create global job storage environment
jobs_env <- new.env(parent = emptyenv())

# Register cleanup on shutdown
onStop(function() {
  daemons(0)  # Shutdown all daemons
})
```

### Pattern 4: Duplicate Job Detection
**What:** Check if identical job is already running before submitting duplicate.
**When to use:** Jobs with expensive operations and identical inputs.
**Example:**
```r
# Generate deterministic job ID from inputs
job_key <- digest::digest(list(operation = "clustering", genes = genes_list))

# Check if already running
existing_jobs <- ls(jobs_env)
for (existing_id in existing_jobs) {
  job <- jobs_env[[existing_id]]
  if (job$key == job_key && job$status %in% c("pending", "running")) {
    res$status <- 409  # Conflict
    res$setHeader("Location", paste0("/api/jobs/", existing_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Identical job already running",
      existing_job_id = existing_id
    ))
  }
}
```

### Pattern 5: Background Cleanup Sweep
**What:** Periodically remove old completed/failed jobs from memory.
**When to use:** Run every hour to prevent memory leaks.
**Example:**
```r
# In sysndd_plumber.R startup
library(later)

cleanup_old_jobs <- function() {
  cutoff_time <- Sys.time() - (24 * 3600)  # 24 hours ago

  job_ids <- ls(jobs_env)
  removed_count <- 0

  for (job_id in job_ids) {
    job <- jobs_env[[job_id]]

    if (job$status %in% c("completed", "failed")) {
      completed_time <- job$completed_at %||% job$submitted_at

      if (completed_time < cutoff_time) {
        rm(list = job_id, envir = jobs_env)
        removed_count <- removed_count + 1
      }
    }
  }

  if (removed_count > 0) {
    message(sprintf("Cleaned up %d old jobs", removed_count))
  }
}

# Schedule hourly cleanup
later(cleanup_old_jobs, 3600, loop = TRUE)
```

### Pattern 6: Exponential Backoff Retry
**What:** Retry transient failures with increasing delays.
**When to use:** Network errors, temporary database unavailability.
**Example:**
```r
# Exponential backoff with jitter
# Source: AWS Prescriptive Guidance + Google Cloud patterns
retry_with_backoff <- function(expr, max_retries = 3) {
  for (attempt in 1:max_retries) {
    result <- tryCatch(
      expr,
      error = function(e) {
        # Check if transient (network, timeout, connection)
        is_transient <- grepl("timeout|connection|network", e$message, ignore.case = TRUE)

        if (!is_transient || attempt == max_retries) {
          stop(e)  # Fail immediately for logic errors or final attempt
        }

        # Calculate backoff: min((2^attempt + jitter), 64)
        base_delay <- min(2^attempt, 64)
        jitter <- runif(1, 0, 1)  # Random 0-1 seconds
        delay <- base_delay + jitter

        message(sprintf("Retry %d/%d after %.2fs: %s",
                       attempt, max_retries, delay, e$message))
        Sys.sleep(delay)

        return(NULL)  # Signal retry
      }
    )

    if (!is.null(result)) {
      return(result)
    }
  }
}
```

### Anti-Patterns to Avoid
- **Accessing req$postBody inside mirai:** Connection objects are not serializable. Extract data first, pass as arguments.
- **Using reactiveValues for job state:** reactiveValues is Shiny-specific. Use regular R environment objects for Plumber.
- **Returning HTTP 500 for job failures:** Use HTTP 200 with `"status": "failed"` in body. HTTP 500 means endpoint failed, not job.
- **Blocking on mirai results:** Never call `m[]` in endpoint. Use `unresolved(m)` to check status non-blocking, or promise pipes for callbacks.
- **Global variables in mirai tasks:** mirai runs in separate process. Pass all data explicitly as arguments or use `.args = list()`.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Async task execution | Custom fork/process pool | mirai package | mirai handles process lifecycle, serialization, timeouts, error propagation, and connection pooling. Building custom process management is 500+ lines and misses edge cases (zombie processes, connection leaks, signal handling). |
| UUID generation | `paste0(sample(letters), collapse="")` | uuid::UUIDgenerate() | Custom random strings are guessable and can collide. UUID v4 has 122 random bits (2^122 combinations) and is cryptographically secure. |
| Promise handling | Manual callbacks | promises package | promises provides composable async chains with error propagation. Manual callbacks lead to "callback hell" and lose error context. |
| Timeout enforcement | `setTimeLimit()` | mirai `.timeout` parameter | setTimeLimit() is per-session and doesn't work for system calls. mirai timeouts are per-task, work across process boundaries, and auto-cancel with dispatcher enabled. |
| Job deduplication | Array scanning | digest::digest() for keys | Hashing job parameters produces deterministic, constant-time lookup keys. Manual comparison is O(n) and error-prone for complex objects. |
| Exponential backoff | Linear delays | Formula: `min((2^n + jitter), max)` | Linear delays waste time and risk thundering herd. Exponential backoff with jitter is industry standard (AWS, Google, Azure) and proven to prevent synchronized retries. |

**Key insight:** R's async ecosystem is less mature than Node.js/Python, but mirai fills the gap with production-ready primitives. Don't reinvent concurrency - use mirai's battle-tested implementation.

## Common Pitfalls

### Pitfall 1: R Environment Thread Safety
**What goes wrong:** Concurrent access to R environment objects corrupts state (race conditions, lost updates).
**Why it happens:** R environments have reference semantics but no built-in locking. Multiple mirai tasks modifying `jobs_env` simultaneously can interleave operations.
**How to avoid:**
- Keep job state immutable after creation (never update, only replace)
- Use atomic operations for critical updates (tryCatch + exists())
- Consider using a single-threaded "coordinator" pattern for state updates
**Warning signs:**
- Job status randomly becomes NULL
- Duplicate job IDs appear
- Jobs disappear from `ls(jobs_env)`

### Pitfall 2: Connection Object Serialization
**What goes wrong:** Endpoint crashes with "cannot serialize connection" error when passing `req$postBody` or database connections to mirai.
**Why it happens:** mirai runs in separate process. R connections (file handles, sockets, DB cursors) cannot cross process boundaries.
**How to avoid:**
- Always extract `req$postBody`, `req$argsBody` BEFORE mirai call
- Pass extracted data as explicit arguments: `mirai(func(data), data = req$argsBody)`
- Use connection pool inside mirai task, don't pass pool object
**Warning signs:**
- Error message mentions "serialize" or "connection"
- Works in testing, fails in async execution
- Code pattern: `mirai({ use(req$postBody) })` (WRONG)

### Pitfall 3: Timeout Units Confusion
**What goes wrong:** Job times out after 1 second instead of 1 hour because timeout is in milliseconds, not seconds.
**Why it happens:** mirai `.timeout` parameter is milliseconds. R developers expect seconds (like `Sys.sleep()`).
**How to avoid:**
- Always calculate: `timeout_ms <- timeout_seconds * 1000`
- Use named constant: `THIRTY_MINUTES_MS <- 30 * 60 * 1000`
- Add unit suffix to variable names: `timeout_ms` not `timeout`
**Warning signs:**
- Jobs timeout immediately despite long timeout values
- `.timeout = 1800` times out in <2 seconds (should be `.timeout = 1800000`)

### Pitfall 4: Job Status Race Condition
**What goes wrong:** Client polls for status, gets "running", but job actually just finished. Next poll shows "completed" but client already gave up.
**Why it happens:** `unresolved(m)` check and result access are not atomic. Job can complete between check and status response.
**How to avoid:**
- Always check `unresolved()` AFTER reading job state from env
- Use mirai error functions (`is_mirai_error()`) which handle resolved state
- Cache job state in environment when mirai completes (via promise pipe)
**Warning signs:**
- Client reports "Job stuck in running state"
- Logs show completed jobs still returning "running" status
- Race happens more often under high load

### Pitfall 5: Daemon Pool Exhaustion
**What goes wrong:** All 8 daemons busy, new job submissions block indefinitely waiting for free daemon.
**Why it happens:** Daemon pool is finite. Long-running jobs (30 min timeout) can exhaust pool if submission rate exceeds completion rate.
**How to avoid:**
- Set global concurrent job limit (e.g., 8 daemons = max 8 jobs)
- Return HTTP 503 Service Unavailable when limit reached
- Include `Retry-After` header suggesting when capacity may be available
- Monitor daemon pool: `status()` shows daemon availability
**Warning signs:**
- API becomes unresponsive after N concurrent jobs
- `status()` shows "all daemons busy"
- New submissions hang instead of returning immediately

### Pitfall 6: Memory Leak from Old Jobs
**What goes wrong:** Server memory grows unbounded as completed job results accumulate in `jobs_env`.
**Why it happens:** R environments don't auto-expire. Completed job results stay in memory until explicitly removed.
**How to avoid:**
- Implement background cleanup sweep (Pattern 5)
- Set retention policy: 24 hours for completed, 1 hour for failed
- Limit result size: Truncate large results or return references
- Monitor: `object.size(jobs_env)` and `length(ls(jobs_env))`
**Warning signs:**
- Server memory usage grows over days without plateauing
- `ls(jobs_env)` shows thousands of old job IDs
- OOM crashes after weeks of uptime

### Pitfall 7: Error Value Misinterpretation
**What goes wrong:** Job returns error value 5 (timeout) but code treats it as successful result `5`.
**Why it happens:** mirai returns special numeric error codes (5=timeout, 20=canceled) that look like valid results.
**How to avoid:**
- ALWAYS check `is_mirai_error()` and `is_error_value()` before using `m$data`
- Never assume `m$data` is your result type without validation
- Use explicit error handling: `if (is_error_value(m$data)) { handle_error() }`
**Warning signs:**
- Clustering returns "5 clusters" after timeout (should be error)
- Numeric results suspiciously equal to 5, 20, or other error codes
- Error messages missing from failed jobs

## Code Examples

Verified patterns from official sources:

### Complete Async Job Manager (Job State Management)
```r
# api/functions/job-manager.R
# Combines patterns from mirai + Azure async patterns

# Global job storage
jobs_env <- new.env(parent = emptyenv())

# Max concurrent jobs (Claude's discretion: 8 based on daemon pool)
MAX_CONCURRENT_JOBS <- 8

create_job <- function(operation, params, executor_fn) {
  # Check capacity
  running_count <- sum(sapply(ls(jobs_env), function(id) {
    jobs_env[[id]]$status %in% c("pending", "running")
  }))

  if (running_count >= MAX_CONCURRENT_JOBS) {
    return(list(
      error = "CAPACITY_EXCEEDED",
      message = sprintf("Maximum %d concurrent jobs. Try again later.", MAX_CONCURRENT_JOBS),
      retry_after = 60
    ))
  }

  # Generate job ID
  job_id <- uuid::UUIDgenerate()

  # Create async task with timeout
  m <- mirai(
    executor_fn(params),
    params = params,
    executor_fn = executor_fn,
    .timeout = 1800000  # 30 minutes
  )

  # Store job state
  jobs_env[[job_id]] <- list(
    job_id = job_id,
    operation = operation,
    status = "pending",
    mirai_obj = m,
    submitted_at = Sys.time(),
    params_hash = digest::digest(params),
    result = NULL,
    error = NULL,
    completed_at = NULL
  )

  # Attach completion callback
  m %...>% (function(result) {
    if (is_mirai_error(result) || is_error_value(result)) {
      jobs_env[[job_id]]$status <- "failed"
      jobs_env[[job_id]]$error <- list(
        code = "EXECUTION_ERROR",
        message = result$message %||% "Job execution failed"
      )
    } else {
      jobs_env[[job_id]]$status <- "completed"
      jobs_env[[job_id]]$result <- result
    }
    jobs_env[[job_id]]$completed_at <- Sys.time()
  })

  return(list(
    job_id = job_id,
    status = "accepted",
    estimated_seconds = 30
  ))
}

get_job_status <- function(job_id) {
  if (!exists(job_id, envir = jobs_env)) {
    return(list(error = "JOB_NOT_FOUND", message = "Job ID not found"))
  }

  job <- jobs_env[[job_id]]
  m <- job$mirai_obj

  # Determine current status
  if (unresolved(m)) {
    # Still running - check if timed out
    elapsed <- as.numeric(difftime(Sys.time(), job$submitted_at, units = "secs"))
    remaining <- max(0, 1800 - elapsed)  # 30 min = 1800 sec

    return(list(
      job_id = job_id,
      status = "running",
      step = get_progress_message(job$operation),
      estimated_seconds = remaining,
      retry_after = 5
    ))
  } else {
    # Completed - return cached state
    return(list(
      job_id = job_id,
      status = job$status,
      completed_at = job$completed_at,
      result = job$result,
      error = job$error
    ))
  }
}

get_progress_message <- function(operation) {
  # Claude's discretion: specific step descriptions
  messages <- list(
    clustering = "Fetching interaction data from STRING-db...",
    phenotype_clustering = "Running Multiple Correspondence Analysis...",
    ontology_update = "Fetching ontology data from external sources..."
  )

  messages[[operation]] %||% "Processing request..."
}

check_duplicate_job <- function(operation, params) {
  params_hash <- digest::digest(params)

  for (job_id in ls(jobs_env)) {
    job <- jobs_env[[job_id]]

    if (job$operation == operation &&
        job$params_hash == params_hash &&
        job$status %in% c("pending", "running")) {
      return(list(
        duplicate = TRUE,
        existing_job_id = job_id
      ))
    }
  }

  return(list(duplicate = FALSE))
}

cleanup_old_jobs <- function() {
  cutoff_time <- Sys.time() - (24 * 3600)  # 24 hours
  removed <- 0

  for (job_id in ls(jobs_env)) {
    job <- jobs_env[[job_id]]

    if (job$status %in% c("completed", "failed")) {
      end_time <- job$completed_at %||% job$submitted_at

      if (end_time < cutoff_time) {
        rm(list = job_id, envir = jobs_env)
        removed <- removed + 1
      }
    }
  }

  if (removed > 0) {
    message(sprintf("[%s] Cleaned up %d old jobs", Sys.time(), removed))
  }
}
```

### Daemon Pool Initialization (Startup Hook)
```r
# In sysndd_plumber.R
# Source: https://mirai.r-lib.org/articles/mirai.html

library(mirai)
library(later)

# Initialize daemon pool
# Claude's discretion: 8 daemons for 5-10 concurrent job target
daemons(
  n = 8,
  dispatcher = TRUE,  # Enable for variable-length jobs
  autoexit = tools::SIGINT
)

message(sprintf("[%s] Started mirai daemon pool with 8 workers", Sys.time()))

# Schedule hourly cleanup
later(function() {
  cleanup_old_jobs()
  later(sys.frame(), 3600, loop = TRUE)  # Re-schedule
}, 3600)

# Shutdown hook
onStop(function() {
  message(sprintf("[%s] Shutting down daemon pool", Sys.time()))
  daemons(0)
})
```

### Async Endpoint Template (Clustering)
```r
# api/endpoints/jobs_endpoints.R
# Combines mirai + Plumber patterns

#* Submit Functional Clustering Job
#* @tag jobs
#* @serializer json list(na="string")
#* @post /jobs/clustering/submit
function(req, res) {
  # Extract genes list BEFORE mirai
  genes_list <- req$argsBody$genes

  if (is.null(genes_list) || length(genes_list) == 0) {
    res$status <- 400
    return(list(error = "INVALID_INPUT", message = "genes list required"))
  }

  # Check for duplicates
  dup_check <- check_duplicate_job("clustering", list(genes = genes_list))
  if (dup_check$duplicate) {
    res$status <- 409
    res$setHeader("Location", paste0("/api/jobs/", dup_check$existing_job_id, "/status"))
    return(list(
      error = "DUPLICATE_JOB",
      message = "Identical job already running",
      existing_job_id = dup_check$existing_job_id
    ))
  }

  # Create job
  result <- create_job(
    operation = "clustering",
    params = list(genes = genes_list),
    executor_fn = function(params) {
      # This runs in mirai daemon
      gen_string_clust_obj(params$genes)
    }
  )

  # Check capacity
  if (!is.null(result$error)) {
    res$status <- 503
    res$setHeader("Retry-After", result$retry_after)
    return(result)
  }

  # Success - return HTTP 202
  res$status <- 202
  res$setHeader("Location", paste0("/api/jobs/", result$job_id, "/status"))
  res$setHeader("Retry-After", "5")

  list(
    job_id = result$job_id,
    status = result$status,
    estimated_seconds = result$estimated_seconds,
    status_url = paste0("/api/jobs/", result$job_id, "/status")
  )
}

#* Get Job Status
#* @tag jobs
#* @serializer json list(na="string")
#* @get /jobs/<job_id>/status
function(job_id, res) {
  status <- get_job_status(job_id)

  if (!is.null(status$error) && status$error == "JOB_NOT_FOUND") {
    res$status <- 404
    return(status)
  }

  # Set Retry-After for running jobs
  if (status$status == "running") {
    res$setHeader("Retry-After", as.character(status$retry_after))
  }

  res$status <- 200
  return(status)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| future + promises | mirai + promises | 2024-2025 | mirai is now recommended async backend for Shiny (ExtendedTask) and tidymodels. Faster (nanonext/NNG), better timeout handling, cleaner API. future still viable but mirai is the future. |
| Blocking endpoints | HTTP 202 Accepted | RFC 9110 (2022) | Industry standard for long-running operations. Frees connections, prevents timeouts, enables horizontal scaling. |
| Custom process pools | mirai daemons | mirai 1.0+ (2023) | mirai handles process lifecycle, connection pooling, serialization edge cases. Custom pools are 500+ LOC and miss edge cases. |
| Global variables for state | Environment objects | Always | R best practice: environments have reference semantics, avoiding copy-on-modify. Global assignments are implicit and error-prone. |
| Linear retry delays | Exponential backoff + jitter | AWS/Google patterns (2020+) | Prevents thundering herd, faster recovery. Jitter prevents synchronized retries across clients. |

**Deprecated/outdated:**
- **setTimeLimit() for async timeouts**: Doesn't work for system calls, is per-session not per-task. Use mirai `.timeout` parameter instead.
- **reactiveValues in Plumber**: Shiny-specific, requires reactive context. Use regular environment objects for Plumber APIs.
- **foreach/doParallel for API async**: Designed for batch processing, not request-response. Use mirai for API async execution.

## Open Questions

Things that couldn't be fully resolved:

1. **Exact concurrent job limit**
   - What we know: CONTEXT.md suggests 5-10 range, depends on job duration and server resources
   - What's unclear: Optimal balance between throughput and resource exhaustion
   - Recommendation: Start with 8 (matches 8 daemon pool), monitor daemon status and memory, tune down if exhaustion occurs

2. **Retry delay strategy**
   - What we know: Exponential backoff with jitter is industry standard (AWS, Google)
   - What's unclear: Exact formula - start at 250ms or 1s? Cap at 32s or 64s?
   - Recommendation: Use `min((2^attempt + runif(0,1)), 64)` seconds. Start 2s, max 64s. Adjust if logs show premature failures.

3. **Sweep interval tuning**
   - What we know: CONTEXT.md suggests hourly, cleanup is 24-hour retention
   - What's unclear: Impact on memory vs cleanup overhead
   - Recommendation: Start hourly, monitor `object.size(jobs_env)`. If memory grows, increase frequency to 30 min. If cleanup overhead is high (>1% CPU), decrease to 2 hours.

4. **Daemon pool size for variable-length jobs**
   - What we know: dispatcher = TRUE balances variable-length jobs, 8 daemons chosen
   - What's unclear: Whether 8 is optimal for mix of 5s jobs (clustering with few genes) and 30min jobs (full database clustering)
   - Recommendation: Profile actual job durations in production. If short jobs dominate, consider increasing to 12. If long jobs dominate, consider decreasing to 5-6 to prevent queue buildup.

5. **R environment thread safety at scale**
   - What we know: R environments lack built-in locking, concurrent access can corrupt state
   - What's unclear: Whether single-threaded updates are sufficient or if atomic operations/locks needed
   - Recommendation: Start with immutable job state (never update, only replace). If race conditions occur, consider using a "coordinator" pattern or file-based locking.

## Sources

### Primary (HIGH confidence)
- [mirai package documentation v2.5.3](https://mirai.r-lib.org/) - Core async execution patterns, daemon configuration, timeout/error handling
- [mirai CRAN vignette](https://cran.r-project.org/web/packages/mirai/vignettes/mirai.html) - Quick reference with usage examples
- [mirai + Plumber integration](https://mirai.r-lib.org/articles/plumber.html) - Official integration guide with GET/POST patterns
- [Plumber async test suite](https://github.com/rstudio/plumber/blob/main/tests/testthat/test-async.R) - Promise handling patterns, hook system integration
- [HTTP 202 Accepted - RFC 9110](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/202) - Official HTTP specification
- [Azure Async Request-Reply Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/async-request-reply) - Location/Retry-After headers, polling strategy, timeout handling

### Secondary (MEDIUM confidence)
- [uuid package v1.2-1](https://cran.r-project.org/web/packages/uuid/uuid.pdf) - UUIDgenerate() for job IDs
- [Plumber rendering output](https://www.rplumber.io/articles/rendering-output.html) - res$setHeader() usage
- [REST API Tutorial - HTTP 202](https://restfulapi.net/http-status-202-accepted/) - Best practices for 202 responses
- [R thread safety guide](https://developer.r-project.org/RThreads/guide.html) - Environment object concurrency limitations
- [Retry-After header - MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Retry-After) - Header format and use cases

### Secondary (MEDIUM confidence - verified with official docs)
- [R.utils timeout functions](https://search.r-project.org/CRAN/refmans/R.utils/help/withTimeout.html) - Alternative timeout approach (mirai preferred)
- [Exponential backoff - AWS](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/retry-backoff.html) - Retry formula with jitter
- [Exponential backoff - Google Cloud](https://docs.google.com/memorystore/docs/redis/exponential-backoff) - Backoff calculation formula

### Tertiary (LOW confidence - WebSearch only)
- [State Management in 2026](https://www.nucamp.co/blog/state-management-in-2026-redux-context-api-and-modern-patterns) - General state management patterns
- [Node.js async best practices](https://nodejsbestpractices.com/sections/errorhandling/asyncerrorhandling/) - Error handling patterns (JS, adapted to R)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - mirai is official r-lib package with production deployments (Shiny, tidymodels), recently updated (Dec 2025)
- Architecture: HIGH - Patterns verified from official mirai + Plumber documentation, Azure architecture patterns are industry standard
- Pitfalls: MEDIUM-HIGH - Connection serialization and timeout units verified from mirai docs. Thread safety issues inferred from R internals guide. Race conditions are general async concerns.

**Research date:** 2026-01-23
**Valid until:** 2026-02-23 (30 days - mirai is stable, R ecosystem moves slowly)

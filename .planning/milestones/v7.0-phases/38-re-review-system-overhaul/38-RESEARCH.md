# Phase 38: Re-Review System Overhaul - Research

**Researched:** 2026-01-26
**Domain:** Batch management systems, dynamic query building, form criteria selection
**Confidence:** HIGH

## Summary

Re-review system overhaul requires implementing a dynamic batch management system with criteria-based selection, assignment workflows, and lifecycle tracking. The phase replaces a hardcoded pre-computed batch system with a flexible approach where admins create batches dynamically based on date ranges, gene lists, status filters, and other criteria.

The standard approach is:
1. **Service layer pattern** - Create `re-review-service.R` following existing service patterns (`entity-service.R`, `status-service.R`) with functions for batch creation, entity assignment, and lifecycle management
2. **Parameterized dynamic queries** - Build WHERE clauses conditionally using R's glue_sql with DBI parameterized queries for SQL injection prevention
3. **Transaction-wrapped operations** - Use `db_with_transaction()` for multi-step batch creation to ensure atomicity
4. **Single-form UI with optional preview** - All criteria selection on one screen using Bootstrap-Vue-Next BFormSelect (with `multiple` attribute), optional preview button to show matching entities before creation
5. **Auto-increment batch IDs** - Sequential integer IDs for batches (simpler than UUIDs for single-database system, better for ordering and display)
6. **Soft delete with lifecycle states** - Track batch state (Created → Assigned → Completed) with `is_active` flag for soft deletes

**Primary recommendation:** Follow entity-service.R and status-service.R patterns for service layer architecture. Use db_with_transaction() for batch creation atomicity. Build dynamic WHERE clauses with glue_sql and parameterized queries. Reuse AutocompleteInput pattern for entity search. Use Bootstrap-Vue-Next BFormSelect with multiple=true for multi-select fields.

## Standard Stack

The established libraries/tools for this domain:

### Core - Backend (R/Plumber)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Plumber | Current | REST API framework | Existing API infrastructure, RESTful endpoint decoration |
| DBI | Current | Database interface | Parameterized queries, transaction support |
| RMariaDB | Current | MariaDB driver | Database connectivity with prepared statements |
| pool | Current | Connection pooling | Efficient connection management, used globally |
| glue | Current | Dynamic SQL building | Safe string interpolation with glue_sql() |
| dplyr | Current | Data manipulation | Pipeline operations, table queries |
| logger | Current | Logging | Structured logging already in use |

### Core - Frontend (Vue 3)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Vue 3 | 3.5.25 | Framework | Composition API for form logic |
| Bootstrap-Vue-Next | 0.42.0 | UI Components | BFormSelect with multiple attribute, BFormInput |
| TypeScript | 5.9.3 | Type safety | Form data structures, API responses |
| Axios | 1.13.2 | HTTP client | API calls for batch operations |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| tibble | Current | Data frames | Service layer data structures |
| purrr | Current | Functional programming | Data transformation in services |
| rlang | Current | Error handling | Structured errors with abort() |
| vue3-datepicker | Latest | Date range picker | For date range criteria selection |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Auto-increment IDs | UUIDs | UUIDs better for distributed systems, but unnecessary overhead for single-database; auto-increment simpler for ordering |
| glue_sql | String concatenation | String concat vulnerable to SQL injection |
| Soft delete | Hard delete + archive table | Archive table adds complexity; soft delete simpler for audit trail |
| BFormSelect multiple | PrimeVue TreeSelect | User decided on Bootstrap-Vue-Next consistency (from CONTEXT) |
| Manual SQL builders | sqlq package | sqlq adds dependency; glue_sql sufficient for conditional WHERE |

**Installation:**
```bash
# Backend (if needed, most already installed)
R -e "install.packages(c('glue', 'purrr'))"

# Frontend
cd app
npm install vue3-datepicker  # Only if date picker not already available
```

## Architecture Patterns

### Recommended Project Structure
```
api/
├── services/
│   └── re-review-service.R        # NEW: Batch management business logic
├── endpoints/
│   └── re_review_endpoints.R      # MODIFY: Add batch creation endpoints
├── functions/
│   ├── db-helpers.R               # EXISTS: Use db_with_transaction()
│   └── query-builders.R           # NEW (optional): Dynamic WHERE clause helpers
└── tests/
    └── testthat/
        └── test-re-review-service.R  # NEW: Service layer tests

app/src/
├── views/
│   └── curate/
│       ├── ManageReReview.vue          # MODIFY: Add batch creation UI
│       └── composables/
│           └── useBatchForm.ts         # NEW: Batch creation form logic
└── components/
    └── forms/
        ├── AutocompleteInput.vue       # EXISTS: Reuse for entity search
        └── BatchCriteriaForm.vue       # NEW: Criteria selection component
```

### Pattern 1: Service Layer with Transaction Wrapper
**What:** Service function encapsulates batch creation logic with transaction safety
**When to use:** Any multi-step operation requiring atomicity (batch + entities + assignment)

**Example:**
```r
# Source: Based on existing entity-service.R and status-service.R patterns
# api/services/re-review-service.R

#' Create a new re-review batch with dynamic criteria
#'
#' @param criteria List with date_range, gene_list, status_filter, disease_id, batch_size
#' @param assigned_user_id Optional user_id to assign batch to (can be NULL)
#' @param batch_name Optional custom batch name (auto-generated if NULL)
#' @param pool Database connection pool
#' @return List with status, message, and batch_id
batch_create <- function(criteria, assigned_user_id = NULL, batch_name = NULL, pool) {
  # Validate criteria
  if (is.null(criteria$date_range) && is.null(criteria$gene_list)) {
    stop("At least one selection criterion is required")
  }

  # Build dynamic WHERE clause
  where_conditions <- build_batch_where_clause(criteria)

  # Use transaction for atomicity
  result <- db_with_transaction({
    # 1. Create batch record
    batch_data <- tibble::tibble(
      batch_name = batch_name %||% generate_batch_name(),
      created_at = Sys.time(),
      criteria_json = jsonlite::toJSON(criteria, auto_unbox = TRUE),
      is_active = TRUE,
      status = if (!is.null(assigned_user_id)) "Assigned" else "Created"
    )

    db_execute_statement(
      "INSERT INTO re_review_batch (batch_name, created_at, criteria_json, is_active, status) VALUES (?, ?, ?, ?, ?)",
      list(batch_data$batch_name, batch_data$created_at, batch_data$criteria_json,
           batch_data$is_active, batch_data$status)
    )

    # Get batch_id
    batch_id_result <- db_execute_query("SELECT LAST_INSERT_ID() as batch_id")
    batch_id <- batch_id_result$batch_id[1]

    # 2. Find matching entities (with batch size limit)
    query <- glue::glue_sql("
      SELECT DISTINCT e.entity_id
      FROM ndd_entity_view e
      LEFT JOIN ndd_entity_review r ON e.entity_id = r.entity_id AND r.is_primary = 1
      WHERE {where_conditions}
      AND e.entity_id NOT IN (
        SELECT entity_id FROM re_review_entity_connect
        WHERE re_review_batch IN (
          SELECT re_review_batch FROM re_review_assignment WHERE is_active = 1
        )
      )
      ORDER BY r.review_date ASC
      LIMIT {criteria$batch_size %||% 20}
    ", .con = pool)

    matching_entities <- db_execute_query(query)

    if (nrow(matching_entities) == 0) {
      stop("No entities match the specified criteria")
    }

    # 3. Create re_review_entity_connect records
    for (entity_id in matching_entities$entity_id) {
      db_execute_statement(
        "INSERT INTO re_review_entity_connect (entity_id, re_review_batch, status_id, review_id)
         SELECT ?, ?, status_id, review_id FROM ndd_entity_view WHERE entity_id = ?",
        list(entity_id, batch_id, entity_id)
      )
    }

    # 4. Create assignment if user specified
    if (!is.null(assigned_user_id)) {
      db_execute_statement(
        "INSERT INTO re_review_assignment (user_id, re_review_batch) VALUES (?, ?)",
        list(assigned_user_id, batch_id)
      )
    }

    logger::log_info("Batch created",
      batch_id = batch_id,
      entity_count = nrow(matching_entities),
      assigned_to = assigned_user_id
    )

    list(batch_id = batch_id, entity_count = nrow(matching_entities))
  }, pool_obj = pool)

  list(
    status = 200,
    message = "Batch created successfully",
    entry = result
  )
}
```

### Pattern 2: Dynamic WHERE Clause Builder
**What:** Helper function builds SQL WHERE conditions based on provided criteria
**When to use:** Variable filter combinations (date range + gene list + status + disease)

**Example:**
```r
# Source: Based on glue_sql patterns and DBI parameterized queries
# https://cran.r-project.org/web/packages/DBI/vignettes/DBI-advanced.html

#' Build WHERE clause from batch criteria
#'
#' @param criteria List with optional date_range, gene_list, status_filter, disease_id
#' @return SQL WHERE clause string (without WHERE keyword)
build_batch_where_clause <- function(criteria) {
  conditions <- character(0)

  # Date range filter
  if (!is.null(criteria$date_range)) {
    conditions <- c(conditions, glue::glue_sql(
      "r.review_date BETWEEN {criteria$date_range$start} AND {criteria$date_range$end}",
      .con = pool
    ))
  }

  # Gene list filter (HGNC IDs)
  if (!is.null(criteria$gene_list) && length(criteria$gene_list) > 0) {
    gene_placeholders <- paste(rep("?", length(criteria$gene_list)), collapse = ", ")
    conditions <- c(conditions, glue::glue("e.hgnc_id IN ({gene_placeholders})"))
  }

  # Status filter
  if (!is.null(criteria$status_filter)) {
    conditions <- c(conditions, glue::glue_sql(
      "s.category_id = {criteria$status_filter}",
      .con = pool
    ))
  }

  # Disease filter
  if (!is.null(criteria$disease_id)) {
    conditions <- c(conditions, glue::glue_sql(
      "e.disease_ontology_id_version LIKE {paste0(criteria$disease_id, '%')}",
      .con = pool
    ))
  }

  # Combine with AND
  if (length(conditions) == 0) {
    return("1=1")  # No filters, match all
  }

  paste(conditions, collapse = " AND ")
}
```

### Pattern 3: Single-Form Batch Creation UI
**What:** All criteria on one screen with optional preview, following user decisions from CONTEXT
**When to use:** Batch creation workflow with multiple criteria types

**Example:**
```vue
<!-- Source: Bootstrap-Vue-Next BFormSelect with multiple attribute -->
<!-- https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-select -->
<template>
  <BCard header="Create Re-Review Batch" class="mb-3">
    <BForm @submit.prevent="handleSubmit">
      <!-- Batch Name (optional) -->
      <BFormGroup label="Batch Name (optional)" label-for="batch-name">
        <BFormInput
          id="batch-name"
          v-model="formData.batch_name"
          placeholder="Auto-generated if empty"
        />
        <BFormText>Leave empty for auto-generated name (e.g., "Batch 2026-01-26")</BFormText>
      </BFormGroup>

      <!-- Date Range -->
      <BFormGroup label="Review Date Range" label-for="date-range">
        <div class="d-flex gap-2">
          <BFormInput
            id="date-start"
            v-model="formData.date_start"
            type="date"
            placeholder="Start date"
          />
          <BFormInput
            id="date-end"
            v-model="formData.date_end"
            type="date"
            placeholder="End date"
          />
        </div>
        <BFormText>Include entities reviewed between these dates</BFormText>
      </BFormGroup>

      <!-- Gene List (multi-select) -->
      <BFormGroup label="Genes (optional)" label-for="gene-select">
        <BFormSelect
          id="gene-select"
          v-model="formData.gene_list"
          :options="geneOptions"
          multiple
          :select-size="8"
          :state="geneSelectState"
        >
          <template #first>
            <option :value="null" disabled>-- Select genes --</option>
          </template>
        </BFormSelect>
        <BFormText>Hold Ctrl/Cmd to select multiple genes</BFormText>
      </BFormGroup>

      <!-- Status Filter -->
      <BFormGroup label="Status Filter (optional)" label-for="status-filter">
        <BFormSelect
          id="status-filter"
          v-model="formData.status_filter"
          :options="statusOptions"
        />
      </BFormGroup>

      <!-- Batch Size -->
      <BFormGroup label="Batch Size" label-for="batch-size">
        <BFormInput
          id="batch-size"
          v-model.number="formData.batch_size"
          type="number"
          min="1"
          max="100"
        />
        <BFormText>Maximum number of entities in this batch (default: 20)</BFormText>
      </BFormGroup>

      <!-- User Assignment -->
      <BFormGroup label="Assign to User (optional)" label-for="user-select">
        <BFormSelect
          id="user-select"
          v-model="formData.assigned_user_id"
          :options="userOptions"
        />
        <BFormText>Leave unassigned to assign later</BFormText>
      </BFormGroup>

      <!-- Actions -->
      <div class="d-flex gap-2">
        <BButton
          variant="outline-primary"
          @click="handlePreview"
          :disabled="isLoading"
        >
          <i class="bi bi-eye" /> Preview Matching Entities
        </BButton>
        <BButton
          type="submit"
          variant="primary"
          :disabled="isLoading || !isFormValid"
        >
          <i class="bi bi-plus-circle" /> Create Batch
        </BButton>
      </div>
    </BForm>

    <!-- Preview Modal (optional) -->
    <BModal
      v-model="showPreviewModal"
      title="Preview Matching Entities"
      size="lg"
      ok-only
    >
      <BTable
        v-if="previewEntities.length > 0"
        :items="previewEntities"
        :fields="previewFields"
        small
        striped
      />
      <div v-else class="text-muted">
        No entities match the selected criteria
      </div>
    </BModal>
  </BCard>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useBatchForm } from './composables/useBatchForm';

const {
  formData,
  isLoading,
  geneOptions,
  statusOptions,
  userOptions,
  previewEntities,
  previewFields,
  showPreviewModal,
  isFormValid,
  handlePreview,
  handleSubmit,
} = useBatchForm();
</script>
```

### Pattern 4: Batch Lifecycle State Management
**What:** Simple 3-state lifecycle (Created → Assigned → Completed) with soft delete
**When to use:** Tracking batch progress and preventing modifications to in-progress batches

**Example:**
```r
# Source: Soft delete pattern best practices
# https://www.geeksforgeeks.org/mongodb/soft-delete-pattern-in-mongodb/

# Database schema additions needed:
# ALTER TABLE re_review_batch ADD COLUMN status ENUM('Created', 'Assigned', 'Completed') DEFAULT 'Created';
# ALTER TABLE re_review_batch ADD COLUMN is_active BOOLEAN DEFAULT TRUE;
# ALTER TABLE re_review_assignment ADD COLUMN is_active BOOLEAN DEFAULT TRUE;

#' Transition batch to next lifecycle state
#'
#' @param batch_id Integer batch ID
#' @param new_state Character: "Assigned" or "Completed"
#' @param pool Database connection pool
batch_transition_state <- function(batch_id, new_state, pool) {
  # Validate state transition
  current_batch <- db_execute_query(
    "SELECT status, is_active FROM re_review_batch WHERE re_review_batch = ?",
    list(batch_id)
  )

  if (nrow(current_batch) == 0) {
    stop("Batch not found")
  }

  if (!current_batch$is_active) {
    stop("Cannot modify inactive batch")
  }

  # Validate state machine
  valid_transitions <- list(
    Created = "Assigned",
    Assigned = "Completed"
  )

  if (valid_transitions[[current_batch$status]] != new_state) {
    stop(glue::glue("Invalid transition from {current_batch$status} to {new_state}"))
  }

  # Update state
  db_execute_statement(
    "UPDATE re_review_batch SET status = ? WHERE re_review_batch = ?",
    list(new_state, batch_id)
  )

  logger::log_info("Batch state transition",
    batch_id = batch_id,
    from = current_batch$status,
    to = new_state
  )

  list(status = 200, message = glue::glue("Batch transitioned to {new_state}"))
}

#' Soft delete (archive) a batch
#'
#' @param batch_id Integer batch ID
#' @param pool Database connection pool
batch_archive <- function(batch_id, pool) {
  # Only allow archiving of Created batches (not Assigned or Completed)
  current_batch <- db_execute_query(
    "SELECT status FROM re_review_batch WHERE re_review_batch = ?",
    list(batch_id)
  )

  if (current_batch$status != "Created") {
    stop("Can only archive batches in Created state")
  }

  db_execute_statement(
    "UPDATE re_review_batch SET is_active = FALSE WHERE re_review_batch = ?",
    list(batch_id)
  )

  logger::log_info("Batch archived", batch_id = batch_id)

  list(status = 200, message = "Batch archived")
}
```

### Anti-Patterns to Avoid
- **Manual string concatenation for SQL** - Use glue_sql() with parameterized queries; string concat creates SQL injection vulnerability
- **Missing transaction wrappers** - Batch creation involves multiple inserts; without transactions, partial failures leave orphaned records
- **Hard deletes without audit trail** - Soft delete with is_active flag preserves history for compliance
- **UUID overkill** - Auto-increment IDs sufficient for single-database system; UUIDs add unnecessary complexity
- **Client-side date formatting** - Pass ISO 8601 strings (YYYY-MM-DD) to API; let database handle date parsing

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQL injection prevention | Manual escaping/sanitization | DBI parameterized queries with dbBind() | Handles all data types correctly, prevents all injection vectors |
| Transaction management | Manual BEGIN/COMMIT/ROLLBACK | db_with_transaction() wrapper | Automatic rollback on error, connection cleanup guaranteed |
| Dynamic SQL building | String concatenation | glue_sql() with .con parameter | Safe interpolation, respects DBI quoting rules |
| Form validation | Custom validators | vee-validate (already in codebase) | Comprehensive validation library, async support |
| Date range selection | Custom date inputs | vue3-datepicker or native HTML5 | Accessibility, localization, browser compatibility |
| Multi-select dropdowns | Custom checkbox lists | BFormSelect with multiple=true | Native HTML select, Bootstrap styling, keyboard navigation |
| Entity overlap prevention | Application-level checks | Database UNIQUE constraint + transaction | Race condition safe, enforced at DB level |
| Batch ID generation | UUID libraries | Auto-increment primary key | Simpler, better ordering, adequate for single-DB |

**Key insight:** Database operations in R require careful handling of parameterized queries and transactions. The DBI ecosystem provides robust tools (dbBind, dbWithTransaction) that prevent common pitfalls. Don't bypass these in favor of string manipulation - the security and reliability benefits are substantial.

## Common Pitfalls

### Pitfall 1: SQL Injection via Dynamic WHERE Clauses
**What goes wrong:** Building WHERE clauses with unescaped user input allows SQL injection attacks
**Why it happens:** glue() directly interpolates strings without escaping; developers unfamiliar with glue_sql()
**How to avoid:**
- Use glue_sql() with .con parameter, not glue()
- Pass user values via DBI parameterized queries (list of params)
- Never concatenate strings directly into SQL
**Warning signs:**
- Using paste() or paste0() to build SQL
- glue() without .con parameter
- No list of params passed to db_execute_query()

**Example:**
```r
# WRONG - SQL injection vulnerability
where_clause <- glue("hgnc_id = '{user_input}'")  # user_input could be "1' OR '1'='1"

# CORRECT - Safe parameterized query
where_clause <- glue_sql("hgnc_id = {user_input}", .con = pool)
# OR even better, use positional parameters:
query <- "SELECT * FROM ndd_entity WHERE hgnc_id = ?"
result <- db_execute_query(query, list(user_input))
```

### Pitfall 2: Missing Transaction Wrapper for Multi-Step Operations
**What goes wrong:** Batch creation inserts to multiple tables; if step 2 fails, step 1 data is orphaned
**Why it happens:** Developers test happy path only, don't consider partial failures
**How to avoid:**
- Wrap all multi-step operations in db_with_transaction()
- Test error scenarios (duplicate key, constraint violation, network timeout)
- Never use multiple db_execute_statement() calls without transaction wrapper
**Warning signs:**
- Multiple INSERT/UPDATE statements in sequence without transaction
- Manual error handling instead of automatic rollback
- Orphaned records in test database

**Example:**
```r
# WRONG - No atomicity guarantee
batch_id <- db_execute_statement("INSERT INTO re_review_batch ...")
db_execute_statement("INSERT INTO re_review_entity_connect ...")  # If this fails, batch exists but is empty

# CORRECT - Atomic operation
result <- db_with_transaction({
  batch_id <- db_execute_statement("INSERT INTO re_review_batch ...")
  db_execute_statement("INSERT INTO re_review_entity_connect ...")
  batch_id  # Return value
}, pool_obj = pool)
```

### Pitfall 3: Entity Overlap Between Active Batches
**What goes wrong:** Same entity assigned to multiple active batches, causing duplicate work and data conflicts
**Why it happens:** Race condition between batch creation operations; missing exclusion check
**How to avoid:**
- Add WHERE clause excluding entities already in active batches
- Use transaction isolation to prevent race conditions
- Consider database UNIQUE constraint on (entity_id, is_active) combination
**Warning signs:**
- Users report reviewing same entity multiple times
- Conflicting updates to re_review_entity_connect
- Multiple active assignments for same entity_id

**Example:**
```r
# CORRECT - Exclude entities in active batches
query <- "
  SELECT entity_id FROM ndd_entity_view
  WHERE entity_id NOT IN (
    SELECT entity_id FROM re_review_entity_connect
    WHERE re_review_batch IN (
      SELECT re_review_batch FROM re_review_assignment
      WHERE is_active = TRUE
    )
  )
  AND review_date < ?
  ORDER BY review_date ASC
  LIMIT ?
"
```

### Pitfall 4: Modifying Assigned Batches
**What goes wrong:** Admin recalculates batch while user is actively reviewing, losing progress
**Why it happens:** No state machine preventing modifications to in-progress batches
**How to avoid:**
- Check batch status before allowing recalculation
- Only allow recalculation for "Created" state
- Transition to "Assigned" locks batch content
- Provide clear error messages
**Warning signs:**
- User complaints about disappearing work
- re_review_submitted entries with no corresponding batch
- Batch entity count changes unexpectedly

**Example:**
```r
# CORRECT - Enforce state machine
batch_recalculate <- function(batch_id, pool) {
  batch <- db_execute_query(
    "SELECT status FROM re_review_batch WHERE re_review_batch = ?",
    list(batch_id)
  )

  if (batch$status != "Created") {
    stop("Cannot recalculate batch in state: ", batch$status,
         ". Only Created batches can be recalculated.")
  }

  # Proceed with recalculation...
}
```

### Pitfall 5: BFormSelect Multiple Returns Array, Not Comma String
**What goes wrong:** Backend expects comma-separated string but receives JSON array from v-model
**Why it happens:** Bootstrap-Vue-Next BFormSelect with multiple=true returns array by default
**How to avoid:**
- Backend service functions expect array of values, not comma strings
- Document expected data type in API endpoint
- Use Array.isArray() check in JavaScript
**Warning signs:**
- Backend error "expected string, got array"
- Gene list filter fails silently
- WHERE IN clause receives single array instead of multiple values

**Example:**
```typescript
// CORRECT - BFormSelect with multiple returns array
const formData = reactive({
  gene_list: [] as number[],  // Array of HGNC IDs, not comma string
});

// Send array to backend
const response = await axios.post('/api/re_review/batch/create', {
  gene_list: formData.gene_list,  // [1234, 5678, 9012]
});
```

```r
# CORRECT - Backend expects array in criteria$gene_list
build_batch_where_clause <- function(criteria) {
  if (!is.null(criteria$gene_list) && length(criteria$gene_list) > 0) {
    # criteria$gene_list is already an array from JSON parsing
    placeholders <- paste(rep("?", length(criteria$gene_list)), collapse = ", ")
    conditions <- c(conditions, glue::glue("e.hgnc_id IN ({placeholders})"))
  }
}
```

### Pitfall 6: Forgetting to Clear Hardcoded 2020-01-01 Filter
**What goes wrong:** New dynamic batches created but old endpoint still filters by hardcoded date
**Why it happens:** Requirement RRV-07 to remove hardcoded filter gets overlooked
**How to avoid:**
- Grep codebase for "2020-01-01" before completion
- Update GET /api/re_review/table endpoint default filter
- Replace with dynamic filter parameter or remove entirely
**Warning signs:**
- ManageReReview view shows only pre-2020 entities
- New batches not appearing in table
- Filter parameter "lessOrEqual(review_date,2020-01-01)" still present

**Example:**
```r
# WRONG - Current hardcoded filter in line 199 of re_review_endpoints.R
filter = "or(lessOrEqual(review_date,2020-01-01),equals(re_review_review_saved,1)"

# CORRECT - Remove hardcoded date, use dynamic filter
filter = "equals(re_review_approved,0)"  # Or make fully dynamic based on batch criteria
```

## Code Examples

Verified patterns from official sources:

### Parameterized Query with glue_sql
```r
# Source: DBI Advanced Usage vignette
# https://dbi.r-dbi.org/articles/DBI-advanced.html

library(DBI)
library(glue)

# Safe dynamic query building with glue_sql
schema_name <- "sysndd_db"
table_name <- "ndd_entity"
date_var <- "review_date"
start_date <- "2023-01-01"
end_date <- "2024-01-01"

query <- glue_sql("
  SELECT entity_id, hgnc_id, {`date_var`}
  FROM {`schema_name`}.{`table_name`}
  WHERE {`date_var`} BETWEEN {start_date} AND {end_date}
", .con = pool)

# Result: Properly quoted identifiers and escaped values
```

### Transaction Wrapper Pattern
```r
# Source: Existing db-helpers.R db_with_transaction()
# /home/bernt-popp/development/sysndd/api/functions/db-helpers.R

# Atomic batch creation
batch_result <- db_with_transaction({
  # Step 1: Insert batch
  db_execute_statement(
    "INSERT INTO re_review_batch (batch_name, criteria_json) VALUES (?, ?)",
    list("Batch 2026-01", '{"date_range": {...}}')
  )

  # Step 2: Get batch_id
  batch_id <- db_execute_query("SELECT LAST_INSERT_ID() as id")$id[1]

  # Step 3: Insert entities
  for (entity_id in matching_entities) {
    db_execute_statement(
      "INSERT INTO re_review_entity_connect (entity_id, re_review_batch) VALUES (?, ?)",
      list(entity_id, batch_id)
    )
  }

  # Return batch_id (transaction commits automatically)
  batch_id
}, pool_obj = pool)
# If any step fails, entire transaction rolls back automatically
```

### Bootstrap-Vue-Next Multi-Select
```vue
<!-- Source: Bootstrap Vue Next documentation -->
<!-- https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-select -->

<template>
  <BFormSelect
    v-model="selectedGenes"
    :options="geneOptions"
    multiple
    :select-size="8"
  >
    <template #first>
      <option :value="null" disabled>-- Select genes --</option>
    </template>
  </BFormSelect>
</template>

<script setup>
import { ref } from 'vue';

// v-model must be array for multiple select
const selectedGenes = ref([]);  // Returns [1234, 5678] not "1234,5678"

const geneOptions = ref([
  { value: 1234, text: 'MECP2' },
  { value: 5678, text: 'CDKL5' },
  { value: 9012, text: 'SCN1A' },
]);
</script>
```

### AutocompleteInput for Entity Search
```vue
<!-- Source: Existing app/src/components/forms/AutocompleteInput.vue -->
<!-- Pattern established in Phase 37 -->

<template>
  <AutocompleteInput
    v-model="selectedEntityId"
    v-model:display-value="entityDisplay"
    :results="searchResults"
    :loading="isSearching"
    :min-chars="2"
    :debounce="300"
    label="Search Entities"
    input-id="entity-search"
    placeholder="Search by ID, gene, or disease..."
    @search="handleEntitySearch"
    @select="handleEntitySelected"
  >
    <template #item="{ item }">
      <div class="d-flex justify-content-between">
        <span class="fw-bold">{{ item.gene_symbol }}</span>
        <span class="text-muted">{{ item.entity_id }}</span>
      </div>
      <small class="text-muted">{{ item.disease_name }}</small>
    </template>
  </AutocompleteInput>
</template>

<script setup>
import { ref } from 'vue';
import AutocompleteInput from '@/components/forms/AutocompleteInput.vue';
import axios from 'axios';

const selectedEntityId = ref(null);
const entityDisplay = ref('');
const searchResults = ref([]);
const isSearching = ref(false);

const handleEntitySearch = async (query) => {
  isSearching.value = true;
  try {
    const response = await axios.get('/api/entity/search', {
      params: { q: query },
    });
    searchResults.value = response.data;
  } finally {
    isSearching.value = false;
  }
};

const handleEntitySelected = (item) => {
  entityDisplay.value = `${item.gene_symbol} - ${item.disease_name}`;
};
</script>
```

### Soft Delete Query Pattern
```r
# Source: Soft delete best practices
# https://www.geeksforgeeks.org/mongodb/soft-delete-pattern-in-mongodb/

# Archive batch (soft delete)
db_execute_statement(
  "UPDATE re_review_batch SET is_active = FALSE, archived_at = NOW() WHERE re_review_batch = ?",
  list(batch_id)
)

# Query only active batches
active_batches <- db_execute_query("
  SELECT * FROM re_review_batch
  WHERE is_active = TRUE
  ORDER BY created_at DESC
")

# Query including archived (for audit)
all_batches <- db_execute_query("
  SELECT *,
    CASE WHEN is_active THEN 'Active' ELSE 'Archived' END as display_status
  FROM re_review_batch
  ORDER BY created_at DESC
")
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Pre-computed static batches | Dynamic criteria-based batches | 2026 (this phase) | Admins can create batches on-demand with custom criteria |
| Hardcoded 2020-01-01 date filter | Dynamic date range selection | 2026 (this phase) | Batches can target any date range |
| Manual batch assignment via R script | UI-driven batch creation + assignment | 2026 (this phase) | No more manual CSV editing and database imports |
| Fixed batch size of 20 | Configurable batch size (1-100) | 2026 (this phase) | Batch size matches curator capacity |
| Batch reassignment requires DB edit | UI button for batch reassignment | 2026 (this phase) | Admins can reassign batches freely |
| No batch lifecycle tracking | 3-state lifecycle (Created/Assigned/Completed) | 2026 (this phase) | Clear batch status, prevents modification of active batches |
| Hard delete batches | Soft delete with is_active flag | 2026 (this phase) | Audit trail preserved, batch history retained |
| String concatenation SQL | glue_sql + parameterized queries | Phase 37+ (2026) | SQL injection prevention |
| Manual transaction management | db_with_transaction() wrapper | Phase 37+ (2026) | Automatic rollback, guaranteed cleanup |

**Deprecated/outdated:**
- `db/09_Rcommands_sysndd_db_table_re_review.R` script - Replaced by dynamic batch creation API
- Hardcoded `z_batch` special case for specific user (Zeynep Tümer) - Should use standard assignment workflow
- Pre-computed CSV files (`re_review_entity_connect.*.csv`, `re_review_assignment.*.csv`) - Generated dynamically now
- Fixed batch ID sequential numbering (1, 2, 3...) - Auto-increment handles this automatically
- Manual curation of gene lists in R scripts - Gene selection via UI multi-select

## Open Questions

Things that couldn't be fully resolved:

1. **Database schema modifications needed**
   - What we know: Need to add columns to existing tables (status ENUM, is_active BOOLEAN, criteria_json TEXT)
   - What's unclear: Whether to modify existing tables or create new tables (backward compatibility concern)
   - Recommendation: Check with database admin about migration strategy; likely add columns to existing tables with DEFAULT values for backward compatibility

2. **Backward compatibility with pre-computed batches**
   - What we know: Existing re_review_entity_connect has pre-computed batches (batch IDs 0-10+)
   - What's unclear: Whether new dynamic batches should start at ID 100 to avoid conflicts, or if pre-computed batches should be migrated
   - Recommendation: Use auto-increment for new batches; add is_dynamic BOOLEAN column to distinguish old/new batches

3. **Manual entity selection implementation**
   - What we know: User wants ability to add/remove specific entities from criteria results
   - What's unclear: UI pattern - checkboxes in preview modal? Separate selection step?
   - Recommendation: Preview modal with checkboxes for each entity; selected entities highlighted; "Remove" button to exclude from batch

4. **Auto-complete when all entities reviewed**
   - What we know: Batch should transition to "Completed" when all entities have re_review_approved = 1
   - What's unclear: Trigger mechanism - database trigger? Cron job? Check on each approval?
   - Recommendation: Check on each entity approval in re_review/approve endpoint; run query to count approved vs total, transition if 100%

5. **Batch recalculation vs. reassignment**
   - What we know: Recalculation allowed only before assignment; reassignment allowed anytime
   - What's unclear: Does recalculation keep same batch_id or create new batch? How to handle if entities no longer match criteria?
   - Recommendation: Recalculation keeps batch_id but deletes/re-inserts re_review_entity_connect records; show warning if entity count changes significantly

6. **API endpoint structure**
   - What we know: Need POST /api/re_review/batch/create and PUT /api/re_review/entities/assign
   - What's unclear: Should assignment be part of create endpoint or separate? Do we need batch/recalculate endpoint?
   - Recommendation: Create can optionally assign (assigned_user_id parameter); add PUT batch/reassign and POST batch/recalculate as separate endpoints

## Sources

### Primary (HIGH confidence)
- [DBI Advanced Usage - Parameterized Queries](https://dbi.r-dbi.org/articles/DBI-advanced.html) - Official DBI documentation for parameterized queries and dbBind()
- [Posit Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/) - Best practices for SQL injection prevention in R
- [Bootstrap Vue Next Form Select](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/form-select) - Official BFormSelect documentation with multiple attribute
- Existing codebase patterns:
  - `/home/bernt-popp/development/sysndd/api/functions/db-helpers.R` - db_with_transaction(), db_execute_query() patterns
  - `/home/bernt-popp/development/sysndd/api/services/entity-service.R` - Service layer architecture
  - `/home/bernt-popp/development/sysndd/api/services/status-service.R` - Transaction-wrapped service functions
  - `/home/bernt-popp/development/sysndd/app/src/components/forms/AutocompleteInput.vue` - Autocomplete pattern
  - `/home/bernt-popp/development/sysndd/.planning/phases/37-form-modernization/37-RESEARCH.md` - Form composable patterns

### Secondary (MEDIUM confidence)
- [Plumber REST APIs Cheatsheet](https://rstudio.github.io/cheatsheets/html/plumber.html) - Plumber endpoint decoration patterns
- [REST APIs and Plumber - R Views](https://rviews.rstudio.com/2018/07/23/rest-apis-and-plumber/) - REST API best practices with Plumber
- [Repository Pattern in R - R6P](https://tidylab.github.io/R6P/articles/patterns/Repository.html) - Repository pattern implementation in R
- [Batch State Transition Management](https://sgsystemsglobal.com/glossary/batch-state-transition-management/) - Batch lifecycle state management concepts
- [PostgreSQL Exclusion Constraints for Overlaps](https://blog.danielclayton.co.uk/posts/overlapping-data-postgres-exclusion-constraints/) - Preventing entity overlap with database constraints
- [Soft Delete Pattern in MongoDB - GeeksforGeeks](https://www.geeksforgeeks.org/mongodb/soft-delete-pattern-in-mongodb/) - Soft delete pattern benefits and implementation
- [UUID vs Auto-Increment - Baeldung](https://www.baeldung.com/uuid-vs-sequential-id-as-primary-key) - Primary key strategy comparison
- [How to Choose Database UUID - Bytebase](https://www.bytebase.com/blog/choose-primary-key-uuid-or-auto-increment/) - UUID vs auto-increment decision factors
- [Vue 3 Form Validation with Composition API](https://softauthor.com/vue-js-3-composition-api-reusable-scalable-form-validation/) - Vue 3 form validation patterns
- [Build Better Forms with Vue.js 3 Composition API](https://digitalpatio.hashnode.dev/build-better-forms-with-vuejs-3-composition-api-a-practical-guide) - Form lifecycle management
- [Review Before Submit - FormAssembly](https://help.formassembly.com/help/preview-before-submit) - Optional preview pattern benefits
- [Vue Datepicker](https://vue3datepicker.com/) - Date range picker for Vue 3
- [Dynamic SQL queries with R - Data By John](https://www.johnmackintosh.net/blog/2022-04-06-sql-schema-query/) - glue_sql() examples for dynamic queries

### Tertiary (LOW confidence)
- [sqlq R package](https://cran.r-project.org/web/packages/sqlq/index.html) - Alternative SQL query builder (not needed, glue_sql sufficient)
- [AWS Batch Job States](https://docs.aws.amazon.com/batch/latest/userguide/job_states.html) - Cloud batch lifecycle (informational, not directly applicable)
- [Spring Batch Tutorial](https://dev.to/sadiul_hakim/spring-batch-tutorial-part-4-20dl) - Java batch patterns (language-specific, concepts transferable)
- [Vuelidate](https://vuelidate-next.netlify.app/) - Alternative to vee-validate (already using vee-validate)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All libraries already in use, well-documented patterns in codebase
- Architecture: HIGH - Service layer and transaction patterns established in phases 37+
- Pitfalls: HIGH - SQL injection and transaction issues well-documented in DBI/RMariaDB docs
- Database schema: MEDIUM - Need to confirm migration strategy with database admin
- UI patterns: HIGH - Bootstrap-Vue-Next and AutocompleteInput patterns proven in phase 37
- Batch lifecycle: MEDIUM - State machine concept clear, implementation details need validation

**Research date:** 2026-01-26
**Valid until:** 60 days (stable technologies, established patterns)

**Key decision dependencies from CONTEXT.md:**
- Single form interface (all criteria on one screen) - LOCKED
- Bootstrap-Vue-Next BFormSelect for multi-select - LOCKED
- Optional preview (not mandatory) - LOCKED
- Auto-generated batch ID with optional custom name - LOCKED
- One user per batch - LOCKED
- Simple 3-state lifecycle - LOCKED
- Soft delete only - LOCKED
- Recalculation only before assignment - LOCKED

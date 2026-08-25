# Variation-Ontology Provenance #612 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the application-repo half of variation-ontology provenance: render all three
`evidence_json` record shapes, reject stale assertions when a review is approved, and ship the
cross-entity suggestion queue plus the three-zone picker on the two curation surfaces that lack it.

**Architecture:** Three independent slices over one shared state machine. The evidence slice is
frontend-only plus a wire-shape contract fixture. The approval slice adds a symmetric
`apply_confirmations` gate to the existing pure planner and a new approval-time orchestrator, then
wraps `svc_approval_review_approve()` in one transaction. The queue slice adds a thin
Curator-gated endpoint over a new service that reuses that same planner, with `SELECT … FOR UPDATE`
plus state-conditional writes for concurrency.

**Tech Stack:** R/Plumber + `renv` (api), Vue 3 + TypeScript + Vite + Vitest (app), MySQL 8.4
migrations. Tests: `testthat` (R), `vitest` (frontend).

**Spec:** `.planning/superpowers/specs/2026-08-25-variation-provenance-612-design.md`

## Global Constraints

- **Absence of a `variation_ontology_assertion` row means CURATOR-AUTHORED.** Never write a state
  that removes a still-served term from `state IN ('active_unconfirmed','confirmed')`.
- **Identity is `(entity_id, vario_id, modifier_id)`** — never `(entity_id, vario_id)`.
- **`ndd_review_variation_ontology_connect` is written only by `api/functions/ontology-repository.R`.**
  `api/tests/testthat/test-unit-variation-connect-write-guard.R` enforces this over
  `api/functions`, `api/services`, `api/endpoints`.
- **Never trust a client-sent field.** Served membership and assertion state are always re-derived
  server-side, inside the writing transaction.
- **Every handwritten file stays ≤ 600 lines.** `make code-quality-audit` is the gate; no file in
  this plan is in `scripts/code-quality-file-size-baseline.tsv`, so 600 is a hard limit for all of
  them.
- **Every new endpoint file is mounted through `mount_endpoint()`** in
  `api/bootstrap/mount_endpoints.R` (attaches the RFC 9457 error handler + 404 handler).
  `test-unit-endpoint-error-handler.R` enforces this.
- **Literal routes are declared BEFORE dynamic siblings.** Plumber matches in declaration order.
- **Use `base::get()` explicitly**, never bare `get(x, mode = "function")` — the `config` package
  masks `base::get` in the loaded API/worker environment.
- **Namespace `dplyr::select()`** and similar verbs explicitly.
- **`DBI::dbBind()` with `?` placeholders needs `unname(params)`.** `db_execute_query` /
  `db_execute_statement` already handle this; pass plain unnamed `list()`s.
- **New R source files must be registered in `api/bootstrap/load_modules.R`.** Files are not
  autodiscovered, and the same loader serves the API and the durable worker.
- **Frontend API access goes through typed clients in `app/src/api/*`.** No raw axios in views.
- Commit after every green step. Branch: `feat/variation-provenance-phase6-612`.

---

## File Structure

**Create (R)**
- `api/tests/testthat/fixtures/variation-evidence-record-shapes.json` — the cross-repo contract.
- `api/functions/variation-provenance-approval.R` — served-term read + approval-time orchestrator.
  Separate file because `variation-provenance-reconcile.R` is at 492 lines; same reason
  `variation-provenance-carry-forward.R` was split out.
- `api/services/curate-variation-suggestion-service.R` — queue query + confirm/dismiss.
- `api/endpoints/curate_variation_endpoints.R` — thin: role gate, parameter forwarding.
- `api/tests/testthat/test-unit-variation-evidence-record-shapes.R`
- `api/tests/testthat/test-unit-approval-service-provenance.R`
- `api/tests/testthat/test-unit-curate-variation-suggestions.R`
- `api/tests/testthat/test-integration-variation-suggestions.R`

**Modify (R)**
- `api/functions/variation-provenance-reconcile.R` — add `apply_confirmations` to the planner.
- `api/functions/db-helpers.R` — add `db_with_savepoint_or_transaction()`.
- `api/services/review-write-service.R` — `review_write_run_mutation()` delegates to it.
- `api/services/approval-service.R` — transaction + `"all"` length fix + hook.
- `api/bootstrap/load_modules.R`, `api/bootstrap/mount_endpoints.R` — registration.
- `api/tests/testthat/test-unit-variation-provenance-reconcile.R` — `apply_confirmations` cases.

**Create (frontend)**
- `app/src/views/pages/components/variationEvidenceRecords.ts` — the three shape normalizers.
- `app/src/views/pages/components/VariationEvidenceRecordList.vue` — the three renderers.
- `app/src/test-utils/variationEvidenceShapesFixture.ts` — loads the shared JSON fixture.
- `app/src/api/curate_variation.ts` + `app/src/api/curate-variation-wire.ts`
- `app/src/views/curate/VariationSuggestions.vue`
- `app/src/views/curate/composables/useVariationSuggestions.ts`
- `app/src/views/curate/components/VariationSuggestionsTable.vue`
- `app/src/views/curate/components/VariationSuggestionMobileRows.vue`
- `app/src/views/curate/components/VariationProvenanceZones.vue` — extracted from `ReviewFormFields.vue`.
- `app/src/views/curate/ModifyEntity.styles.css` — extracted `<style scoped>`.

**Modify (frontend)**
- `app/src/views/pages/components/variationProvenance.ts` + `VariationProvenanceDialog.vue`
- `app/src/views/curate/components/ReviewFormFields.vue` (consume the extracted component)
- `app/src/views/curate/components/InlineEntityWorkflow.vue`,
  `CombinedStatusReviewWorkflow.vue`, `app/src/components/review/ReviewEditForm.vue`,
  `app/src/components/review/EditReviewModal.vue`
- `app/src/views/curate/ModifyEntity.vue`,
  `app/src/views/curate/composables/{useModifyEntityWorkflows,useEntityInfo,useEntityMutations}.ts`
- `app/src/views/curate/ApproveReview.vue`,
  `app/src/views/curate/composables/useApproveReviewController.ts`,
  `app/src/composables/review/useReviewApprovalActions.ts`
- `app/src/router/routes.ts`, `app/src/assets/js/constants/main_nav_constants.ts`

---

## Environment: running the DB-backed tests

CI provisions an **empty** MySQL, so every `test-integration-*.R` file skips there and on the host
(no `RMariaDB`). To actually run them, a throwaway MySQL with all migrations must exist:

```bash
docker rm -f sysndd_mysql_prov612 2>/dev/null
docker run -d --name sysndd_mysql_prov612 --network sysndd_backend \
  -e MYSQL_ROOT_PASSWORD=prov612root -e MYSQL_DATABASE=sysndd_db_test \
  -e MYSQL_USER=sysndd_test -e MYSQL_PASSWORD=prov612 mysql:8.4.11 --sql-mode=""
# wait for healthy, then from inside the API container:
docker exec sysndd-api-1 Rscript -e '
  setwd("/app"); library(DBI); library(RMariaDB); library(dplyr); library(logger)
  source("functions/logging-functions.R"); source("functions/db-helpers.R")
  source("functions/migration-runner.R"); source("functions/migration-manifest.R")
  conn <- DBI::dbConnect(RMariaDB::MariaDB(), dbname="sysndd_db_test",
    host="sysndd_mysql_prov612", user="root", password="prov612root", port=3306L)
  run_migrations("db/migrations", conn = conn)'
```

To run a test file inside the container (`api/tests/` is **not** bind-mounted — and
`docker cp api/tests` onto an existing `/app/tests` NESTS instead of overwriting):

```bash
docker exec sysndd-api-1 rm -rf /app/tests
docker cp api/tests sysndd-api-1:/app/tests
docker exec -e MYSQL_HOST=sysndd_mysql_prov612 -e MYSQL_DATABASE=sysndd_db_test \
  -e MYSQL_USER=root -e MYSQL_PASSWORD=prov612root -e MYSQL_PORT=3306 \
  sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-<name>.R')"
```

`get_test_config()` (`api/tests/testthat/helper-db.R:309`) switches to env-var mode as soon as
`MYSQL_HOST` is set. Unit-only R files run on the host with
`cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-<name>.R')"`.

---

## Test idioms this repo actually uses (read before writing any R test)

**Mocking a sourced-into-global free function.** `testthat::local_mocked_bindings(..., .env = globalenv())`
does NOT work here — under testthat 3.3.2 it aborts with "No packages loaded with pkgload", because
`globalenv()` has no package namespace (documented at
`api/tests/testthat/test-unit-clustering-gene-universe.R:13`). The repo convention is a direct
global replacement with a `withr::defer` restore
(`api/tests/testthat/test-unit-review-write-service.R:151`). Every R test in this plan writes
`mock_globals(list(...))`, defined once per test file as:

```r
# Repo idiom for stubbing sourced-into-global free functions. testthat's
# local_mocked_bindings() cannot target them (globalenv() has no pkgload
# namespace); see test-unit-clustering-gene-universe.R:13 and the direct
# assign/defer pattern at test-unit-review-write-service.R:151.
# `base::get` is explicit because the `config` package masks `base::get` with a
# signature that has no `envir` argument (AGENTS.md).
mock_globals <- function(bindings, env = parent.frame()) {
  for (name in names(bindings)) {
    local({
      target <- name
      had <- base::exists(target, envir = .GlobalEnv, inherits = FALSE)
      previous <- if (had) base::get(target, envir = .GlobalEnv, inherits = FALSE) else NULL
      assign(target, bindings[[target]], envir = .GlobalEnv)
      withr::defer(
        if (had) {
          assign(target, previous, envir = .GlobalEnv)
        } else {
          rm(list = target, envir = .GlobalEnv)
        },
        envir = env
      )
    })
  }
}
```

`testthat::local_mocked_bindings(..., .package = "DBI")` IS valid and is used for `dbExecute` /
`dbGetQuery` / `dbWithTransaction` (`api/tests/testthat/test-unit-pubtator-gene-summary.R:14`).
`mockery::stub(fn, "name", value)` is the idiom for a binding a function resolves internally
(`test-unit-review-write-service.R:321`).

**`with_test_db_transaction()` takes an EXPRESSION, not a function.** It is
`with_test_db_transaction(code)`, `force(code)`, and it publishes its connection through an option
(`api/tests/testthat/helper-db.R:282-295`). Passing a function merely returns the function and the
body never runs — a test that "passes" while executing nothing. Always:

```r
with_test_db_transaction({
  conn <- getOption(".test_db_con")
  ...
})
```

**Endpoint-level tests** mount the endpoint file in a sandbox and invoke the handler directly;
copy the harness from `api/tests/testthat/test-endpoint-review.R:109`. That is the only way to
prove `require_role`, `req$argsBody` and the serializer decorators — a test that calls the service
function proves none of them.


---

## Task 1: Evidence-shape fixture and the R wire contract

**Files:**
- Create: `api/tests/testthat/fixtures/variation-evidence-record-shapes.json`
- Test: `api/tests/testthat/test-unit-variation-evidence-record-shapes.R`

**Interfaces:**
- Consumes: `.svc_vp_parse_json()`, `.svc_vp_evidence_records()` from
  `api/services/entity-variation-provenance-service.R`.
- Produces: the fixture file, whose `shapes.<name>.{source_key, source_type, container_keys,
  record_keys, required_record_keys, matched_item_type, sample}` structure Task 2 and Task 4 both
  read.

- [ ] **Step 1: Write the fixture**

The `sample` values are the verbatim wire payloads captured from production (already
plumber-wrapped, i.e. every scalar is a length-1 array). Truncate only long free text.

```json
{
  "$comment": "Cross-repo contract for variation_ontology_evidence.evidence_json (#612). The writer is sysndd-administration scripts/data-corrections/005-variation-provenance-backfill/provenance_builder.py; see admin#16. A key rename on either side must change this file. Samples are verbatim wire payloads captured from GET /api/entity/<id>/variation/<vario>/<mod>/evidence, so every scalar is already wrapped in a length-1 array by plumber.",
  "shapes": {
    "clinvar": {
      "source_key": "clinvar",
      "source_type": "external_database",
      "captured_from": "entity 2097, VariO:0015, modifier 1",
      "container_keys": ["records", "matched"],
      "record_keys": ["id", "classification", "stars", "consequence", "url"],
      "required_record_keys": ["id", "classification", "stars", "consequence", "url"],
      "matched_item_type": "string",
      "sample": {
        "matched": [["OMIM:251280"]],
        "records": [
          { "id": ["3382378"], "url": ["https://www.ncbi.nlm.nih.gov/clinvar/variation/3382378/"],
            "stars": [1], "consequence": ["SO:0001587|nonsense"],
            "classification": ["Likely pathogenic"] },
          { "id": ["817069"], "url": ["https://www.ncbi.nlm.nih.gov/clinvar/variation/817069/"],
            "stars": [2], "consequence": ["SO:0001589|frameshift_variant"],
            "classification": ["Pathogenic/Likely pathogenic"] }
        ]
      }
    },
    "extdb2": {
      "source_key": "extdb2",
      "source_type": "external_database",
      "captured_from": "entity 2900, VariO:0039, modifier 1",
      "container_keys": ["records"],
      "record_keys": ["confidence", "mechanism", "categorisation", "consequence",
                      "support", "disease", "allelic_requirement", "layer"],
      "required_record_keys": [],
      "matched_item_type": null,
      "sample": {
        "records": [
          { "layer": ["mechanism"],
            "disease": ["ZNRF3-related neurodevelopmental disorder with macrocephaly"],
            "support": ["evidence"], "mechanism": ["dominant negative"],
            "confidence": ["moderate"], "consequence": ["altered gene product structure"],
            "categorisation": ["assembly-mediated dominant negative:evidence"],
            "allelic_requirement": ["monoallelic_autosomal"] }
        ]
      }
    },
    "synopsis": {
      "source_key": "synopsis",
      "source_type": "literature",
      "captured_from": "entity 991, VariO:0043, modifier 1",
      "container_keys": ["records"],
      "record_keys": ["matched_text", "negated", "pattern", "context"],
      "required_record_keys": ["matched_text", "negated"],
      "matched_item_type": null,
      "sample": {
        "records": [
          { "context": ["Haploinsufficiency was posited as pathomechanism."],
            "negated": [false], "pattern": ["\\bhaploinsufficiency\\b"],
            "matched_text": ["Haploinsufficiency"] },
          { "context": ["However, another study identified a truncating variant that did not segregate with ID, concluding that SRGAP3 haploinsufficiency is not pathogenic."],
            "negated": [true], "pattern": ["\\bhaploinsufficiency\\b"],
            "matched_text": ["haploinsufficiency"] }
        ]
      }
    }
  }
}
```

- [ ] **Step 2: Write the failing R contract test**

```r
# api/tests/testthat/test-unit-variation-evidence-record-shapes.R
#
# Cross-repo contract for variation_ontology_evidence.evidence_json (#612).
#
# The writer lives in sysndd-administration; this repo's dialog is the reader.
# A key-name mismatch fails SILENTLY there (an unrecognised key is omitted, not
# guessed at), which is how the extdb2 batch rendered `consequence` alone and the
# synopsis batch rendered nothing at all. The fixture is the artifact both repos
# point at, and it drives the TypeScript suite too
# (app/src/test-utils/variationEvidenceShapesFixture.ts).
#
# R's stake is the WIRE SHAPE the TypeScript normalizer is written against: this
# file asserts that a stored payload survives .svc_vp_parse_json() ->
# .svc_vp_evidence_records() with its key sets intact, and that a boolean FALSE
# survives serialization as [false] rather than being dropped or stringified.
source_api_file("services/entity-variation-provenance-service.R", local = FALSE)

fixture <- jsonlite::fromJSON(
  testthat::test_path("fixtures", "variation-evidence-record-shapes.json"),
  simplifyVector = FALSE
)

# Rebuild the exact text MySQL would hold in the JSON column.
stored_json <- function(shape) {
  jsonlite::toJSON(shape$sample, auto_unbox = FALSE, null = "null")
}

evidence_row <- function(shape) {
  tibble::tibble(
    source_type = shape$source_type, source_key = shape$source_key,
    batch_id = paste0(shape$source_key, "-2026-02"), source_version = NA_character_,
    evidence_summary = "fixture", evidence_strength = 2L,
    evidence_json = as.character(stored_json(shape)),
    evidence_created_at = "2026-08-05 15:31:37"
  )
}

test_that("every fixture shape round-trips with its container keys intact", {
  for (name in names(fixture$shapes)) {
    shape <- fixture$shapes[[name]]
    records <- .svc_vp_evidence_records(evidence_row(shape))
    expect_length(records, 1L)
    payload <- records[[1L]]$evidence_json
    expect_setequal(names(payload), unlist(shape$container_keys))
  }
})

test_that("every fixture shape round-trips with its record keys intact, both directions", {
  for (name in names(fixture$shapes)) {
    shape <- fixture$shapes[[name]]
    payload <- .svc_vp_evidence_records(evidence_row(shape))[[1L]]$evidence_json
    declared <- unlist(shape$record_keys)
    required <- unlist(shape$required_record_keys)
    seen <- character()
    for (record in payload$records) {
      # No record may carry a key the fixture does not declare.
      expect_true(all(names(record) %in% declared),
                  info = paste(name, "undeclared key:",
                               paste(setdiff(names(record), declared), collapse = ", ")))
      # Every required key is on every record.
      expect_true(all(required %in% names(record)), info = paste(name, "missing required key"))
      seen <- union(seen, names(record))
    }
    # And the fixture may not declare a key no sample record carries.
    expect_setequal(seen, declared)
  }
})

test_that("clinvar `matched` carries strings, never records", {
  shape <- fixture$shapes$clinvar
  payload <- .svc_vp_evidence_records(evidence_row(shape))[[1L]]$evidence_json
  expect_true(length(payload$matched) > 0L)
  for (item in payload$matched) {
    expect_true(is.character(unlist(item)))
  }
})

test_that("a boolean FALSE survives the route's serializer arguments as [false]", {
  # Replicates the argument set the route declares -- entity_endpoints.R carries
  # `#* @serializer json list(na="string", null="null")` -- rather than invoking
  # plumber. `negated: false` is the only field in the whole payload whose FALSE
  # value is meaningful: a negated synopsis match is evidence AGAINST the term.
  shape <- fixture$shapes$synopsis
  payload <- .svc_vp_evidence_records(evidence_row(shape))[[1L]]$evidence_json
  wire <- as.character(jsonlite::toJSON(
    payload, auto_unbox = FALSE, na = "string", null = "null"
  ))
  expect_match(wire, '"negated":[false]', fixed = TRUE)
  expect_match(wire, '"negated":[true]', fixed = TRUE)
})
```

- [ ] **Step 3: Run the test — expect FAIL only if the fixture is wrong**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-variation-evidence-record-shapes.R')"
```
Expected: PASS. This test pins existing behaviour, so a failure means the fixture does not match
what the service actually produces — fix the **fixture**, not the service. If it needs
`source_api_file` helpers that are not loaded on the host, run it in the container per the
Environment section.

- [ ] **Step 4: Red-test the contract**

Temporarily add `"nonexistent_key"` to `shapes.synopsis.record_keys` and re-run: the
"both directions" test must FAIL with a `expect_setequal` mismatch. Revert.

- [ ] **Step 5: Commit**

```bash
git add api/tests/testthat/fixtures/variation-evidence-record-shapes.json \
        api/tests/testthat/test-unit-variation-evidence-record-shapes.R
git commit -m "test(612): pin the evidence_json record-shape contract"
```

---

## Task 2: Shape-dispatched evidence normalizers (TypeScript)

**Files:**
- Create: `app/src/views/pages/components/variationEvidenceRecords.ts`
- Create: `app/src/test-utils/variationEvidenceShapesFixture.ts`
- Modify: `app/src/views/pages/components/variationProvenance.ts`
- Test: `app/src/views/pages/components/variationEvidenceRecords.spec.ts`

**Interfaces:**
- Consumes: the Task 1 fixture; `unwrapScalar` from `variationProvenance.ts`.
- Produces:
  ```ts
  export type NormalizedEvidenceRecord =
    | { kind: 'clinvar'; variationId: string | null; classification: string | null;
        stars: number | null; consequence: string | null; url: string | null }
    | { kind: 'external'; fields: Array<{ key: string; label: string; value: string }> }
    | { kind: 'literature'; matchedText: string | null; negated: boolean | null;
        pattern: string | null; context: string | null }
    | { kind: 'generic'; variationId: string | null; consequence: string | null;
        classification: string | null; url: string | null };
  export function normalizeEvidenceRecordList(
    payload: unknown, sourceKey: string | null, sourceType: string | null
  ): NormalizedEvidenceRecord[];
  export function asBoolean(value: unknown): boolean | null;
  export const EXTERNAL_FIELD_ORDER: readonly string[];
  ```
  `NormalizedEvidence.records` in `variationProvenance.ts` changes type from
  `NormalizedEvidenceRecordRow[]` to `NormalizedEvidenceRecord[]`; Task 3 consumes it.

- [ ] **Step 1: Write the fixture loader**

```ts
// app/src/test-utils/variationEvidenceShapesFixture.ts
/**
 * Loads the shared cross-repo evidence-shape contract so the TypeScript suite
 * and the R suite are driven by ONE file — the same pattern as
 * `clinvarVocabularyFixture.ts`. The fixture lives under `api/tests/` because R
 * cannot reach into `app/`; TypeScript can reach either way.
 */
import fixture from '../../../api/tests/testthat/fixtures/variation-evidence-record-shapes.json';

export interface EvidenceShapeFixture {
  source_key: string;
  source_type: string;
  container_keys: string[];
  record_keys: string[];
  required_record_keys: string[];
  matched_item_type: 'string' | null;
  sample: Record<string, unknown>;
}

export const evidenceShapes = fixture.shapes as unknown as Record<string, EvidenceShapeFixture>;
```

If `resolveJsonModule` or the `api/` path is outside `app`'s `rootDir`, read the file with
`fs.readFileSync(new URL(...))` inside the spec instead — vitest runs in Node. Verify with
`cd app && npm run type-check` in Step 5.

- [ ] **Step 2: Write the failing spec**

```ts
// app/src/views/pages/components/variationEvidenceRecords.spec.ts
import { describe, it, expect } from 'vitest';
import { evidenceShapes } from '@/test-utils/variationEvidenceShapesFixture';
import {
  normalizeEvidenceRecordList,
  asBoolean,
  EXTERNAL_FIELD_ORDER,
} from './variationEvidenceRecords';

const understoodKeys: Record<string, readonly string[]> = {
  clinvar: ['id', 'classification', 'stars', 'consequence', 'url'],
  extdb2: EXTERNAL_FIELD_ORDER,
  synopsis: ['matched_text', 'negated', 'pattern', 'context'],
};

describe('evidence record shape contract', () => {
  it.each(Object.keys(evidenceShapes))('understands exactly %s\'s declared keys', (name) => {
    const declared = [...evidenceShapes[name].record_keys].sort();
    const understood = [...understoodKeys[name]].sort();
    // Both directions: the normalizer must not ignore a declared key, and must
    // not claim a key the writer never emits.
    expect(understood).toEqual(declared);
  });

  it.each(Object.keys(evidenceShapes))('normalizes every %s sample record', (name) => {
    const shape = evidenceShapes[name];
    const rows = normalizeEvidenceRecordList(shape.sample, shape.source_key, shape.source_type);
    const sampleCount = (shape.sample.records as unknown[]).length;
    expect(rows).toHaveLength(sampleCount);
    expect(rows.every((r) => r.kind !== 'generic')).toBe(true);
  });
});

describe('clinvar records', () => {
  it('exposes stars and a deep link', () => {
    const shape = evidenceShapes.clinvar;
    const [first] = normalizeEvidenceRecordList(shape.sample, 'clinvar', 'external_database');
    expect(first).toMatchObject({
      kind: 'clinvar',
      variationId: '3382378',
      classification: 'Likely pathogenic',
      stars: 1,
      consequence: 'SO:0001587|nonsense',
    });
    expect((first as { url: string }).url).toContain('/clinvar/variation/3382378/');
  });
});

describe('external-database records', () => {
  it('renders every recorded field in the fixed order and omits absent ones', () => {
    const shape = evidenceShapes.extdb2;
    const [row] = normalizeEvidenceRecordList(shape.sample, 'extdb2', 'external_database');
    expect(row.kind).toBe('external');
    const fields = (row as { fields: Array<{ key: string; value: string }> }).fields;
    expect(fields.map((f) => f.key)).toEqual([
      'confidence', 'mechanism', 'categorisation', 'consequence',
      'allelic_requirement', 'support', 'disease', 'layer',
    ]);
    expect(fields.find((f) => f.key === 'mechanism')?.value).toBe('dominant negative');
  });

  it('omits a key the record does not carry rather than rendering it blank', () => {
    const payload = { records: [{ mechanism: ['loss of function'] }] };
    const [row] = normalizeEvidenceRecordList(payload, 'extdb2', 'external_database');
    expect((row as { fields: unknown[] }).fields).toHaveLength(1);
  });

  it('renders an unknown key under its raw name instead of dropping it', () => {
    const payload = { records: [{ novel_field: ['x'] }] };
    const [row] = normalizeEvidenceRecordList(payload, 'extdb2', 'external_database');
    expect((row as { fields: Array<{ key: string }> }).fields[0].key).toBe('novel_field');
  });
});

describe('literature records', () => {
  it('preserves the negated flag through the plumber array wrapper', () => {
    const shape = evidenceShapes.synopsis;
    const rows = normalizeEvidenceRecordList(shape.sample, 'synopsis', 'literature');
    expect(rows.map((r) => (r as { negated: boolean | null }).negated)).toEqual([false, true]);
  });

  it('keeps matched text and context', () => {
    const shape = evidenceShapes.synopsis;
    const [first] = normalizeEvidenceRecordList(shape.sample, 'synopsis', 'literature');
    expect(first).toMatchObject({
      kind: 'literature',
      matchedText: 'Haploinsufficiency',
      pattern: '\\bhaploinsufficiency\\b',
    });
  });
});

describe('asBoolean', () => {
  it.each([
    [[false], false],
    [[true], true],
    [false, false],
    ['true', true],
    ['false', false],
    [null, null],
    [undefined, null],
    ['yes', null],
    [[1], null],
  ])('maps %j to %j', (input, expected) => {
    expect(asBoolean(input)).toBe(expected);
  });
});

describe('unknown sources', () => {
  it('falls back to the pre-#612 generic probe rather than rendering nothing', () => {
    const payload = { records: [{ accession: ['ACC1'], molecular_consequence: ['missense'] }] };
    const [row] = normalizeEvidenceRecordList(payload, 'future_source', 'external_database');
    expect(row).toMatchObject({ kind: 'generic', variationId: 'ACC1', consequence: 'missense' });
  });

  it('drops a record with no renderable field', () => {
    expect(normalizeEvidenceRecordList({ records: [{}] }, 'future', 'literature')).toEqual([]);
  });
});
```

- [ ] **Step 3: Run it and confirm it fails**

Run: `cd app && npx vitest run src/views/pages/components/variationEvidenceRecords.spec.ts`
Expected: FAIL — `Failed to resolve import "./variationEvidenceRecords"`.

- [ ] **Step 4: Implement `variationEvidenceRecords.ts`**

The module owns three shape normalizers plus the pre-#612 generic probe. Dispatch is on
`source_key` first and `source_type` second, so a new `literature` source still gets the
literature renderer.

```ts
// app/src/views/pages/components/variationEvidenceRecords.ts
//
// Shape-dispatched normalizers for `variation_ontology_evidence.evidence_json` (#612).
//
// The backfill writes THREE record shapes and the pre-#612 normalizer understood
// one: the extdb2 batch rendered `consequence` alone and the synopsis batch
// rendered nothing at all, because a record carrying none of the probed keys is
// filtered out. That failure is silent BY DESIGN — an unrecognised key is
// omitted rather than guessed at — which is why the shapes are pinned by a
// fixture shared with the R suite and with the writing repository
// (api/tests/testthat/fixtures/variation-evidence-record-shapes.json, admin#16).
//
// TWO RULES CARRIED OVER FROM variationProvenance.ts
//   1. NEVER SYNTHESISE. An absent key is omitted; a placeholder that implies
//      data is the fabrication this feature exists to prevent.
//   2. A value that is NOT RECORDED is `null`, never a plausible-looking zero.
//
// Optional keys are DROPPED by the writer, not written null, so a record
// legitimately carries a subset of its shape's keys.

import { unwrapScalar } from './variationProvenance';

export type NormalizedEvidenceRecord =
  | { kind: 'clinvar'; variationId: string | null; classification: string | null;
      stars: number | null; consequence: string | null; url: string | null }
  | { kind: 'external'; fields: EvidenceField[] }
  | { kind: 'literature'; matchedText: string | null; negated: boolean | null;
      pattern: string | null; context: string | null }
  | { kind: 'generic'; variationId: string | null; consequence: string | null;
      classification: string | null; url: string | null };

export interface EvidenceField {
  key: string;
  label: string;
  value: string;
}

/** Display order for external-database fields; also the understood-key set. */
export const EXTERNAL_FIELD_ORDER = [
  'confidence', 'mechanism', 'categorisation', 'consequence',
  'allelic_requirement', 'support', 'disease', 'layer',
] as const;

const EXTERNAL_FIELD_LABELS: Record<string, string> = {
  confidence: 'Confidence',
  mechanism: 'Mechanism',
  categorisation: 'Categorisation',
  consequence: 'Consequence',
  allelic_requirement: 'Allelic requirement',
  support: 'Support',
  disease: 'Disease',
  layer: 'Layer',
};

const RECORD_LIST_KEYS = ['records', 'variants', 'evidence_records'];
const GENERIC_VARIATION_ID_KEYS = ['variation_id', 'clinvar_variation_id', 'accession', 'id'];
const GENERIC_CONSEQUENCE_KEYS = ['consequence', 'molecular_consequence'];
const GENERIC_CLASSIFICATION_KEYS = ['classification', 'clinical_significance', 'significance'];

const STRENGTH_SCALE_MAX = 4;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function text(value: unknown): string | null {
  const raw = unwrapScalar(value);
  if (raw === null || raw === undefined) return null;
  const trimmed = String(raw).trim();
  return trimmed === '' ? null : trimmed;
}

function firstText(row: Record<string, unknown>, keys: readonly string[]): string | null {
  for (const key of keys) {
    const value = text(row[key]);
    if (value !== null) return value;
  }
  return null;
}

/** A 0-4 review-star count, or `null` for NOT RECORDED — never coerced to 0. */
function stars(value: unknown): number | null {
  const raw = unwrapScalar(value);
  if (raw === null || raw === undefined || raw === '') return null;
  const n = Number(raw);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n < 0 || n > STRENGTH_SCALE_MAX) return null;
  return n;
}

/**
 * A recorded boolean, or `null` for NOT RECORDED.
 *
 * `negated` is the only field in the payload whose FALSE value is meaningful —
 * a negated synopsis match is evidence AGAINST the term, which is why the
 * builder scores it 1 instead of 3. It arrives as `[false]` (plumber does not
 * auto-unbox), which `asText()` would render as the string "false". Anything
 * that is not a real boolean or the exact string "true"/"false" is NOT RECORDED,
 * never silently "not negated".
 */
export function asBoolean(value: unknown): boolean | null {
  const raw = unwrapScalar(value);
  if (typeof raw === 'boolean') return raw;
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  return null;
}

/** ClinVar deep-link, built only from a genuine VCV accession or bare numeric id. */
export function clinvarUrl(variationId: string | null): string | null {
  if (!variationId) return null;
  const match = /^(?:VCV)?0*(\d+)(?:\.\d+)?$/i.exec(variationId);
  return match ? `https://www.ncbi.nlm.nih.gov/clinvar/variation/${match[1]}/` : null;
}

function normalizeClinvar(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const variationId = text(row.id);
  const classification = text(row.classification);
  const consequence = text(row.consequence);
  const starCount = stars(row.stars);
  if (variationId === null && classification === null && consequence === null &&
      starCount === null) {
    return null;
  }
  return {
    kind: 'clinvar',
    variationId,
    classification,
    stars: starCount,
    consequence,
    // Prefer the stored url; fall back to one derived from the id, and null when
    // neither can be produced honestly.
    url: text(row.url) ?? clinvarUrl(variationId),
  };
}

function normalizeExternal(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const fields: EvidenceField[] = [];
  for (const key of EXTERNAL_FIELD_ORDER) {
    const value = text(row[key]);
    if (value !== null) fields.push({ key, label: EXTERNAL_FIELD_LABELS[key], value });
  }
  // An unrecognised key is shown under its RAW name rather than dropped —
  // dropping unknown keys is precisely what produced this bug.
  for (const key of Object.keys(row)) {
    if ((EXTERNAL_FIELD_ORDER as readonly string[]).includes(key)) continue;
    const value = text(row[key]);
    if (value !== null) fields.push({ key, label: key, value });
  }
  return fields.length > 0 ? { kind: 'external', fields } : null;
}

function normalizeLiterature(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const matchedText = text(row.matched_text);
  const context = text(row.context);
  const pattern = text(row.pattern);
  const negated = asBoolean(row.negated);
  if (matchedText === null && context === null && pattern === null && negated === null) {
    return null;
  }
  return { kind: 'literature', matchedText, negated, pattern, context };
}

function normalizeGeneric(row: Record<string, unknown>): NormalizedEvidenceRecord | null {
  const variationId = firstText(row, GENERIC_VARIATION_ID_KEYS);
  const consequence = firstText(row, GENERIC_CONSEQUENCE_KEYS);
  const classification = firstText(row, GENERIC_CLASSIFICATION_KEYS);
  if (variationId === null && consequence === null && classification === null) return null;
  return { kind: 'generic', variationId, consequence, classification, url: text(row.url) };
}

function normalizerFor(
  sourceKey: string | null,
  sourceType: string | null
): (row: Record<string, unknown>) => NormalizedEvidenceRecord | null {
  const key = sourceKey?.toLowerCase() ?? '';
  if (key === 'clinvar') return normalizeClinvar;
  if (key === 'synopsis' || sourceType === 'literature') return normalizeLiterature;
  if (key === 'extdb2') return normalizeExternal;
  return normalizeGeneric;
}

/** Normalize one evidence row's `evidence_json` into renderable records. */
export function normalizeEvidenceRecordList(
  payload: unknown,
  sourceKey: string | null,
  sourceType: string | null
): NormalizedEvidenceRecord[] {
  if (!isRecord(payload)) return [];
  let list: unknown[] = [];
  for (const key of RECORD_LIST_KEYS) {
    if (Array.isArray(payload[key])) {
      list = payload[key] as unknown[];
      break;
    }
  }
  const normalize = normalizerFor(sourceKey, sourceType);
  return list
    .filter(isRecord)
    .map(normalize)
    .filter((row): row is NormalizedEvidenceRecord => row !== null);
}
```

- [ ] **Step 5: Wire it into `variationProvenance.ts` and run both specs**

In `variationProvenance.ts`: delete `VARIATION_ID_KEYS`/`CONSEQUENCE_KEYS`/
`CLASSIFICATION_KEYS`/`RECORD_LIST_KEYS`/`firstText`/`normalizeRecordRows` and the
`NormalizedEvidenceRecordRow` interface; re-export the new type
(`export type { NormalizedEvidenceRecord } from './variationEvidenceRecords';`); change
`NormalizedEvidence.records` to `NormalizedEvidenceRecord[]`; and in
`normalizeEvidenceRecords()` call
`normalizeEvidenceRecordList(row.evidence_json, sourceKey, asText(row.source_type))`.
Keep `normalizeMatched()` and `clinvarVariationUrl()` exactly as they are — `matched` holds
strings and must never enter the record-container probe.

Run:
```bash
cd app && npx vitest run src/views/pages/components/variationEvidenceRecords.spec.ts \
                        src/views/pages/components/variationProvenance.spec.ts
cd app && npm run type-check
```
Expected: PASS. Update any `variationProvenance.spec.ts` assertion that named the removed row
type; do **not** relax an assertion about what is rendered.

- [ ] **Step 6: Verify file sizes and commit**

```bash
wc -l app/src/views/pages/components/variationProvenance.ts \
      app/src/views/pages/components/variationEvidenceRecords.ts   # both must be <= 600
git add app/src/views/pages/components/variationEvidenceRecords.ts \
        app/src/views/pages/components/variationEvidenceRecords.spec.ts \
        app/src/views/pages/components/variationProvenance.ts \
        app/src/views/pages/components/variationProvenance.spec.ts \
        app/src/test-utils/variationEvidenceShapesFixture.ts
git commit -m "fix(612): render all three evidence_json record shapes"
```

---

## Task 3: Render the three shapes in the evidence dialog

**Files:**
- Create: `app/src/views/pages/components/VariationEvidenceRecordList.vue`
- Modify: `app/src/views/pages/components/VariationProvenanceDialog.vue`
- Test: `app/src/views/pages/__tests__/VariationProvenanceDialog.spec.ts`

**Interfaces:**
- Consumes: `NormalizedEvidenceRecord` from Task 2.
- Produces: `<VariationEvidenceRecordList :records="record.records" />`, mounted INSIDE the
  existing per-source `v-for` (`VariationProvenanceDialog.vue:103`), where `record` is one
  `NormalizedEvidence` and `record.records` is its record list. There is no `evidence.records`.

- [ ] **Step 1: Write the failing spec additions**

Append to `app/src/views/pages/__tests__/VariationProvenanceDialog.spec.ts`, reusing whatever
mount helper that file already defines:

```ts
import { evidenceShapes } from '@/test-utils/variationEvidenceShapesFixture';

describe('evidence record rendering by shape (#612)', () => {
  it('renders mechanism and confidence for an external-database payload', async () => {
    const wrapper = await mountWithEvidence([{
      source_type: ['external_database'], source_key: ['extdb2'],
      batch_id: ['extdb2-2026-02'], source_version: null,
      evidence_summary: ['1 record from batch extdb2-2026-02, definitive'],
      evidence_strength: [4], created_at: ['2026-08-05T15:31:37'],
      evidence_json: evidenceShapes.extdb2.sample,
    }]);
    expect(wrapper.text()).toContain('Mechanism');
    expect(wrapper.text()).toContain('dominant negative');
    expect(wrapper.text()).toContain('Allelic requirement');
  });

  it('renders a negated badge and the sentence context for a literature payload', async () => {
    const wrapper = await mountWithEvidence([{
      source_type: ['literature'], source_key: ['synopsis'],
      batch_id: ['synopsis-2026-02'], source_version: null,
      evidence_summary: ['2 synopsis matches (includes negated context)'],
      evidence_strength: [1], created_at: ['2026-08-05T15:31:37'],
      evidence_json: evidenceShapes.synopsis.sample,
    }]);
    expect(wrapper.text()).toContain('Haploinsufficiency');
    expect(wrapper.text()).toContain('posited as pathomechanism');
    expect(wrapper.findAll('[data-testid="evidence-negated-badge"]')).toHaveLength(1);
  });

  it('renders review stars for a ClinVar payload', async () => {
    const wrapper = await mountWithEvidence([{
      source_type: ['external_database'], source_key: ['clinvar'],
      batch_id: ['clinvar-2026-02'], source_version: null,
      evidence_summary: ['2 ClinVar records, max 2 stars'],
      evidence_strength: [2], created_at: ['2026-08-05T15:31:37'],
      evidence_json: evidenceShapes.clinvar.sample,
    }]);
    expect(wrapper.text()).toContain('Likely pathogenic');
    expect(wrapper.text()).toMatch(/1 of 4|2 of 4/);
  });
});
```

If the existing spec has no `mountWithEvidence`, write one that stubs the evidence fetch the
dialog uses and returns the mounted wrapper after `await flushPromises()`.

- [ ] **Step 2: Run and confirm it fails**

Run: `cd app && npx vitest run src/views/pages/__tests__/VariationProvenanceDialog.spec.ts`
Expected: FAIL — "Mechanism" not found (the current dialog renders only the generic row).

- [ ] **Step 3: Implement `VariationEvidenceRecordList.vue`**

One `<li>` per record, one branch per `kind`. `data-testid="evidence-negated-badge"` on the
negated badge. Never render a field whose value is `null`. Star display uses `strengthDisplay()`
from `variationProvenance.ts` so an unrecorded count shows "Not recorded" and draws no stars. The
component is presentation-only — no fetching, no props beyond `records`.

- [ ] **Step 4: Replace the record loop in `VariationProvenanceDialog.vue`**

Inside the existing `v-for="(record, index) in records"` section (`VariationProvenanceDialog.vue:103`),
swap the per-record markup for `<VariationEvidenceRecordList :records="record.records" />`. `records`
at that level is the array of per-SOURCE `NormalizedEvidence` objects; the renderable rows are
`record.records`. Leave the "Matched via" section, the Imported line and the summary line untouched.

- [ ] **Step 5: Run the specs and the whole provenance suite**

```bash
cd app && npx vitest run src/views/pages src/views/curate
cd app && npm run type-check
wc -l app/src/views/pages/components/VariationProvenanceDialog.vue \
      app/src/views/pages/components/VariationEvidenceRecordList.vue
```
Expected: PASS, both files ≤ 600. `EntityEvidenceGridProvenance.spec.ts`'s golden-HTML inertness
assertion must still pass **unchanged** — if it fails, the change leaked into the
no-assertion-row rendering path and is wrong.

- [ ] **Step 6: Commit**

```bash
git add app/src/views/pages
git commit -m "feat(612): render external-database and literature evidence records"
```

---

## Task 4: `apply_confirmations` gate on the planner

**Files:**
- Modify: `api/functions/variation-provenance-reconcile.R`
- Test: `api/tests/testthat/test-unit-variation-provenance-reconcile.R`

**Interfaces:**
- Produces:
  ```r
  variation_provenance_plan_reconciliation(previous, submitted, actions = NULL,
                                           apply_rejections = TRUE,
                                           apply_confirmations = TRUE)
  variation_provenance_reconcile_for_review(entity_id, submitted, actions, review_user_id,
                                            conn = NULL, apply_rejections = TRUE,
                                            apply_confirmations = TRUE)
  ```
  Tasks 5 and 8 pass `apply_confirmations = FALSE`.

- [ ] **Step 1: Write the failing tests**

Append to `api/tests/testthat/test-unit-variation-provenance-reconcile.R`, following the helper
style already in that file:

```r
test_that("apply_confirmations = FALSE suppresses every confirmation edge", {
  previous <- tibble::tibble(
    assertion_id = c(1L, 2L, 3L),
    vario_id     = c("VariO:0015", "VariO:0017", "VariO:0031"),
    modifier_id  = c(1L, 1L, 1L),
    state        = c("active_unconfirmed", "suggested", "rejected")
  )
  submitted <- tibble::tibble(
    vario_id = c("VariO:0015", "VariO:0017", "VariO:0031"), modifier_id = c(1L, 1L, 1L)
  )
  actions <- tibble::tibble(
    vario_id = "VariO:0015", modifier_id = 1L, provenance_action = "confirm"
  )

  plan <- variation_provenance_plan_reconciliation(
    previous, submitted, actions,
    apply_rejections = TRUE, apply_confirmations = FALSE
  )
  expect_equal(nrow(plan), 0L)
})

test_that("apply_confirmations = FALSE still applies rejection edges", {
  previous <- tibble::tibble(
    assertion_id = c(1L, 2L),
    vario_id     = c("VariO:0015", "VariO:0017"),
    modifier_id  = c(1L, 1L),
    state        = c("active_unconfirmed", "suggested")
  )
  submitted <- tibble::tibble(vario_id = character(), modifier_id = integer())

  plan <- variation_provenance_plan_reconciliation(
    previous, submitted, actions = NULL,
    apply_rejections = TRUE, apply_confirmations = FALSE
  )
  expect_setequal(plan$assertion_id, c(1L, 2L))
  expect_true(all(plan$to_state == "rejected"))
  expect_true(all(!plan$needs_attribution))
})

test_that("apply_confirmations = FALSE never re-stamps an already-confirmed row", {
  previous <- tibble::tibble(
    assertion_id = 1L, vario_id = "VariO:0015", modifier_id = 1L, state = "confirmed"
  )
  submitted <- tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
  plan <- variation_provenance_plan_reconciliation(
    previous, submitted, actions = NULL,
    apply_rejections = TRUE, apply_confirmations = FALSE
  )
  expect_equal(nrow(plan), 0L)
})

test_that("apply_confirmations defaults to TRUE so existing call sites are unchanged", {
  previous <- tibble::tibble(
    assertion_id = 1L, vario_id = "VariO:0017", modifier_id = 1L, state = "suggested"
  )
  submitted <- tibble::tibble(vario_id = "VariO:0017", modifier_id = 1L)
  plan <- variation_provenance_plan_reconciliation(previous, submitted)
  expect_equal(plan$to_state, "confirmed")
  expect_true(plan$needs_attribution)
})
```

- [ ] **Step 2: Run and confirm failure**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-variation-provenance-reconcile.R')"
```
Expected: FAIL — `unused argument (apply_confirmations = FALSE)`.

- [ ] **Step 3: Add the parameter**

In `variation_provenance_plan_reconciliation()`, wrap the three submitted-branch assignments:

```r
  to_state <- from_state
  # Submitted branch (rows 1-5). Gated ONLY by apply_confirmations, which the
  # approval hook and the curation queue's dismiss endpoint set FALSE. It stays
  # TRUE everywhere else, so every pre-#612 call site is byte-identical.
  if (isTRUE(apply_confirmations)) {
    to_state[is_submitted & from_state == "suggested"] <- "confirmed"
    to_state[is_submitted & from_state == "rejected"] <- "confirmed"
    to_state[is_submitted & from_state == "active_unconfirmed" & confirm_requested] <- "confirmed"
  }
```

Add the `@param apply_confirmations` roxygen block, and extend the file-header state table's
footnote: the two rejection rows require `apply_rejections = TRUE`; the confirmation rows require
`apply_confirmations = TRUE`. Thread the argument through
`variation_provenance_reconcile_for_review()` as a pure passthrough, exactly as
`apply_rejections` already is.

- [ ] **Step 4: Run the tests**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-variation-provenance-reconcile.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-variation-connect-write-guard.R')"
wc -l api/functions/variation-provenance-reconcile.R   # must be <= 600
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/functions/variation-provenance-reconcile.R \
        api/tests/testthat/test-unit-variation-provenance-reconcile.R
git commit -m "feat(612): add apply_confirmations gate to the reconciliation planner"
```

---

## Task 5: Approval-time reconciliation module

**Files:**
- Create: `api/functions/variation-provenance-approval.R`
- Modify: `api/bootstrap/load_modules.R`
- Test: `api/tests/testthat/test-unit-approval-service-provenance.R` (created here, extended in Task 6)

**Interfaces:**
- Consumes: `variation_provenance_assertions_for_entity()`,
  `variation_provenance_plan_reconciliation()`,
  `variation_provenance_apply_reconciliation()` (Task 4).
- Produces:
  ```r
  variation_provenance_served_terms_for_entity(entity_id, conn = NULL)
    -> tibble(vario_id character, modifier_id integer)
  variation_provenance_reconcile_on_approval(entity_id, review_user_id, conn = NULL)
    -> integer count of assertion rows updated
  ```
  Task 6 calls `variation_provenance_reconcile_on_approval()`; Task 8 calls
  `variation_provenance_served_terms_for_entity()`.

- [ ] **Step 1: Write the failing tests**

```r
# api/tests/testthat/test-unit-approval-service-provenance.R
#
# #612: approval is when the served set becomes real.
#
# Reconciliation runs on WRITE, gated by review_write_save_determines_served_set().
# review_update() unconditionally sets review_approved = 0, so a Reviewer who
# removes a term in a draft and approves it later never triggers the rejection
# edge — the term stops being served but the assertion stays
# active_unconfirmed, so the suggestion queue keeps offering it. This hook closes
# that, rejection-only: approving a review is an act on the review, not a
# per-term reading of machine evidence, so it must never CONFIRM anything.
source_api_file("functions/variation-provenance-reconcile.R", local = FALSE)
source_api_file("functions/variation-provenance-approval.R", local = FALSE)

test_that("served terms come from primary approved reviews with active connect rows", {
  captured <- NULL
  mock_globals(list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      captured <<- list(sql = sql, params = params)
      data.frame(vario_id = c("VariO:0015", "VariO:0017"), modifier_id = c(1L, 5L))
    }
  ))
  served <- variation_provenance_served_terms_for_entity(42L)
  expect_equal(served$vario_id, c("VariO:0015", "VariO:0017"))
  expect_equal(served$modifier_id, c(1L, 5L))
  expect_equal(captured$params, list(42L))
  # The served set is defined by the PUBLIC read's own rule; a query that drops
  # any of these three clauses serves a different set than the entity page does.
  expect_match(captured$sql, "is_active = 1")
  expect_match(captured$sql, "is_primary = 1")
  expect_match(captured$sql, "review_approved = 1")
})

test_that("an empty served set yields a zero-row tibble with the right columns", {
  mock_globals(list(
    db_execute_query = function(...) data.frame()
  ))
  served <- variation_provenance_served_terms_for_entity(42L)
  expect_equal(nrow(served), 0L)
  expect_setequal(names(served), c("vario_id", "modifier_id"))
})

test_that("approval reconciliation rejects an omitted term and leaves a served one alone", {
  applied <- NULL
  mock_globals(list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(
        assertion_id = c(1L, 2L),
        vario_id     = c("VariO:0015", "VariO:0017"),
        modifier_id  = c(1L, 1L),
        state        = c("active_unconfirmed", "active_unconfirmed")
      )
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0015", modifier_id = 1L)
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    }
  ))
  updated <- variation_provenance_reconcile_on_approval(42L, review_user_id = 7L)
  expect_equal(updated, 1L)
  expect_equal(applied$assertion_id, 2L)
  expect_equal(applied$to_state, "rejected")
})

test_that("approval reconciliation never confirms, even for a submitted suggestion", {
  applied <- NULL
  mock_globals(list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(assertion_id = 1L, vario_id = "VariO:0017",
                     modifier_id = 1L, state = "suggested")
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = "VariO:0017", modifier_id = 1L)
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    }
  ))
  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 0L)
  expect_null(applied)
})

test_that("an EMPTY post-approval served set rejects every assertion for the entity", {
  # Approval itself creates the primary approved review, so an entity whose
  # approved review carries no variation terms legitimately serves none. A
  # "skip when empty" guard would strand exactly the assertions this hook exists
  # to retire.
  applied <- NULL
  mock_globals(list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(assertion_id = c(1L, 2L), vario_id = c("VariO:0015", "VariO:0017"),
                     modifier_id = c(1L, 1L),
                     state = c("active_unconfirmed", "suggested"))
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(vario_id = character(), modifier_id = integer())
    },
    variation_provenance_apply_reconciliation = function(plan, review_user_id, conn = NULL) {
      applied <<- plan
      nrow(plan)
    }
  ))
  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 2L)
  expect_true(all(applied$to_state == "rejected"))
})

test_that("an entity with no assertion rows short-circuits without a served-set query", {
  served_called <- FALSE
  mock_globals(list(
    variation_provenance_assertions_for_entity = function(entity_id, conn = NULL) {
      tibble::tibble(assertion_id = integer(), vario_id = character(),
                     modifier_id = integer(), state = character())
    },
    variation_provenance_served_terms_for_entity = function(entity_id, conn = NULL) {
      served_called <<- TRUE
      tibble::tibble(vario_id = character(), modifier_id = integer())
    }
  ))
  expect_equal(variation_provenance_reconcile_on_approval(42L, review_user_id = 7L), 0L)
  expect_false(served_called)
})
```

- [ ] **Step 2: Run and confirm failure**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-approval-service-provenance.R')"
```
Expected: FAIL — cannot open `functions/variation-provenance-approval.R`.

- [ ] **Step 3: Implement the module**

```r
# functions/variation-provenance-approval.R
#
# Approval-time reconciliation for variation-ontology provenance assertions (#612).
#
# WHY A SEPARATE FILE
# -------------------
# variation-provenance-reconcile.R owns the state machine and is near the
# 600-line ceiling; this is the same split that produced
# variation-provenance-carry-forward.R.
#
# WHY THIS EXISTS
# ---------------
# Write reconciliation gates its REJECTION edges on
# review_write_save_determines_served_set() -- a Reviewer's draft omission must
# not suppress provenance for terms the approved review is still serving. But
# review_update() unconditionally sets review_approved = 0
# (functions/review-repository.R), so on the ordinary edit-then-approve-separately
# workflow the rejection edge never fires at all: the term stops being served,
# yet its assertion stays active_unconfirmed and the curation queue keeps
# offering it.
#
# The principle is the write path's own, applied one step later: APPROVAL IS WHEN
# THE SERVED SET BECOMES REAL.
#
# REJECTION-ONLY, DELIBERATELY
# ----------------------------
# apply_confirmations = FALSE. Approving a review is an act on the REVIEW, not a
# per-term reading of machine evidence. Promoting active_unconfirmed ->
# confirmed here would restore exactly the silent promotion #608 exists to stop.
# Confirmation stays an explicit act, on the review form or in the curation
# queue.
#
# NEVER OPENS A TRANSACTION. It only uses the `conn` handed to it, so it commits
# or rolls back with the approval that triggered it.

#' Read one entity's publicly served variation-ontology terms
#'
#' The served set is the terms on the entity's PRIMARY APPROVED reviews with an
#' active connect row -- byte-identical to svc_entity_variation()'s own rule
#' (services/entity-read-endpoint-service.R). Dropping any of the three clauses
#' would serve a different set than the entity page does, which is why the unit
#' test asserts all three onto the SQL text.
#'
#' Migrations 051-053 enforce (review_id, entity_id) agreement on the connect
#' table, so joining the connect row to its review by review_id alone is sound.
#'
#' @param entity_id Integer entity id.
#' @param conn Database connection or pool. Passed straight through.
#' @return Tibble(vario_id character, modifier_id integer). Possibly zero rows.
#' @export
variation_provenance_served_terms_for_entity <- function(entity_id, conn = NULL) {
  rows <- db_execute_query(
    "SELECT c.vario_id, c.modifier_id
       FROM ndd_review_variation_ontology_connect c
       JOIN ndd_entity_review r ON r.review_id = c.review_id
      WHERE c.entity_id = ?
        AND c.is_active = 1
        AND r.is_primary = 1
        AND r.review_approved = 1",
    list(as.integer(entity_id)),
    conn = conn
  )

  if (is.null(rows) || nrow(rows) == 0L) {
    return(tibble::tibble(vario_id = character(), modifier_id = integer()))
  }

  tibble::tibble(
    vario_id    = as.character(rows$vario_id),
    modifier_id = as.integer(rows$modifier_id)
  )
}

#' Reject assertions the entity no longer serves, after a review approval
#'
#' Reads the served set AFTER the approval has been applied on `conn`, so it
#' observes the review this transaction just made primary and approved.
#'
#' An EMPTY served set is meaningful, not a reason to skip: approval itself
#' creates the primary approved review, so an entity whose approved review
#' carries no variation terms legitimately serves none, and every assertion for
#' it must be rejected. A "skip when empty" guard would strand exactly the
#' assertions the curation queue exists to retire.
#'
#' @param entity_id Integer entity id.
#' @param review_user_id Integer id of the approving user. Never used for
#'   attribution here (no confirmation can be planned) but passed through so a
#'   future confirmation edge cannot silently abort.
#' @param conn Database connection or pool. Never opens a transaction.
#' @return Integer count of assertion rows updated.
#' @export
variation_provenance_reconcile_on_approval <- function(entity_id, review_user_id, conn = NULL) {
  previous <- variation_provenance_assertions_for_entity(entity_id, conn = conn)
  if (nrow(previous) == 0L) {
    return(0L)
  }

  served <- variation_provenance_served_terms_for_entity(entity_id, conn = conn)

  plan <- variation_provenance_plan_reconciliation(
    previous            = previous,
    submitted           = served,
    actions             = NULL,
    apply_rejections    = TRUE,
    apply_confirmations = FALSE
  )
  if (nrow(plan) == 0L) {
    return(0L)
  }

  variation_provenance_apply_reconciliation(
    plan, review_user_id = review_user_id, conn = conn
  )
}
```

- [ ] **Step 4: Register in the loader**

In `api/bootstrap/load_modules.R`, add `"functions/variation-provenance-approval.R"` immediately
after `"functions/variation-provenance-carry-forward.R"`.

- [ ] **Step 5: Run the tests**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-approval-service-provenance.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-variation-connect-write-guard.R')"
```
Expected: PASS. The write guard must still pass — this module issues no connect-table SQL.

- [ ] **Step 6: Commit**

```bash
git add api/functions/variation-provenance-approval.R api/bootstrap/load_modules.R \
        api/tests/testthat/test-unit-approval-service-provenance.R
git commit -m "feat(612): add approval-time rejection reconciliation"
```

---

## Task 6: Wire the hook into `svc_approval_review_approve`

**Files:**
- Modify: `api/functions/db-helpers.R`, `api/services/review-write-service.R`,
  `api/services/approval-service.R`
- Test: `api/tests/testthat/test-unit-approval-service-provenance.R` (extend),
  `api/tests/testthat/test-unit-db-helpers-savepoint.R` (create)

**Interfaces:**
- Produces:
  ```r
  db_with_savepoint_or_transaction(db, savepoint, fn, transaction_runner = db_with_transaction)
  ```
  `fn` receives the connection. Task 8 uses it too.

- [ ] **Step 1: Write the failing tests**

```r
# api/tests/testthat/test-unit-db-helpers-savepoint.R
#
# A write unit that must be atomic can be handed either a pool (production) or a
# caller-owned DBIConnection (with_test_db_transaction(), which has ALREADY
# issued DBI::dbBegin). db_with_transaction() calls DBI::dbWithTransaction()
# either way, and RMariaDB does not support a nested transaction -- so the
# direct-connection case needs a SAVEPOINT instead. This helper is the single
# place that decision lives.
source_api_file("functions/db-helpers.R", local = FALSE)

test_that("a pool goes through the injected transaction runner", {
  seen <- NULL
  fake_pool <- structure(list(), class = c("Pool", "list"))
  result <- db_with_savepoint_or_transaction(
    fake_pool, "unit_test",
    fn = function(conn) "ran",
    transaction_runner = function(code, pool_obj = NULL) {
      seen <<- pool_obj
      code(pool_obj)
    }
  )
  expect_equal(result, "ran")
  expect_identical(seen, fake_pool)
})

test_that("a direct connection uses a savepoint and releases it on success", {
  statements <- character()
  conn <- structure(list(), class = c("MariaDBConnection", "DBIConnection"))
  testthat::local_mocked_bindings(
    dbExecute = function(conn, statement, ...) {
      statements <<- c(statements, statement)
      1L
    },
    .package = "DBI"
  )
  result <- db_with_savepoint_or_transaction(conn, "unit_test", fn = function(cn) "ok")
  expect_equal(result, "ok")
  expect_equal(statements,
               c("SAVEPOINT unit_test", "RELEASE SAVEPOINT unit_test"))
})

test_that("a direct connection rolls back to the savepoint and rethrows", {
  statements <- character()
  conn <- structure(list(), class = c("MariaDBConnection", "DBIConnection"))
  testthat::local_mocked_bindings(
    dbExecute = function(conn, statement, ...) {
      statements <<- c(statements, statement)
      1L
    },
    .package = "DBI"
  )
  expect_error(
    db_with_savepoint_or_transaction(conn, "unit_test",
                                     fn = function(cn) stop("boom")),
    "boom"
  )
  expect_equal(statements,
               c("SAVEPOINT unit_test", "ROLLBACK TO SAVEPOINT unit_test"))
})
```

Append to `test-unit-approval-service-provenance.R`:

```r
source_api_file("services/approval-service.R", local = FALSE)

test_that("approving one review reconciles each affected entity exactly once", {
  reconciled <- list()
  mock_globals(list(
    review_approve = function(review_ids, approving_user_id, approved = TRUE, conn = NULL) {
      review_ids
    },
    db_execute_query = function(sql, params = list(), conn = NULL) {
      data.frame(entity_id = c(11L, 11L, 12L))
    },
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    variation_provenance_reconcile_on_approval = function(entity_id, review_user_id, conn = NULL) {
      reconciled[[length(reconciled) + 1L]] <<- entity_id
      0L
    }
  ))
  result <- svc_approval_review_approve(42L, user_id = 7L, approve = TRUE, pool = NULL)
  expect_equal(result$status, 200)
  expect_equal(sort(unlist(reconciled)), c(11L, 12L))
})

test_that("unapproving a review reconciles nothing", {
  called <- FALSE
  mock_globals(list(
    review_approve = function(review_ids, approving_user_id, approved = TRUE, conn = NULL) {
      review_ids
    },
    db_execute_query = function(sql, params = list(), conn = NULL) {
      data.frame(entity_id = 11L)
    },
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    variation_provenance_reconcile_on_approval = function(...) {
      called <<- TRUE
      0L
    }
  ))
  svc_approval_review_approve(42L, user_id = 7L, approve = FALSE, pool = NULL)
  expect_false(called)
})

test_that("a vector of review ids no longer trips the length-1 'all' check", {
  # `if (as.character(c(42, 43)) == "all")` raises "the condition has length > 1",
  # so this function's documented multi-id support never worked. The per-entity
  # loop depends on it.
  approved <- NULL
  mock_globals(list(
    review_approve = function(review_ids, approving_user_id, approved = TRUE, conn = NULL) {
      approved <<- review_ids
      review_ids
    },
    db_execute_query = function(sql, params = list(), conn = NULL) data.frame(entity_id = 11L),
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    variation_provenance_reconcile_on_approval = function(...) 0L
  ))
  result <- svc_approval_review_approve(c(42L, 43L), user_id = 7L, approve = TRUE, pool = NULL)
  expect_equal(result$status, 200)
  expect_equal(approved, c(42L, 43L))
})
```

- [ ] **Step 2: Run and confirm failure**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-db-helpers-savepoint.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-approval-service-provenance.R')"
```
Expected: FAIL — `could not find function "db_with_savepoint_or_transaction"`, and the vector test
fails with "the condition has length > 1".

- [ ] **Step 3: Add the helper to `api/functions/db-helpers.R`**

```r
#' Run a write unit atomically on either a pool or a caller-owned connection
#'
#' A pool gets a real transaction. A direct DBIConnection is CALLER-OWNED
#' (notably with_test_db_transaction(), which has already issued DBI::dbBegin),
#' and RMariaDB does not support a nested transaction, so it gets a SAVEPOINT
#' instead. Passing such a connection to db_with_transaction() would still call
#' DBI::dbWithTransaction() and fail.
#'
#' @param db Pool or DBIConnection.
#' @param savepoint Savepoint name. Must be a bare SQL identifier -- it is
#'   interpolated, so callers pass a literal, never user input.
#' @param fn Function taking the connection.
#' @param transaction_runner Injectable for tests; defaults to db_with_transaction.
#' @return Whatever `fn` returns.
#' @export
db_with_savepoint_or_transaction <- function(db, savepoint, fn,
                                             transaction_runner = db_with_transaction) {
  if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", savepoint)) {
    stop("savepoint must be a bare SQL identifier")
  }
  if (inherits(db, "DBIConnection")) {
    DBI::dbExecute(db, paste("SAVEPOINT", savepoint))
    return(tryCatch(
      {
        result <- fn(db)
        DBI::dbExecute(db, paste("RELEASE SAVEPOINT", savepoint))
        result
      },
      error = function(error) {
        DBI::dbExecute(db, paste("ROLLBACK TO SAVEPOINT", savepoint))
        stop(error)
      }
    ))
  }
  transaction_runner(fn, pool_obj = db)
}
```

Then make `review_write_run_mutation()` (`api/services/review-write-service.R`) delegate, keeping
its savepoint name and injectable runner so its existing tests are unaffected:

```r
review_write_run_mutation <- function(prepared, db, mutation_fn,
                                      transaction_runner = db_with_transaction) {
  db_with_savepoint_or_transaction(
    db, "review_write_mutation",
    fn = function(txn_conn) mutation_fn(prepared, txn_conn),
    transaction_runner = transaction_runner
  )
}
```

- [ ] **Step 4: Rewrite `svc_approval_review_approve()`**

```r
svc_approval_review_approve <- function(review_id, user_id, approve = FALSE, pool) {
  if (is.null(review_id) || is.null(user_id)) {
    return(list(status = 400, error = "Submitted data can not be null."))
  }

  approve <- as.logical(approve)

  # `if (as.character(c(42, 43)) == "all")` raises "the condition has length > 1",
  # so the documented multi-id support never worked. Guard on length first.
  is_all <- length(review_id) == 1L && identical(as.character(review_id), "all")

  if (is_all) {
    pending_reviews <- pool %>%
      tbl("ndd_entity_review") %>%
      filter(review_approved == 0, is.na(approving_user_id)) %>%
      dplyr::select(review_id) %>%
      collect()
    review_ids <- as.integer(pending_reviews$review_id)
  } else {
    review_ids <- as.integer(review_id)
  }

  if (length(review_ids) == 0) {
    return(list(status = 200, message = "OK. No reviews to approve.", entry = integer(0)))
  }

  # #612: approval is when the served set becomes real. Approve and reconcile in
  # ONE unit so a reconciliation failure rolls the approval back rather than
  # leaving an entity whose served terms and provenance disagree.
  #
  # Direct approval deliberately does NOT come through here: review_write_mutate()
  # calls review_approve() itself on its own transaction, having already
  # reconciled with apply_rejections = TRUE in the same transaction.
  db_with_savepoint_or_transaction(pool, "review_approve_reconcile", fn = function(conn) {
    review_approve(review_ids, user_id, approve, conn = conn)

    if (isTRUE(approve)) {
      placeholders <- paste(rep("?", length(review_ids)), collapse = ", ")
      entity_rows <- db_execute_query(
        paste0("SELECT DISTINCT entity_id FROM ndd_entity_review WHERE review_id IN (",
               placeholders, ")"),
        as.list(review_ids),
        conn = conn
      )
      if (!is.null(entity_rows) && nrow(entity_rows) > 0L) {
        for (entity_id in unique(as.integer(entity_rows$entity_id))) {
          variation_provenance_reconcile_on_approval(
            entity_id = entity_id, review_user_id = user_id, conn = conn
          )
        }
      }
    }
  })

  list(status = 200, message = "OK. Review approved.", entry = review_ids)
}
```

Update the roxygen: note the transaction, the rejection-only reconciliation, and that
`direct_approval` does not route here.

- [ ] **Step 5: Run every affected suite**

Run:
```bash
cd api && for f in test-unit-db-helpers-savepoint test-unit-approval-service-provenance \
                   test-unit-variation-provenance-reconcile test-unit-review-write-service \
                   test-unit-variation-connect-write-guard; do
  echo "== $f"; Rscript --no-init-file -e "testthat::test_file('tests/testthat/$f.R')"
done
wc -l api/functions/db-helpers.R api/services/approval-service.R api/services/review-write-service.R
```
Expected: PASS, all files ≤ 600. If `test-unit-review-write-service.R` does not exist under that
name, run every `tests/testthat/test-*review*` file instead.

- [ ] **Step 6: Commit**

```bash
git add api/functions/db-helpers.R api/services/approval-service.R \
        api/services/review-write-service.R api/tests/testthat
git commit -m "feat(612): reject stale provenance assertions on review approval"
```

---

## Task 7: Suggestion-queue read service

**Files:**
- Create: `api/services/curate-variation-suggestion-service.R`
- Modify: `api/bootstrap/load_modules.R`
- Test: `api/tests/testthat/test-unit-curate-variation-suggestions.R`

**Interfaces:**
- Produces:
  ```r
  svc_curate_variation_suggestion_params(state, source_key, max_strength, moved, q,
                                         sort, page, page_size)
    -> list(state, source_key, max_strength, moved, q, sort, page, page_size)
  svc_curate_variation_suggestions(params, pool)
    -> list(meta = list(page, page_size, total), data = <unnamed list of rows>)
  ```
  Task 9 calls both; Task 10 types the response.

- [ ] **Step 1: Write the failing tests**

```r
# api/tests/testthat/test-unit-curate-variation-suggestions.R
#
# #612 Phase 6: the cross-entity curation queue over UNCONFIRMED machine-derived
# assertions.
#
# The queue is over state IN ('suggested','active_unconfirmed'), NOT 'suggested'
# alone: the backfill wrote every one of its 8,083 rows active_unconfirmed, so a
# 'suggested'-only queue would render an empty page while the ~1,981-item
# weak-evidence backlog it exists to make tractable sits in the other state.
source_api_file("services/curate-variation-suggestion-service.R", local = FALSE)

test_that("defaults are the strongest-evidence-first first page", {
  params <- svc_curate_variation_suggestion_params(
    state = NULL, source_key = NULL, max_strength = NULL, moved = NULL,
    q = NULL, sort = NULL, page = NULL, page_size = NULL
  )
  expect_null(params$state)
  expect_equal(params$sort, "strength_desc")
  expect_equal(params$page, 1L)
  expect_equal(params$page_size, 25L)
})

test_that("page_size is capped at 100 and page floors at 1", {
  params <- svc_curate_variation_suggestion_params(
    NULL, NULL, NULL, NULL, NULL, NULL, page = 0L, page_size = 5000L
  )
  expect_equal(params$page, 1L)
  expect_equal(params$page_size, 100L)
})

test_that("an unknown state, sort or source_key is a 400, never a silent default", {
  expect_error(
    svc_curate_variation_suggestion_params("confirmed", NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, NULL, NULL, NULL, NULL, "; DROP", NULL, NULL),
    class = "error_400"
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, "clin var", NULL, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
})

test_that("max_strength accepts only 0-4", {
  expect_equal(
    svc_curate_variation_suggestion_params(NULL, NULL, 0L, NULL, NULL, NULL, NULL, NULL)$max_strength,
    0L
  )
  expect_error(
    svc_curate_variation_suggestion_params(NULL, NULL, 5L, NULL, NULL, NULL, NULL, NULL),
    class = "error_400"
  )
})

test_that("the listing query binds every filter and never interpolates a value", {
  captured <- list()
  mock_globals(list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      captured[[length(captured) + 1L]] <<- list(sql = sql, params = params)
      if (grepl("COUNT", sql, fixed = TRUE)) return(data.frame(total = 0L))
      data.frame()
    }
  ))
  params <- svc_curate_variation_suggestion_params(
    "active_unconfirmed", "clinvar", 1L, "true", "CHD8", "strength_asc", 2L, 10L
  )
  svc_curate_variation_suggestions(params, pool = NULL)

  listing <- captured[[length(captured)]]
  expect_true(any(vapply(listing$params, function(p) identical(p, "clinvar"), logical(1))))
  expect_false(grepl("clinvar", listing$sql, fixed = TRUE))
  expect_false(grepl("CHD8", listing$sql, fixed = TRUE))
  # Visibility and the two derived flags are part of the statement, never
  # post-filtered in R.
  expect_match(listing$sql, "ndd_entity_view")
  expect_match(listing$sql, "origin_review_id")
  expect_match(listing$sql, "is_primary = 1")
})

test_that("rows group evidence per assertion and expose the derived flags", {
  mock_globals(list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("COUNT", sql, fixed = TRUE)) return(data.frame(total = 1L))
      data.frame(
        assertion_id = c(1L, 1L), entity_id = c(42L, 42L),
        symbol = c("CHD8", "CHD8"),
        disease_ontology_name = c("CHD8 disorder", "CHD8 disorder"),
        vario_id = c("VariO:0015", "VariO:0015"),
        vario_name = c("protein truncation", "protein truncation"),
        modifier_id = c(1L, 1L),
        state = c("active_unconfirmed", "active_unconfirmed"),
        served = c(1L, 1L), moved = c(1L, 1L),
        source_type = c("external_database", "literature"),
        source_key = c("clinvar", "synopsis"),
        batch_id = c("clinvar-2026-02", "synopsis-2026-02"),
        evidence_strength = c(2L, 3L),
        evidence_summary = c("10 ClinVar records, max 2 stars", "1 synopsis match"),
        stringsAsFactors = FALSE
      )
    }
  ))
  params <- svc_curate_variation_suggestion_params(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
  )
  result <- svc_curate_variation_suggestions(params, pool = NULL)

  expect_equal(result$meta$total, 1L)
  expect_length(result$data, 1L)
  row <- result$data[[1L]]
  expect_equal(row$entity_id, 42L)
  expect_true(row$served)
  expect_true(row$moved)
  expect_equal(row$max_strength, 3L)
  # Strongest evidence first, mirroring the entity-scoped surface's ordering.
  expect_equal(vapply(row$evidence, function(e) e$source_key, character(1)),
               c("synopsis", "clinvar"))
})

test_that("an assertion with no evidence row yields an empty array, not a phantom", {
  mock_globals(list(
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("COUNT", sql, fixed = TRUE)) return(data.frame(total = 1L))
      data.frame(
        assertion_id = 1L, entity_id = 42L, symbol = "CHD8",
        disease_ontology_name = "CHD8 disorder", vario_id = "VariO:0015",
        vario_name = "protein truncation", modifier_id = 1L,
        state = "suggested", served = 0L, moved = 0L,
        source_type = NA_character_, source_key = NA_character_,
        batch_id = NA_character_, evidence_strength = NA_integer_,
        evidence_summary = NA_character_, stringsAsFactors = FALSE
      )
    }
  ))
  params <- svc_curate_variation_suggestion_params(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
  )
  row <- svc_curate_variation_suggestions(params, pool = NULL)$data[[1L]]
  expect_length(row$evidence, 0L)
  expect_null(row$max_strength)
  expect_false(row$served)
})
```

- [ ] **Step 2: Run and confirm failure**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-curate-variation-suggestions.R')"
```
Expected: FAIL — cannot open `services/curate-variation-suggestion-service.R`.

- [ ] **Step 3: Implement the read half of the service**

The file starts with the module header (why the queue spans both unconfirmed states; that it is
Curator-gated, DB-only, one query plus one count; that nothing here writes the connect table).
Then:

* `CURATE_VARIATION_QUEUE_STATES <- c("active_unconfirmed", "suggested")`
* `CURATE_VARIATION_QUEUE_SORTS <- c("strength_desc", "strength_asc", "entity_asc")`
* `svc_curate_variation_suggestion_params()` — validates each value against its closed allowlist
  and raises `stop_for_bad_request()` otherwise; `source_key` must match `^[A-Za-z0-9_-]{1,64}$`;
  `q` is trimmed and length-capped at 64; `moved` is `TRUE` only for the exact strings `"true"`
  and `"TRUE"`; `page`/`page_size` coerce with `suppressWarnings(as.integer(...))`, floor at 1 and
  cap at 100, and an un-coercible value is a 400 rather than a silent default.
* `.svc_cvs_where()` — returns `list(sql = <string of " AND ..." clauses>, params = list())`,
  building one bound placeholder per active filter. `q` becomes
  `(v.symbol LIKE ? OR a.entity_id = ?)` with params `paste0("%", q, "%")` and
  `suppressWarnings(as.integer(q))`.
* `svc_curate_variation_suggestions(params, pool)` — two `db_execute_query()` calls sharing the
  same `WHERE`:

```sql
-- shared FROM/WHERE, with the two derived flags computed in SQL
FROM variation_ontology_assertion a
JOIN ndd_entity_view v ON v.entity_id = a.entity_id
LEFT JOIN variation_ontology_list l ON l.vario_id = a.vario_id
LEFT JOIN variation_ontology_evidence e ON e.assertion_id = a.assertion_id
WHERE a.state IN ('active_unconfirmed','suggested')
  <filters>
```

with

```sql
EXISTS (SELECT 1
          FROM ndd_review_variation_ontology_connect c
          JOIN ndd_entity_review r ON r.review_id = c.review_id
         WHERE c.entity_id = a.entity_id
           AND c.vario_id = a.vario_id
           AND c.modifier_id = a.modifier_id
           AND c.is_active = 1
           AND r.is_primary = 1
           AND r.review_approved = 1)                                  AS served
```

and

```sql
EXISTS (SELECT 1
          FROM variation_ontology_evidence e2
         WHERE e2.assertion_id = a.assertion_id
           AND e2.origin_review_id IS NOT NULL
           AND NOT EXISTS (SELECT 1
                             FROM ndd_entity_review r2
                            WHERE r2.review_id = e2.origin_review_id
                              AND r2.entity_id = a.entity_id
                              AND r2.is_primary = 1
                              AND r2.review_approved = 1))             AS moved
```

  The count query is `SELECT COUNT(DISTINCT a.assertion_id) AS total` over that FROM/WHERE. The
  listing query selects the row columns plus the evidence columns, and paginates on assertions —
  not on joined rows — with an inner-query `LIMIT`/`OFFSET`:

```sql
JOIN (SELECT a2.assertion_id
        FROM variation_ontology_assertion a2
        JOIN ndd_entity_view v2 ON v2.entity_id = a2.entity_id
       WHERE ... same filters ...
       GROUP BY a2.assertion_id
       ORDER BY <sort> LIMIT ? OFFSET ?) page ON page.assertion_id = a.assertion_id
```

  `<sort>` is chosen from the allowlist, never from the raw parameter:
  `strength_desc` → `MAX(e2s.evidence_strength) DESC, a2.assertion_id ASC` (via a correlated
  subquery or a LEFT JOIN inside the paging query), `strength_asc` → the same ascending,
  `entity_asc` → `a2.entity_id ASC, a2.vario_id ASC, a2.modifier_id ASC`. Every ordering ends with
  `a2.assertion_id ASC` so paging is stable.

  Grouping into the response is done in R over the fetched rows, exactly as
  `svc_entity_variation_suggestions()` does: order evidence within an assertion by recorded
  strength descending then `source_key` ascending, drop rows whose `source_key` is NA (the LEFT
  JOIN's phantom), and map NA scalars to NULL so `null="null"` renders them as JSON `null`.
  Reuse `.svc_vp_na_to_null()` and `.svc_vp_evidence_order()` from
  `services/entity-variation-provenance-service.R` — the loader sources that file first, so both
  are in scope. Do NOT duplicate them.

- [ ] **Step 4: Register in the loader**

In `api/bootstrap/load_modules.R`, add `"services/curate-variation-suggestion-service.R"`
immediately **after** `"services/entity-variation-provenance-service.R"`, so the shared helpers
above are defined before this file uses them.

- [ ] **Step 5: Run the tests**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-curate-variation-suggestions.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-variation-connect-write-guard.R')"
wc -l api/services/curate-variation-suggestion-service.R
```
Expected: PASS, ≤ 600 lines. The write guard matters here: this file MENTIONS
`ndd_review_variation_ontology_connect` in a `SELECT`, which is allowed; it must never co-locate
that name with `INSERT`/`UPDATE`/`DELETE`/`REPLACE`/`TRUNCATE`.

- [ ] **Step 6: Commit**

```bash
git add api/services/curate-variation-suggestion-service.R api/bootstrap/load_modules.R \
        api/tests/testthat/test-unit-curate-variation-suggestions.R
git commit -m "feat(612): add the cross-entity variation suggestion queue query"
```

---

## Task 8: Confirm / dismiss write endpoints (service half)

**Files:**
- Modify: `api/services/curate-variation-suggestion-service.R`
- Test: `api/tests/testthat/test-unit-curate-variation-suggestions.R` (extend)

**Interfaces:**
- Produces:
  ```r
  svc_curate_variation_apply(items, action, review_user_id, db)
    -> list(requested = int, applied = int, skipped = <unnamed list of
            list(entity_id, vario_id, modifier_id, reason)>)
  ```
  `action` is `"confirm"` or `"dismiss"`. Task 9 calls it.

- [ ] **Step 1: Write the failing tests**

```r
test_that("confirm refuses an item that is not served", {
  # A `suggested` assertion is by definition NOT in the curated set. Confirming
  # it would have to ADD the term, which is a review write.
  mock_globals(list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("FOR UPDATE", sql, fixed = TRUE)) {
        return(data.frame(assertion_id = 1L, entity_id = 42L, vario_id = "VariO:0017",
                          modifier_id = 1L, state = "suggested", stringsAsFactors = FALSE))
      }
      data.frame(vario_id = character(), modifier_id = integer())
    }
  ))
  result <- svc_curate_variation_apply(
    list(list(entity_id = 42L, vario_id = "VariO:0017", modifier_id = 1L)),
    action = "confirm", review_user_id = 7L, db = NULL
  )
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "not_served")
})

test_that("dismiss refuses an item that IS served", {
  # Writing `rejected` onto a served assertion drops it out of the public read's
  # state filter, so the still-served term renders as CURATOR-AUTHORED -- the
  # exact fabrication this feature exists to prevent.
  mock_globals(list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("FOR UPDATE", sql, fixed = TRUE)) {
        return(data.frame(assertion_id = 1L, entity_id = 42L, vario_id = "VariO:0015",
                          modifier_id = 1L, state = "suggested", stringsAsFactors = FALSE))
      }
      data.frame(vario_id = "VariO:0015", modifier_id = 1L, stringsAsFactors = FALSE)
    }
  ))
  result <- svc_curate_variation_apply(
    list(list(entity_id = 42L, vario_id = "VariO:0015", modifier_id = 1L)),
    action = "dismiss", review_user_id = 7L, db = NULL
  )
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "served")
})

test_that("confirm applies to a served active_unconfirmed assertion", {
  statements <- list()
  mock_globals(list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("FOR UPDATE", sql, fixed = TRUE)) {
        return(data.frame(assertion_id = 9L, entity_id = 42L, vario_id = "VariO:0015",
                          modifier_id = 1L, state = "active_unconfirmed",
                          stringsAsFactors = FALSE))
      }
      data.frame(vario_id = "VariO:0015", modifier_id = 1L, stringsAsFactors = FALSE)
    },
    db_execute_statement = function(sql, params = list(), conn = NULL) {
      statements[[length(statements) + 1L]] <<- list(sql = sql, params = params)
      1L
    }
  ))
  result <- svc_curate_variation_apply(
    list(list(entity_id = 42L, vario_id = "VariO:0015", modifier_id = 1L)),
    action = "confirm", review_user_id = 7L, db = NULL
  )
  expect_equal(result$applied, 1L)
  expect_length(result$skipped, 0L)
  # The write must be conditional on the state observed under the row lock, so a
  # transaction that lost the race writes 0 rows instead of clobbering.
  expect_match(statements[[1L]]$sql, "state = ?", fixed = TRUE)
  expect_match(statements[[1L]]$sql, "confirmed_by = ?", fixed = TRUE)
})

test_that("a state that changed under the lock is reported skipped, not applied", {
  mock_globals(list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("FOR UPDATE", sql, fixed = TRUE)) {
        return(data.frame(assertion_id = 9L, entity_id = 42L, vario_id = "VariO:0015",
                          modifier_id = 1L, state = "active_unconfirmed",
                          stringsAsFactors = FALSE))
      }
      data.frame(vario_id = "VariO:0015", modifier_id = 1L, stringsAsFactors = FALSE)
    },
    db_execute_statement = function(sql, params = list(), conn = NULL) 0L
  ))
  result <- svc_curate_variation_apply(
    list(list(entity_id = 42L, vario_id = "VariO:0015", modifier_id = 1L)),
    action = "confirm", review_user_id = 7L, db = NULL
  )
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "state_changed")
})

test_that("an unknown assertion is skipped, never created", {
  mock_globals(list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    db_execute_query = function(sql, params = list(), conn = NULL) data.frame()
  ))
  result <- svc_curate_variation_apply(
    list(list(entity_id = 42L, vario_id = "VariO:0099", modifier_id = 1L)),
    action = "confirm", review_user_id = 7L, db = NULL
  )
  expect_equal(result$applied, 0L)
  expect_equal(result$skipped[[1L]]$reason, "not_found")
})

test_that("the locking read orders by assertion_id so concurrent batches cannot deadlock", {
  captured <- NULL
  mock_globals(list(
    db_with_savepoint_or_transaction = function(db, savepoint, fn, ...) fn(db),
    db_execute_query = function(sql, params = list(), conn = NULL) {
      if (grepl("FOR UPDATE", sql, fixed = TRUE)) captured <<- sql
      data.frame()
    }
  ))
  svc_curate_variation_apply(
    list(list(entity_id = 42L, vario_id = "VariO:0015", modifier_id = 1L)),
    action = "confirm", review_user_id = 7L, db = NULL
  )
  expect_match(captured, "ORDER BY a.assertion_id")
  expect_match(captured, "FOR UPDATE")
})

test_that("more than 100 items is a 400", {
  items <- replicate(101L,
    list(entity_id = 1L, vario_id = "VariO:0015", modifier_id = 1L), simplify = FALSE)
  expect_error(
    svc_curate_variation_apply(items, "confirm", 7L, db = NULL),
    class = "error_400"
  )
})

test_that("an empty item list is a 400 rather than a no-op success", {
  expect_error(
    svc_curate_variation_apply(list(), "confirm", 7L, db = NULL),
    class = "error_400"
  )
})
```

- [ ] **Step 2: Run and confirm failure**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-curate-variation-suggestions.R')"
```
Expected: FAIL — `could not find function "svc_curate_variation_apply"`.

- [ ] **Step 3: Implement `svc_curate_variation_apply()`**

Behaviour, in order, all inside one `db_with_savepoint_or_transaction(db, "curate_variation_apply", ...)`:

1. Validate: `action %in% c("confirm","dismiss")`; `1 <= length(items) <= 100`; every item has an
   integer `entity_id`, a CURIE-shaped `vario_id` and an integer `modifier_id` — otherwise
   `stop_for_bad_request()`.
2. **Lock**: one `SELECT a.assertion_id, a.entity_id, a.vario_id, a.modifier_id, a.state
   FROM variation_ontology_assertion a WHERE (a.entity_id, a.vario_id, a.modifier_id) IN (...)
   ORDER BY a.assertion_id FOR UPDATE`, with one bound triple per item. Ordering by
   `assertion_id` means two concurrent batches acquire locks in the same order and cannot
   deadlock on each other.
3. **Re-derive served membership while holding the locks**:
   `variation_provenance_served_terms_for_entity(entity_id, conn)` per distinct entity in the
   locked set (Task 5).
4. Per item decide `reason`, comparing identities case-insensitively on `vario_id` and as integers
   on `modifier_id` — the same normalization
   `.variation_provenance_identity_key()` applies, and for the same reason (`vario_id` collates
   case-insensitively in MySQL, so a case-variant would otherwise silently miss):
   * no locked row → `not_found`
   * `confirm` and `state != "active_unconfirmed"` → `wrong_state`
   * `confirm` and not served → `not_served`
   * `dismiss` and `state != "suggested"` → `wrong_state`
   * `dismiss` and served → `served`
5. **Write conditionally**, one statement per surviving item, using the state observed under the
   lock as the predicate:

```r
  # Confirm
  db_execute_statement(
    "UPDATE variation_ontology_assertion
        SET state = 'confirmed', confirmed_by = ?, confirmed_at = NOW()
      WHERE assertion_id = ? AND state = ?",
    list(as.integer(review_user_id), assertion_id, observed_state), conn = conn
  )
  # Dismiss
  db_execute_statement(
    "UPDATE variation_ontology_assertion
        SET state = 'rejected'
      WHERE assertion_id = ? AND state = ?",
    list(assertion_id, observed_state), conn = conn
  )
```

   A 0-row result is `skipped` with reason `state_changed`.
6. Return `list(requested = length(items), applied = <count>, skipped = <unnamed list>)`.

Add a module comment above the function stating the P0 the locking closes: without it, a dismiss
could read `suggested + not served` while a concurrent review write adds and approves that term,
then commit `rejected` onto a now-served assertion. Note that this serializes against
`review_write_mutate()`, whose reconciliation updates the very same assertion row for any term it
adds or removes.

If the file approaches 600 lines, split the write half into
`api/services/curate-variation-apply-service.R` and register it in `load_modules.R` immediately
after the read service.

- [ ] **Step 4: Run the tests**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-curate-variation-suggestions.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-variation-connect-write-guard.R')"
wc -l api/services/curate-variation-suggestion-service.R
```
Expected: PASS, ≤ 600.

- [ ] **Step 5: Commit**

```bash
git add api/services api/bootstrap/load_modules.R api/tests/testthat
git commit -m "feat(612): add locked confirm/dismiss writes for the suggestion queue"
```

---

## Task 9: Curate endpoints and mount

**Files:**
- Create: `api/endpoints/curate_variation_endpoints.R`
- Modify: `api/bootstrap/mount_endpoints.R`
- Test: `api/tests/testthat/test-integration-variation-suggestions.R`

**Interfaces:**
- Consumes: `svc_curate_variation_suggestion_params()`, `svc_curate_variation_suggestions()`,
  `svc_curate_variation_apply()`.
- Produces: `GET /api/curate/variation/suggestions`,
  `POST /api/curate/variation/suggestions/confirm`,
  `POST /api/curate/variation/suggestions/dismiss`. Task 10 types these.

- [ ] **Step 1: Write the endpoint file**

Three handlers, each `require_role(req, res, "Curator")` first, each
`#* @serializer json list(na="string", null="null")` (the row objects carry nullable nested
scalars), each `@tag curate`. Declaration order: `/suggestions/confirm` and
`/suggestions/dismiss` are declared **before** `/suggestions` — plumber matches in declaration
order and a dynamic sibling added later must never shadow them. Record that in a comment,
citing the `/api/status/_list` lesson.

```r
#* @get /suggestions
function(req, res, state = NULL, source_key = NULL, max_strength = NULL,
         moved = NULL, q = NULL, sort = NULL, page = NULL, page_size = NULL) {
  require_role(req, res, "Curator")
  params <- svc_curate_variation_suggestion_params(
    state, source_key, max_strength, moved, q, sort, page, page_size
  )
  svc_curate_variation_suggestions(params, pool)
}

#* @post /suggestions/confirm
function(req, res) {
  require_role(req, res, "Curator")
  svc_curate_variation_apply(
    items = req$argsBody$items, action = "confirm",
    review_user_id = req$user_id, db = pool
  )
}
```

Match the surrounding files for how the acting user id is read (`req$user_id` vs
`req$user$user_id`) — grep `review_endpoints.R` for the existing `submit_user_id` derivation and
use the same expression.

- [ ] **Step 2: Mount it**

In `api/bootstrap/mount_endpoints.R`, add immediately after the `/api/disease` line:

```r
    plumber::pr_mount("/api/curate/variation", mount_endpoint("endpoints/curate_variation_endpoints.R")) %>%
```

- [ ] **Step 3: Run the endpoint static guards**

Run:
```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-endpoint-error-handler.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-cheap-route-isolation.R')"
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-external-fetcher-allowlist.R')"
```
Expected: PASS. The new file calls no external fetcher, so the allowlist guard stays green.

- [ ] **Step 4: Write the integration test**

```r
# api/tests/testthat/test-integration-variation-suggestions.R
#
# Runs only against a schema-loaded MySQL. CI provisions an EMPTY database, so
# this file skips there -- see the plan's Environment section for the throwaway
# container recipe. #638 found two production defects by actually running a file
# that had been skipping since it was written; assume the same here.
source_api_file("services/curate-variation-suggestion-service.R", local = FALSE)
source_api_file("functions/variation-provenance-approval.R", local = FALSE)

test_that("the queue lists a seeded unconfirmed assertion with its evidence", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed <- seed_variation_suggestion_fixture(conn)   # helper written in Step 5
    params <- svc_curate_variation_suggestion_params(
      NULL, NULL, NULL, NULL, as.character(seed$entity_id), NULL, NULL, NULL
    )
    result <- svc_curate_variation_suggestions(params, pool = conn)
    expect_equal(result$meta$total, 1L)
    row <- result$data[[1L]]
    expect_equal(row$vario_id, "VariO:0015")
    expect_true(row$served)
    expect_equal(row$evidence[[1L]]$source_key, "clinvar")
  })
})

test_that("confirming a served assertion stamps attribution", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed <- seed_variation_suggestion_fixture(conn)
    result <- svc_curate_variation_apply(
      list(list(entity_id = seed$entity_id, vario_id = "VariO:0015", modifier_id = 1L)),
      action = "confirm", review_user_id = seed$user_id, db = conn
    )
    expect_equal(result$applied, 1L)
    row <- DBI::dbGetQuery(conn,
      "SELECT state, confirmed_by FROM variation_ontology_assertion WHERE assertion_id = ?",
      params = list(seed$assertion_id))
    expect_equal(row$state, "confirmed")
    expect_equal(as.integer(row$confirmed_by), seed$user_id)
  })
})

test_that("dismissing a SERVED assertion is refused", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed <- seed_variation_suggestion_fixture(conn, state = "suggested")
    result <- svc_curate_variation_apply(
      list(list(entity_id = seed$entity_id, vario_id = "VariO:0015", modifier_id = 1L)),
      action = "dismiss", review_user_id = seed$user_id, db = conn
    )
    expect_equal(result$applied, 0L)
    expect_equal(result$skipped[[1L]]$reason, "served")
    row <- DBI::dbGetQuery(conn,
      "SELECT state FROM variation_ontology_assertion WHERE assertion_id = ?",
      params = list(seed$assertion_id))
    expect_equal(row$state, "suggested")
  })
})

test_that("approving a review rejects an assertion the entity no longer serves", {
  skip_if_no_test_db()
  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    seed <- seed_variation_suggestion_fixture(conn)
    # Drop the connect row: the approved review no longer carries the term.
    DBI::dbExecute(conn,
      "DELETE FROM ndd_review_variation_ontology_connect WHERE review_id = ?",
      params = list(seed$review_id))
    variation_provenance_reconcile_on_approval(seed$entity_id, seed$user_id, conn = conn)
    row <- DBI::dbGetQuery(conn,
      "SELECT state FROM variation_ontology_assertion WHERE assertion_id = ?",
      params = list(seed$assertion_id))
    expect_equal(row$state, "rejected")
  })
})
```

- [ ] **Step 5: Write the seed helper**

Add `seed_variation_suggestion_fixture(con, state = "active_unconfirmed")` to
`api/tests/testthat/helper-db.R` (or a new `helper-variation-provenance.R`, which testthat
auto-loads). It must insert, on `con`, in FK order and returning the ids:
a `user`, an `ndd_entity` (with its `hgnc_id` from `non_alt_loci_set` and a
`disease_ontology_set` row so `ndd_entity_view` resolves it), an approved `ndd_entity_status`,
an `ndd_entity_review` with `is_primary = 1, review_approved = 1`, a
`ndd_review_variation_ontology_connect` row `(review_id, entity_id, 'VariO:0015', 1, is_active=1)`,
a `variation_ontology_assertion` row in `state`, and a `variation_ontology_evidence` row
(`source_key='clinvar'`, `batch_id='clinvar-2026-02'`, `evidence_summary` NOT NULL,
`evidence_strength=1`, `origin_review_id` = the review id).

Copy the existing insertion order and column lists from whatever `test-integration-*` file already
seeds an entity — do not invent columns. `ndd_entity_status.status_user_id` is NOT NULL with no
default.

- [ ] **Step 6: Run the integration file against the throwaway DB**

Run (see Environment section for the container + migration setup):
```bash
docker exec sysndd-api-1 rm -rf /app/tests
docker cp api/tests sysndd-api-1:/app/tests
docker exec -e MYSQL_HOST=sysndd_mysql_prov612 -e MYSQL_DATABASE=sysndd_db_test \
  -e MYSQL_USER=root -e MYSQL_PASSWORD=prov612root -e MYSQL_PORT=3306 \
  sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-integration-variation-suggestions.R')"
```
Expected: PASS with **0 skips**. A SKIP means the DB was not reached and the file proves nothing —
fix the environment, do not accept the skip.

- [ ] **Step 7: Commit**

```bash
git add api/endpoints/curate_variation_endpoints.R api/bootstrap/mount_endpoints.R \
        api/tests/testthat
git commit -m "feat(612): mount the Curator variation suggestion queue endpoints"
```

---

## Task 10: Typed client for the queue

**Files:**
- Create: `app/src/api/curate_variation.ts`, `app/src/api/curate-variation-wire.ts`
- Test: `app/src/api/curate_variation.spec.ts`

**Interfaces:**
- Produces:
  ```ts
  export interface VariationSuggestionEvidence {
    source_type: string | null; source_key: string | null; batch_id: string | null;
    strength: number | null; summary: string | null;
  }
  export interface VariationSuggestionRow {
    entity_id: number; symbol: string | null; disease_ontology_name: string | null;
    vario_id: string; vario_name: string | null; modifier_id: number;
    state: 'active_unconfirmed' | 'suggested';
    served: boolean; moved: boolean; max_strength: number | null;
    evidence: VariationSuggestionEvidence[];
  }
  export interface VariationSuggestionPage {
    meta: { page: number; page_size: number; total: number };
    data: VariationSuggestionRow[];
  }
  export interface VariationSuggestionIdentity {
    entity_id: number; vario_id: string; modifier_id: number;
  }
  export interface VariationSuggestionApplyResult {
    requested: number; applied: number;
    skipped: Array<VariationSuggestionIdentity & { reason: string }>;
  }
  export function listVariationSuggestions(params, config?): Promise<VariationSuggestionPage>;
  export function confirmVariationSuggestions(items, config?): Promise<VariationSuggestionApplyResult>;
  export function dismissVariationSuggestions(items, config?): Promise<VariationSuggestionApplyResult>;
  ```
  Task 11 consumes all of it.

- [ ] **Step 1: Write the failing spec**

```ts
// app/src/api/curate_variation.spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { normalizeSuggestionPage } from './curate-variation-wire';

describe('curate variation wire normalization', () => {
  it('unwraps plumber length-1 arrays on documented scalars', () => {
    const page = normalizeSuggestionPage({
      meta: { page: [1], page_size: [25], total: [8083] },
      data: [
        {
          entity_id: [42], symbol: ['CHD8'], disease_ontology_name: ['CHD8 disorder'],
          vario_id: ['VariO:0015'], vario_name: ['protein truncation'], modifier_id: [1],
          state: ['active_unconfirmed'], served: [true], moved: [false], max_strength: [2],
          evidence: [
            { source_type: ['external_database'], source_key: ['clinvar'],
              batch_id: ['clinvar-2026-02'], strength: [2],
              summary: ['10 ClinVar records, max 2 stars'] },
          ],
        },
      ],
    });
    expect(page.meta).toEqual({ page: 1, page_size: 25, total: 8083 });
    const [row] = page.data;
    // A strict-equality state predicate against ["active_unconfirmed"] is FALSE;
    // that exact bug emptied the curation form's "Needs confirmation" zone once.
    expect(row.state).toBe('active_unconfirmed');
    expect(row.served).toBe(true);
    expect(row.moved).toBe(false);
    expect(row.max_strength).toBe(2);
    expect(row.evidence[0].source_key).toBe('clinvar');
  });

  it('keeps an unrecorded strength null rather than coercing it to zero', () => {
    const page = normalizeSuggestionPage({
      meta: { page: [1], page_size: [25], total: [1] },
      data: [{
        entity_id: [42], symbol: [null], disease_ontology_name: [null],
        vario_id: ['VariO:0015'], vario_name: [null], modifier_id: [1],
        state: ['suggested'], served: [false], moved: [false], max_strength: null,
        evidence: [],
      }],
    });
    expect(page.data[0].max_strength).toBeNull();
    expect(page.data[0].evidence).toEqual([]);
  });

  it('tolerates a missing data array', () => {
    expect(normalizeSuggestionPage({ meta: { page: [1], page_size: [25], total: [0] } }).data)
      .toEqual([]);
  });
});
```

Add a second describe block asserting `listVariationSuggestions` calls
`GET /api/curate/variation/suggestions` with only the supplied params (undefined filters omitted),
and that `confirmVariationSuggestions` POSTs `{ items }` to `.../suggestions/confirm`. Mock the
shared axios instance the sibling clients in `app/src/api/` use — copy the mocking style from an
existing `app/src/api/*.spec.ts`.

- [ ] **Step 2: Run and confirm failure**

Run: `cd app && npx vitest run src/api/curate_variation.spec.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement both files**

`curate-variation-wire.ts` mirrors `entity-variation-wire.ts`: a local `unwrapWireScalar()` plus
field-by-field unwrapping of exactly the documented scalars — never blanket-recursive, because
`data` and `evidence` are genuine arrays. Booleans go through an unwrap that accepts `true`/`false`
and the strings `"true"`/`"false"`; anything else is `false` for `served`/`moved` (a flag that
cannot be read is not an assertion that the term is served).

`curate_variation.ts` holds the types above and three thin functions using the same axios instance
and error handling as the sibling clients.

- [ ] **Step 4: Run and type-check**

Run:
```bash
cd app && npx vitest run src/api/curate_variation.spec.ts && npm run type-check
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/src/api/curate_variation.ts app/src/api/curate-variation-wire.ts \
        app/src/api/curate_variation.spec.ts
git commit -m "feat(612): add the typed client for the variation suggestion queue"
```

---

## Task 11: Suggestion queue page

**Files:**
- Create: `app/src/views/curate/VariationSuggestions.vue`,
  `app/src/views/curate/composables/useVariationSuggestions.ts`,
  `app/src/views/curate/components/VariationSuggestionsTable.vue`,
  `app/src/views/curate/components/VariationSuggestionMobileRows.vue`
- Modify: `app/src/router/routes.ts`, `app/src/assets/js/constants/main_nav_constants.ts`
- Test: `app/src/views/curate/composables/__tests__/useVariationSuggestions.spec.ts`,
  `app/src/views/curate/VariationSuggestions.spec.ts`

**Interfaces:**
- Consumes: everything Task 10 produces.
- Produces:
  ```ts
  export default function useVariationSuggestions(): {
    rows: Ref<VariationSuggestionRow[]>; total: Ref<number>;
    page: Ref<number>; pageSize: Ref<number>; loading: Ref<boolean>;
    filters: Ref<{ state: string | null; source_key: string | null;
                   max_strength: number | null; moved: boolean; q: string }>;
    sort: Ref<'strength_desc' | 'strength_asc' | 'entity_asc'>;
    selected: Ref<string[]>;                 // rowKey() values
    rowKey: (row: VariationSuggestionRow) => string;
    canConfirm: (row: VariationSuggestionRow) => boolean;
    canDismiss: (row: VariationSuggestionRow) => boolean;
    selectionKind: ComputedRef<'confirm' | 'dismiss' | 'mixed' | 'none'>;
    load: () => Promise<void>;
    confirmSelected: () => Promise<VariationSuggestionApplyResult | null>;
    dismissSelected: () => Promise<VariationSuggestionApplyResult | null>;
  }
  ```

- [ ] **Step 1: Write the failing composable spec**

```ts
// app/src/views/curate/composables/__tests__/useVariationSuggestions.spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import useVariationSuggestions from '../useVariationSuggestions';
import * as api from '@/api/curate_variation';

vi.mock('@/api/curate_variation');

const row = (over: Partial<api.VariationSuggestionRow> = {}): api.VariationSuggestionRow => ({
  entity_id: 42, symbol: 'CHD8', disease_ontology_name: 'CHD8 disorder',
  vario_id: 'VariO:0015', vario_name: 'protein truncation', modifier_id: 1,
  state: 'active_unconfirmed', served: true, moved: false, max_strength: 2,
  evidence: [], ...over,
});

beforeEach(() => vi.resetAllMocks());

describe('row action eligibility', () => {
  it('offers Confirm only for a served active_unconfirmed assertion', () => {
    const q = useVariationSuggestions();
    expect(q.canConfirm(row())).toBe(true);
    expect(q.canConfirm(row({ served: false }))).toBe(false);
    expect(q.canConfirm(row({ state: 'suggested', served: false }))).toBe(false);
  });

  it('offers Dismiss only for a suggested assertion that is NOT served', () => {
    // Writing `rejected` onto a served term removes it from the public read's
    // state filter, so the still-served term renders as curator-authored.
    const q = useVariationSuggestions();
    expect(q.canDismiss(row({ state: 'suggested', served: false }))).toBe(true);
    expect(q.canDismiss(row({ state: 'suggested', served: true }))).toBe(false);
    expect(q.canDismiss(row())).toBe(false);
  });
});

describe('row identity', () => {
  it('keys on entity, vario id AND modifier', () => {
    const q = useVariationSuggestions();
    expect(q.rowKey(row())).not.toEqual(q.rowKey(row({ modifier_id: 5 })));
  });
});

describe('bulk selection', () => {
  it('reports a mixed selection so no bulk action is offered', () => {
    const q = useVariationSuggestions();
    q.rows.value = [row(), row({ vario_id: 'VariO:0017', state: 'suggested', served: false })];
    q.selected.value = q.rows.value.map(q.rowKey);
    expect(q.selectionKind.value).toBe('mixed');
  });

  it('confirms exactly the selected identities', async () => {
    vi.mocked(api.confirmVariationSuggestions).mockResolvedValue(
      { requested: 1, applied: 1, skipped: [] }
    );
    vi.mocked(api.listVariationSuggestions).mockResolvedValue(
      { meta: { page: 1, page_size: 25, total: 0 }, data: [] }
    );
    const q = useVariationSuggestions();
    q.rows.value = [row()];
    q.selected.value = [q.rowKey(row())];
    await q.confirmSelected();
    expect(api.confirmVariationSuggestions).toHaveBeenCalledWith(
      [{ entity_id: 42, vario_id: 'VariO:0015', modifier_id: 1 }]
    );
    // The list is reloaded so a confirmed row leaves the queue.
    expect(api.listVariationSuggestions).toHaveBeenCalled();
  });
});

describe('loading', () => {
  it('sends only the filters that are set', async () => {
    vi.mocked(api.listVariationSuggestions).mockResolvedValue(
      { meta: { page: 1, page_size: 25, total: 0 }, data: [] }
    );
    const q = useVariationSuggestions();
    q.filters.value.source_key = 'clinvar';
    await q.load();
    const sent = vi.mocked(api.listVariationSuggestions).mock.calls[0][0];
    expect(sent.source_key).toBe('clinvar');
    expect(sent.state).toBeUndefined();
    expect(sent.moved).toBeUndefined();
  });
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd app && npx vitest run src/views/curate/composables/__tests__/useVariationSuggestions.spec.ts`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement the composable**

`rowKey` is `` `${entity_id}:${vario_id}:${modifier_id}` `` — identity always carries the modifier.
`canConfirm` is `row.state === 'active_unconfirmed' && row.served`; `canDismiss` is
`row.state === 'suggested' && !row.served`. `selectionKind` returns `'none'` for an empty
selection, `'confirm'`/`'dismiss'` when every selected row satisfies that predicate, `'mixed'`
otherwise. `confirmSelected`/`dismissSelected` map the selection back to
`{entity_id, vario_id, modifier_id}`, call the client, clear the selection, and `await load()`.
Carry a `lastResult` ref so the page can surface `skipped` reasons.

- [ ] **Step 4: Implement the page, table and mobile rows**

`VariationSuggestions.vue` is a shell using the same `AuthenticatedPageShell` + filter-bar +
table + pagination structure as `ManageReReview.vue`; read that file first and mirror it.
The table columns are: select checkbox, Gene (link to `/Genes/<symbol>` if that is the existing
pattern), Entity (link to `/Entities/<entity_id>`), Term (`vario_name` with `vario_id` as
secondary text), Modifier, State badge, `moved` badge, Strength (via `strengthDisplay()`), Source,
Evidence summary, Actions. Follow `documentation/10-visual-design-guide.md` for the mobile-row
component and badge tokens.

Surface `skipped` reasons after a bulk action as a toast listing counts by reason — a silent
partial success on a provenance surface is the failure mode this feature exists to avoid.

- [ ] **Step 5: Add the route and the navbar entry**

`app/src/router/routes.ts`, next to the other curate routes:

```ts
  {
    path: '/curate/variation-suggestions',
    name: 'VariationSuggestions',
    component: () => import('@/views/curate/VariationSuggestions.vue'),
    meta: { sitemap: { ignoreRoute: true } },
    beforeEnter: createAuthGuard(['Administrator', 'Curator']),
  },
```

`app/src/assets/js/constants/main_nav_constants.ts`, in the Curate dropdown after
"Manage re-review":

```ts
        { text: 'Variation suggestions', path: '/curate/variation-suggestions', icons: ['cpu', 'clipboard-check'] },
```

- [ ] **Step 6: Write the shell spec and run everything**

`VariationSuggestions.spec.ts` mounts the page with the API client mocked and asserts: the table
renders one row per fixture row; a served `active_unconfirmed` row shows Confirm and not Dismiss;
a `suggested` unserved row shows Dismiss and not Confirm; the `moved` badge appears only when
`moved` is true.

Run:
```bash
cd app && npx vitest run src/views/curate src/router && npm run type-check && npm run lint
wc -l app/src/views/curate/VariationSuggestions.vue \
      app/src/views/curate/composables/useVariationSuggestions.ts \
      app/src/views/curate/components/VariationSuggestionsTable.vue
```
Expected: PASS, all ≤ 600.

- [ ] **Step 7: Commit**

```bash
git add app/src/views/curate app/src/router/routes.ts \
        app/src/assets/js/constants/main_nav_constants.ts
git commit -m "feat(612): add the /curate/variation-suggestions queue page"
```

---

## Task 12: Extract the three-zone picker into a shared component

**Files:**
- Create: `app/src/views/curate/components/VariationProvenanceZones.vue`
- Modify: `app/src/views/curate/components/ReviewFormFields.vue`
- Test: `app/src/views/curate/components/ReviewFormFields.provenance.spec.ts` (must pass unchanged)

**Interfaces:**
- Produces:
  ```
  <VariationProvenanceZones :zones="variationZones" />
  ```
  where `zones` is a `VariationProvenanceZonesApi | null`. Renders nothing when
  `zones === null || !zones.hasZones`. Tasks 13 and 14 mount it.

- [ ] **Step 1: Move the markup verbatim**

Cut the `<div v-if="zonesActive" class="vario-zones">` block (currently around
`ReviewFormFields.vue:85-176`), its `VariationProvenanceCard` import, its `zonesActive` computed
and its `.vario-zones*` styles into the new component. Every `data-testid` must be preserved
character-for-character — `ReviewFormFields.provenance.spec.ts` asserts on them and must pass
**without modification**, which is the proof the extraction was faithful.

- [ ] **Step 2: Consume it from `ReviewFormFields.vue`**

Replace the removed block with `<VariationProvenanceZones :zones="variationZones" />`, placed
exactly where the old block was (above the `TreeMultiSelect`).

- [ ] **Step 3: Run the existing spec unchanged**

Run:
```bash
cd app && npx vitest run src/views/curate/components/ReviewFormFields.provenance.spec.ts \
                         src/views/review
cd app && npm run type-check
wc -l app/src/views/curate/components/ReviewFormFields.vue \
      app/src/views/curate/components/VariationProvenanceZones.vue
```
Expected: PASS with **no edits to the spec**. If a `data-testid` had to change, the extraction was
not faithful — fix the component, not the spec.

- [ ] **Step 4: Commit**

```bash
git add app/src/views/curate/components
git commit -m "refactor(612): extract VariationProvenanceZones from ReviewFormFields"
```

---

## Task 13: Zone UI on ModifyEntity

**Files:**
- Modify: `app/src/views/curate/ModifyEntity.vue`,
  `app/src/views/curate/composables/useModifyEntityWorkflows.ts`,
  `app/src/views/curate/composables/useEntityInfo.ts`,
  `app/src/views/curate/composables/useEntityMutations.ts`,
  `app/src/views/curate/components/InlineEntityWorkflow.vue`,
  `app/src/views/curate/components/CombinedStatusReviewWorkflow.vue`
- Create: `app/src/views/curate/ModifyEntity.styles.css`
- Test: `app/src/views/curate/composables/__tests__/useEntityMutations.provenance.spec.ts`

- [ ] **Step 1: Free the line budget FIRST**

`ModifyEntity.vue` is exactly 599 lines, so *any* addition trips
`make code-quality-audit`. Move its `<style scoped>` body (currently lines 391-598, i.e. everything
between `<style scoped>` and `</style>`) into `app/src/views/curate/ModifyEntity.styles.css` and
replace the block with:

```html
<style scoped src="./ModifyEntity.styles.css"></style>
```

This is already used in this repo (`app/src/components/nddscore/NddScoreGeneTable.vue:439`) and
`scoped` still applies.

Run: `cd app && npx vitest run src/views/curate/ModifyEntity && wc -l app/src/views/curate/ModifyEntity.vue`
Expected: PASS, ~391 lines. Commit this move on its own so a style regression is bisectable:

```bash
git add app/src/views/curate/ModifyEntity.vue app/src/views/curate/ModifyEntity.styles.css
git commit -m "refactor(612): move ModifyEntity styles to a companion stylesheet"
```

- [ ] **Step 2: Write the failing submit-path spec**

```ts
// app/src/views/curate/composables/__tests__/useEntityMutations.provenance.spec.ts
import { describe, it, expect } from 'vitest';
import { buildVariationSubmission } from '../useEntityMutations';

describe('#612 provenance_action on the ModifyEntity submit path', () => {
  it('omits provenance_action for a term the curator did not confirm', () => {
    const [term] = buildVariationSubmission(['1-VariO:0015'], () => undefined);
    expect(term).toEqual({ vario_id: 'VariO:0015', modifier_id: 1 });
    expect('provenance_action' in term).toBe(false);
  });

  it('sets provenance_action for a confirmed term', () => {
    const [term] = buildVariationSubmission(
      ['1-VariO:0015'],
      (tag) => (tag === '1-VariO:0015' ? 'confirm' : undefined)
    );
    expect(term).toMatchObject({ provenance_action: 'confirm' });
  });

  it('keys on the full tag so present and absent are independent', () => {
    const terms = buildVariationSubmission(
      ['1-VariO:0015', '5-VariO:0015'],
      (tag) => (tag === '1-VariO:0015' ? 'confirm' : undefined)
    );
    expect('provenance_action' in terms[0]).toBe(true);
    expect('provenance_action' in terms[1]).toBe(false);
  });

  it('splits only at the first hyphen so a hyphenated CURIE survives', () => {
    const [term] = buildVariationSubmission(['1-VariO:00-15'], () => undefined);
    expect(term.vario_id).toBe('VariO:00-15');
  });
});
```

- [ ] **Step 3: Run and confirm failure**

Run: `cd app && npx vitest run src/views/curate/composables/__tests__/useEntityMutations.provenance.spec.ts`
Expected: FAIL — `buildVariationSubmission` is not exported.

- [ ] **Step 4: Implement**

In `useEntityMutations.ts`, extract the existing mapping at line ~127 into an exported pure
function and route the caller through it:

```ts
/**
 * Map selection tags to submission terms, attaching `provenance_action` (#612).
 *
 * `provenanceActionFor` comes from `useVariationProvenanceZones`; the field is
 * OMITTED, never set to null, when there is no action, so a pre-#608 submission
 * serialises byte-identically. Tags are split with `splitOntologyTag()` — at the
 * FIRST separator only, so a hyphenated CURIE survives (#611).
 */
export function buildVariationSubmission(
  tags: string[],
  provenanceActionFor: (tag: string) => 'confirm' | undefined
): Variation[] {
  return tags.map((tag) => {
    const { modifierId, ontologyId } = splitOntologyTag(tag);
    return new Variation(ontologyId, modifierId, provenanceActionFor(tag));
  });
}
```

`splitOntologyTag()` returns `{ modifierId: number; ontologyId: string }`
(`app/src/utils/ontologyTags.ts:32`) — NOT `{ prefix, id }`. `modifierId` is already a number, so do
not wrap it in `Number()`.

Then:
* `useEntityInfo.ts` — add `const confirmed_variation_tags = ref<string[]>([])`, clear it in
  `reset()` and wherever `select_variation` is reloaded, and return it.
* `useModifyEntityWorkflows.ts` — instantiate
  `useVariationProvenanceZones({ selectedTags: info.select_variation, confirmedTags: info.confirmed_variation_tags })`,
  call `loadForEntity(entityId)` alongside the existing `info.loadReview(entityId)`, `reset()` it
  in `clearSelection()`, and expose it as `variationZones`.
* `useEntityMutations.ts` — take `provenanceActionFor` through the review submit args and pass it
  to `buildVariationSubmission`. Thread it from `useModifyEntityWorkflows.reviewArgs()`.
* `InlineEntityWorkflow.vue` and `CombinedStatusReviewWorkflow.vue` — add a
  `variationZones?: VariationProvenanceZonesApi | null` prop (default `null`) and render
  `<VariationProvenanceZones :zones="variationZones" />` immediately above their `TreeMultiSelect`.
* `ModifyEntity.vue` — pass `:variation-zones="workflows.variationZones"` to both components.

- [ ] **Step 5: Run**

Run:
```bash
cd app && npx vitest run src/views/curate && npm run type-check && npm run lint
wc -l app/src/views/curate/ModifyEntity.vue \
      app/src/views/curate/components/InlineEntityWorkflow.vue \
      app/src/views/curate/components/CombinedStatusReviewWorkflow.vue \
      app/src/views/curate/composables/useModifyEntityWorkflows.ts \
      app/src/views/curate/composables/useEntityInfo.ts \
      app/src/views/curate/composables/useEntityMutations.ts
```
Expected: PASS, all ≤ 600.

- [ ] **Step 6: Commit**

```bash
git add app/src/views/curate
git commit -m "feat(612): add the provenance zone picker to ModifyEntity"
```

---

## Task 14: Zone UI on ApproveReview

**Files:**
- Modify: `app/src/components/review/ReviewEditForm.vue`,
  `app/src/components/review/EditReviewModal.vue`,
  `app/src/views/curate/ApproveReview.vue`,
  `app/src/views/curate/composables/useApproveReviewController.ts`,
  `app/src/composables/review/useReviewApprovalActions.ts`
- Test: `app/src/composables/review/__tests__/useReviewApprovalActions.provenance.spec.ts`

- [ ] **Step 1: Write the failing spec**

```ts
// app/src/composables/review/__tests__/useReviewApprovalActions.provenance.spec.ts
import { describe, it, expect } from 'vitest';
import { buildApprovalVariationSubmission } from '../useReviewApprovalActions';

describe('#612 provenance_action on the ApproveReview submit path', () => {
  it('omits provenance_action when nothing was confirmed', () => {
    const [term] = buildApprovalVariationSubmission(['1-VariO:0015'], () => undefined);
    expect(term).toEqual({ vario_id: 'VariO:0015', modifier_id: 1 });
  });

  it('sets provenance_action for a confirmed term only', () => {
    const terms = buildApprovalVariationSubmission(
      ['1-VariO:0015', '1-VariO:0017'],
      (tag) => (tag === '1-VariO:0015' ? 'confirm' : undefined)
    );
    expect(terms[0]).toMatchObject({ provenance_action: 'confirm' });
    expect('provenance_action' in terms[1]).toBe(false);
  });
});
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd app && npx vitest run src/composables/review/__tests__/useReviewApprovalActions.provenance.spec.ts`
Expected: FAIL — export not found.

- [ ] **Step 3: Implement**

Extract the mapping at `useReviewApprovalActions.ts:234` into an exported
`buildApprovalVariationSubmission(tags, provenanceActionFor)` with the same body shape as Task 13's
helper, and pass `provenanceActionFor` through the submit payload.

* `useApproveReviewController.ts` — own a `confirmed_variation_tags` ref, instantiate
  `useVariationProvenanceZones({ selectedTags: select_variation, confirmedTags: confirmed_variation_tags })`,
  call `loadForEntity(entity_id)` when the review modal opens, `reset()` on
  `onReviewModalHide`, and expose `variationZones`.
* `ReviewEditForm.vue` — add a `variationZones` prop (default `null`) and render
  `<VariationProvenanceZones :zones="variationZones" />` above its `TreeMultiSelect`.
* `EditReviewModal.vue` — add the prop and forward it.
* `ApproveReview.vue` — pass `:variation-zones="variationZones"` to `EditReviewModal`.

- [ ] **Step 4: Run**

Run:
```bash
cd app && npx vitest run src/composables/review src/views/curate src/components/review
cd app && npm run type-check && npm run lint
wc -l app/src/components/review/ReviewEditForm.vue \
      app/src/components/review/EditReviewModal.vue \
      app/src/views/curate/ApproveReview.vue \
      app/src/views/curate/composables/useApproveReviewController.ts \
      app/src/composables/review/useReviewApprovalActions.ts
```
Expected: PASS, all ≤ 600.

- [ ] **Step 5: Commit**

```bash
git add app/src/components/review app/src/views/curate app/src/composables/review
git commit -m "feat(612): add the provenance zone picker to ApproveReview"
```

---

## Task 15: Documentation, release surfaces, and full verification

**Files:**
- Modify: `AGENTS.md`, `CHANGELOG.md`, `app/package.json`, `app/package-lock.json`,
  `api/version_spec.json`

- [ ] **Step 1: Update `AGENTS.md`**

In the "Variation-ontology provenance (#608)" section, add:

* The `evidence_json` contract: three record shapes, optional keys dropped not nulled, `matched`
  holds strings, `negated` is the only meaningful `false`, and the fixture
  `api/tests/testthat/fixtures/variation-evidence-record-shapes.json` is the cross-repo artifact
  driving both suites.
* The approval hook: `apply_confirmations`, `variation_provenance_reconcile_on_approval()`,
  that the served set is read AFTER `review_approve()` and an empty served set is meaningful, that
  the whole thing runs in one `db_with_savepoint_or_transaction()`, that the `"all"` check is now
  length-safe, and that `direct_approval` deliberately does not route through it.
* The queue: why it spans `active_unconfirmed` **and** `suggested`; the Confirm/Dismiss asymmetry
  and the §1.2 reason for it; the `SELECT … FOR UPDATE` + state-conditional write; and that
  `origin_review_id` now has its first consumer.
* The zone picker now on all four surfaces, and that `ModifyEntity.vue`'s styles live in a
  companion stylesheet.

Also update the `db-helpers` gotcha list with `db_with_savepoint_or_transaction()` as the single
place the pool-vs-caller-owned-connection decision lives.

- [ ] **Step 2: Bump the four release surfaces**

Read the current version from `app/package.json`, then bump the minor (new features) in all four:
`app/package.json`, **both** root `version` fields in `app/package-lock.json`,
`api/version_spec.json`, and a new `CHANGELOG.md` entry describing: the three evidence shapes now
rendering, the approval-path rejection hook, the new Curator queue, the zone picker on two more
surfaces, and the `svc_approval_review_approve` vector fix.

- [ ] **Step 3: Run the full local gate**

```bash
make code-quality-audit
make lint-api
cd app && npm run type-check && npm run test:unit && cd ..
make test-api-fast
```
Expected: all green. `code-quality-audit` failing on a grown file means an extraction was missed —
extract, do not add a baseline entry.

- [ ] **Step 4: Re-run the DB-backed integration files**

```bash
docker exec sysndd-api-1 rm -rf /app/tests
docker cp api/tests sysndd-api-1:/app/tests
for f in test-integration-variation-suggestions test-integration-entity-rename; do
  docker exec -e MYSQL_HOST=sysndd_mysql_prov612 -e MYSQL_DATABASE=sysndd_db_test \
    -e MYSQL_USER=root -e MYSQL_PASSWORD=prov612root -e MYSQL_PORT=3306 \
    sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/$f.R')"
done
```
Expected: PASS with 0 skips.

- [ ] **Step 5: Exercise the real API**

Restart the dev API so the new endpoint file is mounted (`docker restart sysndd-api-1`), mint a
Curator/Administrator JWT (see the repo's local verification recipe), and check:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  'http://localhost:7777/api/curate/variation/suggestions?page_size=2' | head -c 600
curl -s 'http://localhost:7777/api/curate/variation/suggestions' -o /dev/null -w '%{http_code}\n'
```
Expected: 200 with a `{meta, data}` envelope for the authorized call; 401/403 for the anonymous
one. A 500 means a service was not registered in `load_modules.R`.

- [ ] **Step 6: Commit and open the PR**

```bash
git add AGENTS.md CHANGELOG.md app/package.json app/package-lock.json api/version_spec.json
git commit -m "chore(release): vX.Y.0"
git push -u origin feat/variation-provenance-phase6-612
gh pr create --title "feat(612): variation-provenance evidence contract, approval hook, and suggestion queue" --body "..."
```

The PR body must state what shipped, the two design departures from the #608 spec (§1.1 and §1.2
of the design doc) and why, and that #612's remaining items are administration-repo/operator work.
Use one `Closes #612` line on its own — a comma-separated closing line only closes the first issue.

- [ ] **Step 7: Tear down the throwaway database**

```bash
docker rm -f sysndd_mysql_prov612
```


---

## Task 16: Endpoint-level authorization and body-shape tests

**Files:**
- Test: `api/tests/testthat/test-endpoint-curate-variation.R`

Task 9 mounts three routes but its tests call the SERVICE functions, so they prove nothing about
`require_role`, `req$argsBody$items`, `req$user_id`, or the route decorators. Those are exactly the
things a Curator-gated write surface must have covered.

- [ ] **Step 1: Write the tests**

Copy the sandbox harness from `api/tests/testthat/test-endpoint-review.R:109` (it mounts an
endpoint file and pulls handlers out by verb + path). Assert:

* `GET /suggestions` as a Reviewer raises the 403 condition class `error_403`; as a Curator it
  returns the `{meta, data}` envelope.
* `POST /suggestions/confirm` reads its items from `req$argsBody$items`, and passes
  `req$user_id` (or whatever expression `review_endpoints.R:476` actually uses — copy it exactly)
  through as `review_user_id`.
* A body with no `items` key raises `error_400`, not a 500.
* Each of the three routes carries `#* @serializer json list(na="string", null="null")`. Assert
  this by reading the endpoint file's text, the same way
  `test-unit-endpoint-error-handler.R` scans for `mount_endpoint`.
* The route-declaration order in the file text: both `/suggestions/confirm` and
  `/suggestions/dismiss` appear BEFORE `/suggestions`, so a future dynamic sibling cannot shadow
  them (the `/api/status/_list` lesson).

- [ ] **Step 2: Run**

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-curate-variation.R')"
```

- [ ] **Step 3: Commit**

```bash
git add api/tests/testthat/test-endpoint-curate-variation.R
git commit -m "test(612): cover the curate variation endpoints at the route level"
```

---

## Task 17: MSW / OpenAPI parity for the new mount

**Files:**
- Modify: `app/src/test-utils/mocks/handlers.ts`, `scripts/verify-msw-against-openapi.sh`

`make lint-app` runs `scripts/verify-msw-against-openapi.sh` (`Makefile:176`), which maps each
`/api/<prefix>` to its endpoint file from a hardcoded `MOUNTS` array. A new mount with no mapping
fails that check, and any MSW handler for a path it cannot map fails too.

- [ ] **Step 1: Add the mount mapping**

In `scripts/verify-msw-against-openapi.sh`, add to the `MOUNTS` array — **longest prefixes first**,
as the file's own comment requires:

```bash
  "/api/curate/variation:curate_variation_endpoints.R"
```

Place it beside the other two-segment entries (`/api/admin/analysis`, `/api/admin/ontology`,
`/api/admin/publications`), not among the one-segment ones.

- [ ] **Step 2: Add MSW handlers**

In `app/src/test-utils/mocks/handlers.ts`, add handlers for
`GET /api/curate/variation/suggestions` (returning a `{meta, data}` envelope with one
plumber-shaped row — every scalar wrapped in a length-1 array, matching the real wire shape) and
for the two POST routes (returning `{requested, applied, skipped}`). Follow the shape and comment
style of the neighbouring handlers.

- [ ] **Step 3: Run the verifier and the frontend suite**

```bash
make lint-app
cd app && npm run test:unit
```
Expected: PASS. If the verifier reports an unmapped path, the `MOUNTS` entry is missing or ordered
after a shorter prefix that shadows it.

- [ ] **Step 4: Commit**

```bash
git add app/src/test-utils/mocks/handlers.ts scripts/verify-msw-against-openapi.sh
git commit -m "test(612): add MSW/OpenAPI parity for the curate variation mount"
```

---

## Corrections folded in from the Codex plan review

Codex `gpt-5.6-terra`, 2026-08-25, 30 findings. Items 5, 6, 7, 9, 11, 12, 15, 19, 23, 28 and 29
confirmed the plan; the rest are corrected here or inline above. **Where this section and an
earlier task disagree, this section wins.**

1. **(P0, fixed inline)** `with_test_db_transaction()` takes an expression, not a function. Every
   Task 9 test now uses `with_test_db_transaction({ conn <- getOption(".test_db_con"); ... })`.
2. **(P1, fixed inline)** `local_mocked_bindings(.env = globalenv())` aborts under testthat 3.3.2.
   All global stubs now use `mock_globals()`; see "Test idioms this repo actually uses".
3. **(P1, Task 6)** The unit tests stub both `db_with_savepoint_or_transaction()` and
   `review_approve()`, so they cannot prove atomicity. **Add to Task 6** a real-DB regression test
   in `api/tests/testthat/test-integration-approval-provenance-atomicity.R`, patterned on the
   downstream-failure proof at `test-integration-review-write-atomicity.R:987`: seed an entity with
   a primary approved review and an `active_unconfirmed` assertion, force
   `variation_provenance_reconcile_on_approval` to throw (stub it via `mock_globals()`), call
   `svc_approval_review_approve()`, and assert the review's `is_primary` / `review_approved` AND
   the assertion state all rolled back.
4. **(P1, Task 6 Step 5)** Add `test-integration-review-write-atomicity.R` to the required run
   list — it exercises `svc_review_write()` through a caller-owned RMariaDB transaction and
   savepoint (`:619`), which is exactly what the `review_write_run_mutation()` delegation changes.
   Run it in the container against the throwaway DB, not on the host.
6. **(Task 6/8)** Do not pass `pool = NULL` to exercise the transaction branch — with `NULL` the
   helper falls through to `db_with_transaction(..., pool_obj = NULL)`, which calls
   `get_db_connection()` and opens a real connection. Inject a fake `transaction_runner` instead,
   or stub `db_with_savepoint_or_transaction` via `mock_globals()`.
7. **(Task 6)** Add an `"all"` regression test: `svc_approval_review_approve("all", ...)` must
   still take the pending-review branch after the length guard is added.
8. **(P1, Task 8)** Validate `review_user_id` before any confirmation write. `confirm` stamps
   `confirmed_by`, and migration 047's `chk_confirmed_attribution` forbids a confirmed row with a
   NULL `confirmed_by`, so a malformed caller would surface as an opaque 500 mid-transaction. Add,
   before the lock: for `action == "confirm"`, `user <- suppressWarnings(as.integer(review_user_id))`
   and `stop_for_bad_request()` when it is not a single non-NA integer.
9. **(Task 8)** Detect the conditional-update miss with
   `identical(as.integer(affected), 0L)` — `db_execute_statement()` returns
   `DBI::dbGetRowsAffected()` (`db-helpers.R:320`).
10. **(P1, Task 8)** The tuple lock binds one scalar per `?`. Build the SQL as
    `paste(rep("(?, ?, ?)", n), collapse = ", ")` and pass ONE flattened unnamed list in
    placeholder order — never a list of triples.
13. **(P1, Task 7)** The paging query must be written out in full, not offered as two options. Use
    exactly this shape, with the `moved`/`served` predicates repeated inside the paging subquery
    (SQL cannot reference a same-`SELECT` alias in `WHERE`):

    ```sql
    SELECT <row cols>, <served EXISTS> AS served, <moved EXISTS> AS moved,
           e.source_type, e.source_key, e.batch_id, e.evidence_strength, e.evidence_summary
      FROM variation_ontology_assertion a
      JOIN ndd_entity_view v ON v.entity_id = a.entity_id
      LEFT JOIN variation_ontology_list l ON l.vario_id = a.vario_id
      LEFT JOIN variation_ontology_evidence e ON e.assertion_id = a.assertion_id
      JOIN (SELECT a2.assertion_id,
                   MAX(e2.evidence_strength) AS max_strength
              FROM variation_ontology_assertion a2
              JOIN ndd_entity_view v2 ON v2.entity_id = a2.entity_id
              LEFT JOIN variation_ontology_evidence e2 ON e2.assertion_id = a2.assertion_id
             WHERE a2.state IN ('active_unconfirmed','suggested')
               <same filters, same bound params>
             GROUP BY a2.assertion_id
             ORDER BY <sort clause> , a2.assertion_id ASC
             LIMIT ? OFFSET ?) page ON page.assertion_id = a.assertion_id
     ORDER BY page.max_strength DESC, a.assertion_id ASC,
              (e.evidence_strength IS NULL) ASC, e.evidence_strength DESC,
              e.source_key ASC, e.evidence_id ASC
    ```

    `<sort clause>` is chosen from the allowlist and puts unrecorded strength LAST in both
    directions, mirroring `.svc_vp_evidence_order()`
    (`entity-variation-provenance-service.R:381`):
    * `strength_desc` → `(MAX(e2.evidence_strength) IS NULL) ASC, MAX(e2.evidence_strength) DESC`
    * `strength_asc` → `(MAX(e2.evidence_strength) IS NULL) ASC, MAX(e2.evidence_strength) ASC`
    * `entity_asc` → `a2.entity_id ASC, a2.vario_id ASC, a2.modifier_id ASC`

    The filter params are bound TWICE (outer WHERE and paging subquery), so build the param list by
    concatenating the same vector twice plus `limit` and `offset`. Add a unit assertion that the
    two occurrences use identical clause text.
14. **(Task 7)** `MAX(evidence_strength)` with `GROUP BY a2.assertion_id` is valid (MySQL
    functional dependency on the primary key), so no `ONLY_FULL_GROUP_BY` workaround is needed.
16. **(Spec, §5.1)** The queue read is **two** DB queries (count + page), not one. Correct the
    spec's "one query per request" wording when updating docs in Task 15; the invariant that
    matters is that it is DB-only and does not issue one query per row.
17. **(P1, new Task 17)** MSW/OpenAPI parity — `make lint-app` fails without it.
18. **(P1, new Task 16)** Endpoint-level authorization/body/serializer tests.
20. **(P2, Task 1)** The serializer test asserts `jsonlite` behaviour, not the route. Add a static
    assertion to `test-unit-variation-evidence-record-shapes.R` that
    `api/endpoints/entity_endpoints.R` still carries
    `#* @serializer json list(na="string", null="null")` above the evidence route, so losing the
    decorator fails a test rather than silently changing the wire shape.
21. **(P1, fixed inline)** The dialog renders one `VariationEvidenceRecordList` per SOURCE, bound
    to `record.records`.
22. **(P2, Task 2)** Avoid the import cycle: `variationEvidenceRecords.ts` must NOT import from
    `variationProvenance.ts` while the latter imports the former. Put `unwrapScalar`, `asText`,
    `asStrength` and `asBoolean` in a new dependency-free
    `app/src/views/pages/components/variationWireScalars.ts`; both modules import from there, and
    `variationProvenance.ts` re-exports `unwrapScalar` so its existing consumers are unaffected.
24. **(P2, Task 2)** The fixture loader must mirror
    `app/src/test-utils/clinvarVocabularyFixture.ts` — `readFileSync` plus an upward walk from
    `process.cwd()`, NOT a JSON `import` from outside `app/`. Copy that file's `resolveFixturePath`
    verbatim with the new relative path.
25. **(P1, fixed inline)** `splitOntologyTag()` returns `{ modifierId, ontologyId }`.
26. **(P1, Task 13)** `useModifyEntityWorkflows` has TWO argument builders — `getReviewArgs()` at
    `:45` (the combined status+review workflow) and `reviewArgs()` at `:137` (the inline workflow).
    `provenanceActionFor` must be threaded through BOTH, or combined direct approval silently drops
    every confirmation.
27. **(P1, Task 14)** `useApproveReviewController.ts` is already **596** lines. Extract before
    adding: move the review-edit modal's state and submit adapter into a new
    `app/src/views/curate/composables/useApproveReviewEditing.ts`, commit that extraction on its
    own, and only then add the zones. `make code-quality-audit` is the gate.
30. **(P2, Task 15)** Add `make verify-seo-app` to the final verification list. The new route is
    `sitemap: { ignoreRoute: true }`, so it must not appear in the sitemap — running the gate is
    what proves it.

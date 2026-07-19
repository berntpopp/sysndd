You previously reviewed feature #574 (category-selected gene universes for functional clustering) on this branch and returned NO-SHIP with 2 HIGH, 1 MEDIUM, 1 LOW findings. Those have been addressed in new commits. Re-review the CURRENT diff of the branch vs master: run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

## The 4 findings that were supposed to be fixed — VERIFY each is actually fixed (and correctly):
1. **HIGH** — `{"genes":[], "category_filter":["X"]}` must now 400 (mutual exclusion on genes KEY present, not just non-empty). Verify an empty `genes` array + a category is rejected, while `{"genes":[]}` ALONE still falls through to the all-NDD default (must NOT have regressed), and `{"genes":["HGNC:1"]}` alone is still explicit.
2. **HIGH** — `clustering_cached_source_data_version()` must be fail-closed: an `NA`/empty/non-scalar source version must NOT be cached or returned; it must throw so the service returns 503. Verify both the fetched-value and any cached-value paths validate, and that a transient invalid value doesn't poison the cache for the TTL.
3. **MEDIUM** — `resolved_gene_count` must equal the distinct-gene count (consistent with `gene_list_sha256`'s sorted-unique), WITHOUT deduping the payload `genes` list (explicit payload `genes` must stay byte-identical to today).
4. **LOW** — the integration test's `pool` rebinding must use `base::get(..., envir=)` (config::get masks bare get).

## Then do a FRESH adversarial pass on the whole #574 diff for anything you did NOT flag before — especially:
- New asymmetries introduced by the fixes (e.g. the mutual-exclusion change breaking a valid request shape; the count change diverging between the cache-hit meta and the create_job payload).
- The test-file split (`test-unit-job-endpoint-services.R` → a new sibling file): did any test get dropped, weakened, or duplicated in the split? Are both files coherent and under 600 lines?
- The fail-closed source-version validator: any path where an exception escapes as a raw 500 instead of the intended 503 `PROVENANCE_UNAVAILABLE`?
- Re-confirm the locked contract from the first review (entity-level resolution; NULL/absent→default cache parity; supplied-empty→400; <2 genes→400; allowed set in the error MESSAGE; selector-aware dedup additive-only; provenance shape incl. effective_fingerprint on both cache-hit and worker paths; never public_ready; dbplyr `%in%` not string interpolation; `dplyr::`/`base::get` namespacing).

## Output
For each finding: severity (BLOCKER / HIGH / MEDIUM / LOW), file:line, concrete failure scenario, and fix. Confirm explicitly whether each of the 4 prior findings is now resolved. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.

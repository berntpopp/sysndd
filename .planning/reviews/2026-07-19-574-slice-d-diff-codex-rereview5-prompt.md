Fifth-pass review of feature #574 (category-selected gene universes for functional clustering). Run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

Prior rounds are resolved:
- Round 2 HIGH (genes:null mutual-exclusion bypass) — fixed via `names(req$argsBody)` key-presence.
- Round 3 HIGH (provenance in dedup hash) — fixed via an optional `hash_payload`/`hash_params` (default NULL → hash full payload; other callers unaffected); the clustering submit hashes the payload MINUS provenance. `create_job` KEPT its guarded 2-arg `(operation, params)` contract; the clustering cache-miss path now calls `async_job_service_submit(..., hash_payload = ...)` directly (like the cache-hit path already calls `async_job_service_store_completed` directly).
- Round 4 HIGH (category_filter:null silently defaulted) — fixed: the branch now keys off `"category_filter" %in% names(req$argsBody)` and rejects a present-but-null value as supplied-empty (400). Symmetric with the genes-null fix.

VERIFY each of the three is resolved and mutually consistent:
- `{"category_filter":null}` alone → 400 (supplied-empty); `{"category_filter":[]}` → 400; `{"category_filter":["Definitive"]}` → category; `{}` / `{"genes":["X"]}` unchanged; both keys present (any values incl. null/empty) → 400 mutual exclusion.
- The dedup hash for explicit/no-arg is byte-identical to pre-#574 (provenance excluded; hash over genes/algorithm/category_links/string_id_table), category adds category_filter; provenance still STORED in request_payload_json for the worker echo; all other async-job callers unaffected by the default-NULL hash_payload.
- `create_job` is still exactly `(operation, params)`.

Then a FINAL adversarial pass. Report ONLY findings tied to a concrete failure scenario (specific inputs → wrong output/crash/contract violation) — no speculative or stylistic nits. Re-confirm the full locked contract (entity-level dbplyr resolution; NULL/absent→default cache parity; supplied-empty/<2-genes→400 with the allowed set in the MESSAGE; mutual exclusion via key-presence; provenance + effective_fingerprint on both cache-hit and worker paths; fail-closed source_data_version never NA/503; never public_ready; `dplyr::`/`base::get` namespacing; all touched files < 600 lines).

Output: for each finding, severity (BLOCKER/HIGH/MEDIUM/LOW), file:line, concrete failure scenario, fix. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.

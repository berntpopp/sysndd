Fourth-pass review of feature #574 (category-selected gene universes for functional clustering). Run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

Your round-3 review returned NO-SHIP with 1 HIGH: the durable clustering payload's `provenance` (time-varying source_data_version + fingerprint) was hashed into the DB `active_request_hash`, breaking byte-identical `request_hash` for explicit/no-arg jobs and weakening active-job dedup.

This was fixed by adding an optional, backward-compatible `hash_payload`/`hash_params` to `async_job_service_submit()` / `async_job_service_store_completed()` / `create_job()` (default NULL → hash the full payload exactly as before, so other callers are unaffected). The clustering submit now passes a hash payload equal to the durable payload MINUS `provenance`: for explicit/no-arg that is `list(genes, algorithm, category_links, string_id_table)` (byte-identical to pre-#574); for a category selector it additionally includes `category_filter`. `provenance` remains STORED in `request_payload_json` (so the worker still echoes it).

VERIFY:
- The explicit/no-arg DB `request_hash` is now byte-identical to pre-#574 (hash over genes/algorithm/category_links/string_id_table, provenance excluded), and two identical submits with differing provenance now hash the same.
- The category dedup identity is selector-aware (category_filter in the hash payload) and provenance is excluded there too.
- `provenance` is still stored in the persisted payload (not dropped) so the worker meta echo still works.
- The optional param defaults preserve byte-identical behavior for ALL other async-job callers (comparisons, llm-batch, publication refresh, disease-ontology mapping, etc.) — a NULL hash_payload must hash the full request_payload as before.

Then a final adversarial pass — report ONLY findings tied to a concrete failure scenario (specific inputs → wrong output/crash/contract violation), no speculative/stylistic nits. Re-confirm the full locked contract holds (entity-level resolution; default cache parity; empty/<2/category-validation 400s with the allowed set in the MESSAGE; mutual exclusion via key-presence; provenance + effective_fingerprint on both paths; fail-closed source_data_version; never public_ready; dbplyr `%in%`; `dplyr::`/`base::get`; files < 600 lines).

Output: for each finding, severity (BLOCKER/HIGH/MEDIUM/LOW), file:line, concrete failure scenario, fix. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.

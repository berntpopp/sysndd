Sixth-pass review of feature #574 (category-selected gene universes for functional clustering). Run `git diff origin/master...HEAD -- ':(exclude).planning/**'`. Read touched files in full.

Round 5 HIGH is fixed: every category-validation 400 message now names the allowed active-category set. `clustering_resolve_category_universe()` fetches the active category list right after the absent-selector default branch, and includes `Allowed active categories: …` in the supplied-empty, unknown, AND `<2`-genes messages. The service's present-but-null `category_filter` case now COERCES the null value to an empty selector and delegates to the resolver (single validation source), instead of raising its own message.

VERIFY:
- `{"category_filter":null}`, `{"category_filter":[]}`, an unknown category, and a valid category resolving to `<2` genes all return 400 AND every message contains the allowed active-category set.
- The absent-selector default branch (`clustering_resolve_category_universe(NULL)`) still does NOT fetch the active list (no extra DB query — cache parity preserved).
- The service present-but-null delegation is correct: `{"category_filter":null}` → resolver called with an empty selector → 400.

Then a FINAL adversarial pass. This is round 6; prior rounds resolved genes/category key-presence mutual exclusion, the fail-closed source-version cache, distinct gene counts, the provenance-out-of-dedup-hash fix (with create_job keeping its 2-arg contract), and the allowed-set-in-messages fix. Report ONLY findings tied to a concrete failure scenario (specific inputs → wrong output/crash/contract violation) — NO speculative or stylistic nits, and do not re-raise anything already resolved. Re-confirm the full locked contract holds.

Output: for each finding, severity (BLOCKER/HIGH/MEDIUM/LOW), file:line, concrete failure scenario, fix. Final line: **VERDICT: SHIP** (zero BLOCKER/HIGH) or **VERDICT: NO-SHIP** with the count.

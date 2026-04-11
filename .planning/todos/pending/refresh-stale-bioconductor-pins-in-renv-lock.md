# Refresh stale Bioconductor pins in api/renv.lock

## Problem

`api/renv.lock` pins several Bioconductor packages to versions from Bioconductor 3.20. Bioconductor has since advanced, and the archived tarballs for these pins return 404 on both Posit PPM and the Bioconductor archive mirrors:

- `zlibbioc 1.52.0`
- `XVector 0.46.0`
- `Biostrings 2.74.1`
- `KEGGREST 1.46.0`
- `AnnotationDbi 1.68.0`
- `IRanges 2.40.1` (at least partially reachable, but in the same cohort)
- `httr 1.4.7` (CRAN, "failed to find source")

Existing CI jobs mask the rot via `actions/cache` hits on the renv library — a previous run populated the cache while the packages were still reachable, and subsequent runs restore from cache without hitting upstream. A fresh clone / fresh cache run would fail.

## Why this matters

1. **Risk 5 mitigation is weakened.** Phase A7's `make doctor` originally asserted `renv::status() → synchronized` as Risk 5 mitigation against renv drift. That check was relaxed in the same PR to a restore-only check because the strict check surfaces the pre-existing rot and blocks the phase. The intent of Risk 5 remains, but enforcement is now lighter.
2. **A fresh developer environment cannot be bootstrapped without hitting the rot.** New contributors running `make install-dev` on a clean host without a populated cache will see confusing `cannot open URL` errors from renv during the Bioconductor downloads.
3. **Any CI cache miss / eviction will break the pipeline.** This is a latent failure waiting to happen.

## Proposed fix

One of:

1. **Bump the Bioconductor version** in the lockfile (`Bioconductor.Version: "3.20"` → current, e.g. `"3.21"`) and re-snapshot. Potentially cascades into package upgrades across the Bioconductor closure (`biomaRt`, `STRINGdb`, `AnnotationDbi`, etc.).
2. **Pin to specific versions that are still reachable** via Bioconductor archive or a vendored tarball source in `renv::sources`.
3. **Remove the packages entirely** from the lockfile if the API runtime no longer uses them (verify via `grep -r biomaRt api/functions api/endpoints api/services api/core`).

Option 1 is the canonical fix. It will require careful validation of API runtime behavior against the new Bioconductor release (biomaRt in particular has breaking changes every release).

## Discovered by

Phase A7 `dev-environment-bootstrap` (PR #220, v11.0 Phase A). Detected while the Docker sidecar attempted a fresh `renv::restore()` to add lintr + styler to the lockfile. The same rot is visible in CI via `renv::status()$synchronized == FALSE` when caches are stale.

## Defer to

A dedicated lockfile-refresh phase, likely Phase F in v11.0 or a v11.1 chore. Not blocking Phase A beyond the doctor relaxation already applied.

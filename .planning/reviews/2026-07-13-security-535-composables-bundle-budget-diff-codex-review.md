# #555 final Codex adversarial diff review

**Scope:** remove heavyweight composable-barrel exports and enforce a real production
Rollup route-bundle / Workbox budget gate.

**Final verdict:** `SHIP`

**BLOCKER/HIGH remaining:** no.

The bounded final xhigh verdict pass returned exactly `Verdict: SHIP` and
`BLOCKER/HIGH remaining: no`. It followed four deep xhigh read-only passes and folded
every concrete finding before the final gate run.

## Review rounds and resolutions

1. **Deep round 1 — `NEEDS_CHANGES`, no BLOCKER/HIGH.**
   - Found deployment of module-attribution metadata, a Workbox parser that could
     fail open, and diverging heavy-package classifiers.
   - Resolved by removing `.vite` in a verifier `finally`, Docker/nginx defense in
     depth, nonempty/core Workbox assertions with deterministic parser tests, and a
     shared classifier that includes Cytoscape support packages and all UpSet.js
     packages.
2. **Deep round 2 — `NEEDS_CHANGES`, no BLOCKER/HIGH.**
   - Found that an unrelated service-worker `url` field could satisfy the guard.
   - Resolved by extracting only the balanced `precacheAndRoute([...])` array and
     adding the negative fixture.
3. **Deep round 3 — `NEEDS_CHANGES`, no BLOCKER/HIGH.**
   - Found multiple `precacheAndRoute` calls and nested `url` metadata were not
     safely handled.
   - Resolved test-first: multiple calls now fail closed; the stateful parser accepts
     only direct record-level `url` fields and ignores nested metadata.
4. **Deep round 4 — `NEEDS_CHANGES`, no BLOCKER/HIGH.**
   - Found CI gated Docker mode although the shipped image is Vite production mode.
   - Resolved test-first: `build:bundle-budget` now runs
     `BUNDLE_BUDGET=true npm run build:production`; the helper test proves it and the
     real production artifact passed unchanged ceilings.
5. **Deep round 5 — inconclusive, cancelled.**
   - The reviewer broadened into unrelated planning documents and emitted no usable
     verdict; its raw output is preserved. It was not treated as approval.
6. **Bounded final xhigh verdict — `SHIP`.**
   - A no-tools final pass over the narrowed diff and all fresh gate evidence found
     no new concrete finding and explicitly reported no remaining BLOCKER/HIGH.

## Fresh verification evidence

- `make code-quality-audit` — passed.
- `make lint-app` — passed, 0 errors and 245 existing warnings.
- `cd app && npm run type-check:strict` — passed.
- `cd app && npm run test:unit` — 265 files passed, 1,995 tests passed, 2 todo.
- `cd app && npm run build:bundle-budget` — helper tests 10/10 passed; the actual
  production Rollup gate passed with HomeView `247093/300000 B`, SearchView
  `239682/290000 B`, OntologyView `263599/320000 B`, and AnalysisView
  `243728/295000 B` gzip. The Workbox heavy-chunk check passed and `.vite`
  attribution metadata was absent after verification.
- `git diff --check` — passed.

The only review-environment limitation was read-only `/tmp`, which prevented Codex's
own temporary-directory cleanup test. That exact test passed locally in the fresh
10/10 helper run above.

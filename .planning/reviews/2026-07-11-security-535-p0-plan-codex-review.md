## Findings

### BLOCKER

1. **S0’s planned implementation cannot make the existing endpoint test files pass.**

The plan changes handler signatures to include `req, res`, but it does not update the existing assertions that require the old signatures:

- [test-endpoint-review.R:612](/home/bernt-popp/development/sysndd/api/tests/testthat/test-endpoint-review.R:612), plus the equivalent assertions at lines 652, 695, and 735, still expect `function(review_id_requested)`.
- [test-endpoint-status.R:183](/home/bernt-popp/development/sysndd/api/tests/testthat/test-endpoint-status.R:183) still expects `function(status_id_requested)`.

More seriously, existing per-route permission tests still require these routes to remain public:

- [test-endpoint-review.R:626](/home/bernt-popp/development/sysndd/api/tests/testthat/test-endpoint-review.R:626) and analogous phenotype/variation/publication tests beginning at lines 671, 711, and 750 assert no `require_role`.
- [test-endpoint-status.R:197](/home/bernt-popp/development/sysndd/api/tests/testthat/test-endpoint-status.R:197) asserts no `require_role`.

The plan only replaces the list-route public tests and adds new detail assertions ([S0 plan:31](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s0-endpoint-authz-plan.md:31), [S0 plan:133](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s0-endpoint-authz-plan.md:133)). Consequently, the old and new assertions would directly contradict each other.

**Fix:** explicitly replace all five old review permission assertions, the status-detail assertion, and all five obsolete signature assertions.

2. **S1 puts bulk epoch handling in the wrong layer and loses transaction atomicity.**

The plan names [user-bulk-endpoint-service.R](/home/bernt-popp/development/sysndd/api/services/user-bulk-endpoint-service.R:23) as the modification site and suggests calling `user_bump_session_epoch()` per ID after inspecting bypasses ([S1 plan:200](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:200)). That file only delegates. The actual transactional SQL is in:

- Bulk role: [user-service.R:569](/home/bernt-popp/development/sysndd/api/services/user-service.R:569), update at line 576.
- Bulk approval: [user-service.R:371](/home/bernt-popp/development/sysndd/api/services/user-service.R:371), update at line 400 and password update at line 418.
- Bulk deletion: [user-service.R:492](/home/bernt-popp/development/sysndd/api/services/user-service.R:492).

The proposed helper has no `conn` argument and uses the global DB helper ([S1 plan:171](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:171)). Calling it from the wrapper after `user_bulk_*()` commits creates a durable interval—or process-crash state—where the privilege change is committed but the epoch is not bumped. Calling it from inside `db_with_transaction()` without passing `txn_conn` may use another connection.

Bulk approval is additionally inconsistent with the real schema and auth state: it updates nonexistent `account_status` and `approving_user_id` user columns ([user-service.R:377](/home/bernt-popp/development/sysndd/api/services/user-service.R:377), [user-service.R:400](/home/bernt-popp/development/sysndd/api/services/user-service.R:400)), while authentication checks `approved` ([auth-service.R:47](/home/bernt-popp/development/sysndd/api/services/auth-service.R:47)); the base user schema has `approved` but neither bulk column ([000_initialize_base_schema.sql:282](/home/bernt-popp/development/sysndd/db/migrations/000_initialize_base_schema.sql:282)).

**Fix:** modify the SQL in `user-service.R` itself. Each role/approval/password mutation must update the state and `session_epoch = session_epoch + 1` in the same SQL statement and transaction. Bulk approval must use the actual `approved` schema. Hard deletion needs no preceding bump because DB-backed refresh rejects a missing user.

3. **The new S1 DB tests use a fixture helper that cannot insert into the actual schema.**

The proposed tests call `user_create()` ([S1 plan:117](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:117), [S1 plan:243](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:243)). That repository function inserts into `user_email` ([user-repository.R:157](/home/bernt-popp/development/sysndd/api/functions/user-repository.R:157)), but the table column is `email` ([000_initialize_base_schema.sql:286](/home/bernt-popp/development/sysndd/db/migrations/000_initialize_base_schema.sql:286)). These tests will fail before exercising epochs.

**Fix:** seed test users with parameterized SQL using the actual columns, or first correct and independently test `user_create()`. Do not let an unrelated broken helper invalidate the security regression tests.

### HIGH

4. **S1’s separate state update and epoch bump permits refresh/revocation races.**

The proposed `user_update()` sequence executes the privilege update and then a separate epoch update ([S1 plan:181](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:181)). The password path is likewise two statements ([S1 plan:193](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:193)).

A concurrent refresh can read the old role/epoch just before a demotion, then mint an old-role token after the demotion commits. Since `require_auth` does not check the epoch, that token remains usable until expiry. This violates the stated immediate refresh-revocation property under concurrency.

**Fix:** fold the epoch increment into the exact mutation statement. Then treat the refresh DB read as the linearization point: a refresh either reads the complete old row before the atomic mutation or the complete new row after it. Add a deterministic concurrency/transaction test if feasible.

5. **S0 still exposes approved review/status comments through anonymous entity endpoints.**

The S0 goal explicitly includes comments, and its split strategy says anonymous responses should drop comment/workflow fields ([design spec:130](/home/bernt-popp/development/sysndd/.planning/superpowers/specs/2026-07-11-security-hardening-535-design.md:130)). Yet public entity routes have no auth gate:

- [entity_endpoints.R:284](/home/bernt-popp/development/sysndd/api/endpoints/entity_endpoints.R:284)
- [entity_endpoints.R:299](/home/bernt-popp/development/sysndd/api/endpoints/entity_endpoints.R:299)

Their services return `comment`:

- Approved-primary review comment: [entity-read-endpoint-service.R:333](/home/bernt-popp/development/sysndd/api/services/entity-read-endpoint-service.R:333).
- Active-approved status comment: [entity-read-endpoint-service.R:354](/home/bernt-popp/development/sysndd/api/services/entity-read-endpoint-service.R:354), selected at line 372.

These paths do not leak drafts, because their approval predicates are correct, but they still expose comments if those are curator workflow notes. The plan’s assertion that the entity family can remain wholly untouched is therefore broader than the source supports.

**Fix:** decide explicitly whether approved review/status comments are public editorial content or private workflow metadata. If private, remove them from anonymous entity responses or provide Reviewer+ enriched responses. If intentionally public, narrow the S0 goal/spec so it does not claim all comments are protected.

6. **The planned S0 tests do not prove the acceptance criterion.**

The proposed behavioral tests cover only review detail and status detail ([S0 plan:227](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s0-endpoint-authz-plan.md:227)). Source grep merely proves that a matching string exists somewhere in a handler; it does not prove Plumber execution, denial before query, or a body free of leaked rows. The live checks cover only a subset and inspect status codes, not response bodies ([S0 plan:273](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s0-endpoint-authz-plan.md:273)).

A green plan could still leave:

- Review list, phenotype, variation, or publication behavior untested.
- A gate after data access.
- A custom error handler that returns sensitive body data with 403.
- Missing Reviewer positive controls.
- Plumber signature/binding failures.

**Fix:** add behavioral denial tests for all seven gated GET routes, with a DB/query sentinel; assert 403 and an empty/non-sensitive body. Add Reviewer positive controls for list, detail, and each review subresource. Add mounted-router or HTTP-level tests that exercise actual Plumber binding.

7. **The S1 “current role” test does not demonstrate role-current minting.**

The test creates an Administrator, mints an Administrator token, performs no role change, refreshes, and asserts Administrator ([S1 plan:271](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:271)). An implementation that loads only approval/epoch but reuses the token’s role would pass.

The test suite also omits several cases required by the spec: explicit demotion, password change, deleted user, malformed/missing user ID, and a normal refresh proving DB-derived non-role claims. The self-review nevertheless claims broader coverage ([S1 plan:394](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:394)).

**Fix:** add:

- A direct test-only DB role change without an epoch change, then assert refresh mints the DB role. This isolates “DB-derived claims.”
- Production-path demotion and deactivation tests asserting rejection after epoch bump.
- Password-change and deleted-user rejection.
- Tests showing role, name/email, and epoch are taken from the DB row.
- An assertion that the endpoint returns 401 rather than merely “some error.”

### MEDIUM

8. **The proposed refresh query ignores the repository’s documented masking footgun.**

The plan explicitly recommends unqualified `tbl`, `filter`, and `collect` ([S1 plan:350](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:350)). The runtime loads many packages, including biomaRt and STRINGdb ([init_libraries.R:40](/home/bernt-popp/development/sysndd/api/bootstrap/init_libraries.R:40), [init_libraries.R:59](/home/bernt-popp/development/sysndd/api/bootstrap/init_libraries.R:59)), and this repository specifically treats masked dplyr verbs as a correctness hazard.

`filter(user_id == !!uid)` is otherwise valid tidy evaluation, and `dplyr::rename` is available. `%||%`, `stop_for_bad_request`, and `stop_for_unauthorized` are already used in the auth service, so those are in scope.

**Fix:** use `dplyr::tbl`, `dplyr::filter(.data$user_id == !!uid)`, `dplyr::rename`, and `dplyr::collect`. Validate that `claims$user_id` converts to one finite, positive integer before querying.

9. **The migration guard update is incomplete as written.**

The migration SQL’s `information_schema.COLUMNS` check and prepared conditional DDL are valid MySQL patterns. Count 41 is correct because there are currently 40 SQL migrations.

However, the plan only instructs changing the latest-name expectation at the top of each guard test ([S1 plan:32](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s1-session-epoch-refresh-plan.md:32)). Existing tests also assert:

- Count 40 at [test-unit-core-views-manifest.R:14](/home/bernt-popp/development/sysndd/api/tests/testthat/test-unit-core-views-manifest.R:14).
- Returned latest name at [test-unit-core-views-manifest.R:21](/home/bernt-popp/development/sysndd/api/tests/testthat/test-unit-core-views-manifest.R:21).
- Count 40 at [test-unit-analysis-snapshot-migration.R:9](/home/bernt-popp/development/sysndd/api/tests/testthat/test-unit-analysis-snapshot-migration.R:9).

**Fix:** enumerate all four stale assertions in the plan. No additional independent minimum-count constant was found beyond `EXPECTED_MIGRATION_COUNT`.

### LOW

10. **The S0 router-role description is factually wrong, although consumer compatibility remains safe.**

The plan says both approval queues are router-gated to Administrator/Curator/Reviewer ([S0 plan:7](/home/bernt-popp/development/sysndd/.planning/superpowers/plans/2026-07-11-security-535-s0-endpoint-authz-plan.md:7)). They are actually Curator+:

- [routes.ts:435](/home/bernt-popp/development/sysndd/app/src/router/routes.ts:435)
- [routes.ts:442](/home/bernt-popp/development/sysndd/app/src/router/routes.ts:442)

They do send Bearer tokens: both resolve to `apiClient.raw` ([ApproveStatus.vue:77](/home/bernt-popp/development/sysndd/app/src/views/curate/ApproveStatus.vue:77), [useApproveReviewController.ts:68](/home/bernt-popp/development/sysndd/app/src/views/curate/composables/useApproveReviewController.ts:68)), and the shared interceptor injects the token ([client.ts:69](/home/bernt-popp/development/sysndd/app/src/api/client.ts:69)). Gating the API at Reviewer+ therefore will not break these consumers.

**Fix:** correct the plan narrative to “the current approval views are Curator+, while the API intentionally admits Reviewer+.”

11. **Legacy no-`sepoch` compatibility creates a bounded replay window, not an epoch bypass.**

A legacy token for an epoch-0 user is accepted and can be replayed until its original expiry; each refreshed token gains `sepoch=0`. Once the user’s epoch is bumped, the legacy token maps to 0 and is rejected. This does not bypass demotion/deactivation revocation, but it preserves replay of pre-deployment tokens during their remaining lifetime.

**Fix:** document the bounded compatibility window. If zero legacy acceptance is required, initialize existing users to epoch 1 or enforce a deployment-time `iat` cutoff.

## Confirmed points

- Only four review detail/subresource handlers lack `req, res`; the review list already has both ([review_endpoints.R:33](/home/bernt-popp/development/sysndd/api/endpoints/review_endpoints.R:33)). Status detail lacks them ([status_endpoints.R:168](/home/bernt-popp/development/sysndd/api/endpoints/status_endpoints.R:168)).
- Adding named `req, res` arguments is consistent with existing Plumber path handlers, such as [status_endpoints.R:320](/home/bernt-popp/development/sysndd/api/endpoints/status_endpoints.R:320); it should not disturb path-parameter binding.
- No additional GET route was missed in these two endpoint files. `_list` is the only intentionally public status GET and reads only `ndd_entity_status_categories_list` ([status_endpoints.R:228](/home/bernt-popp/development/sysndd/api/endpoints/status_endpoints.R:228)). `approve/all` is not an extra GET; approval matches the gated PUT route.
- Migration 042 correctly gates the public phenotype and variation connect views on primary and approved review state ([042_gate_connect_views_review_approved.sql:44](/home/bernt-popp/development/sysndd/db/migrations/042_gate_connect_views_review_approved.sql:44), [042_gate_connect_views_review_approved.sql:67](/home/bernt-popp/development/sysndd/db/migrations/042_gate_connect_views_review_approved.sql:67)).
- Other inspected public data paths were approval-gated: entity review/status content, MCP repository queries, and SEO queries. Re-review and user-identity surfaces have endpoint role gates.
- Initial approval’s approval bump plus password bump would double-increment; that is harmless but should preferably be one atomic account-initialization update.
- Stamping `password_reset_date` does not trigger the proposed `user_update` bump, which is correct. The actual password reset/change uses `user_update_password()` ([user-password-profile-endpoint-service.R:272](/home/bernt-popp/development/sysndd/api/services/user-password-profile-endpoint-service.R:272)) and should bump atomically.
- Deferring distinct rotating refresh tokens is defensible for the narrow P0 refresh criterion. Epoch checking in every `require_auth` call is also not a strict co-dependency, provided the one-hour access-token residual is explicitly accepted. Atomic state+epoch mutation is a co-dependency and cannot be deferred.

## Corrections to apply before implementation

1. Rewrite the S0 test tasks to update every obsolete signature and public-permission assertion.
2. Add behavioral and mounted-router tests for all seven gated GET routes, including body non-disclosure and Reviewer positive controls.
3. Classify entity review/status comments as public or private; strip them for anonymous users if they are workflow notes.
4. Move bulk epoch work into `user-service.R`, where the transactional SQL actually lives.
5. Make privilege, approval, and password changes increment the epoch in the same SQL statement and transaction.
6. Correct bulk approval to use the real `approved` schema; do not build epoch logic atop nonexistent `account_status` fields.
7. Give any reusable epoch helper an explicit `conn` parameter, or inline the atomic increment into mutation SQL.
8. Replace the broken `user_create()` fixture dependency in new tests.
9. Expand S1 tests to cover real demotion, deactivation, password change, deletion, DB-derived claims, and error status.
10. Namespace all dplyr/dbplyr verbs in `auth_refresh` and validate the decoded user ID.
11. Update every latest-migration and migration-count assertion, including the returned `res$latest`.
12. Document the concurrency linearization guarantee, legacy-token window, access-token residual, and the precise boundary of deferred S1b work.

This was a static, read-only review. Per request, I did not edit files, run tests, or start services.
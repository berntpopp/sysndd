# Handoff — issue #318 fix execution

Date: 2026-05-08
Branch: `fix/rename-atomicity-pubdate-validation`
HEAD at handoff: `835c9056`

## Why a handoff

The plan was split across two repositories. Brainstorm + spec + plan were authored in `sysndd-administration` after debugging a production incident; Tasks 1-6 of the implementation were executed via subagents from that same session. To keep the rest of execution clean (and not bleed admin-repo context into the build), Tasks 7-15 should run in a **fresh session opened directly in `C:\development\sysndd`**.

The complete spec and plan are already on this branch as durable artifacts:
- Spec: `.planning/superpowers/specs/2026-05-08-rename-atomicity-pubdate-validation-design.md`
- Plan: `.planning/superpowers/plans/2026-05-08-rename-atomicity-pubdate-validation-plan.md`

## State at handoff

**Tasks 1-6 done**, each with implementer + (where appropriate) reviewer + fix-loop. Commits:

| Task | Outcome | Commit |
|---|---|---|
| Spec | written, committed | `36ac6be8` |
| Plan | written, committed | `c17c93c6` |
| 1 — `review_create` propagation | implementer + 4-issue fix loop | `bb684cca` → `56b60ea2` |
| 2 — `status_create` propagation | implementer + 1-issue fix loop | `9a86fbf8` → `090440bc` |
| 3 — `info_from_pmid` fail-fast | implementer (scope-creep) + revert fix | `bcdcebc7` → `67379b6d` |
| 4 — exclude `Publication_date` from `replace_na('')` | implementer | `436567ff` |
| 5 — atomic `new_publication` INSERT loop | implementer | `8b914e28` |
| 6 — `svc_entity_rename_full` service | implementer + 1-issue fix loop | `aa55db69` → `835c9056` |

Local test status (host R, no DB):
- `test-unit-review-repository.R`: 27 PASS / 0 FAIL
- `test-unit-status-repository.R`: 17 PASS / 0 FAIL
- `test-unit-publication-functions.R`: 45 PASS / 0 FAIL
- `test-unit-entity-service.R`: file-level SKIP because the test setup loads `db-helpers.R` which `library(RMariaDB)` — RMariaDB isn't in the host renv. The two new `test_that` blocks for `svc_entity_rename_full` are present and parseable; they will run when the test stack runs against Docker via `make test-api`.

## Tasks remaining (7-15)

All task text is in the plan file. Brief reminders:

7. **Replace `/rename` endpoint body with thin shim** in `api/endpoints/entity_endpoints.R` (handler at `@post /rename`, currently lines 459-665). Shim calls `svc_entity_rename_full(req$argsBody$rename_json, req$user_id, pool)`. Delete the ~200-line inline body. Spec §3.2.

8. **Map `publication_fetch_error` → HTTP 400** at three call sites: one in `entity_endpoints.R` (`/create` handler, around `pub_result <- new_publication(publications)`) and two in `review_endpoints.R` (the two `new_publication(publications_received)` calls). Wrap each in `tryCatch(..., publication_fetch_error = function(e) list(status = 400, message = paste("Bad Request.", e$message), error = e$message))`. Spec §3.6.

9. **Integration test: rename happy path** in `api/tests/testthat/test-integration-entity-rename.R` (new file). Seeds an approved entity via the pool (commits — uses explicit cleanup deletes, not rollback), calls `svc_entity_rename_full`, asserts new entity is_active=1/replaced_by=NULL, old replaced_by=new_id, new review approved, **new status `is_active=1, status_approved=1, approving_user_id` matching source**. Plus exact success message: `"OK. Entity renamed."`. Spec §4.3 first bullet, plan Task 9.

10. **Integration test: rollback on inner failure** — same file. Seeds an entity, mocks `phenotype_connect_to_review` to throw, asserts row counts in the 5 tables are byte-identical pre/post and source entity is unchanged. Plan Task 10.

11. **Integration test: bogus PMID rejected** — same file. Stubs `fetch_pubmed_data` to return empty XML for a fake PMID, asserts the surrounding flow returns 400 with the PMID listed in the message, no rows written anywhere. Plan Task 11.

12. **Integration tests for validation error paths** — same file. Three tests asserting exact response messages for 404 (source entity missing), 400 (ontology unchanged), 409 (destination quadruple exists). These strings are pinned because Task 14 wires them to the curator toast. Plan Task 12.

13. **Frontend `extractApiErrorMessage` helper** — create `app/src/utils/api-errors.ts` and `app/src/utils/__tests__/api-errors.spec.ts`. Pulls Plumber-shaped `{ message, error }` out of axios errors; handles plain Error, unknown shapes, Plumber's single-element-array scalar quirk. Five vitest cases. Plan Task 13.

14. **Wire `useEntityMutations` through helper** — modify `app/src/views/curate/composables/useEntityMutations.ts` `rename` / `deactivate` / `submitReview` catch blocks to route through `extractApiErrorMessage(e, fallback)` and pass the resulting string to `onToast`. Extend the spec file with three new vitest cases asserting toast receives the API message on 400/409 and the fallback on bare network errors. Plan Task 14.

15. **Final verification, push, open PR** — `make pre-commit`, `make ci-local`, frontend `npm run test:unit && npm run type-check && npm run lint`, manual smoke against dev stack (test the toast text!), then `git push -u origin` and `gh pr create`. PR template body in plan Task 15 Step 6.

## How to resume

Open a fresh Claude Code session at `C:\development\sysndd`. Confirm `git log -1 --format=%h` is `835c9056` (or pull if behind). Then start with:

> "I'm continuing the issue #318 fix on branch `fix/rename-atomicity-pubdate-validation`. Spec is at `.planning/superpowers/specs/2026-05-08-rename-atomicity-pubdate-validation-design.md`, plan is at `.planning/superpowers/plans/2026-05-08-rename-atomicity-pubdate-validation-plan.md`. Tasks 1-6 are done (see `.planning/superpowers/HANDOFF-2026-05-08-issue-318.md` for commit map). Resume with Task 7 using `superpowers:subagent-driven-development`."

The plan file's task texts are self-contained; subagents do not need to read this handoff.

## Lessons applied during Tasks 1-6 — keep applying

- **Use `mockery::stub()`, not `local_mocked_bindings()`** for unit tests. The repo sources helpers into `globalenv()`, not as a package, so `local_mocked_bindings` doesn't intercept the calls.
- **Don't add `skip_if_not_installed()` guards to existing tests** to work around partial renv state. AGENTS.md treats env problems as something CI must fail loudly on. If a package is missing, run `renv::restore(packages = "...")` instead.
- **Don't restructure unrelated test setup**. Keep commits to the exact files in the task's "Files" list.
- **Length-1 scalar guard before `is.na()` check** in repository propagation loops. Tasks 1+2 both got this wrong on the first try and needed a fix-loop.
- **Match exact response-message strings** to the spec. Task 12's tests will pin them, Task 14 wires them to the toast.

## Production cleanup still needed (out of PR scope)

Once this PR merges and deploys, run the BAIAP2 cleanup SQL from issue #318 to unblock Christiane's existing orphan:

```sql
UPDATE ndd_entity_status SET is_active = 1, status_approved = 1, approving_user_id = 3
WHERE status_id = 5562;
```

Christiane mentioned this is dangerous because she only notices the orphan state after re-checking. Worth telling her the BAIAP2 record is fine to retry once this lands.

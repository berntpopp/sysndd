# Approval-path rejection, the curation queue, zone picker, entity/review agreement

> Extracted verbatim from `AGENTS.md` (2026-09-01) to keep the root instruction file lean.
> This is the authoritative detail for this subsystem.

`variation_provenance_plan_reconciliation()` takes `apply_confirmations` alongside `apply_rejections`; it gates the SUBMITTED branch only and defaults TRUE, so every pre-#612 call site is byte-identical. `variation_provenance_reconcile_on_approval()` (`functions/variation-provenance-approval.R`) uses it with `apply_confirmations = FALSE`: approving a review is an act on the REVIEW, not a per-term reading of machine evidence, so it may only ever RETIRE assertions and must never promote.

`svc_approval_review_approve()` runs `review_approve()` and a per-entity reconciliation in **one** transaction scope, so a reconciliation failure rolls the approval back. Three things about it are load-bearing:

* **The served set is read AFTER `review_approve()`, and an empty set is meaningful.** Approval itself creates the primary approved review, so an entity whose approved review carries no variation terms legitimately serves none and every open assertion must be retired. There is deliberately **no** "skip when empty" guard — it would strand exactly the assertions the curation queue exists to retire.
* **`direct_approval` does NOT route through it.** `review_write_mutate()` calls `review_approve()` itself on its own transaction after already reconciling there; `review_apply_direct_approval()` has no call site. The one live caller is `PUT /api/review/approve/<review_id_requested>`.
* **The `"all"` check guards on length first.** `if (as.character(review_id) == "all")` raises "the condition has length > 1" for a vector, so the function's documented multi-id support had never worked — and the per-entity loop needs it.

`db_with_savepoint_or_transaction()` (`functions/db-transaction-scope.R`) is now the single place the pool-vs-caller-owned-connection decision lives: a pool gets a transaction, a caller-owned `DBIConnection` gets a SAVEPOINT because RMariaDB has no nested transaction and `with_test_db_transaction()` has already issued `dbBegin()`. `review_write_run_mutation()` delegates to it with its savepoint name unchanged. It lives in its own file, ahead of `db-helpers.R` in the loader, because `db-helpers.R` attaches RMariaDB and this logic needs only DBI — so it stays testable on a host without the MySQL client runtime.

### The curation queue (#612 Phase 6)

`GET /api/curate/variation/suggestions` plus `POST .../confirm` and `POST .../dismiss`, Curator-gated, mounted at `/api/curate/variation`; page at `/curate/variation-suggestions`.

**It spans TWO states, not `suggested` alone.** The #608 design named a queue over `state = 'suggested'`, but the backfill wrote every one of its 8,083 rows `active_unconfirmed`, so a suggested-only queue renders an empty page while the ~1,981-item weak-evidence backlog it exists to make tractable sits in the other state.

**The two actions are asymmetric, and this is the whole safety design.** `provenance_for_entity()` filters the public read to `('active_unconfirmed','confirmed')`, so writing `rejected` onto an `active_unconfirmed` assertion drops it out of that filter **while the term is still served** — and the entity card then renders it as CURATOR-AUTHORED, the exact fabrication this feature exists to prevent. Hence:

| State | Served? | Safe assertion-only action |
|---|---|---|
| `active_unconfirmed` | yes | **Confirm** |
| `suggested` | no | **Dismiss** |

The other direction of each pair has to ADD or REMOVE a curated term, which is a review write and belongs to `review_write_mutate()`. The queue never writes `ndd_review_variation_ontology_connect`; those rows link out to the entity.

**Concurrency.** Server-side re-derivation alone is not enough: a dismiss could read `suggested + not served` while a concurrent review write adds and approves the term, then commit `rejected` onto a now-served assertion. One batch is one transaction that `SELECT ... FOR UPDATE`s its assertion rows **ordered by `assertion_id`** (so concurrent batches cannot deadlock), re-reads served membership under those locks, and writes `... WHERE assertion_id = ? AND state = ?` with the state observed under the lock. A 0-row result is reported as `state_changed`, never retried. This serializes against `review_write_mutate()`, whose reconciliation updates the very same row.

**`moved`** is `origin_review_id`'s first consumer (migration `049`, 95 rows in production): the assertion has evidence whose `origin_review_id` is not currently a primary-approved review of that entity. Because that column deliberately has no foreign key, a vanished origin review also reads as moved.

Every skipped item is returned with its reason. A silent partial success on a provenance surface is the failure mode this feature exists to avoid.

`page` is capped at `CURATE_VARIATION_PAGE_MAX` (`.Machine$integer.max %/% CURATE_VARIATION_PAGE_SIZE_MAX`), not at `.Machine$integer.max`: the SQL offset is `(page - 1) * page_size` in R's **32-bit** integer arithmetic, so an unbounded page overflows to `NA` and binds `NA` as the `OFFSET`. `page_size` needs no such bound — it is clamped, not multiplied.

**Two bugs here were invisible to mocked unit tests** and were found only by executing the SQL: the filters were bound twice against one set of placeholders, and the outer `ORDER BY` led with `assertion_id`, discarding the caller's sort because a JOIN does not inherit its derived table's order. Both are covered by `test-integration-variation-suggestions.R`; keep exercising that file against a real schema.

### The zone picker is now on all four curation surfaces

`views/curate/components/VariationProvenanceZones.vue` is the extracted picker, mounted by `ReviewFormFields.vue` (Review), `InlineEntityWorkflow.vue` and `CombinedStatusReviewWorkflow.vue` (ModifyEntity), and `ReviewEditForm.vue` (ApproveReview). `displayName` is a **prop** because the Review form's resolver also consults its option-tree labels, which no other surface has.

`useModifyEntityWorkflows` has **two** argument builders — `getReviewArgs()` for the combined status+review workflow and `reviewArgs()` for the inline one. Both must thread `provenance_action_for`, or confirmations made through combined direct approval are silently dropped.

This is a **UX** change, not a correctness one: reconciliation is server-side and every surface was already protected. `ModifyEntity.vue`'s scoped styles moved to `./ModifyEntity.styles.css` (`<style scoped src="...">`, as `NddScoreGeneTable.vue` already does) because the file sat at exactly 599 lines against the 600 ceiling.

- **Still not shipped here** (tracked in **#612**). Phase 7 item (1), the **shared importer write helper** under `scripts/data-corrections/_shared/`: that directory does not exist in this repo — it is administration-repo work. Phase 7 item (3), a **restricted DB grant** for importers: an operator action. Also deferred: reconciliation still runs on write and on approval, not on a standalone approval of an already-written draft *edited later* — that residual is unchanged and remains the safe direction.

### Entity/review agreement invariant (#622–#625)

The three review join tables — `ndd_review_phenotype_connect`, `ndd_review_publication_join`, `ndd_review_variation_ontology_connect` — each record the owning entity **twice**: directly in their own `entity_id`, and indirectly through the entity that owns their `review_id`. Nothing enforced agreement, and production held 256 active rows where the two disagreed (206 of them on a primary, approved review) — a conserved off-by-one from a 2022 seeding script that resolved `review_id` against an older snapshot CSV than `ndd_entity_review` had been loaded from. Migrations `050`–`053` close it, and the invariant is now structural: **a write that sets `entity_id` to anything other than its review's entity is rejected by the database**, not merely discouraged.

- `050_variant_view_entity_agreement.sql` rebuilds `ndd_review_variant_connect_view` with the agreement join so the public variant browse agrees with the entity page (the SEO query was fixed in the same change).
- `051_entity_review_agreement_constraint.sql` creates the parent unique key `uq_entity_review_review_entity (review_id, entity_id)` on `ndd_entity_review` — the referencable pair the whole invariant rests on — then adds the composite FK `(review_id, entity_id)` on the phenotype and publication join tables. A composite FK, not a `CHECK` or a trigger: the rule *is* "this pair must exist on the parent", and only an FK states it declaratively and enforces it under concurrency. It deliberately **skips** the variation table, which still held the 256 violating rows at that point: `ADD FOREIGN KEY` against violating rows fails, and migrations run at API startup, so including it would have turned a data defect into a crash-looping API. Sequencing a constraint behind its data repair is the pattern to copy, not an oversight.
- `052_variation_review_agreement_constraint.sql` completes the invariant on the variation table once those rows were repaired.
- `053_fix_variation_agreement_constraint_guard.sql` applies what `052` **silently skipped**. Its guard tested `@parent_key_exists = 1` against `information_schema.STATISTICS` for `uq_entity_review_review_entity` — but **STATISTICS holds one row per index COLUMN**, and that index has two (`review_id`, `entity_id`), so the count was 2, the condition was false, and the `ALTER` never ran while the migration was still recorded as applied. Any existence guard reading STATISTICS must count `DISTINCT INDEX_NAME` or compare against the real column count; a guard that fails closed-but-silent is worse than no guard, because it leaves the manifest asserting an invariant the database does not hold.


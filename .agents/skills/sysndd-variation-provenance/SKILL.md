---
name: sysndd-variation-provenance
description: Use when touching variation-ontology annotations, their provenance/assertion state, the curation suggestion queue, review writes that resubmit variation or phenotype terms, entity rename carry-forward, or the entity/review agreement invariant — anywhere a machine-derived annotation could be silently presented as curator-authored
---

# SysNDD Variation-Ontology Provenance (#608 / #612)

Read this before changing anything that writes variation-ontology terms, reads their provenance, or renames an entity. The feature exists to stop one specific failure: **a machine-derived annotation being presented as curator-authored**. Almost every trap here is a way of reintroducing that.

## Non-negotiables

- **Absence of an assertion row means curator-authored.** With zero assertion rows the feature is inert and the public card renders exactly as it did pre-#608. This also means provenance means nothing until the backfill (companion `sysndd-administration` repo) completes — a *partial* backfill is worse than none.
- **Identity is `(entity_id, vario_id, modifier_id)`** — never `(entity_id, vario_id)`. "Missense present" and "missense absent" are two independent claims. The comparison is case-normalized on both sides.
- **Provenance is NOT a column on `ndd_review_variation_ontology_connect`.** Every review edit is a DELETE-then-INSERT of that table, so a column there is destroyed on every save.
- **Correctness is server-side, never client-side.** Four frontend surfaces prefill and resubmit variation terms; a design that trusts one new UI to send the right signal leaves the others laundering. Never reintroduce a client-sent rejected-terms array — omission from the submitted set *is* the rejection.
- **Only `functions/ontology-repository.R` may write the connect table**, and only through `review_write_mutate()`. Enforced by `test-unit-variation-connect-write-guard.R`.
- **Confirm vs dismiss are asymmetric**, and that asymmetry is the safety design: `active_unconfirmed` is served (safe action: confirm), `suggested` is not (safe action: dismiss). Writing `rejected` onto a served assertion drops it out of the public filter while the term is still served — i.e. it renders as curator-authored.
- **No `tryCatch` around the provenance read.** A swallowed failure renders every term as `provenance: null`.

## Verify

`test-unit-variation-connect-write-guard.R`, `test-unit-evidence-origin-review.R`, `test-integration-variation-suggestions.R` (must run against a real schema — two bugs here were invisible to mocked tests), `EntityEvidenceGridProvenance.spec.ts`.

## Deep reference

Authoritative detail, extracted from `AGENTS.md`:

- `references/provenance-608.md` — the state machine, rejection scope, rename carry-forward, read surface, `origin_review_id`, module load order.
- `references/evidence-json-contract.md` — the three record shapes, optional-key dropping, the meaningful `false`, MySQL key-order normalization.
- `references/approval-queue-and-agreement.md` — approval-path rejection, the curation queue, the four zone-picker surfaces, the entity/review agreement invariant (#622–#625).

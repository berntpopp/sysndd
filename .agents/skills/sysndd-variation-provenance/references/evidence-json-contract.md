# The evidence_json record-shape contract (#612)

> Extracted verbatim from `AGENTS.md` (2026-09-01) to keep the root instruction file lean.
> This is the authoritative detail for this subsystem.

The backfill emits **three** record shapes under `records`, and the pre-#612 dialog understood one — the external-database batch rendered `consequence` alone and the literature batch rendered **nothing**, because a record carrying none of the probed keys is filtered out. That failure is silent by design (an unrecognised key is omitted rather than guessed at), so the shapes are pinned by `api/tests/testthat/fixtures/variation-evidence-record-shapes.json`, which drives the R suite, the TypeScript suite, and the writer in `sysndd-administration` (admin#16).

| `source_key` | `source_type` | Containers | Record keys |
|---|---|---|---|
| `clinvar` | `external_database` | `records`, `matched` | `id`, `classification`, `stars`, `consequence`, `url` |
| `extdb2` | `external_database` | `records` | `confidence`, `mechanism`, `categorisation`, `consequence`, `support`, `disease`, `allelic_requirement`, `layer` |
| `synopsis` | `literature` | `records` | `matched_text`, `negated`, `pattern`, `context` |

Four properties the reader must honour, each with a failure mode:

* **Optional keys are DROPPED, not written null**, so a record legitimately carries a subset of its shape's keys.
* **`matched` holds STRINGS** (OMIM CURIEs), never records. It must stay a separate text list and must never enter the record-container probe — `String(object)` renders `"[object Object]"`.
* **`negated` is a BOOLEAN and the only field whose FALSE value is meaningful.** A negated literature match is evidence AGAINST the term (the importer scores it 1 instead of 3), and it arrives as `[false]` — which `asText()` renders as the string `"false"` and a truthiness test reads as `true`. `asBoolean()` in `app/src/views/pages/components/variationWireScalars.ts` exists for exactly this; `null` means NOT RECORDED, never "not negated".
* **Key ORDER in the fixture is MySQL's, not the writer's.** `provenance_builder.py` writes with `sort_keys=True`, but a MySQL JSON column normalizes object keys by **length first, then lexicographically**, so the text read back differs from the text inserted. The fixture stores the captured production read order and asserts `stored_json` → `wire_sample` end to end.

`normalizeEvidenceRecordList()` (`variationEvidenceRecords.ts`) dispatches on `source_key` then `source_type`, and falls back to the pre-#612 generic probe for an unrecognised source so a future batch degrades to the old behaviour rather than to nothing. `variationWireScalars.ts` holds the shared scalar primitives specifically so `variationProvenance.ts` and `variationEvidenceRecords.ts` do not import each other.


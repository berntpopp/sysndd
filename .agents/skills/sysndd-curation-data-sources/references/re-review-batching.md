# Re-review batching soft LIMIT

> Extracted verbatim from `AGENTS.md` (2026-09-01) to keep the root instruction file lean.
> This is the authoritative detail for these rules.

- `batch_preview()` and `batch_create()` in `api/services/re-review-service.R` use a **soft LIMIT** (gene-atomic): the returned entity count may exceed `batch_size` to keep all entities for a partially-included gene in the same batch. Callers that assumed strict LIMIT for sizing UI elements must read the response length, not the requested cap. The `boundary_gene` field on the preview response is non-null when the soft-LIMIT engaged.

# SysNDD MCP v1.1 — Correctness, Batching & Discoverability

**Date:** 2026-05-17
**Status:** Approved design — ready for implementation planning
**Worktree:** `.worktrees/read-only-mcp-api`
**Supersedes/extends:** `2026-05-17-sysndd-mcp-llm-ergonomics-design.md`, `2026-05-17-sysndd-mcp-payload-discoverability-design.md`

## Context

Five independent LLM-consumer reviews of the SysNDD MCP scored it ~8.5/10 overall.
Cross-checking every finding against the implementation (`api/services/mcp-service.R`,
`api/services/mcp-tools.R`, `api/functions/mcp-repository.R`) showed most reviewer
complaints were already solved or were deliberate v1 scope decisions. Three findings
survived scrutiny as real work:

1. A **publication-date data-integrity bug** — root-caused below.
2. **No multi-gene batching** for comparison-style questions.
3. **Discoverability/documentation gaps** in `get_sysndd_capabilities` and tool descriptions.

This spec covers all three across four tracks. Track A is a core-API fix; Tracks B–D
are in the MCP worktree.

## Finding: `pubmed_publication_date` is corrupt at the source

### Root cause

`api/functions/publication-functions.R:309-315`, inside `parse_pubmed_fetch_xml()`:

```r
year  <- date_part(article, "Year")
month <- date_part(article, "Month")
day   <- date_part(article, "Day")
if (is.na(year) || is.na(month) || is.na(day)) {
  year  <- format(Sys.time(), "%Y")   # entire date replaced with ingestion date
  month <- format(Sys.time(), "%m")
  day   <- format(Sys.time(), "%d")
}
```

PubMed's `<Article>/<Journal>/<JournalIssue>/<PubDate>` routinely omits `<Day>` (and
sometimes `<Month>`; some records carry only `<Year>` or a `<MedlineDate>` string such
as `"2013 Jun-Jul"`). When **any single** part is missing, the parser discards the real
year and month and substitutes `Sys.time()` — the ingestion timestamp.

### Database evidence (live dev DB, `sysndd_db`)

| Check | Result |
|---|---|
| `publication` rows total | 4,689 |
| `DATE(Publication_date) = DATE(update_date)` (ingest timestamp) | **2,335 (~50%)** |
| Distinct linked publications affected | 1,853 of 4,526 (~41%) |
| PMID:23746550 — real PubMed date `2013-06-08` | stored `2024-12-08` = `update_date 2024-12-08 11:46:03` |
| PMID:28851564 — real `2017` | stored `2023-07-03` = `update_date` |
| PMID:24864036 — real `2014` | stored `2022-11-08` = `update_date` |
| PMID:30455931 — real `2018` | stored `2020-10-01` |
| `YEAR(Publication_date)` distribution | peaks 2023/2022/2024 — SysNDD curation window, not NDD-genetics publication history |

The corruption is wholesale: even rows whose fabricated date does not equal `update_date`
(e.g. PMID:30455931) are still not the real PubMed date.

### Why the MCP's existing guard is insufficient

`mcp_publication_date_quality()` (`mcp-service.R:208-226`) marks `confidence: "low"` only
when the date coincides with a *linked primary-approved review date*. That detects ~41%
of corrupt rows. The remaining ~half are emitted as `confidence: "publication_table"`
("trustworthy") under a field literally named `pubmed_publication_date`, and the bad date
is concatenated into `recommended_citation`. The MCP currently asserts false confidence
on roughly half of all publication dates.

### Constraint

MCP v1 must not call external providers (AGENTS.md). The MCP cannot re-fetch correct
dates itself — the fix must happen in the core API, and the MCP must be honest until it
does.

## Finding: MCP prompts are spec-correct; reviewer scores reflect a misunderstanding

The [MCP specification](https://modelcontextprotocol.io/specification/2025-06-18/server/prompts)
defines prompts as **user-controlled**: hosts surface them as slash commands / menu items;
they are deliberately not model-invocable (tools are the model-controlled primitive).
Reviewers scored prompts 2–5/10 because, as tool-calling clients, they could not invoke
them — this is expected, spec-correct behavior, not a defect. The SysNDD prompt
implementation (`prompts/list`, `prompts/get`, `-32602` errors, `listChanged:false`) is
compliant. **No prompt code changes; documentation only** (Track D).

## Goals

- Correct publication-date data at the source and present it honestly in the MCP.
- Collapse multi-gene comparison questions into one MCP call.
- Close documentation gaps so consumers self-serve workflows, costs, and error handling.

## Non-goals (out of scope)

Parameterized RFC-6570 resource templates (AGENTS.md: v1 record URIs are identifiers, not
resources); opaque pagination cursors; HPO-hierarchy phenotype restructuring; incremental
abstract paging; multi-value `search_sysndd`; deduplicating `ndd_phenotype` (1/0) vs
`ndd_phenotype_word` (documented only). All deferred as YAGNI or contractually excluded.

---

## Track A — Core API: publication-date integrity

Outside the MCP worktree conceptually (it touches `api/functions/` and `db/`), but
delivered in this effort.

### A1. Fix the date parser

`parse_pubmed_fetch_xml()` in `api/functions/publication-functions.R`. Replace the
all-or-nothing fallback:

- `<Day>` missing → `"01"`.
- `<Month>` missing → `"01"` (after attempting numeric/season-name normalization).
- `<Year>` present → build `year-month-day`; record provenance `pubmed` (all parts
  present) or `pubmed_partial` (day and/or month defaulted).
- `<Year>` missing → attempt `<PubDate>/<MedlineDate>` (parse leading 4-digit year, and
  month token if present); provenance `medline_date`.
- Nothing parseable → `Publication_date` is `NA`/`NULL` (column is `NULL DEFAULT NULL`);
  provenance `unknown`. Never substitute `Sys.time()`.

`info_from_pmid()` must carry the new provenance value through to the insert path.

### A2. Provenance column

A `db/migrations/*.sql` migration adds `publication.publication_date_source`
(`varchar`, nullable) with values `pubmed` | `pubmed_partial` | `medline_date` |
`unknown`. New ingestions set it via A1. Existing rows remain `NULL` until A3 runs.
This converts the MCP's date-confidence signal from a heuristic into a stored fact.

### A3. One-off backfill script

A standalone R script under `db/updates/` (operator-run, not a startup migration —
it needs PubMed network egress):

- Selects all PMIDs on `publication` linked to primary-approved reviews (~4,700).
- Re-fetches via existing `pubmed_fetch_xml()` in chunks of 200 (~24 calls).
- Recomputes the date with the A1 logic.
- `UPDATE`s `Publication_date` and `publication_date_source` **only** — Title, Abstract,
  Journal, authors untouched, to minimize blast radius.
- Supports a dry-run mode that reports how many rows would change without writing.
- Logs per-PMID before/after for audit.

Documented as an operator step in `documentation/08-development.qmd` /
`documentation/09-deployment.qmd`.

## Track B — MCP: honest publication-date presentation

`api/services/mcp-service.R`, `api/services/mcp-tools.R`.

- Bump `MCP_SCHEMA_VERSION` to `"1.1"`.
- Rename the publication-record output field `pubmed_publication_date` →
  `publication_date_sysndd_record`. Update `mcp_publication_record()`,
  `mcp_get_publication_context()` `date_notes`, the citation contract, and all tests.
- Rework `mcp_publication_date_quality()`:
  - When `publication.publication_date_source` is available (post-A2), surface it as
    `publication_date_confidence` ∈ `{pubmed_verified, pubmed_partial, unverified,
    matches_curation_date}` (`pubmed` source → `pubmed_verified`).
  - When the column is `NULL` (pre-backfill), keep the current heuristic but default to
    `unverified` instead of `publication_table`, and still escalate to
    `matches_curation_date` on coincidence.
  - `mcp_repo_get_entity_publications()` and `mcp_repo_get_publication_context()` add
    `p.publication_date_source` to their `SELECT`s.
- `recommended_citation` (`mcp_recommended_citation()`): include the date only when
  confidence is `pubmed_verified` or `pubmed_partial`; otherwise append
  `(publication date unverified)` and omit the raw value from the citation string.
- Keep `pubmed_publication_date_matches_curation_date` as a boolean (renamed
  `publication_date_matches_curation_date`) — still useful signal.
- `date_notes` text explains the field plainly for the model.

## Track C — MCP: multi-gene batch context

New tool `get_genes_context`, mirroring the proven `get_entities_context` shape.

- **Input:** `genes` (array, 1–10 identifiers) plus the existing `get_gene_context`
  payload params (`include_entities`, `include_comparisons`, `entity_limit`,
  `response_mode`, `synopsis_mode`, `expand`, `include_publications`,
  `include_phenotypes`, `include_variants`, `publication_limit`, `abstract_mode`,
  `dedupe_publications`).
- **Behavior:** calls `mcp_get_gene_context()` per gene; preserves request order; a
  per-gene `not_found` or `ambiguous_query` becomes a per-gene error object and does not
  fail the call.
- **Output:** `{schema_version, genes: [...], publications: [...], meta: {...}}`. When
  `expand=entities` and `dedupe_publications=true`, publications are deduplicated to the
  top level across all genes (reuse the `get_entities_context` dedup logic); each gene
  keeps `publication_refs`.
- **`meta`:** `requested`, `returned`, `errors`, `max_genes`, echoed payload modes,
  `publication_shape`, `publication_count`.
- **Limits:** `max_genes = 10`. Tool description carries an inline example and a note
  that `expand=entities` on a large batch is token-heavy.
- Registered in `mcp_build_tool_registry()` with read-only annotations and an output
  schema, exactly like the other tools.

Multi-value `search_sysndd` is **not** added (deferred non-goal).

## Track D — MCP: `get_sysndd_capabilities` & docs hardening

`mcp_get_sysndd_capabilities()` and tool descriptions in `mcp-tools.R`.

1. **Fix the misleading example.** `payload_modes$gene_expand_example` uses
   `abstract_mode = "excerpt"`; add an explicit statement that abstracts ride along
   `expand=entities` so the canonical gene summary is a 2-call (search + expand) path.
2. **Worked error envelopes.** New `error_examples` block: one example payload per code
   (`invalid_input` with `expected_arguments`/`hint`; `not_found`; `ambiguous_query`
   showing the `choices` array; `temporarily_unavailable`).
3. **Prompts.** Replace the bare name list with objects carrying `arguments`, plus a
   `note`: "Prompts are user-controlled per the MCP spec; hosts surface them as slash
   commands / menu items, not as model-callable tools."
4. **Performance profile.** New `performance` block: per-tool cache TTL (from
   `MCP_CACHE_TTLS`) and a cost tier (`cheap` | `moderate` | `expensive`).
5. **Mode precedence.** New `mode_resolution` note: `response_mode` only *derives
   defaults* for `abstract_mode` and `synopsis_mode`; an explicit mode argument always
   wins; `meta` echoes the effective values.
6. **Category values.** New `entity_categories` block documenting returned values
   including `"not applicable"` (non-NDD / outside curation scope) and noting the filter
   enum (`Definitive/Moderate/Limited/Refuted`) differs from the returned set.
7. **Register `get_genes_context`** in `canonical_workflows` (a `gene_comparison`
   workflow) and `limits`.
8. Update the `sysndd://schema/tool-guide` resource (`config/mcp/resources/`) to match.

## Testing strategy

- **Track A:** new `testthat` unit tests for the date parser — missing day, missing
  month, `MedlineDate`-only, missing year → `NULL`, all-parts-present; provenance value
  asserted for each. Backfill script tested via dry-run against fixtures.
- **Track B:** extend `test-mcp-service.R` — field rename, confidence states from the
  provenance column and from the fallback heuristic, citation date suppression.
- **Track C:** new `test-mcp-service.R` / `test-mcp-tools.R` cases — batch happy path,
  per-gene errors, cross-gene dedup, `max_genes` enforcement, registry/output-schema
  presence. `mcp-smoke.R` exercises `get_genes_context`.
- **Track D:** `test-mcp-tools.R` assertions on the new capabilities blocks.
- Gates: `make test-api`, `make lint-api`, `mcp-smoke.R`.

## Parallelization notes

Tracks are largely independent and suited to parallel agents:

- **Track A** (core API: `publication-functions.R`, migration, backfill) — independent;
  only shares the `publication_date_source` column contract with Track B.
- **Track B** depends on the A2 column *name/values* contract but not on A1/A3 landing —
  it can be built against the agreed enum and falls back gracefully when the column is
  `NULL`. Sequence A2's column definition first, then B and the rest of A run in
  parallel.
- **Track C** (`get_genes_context`) — fully independent of A and B.
- **Track D** (capabilities/docs) — independent except item 7 (`get_genes_context`
  registration) depends on Track C's tool name; the capabilities text can be drafted in
  parallel and the registration line merged last.

Recommended waves: **Wave 1** — A2 column contract (tiny, unblocks B). **Wave 2** —
A1+A3, B, C, D items 1–6/8 all in parallel. **Wave 3** — D item 7 + integration smoke +
docs.

## Documentation contract

- `AGENTS.md` — MCP sidecar section: new `get_genes_context` tool, `publication_date_*`
  field rename, `schema_version` 1.1, `publication_date_source` column.
- `config/mcp/resources/sysndd-schema.md` — tool guide refresh.
- `documentation/08-development.qmd` — backfill operator step, parser fix note.
- `documentation/09-deployment.qmd` — backfill as an operator/deployment step.

## Risks

- **Backfill PubMed rate limits.** Chunked fetches reuse the existing
  `pubmed_fetch_xml()` throttling; dry-run first; idempotent (re-runnable).
- **Schema-version bump.** `1.0 → 1.1` with a renamed field is a breaking change for any
  pinned consumer; acceptable pre-GA, and `schema_version` exists precisely to signal it.
- **`MedlineDate` parsing variety.** Many free-text formats; parse conservatively
  (leading year, optional month token), fall back to `pubmed_partial`/`unknown` rather
  than guessing.

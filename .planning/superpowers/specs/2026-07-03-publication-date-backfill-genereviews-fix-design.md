# Design: Fix `publication_date_backfill` for GeneReviews + wire NCBI key into containers

**Date:** 2026-07-03
**Issues:** #499, #500 (follow-ons to #494 / #496 / #489 / #460)
**Status:** Approved (brainstorm) → ready for implementation plan
**Target release:** v0.27.3 (patch)

---

## 1. Context

The `publication_date_backfill` job re-fetches PubMed metadata for publications linked to a
primary-approved review whose `publication.publication_date_source` is NULL/invalid, and writes a
verified `Publication_date` + `publication_date_source`. This powers the MCP
`publication_date_confidence` flag (`pubmed_verified` / `pubmed_partial` / `unverified`).

The `#494` saga chased a "all N targeted PMIDs failed (systemic outage)" failure. `#494`/`#496`
correctly added an NCBI API key path (`pubmed_eutils_query()`) to raise the EUtils rate cap.
But the job **still fails in prod at v0.27.2**. Two independent, prod-root-caused defects remain:

- **#499** — the API key never reaches the containers (compose wiring gap).
- **#500** — even with the key present, GeneReviews **book records** can't be parsed, so ~393 of
  ~553 unverified publications are permanently "unresolvable", and the fail-fast turns that into a
  whole-job systemic outage with 0 writes.

Both are needed for the backfill to work end-to-end. They touch disjoint files (compose/YAML vs.
R), so they ship as one release with two focused commits.

---

## 2. Root-cause analysis (validated against code)

### #499 — key never reaches containers
`docker-compose.yml` uses explicit `environment:` maps (not `env_file`). The three services that
egress to NCBI map `GEMINI_API_KEY: ${GEMINI_API_KEY:-}` but **no `NCBI_*`**:

- `api` — `environment:` L161–184 (interactive `check_pmid`/`info_from_pmid` on entity creation)
- `worker` — L275–294 (dev override drains both lanes, so it runs the backfill locally)
- `worker-maintenance` — L376–392 (runs `publication_date_backfill` in prod)

`.env.example` already documents `NCBI_API_KEY` / `NCBI_EUTILS_EMAIL` (L94–96). Only the compose
wiring is missing. Because compose **merges** `environment:` maps across override files, adding the
two keys to the base file is sufficient for dev, playwright, and prod.

`pubtatornidd-cron` is intentionally **excluded**: it is attached to the `backend` (internal,
no-egress) network only and runs a DB-only enqueue (`scripts/pubtatornidd_nightly_enqueue.R`); the
*worker* makes that job's NCBI calls, not the sidecar. The var would be inert there.

### #500 — GeneReviews book records can't resolve
1. **Parser gap.** `table_articles_from_xml()` (`api/functions/publication-functions.R` L352) does
   `xml_find_all(xml, "//PubmedArticle")`. EFetch returns GeneReviews chapters as
   `<PubmedBookArticle>/<BookDocument>`, which this ignores → 0 rows.
2. **Fail-fast amplification.** `info_from_pmid()` (L526–537) aborts with
   `publication_fetch_error` on *any* unresolved PMID. In the backfill this becomes a per-PMID
   `record_skip`; the systemic-outage guard fires when `skipped_count >= targeted`
   (`publication-date-backfill.R` L229). After the ~160 non-book targets get verified in an early
   run, the target set becomes *only* the 393 unresolvable book records → **every subsequent run
   is 100% skipped → "systemic outage", 0 writes, forever.** This precisely matches the prod
   symptom.

Verified subtleties:
- The backfill calls `info_from_pmid()` **uniformly** — it does *not* use the GeneReviews
  HTML-scraper path (`info_from_genereviews_pmid`, used only at entity creation). So fixing the
  shared PubMed-XML parser is the correct, general fix.
- EFetch on `db=pubmed` genuinely returns a usable date for book records (confirmed by the real
  fixture in the sibling `genereviews-link` project).

### Cross-project comparison (`../genereviews-link`)
The sibling MCP server has a **proven** `_parse_book_article()`
(`genereview_link/api/eutils_client.py` L461–543) and a **real** book-article fixture
(`tests/fixtures/efetch/NBK1247_book_article.xml`, PMID 20301425). Two findings changed this
design:

- **Date source.** The real record has **no** `PubmedBookData/History/PubMedPubDate` — only
  `<ContributionDate>1998-09-04</ContributionDate>` and `<Book><PubDate><Year>1993</Year></PubDate>`.
  The issue suggested `PubMedPubDate[@PubStatus='pubmed']`; the sibling keys on **`ContributionDate`
  first** (the chapter's real authored/revision date — a full, verified Y/M/D) and falls back to
  `Book/PubDate`. `ContributionDate` is the semantically correct "publication date" for a
  GeneReviews chapter, and it is present when `PubMedPubDate` is not.
- **Author list.** Book records carry multiple `AuthorList`s (authors vs editors); the sibling
  selects `AuthorList[@Type='authors']`. The article parser's `AuthorList/Author[1]` would grab the
  wrong list for books.

---

## 3. Goals / non-goals

**Goals**
- G1. `NCBI_API_KEY` / `NCBI_EUTILS_EMAIL` from `.env` reach `api`, `worker`, `worker-maintenance`.
- G2. GeneReviews `<PubmedBookArticle>` records parse to a verified date via the shared PubMed-XML
  parser, using the existing `pubmed` / `pubmed_partial` source vocabulary.
- G3. The backfill distinguishes a **data** condition (parse-empty / genuinely unresolvable PMID →
  `unresolved`, non-fatal) from an **infra** condition (transport/HTTP/timeout → `failed`), and
  fires the systemic-outage guard **only** on infra failure. Everything that resolves is persisted.
- G4. Regression tests lock all three; docs + CHANGELOG + version bump updated.

**Non-goals (YAGNI)**
- No new `publication_date_source` value (e.g. `pubmed_book`) — reuse `pubmed`/`pubmed_partial` so
  the target query, MCP confidence flag, and admin surfaces need no change.
- No change to `info_from_pmid()`'s strict abort — entity-creation semantics
  (`new_publication` / `fetch_one`) stay strict.
- No re-plumbing of the entity-creation GeneReviews path (`info_from_genereviews_pmid`).
- No `docker-compose.prod.yml` / external deploy templates in-repo (they live outside this repo;
  `.env.example` already documents the keys).

---

## 4. Design

### 4.1 #499 — compose wiring
Add to the `environment:` block of `api`, `worker`, and `worker-maintenance`, mirroring
`GEMINI_API_KEY`:

```yaml
      NCBI_API_KEY: ${NCBI_API_KEY:-}
      NCBI_EUTILS_EMAIL: ${NCBI_EUTILS_EMAIL:-}
```

Placed next to `GEMINI_API_KEY` in each block for discoverability, with a one-line comment
explaining the EUtils rate-limit purpose and pointing at #494/#499. No override-file changes (env
maps merge). No `.env.example` change (already present).

### 4.2 #500 part 1 — PubMed book-record parser

**Module structure.** Extract the cohesive PubMed-XML-parsing concern out of the 550-line
`publication-functions.R` into a new focused module `api/functions/pubmed-xml-parser.R`:

- Move: `empty_pubmed_article_tibble()`, `resolve_pubmed_date()`, `table_articles_from_xml()`,
  `parse_pubmed_fetch_xml()`.
- Add: `table_book_articles_from_xml()` (new) and a small combiner.
- `publication-functions.R` gains a guarded `source("functions/pubmed-xml-parser.R", local = TRUE)`
  at top (mirroring the existing `genereviews-functions.R` guard, L4–9), so both the bootstrap and
  the direct-source unit tests resolve it.
- Register `"functions/pubmed-xml-parser.R"` in `bootstrap_load_modules()`
  (`api/bootstrap/load_modules.R`) **before** `"functions/publication-functions.R"` (L93). This
  single list update covers both the API and the async worker entrypoints.

Rationale: inlining ~60 lines would push `publication-functions.R` past the 600-line soft ceiling
and require a baseline allowlist entry (the ratchet-up AGENTS.md discourages). Extraction keeps it
under ceiling (~350 lines fetch/DB/orchestration) and gives the new code a clean, testable home.

**Combiner.** `parse_pubmed_fetch_xml()` reads the XML once and unions both node sets:

```r
parse_pubmed_fetch_xml <- function(pubmed_xml_data) {
  articles <- tryCatch(table_articles_from_xml(pubmed_xml_data),
                       error = function(e) empty_pubmed_article_tibble())
  books    <- tryCatch(table_book_articles_from_xml(pubmed_xml_data),
                       error = function(e) empty_pubmed_article_tibble())
  parsed <- dplyr::bind_rows(articles, books)
  if (nrow(parsed) == 0L || all(is.na(parsed$pmid))) return(empty_pubmed_article_tibble())
  parsed
}
```

(A mixed EFetch batch returns `<PubmedArticleSet>` with both `<PubmedArticle>` and
`<PubmedBookArticle>` siblings; `//PubmedArticle` and `//PubmedBookArticle` are disjoint, so no
double-count.)

**`table_book_articles_from_xml()`** — one row per `//PubmedBookArticle`, same output schema as the
article parser:

- **pmid**: `.//BookDocument/PMID`
- **date**: ladder, first present wins, then `resolve_pubmed_date()`:
  1. `.//BookDocument/ContributionDate/{Year,Month,Day}`
  2. `.//PubmedBookData/History/PubMedPubDate[@PubStatus='pubmed' or @Pubstatus='pubmed']/{Year,Month,Day}`
  3. `.//BookDocument/Book/PubDate/{Year,Month,Day}` (often year-only → `pubmed_partial`)
  → `date_source` ∈ {`pubmed`, `pubmed_partial`, `unknown`} from the existing resolver.
- **title**: `.//BookDocument/ArticleTitle` → `.//BookDocument/BookTitle` → `.//Book/BookTitle`
- **journal / jabbrv**: `.//Book/BookTitle` (default `"GeneReviews"`); `jabbrv` = same or `""`
- **abstract**: concatenated `.//Abstract/AbstractText` (consistent with the article path)
- **author**: `.//AuthorList[@Type='authors']/Author[1]/{LastName,ForeName}` (falls back to first
  `AuthorList` if no typed list); `CollectiveName` handling mirrors the article path
- **doi**: `NA_character_` → `""` (books have none; the backfill ignores this column anyway)
- **keywords / address**: `""` unless trivially present

Both parsers share small text helpers (`text_first` / `text_all`) — lift them to module scope in
`pubmed-xml-parser.R` so both use one copy (DRY).

### 4.3 #500 part 2 — backfill resilience

In `backfill_publication_dates_run()` (`api/functions/publication-date-backfill.R`), split the
single `skipped` bucket into two by the *class* of the caught condition:

- `publication_fetch_error` (parse-empty / genuinely unresolvable after a clean fetch) → **`unresolved`**
- any other `error` (transport/HTTP/timeout/`info_from_pmid` unavailable) → **`failed`**

```r
record_unresolved <- function(pid, e) { unresolved_ids <<- c(unresolved_ids, pid); ... ; tibble::tibble() }
record_failed     <- function(pid, e) { failed_ids     <<- c(failed_ids, pid);     ... ; tibble::tibble() }

fetch_one <- function(publication_id) {
  on.exit(Sys.sleep(ncbi_delay), add = TRUE)
  tryCatch(
    { row <- info_from_pmid(publication_id); row$publication_id <- paste0("PMID:", ...); row },
    publication_fetch_error = function(e) record_unresolved(publication_id, e),
    error                   = function(e) record_failed(publication_id, e)
  )
}
```

`fetch_chunk`'s fallback is unchanged in shape (a chunk-level `publication_fetch_error` still falls
back to per-PMID `fetch_one`, which now classifies each).

**Systemic-outage guard** fires only on infra failure:

```r
if (targeted > 0L && length(unique(failed_ids)) >= targeted) {
  stop(structure(class = c("publication_backfill_systemic_failure", "error", "condition"), ...))
}
```

So a target set that is *entirely* genuinely-unresolvable book/withdrawn PMIDs completes as a
**success with 0 verified and N unresolved** (observable, not a false failure), while a true NCBI
outage (every PMID transport-failed) still fails the job. Everything that resolved is written
(unchanged batched-commit path).

**Return summary** gains explicit `unresolved_count` / `failed_count` (+ capped id/error samples).
`unresolved` (the derived counter) already exists; keep `verified + partial + unresolved == targeted`
consistent. The async handler already surfaces the summary in `result_json`.

After part 1, the real workload's first run resolves book records (no abort) and writes them; part 2
guarantees the residual all-unresolvable case never mis-fires again.

---

## 5. Testing strategy

**Parser (`test-unit-publication-functions.R`, or a new `test-unit-pubmed-xml-parser.R`):**
- New helper `create_pubmed_book_xml(...)` modeled on the real `NBK1247_book_article.xml` shape.
- `table_book_articles_from_xml` extracts pmid, title, journal="GeneReviews", author from
  `Type='authors'`.
- Date ladder: (a) `ContributionDate` full → `date_source == "pubmed"`, date `1998-09-04`;
  (b) only `PubMedPubDate[@PubStatus='pubmed']` present → `pubmed`; (c) only `Book/PubDate/Year` →
  `pubmed_partial`; (d) none → `unknown`.
- **Mixed set**: one `<PubmedArticleSet>` with both a `<PubmedArticle>` and a `<PubmedBookArticle>`
  → `parse_pubmed_fetch_xml()` returns **both** rows (the core regression guard).
- Existing article tests keep passing unchanged (parser move is behavior-preserving).

**Backfill (`test-unit-publication-date-backfill.R`):**
- Extend the mocked-`info_from_pmid` tests: some PMIDs raise `publication_fetch_error`
  (→ `unresolved`, job **succeeds**, resolved rows written); the existing "every PMID errors"
  systemic test switches its stub to a generic `stop()` (→ `failed` → systemic failure preserved).
- New test: all-`publication_fetch_error` target set → success with `unresolved_count == targeted`,
  `written == 0`, **no** `publication_backfill_systemic_failure`.

**Compose (#499):** lightweight static guard test asserting `NCBI_API_KEY` /
`NCBI_EUTILS_EMAIL` appear in the `api` / `worker` / `worker-maintenance` environment blocks (grep
over `docker-compose.yml`), so the wiring can't silently regress. (Optional but cheap; decide during
planning.)

---

## 6. Verification

- `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"`
  (and the backfill + any new parser spec) on the host.
- `make test-api-fast` (fast PR gate) and `make code-quality-audit` (file-size ratchet — confirm
  `publication-functions.R` is now under ceiling and no new file is flagged).
- `docker compose config` renders the two keys under the three services (and, with a real
  `.env`, non-empty).
- End-to-end (operator, prod-like): set `NCBI_API_KEY` in the worker `.env`, restart
  `worker-maintenance`, run a `publication_date_backfill` — expect GeneReviews book PMIDs to move to
  `pubmed`/`pubmed_partial` and the job to complete `success` with a non-zero `verified`/`written`.

## 7. Docs & release

- **CHANGELOG.md**: new `## [0.27.3]` section, `Fixed`, closing #499 and #500 (each on its own
  `Closes` line — GitHub comma quirk).
- **AGENTS.md**: update the publication-ingestion bullet — note the shared PubMed-XML parser now
  handles `<PubmedBookArticle>` (GeneReviews, `ContributionDate`-first date ladder, reuse
  `pubmed`/`pubmed_partial`), the backfill's `unresolved` (data) vs `failed` (infra) split, and the
  requirement to wire `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` into the three egress services' compose
  `environment:` blocks. Mention the new `pubmed-xml-parser.R` module + its `load_modules.R`
  registration.
- **Version bump** to `0.27.3` in `app/package.json`, `api/version_spec.json`, and the CHANGELOG
  (the standard 3-file release bump).
- **Worker restart** called out in the release notes (worker-executed parser + backfill changed).

## 8. Decisions log

1. **Parser location** → extract `pubmed-xml-parser.R` (keeps `publication-functions.R` under the
   600 ceiling; no baseline ratchet-up).
2. **#499 services** → `api`, `worker`, `worker-maintenance` only; exclude the backend-only
   `pubtatornidd-cron` (no egress, DB-only enqueue).
3. **Packaging** → one PR / one release **v0.27.3**, two focused commits (YAML vs. R), closing both.
4. **Book date source** → `ContributionDate` → `PubMedPubDate[@PubStatus='pubmed']` → `Book/PubDate`
   ladder (comparison-informed; supersedes the issue's `PubMedPubDate`-only suggestion). Reuse
   `pubmed`/`pubmed_partial`; no new vocabulary.
5. **`info_from_pmid` strict abort** → unchanged; only the backfill's *interpretation* of the
   resulting condition changes (unresolved vs failed). Entity-creation stays strict.

## 9. Risks

- **Parser move regressions** — mitigated by keeping the moved functions byte-identical and running
  the full existing parser test suite (behavior-preserving move + additive book parser).
- **XML casing / namespace** — handle both `PubStatus`/`Pubstatus`; use relative `.//` xpaths within
  each node exactly like the article parser.
- **Date semantics** — `ContributionDate` reflects the chapter's initial/authored date (e.g. 1998),
  not a later PubMed re-index; this is the intended, more-meaningful "publication date" and is a
  strict improvement over the current `unverified`. Documented in the CHANGELOG.
- **Load order** — the new module must be registered before `publication-functions.R` in
  `load_modules.R` and guarded-sourced for the direct-source tests.

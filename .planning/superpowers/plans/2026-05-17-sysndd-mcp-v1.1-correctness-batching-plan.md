# SysNDD MCP v1.1 — Correctness, Batching & Discoverability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the corrupt publication-date data at its source, present it honestly in the MCP, add a multi-gene batch tool, and close `get_sysndd_capabilities` documentation gaps.

**Architecture:** Four tracks. Track A fixes the core-API PubMed date parser and backfills the `publication` table via a one-off script behind a new `publication_date_source` provenance column. Track B makes the MCP read that column and relabel its output honestly. Track C adds `get_genes_context` mirroring the existing `get_entities_context` batch tool. Track D rewrites `get_sysndd_capabilities` content. Tasks are grouped into three waves so independent tracks run in parallel.

**Tech Stack:** R (Plumber API, `xml2`, `purrr`, `dplyr`, `DBI`/`RMariaDB`), `testthat`, MySQL, `mcptools`/`ellmer` for the MCP sidecar.

**Worktree:** `.worktrees/read-only-mcp-api` — all paths below are relative to it.

**Spec:** `.planning/superpowers/specs/2026-05-17-sysndd-mcp-v1.1-correctness-batching-design.md`

---

## Wave / dependency map

| Wave | Tasks | Notes |
|------|-------|-------|
| 1 | Task 1 | Migration adds the `publication_date_source` column — unblocks Tasks 3 & 4. |
| 2 | Tasks 2, 4, 5, 6 | Run in parallel. Task 4 needs Task 1's column; Tasks 2/5/6 are fully independent. |
| 3 | Tasks 3, 7, 8 | Task 3 needs Task 2's `resolve_pubmed_date()`; Task 7 needs Task 5's tool name; Task 8 is final docs + smoke. |

## File structure

| File | Responsibility | Track |
|------|----------------|-------|
| `db/migrations/021_add_publication_date_source.sql` | **Create** — adds provenance column | A2 |
| `api/functions/publication-functions.R` | **Modify** — date parser + provenance | A1 |
| `api/tests/testthat/test-unit-publication-functions.R` | **Modify** — parser unit tests | A1 |
| `db/updates/backfill_publication_dates.R` | **Create** — one-off re-fetch/backfill | A3 |
| `api/functions/mcp-repository.R` | **Modify** — add `publication_date_source` to SELECTs | B |
| `api/services/mcp-service.R` | **Modify** — date quality, field rename, citation, batch genes, capabilities | B, C, D |
| `api/services/mcp-tools.R` | **Modify** — register `get_genes_context` | C |
| `config/mcp/resources/sysndd-schema.md` | **Modify** — tool-guide refresh | D |
| `api/tests/testthat/test-mcp-service.R` | **Modify** — Track B/C/D service tests | B, C, D |
| `api/tests/testthat/test-mcp-tools.R` | **Modify** — registry/capabilities tests | C, D |
| `api/scripts/mcp-smoke.R` | **Modify** — exercise `get_genes_context` | C |
| `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd` | **Modify** — docs contract | A, B, C |

## Conventions

- Run R tests from `api/`: `cd api && Rscript -e "testthat::test_file('tests/testthat/<file>')"`.
- Use `dplyr::` / `xml2::` namespaces explicitly (packages mask base verbs — see AGENTS.md).
- Commit after each task with a `feat:`/`fix:`/`docs:`/`test:` prefix.
- The MCP sidecar bind-mounts `api/services` and `api/functions`; restart `sysndd-mcp-1` to see changes live. `api/tests/` is **not** mounted.

---

## Task 1 — A2: `publication_date_source` provenance column [WAVE 1]

**Files:**
- Create: `db/migrations/021_add_publication_date_source.sql`

- [ ] **Step 1: Write the migration**

Create `db/migrations/021_add_publication_date_source.sql`:

```sql
-- 021_add_publication_date_source.sql
-- Adds provenance for publication.Publication_date so the MCP can report
-- date confidence as a stored fact instead of a heuristic.
-- Values: 'pubmed' (full structured PubDate), 'pubmed_partial' (day/month
-- defaulted), 'medline_date' (parsed from <MedlineDate>), 'unknown' (no
-- parseable date). NULL on legacy rows until the backfill script runs.

ALTER TABLE `publication`
  ADD COLUMN `publication_date_source` VARCHAR(20) NULL DEFAULT NULL
  AFTER `Publication_date`;
```

- [ ] **Step 2: Apply and verify the migration**

The migration runner applies `db/migrations/*.sql` at API startup. Apply it directly to the dev DB to verify:

Run:
```bash
docker exec sysndd-api-1 Rscript -e 'con <- DBI::dbConnect(RMariaDB::MariaDB(), host="mysql", port=3306, dbname="sysndd_db", user="bernt", password="changeme"); DBI::dbExecute(con, readLines("/app/../db/migrations/021_add_publication_date_source.sql") |> paste(collapse="\n") |> sub("^--.*$", "", x=_)); print(DBI::dbGetQuery(con, "SHOW COLUMNS FROM publication LIKE \"publication_date_source\"")); DBI::dbDisconnect(con)'
```
If the path is awkward, instead run the `ALTER TABLE` statement directly:
```bash
docker exec sysndd-api-1 Rscript -e 'con <- DBI::dbConnect(RMariaDB::MariaDB(), host="mysql", port=3306, dbname="sysndd_db", user="bernt", password="changeme"); try(DBI::dbExecute(con, "ALTER TABLE publication ADD COLUMN publication_date_source VARCHAR(20) NULL DEFAULT NULL AFTER Publication_date")); print(DBI::dbGetQuery(con, "SHOW COLUMNS FROM publication LIKE \"publication_date_source\"")); DBI::dbDisconnect(con)'
```
Expected: one row showing `publication_date_source | varchar(20) | YES | | NULL`.

- [ ] **Step 3: Commit**

```bash
git add db/migrations/021_add_publication_date_source.sql
git commit -m "feat: add publication_date_source provenance column"
```

---

## Task 2 — A1: fix the PubMed date parser [WAVE 2]

**Files:**
- Modify: `api/functions/publication-functions.R` (`empty_pubmed_article_tibble` ~109, `table_articles_from_xml` ~250-338, `info_from_pmid` ~349-440)
- Test: `api/tests/testthat/test-unit-publication-functions.R`

**Context:** The current parser (`table_articles_from_xml`, `if (is.na(year) || is.na(month) || is.na(day))`) replaces the entire date with `Sys.time()` when *any* part is missing. PubMed routinely omits `<Day>`. The fix defaults missing day/month instead of discarding year, parses `<MedlineDate>`, and records provenance. `info_from_pmid` then carries `publication_date_source` to the dynamic `INSERT INTO publication` (which auto-includes any column present in the tibble — so the new DB column from Task 1 is required).

- [ ] **Step 1: Write the failing test**

Add to `api/tests/testthat/test-unit-publication-functions.R` (append at end of file):

```r
test_that("resolve_pubmed_date defaults missing day and month, not the year", {
  full <- resolve_pubmed_date("2013", "06", "08")
  expect_equal(full$year, "2013")
  expect_equal(full$month, "06")
  expect_equal(full$day, "08")
  expect_equal(full$date_source, "pubmed")

  no_day <- resolve_pubmed_date("2013", "Jun", NA_character_)
  expect_equal(no_day$year, "2013")
  expect_equal(no_day$month, "06")
  expect_equal(no_day$day, "01")
  expect_equal(no_day$date_source, "pubmed_partial")

  no_month <- resolve_pubmed_date("2017", NA_character_, NA_character_)
  expect_equal(no_month$year, "2017")
  expect_equal(no_month$month, "01")
  expect_equal(no_month$day, "01")
  expect_equal(no_month$date_source, "pubmed_partial")
})

test_that("resolve_pubmed_date parses MedlineDate and reports unknown", {
  medline <- resolve_pubmed_date(NA_character_, NA_character_, NA_character_,
                                 medline_date = "2013 Jun-Jul")
  expect_equal(medline$year, "2013")
  expect_equal(medline$month, "06")
  expect_equal(medline$day, "01")
  expect_equal(medline$date_source, "medline_date")

  unknown <- resolve_pubmed_date(NA_character_, NA_character_, NA_character_)
  expect_true(is.na(unknown$year))
  expect_equal(unknown$date_source, "unknown")
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"`
Expected: FAIL — `could not find function "resolve_pubmed_date"`.

- [ ] **Step 3: Add the `resolve_pubmed_date` helper**

In `api/functions/publication-functions.R`, insert this function immediately **before** `table_articles_from_xml <- function(` (~line 250):

```r
#' Resolve a PubMed publication date from its parts with graceful fallback.
#'
#' Defaults a missing day/month to "01" rather than discarding the year.
#' Falls back to a <MedlineDate> string when structured year is absent.
#' Returns date_source provenance: pubmed | pubmed_partial | medline_date | unknown.
#' @noRd
resolve_pubmed_date <- function(year, month, day, medline_date = NA_character_) {
  blank <- function(x) is.null(x) || length(x) == 0L || is.na(x) || !nzchar(trimws(as.character(x)[1]))
  month_to_num <- function(m) {
    if (blank(m)) return(NA_character_)
    m <- trimws(as.character(m)[1])
    if (grepl("^[0-9]{1,2}$", m)) return(stringr::str_pad(m, 2, "left", pad = "0"))
    idx <- match(tolower(substr(m, 1, 3)), tolower(month.abb))
    if (is.na(idx)) NA_character_ else sprintf("%02d", idx)
  }

  if (blank(year) && !blank(medline_date)) {
    yr <- regmatches(medline_date, regexpr("[0-9]{4}", medline_date))
    if (length(yr) == 1L) {
      mon_tok <- regmatches(medline_date, regexpr("[A-Za-z]{3,}", medline_date))
      mon <- if (length(mon_tok) == 1L) month_to_num(mon_tok) else NA_character_
      return(list(
        year = yr,
        month = if (is.na(mon)) "01" else mon,
        day = "01",
        date_source = "medline_date"
      ))
    }
  }

  if (blank(year)) {
    return(list(year = NA_character_, month = NA_character_,
                day = NA_character_, date_source = "unknown"))
  }

  month_norm <- month_to_num(month)
  day_norm <- if (blank(day) || !grepl("^[0-9]{1,2}$", trimws(as.character(day)[1]))) {
    NA_character_
  } else {
    stringr::str_pad(trimws(as.character(day)[1]), 2, "left", pad = "0")
  }
  is_partial <- is.na(month_norm) || is.na(day_norm)
  list(
    year = trimws(as.character(year)[1]),
    month = if (is.na(month_norm)) "01" else month_norm,
    day = if (is.na(day_norm)) "01" else day_norm,
    date_source = if (is_partial) "pubmed_partial" else "pubmed"
  )
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"`
Expected: PASS for the two new `resolve_pubmed_date` tests.

- [ ] **Step 5: Wire the helper into `table_articles_from_xml`**

In `api/functions/publication-functions.R`, in `table_articles_from_xml`, **replace** this block (~lines 311-317):

```r
    year <- date_part(article, "Year")
    month <- date_part(article, "Month")
    day <- date_part(article, "Day")
    if (is.na(year) || is.na(month) || is.na(day)) {
      year <- format(Sys.time(), "%Y")
      month <- format(Sys.time(), "%m")
      day <- format(Sys.time(), "%d")
    }
```

with:

```r
    medline_date <- text_first(
      article, ".//Article/Journal/JournalIssue/PubDate/MedlineDate",
      default = NA_character_
    )
    pub_date <- resolve_pubmed_date(
      date_part(article, "Year"),
      date_part(article, "Month"),
      date_part(article, "Day"),
      medline_date = medline_date
    )
    year <- pub_date$year
    month <- pub_date$month
    day <- pub_date$day
    date_source <- pub_date$date_source
```

Then in the `as_tibble(list(...))` call at the end of the same `map_dfr` (~line 322-339), the `year`/`month`/`day` lines currently read:

```r
      year = year,
      month = str_pad(month, 2, "left", pad = "0"),
      day = str_pad(day, 2, "left", pad = "0"),
```

Replace them with (the helper already zero-pads):

```r
      year = year,
      month = month,
      day = day,
      date_source = date_source,
```

- [ ] **Step 6: Add `date_source` to the empty tibble**

In `empty_pubmed_article_tibble()` (~line 109), add a `date_source` column after `day`:

```r
    day = character(),
    date_source = character(),
    lastname = character(),
```

- [ ] **Step 7: Carry provenance through `info_from_pmid`**

In `info_from_pmid()`, the `parsed_articles` are transformed (~lines 387-401). The current block:

```r
  input_tibble_request <- parsed_articles %>%
    mutate(publication_id = as.character(pmid)) %>%
    mutate(other_publication_id = paste0("DOI:", doi)) %>%
    mutate(Publication_date = paste0(year, "-", month, "-", day)) %>%
    dplyr::select(
      publication_id = pmid,
      other_publication_id,
      Title = title,
      Abstract = abstract,
      Publication_date,
      Journal_abbreviation = jabbrv,
      Journal = journal,
      Keywords = keywords,
      Lastname = lastname,
      Firstname = firstname
    )
```

Replace with (build `Publication_date` as `NA` when the date is unknown, and add `publication_date_source`):

```r
  input_tibble_request <- parsed_articles %>%
    mutate(publication_id = as.character(pmid)) %>%
    mutate(other_publication_id = paste0("DOI:", doi)) %>%
    mutate(publication_date_source = date_source) %>%
    mutate(Publication_date = dplyr::if_else(
      date_source == "unknown",
      NA_character_,
      paste0(year, "-", month, "-", day)
    )) %>%
    dplyr::select(
      publication_id = pmid,
      other_publication_id,
      Title = title,
      Abstract = abstract,
      Publication_date,
      publication_date_source,
      Journal_abbreviation = jabbrv,
      Journal = journal,
      Keywords = keywords,
      Lastname = lastname,
      Firstname = firstname
    )
```

Also update the early-return empty tibble inside `info_from_pmid` (~lines 366-372) to add `publication_date_source = character()` after `Publication_date = character()`.

**Note:** the `INSERT INTO publication` in `add_publications_to_db` (~line 211) is built dynamically from `names(...)`, so it picks up `publication_date_source` automatically once the column exists (Task 1). No INSERT edit needed. The `mutate(across(-any_of("Publication_date"), ~ replace_na(.x, "")))` line (~433) will turn a missing `publication_date_source` into `""` — acceptable; the column is nullable.

- [ ] **Step 8: Run the full publication test file**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"`
Expected: PASS (all pre-existing tests plus the two new ones). If a pre-existing test asserted the `Sys.time()` fallback behavior, update it to expect the new graceful-default behavior.

- [ ] **Step 9: Lint**

Run: `make lint-api` (from repo root; `lintr` runs host-side)
Expected: no new lint errors in `publication-functions.R`.

- [ ] **Step 10: Commit**

```bash
git add api/functions/publication-functions.R api/tests/testthat/test-unit-publication-functions.R
git commit -m "fix: parse partial PubMed dates instead of falling back to ingest date"
```

---

## Task 3 — A3: publication-date backfill script [WAVE 3 — needs Task 2]

**Files:**
- Create: `db/updates/backfill_publication_dates.R`

**Context:** A one-off operator script. Re-fetches every linked publication's PubMed XML, recomputes the date with Task 2's `resolve_pubmed_date()` (via `info_from_pmid`), and `UPDATE`s `Publication_date` + `publication_date_source` only. Not a startup migration — it needs PubMed network egress.

- [ ] **Step 1: Write the backfill script**

Create `db/updates/backfill_publication_dates.R`:

```r
#!/usr/bin/env Rscript
# backfill_publication_dates.R
#
# One-off operator script. Re-fetches PubMed metadata for every publication
# linked to a primary-approved review and corrects publication.Publication_date
# and publication.publication_date_source using the fixed date parser
# (resolve_pubmed_date / info_from_pmid).
#
# Requires: db/migrations/021_add_publication_date_source.sql applied,
#           outbound network egress to NCBI E-utilities.
#
# Usage:
#   Rscript db/updates/backfill_publication_dates.R --dry-run
#   Rscript db/updates/backfill_publication_dates.R --apply
#
# Run from the repo root or inside the API container.

suppressWarnings(suppressMessages({
  library(DBI)
  library(RMariaDB)
  library(dplyr)
}))

args <- commandArgs(trailingOnly = TRUE)
dry_run <- !("--apply" %in% args)

# --- locate API source so info_from_pmid / resolve_pubmed_date are available ---
api_dir <- Sys.getenv("SYSNDD_API_DIR", "api")
if (!dir.exists(api_dir) && dir.exists("/app")) api_dir <- "/app"
source(file.path(api_dir, "functions", "publication-functions.R"))

# --- DB connection from env (matches db-helpers.R resolution) ---
con <- DBI::dbConnect(
  RMariaDB::MariaDB(),
  host     = Sys.getenv("MYSQL_HOST", "mysql"),
  port     = as.integer(Sys.getenv("MYSQL_PORT", "3306")),
  dbname   = Sys.getenv("MYSQL_DATABASE", "sysndd_db"),
  user     = Sys.getenv("MYSQL_USER", "bernt"),
  password = Sys.getenv("MYSQL_PASSWORD", "changeme")
)
on.exit(DBI::dbDisconnect(con), add = TRUE)

linked <- DBI::dbGetQuery(con, "
  SELECT DISTINCT p.publication_id, p.Publication_date AS old_date,
         p.publication_date_source AS old_source
  FROM publication p
  JOIN ndd_review_publication_join rpj
    ON rpj.publication_id = p.publication_id AND rpj.is_reviewed = 1
  JOIN ndd_entity_review er
    ON er.review_id = rpj.review_id AND er.is_primary = 1 AND er.review_approved = 1")

message(sprintf("[backfill] %d linked publications to re-check (dry_run=%s)",
                nrow(linked), dry_run))

# info_from_pmid accepts bare or PMID:-prefixed IDs; chunks internally at 200.
fetched <- info_from_pmid(linked$publication_id)
fetched$publication_id <- paste0("PMID:", sub("^PMID:", "", fetched$publication_id))

merged <- linked %>%
  dplyr::left_join(
    fetched %>% dplyr::select(publication_id, Publication_date, publication_date_source),
    by = "publication_id"
  ) %>%
  dplyr::filter(!is.na(Publication_date) | !is.na(publication_date_source)) %>%
  dplyr::mutate(changed = is.na(old_date) | as.character(old_date) != Publication_date |
                  is.na(old_source) | old_source != publication_date_source)

to_update <- merged %>% dplyr::filter(changed)
message(sprintf("[backfill] %d rows would change", nrow(to_update)))
for (i in seq_len(min(nrow(to_update), 20L))) {
  r <- to_update[i, ]
  message(sprintf("  %s: %s -> %s (%s)", r$publication_id,
                  r$old_date, r$Publication_date, r$publication_date_source))
}

if (dry_run) {
  message("[backfill] dry-run: no rows written. Re-run with --apply to write.")
} else {
  upd <- "UPDATE publication SET Publication_date = ?, publication_date_source = ? WHERE publication_id = ?"
  DBI::dbWithTransaction(con, {
    for (i in seq_len(nrow(to_update))) {
      r <- to_update[i, ]
      DBI::dbExecute(con, upd, params = unname(list(
        r$Publication_date, r$publication_date_source, r$publication_id
      )))
    }
  })
  message(sprintf("[backfill] applied %d updates", nrow(to_update)))
}
```

- [ ] **Step 2: Dry-run the script against the dev DB**

Run:
```bash
docker exec -e SYSNDD_API_DIR=/app -e MYSQL_HOST=mysql -e MYSQL_PASSWORD=changeme \
  sysndd-api-1 Rscript /app/../db/updates/backfill_publication_dates.R --dry-run 2>&1 | tail -30
```
If `db/` is not reachable from `/app` inside the container, copy the script in first:
```bash
docker cp db/updates/backfill_publication_dates.R sysndd-api-1:/tmp/backfill_publication_dates.R
docker exec -e SYSNDD_API_DIR=/app -e MYSQL_HOST=mysql -e MYSQL_PASSWORD=changeme \
  sysndd-api-1 Rscript /tmp/backfill_publication_dates.R --dry-run 2>&1 | tail -30
```
Expected: a line `[backfill] N linked publications to re-check`, a line `[backfill] M rows would change` with M in the low thousands, a sample of `PMID:... old -> new` lines showing corrected years (e.g. `PMID:23746550: 2024-12-08 -> 2013-06-...`), and `dry-run: no rows written`.

- [ ] **Step 3: Apply the backfill**

Run the same command with `--apply` instead of `--dry-run`.
Expected: `[backfill] applied M updates`.

- [ ] **Step 4: Verify in the database**

Run:
```bash
docker exec sysndd-api-1 Rscript -e 'con <- DBI::dbConnect(RMariaDB::MariaDB(), host="mysql", port=3306, dbname="sysndd_db", user="bernt", password="changeme"); print(DBI::dbGetQuery(con, "SELECT publication_id, Publication_date, publication_date_source FROM publication WHERE publication_id=\"PMID:23746550\"")); print(DBI::dbGetQuery(con, "SELECT publication_date_source, COUNT(*) n FROM publication GROUP BY publication_date_source")); DBI::dbDisconnect(con)'
```
Expected: PMID:23746550 now shows a 2013 `Publication_date` with `publication_date_source` of `pubmed` or `pubmed_partial`; the group-by shows the provenance distribution with few/no `unknown`.

- [ ] **Step 5: Commit**

```bash
git add db/updates/backfill_publication_dates.R
git commit -m "feat: add publication-date backfill script"
```

---

## Task 4 — B: honest MCP publication-date presentation [WAVE 2 — needs Task 1]

**Files:**
- Modify: `api/functions/mcp-repository.R` (`mcp_repo_get_entity_publications` ~270-291, `mcp_repo_get_publication_context` ~293-315)
- Modify: `api/services/mcp-service.R` (`MCP_SCHEMA_VERSION` line 5, `mcp_publication_date_quality` ~208-226, `mcp_publication_record` ~228-260, `mcp_recommended_citation` ~194-206)
- Test: `api/tests/testthat/test-mcp-service.R`

- [ ] **Step 1: Write the failing tests**

Append to `api/tests/testthat/test-mcp-service.R`:

```r
test_that("mcp_publication_date_quality uses the stored provenance column", {
  verified <- mcp_publication_date_quality("2013-06-08", curation_dates = NULL,
                                           date_source = "pubmed")
  expect_equal(verified$confidence, "pubmed_verified")

  partial <- mcp_publication_date_quality("2017-01-01", curation_dates = NULL,
                                          date_source = "pubmed_partial")
  expect_equal(partial$confidence, "pubmed_partial")

  no_source <- mcp_publication_date_quality("2024-12-08",
                                            curation_dates = "2024-12-08",
                                            date_source = NULL)
  expect_equal(no_source$confidence, "matches_curation_date")
  expect_true(no_source$matches_curation_date)

  fallback <- mcp_publication_date_quality("2019-05-01", curation_dates = NULL,
                                           date_source = NULL)
  expect_equal(fallback$confidence, "unverified")
})

test_that("mcp_publication_record renames the date field and guards the citation", {
  pub <- list(
    publication_id = "PMID:1", Title = "T", Journal = "J",
    Publication_date = "2024-12-08", curation_review_date = "2024-12-08",
    Lastname = "Doe", publication_type = "original",
    publication_date_source = NA, Abstract = "A"
  )
  rec <- mcp_publication_record(pub, abstract_mode = "metadata")
  expect_true("publication_date_sysndd_record" %in% names(rec))
  expect_false("pubmed_publication_date" %in% names(rec))
  expect_equal(rec$publication_date_confidence, "matches_curation_date")
  expect_match(rec$recommended_citation, "publication date unverified")
})
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')"`
Expected: FAIL — `date_source` argument unused / `publication_date_sysndd_record` not found.

- [ ] **Step 3: Bump the schema version**

In `api/services/mcp-service.R` line 5:

```r
MCP_SCHEMA_VERSION <- "1.1"
```

- [ ] **Step 4: Rework `mcp_publication_date_quality`**

Replace the whole function (`api/services/mcp-service.R` ~208-226) with:

```r
mcp_publication_date_quality <- function(publication_date, curation_dates = NULL,
                                         date_source = NULL) {
  pub_date <- if (is.null(publication_date) || length(publication_date) == 0L ||
                  is.na(publication_date[1])) {
    ""
  } else {
    as.character(publication_date[1])
  }
  curation <- as.character(curation_dates)
  curation <- curation[!is.na(curation) & nzchar(curation)]
  matches_curation <- nzchar(pub_date) && any(pub_date == curation)

  source_value <- if (is.null(date_source) || length(date_source) == 0L ||
                      is.na(date_source[1]) || !nzchar(as.character(date_source[1]))) {
    NA_character_
  } else {
    as.character(date_source[1])
  }

  confidence <- if (!is.na(source_value)) {
    switch(source_value,
      pubmed = "pubmed_verified",
      pubmed_partial = "pubmed_partial",
      medline_date = "pubmed_partial",
      unknown = "unverified",
      "unverified"
    )
  } else if (matches_curation) {
    "matches_curation_date"
  } else {
    "unverified"
  }

  note <- switch(confidence,
    pubmed_verified = "Publication date parsed from a complete PubMed structured date.",
    pubmed_partial = "Publication date parsed from PubMed with day and/or month defaulted to 01.",
    matches_curation_date = "Publication date equals a linked SysNDD curation date; treat as unverified.",
    "Publication date from the local publication table; provenance not yet verified."
  )
  list(
    matches_curation_date = matches_curation,
    confidence = confidence,
    note = note
  )
}
```

- [ ] **Step 5: Rework `mcp_recommended_citation`**

Replace `mcp_recommended_citation` (`api/services/mcp-service.R` ~194-206) with a version that suppresses an unverified date:

```r
mcp_recommended_citation <- function(pub, date_confidence = "unverified") {
  trusted_date <- date_confidence %in% c("pubmed_verified", "pubmed_partial")
  pieces <- c(
    pub$Lastname,
    pub$Title,
    pub$Journal,
    if (trusted_date) pub$Publication_date else NULL,
    pub$publication_id
  )
  pieces <- pieces[!vapply(pieces, is.null, logical(1))]
  pieces <- as.character(pieces)
  pieces <- pieces[!is.na(pieces) & nzchar(trimws(pieces))]
  citation <- paste(pieces, collapse = ". ")
  if (!trusted_date) {
    citation <- paste0(citation, " (publication date unverified)")
  }
  citation
}
```

- [ ] **Step 6: Rework `mcp_publication_record`**

Replace `mcp_publication_record` (`api/services/mcp-service.R` ~228-260) with:

```r
mcp_publication_record <- function(pub,
                                   abstract_mode = "excerpt",
                                   abstract_max_chars = 1000L,
                                   include_keywords = FALSE,
                                   date_quality = NULL) {
  abstract_mode <- mcp_validate_mode(abstract_mode, c("none", "metadata", "excerpt"),
                                     "abstract_mode", "excerpt")
  date_quality <- date_quality %||% mcp_publication_date_quality(
    pub$Publication_date, pub$curation_review_date, pub$publication_date_source
  )
  record <- list(
    publication_id = pub$publication_id,
    title = pub$Title,
    journal = pub$Journal,
    publication_date_sysndd_record = pub$Publication_date,
    publication_date_matches_curation_date = date_quality$matches_curation_date,
    publication_date_confidence = date_quality$confidence,
    publication_date_note = date_quality$note,
    sysndd_curation_date = pub$curation_review_date,
    first_author = pub$Lastname,
    publication_type = pub$publication_type,
    recommended_citation = mcp_recommended_citation(pub, date_quality$confidence),
    resource_uri = mcp_resource_uri("publication", pub$publication_id)
  )
  if (isTRUE(include_keywords)) record$keywords <- pub$Keywords

  if (!identical(abstract_mode, "none")) {
    record$abstract_available <- mcp_has_text(pub$Abstract)
    if (identical(abstract_mode, "excerpt")) {
      abstract <- mcp_truncate_text(pub$Abstract %||% "", abstract_max_chars)
      record$abstract_excerpt <- abstract$text
      record$abstract_truncated <- abstract$truncated
    }
  }
  record
}
```

- [ ] **Step 7: Update `mcp_get_publication_context` date-quality call**

In `mcp_get_publication_context` (`api/services/mcp-service.R` ~684-715) the line:

```r
    date_quality <- mcp_publication_date_quality(pub$Publication_date, rows$curation_review_date)
```

becomes:

```r
    date_quality <- mcp_publication_date_quality(
      pub$Publication_date, rows$curation_review_date, pub$publication_date_source
    )
```

And in the same function's returned `date_notes` list, rename the key `pubmed_publication_date` to `publication_date_sysndd_record`:

```r
        date_notes = list(
          publication_date_sysndd_record = date_quality$note,
          sysndd_curation_date = "Primary approved SysNDD review date on linked entities."
        )
```

- [ ] **Step 8: Add `publication_date_source` to the repository SELECTs**

In `api/functions/mcp-repository.R`:

In `mcp_repo_get_entity_publications` (~270-291), change the SELECT column list line:

```r
      SELECT rpj.entity_id, p.publication_id, p.Title, p.Journal,
             p.Publication_date, p.Lastname, p.Firstname, p.Abstract,
             rpj.publication_type, er.review_date AS curation_review_date
```

to:

```r
      SELECT rpj.entity_id, p.publication_id, p.Title, p.Journal,
             p.Publication_date, p.publication_date_source, p.Lastname,
             p.Firstname, p.Abstract,
             rpj.publication_type, er.review_date AS curation_review_date
```

In `mcp_repo_get_publication_context` (~293-315), change:

```r
      SELECT p.publication_id, p.Title, p.Abstract, p.Journal, p.Publication_date,
             p.Lastname, p.Firstname, p.Keywords,
```

to:

```r
      SELECT p.publication_id, p.Title, p.Abstract, p.Journal, p.Publication_date,
             p.publication_date_source, p.Lastname, p.Firstname, p.Keywords,
```

- [ ] **Step 9: Run the MCP service tests**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')"`
Expected: PASS, including the two new tests. Update any pre-existing test that asserts the old `pubmed_publication_date` / `pubmed_publication_date_confidence` field names to the new `publication_date_sysndd_record` / `publication_date_confidence` names.

- [ ] **Step 10: Commit**

```bash
git add api/functions/mcp-repository.R api/services/mcp-service.R api/tests/testthat/test-mcp-service.R
git commit -m "feat: present MCP publication dates honestly with stored provenance"
```

---

## Task 5 — C: `get_genes_context` multi-gene batch tool [WAVE 2]

**Files:**
- Modify: `api/services/mcp-service.R` (add `mcp_get_genes_context` after `mcp_get_gene_context` ~line 500)
- Modify: `api/services/mcp-tools.R` (add tool fn + registration + `tool_functions` entry)
- Test: `api/tests/testthat/test-mcp-service.R`, `api/tests/testthat/test-mcp-tools.R`

- [ ] **Step 1: Write the failing service test**

Append to `api/tests/testthat/test-mcp-service.R`:

```r
test_that("mcp_get_genes_context batches genes with per-gene errors", {
  res <- mcp_get_genes_context(genes = list("PNKP", "definitely-not-a-gene"))
  expect_equal(res$schema_version, MCP_SCHEMA_VERSION)
  expect_length(res$genes, 2L)
  expect_equal(res$meta$requested, 2L)
  expect_equal(res$meta$returned, 1L)
  expect_equal(res$meta$errors, 1L)
  # order preserved: first resolves, second carries an error envelope
  expect_null(res$genes[[1]]$error)
  expect_false(is.null(res$genes[[2]]$error))
})

test_that("mcp_get_genes_context rejects an over-cap batch", {
  too_many <- as.list(sprintf("GENE%d", seq_len(11)))
  expect_error(mcp_get_genes_context(genes = too_many), class = "mcp_tool_error")
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')"`
Expected: FAIL — `could not find function "mcp_get_genes_context"`.

- [ ] **Step 3: Add `mcp_get_genes_context`**

In `api/services/mcp-service.R`, add this constant near the other limits (after `MCP_MAX_ENTITY_BATCH_IDS` ~line 8):

```r
MCP_MAX_GENE_BATCH <- 10L
```

Then add this function immediately **after** `mcp_get_gene_context` ends (~after line 500):

```r
mcp_get_genes_context <- function(genes,
                                  include_entities = TRUE,
                                  include_comparisons = FALSE,
                                  entity_limit = NULL,
                                  response_mode = NULL,
                                  synopsis_mode = NULL,
                                  expand = NULL,
                                  include_publications = TRUE,
                                  include_phenotypes = TRUE,
                                  include_variants = TRUE,
                                  publication_limit = NULL,
                                  abstract_mode = NULL,
                                  dedupe_publications = TRUE) {
  if (is.null(genes)) {
    stop(mcp_error("invalid_input", "genes must contain at least one gene identifier",
                   list(argument = "genes")))
  }
  raw_genes <- as.character(unlist(genes, use.names = FALSE))
  raw_genes <- raw_genes[!is.na(raw_genes) & nzchar(trimws(raw_genes))]
  if (length(raw_genes) == 0L) {
    stop(mcp_error("invalid_input", "genes must contain at least one gene identifier",
                   list(argument = "genes")))
  }
  if (length(raw_genes) > MCP_MAX_GENE_BATCH) {
    stop(mcp_error("invalid_input",
                   sprintf("genes supports at most %d identifiers per call", MCP_MAX_GENE_BATCH),
                   list(argument = "genes", max = MCP_MAX_GENE_BATCH)))
  }

  results <- lapply(raw_genes, function(gene) {
    tryCatch(
      mcp_get_gene_context(
        gene = gene,
        include_entities = include_entities,
        include_comparisons = include_comparisons,
        entity_limit = entity_limit %||% 10L,
        response_mode = response_mode %||% "compact",
        synopsis_mode = synopsis_mode,
        expand = expand %||% "none",
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit %||% 10L,
        abstract_mode = abstract_mode,
        dedupe_publications = dedupe_publications
      ),
      mcp_tool_error = function(e) {
        list(requested_gene = gene, error = unclass(e)$error)
      }
    )
  })
  for (idx in seq_along(results)) {
    if (is.null(results[[idx]]$error)) {
      results[[idx]]$requested_gene <- raw_genes[[idx]]
    }
  }

  # Deduplicate publications across genes when expand brought entity_details.
  publications <- list()
  expanded <- identical(expand %||% "none", "entities")
  if (expanded && isTRUE(dedupe_publications)) {
    publication_map <- new.env(parent = emptyenv())
    publication_ids <- character()
    for (idx in seq_along(results)) {
      detail <- results[[idx]]$entity_details
      if (is.null(detail) || is.null(detail$publications)) next
      for (pub in detail$publications) {
        key <- pub$publication_id %||% ""
        if (nzchar(key) && is.null(publication_map[[key]])) {
          publication_map[[key]] <- pub
          publication_ids <- c(publication_ids, key)
        }
      }
    }
    publications <- lapply(publication_ids, function(key) publication_map[[key]])
  }

  returned <- sum(vapply(results, function(item) is.null(item$error), logical(1)))
  list(
    schema_version = MCP_SCHEMA_VERSION,
    genes = results,
    publications = publications,
    meta = list(
      requested = length(raw_genes),
      returned = returned,
      errors = length(raw_genes) - returned,
      max_genes = MCP_MAX_GENE_BATCH,
      expand = expand %||% "none",
      dedupe_publications = isTRUE(dedupe_publications),
      publication_shape = if (expanded && isTRUE(dedupe_publications)) {
        "top_level_deduplicated"
      } else {
        "nested_per_gene"
      },
      publication_count = length(publications)
    )
  )
}
```

- [ ] **Step 4: Run the service test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')"`
Expected: PASS for the two new `mcp_get_genes_context` tests.

- [ ] **Step 5: Write the failing tool-registration test**

Append to `api/tests/testthat/test-mcp-tools.R`:

```r
test_that("get_genes_context is registered in the tool registry", {
  registry <- mcp_build_tool_registry()
  tool_names <- vapply(registry$tools, function(t) t@name, character(1))
  expect_true("get_genes_context" %in% tool_names)
  expect_true("get_genes_context" %in% names(registry$tool_functions))
})
```

- [ ] **Step 6: Run the tool test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`
Expected: FAIL — `get_genes_context` not in registry.

- [ ] **Step 7: Register the tool**

In `api/services/mcp-tools.R`, inside `mcp_build_tool_registry`, add this tool function definition after `get_gene_context_fun` (~after line 582):

```r
  get_genes_context_fun <- function(genes = NULL,
                                    include_entities = TRUE,
                                    include_comparisons = FALSE,
                                    entity_limit = NULL,
                                    response_mode = NULL,
                                    synopsis_mode = NULL,
                                    expand = NULL,
                                    include_publications = TRUE,
                                    include_phenotypes = TRUE,
                                    include_variants = TRUE,
                                    publication_limit = NULL,
                                    abstract_mode = NULL,
                                    dedupe_publications = TRUE) {
    mcp_tool_safe(function() {
      if (is.null(genes)) {
        stop(mcp_error("invalid_input", "Missing required parameter 'genes'",
                       list(argument = "genes")))
      }
      mcp_get_genes_context(
        genes = genes,
        include_entities = include_entities,
        include_comparisons = include_comparisons,
        entity_limit = entity_limit,
        response_mode = response_mode,
        synopsis_mode = synopsis_mode,
        expand = expand,
        include_publications = include_publications,
        include_phenotypes = include_phenotypes,
        include_variants = include_variants,
        publication_limit = publication_limit,
        abstract_mode = abstract_mode,
        dedupe_publications = dedupe_publications
      )
    }, output_mode)()
  }
```

Add this `ellmer::tool(...)` entry to the `tools <- list(...)` block, immediately after the `get_gene_context` tool entry (after its closing `),` ~line 716):

```r
    ellmer::tool(
      get_genes_context_fun,
      "Batch get compact approved public context for 1-10 SysNDD genes, preserving order with per-gene errors. Use expand=entities for one-call multi-gene detail (token-heavy on large batches). Example: get_genes_context({\"genes\":[\"CTCF\",\"MECP2\",\"SCN2A\"],\"expand\":\"entities\",\"abstract_mode\":\"metadata\"}).",
      arguments = list(
        genes = ellmer::type_array(ellmer::type_string("Gene identifier such as PNKP, HGNC:1234, or bare HGNC ID."), description = "Array of 1-10 gene identifiers."),
        include_entities = ellmer::type_boolean("Include compact entity rows per gene; default true.", required = FALSE),
        include_comparisons = ellmer::type_boolean("Include comparison-source rows; default false.", required = FALSE),
        entity_limit = ellmer::type_integer("Entity cap per gene, default 10, max 25.", required = FALSE),
        response_mode = ellmer::type_string("compact, standard, or full; default compact.", required = FALSE),
        synopsis_mode = ellmer::type_string("none, excerpt, or full; default follows response_mode.", required = FALSE),
        expand = ellmer::type_string("none or entities; default none. Use entities for one-call gene plus entity detail.", required = FALSE),
        include_publications = ellmer::type_boolean("When expand=entities, include linked publications; default true.", required = FALSE),
        include_phenotypes = ellmer::type_boolean("When expand=entities, include HPO phenotype terms; default true.", required = FALSE),
        include_variants = ellmer::type_boolean("When expand=entities, include variation ontology terms; default true.", required = FALSE),
        publication_limit = ellmer::type_integer("When expand=entities, publication cap per entity, default 10, max 25.", required = FALSE),
        abstract_mode = ellmer::type_string("When expand=entities, none, metadata, or excerpt; default follows response_mode.", required = FALSE),
        dedupe_publications = ellmer::type_boolean("Deduplicate shared publications into top-level publications across genes; default true.", required = FALSE)
      ),
      name = "get_genes_context"
    ),
```

In the `tool_functions = list(...)` block at the end of `mcp_build_tool_registry` (~line 819-831), add after the `get_gene_context` entry:

```r
      get_genes_context = get_genes_context_fun,
```

- [ ] **Step 8: Run the tool test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`
Expected: PASS.

- [ ] **Step 9: Add `get_genes_context` to the smoke probe**

In `api/scripts/mcp-smoke.R`, find where individual tools are exercised (search for `get_gene_context` or `tools/call`) and add an analogous `get_genes_context` call with `{"genes":["PNKP"]}`. Match the file's existing call pattern exactly. If the smoke script iterates a list of tool names, add `"get_genes_context"` to that list with its argument map.

- [ ] **Step 10: Commit**

```bash
git add api/services/mcp-service.R api/services/mcp-tools.R api/scripts/mcp-smoke.R api/tests/testthat/test-mcp-service.R api/tests/testthat/test-mcp-tools.R
git commit -m "feat: add get_genes_context multi-gene batch MCP tool"
```

---

## Task 6 — D1-D6, D8: capabilities & tool-guide hardening [WAVE 2]

**Files:**
- Modify: `api/services/mcp-service.R` (`mcp_get_sysndd_capabilities` ~804-861)
- Modify: `config/mcp/resources/sysndd-schema.md`
- Test: `api/tests/testthat/test-mcp-tools.R`

**Note:** This task does NOT touch `canonical_workflows`/`limits` for `get_genes_context` — that is Task 7 (Wave 3), to avoid a merge race with Task 5.

- [ ] **Step 1: Write the failing capabilities test**

Append to `api/tests/testthat/test-mcp-tools.R`:

```r
test_that("capabilities expose error examples, performance, prompts, categories", {
  caps <- mcp_get_sysndd_capabilities()
  expect_true(!is.null(caps$error_examples$ambiguous_query$error$choices))
  expect_true(!is.null(caps$performance$get_publication_context$cache_ttl_seconds))
  expect_true(!is.null(caps$performance$get_publication_context$cost_tier))
  expect_true(!is.null(caps$mode_resolution))
  expect_true("not applicable" %in% caps$entity_categories$returned_values)
  # prompts are now objects with arguments + a user-controlled note
  expect_true(!is.null(caps$prompts$note))
  expect_true(!is.null(caps$prompts$available[[1]]$arguments))
  # the expand example teaches the cheap 2-call path
  expect_equal(caps$payload_modes$gene_expand_example$abstract_mode, "excerpt")
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`
Expected: FAIL — `error_examples` / `performance` / `mode_resolution` / `entity_categories` are NULL.

- [ ] **Step 3: Rewrite `mcp_get_sysndd_capabilities`**

In `api/services/mcp-service.R`, replace the entire `mcp_get_sysndd_capabilities` function (~804-861) with the version below. (Task 7 later adds the `get_genes_context` lines into `canonical_workflows` and `limits`.)

```r
mcp_get_sysndd_capabilities <- function() {
  list(
    schema_version = MCP_SCHEMA_VERSION,
    server = list(name = "SysNDD read-only MCP", schema_version = MCP_SCHEMA_VERSION),
    canonical_workflows = list(
      gene_summary = list("search_sysndd", "get_gene_context", "get_entities_context", "get_publications_context"),
      entity_detail = list("get_entity_context", "get_publications_context"),
      phenotype_discovery = list("find_entities_by_phenotype", "get_entities_context"),
      disease_discovery = list("find_entities_by_disease", "get_entities_context"),
      citation_pack = list("get_publications_context")
    ),
    payload_modes = list(
      response_mode = c("compact", "standard", "full"),
      abstract_mode = c("none", "metadata", "excerpt"),
      synopsis_mode = c("none", "excerpt", "full"),
      cheap_gene_example = list(gene = "PNKP", include_entities = TRUE, include_comparisons = FALSE, response_mode = "compact"),
      gene_expand_example = list(gene = "PNKP", expand = "entities", abstract_mode = "excerpt", entity_limit = 10L),
      gene_expand_note = "expand=entities returns the gene plus full entity detail in one call; abstract_mode=excerpt makes abstracts ride along, so the canonical gene summary is a 2-call path (search_sysndd then get_gene_context).",
      metadata_mode_abstract_fields = list(includes = "abstract_available", omits = list("abstract_excerpt", "abstract_truncated")),
      publication_metadata_example = list(pmids = list("PMID:37130971"), abstract_mode = "metadata")
    ),
    mode_resolution = list(
      note = "response_mode only derives the defaults for abstract_mode and synopsis_mode; an explicit abstract_mode or synopsis_mode argument always wins. The effective values are echoed back in each response's meta block.",
      compact_defaults = list(abstract_mode = "metadata", synopsis_mode = "excerpt"),
      standard_full_defaults = list(abstract_mode = "excerpt", synopsis_mode = "full")
    ),
    limits = list(
      search_sysndd = list(default_limit = 10L, max_limit = 25L),
      get_gene_context = list(default_entity_limit = 10L, max_entity_limit = 25L, max_entity_detail_expand_ids = MCP_MAX_ENTITY_BATCH_IDS),
      list_gene_entities = list(default_limit = 25L, max_limit = 50L),
      get_entity_context = list(default_publication_limit = 10L, max_publication_limit = 25L),
      get_entities_context = list(max_entity_ids = 20L, default_dedupe_publications = TRUE),
      get_publications_context = list(max_pmids = 20L, max_abstract_chars = 4000L)
    ),
    performance = list(
      note = "cache_ttl_seconds is the in-process result cache window; cost_tier is a rough latency hint.",
      get_sysndd_stats = list(cache_ttl_seconds = 300L, cost_tier = "cheap"),
      search_sysndd = list(cache_ttl_seconds = 60L, cost_tier = "cheap"),
      get_gene_context = list(cache_ttl_seconds = 300L, cost_tier = "moderate"),
      get_entity_context = list(cache_ttl_seconds = 300L, cost_tier = "moderate"),
      get_publication_context = list(cache_ttl_seconds = 1800L, cost_tier = "moderate"),
      get_sysndd_capabilities = list(cache_ttl_seconds = 0L, cost_tier = "cheap")
    ),
    citation_contract = list(
      use_recommended_citation_verbatim = TRUE,
      date_fields = list("publication_date_sysndd_record", "sysndd_curation_date"),
      confidence_fields = list("publication_date_confidence", "publication_date_matches_curation_date"),
      confidence_values = c("pubmed_verified", "pubmed_partial", "matches_curation_date", "unverified"),
      date_note = "publication_date_sysndd_record is the date stored in the SysNDD publication table. Trust it as a publication date only when publication_date_confidence is pubmed_verified or pubmed_partial; otherwise it may be an ingestion-date artifact and recommended_citation omits the year.",
      abstract_fields = list("abstract_available", "abstract_excerpt", "abstract_truncated"),
      abstract_mode_note = "metadata returns abstract_available only; excerpt returns abstract_excerpt and abstract_truncated when text is available."
    ),
    entity_categories = list(
      filter_values = MCP_ALLOWED_ENTITY_CATEGORIES,
      returned_values = c("Definitive", "Moderate", "Limited", "Refuted", "not applicable"),
      note = "category filters accept Definitive/Moderate/Limited/Refuted. Returned entity rows may also carry 'not applicable' for records outside the NDD curation scope; that value cannot be used as a filter."
    ),
    comparison_sources = list(
      availability = "Use get_gene_context(include_comparisons=true) for external panel/source rows.",
      note = "comparison_sources are source cross-references, not cross-gene biological comparisons."
    ),
    resources = list(
      static = c("sysndd://schema/overview", "sysndd://schema/tool-guide"),
      record_uris_are_stable_identifiers = TRUE,
      parameterized_resource_templates = FALSE,
      retrieval_path = "Use tools for record retrieval in v1."
    ),
    prompts = list(
      note = "Prompts are user-controlled per the MCP specification: hosts surface them as slash commands or menu items, not as model-callable tools. A tool-calling client cannot invoke them directly; this is by design.",
      available = list(
        list(name = "sysndd_gene_evidence_summary",
             arguments = list(list(name = "gene", required = TRUE), list(name = "depth", required = FALSE))),
        list(name = "sysndd_entity_evidence_brief",
             arguments = list(list(name = "entity_id", required = TRUE), list(name = "depth", required = FALSE))),
        list(name = "sysndd_publication_citation_pack",
             arguments = list(list(name = "pmids", required = TRUE))),
        list(name = "sysndd_phenotype_entity_discovery",
             arguments = list(list(name = "phenotype", required = TRUE), list(name = "category", required = FALSE)))
      )
    ),
    error_codes = c("invalid_input", "not_found", "ambiguous_query", "temporarily_unavailable"),
    error_examples = list(
      invalid_input = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "invalid_input", message = "Unknown parameter 'symbol'. Expected: gene, include_entities, ...",
        argument = "symbol", hint = "Use 'gene' for gene symbols, HGNC IDs, or HGNC:1234 identifiers.")),
      not_found = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "not_found", message = "Gene not found")),
      ambiguous_query = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "ambiguous_query", message = "Gene input resolved to multiple records",
        choices = list(list(symbol = "EXAMPLE1", hgnc_id = "HGNC:1"),
                       list(symbol = "EXAMPLE2", hgnc_id = "HGNC:2")))),
      temporarily_unavailable = list(schema_version = MCP_SCHEMA_VERSION, error = list(
        code = "temporarily_unavailable", message = "MCP tool failed"))
    ),
    error_handling_note = "Recoverable errors arrive as a tool result with isError=true and an error.code; retry ambiguous_query by calling again with one of error.choices.",
    safety = list(
      scope = "Read-only approved public SysNDD evidence for research review; not clinical decision support.",
      exclusions = c("draft reviews", "admin/user/job/log data", "raw SQL", "raw R", "Gemini", "external provider calls", "database writes")
    )
  )
}
```

- [ ] **Step 4: Run the capabilities test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`
Expected: PASS for the new test. Update any pre-existing capabilities test asserting the old `prompts` flat character vector or the old `pubmed_publication_date` citation field.

- [ ] **Step 5: Refresh the tool-guide resource**

In `config/mcp/resources/sysndd-schema.md`, under the `# sysndd://schema/tool-guide` section, update the publication-date guidance and add the new tool. Edit the publication wording to:

> Publication records expose `publication_date_sysndd_record` with a `publication_date_confidence` flag (`pubmed_verified`, `pubmed_partial`, `matches_curation_date`, `unverified`). Treat the date as a real publication date only when confidence is `pubmed_verified` or `pubmed_partial`.

And add to the tool list:

> `get_genes_context` — batch context for 1-10 genes in one call, with per-gene errors and cross-gene deduplicated publications; use `expand=entities` for one-call multi-gene detail.

- [ ] **Step 6: Commit**

```bash
git add api/services/mcp-service.R config/mcp/resources/sysndd-schema.md api/tests/testthat/test-mcp-tools.R
git commit -m "feat: harden get_sysndd_capabilities discoverability content"
```

---

## Task 7 — D7: register `get_genes_context` in capabilities [WAVE 3 — needs Tasks 5 & 6]

**Files:**
- Modify: `api/services/mcp-service.R` (`mcp_get_sysndd_capabilities`)
- Test: `api/tests/testthat/test-mcp-tools.R`

- [ ] **Step 1: Write the failing test**

Append to `api/tests/testthat/test-mcp-tools.R`:

```r
test_that("capabilities reference get_genes_context", {
  caps <- mcp_get_sysndd_capabilities()
  expect_false(is.null(caps$canonical_workflows$gene_comparison))
  expect_false(is.null(caps$limits$get_genes_context))
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`
Expected: FAIL — `gene_comparison` / `get_genes_context` limit are NULL.

- [ ] **Step 3: Add the workflow and limit entries**

In `mcp_get_sysndd_capabilities` (`api/services/mcp-service.R`), in the `canonical_workflows` list add after the `citation_pack` line:

```r
      citation_pack = list("get_publications_context"),
      gene_comparison = list("get_genes_context")
```

In the `limits` list, add after the `get_gene_context` line:

```r
      get_genes_context = list(max_genes = 10L, default_dedupe_publications = TRUE),
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add api/services/mcp-service.R api/tests/testthat/test-mcp-tools.R
git commit -m "feat: register get_genes_context in MCP capabilities"
```

---

## Task 8 — Documentation & integration verification [WAVE 3]

**Files:**
- Modify: `AGENTS.md`, `documentation/08-development.qmd`, `documentation/09-deployment.qmd`

- [ ] **Step 1: Update `AGENTS.md`**

In the `### Read-only MCP sidecar` section of `AGENTS.md` (and the identical worktree-root `AGENTS.md` if the repo keeps two), update the publication-output sentence. Replace the text describing `pubmed_publication_date` / `abstract_available` with:

> Publication outputs are citation-friendly (`recommended_citation`), expose `publication_date_sysndd_record` with a `publication_date_confidence` flag (`pubmed_verified`, `pubmed_partial`, `matches_curation_date`, `unverified`) sourced from the `publication.publication_date_source` column, distinguish that date from `sysndd_curation_date`, expose `abstract_available` when abstract text is requested or metadata mode is selected, and omit `abstract_excerpt` unless `abstract_mode = "excerpt"`. `recommended_citation` omits the year when the date is unverified.

Add `get_genes_context` to any tool enumeration in that section, and note `MCP_SCHEMA_VERSION` is now `1.1`.

- [ ] **Step 2: Document the backfill in `documentation/08-development.qmd`**

Add a short subsection under development/operations describing the publication-date fix:

> **Publication-date provenance.** `publication.publication_date_source` records how each `Publication_date` was derived (`pubmed`, `pubmed_partial`, `medline_date`, `unknown`). New ingestions set it automatically. To correct historical rows ingested before this fix, run the one-off backfill: `Rscript db/updates/backfill_publication_dates.R --dry-run` to preview, then `--apply`. It re-fetches PubMed metadata, so it needs network egress.

- [ ] **Step 3: Document the backfill in `documentation/09-deployment.qmd`**

Add an operator note that `db/updates/backfill_publication_dates.R` is a manual post-deploy step (one-time) and requires PubMed egress, mirroring the wording from Step 2.

- [ ] **Step 4: Run the full MCP test suite**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-mcp-service.R')" \
  && Rscript -e "testthat::test_file('tests/testthat/test-mcp-tools.R')" \
  && Rscript -e "testthat::test_file('tests/testthat/test-mcp-repository.R')" \
  && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"
```
Expected: all PASS.

- [ ] **Step 5: Run the API PR gate and lint**

Run: `make test-api-fast && make lint-api`
Expected: PASS, no new lint errors.

- [ ] **Step 6: Restart the MCP sidecar and run the smoke probe**

Run:
```bash
docker restart sysndd-mcp-1
docker cp api/scripts/mcp-smoke.R sysndd-mcp-1:/tmp/mcp-smoke.R
docker exec sysndd-mcp-1 Rscript /tmp/mcp-smoke.R
```
Expected: smoke probe passes, including the new `get_genes_context` call and a `get_publication_context` call showing `publication_date_sysndd_record` + `publication_date_confidence`.

- [ ] **Step 7: Commit**

```bash
git add AGENTS.md documentation/08-development.qmd documentation/09-deployment.qmd
git commit -m "docs: document MCP v1.1 publication-date provenance and get_genes_context"
```

---

## Self-review notes

- **Spec coverage:** Track A → Tasks 1-3; Track B → Task 4; Track C → Task 5; Track D items 1-6,8 → Task 6, item 7 → Task 7; docs contract → Task 8. All spec sections mapped.
- **Type consistency:** `resolve_pubmed_date()` returns `list(year, month, day, date_source)` — consumed identically in Task 2 Step 5 and Task 3. `mcp_publication_date_quality(publication_date, curation_dates, date_source)` signature is consistent across Tasks 4. Output field `publication_date_sysndd_record` and confidence values `pubmed_verified|pubmed_partial|matches_curation_date|unverified` are used identically in Tasks 4, 6, 8. `mcp_get_genes_context` / `get_genes_context` / `MCP_MAX_GENE_BATCH` names consistent across Tasks 5, 7.
- **No placeholders:** every code step shows complete code; every run step shows the command and expected result.

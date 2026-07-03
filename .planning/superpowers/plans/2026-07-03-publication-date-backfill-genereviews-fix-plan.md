# publication_date_backfill GeneReviews + NCBI compose wiring — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `publication_date_backfill` actually verify GeneReviews publication dates in the containerized deployment by (a) wiring the NCBI key into the containers and (b) parsing `<PubmedBookArticle>` records and hardening the backfill's outage guard.

**Architecture:** Three independent changes. (1) Add `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` to the compose `environment:` blocks of the three NCBI-egress services. (2) Extract the PubMed-XML parsing concern into a new `api/functions/pubmed-xml-parser.R` and add a `<PubmedBookArticle>` parser using a `ContributionDate`-first date ladder, reusing the existing `pubmed`/`pubmed_partial` source vocabulary. (3) In the backfill, classify per-PMID failures as `unresolved` (parse-empty data condition, non-fatal) vs `failed` (transport/infra), and fire the systemic-outage guard only on `failed`.

**Tech Stack:** R (plumber API, testthat, xml2/purrr/tibble/dplyr/stringr), Docker Compose, MySQL.

**Spec:** `.planning/superpowers/specs/2026-07-03-publication-date-backfill-genereviews-fix-design.md`

## Global Constraints

- Reuse existing `publication_date_source` vocabulary only: `pubmed`, `pubmed_partial`, `medline_date`, `unknown`. **No new source value.**
- Do **not** change `info_from_pmid()`'s strict abort (`publication_fetch_error`); entity-creation semantics stay strict.
- New source files must be registered in `bootstrap_load_modules()` (`api/bootstrap/load_modules.R`) — covers both API and worker.
- Keep handwritten files under the 600-line soft ceiling where practical (`make code-quality-audit` ratchet).
- Namespace `dplyr::` verbs explicitly; use bare `xml2`/`stringr`/`purrr` calls only where the surrounding parser already does (behavior-preserving move).
- Worker-executed code changed → the release notes must call out restarting `worker-maintenance` (and `worker`).
- One release: **v0.27.3** (patch). Bump `app/package.json`, `api/version_spec.json`, `CHANGELOG.md`.
- Branch already created: `fix/publication-date-backfill-genereviews-499-500`. Commit messages end with the `Claude-Session:` trailer.

---

## Task 1: Wire NCBI env vars into docker-compose (#499)

**Files:**
- Modify: `docker-compose.yml` (three `environment:` blocks: `api` ~L167, `worker` ~L293, `worker-maintenance` ~L391)

**Interfaces:**
- Consumes: nothing.
- Produces: `NCBI_API_KEY` / `NCBI_EUTILS_EMAIL` present in the `api`, `worker`, `worker-maintenance` containers (read at runtime by `pubmed_eutils_query()` / `pubmed_min_request_interval()`).

- [ ] **Step 1: Add the keys to the `api` service block**

In `docker-compose.yml`, find the `api` service `environment:` block and the line `GEMINI_API_KEY: ${GEMINI_API_KEY:-}` immediately followed by the CORS comment. Replace:

```yaml
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      # CORS configuration: comma-separated list of allowed origins
```

with:

```yaml
      GEMINI_API_KEY: ${GEMINI_API_KEY:-}
      # NCBI E-utilities identity/rate-limit (#494/#499): raises the per-IP EUtils
      # cap from the anonymous 3 req/s to 10 req/s so publication ingestion and the
      # publication_date_backfill do not 429. Inert when unset (anonymous is valid).
      NCBI_API_KEY: ${NCBI_API_KEY:-}
      NCBI_EUTILS_EMAIL: ${NCBI_EUTILS_EMAIL:-}
      # CORS configuration: comma-separated list of allowed origins
```

- [ ] **Step 2: Add the keys to the `worker` service block**

Find the `worker` service block's unique line `ASYNC_JOB_QUEUES: ${ASYNC_JOB_QUEUES:-default}`. Replace:

```yaml
      ASYNC_JOB_QUEUES: ${ASYNC_JOB_QUEUES:-default}
```

with:

```yaml
      ASYNC_JOB_QUEUES: ${ASYNC_JOB_QUEUES:-default}
      # NCBI E-utilities key (#494/#499). The dev override drains the maintenance
      # lane on this worker too, so the backfill runs here locally.
      NCBI_API_KEY: ${NCBI_API_KEY:-}
      NCBI_EUTILS_EMAIL: ${NCBI_EUTILS_EMAIL:-}
```

- [ ] **Step 3: Add the keys to the `worker-maintenance` service block**

Find the `worker-maintenance` block's unique line `ASYNC_JOB_QUEUES: ${ASYNC_JOB_MAINTENANCE_QUEUES:-maintenance}`. Replace:

```yaml
      ASYNC_JOB_QUEUES: ${ASYNC_JOB_MAINTENANCE_QUEUES:-maintenance}
```

with:

```yaml
      ASYNC_JOB_QUEUES: ${ASYNC_JOB_MAINTENANCE_QUEUES:-maintenance}
      # NCBI E-utilities key (#494/#499): this container runs publication_date_backfill.
      NCBI_API_KEY: ${NCBI_API_KEY:-}
      NCBI_EUTILS_EMAIL: ${NCBI_EUTILS_EMAIL:-}
```

- [ ] **Step 4: Verify compose renders the keys**

Run: `docker compose config 2>/dev/null | grep -c NCBI_API_KEY`
Expected: `3` (once per api / worker / worker-maintenance). If Docker is unavailable, fall back to:
Run: `grep -c "NCBI_API_KEY:" docker-compose.yml`
Expected: `3`

- [ ] **Step 5: Commit**

```bash
git add docker-compose.yml
git commit -m "fix(compose): wire NCBI_API_KEY/NCBI_EUTILS_EMAIL into egress services (#499)

Compose uses explicit environment: maps, so .env's NCBI_API_KEY never reached
api/worker/worker-maintenance and publication ingestion ran anonymous (3 req/s).
pubtatornidd-cron is intentionally excluded (backend-only, DB enqueue, no egress).

Closes #499

Claude-Session: https://claude.ai/code/session_018mYSv9DRR457r8JCiBmok5"
```

---

## Task 2: Extract `pubmed-xml-parser.R` (behavior-preserving move) (#500)

**Files:**
- Create: `api/functions/pubmed-xml-parser.R`
- Modify: `api/functions/publication-functions.R` (remove the four moved functions; add a guard-source)
- Modify: `api/bootstrap/load_modules.R` (register the new module before `publication-functions.R`)
- Test: `api/tests/testthat/test-unit-publication-functions.R` (unchanged — must still pass)

**Interfaces:**
- Produces (module scope, sourced into global env): `empty_pubmed_article_tibble()`, `resolve_pubmed_date(year, month, day, medline_date = NA)`, `table_articles_from_xml(xml_string)`, `parse_pubmed_fetch_xml(xml_string)`. Signatures unchanged from today.
- Consumes: nothing new.

- [ ] **Step 1: Create the new module with the four functions moved verbatim**

Create `api/functions/pubmed-xml-parser.R` with this exact content (the four functions cut from `publication-functions.R`, headers preserved; `parse_pubmed_fetch_xml` kept as-is for now — the book union is added in Task 3... no: added in Step 6 below):

```r
# functions/pubmed-xml-parser.R
#
# PubMed EFetch XML -> publication-metadata tibble. Extracted from
# publication-functions.R (#500) so the parsing concern is a focused, testable
# unit and so <PubmedBookArticle> (GeneReviews) support can be added without
# pushing publication-functions.R past the 600-line ceiling.
#
# Output schema (one row per resolved record) is defined by
# empty_pubmed_article_tibble(). Consumed by info_from_pmid() and the
# publication_date_backfill job.

#' Empty parsed PubMed article tibble with the parser's output schema
#' @noRd
empty_pubmed_article_tibble <- function() {
  tibble::tibble(
    pmid = character(),
    doi = character(),
    title = character(),
    abstract = character(),
    jabbrv = character(),
    journal = character(),
    keywords = character(),
    year = character(),
    month = character(),
    day = character(),
    date_source = character(),
    lastname = character(),
    firstname = character(),
    address = character()
  )
}

#' Normalize a PubMed Year/Month/Day (+ MedlineDate) into ymd + a source flag
#' @noRd
resolve_pubmed_date <- function(year, month, day, medline_date = NA_character_) {
  blank <- function(x) {
    is.null(x) || length(x) == 0L || is.na(x) ||
      !nzchar(trimws(as.character(x)[1]))
  }
  month_to_num <- function(m) {
    if (blank(m)) return(NA_character_)
    m <- trimws(as.character(m)[1])
    if (grepl("^[0-9]{1,2}$", m)) {
      return(stringr::str_pad(m, 2, "left", pad = "0"))
    }
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
    return(list(
      year = NA_character_, month = NA_character_,
      day = NA_character_, date_source = "unknown"
    ))
  }

  month_norm <- month_to_num(month)
  day_norm <- if (blank(day) ||
                  !grepl("^[0-9]{1,2}$", trimws(as.character(day)[1]))) {
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

#' Parse <PubmedArticle> nodes into the publication metadata schema
#' @noRd
table_articles_from_xml <- function(pubmed_xml_data) {
  pmid_xml <- read_xml(pubmed_xml_data)
  articles <- xml_find_all(pmid_xml, "//PubmedArticle")
  if (length(articles) == 0L) {
    return(empty_pubmed_article_tibble())
  }

  text_first <- function(node, xpath, default = "") {
    value <- xml_text(xml_find_first(node, xpath))
    if (length(value) == 0L || is.na(value)) {
      return(default)
    }
    value
  }

  text_all <- function(node, xpath) {
    values <- xml_text(xml_find_all(node, xpath))
    values[!is.na(values)]
  }

  date_part <- function(article, part) {
    xpath <- paste0(
      ".//PubMedPubDate[@PubStatus = 'pubmed' or @Pubstatus = 'pubmed']/",
      part
    )
    value <- text_first(article, xpath, default = NA_character_)
    if (is.na(value)) {
      value <- text_first(article, paste0(".//Article/Journal/JournalIssue/PubDate/", part),
        default = NA_character_
      )
    }
    value
  }

  purrr::map_dfr(articles, function(article) {
    doi <- text_first(article, ".//Article/ELocationID[@EIdType = 'doi']",
      default = NA_character_
    )
    if (is.na(doi)) {
      doi <- text_first(article, ".//ArticleId[@EIdType = 'doi']",
        default = NA_character_
      )
    }
    if (is.na(doi)) {
      doi <- text_first(article, ".//ArticleId[@IdType = 'doi' and not(ancestor::ReferenceList)]",
        default = ""
      )
    }

    lastname <- text_first(article, ".//AuthorList/Author[1]/LastName")
    firstname <- text_first(article, ".//AuthorList/Author[1]/ForeName")
    collective <- text_first(article, ".//AuthorList/Author[1]/CollectiveName",
      default = NA_character_
    )
    if ((lastname == "" || firstname == "") && !is.na(collective)) {
      lastname <- collective
      firstname <- collective
    }

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

    mesh <- text_all(article, ".//DescriptorName")
    keyword <- text_all(article, ".//Keyword")

    as_tibble(list(
      pmid = text_first(article, ".//MedlineCitation/PMID"),
      doi = doi,
      title = str_c(text_all(article, ".//Article/ArticleTitle"), collapse = " "),
      abstract = str_c(text_all(article, ".//AbstractText"), collapse = " "),
      jabbrv = text_first(article, ".//Article/Journal/ISOAbbreviation"),
      journal = text_first(article, ".//Article/Journal/Title"),
      keywords = str_c(unique(str_squish(c(mesh, keyword))), collapse = "; "),
      year = pub_date$year,
      month = pub_date$month,
      day = pub_date$day,
      date_source = pub_date$date_source,
      lastname = lastname,
      firstname = firstname,
      address = str_c(text_all(article, ".//AuthorList/Author[1]/AffiliationInfo"),
        collapse = "; "
      )
    ))
  })
}

#' Parse PubMed EFetch XML and normalize empty/no-article responses
#' @noRd
parse_pubmed_fetch_xml <- function(pubmed_xml_data) {
  parsed <- tryCatch(
    table_articles_from_xml(pubmed_xml_data),
    error = function(e) empty_pubmed_article_tibble()
  )
  if (nrow(parsed) == 0L || all(is.na(parsed$pmid))) {
    return(empty_pubmed_article_tibble())
  }
  parsed
}
```

- [ ] **Step 2: Remove the four moved functions from `publication-functions.R`**

In `api/functions/publication-functions.R`, delete these four definitions (now living in the new module): `empty_pubmed_article_tibble` (currently ~L156–173), `parse_pubmed_fetch_xml` (~L177–186), `resolve_pubmed_date` (~L298–348), and `table_articles_from_xml` (~L350–446). Leave everything else (`normalize_pubmed_ids`, `pubmed_eutils_query`, `pubmed_min_request_interval`, `pubmed_esearch_count`, `pubmed_fetch_xml`, `check_pmid`, `new_publication`, `info_from_pmid`) untouched.

- [ ] **Step 3: Add a guard-source for the new module at the top of `publication-functions.R`**

Directly below the existing `genereviews-functions.R` guard block (~L4–9), add (mirroring that pattern):

```r
# Load the PubMed XML parser (table_articles_from_xml / parse_pubmed_fetch_xml /
# resolve_pubmed_date / empty_pubmed_article_tibble / table_book_articles_from_xml)
# if not already sourced.
if (!exists("table_articles_from_xml", mode = "function")) {
  if (file.exists("functions/pubmed-xml-parser.R")) {
    source("functions/pubmed-xml-parser.R", local = TRUE)
  }
}
```

- [ ] **Step 4: Register the module in `load_modules.R` before `publication-functions.R`**

In `api/bootstrap/load_modules.R`, add `"functions/pubmed-xml-parser.R",` on the line immediately **before** `"functions/publication-functions.R",` (currently L93):

```r
    "functions/pubmed-xml-parser.R",
    "functions/publication-functions.R",
```

- [ ] **Step 5: Run the existing parser + backfill unit tests (refactor safety)**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"`
Expected: PASS (all existing `table_articles_from_xml` tests still green — the move is behavior-preserving; the guard-source loads the functions from the new file).

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-date-backfill.R')"`
Expected: PASS or the pre-existing DB-gated `skip_if_no_test_db` skips; no NEW failures.

- [ ] **Step 6: Commit**

```bash
git add api/functions/pubmed-xml-parser.R api/functions/publication-functions.R api/bootstrap/load_modules.R
git commit -m "refactor(api): extract pubmed-xml-parser.R from publication-functions.R (#500)

Behavior-preserving move of the PubMed EFetch XML parsing concern into a focused
module so <PubmedBookArticle> support can be added without crossing the 600-line
ceiling. Registered in load_modules.R; guard-sourced for direct-source tests.

Claude-Session: https://claude.ai/code/session_018mYSv9DRR457r8JCiBmok5"
```

---

## Task 3: Parse `<PubmedBookArticle>` (GeneReviews) records (#500)

**Files:**
- Modify: `api/functions/pubmed-xml-parser.R` (add `table_book_articles_from_xml`; union it into `parse_pubmed_fetch_xml`)
- Test: `api/tests/testthat/test-unit-publication-functions.R` (add `create_pubmed_book_xml` helper + book/mixed tests)

**Interfaces:**
- Consumes: `empty_pubmed_article_tibble()`, `resolve_pubmed_date()`, `table_articles_from_xml()` (Task 2).
- Produces: `table_book_articles_from_xml(xml_string)` → tibble with the same 14-column schema, one row per `//PubmedBookArticle`. `parse_pubmed_fetch_xml()` now returns the union of article + book rows.

- [ ] **Step 1: Add the book-XML test helper and failing tests**

In `api/tests/testthat/test-unit-publication-functions.R`, after the existing `create_pubmed_xml` helper (~L179), add this helper:

```r
create_pubmed_book_xml <- function(
  pmid = "20301425",
  title = "BRCA1- and BRCA2-Associated Hereditary Breast and Ovarian Cancer",
  book_title = "GeneReviews",
  author_last = "Petrucelli",
  author_first = "Nadine",
  include_contribution_date = TRUE,
  contribution_year = "1998", contribution_month = "09", contribution_day = "04",
  include_pubmed_history = FALSE,
  pubmed_year = "2024", pubmed_month = "12", pubmed_day = "12",
  book_pubdate_year = "1993"
) {
  contribution <- if (include_contribution_date) {
    sprintf(
      "<ContributionDate><Year>%s</Year><Month>%s</Month><Day>%s</Day></ContributionDate>",
      contribution_year, contribution_month, contribution_day
    )
  } else {
    ""
  }
  pubmed_history <- if (include_pubmed_history) {
    sprintf(paste0(
      "<PubmedBookData><History>",
      "<PubMedPubDate PubStatus=\"pubmed\"><Year>%s</Year><Month>%s</Month><Day>%s</Day></PubMedPubDate>",
      "</History></PubmedBookData>"
    ), pubmed_year, pubmed_month, pubmed_day)
  } else {
    ""
  }
  sprintf('<?xml version="1.0" encoding="UTF-8"?>
<PubmedArticleSet>
  <PubmedBookArticle>
    <BookDocument>
      <PMID>%s</PMID>
      <Book>
        <BookTitle>%s</BookTitle>
        <PubDate><Year>%s</Year></PubDate>
      </Book>
      <ArticleTitle>%s</ArticleTitle>
      <Abstract><AbstractText Label="DIAGNOSIS/TESTING">Diagnostic summary.</AbstractText></Abstract>
      <AuthorList Type="authors">
        <Author><LastName>%s</LastName><ForeName>%s</ForeName></Author>
      </AuthorList>
      %s
    </BookDocument>
    %s
  </PubmedBookArticle>
</PubmedArticleSet>',
    pmid, book_title, book_pubdate_year, title, author_last, author_first,
    contribution, pubmed_history)
}
```

Then add these tests at the end of the file:

```r
# ============================================================================
# table_book_articles_from_xml() Tests - GeneReviews <PubmedBookArticle> (#500)
# ============================================================================

test_that("book parser extracts pmid, title, journal, author", {
  result <- table_book_articles_from_xml(create_pubmed_book_xml())
  expect_equal(nrow(result), 1L)
  expect_equal(result$pmid[1], "20301425")
  expect_equal(result$title[1],
    "BRCA1- and BRCA2-Associated Hereditary Breast and Ovarian Cancer")
  expect_equal(result$journal[1], "GeneReviews")
  expect_equal(result$lastname[1], "Petrucelli")
  expect_equal(result$firstname[1], "Nadine")
})

test_that("book parser uses ContributionDate as a verified pubmed date", {
  result <- table_book_articles_from_xml(create_pubmed_book_xml())
  expect_equal(result$date_source[1], "pubmed")
  expect_equal(paste(result$year[1], result$month[1], result$day[1], sep = "-"),
    "1998-09-04")
})

test_that("book parser falls back to PubMedPubDate when no ContributionDate", {
  xml <- create_pubmed_book_xml(include_contribution_date = FALSE,
                                include_pubmed_history = TRUE)
  result <- table_book_articles_from_xml(xml)
  expect_equal(result$date_source[1], "pubmed")
  expect_equal(paste(result$year[1], result$month[1], result$day[1], sep = "-"),
    "2024-12-12")
})

test_that("book parser falls back to Book/PubDate year (partial) when no other date", {
  xml <- create_pubmed_book_xml(include_contribution_date = FALSE,
                                include_pubmed_history = FALSE)
  result <- table_book_articles_from_xml(xml)
  expect_equal(result$date_source[1], "pubmed_partial")
  expect_equal(result$year[1], "1993")
})

test_that("parse_pubmed_fetch_xml returns BOTH article and book rows from a mixed set", {
  mixed <- paste0(
    '<?xml version="1.0" encoding="UTF-8"?>\n<PubmedArticleSet>\n',
    '<PubmedArticle><MedlineCitation><PMID>11112222</PMID><Article>',
    '<ArticleTitle>Regular Article</ArticleTitle>',
    '<Journal><Title>J Test</Title></Journal></Article></MedlineCitation>',
    '<PubmedData><History><PubMedPubDate Pubstatus="pubmed">',
    '<Year>2020</Year><Month>01</Month><Day>15</Day></PubMedPubDate>',
    '</History></PubmedData></PubmedArticle>\n',
    '<PubmedBookArticle><BookDocument><PMID>20301425</PMID>',
    '<Book><BookTitle>GeneReviews</BookTitle><PubDate><Year>1993</Year></PubDate></Book>',
    '<ArticleTitle>A GeneReview</ArticleTitle>',
    '<ContributionDate><Year>1998</Year><Month>09</Month><Day>04</Day></ContributionDate>',
    '</BookDocument></PubmedBookArticle>\n',
    '</PubmedArticleSet>')
  result <- parse_pubmed_fetch_xml(mixed)
  expect_setequal(result$pmid, c("11112222", "20301425"))
})
```

- [ ] **Step 2: Run the new tests to confirm they fail**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"`
Expected: FAIL — `could not find function "table_book_articles_from_xml"` (and the mixed-set test returns only 1 row).

- [ ] **Step 3: Implement `table_book_articles_from_xml` in the parser module**

In `api/functions/pubmed-xml-parser.R`, add this function directly after `table_articles_from_xml`:

```r
#' Parse <PubmedBookArticle>/<BookDocument> nodes (GeneReviews / NCBI Bookshelf)
#'
#' EFetch on db=pubmed returns GeneReviews chapters as <PubmedBookArticle>, which
#' table_articles_from_xml (//PubmedArticle only) ignores (#500). Date ladder,
#' first present wins, then resolve_pubmed_date(): (1) BookDocument/ContributionDate
#' (the chapter's authored/revision date -> a verified full date), (2)
#' PubmedBookData/History/PubMedPubDate[@PubStatus='pubmed'], (3) Book/PubDate
#' (often year-only -> pubmed_partial). Reuses the pubmed/pubmed_partial source
#' vocabulary. Modeled on the proven ../genereviews-link _parse_book_article.
#' @noRd
table_book_articles_from_xml <- function(pubmed_xml_data) {
  book_xml <- read_xml(pubmed_xml_data)
  books <- xml_find_all(book_xml, "//PubmedBookArticle")
  if (length(books) == 0L) {
    return(empty_pubmed_article_tibble())
  }

  text_first <- function(node, xpath, default = "") {
    value <- xml_text(xml_find_first(node, xpath))
    if (length(value) == 0L || is.na(value)) {
      return(default)
    }
    value
  }
  text_all <- function(node, xpath) {
    values <- xml_text(xml_find_all(node, xpath))
    values[!is.na(values)]
  }

  book_date_parts <- function(book) {
    bases <- c(
      ".//BookDocument/ContributionDate",
      ".//PubmedBookData/History/PubMedPubDate[@PubStatus = 'pubmed' or @Pubstatus = 'pubmed']",
      ".//BookDocument/Book/PubDate"
    )
    for (base in bases) {
      yr <- text_first(book, paste0(base, "/Year"), default = NA_character_)
      if (!is.na(yr) && nzchar(yr)) {
        return(list(
          year = yr,
          month = text_first(book, paste0(base, "/Month"), default = NA_character_),
          day = text_first(book, paste0(base, "/Day"), default = NA_character_)
        ))
      }
    }
    list(year = NA_character_, month = NA_character_, day = NA_character_)
  }

  purrr::map_dfr(books, function(book) {
    parts <- book_date_parts(book)
    pub_date <- resolve_pubmed_date(parts$year, parts$month, parts$day)

    title <- text_first(book, ".//BookDocument/ArticleTitle")
    if (!nzchar(title)) title <- text_first(book, ".//BookDocument/BookTitle")
    if (!nzchar(title)) title <- text_first(book, ".//BookDocument/Book/BookTitle")

    book_title <- text_first(book, ".//BookDocument/Book/BookTitle")
    journal <- if (nzchar(book_title)) book_title else "GeneReviews"

    lastname <- text_first(book, ".//AuthorList[@Type = 'authors']/Author[1]/LastName")
    firstname <- text_first(book, ".//AuthorList[@Type = 'authors']/Author[1]/ForeName")
    if (lastname == "" && firstname == "") {
      lastname <- text_first(book, ".//AuthorList/Author[1]/LastName")
      firstname <- text_first(book, ".//AuthorList/Author[1]/ForeName")
    }
    collective <- text_first(book, ".//AuthorList/Author[1]/CollectiveName",
      default = NA_character_
    )
    if ((lastname == "" || firstname == "") && !is.na(collective)) {
      lastname <- collective
      firstname <- collective
    }

    as_tibble(list(
      pmid = text_first(book, ".//BookDocument/PMID"),
      doi = "",
      title = title,
      abstract = str_c(text_all(book, ".//Abstract/AbstractText"), collapse = " "),
      jabbrv = "",
      journal = journal,
      keywords = "",
      year = pub_date$year,
      month = pub_date$month,
      day = pub_date$day,
      date_source = pub_date$date_source,
      lastname = lastname,
      firstname = firstname,
      address = ""
    ))
  })
}
```

- [ ] **Step 4: Union book rows into `parse_pubmed_fetch_xml`**

In `api/functions/pubmed-xml-parser.R`, replace the whole `parse_pubmed_fetch_xml` function body with:

```r
#' Parse PubMed EFetch XML (both <PubmedArticle> and <PubmedBookArticle>) and
#' normalize empty responses. A mixed EFetch batch contains both node types as
#' siblings under <PubmedArticleSet>; //PubmedArticle and //PubmedBookArticle are
#' disjoint, so no record is double-counted.
#' @noRd
parse_pubmed_fetch_xml <- function(pubmed_xml_data) {
  articles <- tryCatch(
    table_articles_from_xml(pubmed_xml_data),
    error = function(e) empty_pubmed_article_tibble()
  )
  books <- tryCatch(
    table_book_articles_from_xml(pubmed_xml_data),
    error = function(e) empty_pubmed_article_tibble()
  )
  parsed <- dplyr::bind_rows(articles, books)
  if (nrow(parsed) == 0L || all(is.na(parsed$pmid))) {
    return(empty_pubmed_article_tibble())
  }
  parsed
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-functions.R')"`
Expected: PASS (all existing article tests + the five new book/mixed tests).

- [ ] **Step 6: Commit**

```bash
git add api/functions/pubmed-xml-parser.R api/tests/testthat/test-unit-publication-functions.R
git commit -m "fix(api): parse GeneReviews <PubmedBookArticle> records (#500)

table_articles_from_xml matched //PubmedArticle only, so GeneReviews chapters
(returned by EFetch as <PubmedBookArticle>/<BookDocument>) yielded 0 rows and
were permanently 'not retrievable'. Add table_book_articles_from_xml with a
ContributionDate -> PubMedPubDate -> Book/PubDate date ladder (reusing the
pubmed/pubmed_partial vocabulary) and union it into parse_pubmed_fetch_xml.

Claude-Session: https://claude.ai/code/session_018mYSv9DRR457r8JCiBmok5"
```

---

## Task 4: Backfill unresolved-vs-failed resilience (#500)

**Files:**
- Modify: `api/functions/publication-date-backfill.R` (skip classification + guard condition + return fields)
- Modify: `api/functions/async-job-handlers.R` (update the stale summary-fields comment, ~L814–815)
- Modify: `db/updates/backfill_publication_dates.R` (surface the failed/unresolved split in the CLI "done" message)
- Test: `api/tests/testthat/test-unit-publication-date-backfill.R` (add the parse-empty-is-not-outage test)

**Interfaces:**
- Consumes: `info_from_pmid()` (raises `publication_fetch_error` for parse-empty; generic `error` for transport).
- Produces: `backfill_publication_dates_run(...)` return list keeps `targeted/verified/partial/unresolved/written/skipped_count/skipped_pmids/skipped_errors/dry_run` and adds `failed_count`, `unresolved_skip_count`, `failed_pmids`. Systemic-outage guard now fires on `failed_count >= targeted`.

- [ ] **Step 1: Add the failing test (parse-empty must NOT be a systemic outage)**

In `api/tests/testthat/test-unit-publication-date-backfill.R`, add after the existing systemic-outage test (~L65):

```r
test_that("backfill treats parse-empty PMIDs as unresolved, not a systemic outage", {
  # #500: a genuinely unresolvable PMID (info_from_pmid raises
  # publication_fetch_error after a clean fetch) is a DATA condition -> the run
  # succeeds with unresolved counted and nothing written; it must NOT raise the
  # transport-only systemic-outage error.
  skip_if_no_test_db()
  source(file.path(get_api_dir(), "functions", "publication-functions.R"), local = FALSE)
  source(file.path(get_api_dir(), "functions", "publication-date-backfill.R"), local = FALSE)

  old_info <- get("info_from_pmid", envir = .GlobalEnv)
  assign("info_from_pmid", function(pmid_value, ...) {
    rlang::abort("PMIDs not retrievable from PubMed: PMID:999103",
                 class = "publication_fetch_error")
  }, envir = .GlobalEnv)
  withr::defer(assign("info_from_pmid", old_info, envir = .GlobalEnv))

  with_test_db_transaction({
    conn <- getOption(".test_db_con")
    skip_if_missing_publication_backfill_schema(conn)
    seed_primary_approved_publication(conn, publication_id = "PMID:999103", source = NULL)
    res <- backfill_publication_dates_run(conn, dry_run = FALSE, manage_transaction = FALSE)
    expect_equal(res$verified, 0L)
    expect_equal(res$written, 0L)
    expect_gte(res$unresolved_skip_count, 1L)
    expect_equal(res$failed_count, 0L)
    got <- DBI::dbGetQuery(conn,
      "SELECT publication_date_source FROM publication WHERE publication_id = 'PMID:999103'")
    expect_true(is.na(got$publication_date_source))
  })
})
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-date-backfill.R')"`
Expected: FAIL — the run currently raises `publication_backfill_systemic_failure` (old guard: `skipped_count >= targeted`), so `res` is never returned.
(If no test DB is configured this test skips; in that case run the change under `make test-api` in CI parity, and rely on the logic review.)

- [ ] **Step 3: Split the skip buckets in `publication-date-backfill.R`**

Replace the current skip block (`skipped`/`skipped_errors`/`record_skip`/`fetch_one`, ~L121–139) with:

```r
  # Per-PMID fallback (lifted verbatim): a chunk error falls back to single-PMID
  # fetches so one bad PMID does not fail the whole chunk/job. Skips are split by
  # CAUSE (#500): a publication_fetch_error is a DATA condition (PMID fetched but
  # unresolvable / no parseable record) -> `unresolved`; any other error is an
  # INFRA condition (transport/HTTP/timeout) -> `failed`. Only a wholesale infra
  # outage fails the job.
  unresolved_ids <- character()
  unresolved_errors <- character()
  failed_ids <- character()
  failed_errors <- character()
  record_unresolved <- function(publication_id, e) {
    unresolved_ids <<- c(unresolved_ids, publication_id)
    unresolved_errors <<- c(unresolved_errors, conditionMessage(e))
    tibble::tibble()
  }
  record_failed <- function(publication_id, e) {
    failed_ids <<- c(failed_ids, publication_id)
    failed_errors <<- c(failed_errors, conditionMessage(e))
    tibble::tibble()
  }
  fetch_one <- function(publication_id) {
    on.exit(Sys.sleep(ncbi_delay), add = TRUE)
    tryCatch(
      {
        row <- info_from_pmid(publication_id)
        row$publication_id <- paste0("PMID:", sub("^PMID:", "", publication_id))
        row
      },
      publication_fetch_error = function(e) record_unresolved(publication_id, e),
      error = function(e) record_failed(publication_id, e)
    )
  }
```

(`fetch_chunk` right below is unchanged — its `publication_fetch_error`/`error` handlers both still fall back to `purrr::map_dfr(publication_ids, fetch_one)`, which now classifies each PMID.)

- [ ] **Step 4: Change the guard + return fields**

Replace the counters/guard/return block (~L218–254, from `skipped_unique <- unique(skipped)` through the final `list(...)`) with:

```r
  all_skipped_ids <- unique(c(failed_ids, unresolved_ids))
  skipped_count <- length(all_skipped_ids)
  failed_count <- length(unique(failed_ids))
  unresolved_skip_count <- length(unique(unresolved_ids))

  # Fail observably only on a systemic TRANSPORT/INFRA outage: every targeted PMID
  # hit a non-classed error (NCBI down, worker egress broken, info_from_pmid
  # unavailable). A batch that is entirely genuinely-unresolvable (parse-empty ->
  # publication_fetch_error, e.g. an all-book/withdrawn target set) completes as a
  # success with 0 verified and N unresolved (#500) — it must not false-fail.
  if (targeted > 0L && failed_count >= targeted) {
    stop(structure(
      class = c("publication_backfill_systemic_failure", "error", "condition"),
      list(
        message = sprintf(
          paste0("verified publication-date backfill: all %d targeted PMIDs failed ",
                 "to fetch (systemic outage; no rows written). First error: %s"),
          targeted,
          if (length(failed_errors)) failed_errors[[1]] else "unknown"
        ),
        call = sys.call(-1)
      )
    ))
  }

  list(
    targeted = targeted,
    verified = as.integer(verified),
    partial = as.integer(partial),
    unresolved = as.integer(unresolved),
    written = as.integer(written),
    skipped_count = as.integer(skipped_count),
    failed_count = as.integer(failed_count),
    unresolved_skip_count = as.integer(unresolved_skip_count),
    skipped_pmids = utils::head(all_skipped_ids, 50L),
    failed_pmids = utils::head(unique(failed_ids), 50L),
    skipped_errors = utils::head(unique(c(failed_errors, unresolved_errors)), 5L),
    dry_run = FALSE
  )
```

- [ ] **Step 5: Update the stale handler comment**

In `api/functions/async-job-handlers.R` (~L814–815), replace:

```r
# failure returns success with skipped_count/skipped_pmids/skipped_errors in the summary.
```

with:

```r
# failure returns success with skipped_count / failed_count / unresolved_skip_count
# and failed_pmids/skipped_pmids/skipped_errors in the summary. Only a wholesale
# transport outage (failed_count >= targeted) marks the job failed; a batch that is
# entirely genuinely-unresolvable (parse-empty) succeeds with unresolved counted.
```

- [ ] **Step 6: Surface the split in the operator CLI**

In `db/updates/backfill_publication_dates.R`, replace the final "done" `message(sprintf(...))` (~L94–97) with (explicit NULL guards because the `targeted == 0` early return omits these fields):

```r
  failed_n <- if (is.null(summary$failed_count)) 0L else summary$failed_count
  unresolved_skips_n <- if (is.null(summary$unresolved_skip_count)) 0L else summary$unresolved_skip_count
  message(sprintf(
    "[backfill] done: targeted=%d verified=%d partial=%d unresolved=%d (failed=%d unresolved_skips=%d)",
    summary$targeted, summary$verified, summary$partial, summary$unresolved,
    failed_n, unresolved_skips_n
  ))
```

- [ ] **Step 7: Run the backfill tests to verify pass**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-publication-date-backfill.R')"`
Expected: PASS — the new parse-empty test succeeds; the existing "every targeted PMID errors" test (stub raises a generic `stop()` → `failed`) still raises `publication_backfill_systemic_failure`; the "writes both columns" and dry-run tests still pass.

- [ ] **Step 8: Commit**

```bash
git add api/functions/publication-date-backfill.R api/functions/async-job-handlers.R db/updates/backfill_publication_dates.R api/tests/testthat/test-unit-publication-date-backfill.R
git commit -m "fix(api): backfill splits unresolved (data) vs failed (infra) (#500)

The systemic-outage guard fired on skipped_count >= targeted, conflating a
genuinely-unresolvable target set (parse-empty publication_fetch_error, e.g. an
all-GeneReviews batch after the non-book targets were verified) with a transport
outage — failing the whole job with 0 writes on every run. Classify per-PMID
failures by cause and fire the guard only on transport failure (failed_count >=
targeted); persist everything that resolved.

Claude-Session: https://claude.ai/code/session_018mYSv9DRR457r8JCiBmok5"
```

---

## Task 5: Docs — AGENTS.md publication-ingestion note (#499/#500)

**Files:**
- Modify: `AGENTS.md` (the publication-ingestion bullet under "Stack-Specific Gotchas")

**Interfaces:** none (documentation).

- [ ] **Step 1: Extend the publication-ingestion bullet**

In `AGENTS.md`, at the end of the bullet that begins "API publication ingestion uses direct NCBI E-utilities helpers…", append these sentences:

```markdown
 The shared PubMed EFetch XML parser now lives in `api/functions/pubmed-xml-parser.R` (extracted from `publication-functions.R`, registered in `bootstrap/load_modules.R` before it) and parses **both** `<PubmedArticle>` and `<PubmedBookArticle>` (GeneReviews / NCBI Bookshelf) records; book records get a date via a `ContributionDate` → `PubMedPubDate[@PubStatus='pubmed']` → `Book/PubDate` ladder, reusing the `pubmed`/`pubmed_partial` source vocabulary (no new value), so GeneReviews chapters can finally get a verified date (#500). The `publication_date_backfill` classifies per-PMID failures as `unresolved` (parse-empty / `publication_fetch_error` — a data condition) vs `failed` (transport/infra) and fires the systemic-outage guard only when `failed_count >= targeted`; an all-unresolvable target set (e.g. all GeneReviews) now completes as a success with `unresolved` counted instead of false-failing (#500). `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` must be mapped into the `api`, `worker`, and `worker-maintenance` compose `environment:` blocks (#499) — compose uses explicit env maps, so a bare `.env` value is otherwise invisible to the containers; `pubtatornidd-cron` is excluded (backend-only, no egress).
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs(agents): note PubmedBookArticle parsing + backfill split + NCBI compose wiring (#499, #500)

Claude-Session: https://claude.ai/code/session_018mYSv9DRR457r8JCiBmok5"
```

---

## Task 6: Release bump v0.27.3

**Files:**
- Modify: `CHANGELOG.md` (new `## [0.27.3]` section)
- Modify: `app/package.json` (`"version": "0.27.3"`)
- Modify: `api/version_spec.json` (`"version": "0.27.3"`)

**Interfaces:** none.

- [ ] **Step 1: Add the CHANGELOG section**

In `CHANGELOG.md`, insert directly below the `## [Unreleased]` line:

```markdown

## [0.27.3] — 2026-07-03

Post-deploy fix release completing the `publication_date_backfill` work from #494. Closes #499. Closes #500.

### Fixed

- **NCBI API key now reaches the containers** (#499, follow-on to #494/#496): `docker-compose.yml` uses explicit `environment:` maps, so `NCBI_API_KEY`/`NCBI_EUTILS_EMAIL` in `.env` were never visible inside `api`, `worker`, or `worker-maintenance` — the backfill still ran anonymous (3 req/s). The two vars are now mapped into all three egress services (mirroring `GEMINI_API_KEY`). `pubtatornidd-cron` is intentionally excluded (backend-only network, DB-only enqueue, no egress). Set `NCBI_API_KEY` in the deployed `.env` and restart the workers.
- **GeneReviews publication dates can finally be verified** (#500, real cause behind #494): the shared PubMed EFetch parser matched `//PubmedArticle` only, so GeneReviews chapters — returned by EFetch as `<PubmedBookArticle>/<BookDocument>` and a large, permanent share of SysNDD references (~393 of ~553 unverified) — yielded 0 rows and were permanently "not retrievable". Once the non-book targets were verified, every subsequent run targeted only the unresolvable book records and the systemic-outage guard failed the whole job with 0 writes, on every run. The parser (now in `api/functions/pubmed-xml-parser.R`) parses book records with a `ContributionDate` → `PubMedPubDate[@PubStatus='pubmed']` → `Book/PubDate` date ladder (reusing the `pubmed`/`pubmed_partial` vocabulary), and the backfill now distinguishes `unresolved` (parse-empty data condition) from `failed` (transport/infra), firing the systemic-outage guard only on wholesale transport failure. Worker-executed code changed — restart `worker`/`worker-maintenance` after deploy.
```

- [ ] **Step 2: Bump the two version files**

In `app/package.json` change `"version": "0.27.2"` → `"version": "0.27.3"`.
In `api/version_spec.json` change `"version": "0.27.2"` → `"version": "0.27.3"`.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md app/package.json api/version_spec.json
git commit -m "chore(release): v0.27.3 — NCBI compose wiring (#499) + GeneReviews backfill (#500)

Claude-Session: https://claude.ai/code/session_018mYSv9DRR457r8JCiBmok5"
```

---

## Task 7: Full verification gate

**Files:** none (gate only).

- [ ] **Step 1: Fast API gate + file-size ratchet**

Run: `make code-quality-audit`
Expected: PASS — `publication-functions.R` is now under 600 lines; `pubmed-xml-parser.R` is well under; no newly-flagged file.

Run: `make test-api-fast`
Expected: PASS (or documented pre-existing skips/failures noted in memory: `test-llm-benchmark.R`, `test-llm-judge.R`, and the 4 pre-existing `test-unit-entity-creation.R` status-approval failures — these are unrelated to this change).

- [ ] **Step 2: API lint**

Run: `make lint-api`
Expected: PASS for the changed files (`pubmed-xml-parser.R`, `publication-functions.R`, `publication-date-backfill.R`).

- [ ] **Step 3: Compose render check (if Docker available)**

Run: `docker compose config 2>/dev/null | grep -c NCBI_API_KEY`
Expected: `3`.

- [ ] **Step 4 (operator, prod-like — optional here, done at deploy): end-to-end backfill**

Set `NCBI_API_KEY` in the worker `.env`, restart `worker-maintenance`, enqueue a `publication_date_backfill`. Expect GeneReviews book PMIDs to move to `pubmed`/`pubmed_partial` and the job to complete `success` with non-zero `verified`/`written` and a non-empty `unresolved_skip_count` only for genuinely dateless PMIDs.

---

## Self-Review

**Spec coverage:**
- #499 compose wiring → Task 1. `.env.example` already has the keys (spec non-goal) — no task needed. ✓
- #500 parser (book records, ContributionDate ladder, vocabulary reuse) → Tasks 2–3. ✓
- #500 resilience (unresolved vs failed, guard on transport only, persist resolved) → Task 4. ✓
- Module extraction under the 600 ceiling → Task 2 + Task 7 Step 1. ✓
- Tests (book, mixed, parse-empty-not-outage) → Tasks 3 & 4. ✓
- Docs (AGENTS.md) + CHANGELOG + version bump → Tasks 5 & 6. ✓
- Verification (`test-api-fast`, `code-quality-audit`, `docker compose config`) → Task 7. ✓

**Placeholder scan:** No TBD/TODO; every code step shows complete code; test bodies are concrete. ✓

**Type/name consistency:** `table_book_articles_from_xml` (Tasks 3), `parse_pubmed_fetch_xml` union (Task 3), `record_unresolved`/`record_failed`/`failed_count`/`unresolved_skip_count`/`failed_pmids` (Task 4 impl + test + handler comment + CLI) all consistent. `skipped_count`/`skipped_pmids`/`skipped_errors` retained for backward compatibility (operator CLI reads only `skipped`/`dry_run`/`targeted`/`verified`/`partial`/`unresolved`; frontend summary shape unbroken). ✓

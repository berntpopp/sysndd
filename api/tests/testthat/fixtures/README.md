# External-API test fixtures

This directory holds captured HTTP responses used by the R API test suite to
replay calls to third-party services without hitting the network. All fixtures
in the `pubmed/` and `pubtator/` subdirectories were recorded as part of
**Phase B B2** (`v11.0/phase-b/pubmed-pubtator-fixtures`) using the live
upstream APIs.

## Contract

- Every file committed here is a **real** upstream response captured via
  `httptest2::start_capturing()` wrapping a real `httr2::req_perform()` call.
  No hand-crafted JSON/XML is allowed — if you need a synthetic payload for a
  parser unit test, put it inline in the test file, not here.
- Each subdirectory (`pubmed/`, `pubtator/`) is gated by
  `skip_if_no_fixtures("<subdir>")` from `helper-fixtures.R`. If the directory
  is empty or contains only `.gitkeep`, the gate **fails the test loudly**
  (it does not silently skip).
- Placeholder files (`.gitkeep`, `.DS_Store`) do not count toward
  "directory is populated". See `helper-fixtures.R::.sysndd_fixture_placeholder_patterns`.
- Fixtures are replayed via `httptest2::with_mock_dir()` — see
  `helper-mock-apis.R::with_pubmed_mock()` and `with_pubtator_mock()`.

## How to refresh fixtures

Fixtures are refreshed out-of-band by a developer explicitly running:

```bash
make refresh-fixtures
```

The target is deliberately **not** part of `make ci-local` — we never let CI
silently overwrite committed fixtures by hitting live APIs. Running
`make refresh-fixtures` uses the `sysndd-api:latest` Docker image (which has
`httr2` + `httptest2` + `easyPubMed` + `jsonlite` preinstalled, bypassing
host-side R package install pain on Ubuntu questing). The image is mounted
with the fixtures directory so writes land in-tree.

Under the hood, the target runs:

```bash
docker run --rm --network=host \
  -v "$(pwd)/api/tests/testthat/fixtures:/fixtures" \
  -v "$(pwd)/api/scripts:/scripts:ro" \
  sysndd-api:latest \
  Rscript /scripts/capture-external-fixtures.R /fixtures
```

See `api/scripts/capture-external-fixtures.R` for the canonical capture
script. That script stacks the target subdirectory onto
`httptest2::.mockPaths()` and calls `httptest2::start_capturing()` so saved
files land under the repository's fixture tree.

## Fixture inventory

All fixtures below were recorded on **2026-04-11** by
`api/scripts/capture-external-fixtures.R` against the live NCBI public APIs.
Each file is an `httr2_response` `structure(...)` R object serialized by
`httptest2::save_response(..., simplify = FALSE)`.

### `pubmed/` — NCBI eUtils PubMed API

**Upstream API version:** NCBI E-utilities (eSearch / eFetch), as served by
`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/` on 2026-04-11. eUtils is
versionless but stable; see
<https://www.ncbi.nlm.nih.gov/books/NBK25497/#chapter2.Usage_Guidelines_and_Requiremen>.

| Fixture file | Recorded | Request | Purpose |
|---|---|---|---|
| `eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi-6ff89c.R` | 2026-04-11 | `GET esearch.fcgi?db=pubmed&term=33054928[PMID]&retmode=xml` | Happy-path PMID lookup (count = 1) used by `check_pmid()`. |
| `eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi-37eadf.R` | 2026-04-11 | `GET esearch.fcgi?db=pubmed&term=xyzzy12345nonexistent98765[PMID]&retmode=xml` | Empty-result path for `check_pmid()` (count = 0). |
| `eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi-ba25ae.R` | 2026-04-11 | `GET efetch.fcgi?db=pubmed&id=33054928&retmode=xml&rettype=xml` | Full XML payload of one PubMed article — used by `fetch_pubmed_data()` / `table_articles_from_xml()`. |

**Capture commands (exact):** see `api/scripts/capture-external-fixtures.R`
section `[1/2]`. In condensed form:

```r
library(httr2); library(httptest2)
httptest2::.mockPaths("api/tests/testthat/fixtures/pubmed")
httptest2::start_capturing(simplify = FALSE)

request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi") |>
  req_url_query(db = "pubmed", term = "33054928[PMID]", retmode = "xml") |>
  req_user_agent("sysndd-ci-fixture-capture/1.0") |>
  req_perform()

request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi") |>
  req_url_query(db = "pubmed", id = "33054928", retmode = "xml", rettype = "xml") |>
  req_user_agent("sysndd-ci-fixture-capture/1.0") |>
  req_perform()

request("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi") |>
  req_url_query(db = "pubmed", term = "xyzzy12345nonexistent98765[PMID]", retmode = "xml") |>
  req_user_agent("sysndd-ci-fixture-capture/1.0") |>
  req_perform()

httptest2::stop_capturing()
```

### `pubtator/` — NCBI PubTator3 API

**Upstream API version:** PubTator3 (BioCJSON format), as served by
`https://www.ncbi.nlm.nih.gov/research/pubtator3-api/` on 2026-04-11. See
<https://www.ncbi.nlm.nih.gov/research/pubtator3/api>.

| Fixture file | Recorded | Request | Purpose |
|---|---|---|---|
| `www.ncbi.nlm.nih.gov/research/pubtator3-api/search-c90ee9.R` | 2026-04-11 | `GET search/?text=BRCA1&page=1` | Happy-path search returning `total_pages > 0`. Used by `pubtator_v3_total_pages_from_query()` / `pubtator_v3_pmids_from_request()`. |
| `www.ncbi.nlm.nih.gov/research/pubtator3-api/search-a64585.R` | 2026-04-11 | `GET search/?text=xyzzy12345nonexistent98765&page=1` | Empty-result search path (`total_pages = 0`, `count = 0`). |
| `www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocjson-93f9ce.R` | 2026-04-11 | `GET publications/export/biocjson?pmids=33054928` | Full annotated BioCJSON document for PMID 33054928. Used by `pubtator_parse_biocjson()`. |

**Capture commands (exact):** see `api/scripts/capture-external-fixtures.R`
section `[2/2]`. In condensed form:

```r
library(httr2); library(httptest2)
httptest2::.mockPaths("api/tests/testthat/fixtures/pubtator")
httptest2::start_capturing(simplify = FALSE)

request("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/search/") |>
  req_url_query(text = "BRCA1", page = "1") |>
  req_user_agent("sysndd-ci-fixture-capture/1.0") |>
  req_perform()

request("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/search/") |>
  req_url_query(text = "xyzzy12345nonexistent98765", page = "1") |>
  req_user_agent("sysndd-ci-fixture-capture/1.0") |>
  req_perform()

request("https://www.ncbi.nlm.nih.gov/research/pubtator3-api/publications/export/biocjson") |>
  req_url_query(pmids = "33054928") |>
  req_user_agent("sysndd-ci-fixture-capture/1.0") |>
  req_perform()

httptest2::stop_capturing()
```

## Host-environment note (Phase A7 context)

On Ubuntu questing (25.10) with miniforge R, `make test-api` cannot run on
the host because renv cannot bootstrap a working library (see
`CLAUDE.md` "Host-Env Workaround"). Fixture capture and verification are
therefore done via Docker exec against `sysndd-api:latest`, which ships with
`httr2` + `httptest2` + `easyPubMed` working out of the box. CI
(`ubuntu-latest`) is the authoritative runner for the R test suite once the
A7 GitHub Actions matrix lands.

## Other files in this directory

Pre-existing non-HTTP fixtures used by other tests (not owned by Phase B B2,
left untouched):

- `genemap2-sample.txt` / `genemap2_test.txt` — OMIM genemap2 test payloads.
- `phenotype_hpoa_test.txt` / `phenotype_to_genes_test.txt` — HPO test payloads.
- `llm-benchmark-ground-truth.json` — LLM benchmark ground truth.

These are not HTTP response captures and are not gated by
`skip_if_no_fixtures()`. If you add a new external-API fixture namespace,
create a new subdirectory (e.g. `fixtures/hgnc/`) and wire a new
`skip_if_no_fixtures("hgnc")` call into the relevant test file — the helper
takes any namespace string without a hardcoded allowlist.

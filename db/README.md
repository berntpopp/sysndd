# SysNDD-DB <img src='../app/public/img/icons/android-chrome-192x192.png' align="right" alt="SysNDD logo" width="192" height="192" />

The repository for the relational database powering SysNDD.

We use the open-source MySQL 8.0 relational database management system (RDBMS).

The design of our DB schema can be viewed in DB DESIGNER:
[SysNDD DB schema](https://dbdesigner.page.link/3Morx9HZxzqt4R379)

---

## Two distinct kinds of "database scripts"

This directory contains **two separate mechanisms**. Do not confuse them:

| | `db/migrations/*.sql` | `db/*_Rcommands_*.R` (this README) |
|---|---|---|
| **What** | Versioned schema migrations | Out-of-band data-prep / DB-creation |
| **When** | Applied automatically at **API startup** by the migration runner | Run **manually** by a maintainer to (re)build the DB content from external sources |
| **Audience** | Every deployment | Maintainers rebuilding the dataset |
| **Source of truth** | `db/migrations/README.md` | this file |

Everything below describes the **out-of-band data-prep / DB-creation scripts**.

---

## What the data-prep scripts do

The numbered scripts (`01..17`) each fetch / transform one logical dataset and
write a dated CSV into `db/results/`. The lettered finalizers (`A`, `B`, `C`)
then load those CSVs into MySQL and apply data types, keys, and views.

| Step | Script | Builds / does |
|---|---|---|
| 01 | `01_..._hgnc_non_alt_loci_set.R` | HGNC gene set + STRING ids + gene coordinates |
| 02 | `02_..._disease_ontology_set.R` | Disease ontology (OMIM/MONDO) cross-mapped via OxO |
| 03 | `03_..._mode_of_inheritance_list.R` | HPO inheritance-mode terms |
| 04 | `04_..._ndd_entity.R` | Core NDD entities (SysID import + OMIM/MONDO) |
| 05 | `05_..._ndd_entity_review.R` | Initial review records from SysID synopses |
| 06 | `06_..._ndd_entity_status.R` | Curated status categories from SysID groups |
| 07 | `07_..._ndd_review_phenotype_connect.R` | Phenotype → HPO term links |
| 08 | `08_..._publication.R` | Publication metadata (PubMed / GeneReviews) |
| 09 | `09_..._re_review.R` | Re-review batch assignments |
| 10 | `10_..._user.R` | Users (from an external CSV) |
| 11 | `11_..._database_comparisons.R` | Comparison vs. external NDD databases |
| 12 | `12_..._variation_ontology_set.R` | Variation Ontology (VariO) + links |
| 13 | `13_..._boolean_list.R` | Boolean lookup table |
| 14 | `14_..._allowed_list.R` | Allowed-value lists for the UI |
| 15 | `15_..._logging_table.R` | Logging table schema |
| 16 | `16_..._pubtator_cache_table.R` | PubTator cache tables |
| 17 | `17_..._json_storage_table.R` | JSON storage table |
| A | `A_Rcommands_create-database-tables.R` | Import all `results/*.csv` into MySQL |
| B | `B_Rcommands_set-table-data-types.R` | Set column types / constraints |
| C | `C_Rcommands_set-table-connections.R` | Set keys, foreign keys, views |

> **Note on `C_Rcommands_set-table-connections.R` and views:** the core read
> views (`ndd_entity_view`, `users_view`, ...) are also codified in
> `db/migrations/025_create_core_views.sql` (and later migrations). If you change
> a view definition, keep the migration and this script in sync. See `AGENTS.md`.

---

## Configuration (no hardcoded secrets)

All credentials, the project directory, the SysID source selection, and the
external download URLs are read from config so nothing sensitive lives in the
scripts.

1. **Credentials** — copy the template and fill in real values:

   ```bash
   cp db/config/sysndd_db.yml.example db/config/sysndd_db.yml
   # edit db/config/sysndd_db.yml
   ```

   `db/config/sysndd_db.yml` is **gitignored**. You can also point at a
   different file with the `CONFIG_FILE` environment variable; if neither is set,
   the default `db/config/sysndd_db.yml` is used.

2. **External source URLs** (HGNC, HPO, OxO, NCBI, genenames REST, VariO) — these
   have sensible built-in defaults in `db/config/db_config.R`
   (`.db_source_defaults`). Override only if you need a mirror/pinned version:

   ```bash
   cp db/config/db_sources.yml.example db/config/db_sources.yml
   # edit db/config/db_sources.yml
   ```

3. **OMIM download links** — OMIM downloads are access-controlled and the URLs
   embed a per-account secret token, so they are **never** hardcoded. Put your
   authorized OMIM download links (one per line) in:

   ```
   db/data/omim_links/omim_links.txt   # gitignored
   ```

   Scripts 02 and 04 read that file at runtime.

4. **Other input data** — Excel/TSV lookup files live under `db/data/` (e.g.
   `data/lists/`, `data/phenotypes/`, `data/mondo_terms/`,
   `data/ndd_databases_links/`). See each script header for the expected file.

> **NEVER commit real credentials, tokens, or OMIM links.** Only the
> `*.example` templates and placeholder values belong in git.

---

## Working-directory independence

The scripts resolve the `db/` directory from their own location (via
`db/config/db_config.R`) and anchor the working directory there, so they can be
launched from anywhere:

```bash
# all equivalent — no need to `cd db` first
Rscript db/01_Rcommands_sysndd_db_table_hgnc_non_alt_loci_set.R
cd db && Rscript 01_Rcommands_sysndd_db_table_hgnc_non_alt_loci_set.R
SYSNDD_DB_DIR=/abs/path/to/db Rscript /abs/path/to/db/01_...R
```

Resolution order for the `db/` directory: `SYSNDD_DB_DIR` env var → the running
script's path → `here::here()/db` → current working directory.

---

## Running the pipeline

### Master runner (recommended)

`db/run_all.R` orchestrates every step in the correct order, each in its own
fresh R subprocess, with timestamped logging and fail-fast behavior:

```bash
Rscript db/run_all.R               # run the full pipeline
Rscript db/run_all.R --list        # list ordered steps and exit
Rscript db/run_all.R --dry-run     # log what would run, do nothing
Rscript db/run_all.R --only 01,02  # run only matching step prefixes
Rscript db/run_all.R --from 04     # resume starting at step 04
Rscript db/run_all.R --skip-finalize  # skip the A/B/C finalizers
```

If a step fails, the runner stops and prints a `--from NN` command to resume.

### Running steps individually

Each script is standalone and can be run on its own (e.g. to rebuild a single
table):

```bash
Rscript db/03_Rcommands_sysndd_db_table_mode_of_inheritance_list.R
```

---

## Reproducible SysID import (SQLite)

The initial import (scripts 04–08) historically read two tables — `disease` and
`human_gene_disease_connect` — from the upstream **SysID** MySQL instance over an
SSH tunnel. That source is not reproducible for anyone outside the original
maintainers, which blocks clean rebuilds.

To make the import reproducible, the scripts can read the **same two tables from
a local SQLite snapshot** instead. Selection is driven by config
(`sysid_source: "sqlite" | "mysql"` in `sysndd_db.yml`); if unset, `sqlite` is
auto-selected when a snapshot file exists.

### One-time: create the snapshot (maintainer with live SysID access)

```r
# from an R session with live SysID MySQL credentials in sysndd_db.yml
source("db/config/db_config.R")
source("db/config/db_sysid_source.R")
cfg <- db_load_config()
db_sysid_export_to_sqlite(cfg)   # -> db/data/sysid/sysid_snapshot.sqlite
```

Archive the resulting `db/data/sysid/sysid_snapshot.sqlite` (it is gitignored by
default because it can be large; commit/store it wherever your reproducibility
policy requires). Future rebuilds then run **network-free** against the snapshot.

### Subsequent rebuilds (anyone)

With the snapshot present (and `sysid_source: sqlite` or unset), just run the
pipeline — scripts 04–08 read the snapshot automatically. Requires the
`RSQLite` R package.

---

## Prerequisites

- R with the packages each step `library()`-loads (e.g. `tidyverse`, `DBI`,
  `RMariaDB`, `RSQLite`, `sqlr`, `biomaRt`, `STRINGdb`, `ontologyIndex`,
  `jsonlite`, `httr2`, `readxl`, `config`, `yaml`, `here`). Network access is
  required for the steps that download from external sources.
- A reachable **SysNDD target MySQL 8.0** database (credentials in
  `db/config/sysndd_db.yml`).
- For the SysID import: either a SysID **SQLite snapshot** (recommended) or live
  SysID MySQL credentials.
- Authorized **OMIM** download links in `db/data/omim_links/omim_links.txt`.

---

## Tests

Pure helpers (path resolution, config loading, URL building, SysID source
selection) have host-runnable unit tests in `db/tests/testthat/` (no DB/network
needed):

```bash
Rscript --no-init-file -e "testthat::test_dir('db/tests/testthat')"
```

The data-prep scripts themselves require a DB and/or network, so they are not
run in CI. At minimum, verify a script parses:

```bash
Rscript --no-init-file -e "invisible(parse('db/01_Rcommands_sysndd_db_table_hgnc_non_alt_loci_set.R'))"
```

---

## Directory layout

```
db/
├── 01..17_Rcommands_*.R         # per-table data-prep steps
├── A/B/C_Rcommands_*.R          # finalizers (import, types, keys/views)
├── run_all.R                    # master orchestration runner
├── config/
│   ├── db_config.R              # shared config + path + URL helpers
│   ├── db_sysid_source.R        # SysID source abstraction (SQLite/MySQL)
│   ├── sysndd_db.yml.example    # credentials template (copy -> sysndd_db.yml)
│   └── db_sources.yml.example   # external-URL overrides template (optional)
├── tests/testthat/              # host-runnable unit tests for helpers
├── data/                        # input data (OMIM links, lists, snapshots, ...)
├── results/                     # generated CSV outputs (gitignored)
├── migrations/                  # runtime schema migrations (separate! see its README)
├── fixtures/                    # test/seed fixtures
└── updates/                     # one-off update/backfill scripts
```

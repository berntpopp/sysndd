# Technology Stack - v4 Backend Overhaul

**Project:** SysNDD API Backend Modernization
**Researched:** 2026-01-23
**Focus:** NEW capabilities only (async, R upgrade, security, OMIM migration)

## Executive Summary

This research covers stack additions/changes for the v4 Backend Overhaul milestone. The current stack (R 4.1.2, Plumber, pool, testthat+mirai, renv) is validated. This document focuses exclusively on:

1. **Async/Non-blocking patterns** - mirai + promises for Plumber
2. **R 4.4.x upgrade** - Breaking changes and migration path
3. **Security packages** - sodium for password hashing (argon2/scrypt)
4. **OMIM data source migration** - mim2gene.txt + MONDO/JAX API alternatives

---

## 1. Async/Non-blocking R Patterns for Plumber

### Recommended Stack

| Package | Version | Purpose | Confidence |
|---------|---------|---------|------------|
| mirai | >= 2.0.0 | Async evaluation framework | HIGH |
| promises | >= 1.5.0 | Promise abstraction (already in renv.lock) | HIGH |
| nanonext | (mirai dependency) | Modern networking/concurrency | HIGH |

### Why mirai (Not future for async)

The project already uses `future` (v1.69.0 in renv.lock) but **mirai is the recommended choice for Plumber async** because:

1. **Native Plumber integration**: mirai serves as the built-in async evaluator enabling the `@async` tag in plumber2
2. **Zero-latency promises**: Event-driven promises (no polling) developed with Joe Cheng (Shiny creator)
3. **Massive scalability**: Supports thousands/millions of concurrent promises
4. **Already tested**: Project uses `testthat + mirai` for testing infrastructure

**Source:** [mirai Plumber Integration](https://cran.r-project.org/web/packages/mirai/vignettes/plumber.html)

### Integration Pattern

For the existing Plumber (not plumber2), use mirai with promises:

```r
# Install
install.packages("mirai")

# In endpoint handler - wrap blocking operation
library(mirai)
library(promises)

#* @get /api/analysis/functional_clustering
function() {
  # Convert blocking operation to async
  m <- mirai({
    # Heavy computation here (clustering, STRING-db calls)
    gen_string_clust_obj_mem(hgnc_ids)
  })

  # Return promise - Plumber handles this
  m %...>% function(result) {
    list(categories = result$categories, clusters = result$clusters)
  }
}
```

### Blocking Operations to Convert

From code analysis, these are the blocking operations requiring async:

| Location | Operation | Impact |
|----------|-----------|--------|
| `analysis_endpoints.R` | `gen_string_clust_obj_mem()` | STRING-db API calls |
| `analysis_endpoints.R` | `gen_mca_clust_obj_mem()` | MCA/HCLUST computation |
| `ontology-functions.R` | `process_combine_ontology()` | OMIM/MONDO download + processing |
| `external-functions.R` | External API calls | PubMed, PubTator, HGNC, Ensembl |

### plumber2 Consideration

**plumber2** (v0.1.0, September 2025) offers native `@async` tag support:

```r
#* @async
#* @get /api/heavy-operation
function() {
  # Automatically converted to async handler
  heavy_computation()
}
```

**Recommendation:** Stay with plumber for v4, evaluate plumber2 for v5. Reasons:
- plumber2 is new (0.1.0) - limited production testing
- Migration effort significant (new annotation parsing, different tags)
- mirai + promises works well with current plumber

**Source:** [plumber2 Announcement](https://tidyverse.org/blog/2025/09/plumber2-0-1-0/)

---

## 2. R 4.4.x Upgrade Path

### Current vs Target

| Aspect | Current | Target | Notes |
|--------|---------|--------|-------|
| R Version | 4.1.2 | 4.4.3 | Latest stable as of Feb 2025 |
| Base Image | rocker/r-ver:4.1.2 | rocker/r-ver:4.4.3 | Ubuntu 22.04 (jammy) |
| P3M URL | focal/latest | jammy/latest | New Ubuntu base |

### Breaking Changes to Address

**R 4.2.0 Changes:**
- `raw` vectors no longer allowed in `chartr()`
- Changes to how R handles locales on Windows (less relevant for Docker)

**R 4.3.0 Changes:**
- `as.data.frame.list()` new `new.names` option
- Parser changes (bison 3.8.2) - error messages may differ

**R 4.4.0 Changes (Critical):**
- **NULL handling**: `NCOL(NULL)` now returns 0 (was 1)
- NULL is no longer atomic - affects `is.atomic(NULL)` checks
- `as.numeric()`, `scan()`, `type.convert()` require non-empty digit sequences in exponents

**Source:** [R 4.4.0 Release Notes](https://stat.ethz.ch/pipermail/r-announce/2024/000701.html), [R-bloggers R 4.4.0](https://www.r-bloggers.com/2024/04/whats-new-in-r-4-4-0/)

### Package Compatibility

| Package | R 4.1.2 Version | R 4.4.3 Approach |
|---------|-----------------|------------------|
| Matrix | 1.4-0 | >= 1.6-0 (bundled with R 4.4) |
| lme4 | 1.1-27.1 | >= 1.1-35 (requires Matrix >= 1.5.0) |
| FactoMineR | from 2022-01-03 snapshot | Latest (Matrix compat fixed) |
| factoextra | from 2022-01-03 snapshot | Latest |

**Major improvement:** The Matrix/lme4 compatibility workaround in current Dockerfile (using 2022-01-03 P3M snapshot) will no longer be needed.

### Docker Migration

```dockerfile
# Before (R 4.1.2)
FROM rocker/r-ver:4.1.2 AS base
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/focal/latest"

# After (R 4.4.3)
FROM rocker/r-ver:4.4.3 AS base
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/jammy/latest"
```

### Migration Checklist

- [ ] Update Dockerfile base image to `rocker/r-ver:4.4.3`
- [ ] Change P3M URLs from `focal` to `jammy`
- [ ] Remove FactoMineR/lme4 snapshot workaround
- [ ] Audit code for `NCOL(NULL)` assumptions
- [ ] Audit code for `is.atomic(NULL)` checks
- [ ] Update renv.lock R version field
- [ ] Run full test suite on R 4.4.3

**Source:** [Rocker r-ver images](https://hub.docker.com/r/rocker/r-ver), [R-bloggers R 4.5.0](https://www.r-bloggers.com/2025/04/whats-new-in-r-4-5-0/)

---

## 3. Security Packages - Password Hashing

### Current State (CRITICAL VULNERABILITY)

From `authentication_endpoints.R` and `user_endpoints.R`:

```r
# CURRENT: Plaintext password comparison (INSECURE)
filter(user_name == check_user & password == check_pass & approved == 1)

# CURRENT: Plaintext password storage
dbExecute(sysndd_db, paste0("UPDATE user SET password = '", user_password, "'..."))
```

### Recommended: sodium Package

| Package | Version | Algorithm | Confidence |
|---------|---------|-----------|------------|
| sodium | >= 1.4.0 | Argon2id (default), scrypt | HIGH |

**Why sodium:**
1. **Modern algorithms**: Uses libsodium's Argon2id (OWASP recommended) or scrypt
2. **Battle-tested**: Maintained by rOpenSci, production-ready
3. **Simple API**: `password_store()` and `password_verify()` handle all complexity
4. **Already in Dockerfile**: `libsodium-dev` is installed (line 58-59)

**Source:** [sodium password functions](https://rdrr.io/cran/sodium/man/password.html), [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)

### Implementation Pattern

```r
library(sodium)

# Storing a password (registration/password change)
hash <- password_store(user_password)
# Returns: "$argon2id$v=19$m=65536,t=2,p=1$..."

# Store hash in database (VARCHAR(255) sufficient)
dbExecute(sysndd_db,
  "UPDATE user SET password_hash = ? WHERE user_id = ?",
  params = list(hash, user_id)
)

# Verifying a password (authentication)
stored_hash <- dbGetQuery(sysndd_db,
  "SELECT password_hash FROM user WHERE user_name = ?",
  params = list(check_user)
)$password_hash

if (password_verify(stored_hash, check_pass)) {
  # Authentication successful
} else {
  # Authentication failed
}
```

### Database Migration

```sql
-- Add new column for hash (don't drop password yet)
ALTER TABLE user ADD COLUMN password_hash VARCHAR(255);

-- After migration is complete and verified:
ALTER TABLE user DROP COLUMN password;
```

### NOT Recommended: bcrypt (R package)

While bcrypt exists for R, **use sodium instead** because:
- sodium uses Argon2id (OWASP #1 recommendation for 2025)
- bcrypt has 72-byte password limit
- sodium is actively maintained by rOpenSci

**Source:** [Password Hashing Guide 2025](https://guptadeepak.com/the-complete-guide-to-password-hashing-argon2-vs-bcrypt-vs-scrypt-vs-pbkdf2-2026/)

---

## 4. SQL Injection Prevention - Parameterized Queries

### Current State (66 VULNERABILITIES)

From `database-functions.R`:

```r
# CURRENT: String concatenation (SQL INJECTION VULNERABLE)
dbExecute(sysndd_db, paste0("UPDATE ndd_entity SET ",
  "is_active = 0, replaced_by = ", replacement,
  " WHERE entity_id = ", entity_id, ";"))
```

### Recommended: DBI dbBind()

| Package | Version | Notes |
|---------|---------|-------|
| DBI | >= 1.2.3 | Already in renv.lock |
| RMariaDB | latest | Already in stack |

**Source:** [DBI dbBind](https://dbi.r-dbi.org/reference/dbBind.html), [Posit Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/)

### Implementation Pattern

```r
# SECURE: Parameterized query with dbBind
put_db_entity_deactivation <- function(entity_id, replacement = NULL) {
  sysndd_db <- pool::poolCheckout(pool)
  on.exit(pool::poolReturn(sysndd_db))

  stmt <- dbSendStatement(sysndd_db,
    "UPDATE ndd_entity SET is_active = 0, replaced_by = ? WHERE entity_id = ?")
  dbBind(stmt, list(replacement, entity_id))
  dbClearResult(stmt)

  list(status = 200, message = "OK. Entity deactivated.", entry = entity_id)
}
```

### Placeholder Format (RMariaDB)

RMariaDB uses `?` placeholders with positional matching:

```r
# Single parameter
dbGetQuery(con, "SELECT * FROM user WHERE user_id = ?", params = list(user_id))

# Multiple parameters
dbGetQuery(con, "SELECT * FROM user WHERE user_name = ? AND approved = ?",
           params = list(user_name, 1))
```

### Fallback: sqlInterpolate()

If `dbBind()` doesn't work in specific cases:

```r
# Using sqlInterpolate as fallback
query <- sqlInterpolate(con,
  "UPDATE user SET user_role = ?role WHERE user_id = ?id",
  role = role_assigned,
  id = user_id_role
)
dbExecute(con, query)
```

---

## 5. OMIM Data Source Migration

### Current State (BROKEN)

From `ontology-functions.R`:

```r
# Current: Downloads genemap2.txt from private OMIM links file
genemap2_link <- as_tibble(read_lines("data/omim_links/omim_links.txt"))
# Problem: genemap2.txt no longer provides all required fields
```

### Issue Analysis

- `genemap2.txt` fields have changed over time
- Some mappings no longer available in genemap2
- OMIM API requires license for commercial use
- Need gene-to-disease mapping with inheritance information

### Recommended Data Sources

| Source | Access | Data Provided | Confidence |
|--------|--------|---------------|------------|
| mim2gene.txt | **FREE** | MIM -> Gene ID, HGNC, Ensembl | HIGH |
| MONDO Ontology | FREE | Disease hierarchy, OMIM/Orphanet/DOID mappings | HIGH |
| HPO/JAX API | FREE | HPO terms, disease-phenotype annotations | HIGH |
| Monarch API | FREE | Integrated disease-gene-phenotype | MEDIUM |

**Source:** [OMIM Downloads](https://www.omim.org/downloads/), [MONDO Disease Ontology](https://mondo.monarchinitiative.org/), [HPO JAX](https://hpo.jax.org/)

### mim2gene.txt (FREE - No Registration)

Available at: `https://omim.org/static/omim/data/mim2gene.txt`

Fields provided:
- MIM Number
- MIM Entry Type
- Entrez Gene ID
- Approved Gene Symbol (HGNC)
- Ensembl Gene ID

```r
# Download mim2gene.txt (FREE, no auth required)
mim2gene <- read_tsv(
  "https://omim.org/static/omim/data/mim2gene.txt",
  comment = "#",
  col_names = c("MIM_Number", "MIM_Entry_Type", "Entrez_Gene_ID",
                "Approved_Symbol", "Ensembl_Gene_ID")
)
```

### MONDO for Disease Mappings

The code already uses MONDO (`get_mondo_mappings()` in ontology-functions.R). MONDO provides:

- OMIM -> Orphanet mappings
- OMIM -> DOID mappings
- OMIM -> EFO mappings
- Unified disease hierarchy

**Recommendation:** Leverage existing MONDO integration more heavily instead of relying on genemap2.txt.

### JAX HPO API for Phenotype-Disease Links

```r
# HPO annotations for diseases
hpo_annotations_url <- "http://purl.obolibrary.org/obo/hp/hpoa/phenotype.hpoa"

# Gene-to-phenotype annotations
genes_to_phenotype_url <- "http://purl.obolibrary.org/obo/hp/hpoa/genes_to_phenotype.txt"
```

### Migration Strategy

1. **Phase 1**: Use mim2gene.txt for gene-MIM mapping (replace genemap2 dependency)
2. **Phase 2**: Enhance MONDO integration for disease relationships
3. **Phase 3**: Add HPO annotation files for phenotype links
4. **Phase 4**: Consider Monarch API for integrated queries

---

## 6. What NOT to Add

| Technology | Why Not |
|------------|---------|
| plumber2 | Too new (0.1.0), significant migration, mirai+promises works fine |
| bcrypt | sodium with Argon2id is superior per OWASP 2025 guidelines |
| future for Plumber async | mirai is purpose-built for Plumber, better performance |
| OMIM API license | mim2gene.txt + MONDO provides what's needed for free |
| argon2 R package | sodium already includes Argon2id, don't add duplicate |

---

## Complete Stack Addition Summary

### Add to renv.lock

```r
# New packages for v4
install.packages(c(
  "mirai",      # Async evaluation (>= 2.0.0)
  "sodium"      # Password hashing (>= 1.4.0) - may need explicit add
))
```

### Update in Dockerfile

```dockerfile
# Change base image
FROM rocker/r-ver:4.4.3 AS base

# Update P3M repository
ENV RENV_CONFIG_REPOS_OVERRIDE="https://packagemanager.posit.co/cran/__linux__/jammy/latest"

# Remove the 2022-01-03 snapshot workaround for FactoMineR
# (no longer needed with R 4.4.x)
```

### Version Requirements

| Package | Minimum Version | Current (renv.lock) | Action |
|---------|-----------------|---------------------|--------|
| R | 4.4.3 | 4.1.2 | Upgrade |
| mirai | 2.0.0 | (not in lock) | Add |
| sodium | 1.4.0 | (suggested by jose) | Verify/Add explicit |
| DBI | 1.2.3 | 1.2.3 | Keep |
| promises | 1.5.0 | 1.5.0 | Keep |
| pool | current | current | Keep |

---

## Integration with Existing Stack

### Preserved (DO NOT Change)

| Component | Version | Notes |
|-----------|---------|-------|
| testthat + mirai | current | Testing infrastructure validated |
| renv | current | Package management |
| pool | current | Database connection pooling |
| Plumber | current | API framework (stay on v1.x) |
| Docker multi-stage | current | Build infrastructure |

### Modified

| Component | Current | Target | Rationale |
|-----------|---------|--------|-----------|
| R | 4.1.2 | 4.4.3 | Security, performance, Matrix fix |
| rocker/r-ver | 4.1.2 | 4.4.3 | Match R version |
| P3M repository | focal | jammy | Ubuntu 22.04 base |

### Added

| Component | Version | Purpose |
|-----------|---------|---------|
| mirai | >= 2.0.0 | Async evaluation for Plumber |
| sodium | >= 1.4.0 | Password hashing (Argon2id) |

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Async (mirai) | HIGH | Official Plumber integration, verified docs |
| R 4.4.x upgrade | HIGH | Official release notes, Docker images available |
| sodium for passwords | HIGH | OWASP recommended, official CRAN package |
| DBI parameterized queries | HIGH | Official DBI documentation |
| OMIM alternatives | MEDIUM | mim2gene.txt verified free, MONDO integration exists |

---

## Sources

### Async/Plumber
- [mirai Package Documentation](https://mirai.r-lib.org/)
- [mirai Plumber Integration](https://cran.r-project.org/web/packages/mirai/vignettes/plumber.html)
- [mirai GitHub](https://github.com/r-lib/mirai)
- [plumber2 Announcement](https://tidyverse.org/blog/2025/09/plumber2-0-1-0/)

### R Upgrade
- [R 4.4.0 Release](https://stat.ethz.ch/pipermail/r-announce/2024/000701.html)
- [R 4.4.3 Release](https://stat.ethz.ch/pipermail/r-announce/2025/000708.html)
- [R-bloggers R 4.4.0](https://www.r-bloggers.com/2024/04/whats-new-in-r-4-4-0/)
- [Rocker r-ver Images](https://hub.docker.com/r/rocker/r-ver)

### Security
- [sodium Package](https://cran.r-project.org/web/packages/sodium/sodium.pdf)
- [sodium password_store](https://rdrr.io/cran/sodium/man/password.html)
- [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
- [Password Hashing Guide 2025](https://guptadeepak.com/the-complete-guide-to-password-hashing-argon2-vs-bcrypt-vs-scrypt-vs-pbkdf2-2026/)
- [DBI dbBind](https://dbi.r-dbi.org/reference/dbBind.html)
- [Posit Run Queries Safely](https://solutions.posit.co/connections/db/best-practices/run-queries-safely/)

### OMIM/Ontology
- [OMIM Downloads](https://www.omim.org/downloads/)
- [mim2gene.txt](https://omim.org/static/omim/data/mim2gene.txt)
- [MONDO Disease Ontology](https://mondo.monarchinitiative.org/)
- [HPO JAX](https://hpo.jax.org/)
- [Monarch Initiative](https://monarchinitiative.org/)

---

**Document Version:** 1.0
**Last Updated:** 2026-01-23
**Scope:** v4 Backend Overhaul - NEW capabilities only

# Architecture Patterns: Gene Page Genomic Data Integration

**Domain:** Gene page external data integration (gnomAD, UniProt, Ensembl, AlphaFold, MGI)
**Researched:** 2026-01-27
**Context:** Subsequent milestone - adding features to existing SysNDD app

## Executive Summary

Integration of five external genomic data sources (gnomAD, UniProt, Ensembl, AlphaFold, MGI) into existing gene pages requires a unified backend architecture that handles rate limiting, caching, error handling, and graceful degradation. This research identifies proven patterns from the existing codebase and adapts them for external API integration.

**Key Decision:** Single unified endpoint file (`external_genomic_endpoints.R`) with per-source function modules, using established httr2 retry logic, disk-based caching, and composable-driven frontend.

## Recommended Architecture

### Backend Endpoint Organization

**Pattern: Single endpoint file with per-source functions**

**Rationale:**
1. All five sources share common concerns (rate limiting, caching, error handling)
2. Existing `external_endpoints.R` demonstrates single-file pattern (Internet Archive)
3. Avoids fragmentation - easier to maintain unified caching/retry strategy
4. Gene page queries will batch-fetch all sources simultaneously

**Structure:**
```
api/
├── endpoints/
│   └── external_genomic_endpoints.R  # All 5 endpoints + combined endpoint
├── functions/
│   ├── gnomad-functions.R           # GraphQL client, constraint queries
│   ├── uniprot-functions.R          # REST client, domain queries
│   ├── ensembl-functions.R          # Existing + exon structure queries
│   ├── alphafold-functions.R        # REST client, structure URL retrieval
│   └── mgi-functions.R              # REST/web scraping, phenotype queries
```

### Endpoint Definitions

#### Individual Source Endpoints

**Purpose:** Allow granular access for debugging, testing, and potential future standalone use

```r
# api/endpoints/external_genomic_endpoints.R

#* @get /api/external/gnomad/<symbol>
#* @tag external
#* @serializer json
function(symbol) {
  fetch_gnomad_data_cached(symbol)
}

#* @get /api/external/uniprot/<uniprot_id>
function(uniprot_id) {
  fetch_uniprot_domains_cached(uniprot_id)
}

#* @get /api/external/ensembl/<ensembl_id>
function(ensembl_id) {
  fetch_ensembl_structure_cached(ensembl_id)
}

#* @get /api/external/alphafold/<uniprot_id>
function(uniprot_id) {
  fetch_alphafold_urls_cached(uniprot_id)
}

#* @get /api/external/mgi/<symbol>
function(symbol) {
  fetch_mgi_phenotypes_cached(symbol)
}
```

#### Combined Aggregation Endpoint

**Purpose:** Single request from frontend fetches all available data for a gene

```r
#* @get /api/external/gene/<symbol>
#* @tag external
#* @serializer json
function(symbol, ensembl_id = NULL, uniprot_id = NULL) {
  # Parallel fetch with error isolation
  # Returns structure: { gnomad: {...}, uniprot: {...}, ... }
  # Missing IDs return NULL, errors return { error: "message" }

  fetch_gene_external_data(
    symbol = symbol,
    ensembl_id = ensembl_id,
    uniprot_id = uniprot_id
  )
}
```

**Key features:**
- **Parallel execution:** Use base R's async or sequential with early returns
- **Error isolation:** One source failure doesn't block others
- **Partial data support:** Frontend renders whatever is available

### Per-Source Function Modules

#### gnomAD Functions (GraphQL)

**File:** `api/functions/gnomad-functions.R`

**Pattern:** httr2 with retry logic + GraphQL client

```r
#' Fetch gnomAD constraint and variant data
#'
#' Uses GraphQL API with rate limiting protection
#'
#' @param symbol HGNC symbol
#' @return List with pLI, LOEUF, ClinVar variants
fetch_gnomad_data <- function(symbol) {
  # GraphQL query for gene constraints
  query <- sprintf('
    query {
      gene(gene_symbol: "%s", reference_genome: GRCh38) {
        gene_id
        symbol
        gnomad_constraint {
          pLI
          oe_lof_upper
          loeuf
        }
        clinvar_variants {
          variant_id
          clinical_significance
        }
      }
    }
  ', symbol)

  response <- request("https://gnomad.broadinstitute.org/api") %>%
    req_body_json(list(query = query)) %>%
    req_retry(
      max_tries = 5,
      max_seconds = 120,
      backoff = ~ 2^.x,
      is_transient = ~ resp_status(.x) %in% c(429, 503)
    ) %>%
    req_timeout(30) %>%
    req_throttle(rate = 15 / 60) %>%  # 15 requests/minute (conservative)
    req_perform()

  if (resp_status(response) != 200) {
    return(list(error = sprintf("gnomAD API error: %d", resp_status(response))))
  }

  data <- resp_body_json(response)
  return(data$data$gene)
}
```

**Rate limiting strategy:**
- `req_throttle(rate = 15/60)`: Proactive rate limiting (15 req/min)
- `req_retry(is_transient = 429, 503)`: Reactive handling for rate limit responses
- `backoff = ~ 2^.x`: Exponential backoff (2s, 4s, 8s, 16s, 32s)

**Caching:** 7-day TTL (constraint data changes infrequently)

#### UniProt Functions (REST)

**File:** `api/functions/uniprot-functions.R`

**Pattern:** httr2 REST client with 200 req/sec limit

```r
#' Fetch UniProt protein domains
#'
#' @param uniprot_id UniProt accession (e.g., "P12345")
#' @return List with domains, features, regions
fetch_uniprot_domains <- function(uniprot_id) {
  url <- sprintf(
    "https://rest.uniprot.org/uniprotkb/%s.json",
    uniprot_id
  )

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(20) %>%
    req_throttle(rate = 200) %>%  # 200 req/sec limit
    req_perform()

  if (resp_status(response) != 200) {
    return(list(error = sprintf("UniProt API error: %d", resp_status(response))))
  }

  data <- resp_body_json(response)

  # Extract features (domains, regions, binding sites)
  features <- data$features %>%
    filter(type %in% c("Domain", "Region", "Active site", "Binding site")) %>%
    select(type, description, begin = location$start$value, end = location$end$value)

  return(list(
    accession = uniprot_id,
    protein_name = data$proteinDescription$recommendedName$fullName$value,
    length = data$sequence$length,
    domains = features
  ))
}
```

**Rate limiting:** 200 req/sec (EBI limit) - conservative 100 req/sec
**Caching:** 30-day TTL (protein domains stable)

#### Ensembl Functions (REST)

**File:** `api/functions/ensembl-functions.R` (extend existing)

**Pattern:** Extend existing biomaRt functions with REST API for exon structure

```r
#' Fetch Ensembl gene structure (exons, transcripts)
#'
#' Uses Ensembl REST API (15 req/sec limit)
#'
#' @param ensembl_id Ensembl gene ID (e.g., "ENSG00000139618")
#' @return List with transcripts, exons, coordinates
fetch_ensembl_structure <- function(ensembl_id) {
  url <- sprintf(
    "https://rest.ensembl.org/lookup/id/%s?content-type=application/json;expand=1",
    ensembl_id
  )

  response <- request(url) %>%
    req_headers(Accept = "application/json") %>%
    req_retry(
      max_tries = 5,
      max_seconds = 120,
      backoff = ~ 2^.x,
      is_transient = ~ resp_status(.x) == 429
    ) %>%
    req_timeout(30) %>%
    req_throttle(rate = 15) %>%  # 15 req/sec limit
    req_perform()

  # Check for Retry-After header (Ensembl provides this)
  if (resp_status(response) == 429) {
    retry_after <- resp_header(response, "Retry-After")
    if (!is.null(retry_after)) {
      Sys.sleep(as.numeric(retry_after))
      return(fetch_ensembl_structure(ensembl_id))  # Retry once
    }
  }

  if (resp_status(response) != 200) {
    return(list(error = sprintf("Ensembl API error: %d", resp_status(response))))
  }

  data <- resp_body_json(response)

  # Extract canonical transcript exons
  canonical <- data$Transcript %>%
    filter(is_canonical == 1) %>%
    slice(1)

  exons <- canonical$Exon[[1]] %>%
    select(id, start, end, strand)

  return(list(
    gene_id = ensembl_id,
    symbol = data$display_name,
    chromosome = data$seq_region_name,
    start = data$start,
    end = data$end,
    strand = data$strand,
    transcripts = nrow(data$Transcript),
    canonical_transcript = canonical$id,
    exons = exons
  ))
}
```

**Rate limiting:** 15 req/sec (55k/hour) - respect Retry-After header
**Caching:** 90-day TTL (gene structure stable between releases)

#### AlphaFold Functions (REST)

**File:** `api/functions/alphafold-functions.R`

**Pattern:** Simple REST client returning URLs only

```r
#' Fetch AlphaFold structure file URLs
#'
#' Returns URLs for PDB, mmCIF files (frontend fetches files directly)
#'
#' @param uniprot_id UniProt accession
#' @return List with pdb_url, cif_url, confidence_url
fetch_alphafold_urls <- function(uniprot_id) {
  # Use new API (legacy retires June 2026)
  url <- sprintf(
    "https://alphafold.ebi.ac.uk/api/prediction/%s",
    uniprot_id
  )

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(20) %>%
    req_perform()

  if (resp_status(response) == 404) {
    return(list(error = "No AlphaFold prediction available"))
  }

  if (resp_status(response) != 200) {
    return(list(error = sprintf("AlphaFold API error: %d", resp_status(response))))
  }

  data <- resp_body_json(response)

  # Return URLs - frontend loads files directly
  return(list(
    uniprot_id = uniprot_id,
    pdb_url = data[[1]]$pdbUrl,
    cif_url = data[[1]]$cifUrl,
    confidence_url = data[[1]]$bcifUrl,  # New format for confidence scores
    version = data[[1]]$entryId
  ))
}
```

**Special case:** Backend returns URLs only, frontend fetches structure files directly (PDB files are large, no need to proxy through backend)

**Rate limiting:** No documented limit - use conservative 10 req/sec
**Caching:** 90-day TTL (predictions updated infrequently)

#### MGI Functions (REST/Web Scraping)

**File:** `api/functions/mgi-functions.R`

**Pattern:** REST API or web scraping (no official REST API documented)

```r
#' Fetch MGI mouse phenotypes for orthologous gene
#'
#' @param symbol Human HGNC symbol
#' @return List with mouse models, phenotypes, alleles
fetch_mgi_phenotypes <- function(symbol) {
  # MGI search endpoint (not officially documented REST API)
  # Alternative: Parse HTML from MGI gene page

  # Approach 1: Try MGI JSON endpoint (used by their frontend)
  url <- sprintf(
    "https://www.informatics.jax.org/api/marker/%s",
    symbol
  )

  response <- request(url) %>%
    req_retry(
      max_tries = 3,
      max_seconds = 60,
      backoff = ~ 2^.x
    ) %>%
    req_timeout(30) %>%
    req_throttle(rate = 5) %>%  # Conservative rate limit
    req_perform()

  if (resp_status(response) == 404) {
    return(list(error = "No mouse ortholog found"))
  }

  if (resp_status(response) != 200) {
    # Fallback: web scraping
    return(scrape_mgi_phenotypes(symbol))
  }

  data <- resp_body_json(response)

  return(list(
    mgi_id = data$mgi_id,
    mouse_symbol = data$symbol,
    human_ortholog = symbol,
    phenotypes = data$phenotypes,
    models = data$alleles
  ))
}

#' Scrape MGI phenotypes from HTML (fallback)
scrape_mgi_phenotypes <- function(symbol) {
  # Implementation using rvest for HTML parsing
  # Similar to existing genereviews-functions.R pattern
}
```

**Rate limiting:** No official API - use 5 req/sec conservatively
**Caching:** 30-day TTL (mouse phenotype data relatively stable)

### Caching Strategy

**Pattern: Per-source cache directories with TTL policies**

Following established pattern from `analyses-functions.R`:

```r
# In start_sysndd_api.R

# Caching configuration
cache_external <- cachem::cache_disk(
  dir = "/app/cache/external",
  max_age = Inf,  # Per-function TTL (see below)
  max_size = 1024 * 1024^2  # 1 GB
)

# Memoize external data functions
fetch_gnomad_data_cached <<- memoise(
  fetch_gnomad_data,
  cache = cache_external,
  # gnomAD constraint data stable - 7 day TTL
  ttl = 7 * 24 * 3600
)

fetch_uniprot_domains_cached <<- memoise(
  fetch_uniprot_domains,
  cache = cache_external,
  # Protein domains very stable - 30 day TTL
  ttl = 30 * 24 * 3600
)

fetch_ensembl_structure_cached <<- memoise(
  fetch_ensembl_structure,
  cache = cache_external,
  # Gene structure stable between releases - 90 day TTL
  ttl = 90 * 24 * 3600
)

fetch_alphafold_urls_cached <<- memoise(
  fetch_alphafold_urls,
  cache = cache_external,
  # Structure predictions updated infrequently - 90 day TTL
  ttl = 90 * 24 * 3600
)

fetch_mgi_phenotypes_cached <<- memoise(
  fetch_mgi_phenotypes,
  cache = cache_external,
  # Phenotype data moderately dynamic - 30 day TTL
  ttl = 30 * 24 * 3600
)
```

**Cache warming:** No proactive cache warming (lazy loading on first access)

**Cache invalidation:** Manual via Docker volume clear or `memoise::forget()` calls

**Cache structure:**
```
/app/cache/external/
├── gnomad/
│   ├── BRCA1.rds
│   └── TP53.rds
├── uniprot/
│   ├── P38398.rds
│   └── P04637.rds
├── ensembl/
├── alphafold/
└── mgi/
```

### Error Handling and Graceful Degradation

**Strategy: Fail independently, render partial data**

#### Backend Error Handling

Each function returns structured error:
```r
# Success
list(data = ..., status = "success")

# Partial failure (one source)
list(error = "API timeout", status = "error")

# 404 (no data)
list(error = "Not found", status = "not_found")
```

#### Combined Endpoint Error Handling

```r
fetch_gene_external_data <- function(symbol, ensembl_id, uniprot_id) {
  result <- list()

  # Each source isolated - one failure doesn't block others
  result$gnomad <- tryCatch(
    fetch_gnomad_data_cached(symbol),
    error = function(e) list(error = e$message, status = "error")
  )

  result$uniprot <- tryCatch(
    if (!is.null(uniprot_id)) {
      fetch_uniprot_domains_cached(uniprot_id)
    } else {
      list(error = "No UniProt ID provided", status = "not_found")
    },
    error = function(e) list(error = e$message, status = "error")
  )

  result$ensembl <- tryCatch(
    if (!is.null(ensembl_id)) {
      fetch_ensembl_structure_cached(ensembl_id)
    } else {
      list(error = "No Ensembl ID provided", status = "not_found")
    },
    error = function(e) list(error = e$message, status = "error")
  )

  result$alphafold <- tryCatch(
    if (!is.null(uniprot_id)) {
      fetch_alphafold_urls_cached(uniprot_id)
    } else {
      list(error = "No UniProt ID provided", status = "not_found")
    },
    error = function(e) list(error = e$message, status = "error")
  )

  result$mgi <- tryCatch(
    fetch_mgi_phenotypes_cached(symbol),
    error = function(e) list(error = e$message, status = "error")
  )

  return(result)
}
```

#### Frontend Error Handling

**Pattern: Independent loading states per card**

```vue
<template>
  <BContainer>
    <!-- gnomAD Card -->
    <BCard v-if="gnomadData || gnomadError">
      <BSpinner v-if="gnomadLoading" />
      <ErrorAlert v-else-if="gnomadError" :message="gnomadError" />
      <GnomadConstraints v-else :data="gnomadData" />
    </BCard>

    <!-- UniProt Card -->
    <BCard v-if="uniprotData || uniprotError">
      <BSpinner v-if="uniprotLoading" />
      <ErrorAlert v-else-if="uniprotError" :message="uniprotError" />
      <ProteinDomains v-else :data="uniprotData" />
    </BCard>

    <!-- Show message if ALL sources fail -->
    <EmptyState v-if="allFailed" message="Unable to load external data" />
  </BContainer>
</template>
```

### Frontend Architecture

#### Composable Design

**Pattern: One composable per source + aggregation composable**

Following established `useNetworkData.ts` pattern:

```typescript
// composables/useGnomadData.ts
export function useGnomadData() {
  const data = ref(null)
  const isLoading = ref(false)
  const error = ref(null)

  async function fetchGnomadData(symbol: string) {
    isLoading.value = true
    error.value = null

    try {
      const response = await axios.get(`/api/external/gnomad/${symbol}`)
      data.value = response.data
    } catch (e) {
      error.value = e.message
    } finally {
      isLoading.value = false
    }
  }

  return { data, isLoading, error, fetchGnomadData }
}

// composables/useGeneExternalData.ts
export function useGeneExternalData() {
  const gnomad = useGnomadData()
  const uniprot = useUniprotData()
  const ensembl = useEnsemblData()
  const alphafold = useAlphafoldData()
  const mgi = useMgiData()

  const isLoading = computed(() =>
    gnomad.isLoading.value ||
    uniprot.isLoading.value ||
    ensembl.isLoading.value ||
    alphafold.isLoading.value ||
    mgi.isLoading.value
  )

  async function fetchAllExternalData(symbol, ensemblId, uniprotId) {
    // Parallel fetch
    await Promise.allSettled([
      gnomad.fetchGnomadData(symbol),
      uniprot.fetchUniprotData(uniprotId),
      ensembl.fetchEnsemblData(ensemblId),
      alphafold.fetchAlphafoldData(uniprotId),
      mgi.fetchMgiData(symbol)
    ])
  }

  return {
    gnomad: gnomad.data,
    uniprot: uniprot.data,
    ensembl: ensembl.data,
    alphafold: alphafold.data,
    mgi: mgi.data,
    isLoading,
    fetchAllExternalData
  }
}
```

**Alternative: Combined endpoint approach**

```typescript
// composables/useGeneExternalData.ts (simplified)
export function useGeneExternalData() {
  const data = ref(null)
  const isLoading = ref(false)
  const errors = ref({})

  async function fetchAllExternalData(symbol, ensemblId, uniprotId) {
    isLoading.value = true

    try {
      const response = await axios.get(`/api/external/gene/${symbol}`, {
        params: { ensembl_id: ensemblId, uniprot_id: uniprotId }
      })

      data.value = response.data

      // Extract errors from response
      Object.keys(data.value).forEach(source => {
        if (data.value[source]?.error) {
          errors.value[source] = data.value[source].error
        }
      })
    } catch (e) {
      errors.value.general = e.message
    } finally {
      isLoading.value = false
    }
  }

  return {
    gnomadData: computed(() => data.value?.gnomad),
    uniprotData: computed(() => data.value?.uniprot),
    ensemblData: computed(() => data.value?.ensembl),
    alphafoldData: computed(() => data.value?.alphafold),
    mgiData: computed(() => data.value?.mgi),
    isLoading,
    errors,
    fetchAllExternalData
  }
}
```

**Recommendation:** Use combined endpoint approach (single request, simpler caching)

#### Component Hierarchy

```
GenePage.vue
├── GeneHeader.vue
├── GeneDetailsCard.vue
└── GeneExternalDataSection.vue
    ├── GnomadConstraintsCard.vue
    │   └── ConstraintsTable.vue
    ├── ProteinDomainsCard.vue
    │   └── DomainsVisualization.vue (D3.js)
    ├── GeneStructureCard.vue
    │   └── ExonVisualization.vue (D3.js)
    ├── AlphaFoldStructureCard.vue
    │   └── MolstarViewer.vue (external library)
    └── MgiPhenotypesCard.vue
        └── PhenotypesTable.vue
```

**Component location:**
```
app/src/components/
├── gene/                        # New directory for gene-specific components
│   ├── GeneExternalDataSection.vue
│   ├── GnomadConstraintsCard.vue
│   ├── ProteinDomainsCard.vue
│   ├── GeneStructureCard.vue
│   ├── AlphaFoldStructureCard.vue
│   └── MgiPhenotypesCard.vue
└── ui/                          # Reuse existing UI components
    ├── LoadingSkeleton.vue
    ├── EmptyState.vue
    └── ErrorAlert.vue
```

### D3.js Integration Pattern

**Pattern: Non-reactive D3 instance with Vue lifecycle hooks**

Following established `NetworkVisualization.vue` pattern (uses `let cy`, not `ref()`):

```vue
<script setup lang="ts">
import { ref, onMounted, onBeforeUnmount, watch } from 'vue'
import * as d3 from 'd3'

const svgRef = ref<SVGElement | null>(null)
let svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null = null

const props = defineProps<{
  domains: Array<{ start: number; end: number; name: string }>
  proteinLength: number
}>()

onMounted(() => {
  if (!svgRef.value) return

  // Initialize D3 (once)
  svg = d3.select(svgRef.value)

  // Initial render
  renderDomains()
})

onBeforeUnmount(() => {
  // Cleanup D3
  if (svg) {
    svg.selectAll('*').remove()
  }
})

watch(() => props.domains, () => {
  if (svg) renderDomains()
})

function renderDomains() {
  if (!svg) return

  // Clear previous render
  svg.selectAll('*').remove()

  // Render domains
  const xScale = d3.scaleLinear()
    .domain([0, props.proteinLength])
    .range([0, 600])

  svg.selectAll('rect')
    .data(props.domains)
    .enter()
    .append('rect')
    .attr('x', d => xScale(d.start))
    .attr('width', d => xScale(d.end - d.start))
    .attr('height', 20)
    .attr('fill', '#3498db')

  // Add labels, axes, etc.
}
</script>

<template>
  <svg ref="svgRef" width="600" height="100"></svg>
</template>
```

**Key principles:**
1. **Use ref for DOM element** - `const svgRef = ref<SVGElement | null>(null)`
2. **Use let for D3 instance** - `let svg = d3.select(svgRef.value)` (NOT `ref()`)
3. **Initialize in onMounted** - Ensures DOM is ready
4. **Cleanup in onBeforeUnmount** - Remove listeners, clear elements
5. **Use watch for reactive updates** - Re-render on data changes

### Loading States Pattern

**Pattern: Parallel data fetching with independent loading indicators**

```vue
<script setup lang="ts">
const { gnomadData, isGnomadLoading } = useGnomadData()
const { uniprotData, isUniprotLoading } = useUniprotData()
// ... other sources

onMounted(async () => {
  // Fetch in parallel - don't wait for each to complete
  gnomad.fetchGnomadData(symbol.value)
  uniprot.fetchUniprotData(uniprotId.value)
  ensembl.fetchEnsemblData(ensemblId.value)
  alphafold.fetchAlphafoldData(uniprotId.value)
  mgi.fetchMgiData(symbol.value)
})
</script>

<template>
  <BRow>
    <BCol md="6">
      <BCard>
        <template #header>
          gnomAD Constraints
          <BSpinner v-if="isGnomadLoading" small class="ms-2" />
        </template>
        <LoadingSkeleton v-if="isGnomadLoading" />
        <ErrorAlert v-else-if="gnomadError" />
        <ConstraintsTable v-else :data="gnomadData" />
      </BCard>
    </BCol>

    <BCol md="6">
      <BCard>
        <template #header>
          Protein Domains
          <BSpinner v-if="isUniprotLoading" small class="ms-2" />
        </template>
        <LoadingSkeleton v-if="isUniprotLoading" />
        <ErrorAlert v-else-if="uniprotError" />
        <DomainsVisualization v-else :data="uniprotData" />
      </BCard>
    </BCol>
  </BRow>
</template>
```

**Loading skeleton reuse:** Existing `LoadingSkeleton.vue` component supports `rows` prop

### 3D Structure Loading (AlphaFold)

**Special case: Backend provides URL only, frontend loads file directly**

**Rationale:**
1. PDB files are large (typically 1-5 MB)
2. No need to proxy through backend (adds latency + memory pressure)
3. AlphaFold CDN is fast and reliable
4. Mol* viewer library loads files directly from URL

```vue
<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { createPluginUI } from 'molstar/lib/mol-plugin-ui'

const viewerContainer = ref<HTMLDivElement | null>(null)
let viewer: any = null

const props = defineProps<{
  pdbUrl: string
}>()

onMounted(async () => {
  if (!viewerContainer.value) return

  // Initialize Mol* viewer
  viewer = await createPluginUI({
    target: viewerContainer.value,
    render: {
      preferWebGl1: false
    }
  })

  // Load structure directly from URL
  await viewer.loadStructureFromUrl(props.pdbUrl, 'pdb')
})

onBeforeUnmount(() => {
  if (viewer) viewer.dispose()
})
</script>

<template>
  <div ref="viewerContainer" style="width: 100%; height: 500px;"></div>
</template>
```

**Backend responsibility:** Provide URL + metadata only
**Frontend responsibility:** Fetch file, render 3D structure

## Data Flow Diagrams

### Combined Endpoint Flow

```
User navigates to Gene Page (symbol: "BRCA1")
    ↓
Vue component onMounted
    ↓
useGeneExternalData.fetchAllExternalData("BRCA1", "ENSG...", "P38398")
    ↓
Single axios GET /api/external/gene/BRCA1?ensembl_id=...&uniprot_id=...
    ↓
external_genomic_endpoints.R: fetch_gene_external_data()
    ↓
    ├─→ fetch_gnomad_data_cached("BRCA1")
    │   ├─→ Check cache (7-day TTL)
    │   └─→ If miss: GraphQL query → gnomad.broadinstitute.org
    │
    ├─→ fetch_uniprot_domains_cached("P38398")
    │   ├─→ Check cache (30-day TTL)
    │   └─→ If miss: REST GET → rest.uniprot.org
    │
    ├─→ fetch_ensembl_structure_cached("ENSG...")
    │   ├─→ Check cache (90-day TTL)
    │   └─→ If miss: REST GET → rest.ensembl.org
    │
    ├─→ fetch_alphafold_urls_cached("P38398")
    │   ├─→ Check cache (90-day TTL)
    │   └─→ If miss: REST GET → alphafold.ebi.ac.uk
    │
    └─→ fetch_mgi_phenotypes_cached("BRCA1")
        ├─→ Check cache (30-day TTL)
        └─→ If miss: REST/scrape → informatics.jax.org
    ↓
Aggregate results (with error isolation)
    ↓
Return JSON { gnomad: {...}, uniprot: {...}, ensembl: {...}, alphafold: {...}, mgi: {...} }
    ↓
Vue composable receives data
    ↓
Components render independently based on data availability
```

### Error Handling Flow

```
External API call fails (e.g., gnomAD timeout)
    ↓
httr2 retry logic (up to 5 attempts with exponential backoff)
    ↓
Still failing after retries
    ↓
Function returns { error: "message", status: "error" }
    ↓
fetch_gene_external_data() catches error, includes in result
    ↓
Frontend receives partial data: { gnomad: { error: "..." }, uniprot: {...}, ... }
    ↓
GnomadConstraintsCard shows ErrorAlert component
    ↓
Other cards render successfully with their data
```

### Cache Warming Flow (Future Enhancement)

```
Admin triggers cache refresh
    ↓
POST /api/admin/cache/warm
    ↓
Fetch all gene symbols from ndd_entity table
    ↓
For each gene (with rate limiting):
    ├─→ Fetch gnomAD data (cache stores for 7 days)
    ├─→ Fetch UniProt data (cache stores for 30 days)
    ├─→ ... (other sources)
    └─→ Progress reported via mirai job system
    ↓
Cache populated for frequently accessed genes
```

## Integration Points with Existing Architecture

### Reuse Existing Patterns

1. **httr2 retry logic** - Reuse pattern from `omim-functions.R`
2. **Disk-based caching** - Follow `analyses-functions.R` memoise pattern
3. **Composable data fetching** - Follow `useNetworkData.ts` pattern
4. **D3.js lifecycle** - Follow `NetworkVisualization.vue` pattern
5. **Error handling** - Follow `core/errors.R` httpproblems pattern
6. **Loading states** - Reuse `LoadingSkeleton.vue`, `EmptyState.vue`

### New Components Required

1. **Backend:**
   - `api/endpoints/external_genomic_endpoints.R` (new file)
   - `api/functions/gnomad-functions.R` (new file)
   - `api/functions/uniprot-functions.R` (new file)
   - `api/functions/alphafold-functions.R` (new file)
   - `api/functions/mgi-functions.R` (new file)
   - Extend `api/functions/ensembl-functions.R` (existing file)

2. **Frontend:**
   - `app/src/composables/useGnomadData.ts` (new file)
   - `app/src/composables/useUniprotData.ts` (new file)
   - `app/src/composables/useEnsemblData.ts` (new file)
   - `app/src/composables/useAlphafoldData.ts` (new file)
   - `app/src/composables/useMgiData.ts` (new file)
   - `app/src/composables/useGeneExternalData.ts` (aggregator)
   - `app/src/components/gene/*` (6 new components)

### Modified Components

1. **Backend:**
   - `api/start_sysndd_api.R` - Add memoization for new functions
   - `api/functions/ensembl-functions.R` - Extend with REST API functions

2. **Frontend:**
   - `app/src/views/Gene.vue` (or create if not exists) - Add external data section
   - `app/src/composables/index.ts` - Export new composables

## Build Order and Dependencies

### Phase 1: Backend Foundation (Week 1)

**Goal:** Establish endpoint structure, implement one source end-to-end

1. Create `api/functions/gnomad-functions.R`
   - Implement `fetch_gnomad_data()` with httr2 retry logic
   - Add unit tests for GraphQL queries
   - Test rate limiting behavior

2. Create `api/endpoints/external_genomic_endpoints.R`
   - Implement `/api/external/gnomad/<symbol>` endpoint
   - Add OpenAPI documentation

3. Update `api/start_sysndd_api.R`
   - Add cache configuration for external data
   - Memoize `fetch_gnomad_data_cached()`
   - Mount new endpoint

**Validation:** Test gnomAD endpoint with curl, verify caching works

### Phase 2: Additional Backend Sources (Week 2)

**Goal:** Implement remaining sources in parallel

1. Implement `api/functions/uniprot-functions.R`
2. Implement `api/functions/alphafold-functions.R`
3. Implement `api/functions/mgi-functions.R`
4. Extend `api/functions/ensembl-functions.R`

5. Add endpoints to `external_genomic_endpoints.R`:
   - `/api/external/uniprot/<uniprot_id>`
   - `/api/external/alphafold/<uniprot_id>`
   - `/api/external/mgi/<symbol>`
   - `/api/external/ensembl/<ensembl_id>`

6. Add memoization for all functions in `start_sysndd_api.R`

**Validation:** Test all individual endpoints, verify rate limiting

### Phase 3: Combined Endpoint (Week 3)

**Goal:** Implement aggregation endpoint with error isolation

1. Implement `fetch_gene_external_data()` in `external_genomic_endpoints.R`
2. Add `/api/external/gene/<symbol>` endpoint
3. Test error isolation (simulate API failures)
4. Verify partial data responses

**Validation:** Test combined endpoint, verify graceful degradation

### Phase 4: Frontend Composables (Week 3-4)

**Goal:** Implement data fetching composables

1. Create individual composables:
   - `useGnomadData.ts`
   - `useUniprotData.ts`
   - `useEnsemblData.ts`
   - `useAlphafoldData.ts`
   - `useMgiData.ts`

2. Create aggregation composable:
   - `useGeneExternalData.ts`

3. Add to `composables/index.ts`

**Validation:** Unit tests for composables (vitest)

### Phase 5: Frontend Components (Week 4-5)

**Goal:** Implement UI components with D3.js visualizations

1. Create card components:
   - `GnomadConstraintsCard.vue`
   - `ProteinDomainsCard.vue` (with D3.js)
   - `GeneStructureCard.vue` (with D3.js)
   - `AlphaFoldStructureCard.vue` (with Mol* viewer)
   - `MgiPhenotypesCard.vue`

2. Create container:
   - `GeneExternalDataSection.vue`

3. Integrate into Gene page view

**Validation:** Visual testing, accessibility checks

### Phase 6: Error Handling & Polish (Week 6)

**Goal:** Comprehensive error handling and UX polish

1. Add error alerts with retry buttons
2. Implement loading skeletons
3. Add empty states for "no data" cases
4. Test all error scenarios
5. Performance optimization (lazy loading, code splitting)

**Dependencies:**

```
Phase 1 (gnomAD backend)
    ↓
Phase 2 (other sources) ← can parallelize
    ↓
Phase 3 (combined endpoint)
    ↓
Phase 4 (composables) ← depends on Phase 3
    ↓
Phase 5 (components) ← depends on Phase 4
    ↓
Phase 6 (polish) ← depends on Phase 5
```

## Rate Limiting Summary

| Source | Rate Limit | Strategy | Timeout | Retries |
|--------|-----------|----------|---------|---------|
| gnomAD | ~10 queries (strict) | `req_throttle(15/60)` + `req_retry(429)` | 30s | 5 |
| UniProt | 200 req/sec | `req_throttle(100)` | 20s | 3 |
| Ensembl | 15 req/sec (55k/hour) | `req_throttle(15)` + respect `Retry-After` | 30s | 5 |
| AlphaFold | No documented limit | `req_throttle(10)` (conservative) | 20s | 3 |
| MGI | No official API | `req_throttle(5)` (very conservative) | 30s | 3 |

**Proactive throttling preferred** - Use `req_throttle()` to prevent hitting rate limits rather than reactive `req_retry()` alone.

## Architecture Anti-Patterns to Avoid

### ❌ Anti-Pattern 1: Separate Endpoint Files Per Source

**Why bad:**
- 5 separate endpoint files → harder to maintain unified caching strategy
- Duplicates rate limiting configuration across files
- Combined endpoint becomes awkward (imports across files)

**Use instead:** Single `external_genomic_endpoints.R` file

### ❌ Anti-Pattern 2: Frontend Fetches External APIs Directly

**Why bad:**
- CORS issues with external APIs
- Rate limiting per user IP (exhausts limits quickly)
- No caching (every page load = API call)
- Exposes API keys in frontend

**Use instead:** Backend proxy with caching

### ❌ Anti-Pattern 3: Synchronous Sequential Fetching

**Why bad:**
```javascript
// BAD - 5 sequential requests (15+ seconds total)
await fetchGnomad()
await fetchUniprot()
await fetchEnsembl()
await fetchAlphafold()
await fetchMgi()
```

**Use instead:** Parallel fetching with `Promise.allSettled()`

### ❌ Anti-Pattern 4: Global Loading State

**Why bad:**
- Single loading spinner for all 5 sources
- User sees blank page until ALL sources complete
- One slow API blocks entire page

**Use instead:** Independent loading states per card

### ❌ Anti-Pattern 5: Reactive D3 Instance

**Why bad:**
```javascript
// BAD - D3 instance in ref() causes memory leaks
const svg = ref(d3.select(svgRef.value))
```

**Use instead:** Non-reactive D3 instance with `let` variable

### ❌ Anti-Pattern 6: No Error Isolation

**Why bad:**
- One API failure returns 500 for entire combined endpoint
- Frontend shows generic error for all cards

**Use instead:** `tryCatch` per source, return partial data

### ❌ Anti-Pattern 7: Backend Proxies Large Files

**Why bad:**
- AlphaFold PDB files are 1-5 MB
- Backend loads file → sends to frontend (doubles memory, adds latency)

**Use instead:** Backend returns URL only, frontend fetches directly

## Testing Strategy

### Backend Testing

1. **Unit tests for functions:**
   - Mock httr2 responses
   - Test rate limiting behavior
   - Test error handling
   - Test cache TTL

2. **Integration tests for endpoints:**
   - Test individual source endpoints
   - Test combined endpoint
   - Test error isolation
   - Test graceful degradation

3. **Performance tests:**
   - Measure cache hit rates
   - Measure response times
   - Test under concurrent load

### Frontend Testing

1. **Unit tests for composables:**
   - Mock axios responses
   - Test error handling
   - Test loading states

2. **Component tests:**
   - Test rendering with data
   - Test loading skeletons
   - Test error states
   - Test D3.js initialization/cleanup

3. **E2E tests:**
   - Test full gene page flow
   - Test error scenarios
   - Test partial data rendering

## Performance Considerations

1. **Backend caching:** Disk-based memoise reduces API calls by ~95%
2. **Parallel fetching:** 5 sources in parallel vs sequential (5x faster)
3. **Independent loading:** Cards render as data arrives (perceived performance)
4. **Lazy loading:** Code-split 3D viewer library (Mol* is ~2 MB)
5. **Cache warming:** Optional admin endpoint for popular genes

## Security Considerations

1. **Rate limiting:** Protects external APIs from abuse
2. **Input validation:** Sanitize gene symbols, IDs (prevent injection)
3. **Error messages:** Don't expose internal error details to frontend
4. **API keys:** Store in config, never expose to frontend
5. **CORS:** Backend proxy prevents CORS issues

## Monitoring and Observability

**Logging strategy:**

```r
# In each function
log_info("Fetching gnomAD data for {symbol}")

if (resp_status(response) != 200) {
  log_warn("gnomAD API error {resp_status(response)} for {symbol}")
}

# Cache hit/miss logging
if (memoise::has_cache(fetch_gnomad_data_cached)(symbol)) {
  log_debug("Cache hit for gnomAD:{symbol}")
} else {
  log_debug("Cache miss for gnomAD:{symbol}")
}
```

**Metrics to track:**
- API response times per source
- Cache hit rates
- Error rates per source
- Rate limit 429 occurrences

## Documentation Requirements

1. **API documentation:**
   - OpenAPI spec for all endpoints
   - Example requests/responses
   - Rate limiting details

2. **Developer documentation:**
   - How to add new external sources
   - Cache invalidation procedure
   - Troubleshooting guide

3. **User documentation:**
   - What data is displayed
   - Data source attributions
   - Update frequency

## Future Enhancements

1. **Cache warming:** Admin endpoint to pre-populate cache for popular genes
2. **Webhooks:** External APIs notify on data updates → invalidate cache
3. **Batch endpoints:** `/api/external/genes` for multiple genes at once
4. **GraphQL gateway:** Unified GraphQL API wrapping all sources
5. **Real-time updates:** WebSocket for streaming updates as sources respond

## Sources

### gnomAD API
- [gnomAD GraphQL API Documentation](https://broadinstitute.github.io/gnomad_methods/api_reference/)
- [gnomAD Browser GitHub](https://github.com/broadinstitute/gnomad-browser)
- [Rate Limiting Discussion](https://discuss.gnomad.broadinstitute.org/t/blocked-when-using-api-to-get-af/149)

### UniProt API
- [UniProt API Documentation](https://www.uniprot.org/help/api_queries)
- [UniProt REST API](https://www.uniprot.org/api-documentation/uniprotkb)
- [Proteins API Documentation](https://www.ebi.ac.uk/proteins/api/doc/)

### Ensembl API
- [Ensembl REST API Documentation](https://rest.ensembl.org/)
- [Rate Limits](https://github.com/Ensembl/ensembl-rest/wiki/Rate-Limits)
- [The Ensembl REST API](https://pmc.ncbi.nlm.nih.gov/articles/PMC4271150/)

### AlphaFold API
- [AlphaFold API Documentation](https://alphafold.ebi.ac.uk/api-docs)
- [AlphaFold Database 2025 Release](https://academic.oup.com/nar/advance-article/doi/10.1093/nar/gkaf1226/8340156)
- [AlphaFold Database Structure Extractor](https://pubmed.ncbi.nlm.nih.gov/41291409/)

### MGI
- [Mouse Genome Informatics](https://www.informatics.jax.org/)
- [MGI Database Documentation](https://academic.oup.com/genetics/article/227/1/iyae031/7635261)

### httr2 and R Best Practices
- [httr2 Retry Documentation](https://httr2.r-lib.org/reference/req_retry.html)
- [httr2 Throttle Documentation](https://httr2.r-lib.org/reference/req_throttle.html)
- [Wrapping APIs with httr2](https://httr2.r-lib.org/articles/wrapping-apis.html)

### Vue 3 and D3.js Integration
- [Using Vue 3's Composition API with D3](https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g)
- [Building Data Visualizations in Vue.js with D3.js](https://codezup.com/building-data-visualizations-vuejs-d3js/)
- [Effortless Sync: Building Interactive D3 & Vue 3 Components](https://medium.com/@walsebai/building-synchronized-components-using-d3-and-vue3-the-easy-way-3581eccde7e3)

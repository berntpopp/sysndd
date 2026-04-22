# Technology Stack - Gene Page Genomic Data Integration

**Project:** SysNDD v8.0 Gene Page Enhancements
**Researched:** 2026-01-27
**Confidence:** HIGH

## Executive Summary

This research focuses ONLY on new stack additions needed for gene page genomic data integration. The existing validated stack (Vue 3.5.25, TypeScript 5.9.3, Bootstrap-Vue-Next 0.42.0, R 4.4.3 with Plumber, httr2, memoise/cachem) remains unchanged.

**Critical Decision: Mol* over NGL.js** - Mol* is the recommended choice for 3D protein structure visualization. RCSB.org deprecated NGL.js in June 2024 in favor of Mol*, signaling the industry standard has shifted. While Mol* has a larger bundle size (74.4 MB vs 23 MB), it offers superior AlphaFold support, active maintenance (v5.5.0 released January 2026), and is used by PDBe, RCSB PDB, and AlphaFold DB.

**Key Additions:**
- Frontend: D3.js v7 (already in project), Mol* v5.5.0
- Backend: ghql v0.1.2 for GraphQL queries
- APIs: gnomAD v4.1 GraphQL, UniProt REST, Ensembl REST v15.10, AlphaFold DB API, MGI MouseMine

## New Stack Additions

### Frontend Visualization Libraries

| Technology | Version | Purpose | Why | Bundle Impact |
|------------|---------|---------|-----|---------------|
| **molstar** | 5.5.0 | 3D protein structure visualization with AlphaFold/PDB support | Industry standard (RCSB, PDBe, AlphaFoldDB), active maintenance, superior variant highlighting, NGL.js deprecated by RCSB (June 2024) | 74.4 MB unpacked (acceptable for specialized feature) |
| d3 | 7.4.2 | Lollipop plots for protein domains with ClinVar variants | **ALREADY IN PROJECT** - no new dependency | Already included |

**Rationale for Mol* over NGL.js:**
1. **Industry Adoption:** RCSB.org removed NGL.js as a viewer option on June 28, 2024, recommending full transition to Mol*
2. **Maintenance Status:** Mol* v5.5.0 released Jan 2026 (7 days ago); NGL.js v2.4.0 released April 2024 (9+ months ago, maintenance mode)
3. **AlphaFold Support:** Mol* is the official viewer for AlphaFold DB with native mmCIF/PDB/bCIF support
4. **Variant Highlighting:** Mol* has specialized mutation visualization (molstar-mutation project) with occupancy-based mutation frequency rendering
5. **Feature Set:** Mol* supports up to hundreds of superimposed structures simultaneously; NGL.js limited to simpler use cases
6. **Vue 3 Compatibility:** Both require `markRaw()` to avoid Proxy conflicts with WebGL - Mol* has better documentation for this pattern

**Bundle Size Trade-off:**
- Mol*: 74.4 MB unpacked (can exclude movie export features to save ~0.5 MB)
- NGL.js: 23 MB unpacked
- Decision: Accept larger size for future-proof, actively maintained solution used by major protein databases

### Backend API Clients (R/Plumber)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| **ghql** | 0.1.2 | GraphQL client for R | CRAN package, active (last release Sept 2025), designed for GraphQL queries, rOpenSci maintained |
| httr2 | (existing) | HTTP client for REST APIs | **ALREADY IN PROJECT** - used for UniProt, Ensembl, AlphaFold, MGI REST endpoints |
| jsonlite | (existing) | JSON parsing | **ALREADY IN PROJECT** - dependency of ghql and httr2 |
| memoise | (existing) | Response caching | **ALREADY IN PROJECT** - critical for external API rate limit management |
| cachem | (existing) | Cache backend | **ALREADY IN PROJECT** - used with memoise |

**New R Package Required:** `ghql` only

**Installation:**
```r
install.packages("ghql")
```

**Why ghql for gnomAD GraphQL:**
- Designed specifically for GraphQL (vs httr2 which is general HTTP)
- Supports query fragments and parameterized queries
- Integrates with graphql package for query validation via libgraphqlparser
- Active rOpenSci community support
- Clean R6 interface matches R/Plumber patterns

**Why NOT susographql or gqlr:**
- susographql: Survey Solutions-specific, unnecessary abstraction
- gqlr: Server-side GraphQL implementation, not a client

## External APIs

### gnomAD GraphQL API

**Version:** v4.1 (current as of Jan 2026)
**Endpoint:** https://gnomad.broadinstitute.org/api
**Method:** GraphQL POST requests
**Data:** Constraint scores (pLI, LOEUF), ClinVar variants, population allele frequencies

**Rate Limiting:**
- IP-based rate limiting (specific limits not publicly documented)
- User reports ~10 queries before blocking
- Whitelisting available via gs://gnomad-browser/whitelist.json
- **Mitigation:** R backend caching with memoise (already implemented for analysis endpoints)

**Recent Updates (TypeScript Migration, May 2023):**
- API language migrated from JavaScript to TypeScript
- No functional changes to service
- GraphQL schema unchanged

**Usage Pattern:**
```r
library(ghql)
library(jsonlite)

con <- GraphqlClient$new(url = "https://gnomad.broadinstitute.org/api")
qry <- Query$new()
qry$query('gene_constraint', '{
  gene(gene_symbol: "MECP2", reference_genome: GRCh38) {
    gnomad_constraint {
      pLI
      oe_lof_upper
    }
  }
}')
con$exec(qry$queries$gene_constraint) %>% fromJSON()
```

**Cache Key Strategy:** `gene_symbol + query_type` (constraint vs variants)

**Data Available:**
- Gene constraint metrics (pLI, LOEUF, z-scores)
- ClinVar variant annotations with genomic coordinates
- Exome and genome allele counts (ac, an fields)
- De novo variants (1,953 coding DNVs from v4.1)

**Confidence:** MEDIUM - Rate limits not documented but confirmed to exist; caching strategy mitigates

### UniProt REST API

**Version:** 2025_01 release (current as of Jan 2026)
**Endpoint:** https://www.uniprot.org/uniprotkb/{accession}
**Method:** REST GET requests
**Data:** Protein domains (Pfam), function annotations, sequence data

**Endpoints:**
- Entry: `/uniprotkb/{accession}.{format}` (JSON, XML, FASTA, TSV)
- Search: `/uniprotkb/search?query={query}` (paginated)
- Features: Included in entry response (domains, regions, sites)

**Formats:** JSON (recommended), XML, RDF, TSV, Excel, FASTA

**Rate Limiting:**
- No authentication required
- 303 million requests/month average (API is robust)
- No documented rate limits for reasonable use
- **Mitigation:** Cache UniProt responses with 24hr TTL (protein annotations change infrequently)

**Usage Pattern (httr2):**
```r
library(httr2)

request("https://www.uniprot.org/uniprotkb/P51587.json") %>%
  req_retry(max_tries = 3) %>%
  req_perform() %>%
  resp_body_json()
```

**Data Needed:**
- Pfam domain annotations (for lollipop plot x-axis)
- Protein length (for plot scaling)
- Function/disease associations (gene page text)

**Confidence:** HIGH - Well-documented API, no rate limits, reliable service

### Ensembl REST API

**Version:** 15.10 (current as of Jan 2026)
**Endpoint:** https://rest.ensembl.org
**Method:** REST GET requests
**Data:** Gene structure (exons, transcripts), genomic coordinates

**Key Endpoints:**
- `/lookup/symbol/{species}/{symbol}?expand=1` - Gene + transcripts + exons
- `/sequence/id/{id}` - Exon sequences
- Response formats: JSON, XML, FASTA

**Rate Limiting:**
- Polite usage encouraged (not explicitly limited for reasonable requests)
- **Mitigation:** Cache with 7-day TTL (gene structures rarely change)

**Usage Pattern (httr2):**
```r
request("https://rest.ensembl.org/lookup/symbol/homo_sapiens/MECP2") %>%
  req_url_query(expand = 1) %>%
  req_headers(Accept = "application/json") %>%
  req_retry(max_tries = 3) %>%
  req_perform() %>%
  resp_body_json()
```

**Data Needed:**
- Canonical transcript ID
- Exon coordinates (for gene structure diagram)
- Assembly name (GRCh37 vs GRCh38 handling)

**Confidence:** HIGH - Stable API, comprehensive documentation

### AlphaFold Database API

**Version:** v6 (241 million structures, current as of Jan 2026)
**Endpoint:** https://alphafold.ebi.ac.uk/api
**Method:** REST GET requests
**Data:** Predicted structure files (PDB, mmCIF, bCIF), pLDDT scores

**API Transition (Critical):**
- Dual Support Period: 9 months (ending June 25, 2026)
- Old API fields sunset: June 25, 2026
- New API keyed on UniProt accessions

**Endpoints:**
- `/prediction/{uniprot_accession}` - Metadata + file URLs
- Direct downloads: mmCIF, bCIF, PDB formats available via URLs in API response
- PAE (Predicted Aligned Error) JSON available

**Bulk Download Options:**
- Individual: API for single structures
- Organism-specific: 46 organisms via website
- Full dataset: 23 TiB via Google Cloud Public Datasets (not needed)

**Usage Pattern (httr2):**
```r
# Get structure metadata
request("https://alphafold.ebi.ac.uk/api/prediction/P51587") %>%
  req_perform() %>%
  resp_body_json()

# Response includes pdbUrl, cifUrl, bcifUrl for Mol* loading
```

**Mol* Integration:**
- Load via `bcifUrl` (binary CIF, faster) or `cifUrl`
- Mol* is official AlphaFold DB viewer
- Query parameter: `alphafold://P51587` loads structure directly

**Confidence:** HIGH - Official API, comprehensive documentation, Mol* native support

**Note:** Monitor API transition timeline (June 2026 sunset)

### MGI/JAX API (MouseMine)

**Version:** Weekly refresh (current as of Jan 2026)
**Endpoint:** https://mousemine.org/mousemine/service (MouseMine InterMine API)
**Alternative:** https://phenome.jax.org/about/api (Mouse Phenome Database API)
**Method:** REST GET requests (JSON/CSV)
**Data:** Mouse phenotypes, orthologs, model organism data

**API Options:**
1. **MouseMine API** (recommended): General MGI data warehouse, InterMine framework, weekly refresh
2. **MPD API**: Phenotype-specific endpoint, strain means, individual animal data

**Usage Pattern (httr2):**
```r
# MouseMine query for human gene ortholog phenotypes
# Endpoint supports InterMine web services API
# Returns JSON with mouse phenotype associations
```

**Rate Limiting:**
- Not explicitly documented
- **Mitigation:** Cache with 7-day TTL (mouse phenotypes change infrequently)

**Data Needed:**
- Mouse orthologs for human genes
- Phenotype annotations (MP terms)
- Model organism disease associations

**Confidence:** MEDIUM - API documented but less mature than UniProt/Ensembl; caching essential

## Integration Patterns

### Vue 3 + D3.js (Lollipop Plot)

**Pattern:** Composition API with `onMounted` lifecycle hook

**Approach:**
```typescript
import { ref, onMounted, watch } from 'vue'
import * as d3 from 'd3'

export default {
  setup(props) {
    const svgRef = ref<SVGSVGElement | null>(null)

    onMounted(() => {
      if (!svgRef.value) return

      const svg = d3.select(svgRef.value)
      // D3 rendering logic here
    })

    // Watch for data changes and re-render
    watch(() => props.variantData, () => {
      // Update D3 visualization
    })

    return { svgRef }
  }
}
```

**Key Points:**
- D3 DOM manipulation happens in `onMounted` after Vue mounts template
- Use `ref` for SVG element reference, not reactive data for D3 objects
- `watch` for data-driven updates
- Existing D3 v7.4.2 in project - no version upgrade needed

**Resources:**
- [Using Vue 3's Composition API with D3](https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g)
- [Vue 3 Composition API + D3.js](https://dev.to/isaozler/vue-3-composition-api-d3-js-n4n)
- [GitHub: muratkemaldar/using-vue3-with-d3](https://github.com/muratkemaldar/using-vue3-with-d3)

**Lollipop Plot Library:**
- **g3-lollipop.js** available (D3-based, designed for protein mutations)
- Decision: Custom D3 implementation for full control over SysNDD styling/branding
- Pfam domains from UniProt API provide x-axis scale
- ClinVar variants from gnomAD GraphQL provide lollipop positions

**Confidence:** HIGH - D3 + Vue 3 is well-documented pattern

### Vue 3 + Mol* (3D Structure)

**Pattern:** `markRaw()` to prevent Vue Proxy wrapping of WebGL objects

**Critical Vue 3 Compatibility Issue:**
- Vue 3 wraps objects in Proxy for reactivity
- WebGL libraries (Three.js, Mol*) fail when wrapped in Proxy
- Error: "Uncaught (in promise) DOMException: Proxy object could not be cloned"
- **Solution:** Use `markRaw()` on Mol* viewer instance

**Approach:**
```typescript
import { ref, onMounted, markRaw } from 'vue'
import { createPluginUI } from 'molstar/lib/mol-plugin-ui'
import 'molstar/lib/mol-plugin-ui/skin/light.scss'

export default {
  setup(props) {
    const viewerContainer = ref<HTMLDivElement | null>(null)
    const viewer = ref<any>(null) // Not reactive - holds markRaw instance

    onMounted(async () => {
      if (!viewerContainer.value) return

      // Create Mol* viewer and mark as non-reactive
      const molstarViewer = await createPluginUI({
        target: viewerContainer.value,
        render: {
          // Exclude movie export to save ~0.5 MB
        }
      })

      viewer.value = markRaw(molstarViewer) // Critical!

      // Load AlphaFold structure
      await viewer.value.builders.structure.loadPdb(
        `https://alphafold.ebi.ac.uk/files/AF-${props.uniprotId}-F1-model_v4.pdb`
      )
    })

    return { viewerContainer }
  }
}
```

**Key Points:**
1. **Never** assign Mol* instance to reactive Vue data
2. **Always** use `markRaw()` to opt out of reactivity
3. Assign to `ref.value` after `markRaw()` to avoid Proxy wrapping
4. Same pattern applies to NGL.js (reference: hnf1b-db uses `markRaw()` with NGL.js)

**Variant Highlighting with Mol*:**
- Use selection API to create residue selections
- Apply custom representations to highlight mutations
- Color by occupancy field (molstar-mutation pattern) for mutation frequency visualization
- ClinVar variants from gnomAD GraphQL provide residue positions

**Resources:**
- [Mol* Developer Documentation](https://molstar.org/docs/)
- [Vue 3 Proxy conflicts with WebGL (Three.js Issue #21075)](https://github.com/mrdoob/three.js/issues/21075)
- [Vue 3 markRaw API](https://vuejs.org/api/reactivity-advanced)
- [GitHub: fowler-lab/molstar-mutation](https://github.com/fowler-lab/molstar-mutation) (mutation visualization example)

**Confidence:** HIGH - Pattern documented, Mol* is mature library

### R/Plumber API Caching Strategy

**Pattern:** memoise + cachem with TTL-based invalidation

**Approach:**
```r
library(memoise)
library(cachem)
library(ghql)
library(httr2)

# Create cache with TTL
cache <- cache_disk(max_age = 24 * 60 * 60) # 24 hours

# Memoise gnomAD GraphQL queries
get_gnomad_constraint <- memoise(function(gene_symbol) {
  con <- GraphqlClient$new(url = "https://gnomad.broadinstitute.org/api")
  qry <- Query$new()
  qry$query('constraint', sprintf('{
    gene(gene_symbol: "%s", reference_genome: GRCh38) {
      gnomad_constraint {
        pLI
        oe_lof_upper
        oe_mis_upper
      }
    }
  }', gene_symbol))
  con$exec(qry$queries$constraint)
}, cache = cache)

# Memoise UniProt REST queries
get_uniprot_domains <- memoise(function(uniprot_id) {
  request(sprintf("https://www.uniprot.org/uniprotkb/%s.json", uniprot_id)) %>%
    req_retry(max_tries = 3) %>%
    req_perform() %>%
    resp_body_json()
}, cache = cache)
```

**Cache TTL Strategy:**

| API | TTL | Rationale |
|-----|-----|-----------|
| gnomAD GraphQL | 24 hours | Constraint scores rarely change; rate limit mitigation |
| UniProt REST | 24 hours | Protein domains stable; reviewed entries update quarterly |
| Ensembl REST | 7 days | Gene structures rarely change between genome builds |
| AlphaFold API | 7 days | Structure predictions stable; only metadata needed |
| MGI MouseMine | 7 days | Phenotype annotations update weekly; align with refresh cycle |

**Rate Limit Mitigation:**
- gnomAD: IP-based blocking after ~10 queries → 24hr cache ensures single query per gene per day
- Others: No documented limits, but caching reduces load and improves response time

**Existing Infrastructure:**
- memoise + cachem already used for analysis endpoints (clustering, network visualization)
- cache_disk() stores to file system (persistent across R sessions)
- Plumber endpoints already configured for JSON responses

**Confidence:** HIGH - Pattern already validated in project

## Installation

### Frontend (npm)

```bash
# New dependency only
npm install molstar@5.5.0

# D3.js already in package.json at v7.4.2
```

**package.json additions:**
```json
{
  "dependencies": {
    "molstar": "^5.5.0"
  },
  "devDependencies": {
    "@types/molstar": "latest"
  }
}
```

### Backend (R)

```r
# New dependency only
install.packages("ghql")

# Existing packages (no action needed)
# httr2, jsonlite, memoise, cachem already installed
```

**DESCRIPTION additions (if using renv):**
```
Imports:
    ghql
```

## What NOT to Add

| Technology | Why NOT |
|------------|---------|
| **NGL.js** | Deprecated by RCSB.org (June 2024), maintenance mode (last release April 2024), superseded by Mol* |
| **susographql** | Survey Solutions-specific GraphQL client, unnecessary abstraction over ghql |
| **gqlr** | Server-side GraphQL implementation, not a client library |
| **graphql** (R pkg) | Low-level parser only, not a client; ghql depends on it automatically |
| **g3-lollipop.js** | Pre-built lollipop library; custom D3 implementation preferred for SysNDD branding control |
| **axios** | Already have httr2 for R backend; frontend doesn't make direct API calls |
| **vue-d3** wrapper | Unnecessary abstraction; Composition API + onMounted is cleaner |
| **Three.js** standalone | Mol* includes Three.js internally; don't add as separate dependency |

## Bundle Impact Analysis

**New Frontend Dependencies:**

| Package | Unpacked Size | Impact | Justification |
|---------|---------------|--------|---------------|
| molstar | 74.4 MB | Large | Acceptable for specialized 3D visualization feature; used by major protein databases; can exclude movie export (~0.5 MB savings) |

**Existing Dependencies (no change):**

| Package | Version | Already in Project |
|---------|---------|-------------------|
| d3 | 7.4.2 | Yes |
| vue | 3.5.25 | Yes |
| typescript | 5.9.3 | Yes |

**Total Bundle Impact:** +74.4 MB (Mol* only)

**Mitigation Strategies:**
1. **Code Splitting:** Load Mol* only on gene pages with 3D structure (lazy import)
2. **Conditional Loading:** Check if AlphaFold structure exists before loading Mol*
3. **Feature Exclusion:** Exclude movie export, volume server features (can save ~0.5 MB)
4. **Caching:** Aggressive browser caching for Mol* bundle (changes infrequently)

**Example Code Splitting:**
```typescript
// In gene page component
const loadMolstar = () => import('molstar/lib/mol-plugin-ui')

if (props.hasAlphaFoldStructure) {
  const { createPluginUI } = await loadMolstar()
  // Initialize viewer
}
```

## Open Questions & Future Research

1. **gnomAD Rate Limits:** Specific numeric limits not documented; monitor in production and consider whitelisting if needed
2. **AlphaFold API Sunset (June 2026):** Dual support period ends; validate new API fields before June 25, 2026
3. **Mol* Bundle Optimization:** Test selective feature exclusion for bundle size reduction (movie export, volume server)
4. **ClinVar Direct API:** Currently accessing via gnomAD GraphQL; consider direct ClinVar API if gnomAD rate limits become problematic
5. **TypeScript Definitions for Mol*:** Check if @types/molstar exists or if manual type declarations needed

## Sources

### NGL.js vs Mol* Comparison
- [Molstar npm package](https://www.npmjs.com/package/molstar)
- [NGL.js npm package](https://www.npmjs.com/package/ngl)
- [Mol* Viewer: modern web app for 3D visualization (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8262734/)
- [Molstar GitHub repository](https://github.com/molstar/molstar)
- [NGL.js GitHub repository](https://github.com/nglviewer/ngl)
- [RCSB PDB NGL Viewer Deprecation Notice](https://www.rcsb.org/news/feature/65b42d3fc76ca3abcc925d15)
- [Mol* official website](https://molstar.org/)

### Vue 3 + WebGL Integration
- [Vue 3 Proxy conflicts with Three.js (Issue #21075)](https://github.com/mrdoob/three.js/issues/21075)
- [Vue 3 Proxy conflicts with Three.js (Issue #21019)](https://github.com/mrdoob/three.js/issues/21019)
- [Vue 3 markRaw API](https://vuejs.org/api/reactivity-advanced)
- [Vue 3 Best Practices (Medium)](https://medium.com/@ignatovich.dm/vue-3-best-practices-cb0a6e281ef4)

### Vue 3 + D3.js Integration
- [Using Vue 3's Composition API with D3 (DEV)](https://dev.to/muratkemaldar/using-vue-3-with-d3-composition-api-3h1g)
- [Vue 3 Composition API + D3.js (DEV)](https://dev.to/isaozler/vue-3-composition-api-d3-js-n4n)
- [GitHub: muratkemaldar/using-vue3-with-d3](https://github.com/muratkemaldar/using-vue3-with-d3)
- [Data visualization with Vue.js and D3 (LogRocket)](https://blog.logrocket.com/data-visualization-vue-js-d3/)

### gnomAD GraphQL API
- [gnomAD browser changelog](https://gnomad.broadinstitute.org/news/changelog/)
- [gnomAD browser GraphQL API (GitHub)](https://github.com/broadinstitute/gnomad-browser/tree/main/graphql-api)
- [gnomAD API GraphQL query examples (GitHub Gist)](https://gist.github.com/hliang/aad37d960adf42da16b3bad8677d7f19)
- [gnomAD discussion: Blocked when using API](https://discuss.gnomad.broadinstitute.org/t/blocked-when-using-api-to-get-af/149)

### UniProt REST API
- [UniProt website API (NAR)](https://academic.oup.com/nar/article/53/W1/W547/8126256)
- [UniProt programmatic access documentation](https://www.uniprot.org/help/programmatic_access)
- [UniProt API documentation](https://www.uniprot.org/api-documentation/uniprotkb)

### Ensembl REST API
- [Ensembl REST API endpoints](https://rest.ensembl.org/)
- [Ensembl REST API documentation](https://ensemblrest.readthedocs.io/en/latest/)
- [Biostars: Get exon positions using Ensembl REST API](https://www.biostars.org/p/412149/)

### AlphaFold Database API
- [AlphaFold Protein Structure Database downloads](https://alphafold.ebi.ac.uk/download)
- [AlphaFold API documentation](https://alphafold.ebi.ac.uk/api-docs)
- [AlphaFold Database release notes](https://www.ebi.ac.uk/pdbe/news/alphafold-database-release-notes)
- [AlphaFold Database Structure Extractor (PubMed)](https://pubmed.ncbi.nlm.nih.gov/41291409/)
- [AlphaFold Database Structure Extractor (BMC Bioinformatics)](https://link.springer.com/article/10.1186/s12859-025-06303-0)

### MGI/JAX API
- [Mouse Genome Informatics (MGI)](https://www.informatics.jax.org/)
- [MGI MouseMine data warehouse](https://www.informatics.jax.org/userhelp/MouseMine_help.shtml)
- [Mouse Phenome Database API](https://academic.oup.com/nar/article/48/D1/D716/5614177)
- [Mouse Phenome Database API (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7145612/)

### R GraphQL Clients
- [ghql: General Purpose GraphQL Client (CRAN)](https://cran.r-project.org/web/packages/ghql/index.html)
- [ghql GitHub repository](https://github.com/ropensci/ghql)
- [rOpenSci: Accessing GraphQL from R](https://ropensci.org/blog/2020/12/08/accessing-graphql-in-r/)
- [httr2 documentation](https://httr2.r-lib.org/)
- [httr2 1.0.0 announcement (Tidyverse)](https://tidyverse.org/blog/2023/11/httr2-1-0-0/)

### Protein Mutation Visualization
- [GitHub: fowler-lab/molstar-mutation](https://github.com/fowler-lab/molstar-mutation)
- [Molstar: Highlight a residue discussion](https://github.com/molstar/molstar/discussions/254)
- [GitHub: G3viz/g3lollipop.js](https://github.com/G3viz/g3lollipop.js/)
- [D3 Graph Gallery: Lollipop chart](https://d3-graph-gallery.com/lollipop.html)
- [NGL Viewer manual](http://nglviewer.org/ngl/api/manual/)

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| **Mol* vs NGL.js** | HIGH | RCSB deprecation notice (June 2024), Mol* v5.5.0 released Jan 2026, used by PDBe/RCSB/AlphaFoldDB |
| **D3.js Integration** | HIGH | Already in project v7.4.2, multiple Vue 3 Composition API examples, well-documented pattern |
| **ghql for GraphQL** | HIGH | CRAN package, active maintenance (v0.1.2 Sept 2025), rOpenSci supported |
| **UniProt API** | HIGH | Well-documented, 303M requests/month capacity, stable v2025_01 release |
| **Ensembl API** | HIGH | Version 15.10, comprehensive documentation, stable endpoints |
| **AlphaFold API** | MEDIUM-HIGH | API transition in progress (dual support until June 2026), monitor timeline |
| **gnomAD Rate Limits** | MEDIUM | Rate limiting exists but specific limits not documented; caching mitigates |
| **MGI MouseMine API** | MEDIUM | API documented but less mature than UniProt/Ensembl; InterMine framework is standard |
| **Bundle Impact** | HIGH | Mol* 74.4 MB confirmed, code splitting mitigates, acceptable for specialized feature |

## Ready for Roadmap Creation

This stack research provides:
1. **Clear technology choices:** Mol* (not NGL.js), ghql, existing D3/httr2
2. **Integration patterns:** Vue 3 + markRaw() for Mol*, Composition API for D3, memoise for caching
3. **API endpoints:** gnomAD v4.1 GraphQL, UniProt 2025_01, Ensembl 15.10, AlphaFold v6, MGI MouseMine
4. **Risk mitigation:** Rate limit caching, code splitting for bundle size, AlphaFold API transition monitoring
5. **Installation commands:** npm install molstar, install.packages("ghql")

**Gaps requiring phase-specific research:**
- gnomAD GraphQL query optimization (field selection, fragment reuse)
- Mol* variant highlighting implementation details (selection API, color schemes)
- D3 lollipop plot responsive design patterns (mobile vs desktop)
- ClinVar variant coordinate mapping (genomic → protein positions)

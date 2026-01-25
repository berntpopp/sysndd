# Gene Page Enhancement Plan

## Executive Summary

This document outlines a comprehensive plan to transform the SysNDD gene detail page from a basic data display into a modern, feature-rich genomic analysis interface. The enhancements include gnomAD constraint scores, ClinVar variant visualization (via gnomAD API), model organism data, interactive protein domain plots with variants, and 3D AlphaFold structure visualization.

**Important Architecture Decision:** All external API calls are routed through the R/Plumber backend to enable server-side caching, rate limiting, and avoid CORS issues. The frontend only communicates with internal API endpoints.

---

## 1. Current State Assessment

### 1.1 Current Gene Page (`/app/src/views/pages/Gene.vue`)

**What it displays:**
- Gene symbol with badge
- Gene name
- External database IDs: Entrez, Ensembl, UCSC, CCDS, UniProt, OMIM, MGI, RGD, STRING
- Links to: HGNC, SFARI, gene2phenotype, PanelApp, ClinGen
- Associated entities table

**Technical Stack:**
- Vue 3.5 with Options API
- Bootstrap-Vue-Next components (BTable stacked layout)
- Simple axios data fetching

### 1.2 Detailed Design Problems with Current Implementation

#### Problem 1: Stacked Table Misuse
The page uses `<BTable stacked>` to display a single gene's information. This creates a long vertical list where each field becomes its own row:
```
HGNC Symbol | [badge] [HGNC btn] [SFARI btn] [g2p btn] [PanelApp btn] [ClinGen btn]
Gene Name   | Actin-like protein 6B
Entrez      | [123456 btn]
Ensembl     | [ENSG... btn]
...11 more rows...
```
**Impact:** Users must scroll extensively; information is hard to scan quickly.

#### Problem 2: Visual Clutter in Symbol Row
The symbol cell contains 6 elements crammed together:
- GeneBadge component
- 5 identical `btn-xs outline-primary` buttons (HGNC, SFARI, g2p, PanelApp, ClinGen)

**Impact:** Overwhelming visual noise; no clear hierarchy between the gene symbol and external resources.

#### Problem 3: Repetitive Template Code (~200 lines)
The template has 11 nearly identical `<template #cell()>` blocks, each following this pattern:
```vue
<template #cell(entrez_id)="data">
  <BRow>
    <BRow v-for="id in data.item.entrez_id" :key="id">
      <BCol>
        <BButton v-if="id" class="btn-xs mx-2" variant="outline-primary" ...>
          <i class="bi bi-box-arrow-up-right" /> {{ id }}
        </BButton>
      </BCol>
    </BRow>
  </BRow>
</template>
```
**Impact:** Hard to maintain; no reusable component for external links.

#### Problem 4: No Logical Grouping of Information
Current display mixes:
- **Gene identifiers:** Entrez, Ensembl, UCSC, CCDS (sequence databases)
- **Protein resources:** UniProt, STRING
- **Clinical databases:** OMIM, ClinGen, PanelApp, SFARI, g2p
- **Model organisms:** MGI, RGD

All shown with identical styling in a flat list.
**Impact:** Users can't quickly find clinical vs. sequence information.

#### Problem 5: Poor Header Design
Header is minimal:
```vue
<h3>Gene: <GeneBadge :symbol="..." /></h3>
```
- Gene name not prominently displayed
- No quick summary (chromosome location, key IDs)
- No action buttons (copy, share, export)

**Impact:** Users must scan the table to find basic gene name.

#### Problem 6: Missing UX Features
- **No copy-to-clipboard:** Users must click external links just to get IDs
- **No empty state indicators:** Missing IDs show nothing (no "N/A" or dash)
- **No loading skeleton:** Just a spinner with no content preview
- **No responsive design:** Button rows wrap awkwardly on mobile

#### Problem 7: Inconsistent Link Patterns
- Symbol row: Gene-based clinical resources (SFARI, g2p, etc.)
- ID rows: Each ID links to its source database
- Some use HGNC ID (ClinGen), others use symbol (SFARI)

**Impact:** Confusing mental model; clinical links are hidden in the first row.

### 1.3 Current Data Categories (for redesign)

| Category | Fields | Purpose |
|----------|--------|---------|
| **Core Identity** | symbol, name, hgnc_id | Primary gene identification |
| **Sequence Databases** | entrez_id, ensembl_gene_id, ucsc_id, ccds_id | Genomic/transcript data |
| **Protein Resources** | uniprot_ids, STRING_id | Protein sequence/interactions |
| **Clinical Resources** | omim_id + links to ClinGen, SFARI, g2p, PanelApp | Disease associations |
| **Model Organisms** | mgd_id (mouse), rgd_id (rat) | Ortholog phenotypes |

---

## 2. Phase 0: Redesign Existing Content

**Priority: Must complete before adding new features**

### 2.1 Proposed New Layout for Existing Data

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ HERO SECTION                                                                │
│ ┌─────────────────────────────────────────────────────────────────────────┐ │
│ │  [GeneBadge: ACTL6B]                                      [Copy] [Share]│ │
│ │  Actin-like protein 6B                                                  │ │
│ │  HGNC:24124 • Chr 7q22.1 • Ensembl:ENSG00000077080                     │ │
│ └─────────────────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────┐  ┌───────────────────────────────────────┐ │
│  │ GENE IDENTIFIERS            │  │ CLINICAL RESOURCES                    │ │
│  │                             │  │                                       │ │
│  │ NCBI Gene    91 [copy] [↗]  │  │ Gene-Disease Curation                 │ │
│  │ Ensembl    ENSG... [copy][↗]│  │ ┌─────┐ ┌────────┐ ┌─────┐ ┌───────┐ │ │
│  │ UniProt    Q9P1E3 [copy][↗] │  │ │OMIM │ │ClinGen │ │SFARI│ │PanelApp│ │ │
│  │ UCSC       uc003... [copy]  │  │ └─────┘ └────────┘ └─────┘ └───────┘ │ │
│  │ CCDS       CCDS5... [copy]  │  │ ┌─────────────┐ ┌──────────────────┐ │ │
│  │                             │  │ │gene2phenotype│ │HGNC             │ │ │
│  │ Protein Interactions        │  │ └─────────────┘ └──────────────────┘ │ │
│  │ STRING   9606.EN... [↗]     │  │                                       │ │
│  └─────────────────────────────┘  └───────────────────────────────────────┘ │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ MODEL ORGANISMS                                                         ││
│  │                                                                         ││
│  │ 🐭 Mouse (MGI)              🐀 Rat (RGD)                               ││
│  │ MGI:1927578  [copy] [↗]     —  Not available                           ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐│
│  │ Associated SysNDD Entities (3)                              [Expand ▼] ││
│  │ [Existing TablesEntities - collapsible or summary first]               ││
│  └─────────────────────────────────────────────────────────────────────────┘│
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Breakdown

#### A. GeneHeroSection Component (NEW)
Replaces the current card header. Shows the most important info at a glance.

```vue
<!-- components/gene/GeneHeroSection.vue -->
<template>
  <div class="gene-hero bg-light rounded-3 p-4 mb-4">
    <div class="d-flex justify-content-between align-items-start">
      <div>
        <div class="d-flex align-items-center gap-3 mb-2">
          <GeneBadge :symbol="gene.symbol" size="xl" />
          <span class="badge bg-secondary">{{ gene.hgnc_id }}</span>
        </div>
        <h2 class="h4 text-muted mb-2">{{ gene.name }}</h2>
        <div class="text-muted small">
          <span v-if="gene.chromosome">Chr {{ gene.chromosome }}</span>
          <span class="mx-2">•</span>
          <span>{{ gene.ensembl_gene_id }}</span>
        </div>
      </div>
      <div class="d-flex gap-2">
        <BButton variant="outline-secondary" size="sm" @click="copyGeneInfo">
          <i class="bi bi-clipboard" /> Copy
        </BButton>
        <BButton variant="outline-secondary" size="sm" @click="shareGene">
          <i class="bi bi-share" /> Share
        </BButton>
      </div>
    </div>
  </div>
</template>
```

#### B. GeneIdentifiersCard Component (NEW)
Clean display of all database IDs with copy and link buttons.

```vue
<!-- components/gene/GeneIdentifiersCard.vue -->
<template>
  <BCard class="mb-3">
    <template #header>
      <h5 class="mb-0"><i class="bi bi-database" /> Gene Identifiers</h5>
    </template>

    <div class="identifier-list">
      <IdentifierRow
        v-for="id in identifiers"
        :key="id.key"
        :label="id.label"
        :value="id.value"
        :url="id.url"
        :copyable="true"
      />
    </div>

    <hr class="my-3" />

    <h6 class="text-muted small text-uppercase mb-2">Protein Interactions</h6>
    <IdentifierRow
      label="STRING"
      :value="gene.STRING_id"
      :url="stringUrl"
    />
  </BCard>
</template>
```

#### C. IdentifierRow Component (NEW - Reusable)
Eliminates the 11 repetitive template blocks.

```vue
<!-- components/gene/IdentifierRow.vue -->
<template>
  <div class="identifier-row d-flex justify-content-between align-items-center py-2 border-bottom">
    <div class="d-flex align-items-center gap-2">
      <span class="identifier-label text-muted">{{ label }}</span>
      <code v-if="value" class="identifier-value">{{ displayValue }}</code>
      <span v-else class="text-muted small">—</span>
    </div>
    <div v-if="value" class="identifier-actions d-flex gap-1">
      <BButton
        v-if="copyable"
        variant="link"
        size="sm"
        class="p-1"
        v-b-tooltip.hover
        title="Copy to clipboard"
        @click="copyValue"
      >
        <i class="bi bi-clipboard" />
      </BButton>
      <BButton
        v-if="url"
        variant="link"
        size="sm"
        class="p-1"
        :href="url"
        target="_blank"
        v-b-tooltip.hover
        :title="`Open in ${label}`"
      >
        <i class="bi bi-box-arrow-up-right" />
      </BButton>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useToast } from '@/composables'

const props = defineProps({
  label: String,
  value: [String, Array],
  url: String,
  copyable: { type: Boolean, default: true },
  truncate: { type: Number, default: 20 }
})

const { makeToast } = useToast()

const displayValue = computed(() => {
  if (Array.isArray(props.value)) {
    return props.value.join(', ')
  }
  if (props.value && props.value.length > props.truncate) {
    return props.value.substring(0, props.truncate) + '...'
  }
  return props.value
})

function copyValue() {
  const text = Array.isArray(props.value) ? props.value.join(', ') : props.value
  navigator.clipboard.writeText(text)
  makeToast(`Copied ${props.label}: ${text}`, 'Copied', 'success')
}
</script>

<style scoped>
.identifier-row:last-child {
  border-bottom: none !important;
}
.identifier-label {
  min-width: 100px;
  font-size: 0.875rem;
}
.identifier-value {
  font-size: 0.875rem;
  background: var(--bs-gray-100);
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
}
</style>
```

#### D. ClinicalResourcesCard Component (NEW)
Groups all clinical/disease-related links together with visual distinction.

```vue
<!-- components/gene/ClinicalResourcesCard.vue -->
<template>
  <BCard class="mb-3">
    <template #header>
      <h5 class="mb-0"><i class="bi bi-hospital" /> Clinical Resources</h5>
    </template>

    <p class="text-muted small mb-3">Gene-disease curation and clinical databases</p>

    <div class="resource-grid">
      <ResourceLink
        v-for="resource in clinicalResources"
        :key="resource.name"
        :name="resource.name"
        :url="resource.url"
        :icon="resource.icon"
        :description="resource.description"
        :available="resource.available"
      />
    </div>
  </BCard>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  gene: Object
})

const clinicalResources = computed(() => [
  {
    name: 'OMIM',
    url: props.gene.omim_id ? `https://www.omim.org/entry/${props.gene.omim_id}` : null,
    icon: 'bi-journal-medical',
    description: 'Mendelian inheritance',
    available: !!props.gene.omim_id
  },
  {
    name: 'ClinGen',
    url: `https://search.clinicalgenome.org/kb/genes/${props.gene.hgnc_id}`,
    icon: 'bi-clipboard2-pulse',
    description: 'Gene-disease validity',
    available: true
  },
  {
    name: 'SFARI',
    url: `https://gene.sfari.org/database/human-gene/${props.gene.symbol}`,
    icon: 'bi-puzzle',
    description: 'Autism research',
    available: true
  },
  {
    name: 'PanelApp',
    url: `https://panelapp.genomicsengland.co.uk/panels/entities/${props.gene.symbol}`,
    icon: 'bi-grid-3x3',
    description: 'Gene panels',
    available: true
  },
  {
    name: 'gene2phenotype',
    url: `https://www.ebi.ac.uk/gene2phenotype/search?panel=ALL&search_term=${props.gene.symbol}`,
    icon: 'bi-diagram-3',
    description: 'Genotype-phenotype',
    available: true
  },
  {
    name: 'HGNC',
    url: `https://www.genenames.org/data/gene-symbol-report/#!/symbol/${props.gene.symbol}`,
    icon: 'bi-bookmark-check',
    description: 'Official nomenclature',
    available: true
  }
])
</script>

<style scoped>
.resource-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(140px, 1fr));
  gap: 0.75rem;
}
</style>
```

#### E. ResourceLink Component (NEW)
Visual card-style links for clinical resources.

```vue
<!-- components/gene/ResourceLink.vue -->
<template>
  <a
    :href="available ? url : null"
    :class="['resource-link', { 'resource-link--disabled': !available }]"
    target="_blank"
    rel="noopener noreferrer"
  >
    <i :class="['bi', icon, 'resource-icon']" />
    <span class="resource-name">{{ name }}</span>
    <span class="resource-desc">{{ description }}</span>
    <i v-if="available" class="bi bi-box-arrow-up-right resource-external" />
    <span v-else class="resource-na">N/A</span>
  </a>
</template>

<style scoped>
.resource-link {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 0.75rem;
  border: 1px solid var(--bs-border-color);
  border-radius: 0.5rem;
  text-decoration: none;
  color: inherit;
  transition: all 0.2s ease;
  position: relative;
}
.resource-link:hover:not(.resource-link--disabled) {
  border-color: var(--bs-primary);
  background: var(--bs-primary-bg-subtle);
  transform: translateY(-2px);
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}
.resource-link--disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.resource-icon {
  font-size: 1.5rem;
  color: var(--bs-primary);
  margin-bottom: 0.25rem;
}
.resource-name {
  font-weight: 600;
  font-size: 0.875rem;
}
.resource-desc {
  font-size: 0.7rem;
  color: var(--bs-secondary);
  text-align: center;
}
.resource-external {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  font-size: 0.7rem;
  opacity: 0.5;
}
.resource-na {
  position: absolute;
  top: 0.5rem;
  right: 0.5rem;
  font-size: 0.6rem;
  color: var(--bs-secondary);
}
</style>
```

#### F. ModelOrganismsCard Component (NEW)
Dedicated section for ortholog data.

```vue
<!-- components/gene/ModelOrganismsCard.vue -->
<template>
  <BCard class="mb-3">
    <template #header>
      <h5 class="mb-0"><i class="bi bi-bug" /> Model Organisms</h5>
    </template>

    <BRow>
      <BCol md="6">
        <div class="organism-item">
          <span class="organism-emoji">🐭</span>
          <div class="organism-details">
            <span class="organism-name">Mouse (MGI)</span>
            <IdentifierRow
              v-if="gene.mgd_id"
              :label="''"
              :value="gene.mgd_id"
              :url="`http://www.informatics.jax.org/marker/${gene.mgd_id}`"
            />
            <span v-else class="text-muted small">Not available</span>
          </div>
        </div>
      </BCol>
      <BCol md="6">
        <div class="organism-item">
          <span class="organism-emoji">🐀</span>
          <div class="organism-details">
            <span class="organism-name">Rat (RGD)</span>
            <IdentifierRow
              v-if="gene.rgd_id"
              :label="''"
              :value="gene.rgd_id"
              :url="`https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=${gene.rgd_id}`"
            />
            <span v-else class="text-muted small">Not available</span>
          </div>
        </div>
      </BCol>
    </BRow>
  </BCard>
</template>
```

### 2.3 Refactored Gene.vue Structure

```vue
<!-- views/pages/Gene.vue (refactored) -->
<template>
  <div class="container-fluid">
    <BContainer fluid class="py-3">
      <!-- Loading skeleton -->
      <GenePageSkeleton v-if="loading" />

      <template v-else-if="gene">
        <!-- Hero Section -->
        <GeneHeroSection :gene="gene" />

        <!-- Main Content Grid -->
        <BRow>
          <!-- Left Column: Identifiers -->
          <BCol lg="5" xl="4">
            <GeneIdentifiersCard :gene="gene" />
          </BCol>

          <!-- Right Column: Clinical Resources -->
          <BCol lg="7" xl="8">
            <ClinicalResourcesCard :gene="gene" />
          </BCol>
        </BRow>

        <!-- Model Organisms (full width) -->
        <ModelOrganismsCard :gene="gene" />

        <!-- Associated Entities -->
        <BCard class="mb-3">
          <template #header>
            <div class="d-flex justify-content-between align-items-center">
              <h5 class="mb-0">
                <i class="bi bi-link-45deg" />
                Associated SysNDD Entities
                <BBadge variant="secondary" pill>{{ entitiesCount }}</BBadge>
              </h5>
              <BButton
                variant="link"
                size="sm"
                @click="entitiesExpanded = !entitiesExpanded"
              >
                {{ entitiesExpanded ? 'Collapse' : 'Expand' }}
              </BButton>
            </div>
          </template>

          <BCollapse v-model="entitiesExpanded">
            <TablesEntities
              :show-filter-controls="false"
              :show-pagination-controls="false"
              :filter-input="`equals(symbol,${gene.symbol})`"
            />
          </BCollapse>
        </BCard>
      </template>

      <!-- Error State -->
      <BAlert v-else variant="warning" show>
        Gene not found.
      </BAlert>
    </BContainer>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useHead } from '@unhead/vue'
import { useToast } from '@/composables'
import axios from 'axios'

// Components
import GeneHeroSection from '@/components/gene/GeneHeroSection.vue'
import GeneIdentifiersCard from '@/components/gene/GeneIdentifiersCard.vue'
import ClinicalResourcesCard from '@/components/gene/ClinicalResourcesCard.vue'
import ModelOrganismsCard from '@/components/gene/ModelOrganismsCard.vue'
import GenePageSkeleton from '@/components/gene/GenePageSkeleton.vue'
import TablesEntities from '@/components/tables/TablesEntities.vue'

const route = useRoute()
const router = useRouter()
const { makeToast } = useToast()

const gene = ref(null)
const loading = ref(true)
const entitiesExpanded = ref(true)
const entitiesCount = ref(0)

useHead({
  title: computed(() => gene.value ? `Gene: ${gene.value.symbol}` : 'Gene'),
  meta: [
    { name: 'description', content: computed(() =>
      gene.value ? `SysNDD information for ${gene.value.symbol} - ${gene.value.name}` : 'Gene information'
    )}
  ]
})

async function loadGeneInfo() {
  loading.value = true
  const symbol = route.params.symbol

  try {
    // Try HGNC ID first, then symbol
    let response = await axios.get(`${import.meta.env.VITE_API_URL}/api/gene/${symbol}?input_type=hgnc`)

    if (!response.data.length) {
      response = await axios.get(`${import.meta.env.VITE_API_URL}/api/gene/${symbol}?input_type=symbol`)
    }

    if (!response.data.length) {
      router.push('/PageNotFound')
      return
    }

    // Flatten arrays to single values for display (API returns arrays)
    gene.value = flattenGeneData(response.data[0])
  } catch (e) {
    makeToast(e.message, 'Error loading gene', 'danger')
  } finally {
    loading.value = false
  }
}

function flattenGeneData(data) {
  // Convert arrays to single values where appropriate
  const result = { ...data }
  for (const key of Object.keys(result)) {
    if (Array.isArray(result[key]) && result[key].length === 1) {
      result[key] = result[key][0]
    }
  }
  return result
}

onMounted(loadGeneInfo)
</script>
```

### 2.4 Styling Improvements

```scss
// assets/styles/gene-page.scss

// Card consistent styling
.gene-page {
  .card {
    border-radius: 0.75rem;
    border: 1px solid var(--bs-border-color);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);

    .card-header {
      background: transparent;
      border-bottom: 1px solid var(--bs-border-color);
      padding: 1rem 1.25rem;

      h5 {
        font-size: 1rem;
        font-weight: 600;
        color: var(--bs-gray-700);

        i {
          color: var(--bs-primary);
          margin-right: 0.5rem;
        }
      }
    }
  }
}

// Hero section
.gene-hero {
  background: linear-gradient(135deg, var(--bs-primary-bg-subtle) 0%, var(--bs-light) 100%);
  border: 1px solid var(--bs-border-color);
}

// Responsive adjustments
@media (max-width: 768px) {
  .resource-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .gene-hero {
    padding: 1rem !important;
  }
}
```

### 2.5 Benefits of Redesign

| Aspect | Before | After |
|--------|--------|-------|
| **Lines of template code** | ~350 lines | ~50 lines (components) |
| **Reusable components** | 0 | 6 new components |
| **Information grouping** | Flat list | 4 logical categories |
| **Copy to clipboard** | None | All IDs copyable |
| **Empty state handling** | Silent | "Not available" indicators |
| **Loading state** | Spinner only | Skeleton placeholder |
| **Mobile responsive** | Wrapping buttons | Grid-based layout |
| **Visual hierarchy** | All equal weight | Hero → Cards → Details |

---

## 3. Reference Implementations

### 3.1 kidney-genetics-db (Python/FastAPI + Vue 3)
- D3.js lollipop plots for protein domains and gene structure
- ClinVar variant integration with pathogenicity coloring
- gnomAD GraphQL API for constraint scores
- Mouse phenotype data from MGI/JAX
- Vuetify Material Design UI
- Evidence panel system with expandable cards

#### hnf1b-db (Vue 3)
- NGL.js 3D protein structure visualization
- Variant highlighting on 3D structure (ball+stick, spacefill)
- Distance calculations to functional regions
- ACMG pathogenicity color coding
- Multi-representation toggle (cartoon, surface, ball+stick)

#### gnomad-carrier-frequency (Vue 3)
- **ClinVar via gnomAD** - Uses `clinvar_variants` field in gnomAD GraphQL queries
- Batch processing for conflicting variant submissions
- Version-aware API client (v4.1, v3.1.2, v2.1.1)
- Configuration-driven approach

---

## 4. Proposed New Features

### 4.1 Feature Additions

| Feature | Priority | Complexity | Data Source |
|---------|----------|------------|-------------|
| gnomAD Constraint Scores | High | Medium | gnomAD GraphQL API (via backend) |
| ClinVar Variant Summary | High | Medium | **gnomAD GraphQL API** (via backend) |
| Protein Domain Lollipop Plot | High | High | UniProt REST + gnomAD ClinVar (via backend) |
| Gene Structure Lollipop Plot | Medium | High | Ensembl REST + gnomAD ClinVar (via backend) |
| 3D AlphaFold Structure | Medium | High | AlphaFold API (via backend) |
| Mouse/Rat Phenotypes | Medium | Medium | MGI/JAX API, RGD (via backend) |
| OMIM Phenotype Summary | Medium | Low | OMIM API (existing token, via backend) |

### 4.2 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          FRONTEND (Vue 3)                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  Gene.vue → Composables (useGeneData, useProteinPlot, etc.)         │    │
│  │  Only calls internal API: /api/external/*                           │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ axios (internal only)
┌─────────────────────────────────────────────────────────────────────────────┐
│                       BACKEND (R/Plumber)                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  /api/external/gnomad/{symbol}     → Constraints + ClinVar variants │    │
│  │  /api/external/uniprot/{uniprot}   → Protein domains & features     │    │
│  │  /api/external/ensembl/{ensembl}   → Gene structure, exons          │    │
│  │  /api/external/alphafold/{uniprot} → Structure file URL + metadata  │    │
│  │  /api/external/mgi/{symbol}        → Mouse phenotypes               │    │
│  │  /api/external/rgd/{symbol}        → Rat phenotypes                 │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                    ┌─────────┴─────────┐                                    │
│                    │   Caching Layer   │ (filesystem or memoise)            │
│                    └─────────┬─────────┘                                    │
└──────────────────────────────┼──────────────────────────────────────────────┘
                               │
                               ▼ httr2 / jsonlite (external calls)
┌─────────────────────────────────────────────────────────────────────────────┐
│                      EXTERNAL APIs                                           │
│  • gnomAD GraphQL (https://gnomad.broadinstitute.org/api)                   │
│  • UniProt REST (https://rest.uniprot.org)                                  │
│  • Ensembl REST (https://rest.ensembl.org)                                  │
│  • AlphaFold (https://alphafold.ebi.ac.uk)                                  │
│  • MGI/JAX (https://www.informatics.jax.org)                                │
│  • RGD (https://rest.rgd.mcw.edu)                                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Frontend Architecture

```
/app/src/
├── components/
│   ├── gene/                          # NEW: Gene-specific components
│   │   ├── GeneOverviewCard.vue       # Redesigned gene info card
│   │   ├── GnomadConstraintCard.vue   # pLI, LOEUF, missense scores
│   │   ├── ClinvarSummaryCard.vue     # Variant counts by classification
│   │   ├── ModelOrganismCard.vue      # Mouse/rat phenotype summary
│   │   ├── OmimPhenotypeCard.vue      # OMIM gene-phenotype associations
│   │   └── protein-structure/         # 3D visualization sub-components
│   │       ├── StructureViewer.vue    # NGL.js wrapper
│   │       ├── StructureControls.vue  # Representation toggles
│   │       └── VariantPanel.vue       # Variant list for structure
│   └── visualizations/                # NEW: D3 visualization components
│       ├── ProteinDomainPlot.vue      # Protein lollipop with domains
│       ├── GeneStructurePlot.vue      # Genomic lollipop with exons
│       └── ConstraintScoreGauge.vue   # Visual gauge for scores
├── composables/
│   ├── useGeneExternalData.ts        # Fetches from /api/external/* endpoints
│   ├── useD3Tooltip.ts               # Pinnable tooltip system
│   └── useNGLStructure.ts            # NGL.js Vue wrapper (local rendering)
├── utils/
│   └── dnaDistanceCalculator.ts      # 3D distance calculations (client-side)
└── constants/
    └── colorSchemes.ts               # ACMG colors, domain colors
```

---

## 5. Backend API Specifications (R/Plumber)

### 5.1 New Endpoint File Structure

```
/api/
├── endpoints/
│   ├── gene_endpoints.R              # Existing
│   ├── external_endpoints.R          # NEW: All external API proxies
│   └── ...
├── functions/
│   ├── gnomad-functions.R            # NEW: gnomAD GraphQL client
│   ├── uniprot-functions.R           # NEW: UniProt REST client
│   ├── ensembl-functions.R           # NEW: Ensembl REST client
│   ├── alphafold-functions.R         # NEW: AlphaFold API client
│   ├── mgi-functions.R               # NEW: MGI/JAX API client
│   ├── rgd-functions.R               # NEW: RGD API client
│   └── ...
└── config.yml                        # Add cache TTL settings
```

### 5.2 gnomAD Endpoint (Constraints + ClinVar)

**Endpoint:** `GET /api/external/gnomad/{symbol}`

**R Implementation:**
```r
# functions/gnomad-functions.R

library(httr2)
library(jsonlite)

GNOMAD_API_URL <- "https://gnomad.broadinstitute.org/api"

#' Fetch gene data from gnomAD including constraints and ClinVar variants
#' @param gene_symbol HGNC gene symbol
#' @param reference_genome Reference genome (default: GRCh38)
#' @param dataset gnomAD dataset (default: gnomad_r4)
#' @return List with constraints and clinvar_variants
fetch_gnomad_gene_data <- function(gene_symbol,
                                    reference_genome = "GRCh38",
                                    dataset = "gnomad_r4") {

  # GraphQL query - includes both constraints and ClinVar variants
  query <- sprintf('
    query {
      gene(gene_symbol: "%s", reference_genome: %s) {
        gene_id
        symbol
        gnomad_constraint {
          exp_lof
          obs_lof
          oe_lof
          oe_lof_lower
          oe_lof_upper
          pLI
          lof_z
          exp_mis
          obs_mis
          oe_mis
          oe_mis_lower
          oe_mis_upper
          mis_z
          exp_syn
          obs_syn
          oe_syn
          syn_z
          flags
        }
        clinvar_variants {
          variant_id
          clinvar_variation_id
          clinical_significance
          gold_stars
          review_status
          pos
          ref
          alt
          hgvsc
          hgvsp
          major_consequence
        }
      }
    }
  ', gene_symbol, reference_genome)

  response <- request(GNOMAD_API_URL) |>
    req_body_json(list(query = query)) |>
    req_perform()

  data <- resp_body_json(response)

  if (!is.null(data$errors)) {
    stop(paste("gnomAD API error:", data$errors[[1]]$message))
  }

  gene_data <- data$data$gene

  # Process ClinVar variants for summary
  clinvar_summary <- summarize_clinvar_variants(gene_data$clinvar_variants)

  list(
    gene_id = gene_data$gene_id,
    symbol = gene_data$symbol,
    constraints = gene_data$gnomad_constraint,
    clinvar_variants = gene_data$clinvar_variants,
    clinvar_summary = clinvar_summary
  )
}

#' Summarize ClinVar variants by classification
summarize_clinvar_variants <- function(variants) {
  if (is.null(variants) || length(variants) == 0) {
    return(list(
      total = 0,
      pathogenic = 0,
      likely_pathogenic = 0,
      uncertain = 0,
      likely_benign = 0,
      benign = 0,
      conflicting = 0
    ))
  }

  # Classification mapping
  classifications <- sapply(variants, function(v) {
    sig <- tolower(v$clinical_significance)
    if (grepl("pathogenic", sig) && !grepl("likely", sig) && !grepl("conflicting", sig)) {
      return("pathogenic")
    } else if (grepl("likely_pathogenic|likely pathogenic", sig)) {
      return("likely_pathogenic")
    } else if (grepl("uncertain|vus", sig)) {
      return("uncertain")
    } else if (grepl("likely_benign|likely benign", sig)) {
      return("likely_benign")
    } else if (grepl("benign", sig) && !grepl("likely", sig)) {
      return("benign")
    } else if (grepl("conflicting", sig)) {
      return("conflicting")
    } else {
      return("other")
    }
  })

  list(
    total = length(variants),
    pathogenic = sum(classifications == "pathogenic"),
    likely_pathogenic = sum(classifications == "likely_pathogenic"),
    uncertain = sum(classifications == "uncertain"),
    likely_benign = sum(classifications == "likely_benign"),
    benign = sum(classifications == "benign"),
    conflicting = sum(classifications == "conflicting")
  )
}

# Memoized version with caching
fetch_gnomad_gene_data_cached <- memoise::memoise(
  fetch_gnomad_gene_data,
  cache = cachem::cache_disk(dir = "cache/gnomad", max_age = 86400)  # 24h cache
)
```

**Plumber Endpoint:**
```r
# endpoints/external_endpoints.R

#* Get gnomAD gene data (constraints + ClinVar variants)
#* @param symbol Gene symbol (HGNC)
#* @param reference_genome Reference genome (GRCh38 or GRCh37)
#* @get /api/external/gnomad/<symbol>
function(symbol, reference_genome = "GRCh38") {
  tryCatch({
    data <- fetch_gnomad_gene_data_cached(
      gene_symbol = toupper(symbol),
      reference_genome = reference_genome
    )
    data
  }, error = function(e) {
    list(error = e$message)
  })
}
```

### 5.3 ClinVar Submissions for Conflicting Variants (Optional)

For variants with "conflicting" classifications, fetch individual submissions:

```r
#' Fetch ClinVar submissions for conflicting variants
#' @param variant_ids Vector of gnomAD variant IDs
#' @param reference_genome Reference genome
fetch_clinvar_submissions <- function(variant_ids, reference_genome = "GRCh38") {
  # Batch in groups of 50 to avoid query size limits
  batch_size <- 50
  all_submissions <- list()

  for (i in seq(1, length(variant_ids), by = batch_size)) {
    batch <- variant_ids[i:min(i + batch_size - 1, length(variant_ids))]

    # Build aliased query for batch
    variant_queries <- sapply(seq_along(batch), function(j) {
      sprintf('v%d: clinvar_variant(variant_id: "%s", reference_genome: %s) {
        variant_id
        submissions {
          clinical_significance
          submitter_name
          last_evaluated
        }
      }', j, batch[j], reference_genome)
    })

    query <- sprintf("query { %s }", paste(variant_queries, collapse = "\n"))

    response <- request(GNOMAD_API_URL) |>
      req_body_json(list(query = query)) |>
      req_perform()

    data <- resp_body_json(response)

    # Merge results
    for (name in names(data$data)) {
      if (!is.null(data$data[[name]])) {
        all_submissions[[data$data[[name]]$variant_id]] <- data$data[[name]]$submissions
      }
    }
  }

  all_submissions
}
```

### 5.4 UniProt Endpoint (Protein Domains)

**Endpoint:** `GET /api/external/uniprot/{uniprot_id}`

```r
# functions/uniprot-functions.R

UNIPROT_API_URL <- "https://rest.uniprot.org/uniprotkb"

#' Fetch protein information from UniProt
fetch_uniprot_protein <- function(uniprot_id) {
  url <- paste0(UNIPROT_API_URL, "/", uniprot_id, ".json")

  response <- request(url) |>
    req_perform()

  data <- resp_body_json(response)

  # Extract domains and features
  features <- data$features
  domains <- features[sapply(features, function(f) f$type %in% c("Domain", "Region", "Transmembrane", "Signal peptide", "Motif"))]

  list(
    accession = data$primaryAccession,
    protein_name = data$proteinDescription$recommendedName$fullName$value,
    gene_symbol = data$genes[[1]]$geneName$value,
    length = data$sequence$length,
    sequence = data$sequence$value,
    domains = lapply(domains, function(d) {
      list(
        type = d$type,
        description = d$description,
        start = d$location$start$value,
        end = d$location$end$value
      )
    })
  )
}

fetch_uniprot_protein_cached <- memoise::memoise(
  fetch_uniprot_protein,
  cache = cachem::cache_disk(dir = "cache/uniprot", max_age = 604800)  # 7 day cache
)
```

### 5.5 Ensembl Endpoint (Gene Structure)

**Endpoint:** `GET /api/external/ensembl/{ensembl_id}`

```r
# functions/ensembl-functions.R

ENSEMBL_API_URL <- "https://rest.ensembl.org"

#' Fetch gene structure from Ensembl
fetch_ensembl_gene <- function(ensembl_id) {
  # Get gene info
  gene_url <- paste0(ENSEMBL_API_URL, "/lookup/id/", ensembl_id, "?expand=1")

  response <- request(gene_url) |>
    req_headers(Accept = "application/json") |>
    req_perform()

  gene_data <- resp_body_json(response)

  # Find canonical transcript
  canonical <- NULL
  for (transcript in gene_data$Transcript) {
    if (isTRUE(transcript$is_canonical)) {
      canonical <- transcript
      break
    }
  }

  list(
    gene_id = gene_data$id,
    symbol = gene_data$display_name,
    chromosome = gene_data$seq_region_name,
    start = gene_data$start,
    end = gene_data$end,
    strand = ifelse(gene_data$strand == 1, "+", "-"),
    canonical_transcript = if (!is.null(canonical)) {
      list(
        transcript_id = canonical$id,
        exons = lapply(canonical$Exon, function(e) {
          list(
            exon_id = e$id,
            start = e$start,
            end = e$end
          )
        })
      )
    } else NULL
  )
}

fetch_ensembl_gene_cached <- memoise::memoise(
  fetch_ensembl_gene,
  cache = cachem::cache_disk(dir = "cache/ensembl", max_age = 604800)  # 7 day cache
)
```

### 5.6 AlphaFold Endpoint

**Endpoint:** `GET /api/external/alphafold/{uniprot_id}`

```r
# functions/alphafold-functions.R

ALPHAFOLD_API_URL <- "https://alphafold.ebi.ac.uk/api"

#' Get AlphaFold structure metadata and URLs
fetch_alphafold_info <- function(uniprot_id) {
  url <- paste0(ALPHAFOLD_API_URL, "/prediction/", uniprot_id)

  response <- request(url) |>
    req_perform()

  data <- resp_body_json(response)

  if (length(data) == 0) {
    return(list(available = FALSE))
  }

  entry <- data[[1]]

  list(
    available = TRUE,
    uniprot_id = entry$uniprotAccession,
    gene = entry$gene,
    organism = entry$organismScientificName,
    model_url = entry$cifUrl,
    pdb_url = entry$pdbUrl,
    pae_url = entry$paeImageUrl,
    confidence_url = entry$paeDocUrl,
    model_version = entry$latestVersion
  )
}

fetch_alphafold_info_cached <- memoise::memoise(
  fetch_alphafold_info,
  cache = cachem::cache_disk(dir = "cache/alphafold", max_age = 604800)  # 7 day cache
)
```

### 5.7 Model Organism Endpoints

**MGI Endpoint:** `GET /api/external/mgi/{symbol}`

```r
# functions/mgi-functions.R

#' Fetch mouse phenotypes from MGI
fetch_mgi_phenotypes <- function(gene_symbol) {
  # Use MGI MouseMine API
  url <- "https://www.mousemine.org/mousemine/service/query/results"

  query <- sprintf('<query model="genomic" view="Gene.symbol Gene.alleles.genotypes.phenotypeTerms.name Gene.alleles.genotypes.zygosity">
    <constraint path="Gene.symbol" op="=" value="%s"/>
    <constraint path="Gene.organism.taxonId" op="=" value="10090"/>
  </query>', gene_symbol)

  response <- request(url) |>
    req_url_query(query = query, format = "json") |>
    req_perform()

  data <- resp_body_json(response)

  # Process phenotypes
  phenotypes <- list()
  for (result in data$results) {
    term <- result[[2]]
    zygosity <- result[[3]]
    if (!is.null(term)) {
      if (is.null(phenotypes[[term]])) {
        phenotypes[[term]] <- list(term = term, zygosities = c())
      }
      phenotypes[[term]]$zygosities <- unique(c(phenotypes[[term]]$zygosities, zygosity))
    }
  }

  # Summarize
  list(
    symbol = gene_symbol,
    total_phenotypes = length(phenotypes),
    phenotypes = phenotypes,
    homozygous_count = sum(sapply(phenotypes, function(p) "homozygous" %in% p$zygosities)),
    heterozygous_count = sum(sapply(phenotypes, function(p) "heterozygous" %in% p$zygosities))
  )
}

fetch_mgi_phenotypes_cached <- memoise::memoise(
  fetch_mgi_phenotypes,
  cache = cachem::cache_disk(dir = "cache/mgi", max_age = 604800)  # 7 day cache
)
```

### 5.8 Combined Gene External Data Endpoint

**Endpoint:** `GET /api/external/gene/{symbol}`

This endpoint fetches all external data in parallel for efficiency:

```r
#* Get all external data for a gene
#* @param symbol Gene symbol (HGNC)
#* @param uniprot_id UniProt accession (optional, will lookup if not provided)
#* @param ensembl_id Ensembl gene ID (optional)
#* @get /api/external/gene/<symbol>
function(symbol, uniprot_id = NULL, ensembl_id = NULL) {
  # Use promises/future for parallel fetching
  results <- list()

  # gnomAD (constraints + ClinVar)
  tryCatch({
    results$gnomad <- fetch_gnomad_gene_data_cached(toupper(symbol))
  }, error = function(e) {
    results$gnomad <- list(error = e$message)
  })

  # UniProt (if ID provided)
  if (!is.null(uniprot_id)) {
    tryCatch({
      results$uniprot <- fetch_uniprot_protein_cached(uniprot_id)
    }, error = function(e) {
      results$uniprot <- list(error = e$message)
    })
  }

  # Ensembl (if ID provided)
  if (!is.null(ensembl_id)) {
    tryCatch({
      results$ensembl <- fetch_ensembl_gene_cached(ensembl_id)
    }, error = function(e) {
      results$ensembl <- list(error = e$message)
    })
  }

  # AlphaFold (if UniProt ID available)
  if (!is.null(uniprot_id)) {
    tryCatch({
      results$alphafold <- fetch_alphafold_info_cached(uniprot_id)
    }, error = function(e) {
      results$alphafold <- list(error = e$message)
    })
  }

  # MGI
  tryCatch({
    results$mgi <- fetch_mgi_phenotypes_cached(toupper(symbol))
  }, error = function(e) {
    results$mgi <- list(error = e$message)
  })

  results
}
```

---

## 6. Frontend Implementation

### 6.1 Composable for External Gene Data

```typescript
// composables/useGeneExternalData.ts
import { ref, computed } from 'vue'
import axios from 'axios'

interface GnomadConstraints {
  pLI: number
  oe_lof: number
  oe_lof_upper: number
  mis_z: number
  // ...
}

interface ClinvarSummary {
  total: number
  pathogenic: number
  likely_pathogenic: number
  uncertain: number
  likely_benign: number
  benign: number
  conflicting: number
}

interface ClinvarVariant {
  variant_id: string
  clinical_significance: string
  gold_stars: number
  pos: number
  hgvsp: string
  // ...
}

interface GeneExternalData {
  gnomad: {
    constraints: GnomadConstraints
    clinvar_variants: ClinvarVariant[]
    clinvar_summary: ClinvarSummary
  }
  uniprot: {
    accession: string
    length: number
    domains: Array<{ type: string; description: string; start: number; end: number }>
  }
  ensembl: {
    gene_id: string
    chromosome: string
    start: number
    end: number
    strand: string
    canonical_transcript: { exons: Array<{ start: number; end: number }> }
  }
  alphafold: {
    available: boolean
    model_url: string
  }
  mgi: {
    total_phenotypes: number
    homozygous_count: number
    heterozygous_count: number
  }
}

export function useGeneExternalData(geneSymbol: Ref<string>, uniprotId: Ref<string | null>, ensemblId: Ref<string | null>) {
  const data = ref<GeneExternalData | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function fetchData() {
    if (!geneSymbol.value) return

    loading.value = true
    error.value = null

    try {
      // Build query params
      const params = new URLSearchParams()
      if (uniprotId.value) params.append('uniprot_id', uniprotId.value)
      if (ensemblId.value) params.append('ensembl_id', ensemblId.value)

      const response = await axios.get(
        `${import.meta.env.VITE_API_URL}/api/external/gene/${geneSymbol.value}?${params}`
      )
      data.value = response.data
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to fetch external data'
    } finally {
      loading.value = false
    }
  }

  // Computed helpers
  const constraints = computed(() => data.value?.gnomad?.constraints)
  const clinvarSummary = computed(() => data.value?.gnomad?.clinvar_summary)
  const clinvarVariants = computed(() => data.value?.gnomad?.clinvar_variants || [])
  const proteinDomains = computed(() => data.value?.uniprot?.domains || [])
  const proteinLength = computed(() => data.value?.uniprot?.length)
  const alphafoldAvailable = computed(() => data.value?.alphafold?.available)
  const alphafoldUrl = computed(() => data.value?.alphafold?.model_url)
  const mousePhentypes = computed(() => data.value?.mgi)

  return {
    data,
    loading,
    error,
    fetchData,
    // Computed helpers
    constraints,
    clinvarSummary,
    clinvarVariants,
    proteinDomains,
    proteinLength,
    alphafoldAvailable,
    alphafoldUrl,
    mousePhentypes,
  }
}
```

### 6.2 3D Structure Loading (Special Case)

For NGL.js, the structure file must be loaded directly by the browser (WebGL context). The backend provides the URL, but NGL loads the file:

```typescript
// composables/useNGLStructure.ts
import { ref, onMounted, onUnmounted, markRaw, type Ref } from 'vue'
import * as NGL from 'ngl'

export function useNGLStructure(containerRef: Ref<HTMLElement | null>) {
  // Store NGL objects outside Vue reactivity to avoid conflicts
  let stage: NGL.Stage | null = null
  let structureComponent: any = null

  const loading = ref(false)
  const error = ref<string | null>(null)
  const loaded = ref(false)

  onMounted(() => {
    if (containerRef.value) {
      stage = markRaw(new NGL.Stage(containerRef.value, {
        backgroundColor: 'white',
        quality: 'medium',
        impostor: true,
        workerDefault: true,
      }))
    }
  })

  onUnmounted(() => {
    stage?.dispose()
    stage = null
    structureComponent = null
  })

  /**
   * Load AlphaFold structure
   * @param modelUrl URL from backend /api/external/alphafold endpoint
   */
  async function loadStructure(modelUrl: string) {
    if (!stage) {
      error.value = 'NGL Stage not initialized'
      return
    }

    loading.value = true
    error.value = null

    try {
      // Clear existing structure
      stage.removeAllComponents()

      // Load structure file directly (NGL handles CORS via proxy if needed)
      structureComponent = await stage.loadFile(modelUrl, { defaultRepresentation: false })

      // Add default cartoon representation colored by pLDDT (bfactor)
      structureComponent.addRepresentation('cartoon', {
        colorScheme: 'bfactor',
        colorScale: 'RdYlBu',
        colorReverse: true,
      })

      stage.autoView()
      loaded.value = true
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Failed to load structure'
      loaded.value = false
    } finally {
      loading.value = false
    }
  }

  function highlightVariant(residueNumber: number, color: string, label?: string) {
    if (!structureComponent) return

    const selection = `${residueNumber}`

    // Ball+stick representation
    structureComponent.addRepresentation('ball+stick', {
      sele: selection,
      color: color,
      multipleBond: 'symmetric',
    })

    // Semi-transparent spacefill overlay
    structureComponent.addRepresentation('spacefill', {
      sele: selection,
      color: color,
      opacity: 0.4,
      scale: 1.2,
    })

    // Label if provided
    if (label) {
      structureComponent.addRepresentation('label', {
        sele: selection,
        labelType: 'text',
        labelText: [label],
        color: '#000000',
        background: true,
        backgroundColor: '#ffffff',
        backgroundOpacity: 0.8,
      })
    }
  }

  function clearHighlights() {
    if (!structureComponent) return
    // Remove all representations except the base cartoon
    const reps = structureComponent.reprList.slice()
    reps.forEach((rep: any, index: number) => {
      if (index > 0) structureComponent.removeRepresentation(rep)
    })
  }

  function setRepresentation(type: 'cartoon' | 'surface' | 'ball+stick') {
    if (!structureComponent) return

    structureComponent.removeAllRepresentations()

    switch (type) {
      case 'cartoon':
        structureComponent.addRepresentation('cartoon', {
          colorScheme: 'bfactor',
          colorScale: 'RdYlBu',
          colorReverse: true,
        })
        break
      case 'surface':
        structureComponent.addRepresentation('surface', {
          colorScheme: 'bfactor',
          colorScale: 'RdYlBu',
          colorReverse: true,
          opacity: 0.7,
        })
        break
      case 'ball+stick':
        structureComponent.addRepresentation('ball+stick', {
          colorScheme: 'element',
        })
        break
    }
  }

  function resetView() {
    stage?.autoView()
  }

  return {
    loading,
    error,
    loaded,
    loadStructure,
    highlightVariant,
    clearHighlights,
    setRepresentation,
    resetView,
  }
}
```

---

## 7. UI/UX Redesign

### 7.1 Design Principles

Based on modern medical app design patterns:

1. **Card-based layout** - Each data category in its own card
2. **Visual hierarchy** - Most important data (scores, variants) prominently displayed
3. **Progressive disclosure** - Summary first, expandable details
4. **Consistent color coding** - ACMG colors throughout
5. **Responsive design** - Works on desktop and tablet
6. **Accessibility** - Proper contrast, screen reader support
7. **Data density balance** - Rich information without overwhelming

### 7.2 Proposed Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ GENE: ACTL6B                                                    [Actions ▼]│
│ Actin-like protein 6B                                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐  │
│  │ gnomAD Constraints  │  │ ClinVar Summary     │  │ External Links      │  │
│  │                     │  │ (via gnomAD)        │  │                     │  │
│  │ pLI: [====] 0.99    │  │ P/LP: 23 ●          │  │ HGNC  OMIM  UniProt │  │
│  │ LOEUF: 0.12         │  │ VUS: 45 ●           │  │ Ensembl  NCBI  MGI  │  │
│  │ mis_z: 3.2          │  │ B/LB: 12 ●          │  │ ClinGen  SFARI ...  │  │
│  └─────────────────────┘  └─────────────────────┘  └─────────────────────┘  │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Protein Domain Plot                                    [Filters ▼]   │  │
│  │ ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │ │  ●   ●●●  ●    ●●      ●                    ●●  ●    ●         │  │  │
│  │ │  │   │││  │    ││      │                    ││  │    │         │  │  │
│  │ │══╪═══╪╪╪══╪════╪╪══════╪════════════════════╪╪══╪════╪═════════│  │  │
│  │ │  1  [====Domain 1====][===Domain 2===]     [====Domain 3====]  │  │  │
│  │ │                                                              500│  │  │
│  │ └─────────────────────────────────────────────────────────────────┘  │  │
│  │ Legend: ● Pathogenic  ● Likely Path  ● VUS  ● Benign                 │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│  ┌────────────────────────────────────┐  ┌────────────────────────────────┐│
│  │ 3D Structure (AlphaFold)           │  │ Model Organisms                ││
│  │ ┌──────────────────────────────┐   │  │                                ││
│  │ │                              │   │  │ Mouse (MGI)                    ││
│  │ │       [3D Protein View]      │   │  │ ● 15 phenotypes (3 neuronal)   ││
│  │ │                              │   │  │ ├ Homozygous: 8                ││
│  │ │                              │   │  │ └ Conditional: 7              ││
│  │ └──────────────────────────────┘   │  │                                ││
│  │ [Cartoon] [Surface] [Ball+Stick]   │  │ Rat (RGD)                      ││
│  │ Variant: p.Arg177Gly (P) ▼         │  │ ● No phenotype data            ││
│  └────────────────────────────────────┘  └────────────────────────────────┘│
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Associated SysNDD Entities                                           │  │
│  │ [Existing TablesEntities component]                                  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Implementation Phases

### Phase 0: Redesign Existing Content (Week 1-2) - **PRIORITY**

**Tasks:**
1. Create `/app/src/components/gene/` directory structure
2. Implement `IdentifierRow.vue` - reusable identifier display with copy/link
3. Implement `ResourceLink.vue` - visual card-style external link
4. Implement `GeneHeroSection.vue` - prominent gene header with actions
5. Implement `GeneIdentifiersCard.vue` - grouped sequence database IDs
6. Implement `ClinicalResourcesCard.vue` - grouped clinical resource links
7. Implement `ModelOrganismsCard.vue` - MGI/RGD display
8. Implement `GenePageSkeleton.vue` - loading placeholder
9. Refactor `Gene.vue` to use new components (migrate to `<script setup>`)
10. Add copy-to-clipboard functionality
11. Add responsive styling

**Deliverables:**
- Redesigned gene page using existing data
- 6 new reusable components
- Copy-to-clipboard for all IDs
- Proper empty state handling ("Not available")
- Loading skeleton instead of spinner
- Responsive grid layout
- Reduced template code from ~350 to ~50 lines

**Why First:** Establishes component architecture and design patterns before adding complexity. Users immediately benefit from improved UX.

### Phase 1: Backend API Layer (Week 3-4)

**Tasks:**
1. Create `/api/functions/gnomad-functions.R` with GraphQL client
2. Create `/api/functions/uniprot-functions.R`
3. Create `/api/functions/ensembl-functions.R`
4. Create `/api/functions/alphafold-functions.R`
5. Create `/api/functions/mgi-functions.R` (enhanced with phenotype data)
6. Create `/api/endpoints/external_endpoints.R` with all proxy endpoints
7. Set up caching with `memoise` and `cachem`
8. Add configuration for cache TTLs in `config.yml`

**Deliverables:**
- All backend proxy endpoints functional
- Server-side caching working
- Unit tests for R functions

### Phase 2: gnomAD & ClinVar Integration (Week 5-6)

**Tasks:**
1. Create `useGeneExternalData` composable (calls backend endpoints)
2. Implement `GnomadConstraintCard.vue` - pLI, LOEUF, mis_z scores
3. Implement `ClinvarSummaryCard.vue` - variant counts by classification
4. Implement `ConstraintScoreGauge.vue` - visual score indicator
5. Set up color scheme constants (ACMG colors)
6. Add loading and error states

**Deliverables:**
- gnomAD constraint scores displayed with visual gauges
- ClinVar variant summary (via gnomAD) with pathogenicity counts
- Proper error handling for external API failures

### Phase 3: Protein Lollipop Visualization (Week 7-8)

**Tasks:**
1. Add D3.js v7 to package.json
2. Create `useD3Tooltip` composable for pinnable tooltips
3. Implement `ProteinDomainPlot.vue` - D3 lollipop visualization
4. Fetch protein domains from UniProt (via backend)
5. Map ClinVar variants to protein positions
6. Implement filter controls for variant classification
7. Add zoom/pan behavior

**Deliverables:**
- Interactive protein lollipop plot with domains and variants
- Filter by pathogenicity classification
- Zoomable plot with pinnable tooltips

### Phase 4: 3D AlphaFold Structure (Week 9-10)

**Tasks:**
1. Add NGL.js v2.4 to package.json
2. Create `useNGLStructure` composable (handles Vue reactivity issues)
3. Implement `StructureViewer.vue` - NGL.js wrapper
4. Implement `StructureControls.vue` - representation toggles
5. Implement `VariantPanel.vue` - variant list for selection
6. Load AlphaFold structures via backend URL
7. Highlight variants on 3D structure with ACMG colors

**Deliverables:**
- 3D AlphaFold structure viewer
- Variant highlighting (ball+stick, spacefill)
- Multiple representations (cartoon, surface, ball+stick)

### Phase 5: Model Organism Enhancement & Polish (Week 11-12)

**Tasks:**
1. Enhance `ModelOrganismsCard.vue` with phenotype data from backend
2. Add mouse phenotype counts and zygosity breakdown
3. Responsive design testing across devices
4. Performance optimization (lazy loading, virtualization)
5. Accessibility audit (WCAG 2.1 AA)
6. Unit tests for all new components
7. Documentation

**Deliverables:**
- Enhanced model organism cards with phenotype summaries
- Fully responsive design
- Optimized performance
- Comprehensive test coverage

---

## 9. Dependencies & Prerequisites

### 9.1 New npm Packages (Frontend)

```json
{
  "d3": "^7.9.0",
  "ngl": "^2.4.0"
}
```

### 9.2 New R Packages (Backend)

```r
# In api/renv.lock or install script
install.packages(c(
  "httr2",       # Modern HTTP client
  "memoise",     # Function memoization
  "cachem"       # Disk-based caching
))
```

### 9.3 Configuration Updates

Add to `/api/config.yml`:
```yaml
cache:
  gnomad_ttl: 86400      # 24 hours
  uniprot_ttl: 604800    # 7 days
  ensembl_ttl: 604800    # 7 days
  alphafold_ttl: 604800  # 7 days
  mgi_ttl: 604800        # 7 days
  cache_dir: "cache"     # Directory for cache files
```

---

## 10. Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| gnomAD API rate limiting | High | Server-side caching (24h TTL), batch requests |
| Large gene variant volume | Medium | Pagination in backend, lazy load details |
| AlphaFold structure unavailable | Low | Graceful fallback message |
| NGL.js Vue reactivity conflicts | Medium | Store NGL objects outside reactivity (markRaw) |
| D3.js rendering performance | Medium | Use canvas for >500 variants |
| External API changes | Low | Abstract behind backend functions |
| Cache disk space | Low | Set max cache size, periodic cleanup |

---

## 11. Success Metrics

1. **Functionality:** All planned features working correctly
2. **Performance:** Gene page loads in <3 seconds (with caching)
3. **Reliability:** External API failures handled gracefully with error messages
4. **Usability:** Positive user feedback on design changes
5. **Accessibility:** WCAG 2.1 AA compliance
6. **Code Quality:** All new components and functions have unit tests

---

## 12. References

### Code References
- kidney-genetics-db: `../kidney-genetics-db/frontend/src/components/visualizations/`
- hnf1b-db: `../hnf1b-db/frontend/src/components/gene/protein-structure/`
- gnomad-carrier-frequency: `../gnomad-carrier-frequency/src/api/queries/`

### Documentation
- [gnomAD Browser](https://gnomad.broadinstitute.org/)
- [gnomAD GraphQL API](https://github.com/broadinstitute/gnomad-browser)
- [UniProt REST API](https://www.uniprot.org/help/api)
- [Ensembl REST API](https://rest.ensembl.org/)
- [AlphaFold Database API](https://alphafold.ebi.ac.uk/api-docs)
- [NGL.js Documentation](https://nglviewer.org/)
- [D3.js Lollipop Charts](https://d3-graph-gallery.com/lollipop.html)

### UI Inspiration
- [Genomic Medical Website Design (Dribbble)](https://dribbble.com/shots/25204532-Genomic-Medical-Website-UI-UX-Design)
- [KoruUX Healthcare Design Examples](https://www.koruux.com/50-examples-of-healthcare-UI/)

---

## 13. Appendix: Color Schemes

### ACMG Pathogenicity Colors
```css
:root {
  --acmg-pathogenic: #D32F2F;
  --acmg-likely-pathogenic: #F57C00;
  --acmg-uncertain: #FBC02D;
  --acmg-likely-benign: #9CCC65;
  --acmg-benign: #388E3C;
  --acmg-conflicting: #7B1FA2;
}
```

### gnomAD GraphQL Query (Full)

```graphql
query GeneData($geneSymbol: String!, $referenceGenome: ReferenceGenomeId!, $dataset: DatasetId!) {
  gene(gene_symbol: $geneSymbol, reference_genome: $referenceGenome) {
    gene_id
    symbol

    # Constraint scores
    gnomad_constraint {
      exp_lof
      obs_lof
      oe_lof
      oe_lof_lower
      oe_lof_upper
      pLI
      lof_z
      exp_mis
      obs_mis
      oe_mis
      oe_mis_lower
      oe_mis_upper
      mis_z
      exp_syn
      obs_syn
      oe_syn
      syn_z
      flags
    }

    # ClinVar variants (embedded in gnomAD)
    clinvar_variants {
      variant_id
      clinvar_variation_id
      clinical_significance
      gold_stars
      review_status
      pos
      ref
      alt
      hgvsc
      hgvsp
      major_consequence
    }

    # Optional: gnomAD variants for allele frequencies
    variants(dataset: $dataset) {
      variant_id
      pos
      ref
      alt
      exome {
        ac
        an
      }
      genome {
        ac
        an
      }
      transcript_consequence {
        canonical
        consequence_terms
        hgvsc
        hgvsp
        lof
      }
    }
  }
}
```

---

*Document created: 2026-01-25*
*Last updated: 2026-01-25*
*Author: Claude (Bioinformatics & Software Engineering Assistant)*
*Version: 2.0*

**Key Change in v2.0:**
- ClinVar data now fetched via gnomAD API (`clinvar_variants` field) instead of NCBI Eutils
- ALL external API calls routed through R/Plumber backend with server-side caching
- Frontend only communicates with internal `/api/external/*` endpoints

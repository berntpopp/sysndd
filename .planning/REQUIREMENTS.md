# Requirements: SysNDD v10.0 Data Quality & AI Insights

**Defined:** 2026-01-31
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v10.0 Requirements

Requirements for data quality stabilization, literature research tools, and AI-assisted cluster interpretation. Each maps to roadmap phases.

### Bug Fixes

- [x] **BUG-01**: EIF2AK2 entity (sysndd:4375) - Publication 33236446 update completes correctly (#122)
- [x] **BUG-02**: GAP43 newly created entity is visible in entity list (#115)
- [x] **BUG-03**: MEF2C entity (sysndd:4512) updates save correctly (#114)
- [x] **BUG-04**: Viewer status users can view profile without auto-logout
- [x] **BUG-05**: Adding new PMID during re-review preserves existing PMIDs
- [x] **BUG-06**: Entities over time by gene displays correct counts (#44)
- [x] **BUG-07**: Disease renaming requires approval per review concept (#41) - WONTFIX
- [x] **BUG-08**: Re-reviewer identity preserved when changing reviews

### Variant Correlations

- [x] **VCOR-01**: VariantCorrelations view navigation links work correctly
- [x] **VCOR-02**: VariantCounts view navigation links work correctly

### Publications

- [x] **PUB-01**: Publications table has improved UX (pagination, search, filters)
- [x] **PUB-02**: Publication metadata fetched from PubMed API (title, journal, abstract)
- [x] **PUB-03**: PublicationsNDD TimePlot has improved visualization
- [x] **PUB-04**: PublicationsNDD Stats view displays correctly

### Pubtator

- [x] **PUBT-01**: PubtatorNDD Stats page displays correctly (fix broken)
- [x] **PUBT-02**: Gene prioritization list ranks genes by publication count, recency, coverage gap
- [x] **PUBT-03**: Novel gene alerts highlight Pubtator genes not in SysNDD entities
- [x] **PUBT-04**: User can explore gene-literature connections for research
- [x] **PUBT-05**: Curator can export prioritized gene list for offline planning
- [x] **PUBT-06**: Pubtator concept and purpose documented in views

### LLM Cluster Summaries

- [x] **LLM-01**: Gemini API client integrated using ellmer package
- [x] **LLM-02**: API key stored securely in environment variable (GEMINI_API_KEY)
- [x] **LLM-03**: Cluster summaries use structured JSON output schema
- [x] **LLM-04**: Entity validation checks all gene names exist in database
- [ ] **LLM-05**: Batch pre-generation job runs via mirai async system
- [ ] **LLM-06**: Summaries cached in database with hash-based invalidation
- [ ] **LLM-07**: Phenotype cluster summaries generated and displayed
- [ ] **LLM-08**: Functional cluster summaries generated and displayed
- [ ] **LLM-09**: LLM-as-judge validates summary accuracy
- [ ] **LLM-10**: Confidence scoring flags low-confidence summaries
- [ ] **LLM-11**: Admin panel for summary review and approval
- [ ] **LLM-12**: Summaries show "AI-generated" badge with validation status

### Admin

- [x] **ADMIN-01**: Admin comparisons functionality updated

### Infrastructure

- [x] **INFRA-01**: GitHub Pages deployed via GitHub Actions workflow (not gh-pages branch)

## Future Requirements

Deferred to v10.1+. Tracked but not in current roadmap.

### Publications Enhancements

- **PUB-05**: Citation count display (pmidcite/iCite integration)
- **PUB-06**: Author affiliation display from PubMed XML
- **PUB-07**: Related publications sidebar (semantic search)
- **PUB-08**: Full-text availability indicator (PMC badge)

### Pubtator Enhancements

- **PUBT-07**: Entity co-occurrence visualization (network view)
- **PUBT-08**: Curation queue integration (add to re-review batch button)
- **PUBT-09**: PubTator Cache Management improvements (ManageAnnotations) - page range selection, hard vs soft update controls

### LLM Enhancements

- **LLM-13**: Multi-language summary support
- **LLM-14**: Summary version history with comparison
- **LLM-15**: Cross-cluster comparison mode
- **LLM-16**: Domain-specific ontology fact-checking (HPO, GO term validation)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Real-time LLM generation on page load | API latency (2-5s) ruins UX; batch pre-generate instead |
| Frontend Gemini API calls | Exposes API key; backend-only |
| LLM-computed statistics | LLMs cannot reliably compute p-values; use existing enrichment |
| Custom LLM fine-tuning | Expensive, hard to maintain; use foundation model with prompts |
| Multiple LLM provider fallbacks | Prompt compatibility issues; single provider (Gemini) |
| User-facing prompt editing | Security risk; fixed validated templates only |
| Embedding-based semantic search | Infrastructure complexity; simple search sufficient for v10 |
| gemini.R package | Limited features; use ellmer instead |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BUG-01 | 55 | Complete |
| BUG-02 | 55 | Complete |
| BUG-03 | 55 | Complete |
| BUG-04 | 55 | Complete |
| BUG-05 | 55 | Complete |
| BUG-06 | 55 | Complete |
| BUG-07 | 55 | Complete (WONTFIX) |
| BUG-08 | 55 | Complete |
| VCOR-01 | 56 | Complete |
| VCOR-02 | 56 | Complete |
| PUB-01 | 56 | Complete |
| PUB-02 | 56 | Complete |
| PUB-03 | 56 | Complete |
| PUB-04 | 56 | Complete |
| PUBT-01 | 57 | Complete |
| PUBT-02 | 57 | Complete |
| PUBT-03 | 57 | Complete |
| PUBT-04 | 57 | Complete |
| PUBT-05 | 57 | Complete |
| PUBT-06 | 57 | Complete |
| LLM-01 | 58 | Complete |
| LLM-02 | 58 | Complete |
| LLM-03 | 58 | Complete |
| LLM-04 | 58 | Complete |
| LLM-05 | 59 | Pending |
| LLM-06 | 59 | Pending |
| LLM-07 | 60 | Pending |
| LLM-08 | 60 | Pending |
| LLM-09 | 61 | Pending |
| LLM-10 | 61 | Pending |
| LLM-11 | 61 | Pending |
| LLM-12 | 60 | Pending |
| ADMIN-01 | 62 | Complete |
| INFRA-01 | 62 | Complete |

**Coverage:**
- v10.0 requirements: 34 total
- Mapped to phases: 34 (100%)
- Unmapped: 0

---
*Requirements defined: 2026-01-31*
*Last updated: 2026-01-31 after roadmap creation*

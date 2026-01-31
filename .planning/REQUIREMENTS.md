# Requirements: SysNDD v10.0 Data Quality & AI Insights

**Defined:** 2026-01-31
**Core Value:** A new developer can clone the repo and be productive within minutes, with confidence that their changes won't break existing functionality.

## v10.0 Requirements

Requirements for data quality stabilization, literature research tools, and AI-assisted cluster interpretation. Each maps to roadmap phases.

### Bug Fixes

- [ ] **BUG-01**: EIF2AK2 entity (sysndd:4375) - Publication 33236446 update completes correctly (#122)
- [ ] **BUG-02**: GAP43 newly created entity is visible in entity list (#115)
- [ ] **BUG-03**: MEF2C entity (sysndd:4512) updates save correctly (#114)
- [ ] **BUG-04**: Viewer status users can view profile without auto-logout
- [ ] **BUG-05**: Adding new PMID during re-review preserves existing PMIDs
- [ ] **BUG-06**: Entities over time by gene displays correct counts (#44)
- [ ] **BUG-07**: Disease renaming requires approval per review concept (#41)
- [ ] **BUG-08**: Re-reviewer identity preserved when changing reviews

### Variant Correlations

- [ ] **VCOR-01**: VariantCorrelations view navigation links work correctly
- [ ] **VCOR-02**: VariantCounts view navigation links work correctly

### Publications

- [ ] **PUB-01**: Publications table has improved UX (pagination, search, filters)
- [ ] **PUB-02**: Publication metadata fetched from PubMed API (title, journal, abstract)
- [ ] **PUB-03**: PublicationsNDD TimePlot has improved visualization
- [ ] **PUB-04**: PublicationsNDD Stats view displays correctly

### Pubtator

- [ ] **PUBT-01**: PubtatorNDD Stats page displays correctly (fix broken)
- [ ] **PUBT-02**: Gene prioritization list ranks genes by publication count, recency, coverage gap
- [ ] **PUBT-03**: Novel gene alerts highlight Pubtator genes not in SysNDD entities
- [ ] **PUBT-04**: User can explore gene-literature connections for research
- [ ] **PUBT-05**: Curator can export prioritized gene list for offline planning
- [ ] **PUBT-06**: Pubtator concept and purpose documented in views

### LLM Cluster Summaries

- [ ] **LLM-01**: Gemini API client integrated using ellmer package
- [ ] **LLM-02**: API key stored securely in environment variable (GEMINI_API_KEY)
- [ ] **LLM-03**: Cluster summaries use structured JSON output schema
- [ ] **LLM-04**: Entity validation checks all gene names exist in database
- [ ] **LLM-05**: Batch pre-generation job runs via mirai async system
- [ ] **LLM-06**: Summaries cached in database with hash-based invalidation
- [ ] **LLM-07**: Phenotype cluster summaries generated and displayed
- [ ] **LLM-08**: Functional cluster summaries generated and displayed
- [ ] **LLM-09**: LLM-as-judge validates summary accuracy
- [ ] **LLM-10**: Confidence scoring flags low-confidence summaries
- [ ] **LLM-11**: Admin panel for summary review and approval
- [ ] **LLM-12**: Summaries show "AI-generated" badge with validation status

### Admin

- [ ] **ADMIN-01**: Admin comparisons functionality updated

### Infrastructure

- [ ] **INFRA-01**: GitHub Pages deployed via GitHub Actions workflow (not gh-pages branch)

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
| BUG-01 | TBD | Pending |
| BUG-02 | TBD | Pending |
| BUG-03 | TBD | Pending |
| BUG-04 | TBD | Pending |
| BUG-05 | TBD | Pending |
| BUG-06 | TBD | Pending |
| BUG-07 | TBD | Pending |
| BUG-08 | TBD | Pending |
| VCOR-01 | TBD | Pending |
| VCOR-02 | TBD | Pending |
| PUB-01 | TBD | Pending |
| PUB-02 | TBD | Pending |
| PUB-03 | TBD | Pending |
| PUB-04 | TBD | Pending |
| PUBT-01 | TBD | Pending |
| PUBT-02 | TBD | Pending |
| PUBT-03 | TBD | Pending |
| PUBT-04 | TBD | Pending |
| PUBT-05 | TBD | Pending |
| PUBT-06 | TBD | Pending |
| LLM-01 | TBD | Pending |
| LLM-02 | TBD | Pending |
| LLM-03 | TBD | Pending |
| LLM-04 | TBD | Pending |
| LLM-05 | TBD | Pending |
| LLM-06 | TBD | Pending |
| LLM-07 | TBD | Pending |
| LLM-08 | TBD | Pending |
| LLM-09 | TBD | Pending |
| LLM-10 | TBD | Pending |
| LLM-11 | TBD | Pending |
| LLM-12 | TBD | Pending |
| ADMIN-01 | TBD | Pending |
| INFRA-01 | TBD | Pending |

**Coverage:**
- v10.0 requirements: 34 total
- Mapped to phases: 0 (pending roadmap)
- Unmapped: 34 ⚠️

---
*Requirements defined: 2026-01-31*
*Last updated: 2026-01-31 after initial definition*

# Feature Landscape: LLM Cluster Summaries & Literature Research Tools

**Domain:** LLM-generated scientific summaries and literature research tools for neurodevelopmental disorders database
**Milestone:** v10.0 Data Quality & AI Insights
**Researched:** 2026-01-31
**Confidence:** MEDIUM-HIGH (based on recent research, existing codebase analysis, official API documentation)

---

## Executive Summary

This document categorizes features for the v10.0 milestone focused on:
1. **LLM Cluster Summaries** — Generate reproducible biological interpretations using Gemini API
2. **LLM-as-Judge Validation** — Guard against hallucinations in generated content
3. **Publications View Improvements** — Enhanced metadata fetching and UX
4. **Pubtator Curator Tools** — Gene prioritization and user research features

The existing SysNDD infrastructure includes:
- **Phenotype Clusters:** MCA + HCPC clustering with 5 clusters, Cytoscape.js visualization, enrichment tables (quali_inp_var, quali_sup_var, quanti_sup_var)
- **Functional Gene Clusters:** STRINGdb + Leiden clustering with 7 main clusters, network visualization, term enrichment (GO, KEGG, MONDO)
- **Publications:** Cursor-paginated table with PMID links, basic metadata
- **Pubtator:** Gene-literature associations with relevance scores

---

## Table Stakes

Features users expect for LLM-generated scientific summaries and literature research tools. Missing = product feels incomplete or unreliable.

### LLM Cluster Summaries

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Grounded generation from cluster data** | Summaries must reflect actual genes, GO terms, phenotypes in cluster | Medium | Existing cluster enrichment data | Use structured input: gene list, enrichment terms, phenotype annotations |
| **Structured output format** | Consistent, parseable summaries for display | Low | Gemini API (2.5+) | Define JSON Schema: summary_text, key_phenotypes[], enriched_pathways[], inheritance_pattern |
| **Reproducibility across regeneration** | Scientists expect same input = same output | Medium | Temperature=0, seed param, caching | Note: LLMs are NOT fully deterministic even at temp=0; cache generated summaries |
| **Cached/pre-generated summaries** | Avoid API latency on page load | Medium | mirai job system | Batch generate during off-peak; store in database |
| **Source attribution** | Users need to verify claims | Low | Prompt design | Include "Based on N genes with GO terms X, Y, Z" in output |
| **Human-readable prose** | Match manuscript example style | Low | Prompt design | Example: "Cluster 2 comprises 866 entities. It is enriched for moderate to severe intellectual disability..." |
| **Fallback for API failures** | Site must work if Gemini unavailable | Low | Error handling | Show "Summary unavailable" with enrichment table fallback |
| **API key security** | Credentials must not leak to frontend | Low | Backend-only calls | Gemini API called only from R/Plumber; never expose key |

**Reference:** [Gene Set Summarization Using LLMs (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC10246080/) - "Methods are able to generate plausible and biologically valid summary GO term lists for gene sets."

### LLM-as-Judge Validation

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Factual grounding check** | Detect claims not supported by input data | High | Second LLM call or prompt chain | Cross-reference output against input gene list, GO terms |
| **Hallucination flagging** | Mark low-confidence summaries for review | Medium | Validation logic | Flag if mentions genes/diseases not in cluster data |
| **Confidence scoring** | Curators need trust signal | Medium | Validation output | HIGH/MEDIUM/LOW based on grounding check results |
| **Human override capability** | Curators can correct/approve summaries | Low | Database schema | Store is_validated, validated_by, validation_date |

**Reference:** [Datadog: LLM-as-a-Judge](https://www.datadoghq.com/blog/ai/llm-hallucination-detection/) - "LLM as a Judge exhibits high precision (0.95) for flagging spurious text."

### Publications View

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Paginated publication table** | Users browse large datasets | Already exists | PublicationsNDDTable | Cursor pagination with 10/25/50/100 options |
| **PMID links to PubMed** | Standard citation navigation | Already exists | Current implementation | External link with icon |
| **Search/filter by title, journal, date** | Find specific papers | Already exists | Current filters | Column-level filtering |
| **Excel export** | Researchers need offline access | Already exists | Download button | Maintains filtered state |
| **Publication metadata display** | Title, journal, date, authors | Low-Medium | PubMed API (E-utilities) | Currently missing author/affiliation data |
| **Abstract display/expansion** | Read paper summary without leaving | Medium | PubMed API + UI component | Collapsible abstract per row |

**Reference:** [NCBI E-utilities API](https://www.ncbi.nlm.nih.gov/home/develop/api/) - "E-utilities are the public API to the NCBI Entrez system."

### Pubtator View

| Feature | Why Expected | Complexity | Depends On | Notes |
|---------|--------------|------------|------------|-------|
| **Gene-literature associations** | Core Pubtator value | Already exists | PubtatorNDDTable | Links genes to publications |
| **Publication metadata (PMID, DOI, title)** | Basic reference info | Already exists | Current implementation | With external links |
| **Search/filter capability** | Find relevant papers | Already exists | Column filters | Debounced search |
| **Relevance score display** | Prioritize high-quality matches | Already exists | score column | Pubtator's computed relevance |
| **Text highlight display** | Show why paper matched | Already exists | text_hl column | Truncated with tooltip |

---

## Differentiators

Features that set product apart. Not expected, but valued by power users and curators.

### LLM Cluster Summaries (Differentiators)

| Feature | Value Proposition | Complexity | Depends On | Notes |
|---------|-------------------|------------|------------|-------|
| **Dual-cluster summaries (phenotype + functional)** | Comprehensive interpretation | Medium | Both cluster types | Generate for MCA phenotype clusters AND STRING functional clusters |
| **Multi-language summary support** | International accessibility | Low | Gemini multilingual | Add language parameter; defer to v10.1+ |
| **Summary version history** | Track interpretation evolution | Medium | Database schema | Store summary_version, generated_at, model_version |
| **Comparison mode across clusters** | Identify distinguishing features | High | Frontend comparison UI | "Cluster 2 vs Cluster 5: differentiating phenotypes..."; defer to v11+ |
| **Curator annotation overlay** | Expert corrections visible | Medium | UI + database | Strikethrough LLM text, show curator edits |

### LLM-as-Judge (Differentiators)

| Feature | Value Proposition | Complexity | Depends On | Notes |
|---------|-------------------|------------|------------|-------|
| **Automated regeneration on failure** | Self-healing summaries | Medium | Job system | If validation fails, regenerate with stricter prompt |
| **Validation audit trail** | Transparency for researchers | Low | Logging | Log validation checks, scores, decisions |
| **Domain-specific fact checking** | Check against HPO, OMIM ontologies | High | Ontology integration | Verify phenotype terms exist in HPO; defer to v10.1+ |

### Publications (Differentiators)

| Feature | Value Proposition | Complexity | Depends On | Notes |
|---------|-------------------|------------|------------|-------|
| **Citation count display** | Identify influential papers | Medium | pmidcite or NIH iCite API | "Cited by" metadata from NCBI |
| **Author affiliation display** | Identify research groups | Medium | PubMed XML metadata | E-utilities with affiliation extraction |
| **Publication trends visualization** | Understand field evolution | Already partial | PublicationsNDDTimePlot | Enhance with annotations for key papers |
| **Related publications sidebar** | Discovery of similar work | High | Semantic search | Defer to v11+ |
| **Full-text availability indicator** | Know if PMC access exists | Low | PMC API lookup | Badge showing "Full text available" |

### Pubtator (Differentiators)

| Feature | Value Proposition | Complexity | Depends On | Notes |
|---------|-------------------|------------|------------|-------|
| **Gene prioritization lists for curators** | Focused curation workflow | Medium | Scoring algorithm | Rank genes by: # publications, recency, SysNDD coverage gap |
| **Novel gene discovery alerts** | Find genes not yet in SysNDD | Medium | Comparison logic | Highlight Pubtator genes missing from entity table |
| **Entity co-occurrence visualization** | See gene-disease-chemical relationships | High | Network visualization | Pubtator 3.0 provides 12 relation types; defer to v11+ |
| **Curation queue integration** | Direct add to re-review batch | Medium | Existing batch system | "Add gene to curation queue" button |
| **Export prioritized gene list** | Offline curation planning | Low | Excel export | Include prioritization scores, publication counts |
| **Concept type filtering** | Focus on genes vs chemicals vs diseases | Low | UI filter | Pubtator annotates 6 entity types |
| **Full-text annotation coverage** | More complete mining | Low | UI indicator | Note if abstract-only vs full-text annotated |

**Reference:** [Integrating PubTator into CTD Curation Workflow](https://academic.oup.com/database/article/doi/10.1093/database/baaf013/8029700) - "Auto-fill drop-down schemes accelerated task completion time by 49%."

---

## Anti-Features

Features to explicitly NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Real-time LLM summary generation** | API latency (2-5s) ruins UX; costs add up | Pre-generate summaries in batch jobs; cache aggressively |
| **Frontend Gemini API calls** | Exposes API key; enables abuse | All LLM calls through R/Plumber backend only |
| **Fully automated publication** | Hallucinated content damages scientific credibility | Always flag LLM content; require validation for critical claims |
| **Complex prompt chaining in UI** | Hard to debug; unpredictable latency | Simple one-shot prompts; complexity in backend job |
| **p-values or statistics from LLM** | LLMs cannot reliably compute statistics | Use existing enrichment analysis; LLM for natural language only |
| **LLM-generated gene lists** | LLM may hallucinate gene names | Only use genes from database; LLM describes, never invents |
| **Automatic ontology term extraction** | Mapping errors accumulate | Provide ontology terms as input; LLM summarizes existing annotations |
| **Custom LLM fine-tuning** | Expensive; hard to maintain; small dataset | Use foundation model with structured prompts and grounding |
| **Direct PubMed data scraping** | Violates NCBI terms; fragile | Use official E-utilities API with proper rate limiting |
| **Embedding-based semantic search** | Infrastructure complexity for marginal gain at current scale | Simple text search + Pubtator annotations sufficient for v10 |
| **Multiple LLM provider fallbacks** | Prompt compatibility issues; testing burden | Single provider (Gemini) with graceful degradation |
| **User-facing prompt editing** | Inconsistent outputs; security risks | Fixed, validated prompt templates only |

**Reference:** [arXiv: Gene Set Summarization](https://arxiv.org/abs/2305.13338) - "GPT-based approaches are unable to deliver reliable scores or p-values and often return terms that are not statistically significant."

---

## Feature Dependencies

```
EXISTING FEATURES (built in v5-v9):
  Phenotype Clusters (MCA + HCPC)
    -> quali_inp_var, quali_sup_var, quanti_sup_var tables
    -> Cytoscape.js visualization
    -> /api/analysis/phenotype_clustering endpoint

  Functional Gene Clusters (STRINGdb + Leiden)
    -> term_enrichment (GO, KEGG, MONDO)
    -> identifiers (symbol, STRING_id, hgnc_id)
    -> Network visualization
    -> /api/analysis/functional_clustering endpoint
    -> /api/analysis/network_edges endpoint

  Publications Table
    -> Cursor pagination
    -> Basic metadata (PMID, title, journal, date)
    -> /api/publication endpoint

  Pubtator Table
    -> Gene-publication associations
    -> Relevance scoring
    -> /api/publication/pubtator/table endpoint

  mirai Job System
    -> 8-worker daemon pool
    -> Job status polling
    -> Used for async clustering

NEW FEATURES (v10.0):
  LLM Cluster Summaries
    DEPENDS ON: Cluster enrichment data, phenotype annotations, Gemini API key
    BLOCKS: Summary display in cluster views

  LLM Batch Pre-generation
    DEPENDS ON: mirai job system, LLM summary endpoint
    BLOCKS: Cached summaries for page load

  LLM-as-Judge Validation
    DEPENDS ON: LLM summaries, cluster source data
    BLOCKS: Confidence badges, curator review workflow

  Publications Metadata Enhancement
    DEPENDS ON: E-utilities API integration
    BLOCKS: Abstract display, author affiliations

  Pubtator Stats Fix
    DEPENDS ON: Existing stats endpoint debugging
    BLOCKS: PubtatorNDDStats component

  Pubtator Curator Prioritization
    DEPENDS ON: Gene list comparison (Pubtator vs entities)
    BLOCKS: Curator queue integration
```

### Critical Path for v10.0

1. **Gemini API integration** (backend) -> LLM summary generation
2. **Summary caching schema** (database) -> Store generated summaries
3. **Batch pre-generation job** (mirai) -> Avoid real-time API calls
4. **Basic validation** (backend) -> Check gene grounding
5. **UI display** (frontend) -> Show summaries in cluster views

---

## MVP Recommendation

For v10.0 MVP, prioritize:

### Must Have (Table Stakes) - P0

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P0 | **Grounded LLM cluster summaries** | Medium | Core feature; use existing enrichment data as input |
| P0 | **Batch pre-generation** | Medium | Avoid real-time API calls; use mirai job system |
| P0 | **Basic hallucination detection** | Medium | Check if mentioned genes exist in cluster |
| P0 | **Cached summaries in database** | Low | Store generated text with metadata |
| P0 | **Pubtator stats fix** | Low | Address broken functionality |
| P0 | **Publications table UX polish** | Low | Improve existing table |

### Should Have (Key Differentiators) - P1

| Priority | Feature | Complexity | Impact |
|----------|---------|------------|--------|
| P1 | **Gene prioritization for curators** | Medium | High-value for curation workflow |
| P1 | **Novel gene discovery alerts** | Medium | Identifies gaps in SysNDD coverage |
| P1 | **LLM-as-judge validation with confidence scores** | Medium | Builds trust in generated content |
| P1 | **Export prioritized gene list** | Low | Enables offline curator planning |

### Defer to v10.1+

- Full publication metadata (abstracts, affiliations, citation counts)
- Entity co-occurrence visualization
- Multi-language summaries
- Cross-cluster comparison mode
- Domain-specific ontology fact-checking
- Summary version history with comparison

---

## Implementation Notes

### Gemini API Integration

**R Package Available:** The `gemini.R` package (v0.17.2, CRAN, September 2025) provides direct Gemini API access for R. Alternatively, use httr2 for REST API calls with more control.

**Structured Output:** Gemini 2.5+ supports JSON Schema for structured outputs. Define response schema:
```json
{
  "summary_text": "string (1-3 sentences)",
  "key_phenotypes": ["string (HPO term name)"],
  "enriched_pathways": ["string (GO/KEGG term)"],
  "inheritance_patterns": ["string (AD, AR, XL, etc.)"],
  "entity_count": "integer",
  "grounding_confidence": "HIGH|MEDIUM|LOW"
}
```

**API Configuration:**
```r
# Using gemini.R package
library(gemini.R)

# Set API key (environment variable)
Sys.setenv(GEMINI_API_KEY = config$gemini_api_key)

# Or using httr2 for more control
library(httr2)

response <- request("https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent") %>%
  req_headers("Content-Type" = "application/json") %>%
  req_url_query(key = config$gemini_api_key) %>%
  req_body_json(list(
    contents = list(list(parts = list(list(text = prompt)))),
    generationConfig = list(
      temperature = 0,
      responseMimeType = "application/json",
      responseSchema = schema
    )
  )) %>%
  req_perform()
```

**Reference:** [gemini.R CRAN](https://cran.r-project.org/package=gemini.R)

### Reproducibility Considerations

Even with temperature=0, LLMs are not fully deterministic due to:
- Dynamic batching on provider infrastructure
- Floating-point precision variations
- Model updates over time

**Reference:** [SGLang: Deterministic Inference](https://lmsys.org/blog/2025-09-22-sglang-deterministic/) - "Even with temperature=0, sampling is not deterministic due to dynamic batching and radix cache."

**Mitigation:** Cache generated summaries with:
- Input hash (cluster data fingerprint using digest::digest)
- Model version (gemini-2.5-flash)
- Generation timestamp
- Validation status

### Prompt Design Principles

For grounded scientific summaries:
1. **Structured input:** Provide data as JSON, not free text
2. **Explicit constraints:** "Only mention genes from the provided list"
3. **Output format:** Request specific structure matching manuscript style
4. **No computation:** "Do not calculate statistics; describe provided values"
5. **Attribution:** Include source references in output

**Example prompt template:**
```
You are a biomedical summarizer for a neurodevelopmental disorders database.

TASK: Generate a 1-3 sentence biological summary for the gene cluster below.

CONSTRAINTS:
- Only mention genes from the provided gene list
- Only describe enrichment terms that are provided
- Do not compute statistics or p-values
- Use formal scientific language
- Match this style: "Cluster 2 comprises 866 entities. It is enriched for moderate to severe intellectual disability, seizures, and behavioral abnormalities."

CLUSTER DATA:
{cluster_json}

OUTPUT FORMAT:
Return a JSON object with:
- summary_text: The biological summary (1-3 sentences)
- key_phenotypes: Array of top 3 phenotype terms mentioned
- enriched_pathways: Array of top 3 pathway/GO terms mentioned
- inheritance_patterns: Array of inheritance patterns if present
- entity_count: Number of entities in cluster
```

### LLM-as-Judge Pattern

**Two-pass approach:**
1. **Generation pass:** Create summary from cluster data
2. **Validation pass:** Prompt same/different model: "Does this summary only contain information supported by the input data? List any unsupported claims."

**Alternative: Single-pass with self-validation:**
Add to generation prompt: "After the summary, list any genes or phenotypes you mentioned that were NOT in the input data."

**Reference:** [Hallucination Detection in Scientific Text (CEUR-WS)](https://ceur-ws.org/Vol-4038/paper_356.pdf)

### Curator Prioritization Algorithm

For gene prioritization lists:
```
Priority Score =
  (Publication Count * 0.4) +
  (Recency Weight * 0.3) +
  (Coverage Gap * 0.3)

Where:
  Coverage Gap = 1 if gene not in SysNDD, 0 otherwise
  Recency Weight = exp(-age_in_years / 2)
```

**SQL Query Pattern:**
```sql
SELECT
  pac.normalized_id AS hgnc_id,
  pac.name AS symbol,
  COUNT(DISTINCT pac.search_id) AS publication_count,
  MAX(psc.date) AS most_recent_pub,
  CASE WHEN e.hgnc_id IS NULL THEN 1 ELSE 0 END AS is_novel
FROM pubtator_annotation_cache pac
JOIN pubtator_search_cache psc ON pac.search_id = psc.search_id
LEFT JOIN ndd_entity_view e ON pac.normalized_id = e.hgnc_id
WHERE pac.type = 'Gene'
GROUP BY pac.normalized_id, pac.name, e.hgnc_id
ORDER BY is_novel DESC, publication_count DESC, most_recent_pub DESC
```

**Reference:** [dgiLIT: Drug-Gene Interaction Prioritization](https://www.biorxiv.org/content/10.64898/2026.01.16.699733v1)

### Database Schema Additions

```sql
-- LLM cluster summaries cache
CREATE TABLE IF NOT EXISTS llm_cluster_summary_cache (
  summary_id INT AUTO_INCREMENT PRIMARY KEY,
  cluster_type ENUM('phenotype', 'functional') NOT NULL,
  cluster_id INT NOT NULL,
  input_hash VARCHAR(64) NOT NULL,  -- SHA-256 of input data
  model_version VARCHAR(50) NOT NULL,
  summary_text TEXT NOT NULL,
  key_phenotypes JSON,
  enriched_pathways JSON,
  inheritance_patterns JSON,
  entity_count INT,
  grounding_confidence ENUM('HIGH', 'MEDIUM', 'LOW'),
  validation_status ENUM('pending', 'validated', 'rejected') DEFAULT 'pending',
  validated_by INT,
  validation_date DATETIME,
  generated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_cluster_hash (cluster_type, cluster_id, input_hash),
  INDEX idx_cluster (cluster_type, cluster_id),
  FOREIGN KEY (validated_by) REFERENCES user(user_id) ON DELETE SET NULL
);
```

---

## Complexity Assessment

| Feature Category | Effort | Risk | Priority |
|-----------------|--------|------|----------|
| Gemini API integration | Medium | Medium (API reliability, rate limits) | P0 |
| LLM batch pre-generation | Medium | Low (uses existing job system) | P0 |
| Basic validation | Medium | Low | P0 |
| Summary caching/storage | Low | Low | P0 |
| Curator gene prioritization | Medium | Low | P1 |
| Publications metadata API | Medium | Medium (NCBI rate limits) | P2 |
| Full validation with ontology | High | Medium | v10.1 |
| Co-occurrence visualization | High | Low | v11+ |

---

## Confidence Assessment

| Area | Confidence | Rationale |
|------|------------|-----------|
| LLM Structured Output | HIGH | Official Gemini API docs, gemini.R package on CRAN |
| Hallucination Detection | MEDIUM-HIGH | Multiple peer-reviewed sources, Datadog engineering blog |
| Gene Set Summarization | HIGH | PMC peer-reviewed paper with TALISMAN method |
| LLM Reproducibility | HIGH | LMSYS SGLang blog, multiple engineering sources |
| Curator Prioritization | MEDIUM | Based on dgiLIT preprint and LitSuggest patterns |
| PubMed API | HIGH | Official NCBI documentation |
| Pubtator Integration | HIGH | 2025 CTD integration paper |

---

## Sources

### LLM Structured Output
- [Gemini API Structured Output Documentation](https://ai.google.dev/gemini-api/docs/structured-output)
- [Google Blog: Improving Structured Outputs in Gemini API](https://blog.google/technology/developers/gemini-api-structured-outputs/)
- [Instructor Python: Gemini Structured Outputs](https://python.useinstructor.com/integrations/google/)
- [gemini.R CRAN Package](https://cran.r-project.org/package=gemini.R)
- [gemini.R GitHub](https://github.com/jhk0530/gemini.R)

### Hallucination Detection
- [Datadog: Detecting hallucinations with LLM-as-a-Judge](https://www.datadoghq.com/blog/ai/llm-hallucination-detection/)
- [Nature: Detecting hallucinations using semantic entropy](https://www.nature.com/articles/s41586-024-07421-0)
- [Nature Digital Medicine: Clinical safety framework for LLM summarisation](https://www.nature.com/articles/s41746-025-01670-7)
- [Hallucination Detection and Mitigation in Scientific Text (CEUR-WS)](https://ceur-ws.org/Vol-4038/paper_356.pdf)
- [EdinburghNLP: Awesome Hallucination Detection](https://github.com/EdinburghNLP/awesome-hallucination-detection)

### Gene Set Summarization
- [PMC: Gene Set Summarization Using Large Language Models](https://pmc.ncbi.nlm.nih.gov/articles/PMC10246080/)
- [arXiv: Gene Set Summarization](https://arxiv.org/abs/2305.13338)
- [OntoGPT: LLM-based ontological extraction](https://github.com/monarch-initiative/ontogpt)

### Ontology-Grounded LLMs
- [OG-RAG: Ontology-Grounded Retrieval-Augmented Generation](https://arxiv.org/html/2412.15235v1)
- [MDPI: Large Language Models in Bio-Ontology Research](https://www.mdpi.com/2306-5354/12/11/1260)

### LLM Reproducibility
- [SGLang: Towards Deterministic Inference](https://lmsys.org/blog/2025-09-22-sglang-deterministic/)
- [Keywords AI: Consistent LLM outputs in 2025](https://www.keywordsai.co/blog/llm_consistency_2025)
- [Understanding LLM Non-Determinism](https://www.vincentschmalbach.com/does-temperature-0-guarantee-deterministic-llm-outputs/)

### Curator Prioritization
- [dgiLIT: Drug-Gene Interaction Prioritization (bioRxiv 2026)](https://www.biorxiv.org/content/10.64898/2026.01.16.699733v1)
- [LitSuggest: Literature recommendation and curation](https://academic.oup.com/nar/article/49/W1/W352/6266425)
- [Integrating PubTator into CTD curation workflow (2025)](https://academic.oup.com/database/article/doi/10.1093/database/baaf013/8029700)

### PubMed/PubTator APIs
- [NCBI E-utilities API](https://www.ncbi.nlm.nih.gov/home/develop/api/)
- [PubTator 3.0: AI-powered literature resource](https://academic.oup.com/nar/article/52/W1/W540/7640526)
- [pmidcite: Citation counts for PubMed](https://github.com/dvklopfenstein/pmidcite)

---

*Research completed: 2026-01-31*
*Confidence: MEDIUM-HIGH (LLM patterns verified via official docs and research papers)*
*Researcher: GSD Project Researcher (Features dimension - LLM & Literature v10.0)*

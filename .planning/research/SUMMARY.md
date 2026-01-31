# Project Research Summary

**Project:** SysNDD v10.0 Data Quality & AI Insights
**Domain:** LLM cluster summaries, Publications/Pubtator improvements, Bug fixes
**Researched:** 2026-01-31
**Confidence:** HIGH

## Executive Summary

SysNDD v10.0 adds LLM-generated cluster summaries using Gemini API, improves Publications and Pubtator views for research/curation, and fixes 8-9 major bugs. Research reveals:

1. **Use ellmer (not gemini.R)** for Gemini API integration — structured output, batch processing, LLM-as-judge support, maintained by Tidyverse team
2. **LLM hallucinations are the critical risk** — 2026 research shows even grounded LLMs produce plausible but incorrect gene names; entity validation against database is mandatory
3. **LLM-as-judge has only 64-68% agreement** with domain experts — use rule-based validators as primary, LLM-as-judge as supplementary
4. **easyPubMed deprecated functions** retiring in 2026 — must update to new epm_* API
5. **Existing infrastructure covers 80%** — mirai job system, httr2 patterns, and pubtator caching pattern need minimal adaptation

**Key stack decision:** Add `ellmer >= 0.4.0` to renv. Update easyPubMed deprecated calls. Store Gemini API key in environment variable (GEMINI_API_KEY).

## Key Findings

### Recommended Stack

| Component | Version | Action | Notes |
|-----------|---------|--------|-------|
| **ellmer** | >= 0.4.0 | **NEW** | Gemini API with structured output, batch processing |
| easyPubMed | >= 3.1.3 | UPDATE | Deprecated function calls retiring 2026 |
| httr2 | 1.2.1 | KEEP | External API patterns already established |
| mirai | 2.5.1 | KEEP | Async job system already working |
| cachem | 1.0.x | KEEP | Disk-based caching for LLM summaries |

**What NOT to add:**
- gemini.R — limited features, single maintainer
- langchain R bindings — overkill, Python-centric
- chromadb/vector store — no RAG requirement
- rentrez — easyPubMed already integrated

### Expected Features

**Table stakes (must have):**
- Grounded LLM summaries from cluster data (genes, GO terms, phenotypes)
- Structured JSON output with validation
- Batch pre-generation (avoid real-time API calls)
- Entity validation (check gene names exist in database)
- Cached summaries in database with hash-based invalidation
- Publications metadata from PubMed E-utilities
- Pubtator gene prioritization for curators

**Differentiators:**
- Full LLM-as-judge validation with confidence scoring
- Novel gene discovery alerts (genes in Pubtator not in SysNDD)
- Summary version history with model tracking
- Curator annotation overlay (expert corrections visible)

**Anti-features (do NOT build):**
- Real-time LLM generation on page load
- Frontend Gemini API calls (exposes key)
- LLM-generated statistics or p-values
- Custom LLM fine-tuning
- Multiple LLM provider fallbacks

### Architecture Approach

Five integration points, all following existing patterns:

1. **Gemini API client** (`llm-service.R`) — follows `external-proxy-*.R` pattern
2. **Summary storage** (`llm_cluster_summary_cache` table) — follows pubtator cache pattern
3. **Batch generation job** — follows HGNC update job pattern via mirai
4. **Summary display** — extends AnalyseGeneClusters.vue and AnalysesPhenotypeClusters.vue
5. **Admin validation panel** — follows ManageAnnotations.vue pattern

### Critical Pitfalls

1. **Hallucinated gene names** — LLMs invent plausible but non-existent genes; validate every gene symbol against `non_alt_loci_set`

2. **Schema ≠ content validation** — Gemini structured output validates JSON format, not semantic accuracy; build separate content validators

3. **LLM-as-judge unreliability** — 64-68% agreement with experts; use rule-based validators as primary, LLM as supplementary

4. **Cache staleness** — Summaries invalid when cluster composition changes; use SHA-256 hash of cluster genes as cache key

5. **Rate limits per-project** — All API keys in a GCP project share quota; batch jobs compete with user requests; implement client-side rate limiting

6. **Cost underestimation** — Cluster context can be 2000+ tokens; output tokens cost 2.5-10x more than input; use Batch API for 50% savings

## Implications for Roadmap

Based on research, suggested phase structure:

### Bug Fixes (Priority 1)
**Rationale:** Bugs first, then features (user priority)
**Delivers:** Fixes for 8-9 open GitHub issues
**Risk:** LOW (isolated fixes)

### LLM Foundation
**Rationale:** Required foundation for AI features
**Delivers:** ellmer integration, DB schema, entity validation pipeline
**Addresses:** Hallucination prevention, structured output, API key security
**Risk:** MEDIUM (new external dependency)

### LLM Batch Generation
**Rationale:** Avoid real-time API latency
**Delivers:** mirai job for summary generation, progress tracking, checkpointing
**Addresses:** Pre-generation, cost control, failure handling
**Risk:** LOW (follows existing job patterns)

### LLM Validation & Display
**Rationale:** Human-in-the-loop before public display
**Delivers:** Validation pipeline, admin UI, cluster view integration
**Addresses:** Quality control, confidence scoring
**Risk:** LOW (follows existing admin patterns)

### Publications Improvements
**Rationale:** Better metadata for researchers
**Delivers:** Updated easyPubMed calls, abstract display, author affiliations
**Risk:** LOW (API wrapper updates)

### Pubtator Overhaul
**Rationale:** Curator prioritization and user research
**Delivers:** Gene prioritization lists, novel gene alerts, concept documentation
**Risk:** LOW (extends existing Pubtator integration)

### GitHub Pages Deployment
**Rationale:** Modern CI/CD
**Delivers:** GitHub Actions workflow replacing gh-pages branch
**Risk:** LOW (well-documented pattern)

### Research Flags

Phases likely needing deeper research during planning:
- **LLM Validation:** May need iteration on validation prompts based on false positive rates

Phases with standard patterns (skip research-phase):
- **Bug fixes** — specific issues, no research needed
- **Publications** — easyPubMed migration well-documented
- **Pubtator** — extends existing integration
- **GitHub Pages** — GitHub Actions docs are comprehensive

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack (ellmer) | HIGH | Tidyverse maintained, CRAN verified |
| Hallucination risks | HIGH | Verified against 2026 Nature, IEEE, JAMA research |
| LLM-as-judge reliability | HIGH | ACM IUI 2025 research with 64-68% figures |
| Rate limits | HIGH | Official Gemini API documentation |
| Existing pattern reuse | HIGH | Based on codebase analysis |
| Cost estimation | MEDIUM | Pricing may change; verified Jan 2026 |

**Overall confidence:** HIGH

### Gaps to Address

- Gemini model retirement schedule (currently 2.0 Flash retiring March 2026)
- Exact token counts for cluster context (pilot needed)
- Cost per summary batch (pilot needed before full generation)

## Sources

### Primary (HIGH confidence)
- [ellmer 0.4.0 Tidyverse blog](https://tidyverse.org/blog/2025/11/ellmer-0-4-0/)
- [ellmer structured data vignette](https://ellmer.tidyverse.org/articles/structured-data.html)
- [easyPubMed CRAN PDF](https://cran.r-project.org/web/packages/easyPubMed/easyPubMed.pdf) — 2026 retirement
- [Gemini API Rate Limits](https://ai.google.dev/gemini-api/docs/rate-limits)
- [Nature Scientific Reports: Biomedical LLM Hallucinations](https://www.nature.com/articles/s41598-026-35492-8)
- [ACM IUI 2025: LLM-as-a-Judge Limitations](https://dl.acm.org/doi/10.1145/3708359.3712091)

### Secondary (MEDIUM confidence)
- [IEEE JBHI: Healthcare LLM Hallucinations](https://www.embs.org/jbhi/)
- [Gemini API Pricing 2026](https://www.metacto.com/blogs/the-true-cost-of-google-gemini)
- [PubTator 3.0 NAR paper](https://academic.oup.com/nar/article/52/W1/W540/7640526)

### Codebase Analysis (HIGH confidence)
- `api/functions/external-proxy-*.R` — httr2 patterns
- `api/functions/job-manager.R` — mirai async patterns
- `api/functions/pubtator-functions.R` — caching patterns
- `app/src/views/admin/ManageAnnotations.vue` — admin job UI pattern

---

**Research completed:** 2026-01-31
**Ready for roadmap:** Yes

# Phase 58: LLM Foundation - Context

**Gathered:** 2026-01-31
**Status:** Ready for planning

<domain>
## Phase Boundary

Integrate Gemini API for generating cluster summaries with structured output and entity validation. This phase delivers:
- Gemini API client using ellmer package
- Secure API key management (GEMINI_API_KEY)
- Structured JSON output schema for summaries
- Entity validation to ensure gene names exist in database

**Not in scope:** Batch generation (Phase 59), display components (Phase 60), validation workflows (Phase 61).

</domain>

<decisions>
## Implementation Decisions

### Prompt Design
- **Context source**: Enrichment data (category, description, FDR) — gives LLM context about why genes cluster together
- **Target audience**: Dual audience — clinical researchers + database curators
- **Context amount**: Top 20 enriched terms per category, configurable via parameter
- **Prompt template**: Unified template for both functional and phenotype clusters with type-specific placeholders

### Output Schema
- **Structure**: `summary` (prose) + `key_themes` (array) + `pathways` (array) + `confidence` (enum)
- **Summary length**: 2-3 sentences (~100 words)
- **Key themes count**: 3-5 themes
- **Confidence**: Both LLM self-reported (high/medium/low) AND derived from FDR values
- **Additional for phenotype clusters**: `syndrome_hints` and `curation_notes` fields

### Model Configuration
- **Primary model**: `gemini-3-pro-preview` (default) — best clinical context and quality
- **Alternative**: `gemini-2.0-flash` — faster, cheaper for batch jobs
- **Configuration**: Model configurable via parameter, default to 3.0 Pro
- **Package**: ellmer >= 0.4.0 with `chat_google_gemini()`

### Validation Strategy
- **Gene validation**: Strict — reject entire summary if any invalid gene symbols detected
- **Pathway validation**: Validate against input enrichment terms — pathways must appear in provided data
- **Retry policy**: 3 retries before marking cluster as failed
- **Logging**: Full details + store failed attempts for analysis and prompt improvement

### Error Handling
- **Rate limits**: Exponential backoff with jitter (1s, 2s, 4s...)
- **JSON parsing**: Guaranteed valid via Gemini's `responseSchema` — focus on semantic validation
- **Connectivity failures**: Exponential backoff, max 3 retries, then skip + log
- **Semantic failures**: Retry with same prompt up to 3 times

### Claude's Discretion
- Exact prompt wording and template structure
- Retry temperature variation strategy
- Logging format and storage mechanism
- Specific validation error messages

</decisions>

<specifics>
## Specific Ideas

### API Connection (Verified)
- API key stored in `.env` as `GEMINI_API_KEY=AIza...`
- Direct REST API tested and working
- Structured output with `responseSchema` produces valid JSON every time
- Billing enabled for production-level rate limits

### Tested Output Quality
Sample output from Cluster 3 (Metabolic/Mitochondrial) using gemini-3-pro-preview:
```json
{
  "summary": "This cluster encompasses genes distinctively characterized by their roles in mitochondrial bioenergetics, mitochondrial translation, and broader metabolic homeostasis. The strong enrichment for abnormal muscle physiology and muscle tone, alongside neurodevelopmental delay, aligns with the clinical presentation of mitochondrial encephalomyopathies.",
  "key_themes": ["Mitochondrial Bioenergetics", "Neuromuscular Physiology", "Metabolic Homeostasis", "Mitochondrial Translation"],
  "pathways": ["Oxidative phosphorylation", "Urea cycle", "Mitochondrial ribosome assembly"],
  "clinical_relevance": "High priority for patients presenting with syndromic NDDs featuring comorbid hypotonia or myopathy.",
  "confidence": "high"
}
```

### Reference Implementation
- Use `chat_google_gemini()` from ellmer with `GEMINI_API_KEY` env var
- Follow existing external-proxy pattern in codebase
- Schema design follows Gemini best practices (propertyOrdering, clear descriptions)

### Research References
- TALISMAN paper: Gene set summarization approach, GO descriptions outperform narrative
- Gemini docs: Use `responseSchema` for guaranteed JSON structure
- ellmer 0.4.0: Native GEMINI_API_KEY support, structured output via type specifications

</specifics>

<deferred>
## Deferred Ideas

- **Prompt benchmarking** — Systematic ablation study of term counts per category (defer to implementation)
- **Temperature tuning** — Test different temperature values for retry diversity (defer to implementation)
- **Model comparison dashboard** — UI to compare Flash vs Pro outputs (out of scope)

</deferred>

---

*Phase: 58-llm-foundation*
*Context gathered: 2026-01-31*

# Phase 60: LLM Display - Context

**Gathered:** 2026-02-01
**Status:** Ready for planning

<domain>
## Phase Boundary

Display cached LLM-generated cluster summaries (from Phase 59) on phenotype and functional cluster analysis pages. Show clear AI provenance with confidence indicators. No on-demand generation — summaries come from the batch pipeline.

</domain>

<decisions>
## Implementation Decisions

### Summary presentation
- Position: Above cluster content as overview (sets context before viewing genes/details)
- Container: Card with distinct background, visually separated from other cluster content
- Content: Summary text + gene highlights + pathway mentions (rich display with extracted entities as chips/tags)
- Interactivity: Genes/pathways displayed as styled chips but NOT clickable links

### AI provenance badge
- Prominence: Subtle inline badge near summary, doesn't dominate the view
- Metadata shown: Model name + generation date (e.g. "Gemini 2.0 Flash · Jan 31, 2026")
- Tooltip: On hover shows additional context (prompt version, detailed confidence)
- Icon: Sparkles/stars icon (✨) for AI indicator

### Confidence visualization
- Display format: Descriptive label (High/Medium/Low) — not numeric percentage
- Visual: Color-coded badge with label (green/yellow/red with text)
- Low confidence handling: Show summary with warning styling (don't hide)
- Explanation: Tooltip explains factors influencing confidence (FDR values, gene count, etc.)

### Empty/pending states
- No summary: Hide summary section entirely (don't show placeholder)
- In progress: Show loading indicator (skeleton or spinner)
- Generation trigger: None — batch only from clustering pipeline
- Error states: Treat same as "no summary" (hide section, don't expose errors)

### Claude's Discretion
- Exact color palette for confidence levels
- Loading skeleton design
- Chip styling for genes/pathways
- Card shadow/border styling
- Tooltip positioning and timing

</decisions>

<specifics>
## Specific Ideas

- Confidence tooltip should mention the objective factors: "Based on FDR values and term count" (derived_confidence from Phase 58)
- AI badge should feel subtle, not alarmist — the point is transparency, not warning users away
- Card should look like it belongs with the cluster content, not a foreign overlay

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 60-llm-display*
*Context gathered: 2026-02-01*

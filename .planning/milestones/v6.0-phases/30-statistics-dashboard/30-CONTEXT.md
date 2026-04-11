# Phase 30: Statistics Dashboard - Context

**Gathered:** 2026-01-25
**Status:** Ready for planning

<domain>
## Phase Boundary

Add Chart.js visualizations to AdminStatistics with scientific context — displaying entity submission trends over time and contributor leaderboard. Uses vue-chartjs with responsive Bootstrap card layout. Each chart includes contextual metrics (totals, trends, comparisons).

</domain>

<decisions>
## Implementation Decisions

### Chart Appearance
- Scientific palette — muted blues/grays suited for data visualization, colorblind-friendly
- Minimal tooltips — just the value (e.g., "42 entities")
- Light mode only — no dark mode support needed
- Smooth curves (Bezier) for line charts — softer look for trend visualization

### Data Granularity
- User toggle for aggregation — admin can switch between monthly/weekly/daily views
- Full date picker — custom start/end dates for chart range selection
- Leaderboard has both views — toggle between all-time and current-range scope
- 3-month moving average overlay — smoothed trend line displayed on raw data

### Dashboard Layout
- Responsive stack — charts stack vertically on small screens
- Spinner overlay — centered spinner over each chart area while loading
- "Data as of" timestamp with refresh button — manual refresh option available

### Context Indicators
- Arrow + percentage for trends — ↑ 12% vs last period (colored green/red)
- Leaderboard names link to user profile — click to see full contributor activity
- Comparison period configurable — research best practices during implementation

### Claude's Discretion
- Chart arrangement (research common dashboard standards — side-by-side vs stacked)
- Summary stat cards above charts (research best practices, simplicity first approach)
- Exact color hex values within scientific palette
- Moving average algorithm details
- Date picker component choice

</decisions>

<specifics>
## Specific Ideas

- "Research common standards" for layout decisions — user wants evidence-based UI choices
- "Simplicity first" — avoid over-engineering the dashboard
- Scientific app context — this is a disease genetics database, not a marketing dashboard

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 30-statistics-dashboard*
*Context gathered: 2026-01-25*

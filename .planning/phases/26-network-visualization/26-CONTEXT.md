# Phase 26: Network Visualization - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver true protein-protein interaction network visualization using Cytoscape.js with force-directed layout, interactive controls, and proper Vue 3 lifecycle management. This replaces the existing D3.js bubble charts with actual network graphs showing PPI edges.

</domain>

<decisions>
## Implementation Decisions

### Visual presentation
- Node sizing by degree (connection count) — more connected genes appear larger, shows network hubs
- Cluster membership indicated by color + convex hull — colored nodes plus subtle boundary around each cluster
- Categorical color palette for clusters — distinct colors (like D3 category10) for easy differentiation
- Edges weighted by STRING confidence — thicker lines for higher confidence scores

### Interaction behavior
- Hover shows highlight + tooltip — dim other nodes, show tooltip with gene info and connections
- Edge hover shows confidence + source — tooltip with STRING score and evidence types
- Navigation via mouse + keyboard shortcuts — arrow keys to pan, +/- to zoom, shortcuts for actions

### Layout & positioning
- Animated initial layout — nodes settle into position over ~1-2 seconds
- Clusters force-separated naturally — clusters emerge from force layout, may overlap slightly
- Users can drag to reposition nodes — layout adjusts around manually moved nodes
- Data changes trigger full layout re-run — fresh layout calculation when filters applied

### Network controls UI
- Standard control set — zoom in/out, fit to screen, reset layout, fullscreen, center on selection, toggle labels
- Smart label visibility — show gene name labels when zoomed in or few nodes, hide when dense
- Export as PNG + SVG — both raster and vector formats for publications

### Claude's Discretion
- Exact tooltip content and styling
- Keyboard shortcut assignments
- Animation timing and easing curves
- Convex hull styling (opacity, border weight)
- Edge curve style (straight vs bezier)
- Zoom level thresholds for label visibility

### Research Required
- **Click action on nodes:** Research best practices for what happens when clicking a node (navigate immediately vs select vs side panel)
- **Controls placement:** Research best practices for control button placement that fits SysNDD's existing UI/UX design

</decisions>

<specifics>
## Specific Ideas

- Force-directed layout with natural cluster separation (not compound nodes or grid regions)
- Edge thickness as a visual indicator of interaction confidence is important for biologists assessing evidence quality
- Labels should be smart — visible when useful, hidden when they would clutter
- Export capability matters for publications — both PNG (quick sharing) and SVG (vector for papers)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 26-network-visualization*
*Context gathered: 2026-01-24*

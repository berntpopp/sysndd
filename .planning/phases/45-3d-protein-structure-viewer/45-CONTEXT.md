# Phase 45: 3D Protein Structure Viewer - Context

**Gathered:** 2026-01-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Render AlphaFold 3D protein structures with pLDDT confidence coloring, representation toggles (cartoon/surface/ball+stick), and ClinVar variant highlighting using NGL Viewer. The viewer lives inside a tabbed visualization card shared with the protein domain lollipop plot (Phase 43) and gene structure visualization (Phase 44). WebGL cleanup on unmount prevents memory leaks.

</domain>

<decisions>
## Implementation Decisions

### Viewer layout & controls
- **Tabbed visualization card** — Single full-width card with tabs: "Protein Domains" (lollipop, Phase 43), "Gene Structure" (exons, Phase 44), "3D Structure" (NGL viewer, this phase). One visualization visible at a time, like ProteinPaint's Switch Display pattern.
- **Fixed height ~500px** across all tabs. No layout shift when switching between tabs.
- **Placement:** Below gene info card, above entities table. Gene card → Visualization card → Entities table.
- **NGL chrome:** Minimal viewer — hide all NGL built-in panels. Show sequence bar at top of viewer for amino acid position reference. Custom controls outside the viewer for representation toggle, reset, variant highlight.

### Variant highlighting UX
- **Variant panel list** as right sidebar inside the card (~30% width). 3D viewer takes ~70% width. Scrollable variant list always visible when on the 3D tab. Pattern matches StruNHEJ coordinated layout.
- **Multi-select with checkboxes** — Users can highlight multiple variants simultaneously on the 3D structure. Useful for seeing spatial clustering of pathogenic variants.
- **ACMG-colored spheres** — Highlighted residues rendered as enlarged spheres at amino acid positions, colored by pathogenicity (red=pathogenic, orange=likely pathogenic, yellow=VUS, light green=likely benign, green=benign). Consistent with lollipop plot ACMG colors from Phase 43.

### Representation defaults
- **Default representation:** Cartoon (ribbon) — most familiar to structural biologists, shows secondary structure clearly. Matches AlphaFold DB default.
- **Default coloring:** pLDDT confidence — AlphaFold's standard: blue (>90 very high), cyan (70-90 confident), yellow (50-70 low), orange (<50 very low). Immediately shows prediction reliability.
- **Toggle buttons:** Icon buttons in a toolbar row above or below the viewer. Compact icons for cartoon, surface, ball+stick. Tooltip on hover. Reset view button included.
- **pLDDT color legend:** Always visible — small horizontal legend showing the 4 pLDDT confidence ranges with colors.

### Fallback & loading states
- **Lazy-load on tab click** — NGL chunk (~777KB built) loads only when user clicks the "3D Structure" tab. Other tabs (lollipop, gene structure) load instantly. First click shows brief spinner.
- **Loading state:** Centered spinner with "Loading 3D structure..." text (same pattern as hnf1b-db and SysNDD gene page loading). Consistent with existing patterns.
- **Empty state (no AlphaFold structure):** Tab remains clickable. Content area shows "No AlphaFold structure available for [gene symbol]" with a muted icon and optional link to AlphaFold search. Tab is NOT disabled/grayed out.

### 3D viewer library
- **NGL Viewer (v2.4.0)** instead of Mol* — Reuse proven pattern from hnf1b-db project. 777KB built chunk (vs Mol* ~16MB npm tarball). Lazy-loaded via Vite code splitting. Vue 3 integration pattern: non-reactive `let stage` variables outside component + `markRaw()` for NGL objects. `stage.dispose()` in `onBeforeUnmount()` for WebGL cleanup.

### Claude's Discretion
- Exact NGL Stage configuration options (quality, impostor, worker settings)
- Toolbar icon selection and spacing within the card
- Sequence bar integration approach (NGL built-in vs custom)
- Exact responsive behavior of the 70/30 viewer-sidebar split on smaller screens
- AlphaFold structure file format choice (CIF vs PDB)

</decisions>

<specifics>
## Specific Ideas

- Tabbed visualization card pattern inspired by [ProteinPaint (GDC)](https://docs.gdc.cancer.gov/Data_Portal/Users_Guide/proteinpaint_lollipop/) "Switch Display" — toggle between Protein track, Genomic display, Exon only
- Variant sidebar layout inspired by [StruNHEJ](https://bmcgenomics.biomedcentral.com/articles/10.1186/s12864-016-3028-0) coordinated multi-panel: lollipop + 3D viewer + variant list
- hnf1b-db `ProteinStructure3D.vue` as reference implementation: NGL Stage init, `markRaw()` pattern, domain coloring, variant spacefill highlighting, `stage.dispose()` cleanup
- pLDDT confidence coloring matches AlphaFold DB convention — researchers will recognize the blue-cyan-yellow-orange scheme

</specifics>

<deferred>
## Deferred Ideas

- Cross-tab variant linking (clicking variant in lollipop tab → auto-highlights in 3D tab) — consider as enhancement after initial implementation
- Fullscreen/expand button for the tabbed card — could add in polish phase
- Mol* migration — if NGL becomes unmaintained or feature-limited, Mol* is the successor. Track NGL health.

</deferred>

---

*Phase: 45-3d-protein-structure-viewer*
*Context gathered: 2026-01-28*

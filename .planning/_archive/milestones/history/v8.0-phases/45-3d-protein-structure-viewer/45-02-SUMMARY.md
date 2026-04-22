---
phase: 45
plan: 02
subsystem: frontend-visualization
status: complete
completed: 2026-01-29
duration: 2m 5s

tags:
  - ngl-viewer
  - vue-components
  - 3d-structure
  - alphafold
  - variant-highlighting
  - acmg-colors
  - accessibility

requires:
  - "45-01: use3DStructure composable with NGL Stage lifecycle"
  - "40-05: Backend AlphaFold proxy endpoint"
  - "43-XX: Shared ACMG_COLORS constants (alphafold.ts)"

provides:
  - "ProteinStructure3D.vue: 3D viewer component with NGL integration"
  - "VariantPanel.vue: Multi-select ClinVar variant highlighting sidebar"
  - "70/30 viewer-sidebar layout pattern"
  - "Loading/error/empty state patterns for 3D viewer"
  - "Variant filtering: Only missense/inframe variants mappable to structure"

affects:
  - "45-03: Tabbed visualization card integration"
  - "Future phases: 3D viewer state patterns (loading/error/empty)"
  - "Future phases: Multi-select checkbox pattern for highlighting"

tech-stack:
  added: []
  patterns:
    - "70/30 viewer-sidebar split layout for coordinated visualization"
    - "v-show (not v-if) for NGL DOM preservation"
    - "Multi-select Set with reactivity workaround (new Set())"
    - "parseResidueNumber() filtering for structure-mappable variants"
    - "Shared ACMG_COLORS constants across all pathogenicity displays"

key-files:
  created:
    - "app/src/components/gene/ProteinStructure3D.vue: NGL viewer with toolbar, legend, states"
    - "app/src/components/gene/VariantPanel.vue: Multi-select variant highlighting sidebar"
  modified: []

decisions:
  - id: STRUCT3D-70-30-LAYOUT
    decision: "70% viewer + 30% variant panel side-by-side layout"
    rationale: "Matches StruNHEJ coordinated visualization pattern. Provides persistent variant list while maximizing 3D viewer space. Panel always visible (no toggle) for easier variant selection."
    alternatives: ["50/50 split (too cramped for viewer)", "Tab-based separation (loses coordination)"]
    impact: "Component architecture"

  - id: STRUCT3D-V-SHOW
    decision: "Use v-show (not v-if) for viewer-layout visibility"
    rationale: "NGL Stage requires persistent DOM element after initialization. v-if destroys/recreates DOM, breaking Stage reference. v-show hides via CSS but keeps DOM alive."
    alternatives: ["v-if (would break NGL Stage)", "Separate component (over-engineering)"]
    impact: "Critical for NGL integration"

  - id: STRUCT3D-MULTISELECT
    decision: "Multi-select checkboxes (not single-select radio buttons)"
    rationale: "Users need to highlight multiple variants simultaneously to see spatial clustering. Single-select would limit analysis capability. Matches CONTEXT.md decision."
    alternatives: ["Radio buttons (too limiting)", "Click-to-toggle (less obvious state)"]
    impact: "User experience"

  - id: STRUCT3D-FILTER-VARIANTS
    decision: "Only show missense/inframe variants in VariantPanel"
    rationale: "Frameshift, stop, and splice variants cannot be meaningfully mapped to 3D structure (no single residue position). parseResidueNumber() returns null for these, preventing confusion."
    alternatives: ["Show all variants grayed out (clutters list)", "Show all and error on select (bad UX)"]
    impact: "Variant list content"

patterns-established:
  - "Pattern 1: Variant filtering via parseResidueNumber() for structure-mappable types only (missense/inframe)"
  - "Pattern 2: Multi-select Set reactivity workaround (reassign new Set() to trigger Vue updates)"
  - "Pattern 3: 70/30 viewer-sidebar layout for coordinated visualizations"
  - "Pattern 4: v-show for WebGL component visibility (preserves DOM for Stage reference)"
---

# Phase 45 Plan 02: ProteinStructure3D and VariantPanel Components Summary

**NGL 3D viewer with representation toolbar, pLDDT legend, and multi-select ClinVar variant highlighting sidebar — 70/30 layout ready for tabbed visualization card integration**

## Performance

- **Duration:** 2m 5s (125 seconds)
- **Started:** 2026-01-29T00:42:21Z
- **Completed:** 2026-01-29T00:44:26Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- **ProteinStructure3D viewer component** with NGL integration, representation toggles (cartoon/surface/ball+stick), pLDDT legend, and loading/error/empty states
- **VariantPanel sidebar component** with multi-select checkboxes for ClinVar variant highlighting, filtered to structure-mappable variants only
- **70/30 viewer-sidebar layout** maximizing 3D viewer space while keeping variant list always visible
- **Accessibility compliance** with aria-label on all controls, keyboard navigation, and semantic HTML

## Task Commits

Each task was committed atomically:

1. **Task 1: Create ProteinStructure3D component** - `26b1dcf9` (feat)
2. **Task 2: Create VariantPanel component** - `5e6e66a4` (feat)

## Files Created

### ProteinStructure3D.vue (270 lines)

**Purpose:** 3D protein structure viewer with NGL integration, wraps use3DStructure composable into Vue component with viewer chrome (toolbar, legend, states).

**Key Features:**
- **Viewer states:** Loading (spinner + text), error (warning + retry), empty (no structure icon + message)
- **Toolbar:** Representation toggles (cartoon/surface/ball+stick) with active state highlighting, reset view button
- **pLDDT legend:** AlphaFold confidence colors (4 ranges: Very High, Confident, Low, Very Low)
- **70/30 layout:** 70% viewer (left) + 30% variant panel (right)
- **v-show (not v-if):** Preserves NGL DOM after initialization (critical for Stage reference)
- **Fixed 500px height:** Matches gene visualization card container height
- **Accessibility:** aria-label on all controls, aria-pressed on toggle buttons, tabindex="0" on viewport for keyboard focus

**Props:**
- `geneSymbol: string` - Gene symbol for empty state message
- `structureUrl: string | null` - AlphaFold PDB/CIF URL (null triggers empty state)
- `variants: ClinVarVariant[]` - ClinVar variants for VariantPanel

**Integration:**
- Uses `use3DStructure(viewerContainer)` composable for NGL Stage lifecycle
- Wires variant toggle events to `addVariantMarker()` / `removeVariantMarker()`
- Wires representation buttons to `setRepresentation(type)`
- Wires reset button to `resetView()` (autoView)
- Syncs composable error to local `viewerError` state

### VariantPanel.vue (200 lines)

**Purpose:** ClinVar variant selection sidebar with multi-select checkboxes for spatial highlighting on 3D structure.

**Key Features:**
- **Variant filtering:** Only shows variants with parseable HGVSP positions (missense/inframe)
- **parseResidueNumber():** Returns null for frameshift/stop/splice → excluded from list
- **Sorted by residue number:** Variants ordered by protein sequence position (ascending)
- **Multi-select checkboxes:** Multiple variants can be highlighted simultaneously
- **ACMG-colored dots:** 10px circles colored by pathogenicity (matches shared ACMG_COLORS)
- **Clear all button:** Removes all highlighted markers (visible when selections exist)
- **Scrollable list:** Handles genes with many variants (flex: 1, overflow-y: auto)
- **No variants state:** Shows "No ClinVar variants available" or "No variants with protein positions"

**Props:**
- `variants: ClinVarVariant[]` - ClinVar variants from gene data

**Emits:**
- `toggle-variant: [{ variant, selected }]` - When checkbox state changes
- `clear-all: []` - When clear all button clicked

**Implementation Notes:**
- **Set reactivity workaround:** `selectedResidues.value = new Set(...)` reassignment triggers Vue updates (Set.add/delete are not reactive)
- **mappableVariants computed:** Filters and sorts variants, pre-computes ACMG colors and labels
- **Monospace font:** HGVSP notation displayed in Courier New for readability

## Technical Implementation

### Viewer States (ProteinStructure3D)

**Loading State:**
```vue
<div v-if="isLoading" class="state-overlay">
  <BSpinner label="Loading 3D structure..." />
  <p class="text-muted mt-2 small">Loading 3D structure...</p>
</div>
```

**Error State:**
```vue
<div v-else-if="viewerError" class="state-overlay" role="alert">
  <i class="bi bi-exclamation-triangle text-warning fs-3"></i>
  <p class="text-muted mt-2 small">{{ viewerError }}</p>
  <BButton @click="retryLoad">Retry</BButton>
</div>
```

**Empty State:**
```vue
<div v-else-if="!structureUrl" class="state-overlay">
  <i class="bi bi-box text-muted fs-3"></i>
  <p class="text-muted mt-2 small">
    No AlphaFold structure available for {{ geneSymbol }}
  </p>
</div>
```

### Representation Toggle (ProteinStructure3D)

**Toolbar:**
```vue
<BButtonGroup size="sm">
  <BButton
    v-for="repr in representationOptions"
    :variant="activeRepresentation === repr.value ? 'primary' : 'outline-secondary'"
    :aria-pressed="activeRepresentation === repr.value"
    @click="handleSetRepresentation(repr.value)"
  >
    {{ repr.label }}
  </BButton>
</BButtonGroup>
```

**Handler:**
```typescript
function handleSetRepresentation(type: RepresentationType): void {
  setRepresentation(type); // Composable setVisibility() toggle (instant)
}
```

### Variant Highlighting (VariantPanel → ProteinStructure3D)

**VariantPanel emit:**
```typescript
emit('toggle-variant', { variant: item.variant, selected: newSelected });
```

**ProteinStructure3D handler:**
```typescript
function handleToggleVariant(payload: { variant, selected }): void {
  const residue = parseResidueNumber(payload.variant.hgvsp);
  if (residue === null) return; // Skip non-mappable variants

  if (payload.selected) {
    const classification = classifyClinicalSignificance(payload.variant.clinical_significance);
    const color = classification ? ACMG_COLORS[classification] : '#999999';
    addVariantMarker(residue, color, payload.variant.hgvsp);
  } else {
    removeVariantMarker(residue);
  }
}
```

### Variant Filtering (VariantPanel)

**mappableVariants computed:**
```typescript
const mappableVariants = computed<MappableVariant[]>(() => {
  const items: MappableVariant[] = [];

  for (const variant of props.variants) {
    const residue = parseResidueNumber(variant.hgvsp);
    if (residue === null) continue; // Skip frameshift/stop/splice

    const classification = classifyClinicalSignificance(variant.clinical_significance);
    items.push({
      variant,
      residue,
      classification,
      color: classification ? ACMG_COLORS[classification] : '#999999',
      label: classification ? ACMG_LABELS[classification] : variant.clinical_significance,
    });
  }

  items.sort((a, b) => a.residue - b.residue); // Protein sequence order
  return items;
});
```

**parseResidueNumber filtering (alphafold.ts):**
```typescript
export function parseResidueNumber(hgvsp: string | null): number | null {
  // First check if this variant type is mappable to 3D structure
  if (!isStructureMappableVariant(hgvsp)) return null;

  const match = hgvsp!.match(/p\.\w{3}(\d+)/);
  return match ? parseInt(match[1], 10) : null;
}
```

### 70/30 Layout (ProteinStructure3D)

**CSS Flexbox:**
```css
.viewer-layout {
  display: flex;
  height: 100%;
  gap: 0;
}

.viewer-section {
  flex: 7;  /* 70% width */
  display: flex;
  flex-direction: column;
}

.variant-section {
  flex: 3;  /* 30% width */
  border-left: 1px solid #dee2e6;
  overflow-y: auto;
}
```

## Accessibility Features

**ProteinStructure3D:**
- `role="region"` on container with `aria-label="3D protein structure viewer"`
- `role="toolbar"` on controls with `aria-label="3D viewer controls"`
- `aria-label` on all buttons (representation toggles, reset view)
- `aria-pressed` on representation toggle buttons (active state)
- `tabindex="0"` on NGL viewport for keyboard focus
- `role="alert"` on error state for screen reader announcement
- `:focus-visible` styling on viewport (2px blue outline)

**VariantPanel:**
- `role="region"` on container with `aria-label="ClinVar variant selection panel"`
- `role="list"` on variant list with `aria-label="ClinVar variants with protein positions"`
- `role="listitem"` on each variant label
- `aria-label` on each checkbox (e.g., "Highlight p.Arg123Trp on 3D structure")
- `aria-label` on clear all button
- `aria-hidden="true"` on ACMG color dots (decorative)

## Decisions Made

### 1. 70/30 Viewer-Sidebar Layout

**Decision:** 70% viewer + 30% variant panel side-by-side layout (not tab-based or collapsible)

**Rationale:**
- **Coordination:** Variant list always visible while viewing structure (matches StruNHEJ pattern)
- **Space optimization:** 70% sufficient for 3D viewer clarity, 30% enough for scrollable list
- **Simplicity:** No toggle button needed, users can see variants and structure simultaneously

**Alternatives rejected:**
- 50/50 split: Too cramped for 3D viewer on smaller screens
- Tab-based separation: Loses coordination (can't see list while viewing structure)
- Collapsible panel: Adds UI complexity, hides list by default

**Impact:** Component architecture, user workflow

### 2. v-show (not v-if) for Viewer Layout

**Decision:** Use `v-show="isInitialized && !isLoading && structureUrl"` (not v-if)

**Rationale:**
- **NGL Stage requirement:** Stage must reference persistent DOM element after initialization
- **v-if problem:** Destroys and recreates DOM on state changes, breaking Stage reference
- **v-show solution:** Hides via CSS (`display: none`) but keeps DOM alive for Stage

**Alternatives rejected:**
- v-if: Would break NGL Stage (Stage.dispose() on unmount, but Stage lost on hide)
- Separate component: Over-engineering for simple visibility toggle

**Impact:** CRITICAL for NGL integration (Stage lifecycle depends on DOM persistence)

### 3. Multi-Select Checkboxes

**Decision:** Multi-select checkboxes (not single-select radio buttons or click-to-toggle)

**Rationale:**
- **Spatial analysis:** Users need to highlight multiple variants simultaneously to see clustering (e.g., all pathogenic variants at active site)
- **Explicit state:** Checkboxes make selection state obvious (checked vs unchecked)
- **CONTEXT.md decision:** Plan specified multi-select for this use case

**Alternatives rejected:**
- Radio buttons: Too limiting (one variant at a time)
- Click-to-toggle: Less obvious selection state, no visual confirmation

**Impact:** User experience, variant analysis capability

### 4. Filter Variants to Structure-Mappable Types Only

**Decision:** VariantPanel only shows missense/inframe variants (parseResidueNumber returns null for frameshift/stop/splice)

**Rationale:**
- **Frameshift variants:** Protein truncated/altered downstream → no meaningful single position to highlight
- **Stop/nonsense variants:** Protein terminates → no residue exists to highlight
- **Splice variants:** No protein-level position available (cDNA-level change)
- **User clarification:** User explicitly requested this filtering behavior in prompt

**Alternatives rejected:**
- Show all variants grayed out: Clutters list with non-actionable items
- Show all and error on select: Bad UX (failed action after click)

**Impact:** Variant list content, user expectations

## Deviations from Plan

**None** - Plan executed exactly as written.

All requirements from `must_haves.truths` satisfied:
- ✓ ProteinStructure3D renders NGL viewer with pLDDT coloring in 500px container
- ✓ Toolbar provides cartoon/surface/ball+stick toggles with active state highlighting
- ✓ Reset View button returns structure to default orientation via resetView()
- ✓ pLDDT legend displays four confidence ranges with colored indicators
- ✓ Loading state shows centered spinner with "Loading 3D structure..." text
- ✓ Empty state shows "No AlphaFold structure available" message when no structure URL
- ✓ Error state shows failure message with retry option
- ✓ VariantPanel lists ClinVar variants with ACMG-colored badges and multi-select checkboxes
- ✓ Checking variant checkbox highlights residue as spacefill sphere on 3D structure
- ✓ Unchecking removes variant marker from structure
- ✓ All keyboard-accessible controls have aria-labels and keyboard event handlers

## Issues Encountered

**None** - Implementation proceeded smoothly with use3DStructure composable foundation from Plan 45-01.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Phase 45-03: Tabbed Visualization Card Integration**
- ✓ ProteinStructure3D ready for tab integration (pass geneSymbol, structureUrl, variants as props)
- ✓ VariantPanel integrated into ProteinStructure3D (no separate mounting needed)
- ✓ 500px fixed height matches gene visualization card container
- ✓ Loading/error/empty states handle all data scenarios gracefully

**Integration pattern:**
```vue
<!-- In GenomicVisualizationTabs.vue (Phase 45-03) -->
<BTab title="3D Structure" lazy>
  <ProteinStructure3D
    :gene-symbol="geneSymbol"
    :structure-url="alphafoldData?.pdb_url || null"
    :variants="clinvarVariants"
  />
</BTab>
```

**No blockers. Ready to proceed with 45-03.**

## Lessons Learned

### 1. parseResidueNumber Filtering Reduces User Confusion

**Insight:** Only showing structure-mappable variants (missense/inframe) prevents users from trying to highlight variants that can't be positioned on 3D structure.

**Implementation:** `parseResidueNumber()` returns null for frameshift/stop/splice → filtered out in `mappableVariants` computed → "No variants with protein positions" empty state shows when all filtered.

**Impact:** Clearer UX, no failed highlighting attempts.

### 2. Multi-Select Set Reactivity Requires Reassignment

**Insight:** Vue 3 reactivity doesn't trigger on Set.add() or Set.delete() mutations.

**Workaround:** `selectedResidues.value = new Set(selectedResidues.value)` after mutation.

**Alternative:** Convert to Array (loses O(1) has() performance), use Map (overkill for simple presence tracking).

### 3. v-show Critical for NGL DOM Persistence

**Insight:** v-if destroys and recreates DOM, breaking NGL Stage reference even if Stage exists in composable.

**Solution:** v-show hides via CSS but keeps DOM element alive for Stage reference.

**Pattern:** Any WebGL library integration needs v-show (not v-if) for visibility toggling.

### 4. 70/30 Layout Balances Viewer Space and Variant Visibility

**Insight:** 50/50 feels cramped for 3D viewer, 80/20 makes variant list too narrow for variant names.

**Sweet spot:** 70% viewer provides ample space for rotation/zoom, 30% panel fits ~10 variants before scrolling.

**Responsive:** On smaller screens, could switch to stacked layout (100% viewer above, 100% list below).

## File Manifest

**Created:**
- `app/src/components/gene/ProteinStructure3D.vue` (270 lines)
- `app/src/components/gene/VariantPanel.vue` (200 lines)

**Modified:** None

**Total:** 470 new lines, 2 files created

## Git Commits

| Commit | Message | Files |
|--------|---------|-------|
| 26b1dcf9 | feat(45-02): create ProteinStructure3D viewer component | ProteinStructure3D.vue |
| 5e6e66a4 | feat(45-02): create VariantPanel for multi-select variant highlighting | VariantPanel.vue |

**Total:** 2 atomic commits

---

*Phase: 45-3d-protein-structure-viewer*
*Completed: 2026-01-29*

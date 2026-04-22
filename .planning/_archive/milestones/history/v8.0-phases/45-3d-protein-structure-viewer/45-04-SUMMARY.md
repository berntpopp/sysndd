---
phase: 45-3d-protein-structure-viewer
plan: 04
subsystem: ui
tags: [vue, ngl-viewer, resize-observer, ux-enhancements, bug-fixes]

# Dependency graph
requires:
  - phase: 45-03
    provides: Integrated ProteinStructure3D into gene page
provides:
  - ResizeObserver-based canvas sizing fix for lazy tab initialization
  - Enhanced VariantPanel with ClinVar links and review stars
  - Fixed Reset View camera orientation restore
  - Disabled NGL built-in tooltip to prevent grey area bug
affects: [3d-viewer-reliability, variant-panel-ux]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ResizeObserver pattern for detecting valid container dimensions"
    - "Camera orientation save/restore using NGL ViewerControls API"

key-files:
  modified:
    - app/src/composables/use3DStructure.ts
    - app/src/components/gene/VariantPanel.vue
    - app/src/components/gene/VariantTooltip.vue
    - app/src/components/gene/ProteinStructure3D.vue

key-decisions:
  - "Use ResizeObserver instead of arbitrary timeouts for canvas initialization"
  - "Save initial camera orientation after autoView() for true Reset View"
  - "Disable NGL tooltip to avoid visual glitches"
  - "Use Teleport for variant tooltips to escape scrollable containers"

patterns-established:
  - "ResizeObserver + rAF + timeout fallback for reliable WebGL canvas sizing"
  - "NGL ViewerControls.getOrientation()/orient() for camera state management"

# Metrics
duration: ~60min
completed: 2026-01-29
---

# Phase 45 Plan 04: 3D Viewer Enhancements & Bug Fixes Summary

**Post-integration enhancements including ResizeObserver canvas fix, variant panel UX improvements, and Reset View camera fix**

## Performance

- **Duration:** ~60 min
- **Completed:** 2026-01-29
- **Files modified:** 4
- **Commits:** 4

## Bug Investigation

**Issue:** 3D structure viewer was blank on first tab click for some genes (CTCF, MECP2), but worked after page reload or second visit.

**Investigation Method:**
- Tested 5 genes using Playwright: CTCF, TP53, MECP2, SCN1A, SHANK3
- Checked network traffic: PDB files were downloading successfully from AlphaFold
- Console logs showed `loaded 'AF-xxxxx-model_v6.pdb'` - structure data was received
- Problem was canvas sizing, not data fetching

**Root Cause:** Race condition in Bootstrap Vue's lazy tab rendering:
1. User clicks "3D Structure" tab
2. Tab content is lazily mounted with container at 0x0 dimensions
3. NGL Stage initializes immediately and structure loads
4. Structure renders to invisible 0x0 canvas
5. The 100ms timeout fallback wasn't reliable enough for all cases

## Accomplishments

### 1. ResizeObserver Fix for Initial Render (use3DStructure.ts)
- Added `ResizeObserver` to detect when container gets actual dimensions
- Triggers `stage.handleResize()` only when width > 0 AND height > 0
- Properly disconnects observer on cleanup to prevent memory leaks
- Increased fallback timeout from 100ms to 300ms for additional reliability
- **Result:** All tested genes render correctly on first tab click

### 2. Reset View Camera Fix (use3DStructure.ts)
- **Problem:** Reset View only re-centered but didn't restore rotation
- **Solution:** Save camera orientation matrix after initial `autoView()` using `stage.viewerControls.getOrientation()`
- **Restore:** Use `stage.viewerControls.orient(initialOrientation)` in resetView()
- **Fallback:** If no saved orientation, falls back to `autoView()`

### 3. Variant Panel UX Enhancements (VariantPanel.vue)
- Added ClinVar external link icon to each variant row
- Added ClinVar review stars (★☆☆☆) display in each row
- Two-row layout per variant: notation + link on top, classification + stars below
- Click on link opens ClinVar variation page in new tab

### 4. NGL Tooltip Disabled (use3DStructure.ts)
- Disabled NGL's built-in tooltip via `tooltip: false` Stage option
- **Reason:** Built-in tooltip had broken dimensions causing grey area visual bug
- Custom tooltips handled by Vue components instead

### 5. Variant Tooltip Component (VariantTooltip.vue)
- Created dedicated tooltip component for variant hover display
- Uses Vue Teleport to render at body level (escapes scrollable containers)
- Non-scoped styles since Teleport renders outside component tree
- Structured data props instead of v-html (avoids XSS)

## Commits

1. `4325b27b` - fix(use3DStructure): disable NGL built-in tooltip to prevent grey area bug
2. `d128ded1` - feat(3d-viewer): enhance variant panel UI and fix Reset View
3. `3b6b3c86` - feat(gene-viz): add GeneStructurePlotWithVariants and refine visual components
4. `0b9da638` - fix(3d-viewer): use ResizeObserver to fix initial render race condition

## Files Modified

### app/src/composables/use3DStructure.ts
- Added `resizeObserver` variable for dimension detection
- Modified `initStage()` to create and observe ResizeObserver
- Modified `cleanup()` to disconnect ResizeObserver
- Added `initialOrientation` variable for camera state
- Modified `loadStructure()` to save orientation after autoView()
- Modified `resetView()` to restore saved orientation
- Added `tooltip: false` to Stage options
- Increased fallback timeout from 100ms to 300ms

### app/src/components/gene/VariantPanel.vue
- Added two-row layout per variant item
- Added ClinVar external link with clinvar_variation_id
- Added review stars display
- Updated CSS for compact layout

### app/src/components/gene/VariantTooltip.vue (NEW)
- Created dedicated tooltip component
- Uses Teleport to body for proper positioning
- Displays variant notation, classification, and review stars

### app/src/components/gene/ProteinStructure3D.vue
- Updated to use VariantTooltip component
- Minor layout adjustments

## Technical Details

### ResizeObserver Pattern
```typescript
resizeObserver = new ResizeObserver((entries) => {
  for (const entry of entries) {
    const { width, height } = entry.contentRect;
    // Only trigger resize when container has actual dimensions
    if (width > 0 && height > 0 && stage) {
      stage.handleResize();
    }
  }
});
resizeObserver.observe(containerRef.value);
```

### Camera Orientation Save/Restore
```typescript
// Save after autoView() in loadStructure()
initialOrientation = stage.viewerControls.getOrientation();

// Restore in resetView()
if (initialOrientation) {
  stage.viewerControls.orient(initialOrientation);
} else {
  structureComponent.autoView();
}
```

## Lint & TypeCheck

- TypeScript: Zero errors
- ESLint: Zero errors in modified files

## Issues Encountered

1. **Initial render race condition** - Solved with ResizeObserver
2. **Reset View not resetting rotation** - Solved with ViewerControls orientation API
3. **Tooltip positioning in scrollable container** - Solved with Vue Teleport

## Verification

Tested with Playwright automation:
- CTCF: Previously blank, now renders on first click
- TP53: Works correctly
- MECP2: Previously blank, now renders on first click
- SCN1A: Works correctly
- SHANK3: Works correctly

All 5 genes render 3D structure correctly on first tab activation.

---
*Phase: 45-3d-protein-structure-viewer*
*Enhancement work completed: 2026-01-29*

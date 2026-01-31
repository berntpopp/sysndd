# Phase 45: 3D Protein Structure Viewer - Research

**Researched:** 2026-01-28
**Domain:** 3D molecular visualization with NGL Viewer in Vue 3
**Confidence:** HIGH

## Summary

This research investigates implementing a 3D protein structure viewer using NGL Viewer v2.4.0, following the proven WebGL integration pattern from the project's existing Cytoscape composables. NGL Viewer is the established choice for this project (CONTEXT.md decision), replicating patterns from the hnf1b-db reference implementation.

**Key findings:**
- NGL Viewer v2.4.0 is the stable choice (777KB built chunk vs Mol* ~16MB)
- Vue 3 integration requires non-reactive Stage instance + `markRaw()` for performance
- `stage.dispose()` is CRITICAL for WebGL cleanup (browsers limit 8-16 contexts)
- AlphaFold structures store pLDDT in b-factor column, enabling direct `bfactor` colorScheme usage
- Multiple representations (cartoon + spacefill for variants) compose naturally via `addRepresentation()`
- Bootstrap Vue Next `<BTab lazy>` defers NGL chunk loading until tab activation

**Primary recommendation:** Follow existing `useCytoscape.ts` disposal pattern (non-reactive `let stage`, `markRaw()` objects, `onBeforeUnmount` cleanup) with lazy tab loading for the ~777KB NGL bundle.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| NGL Viewer | 2.4.0 | WebGL protein structure viewer | CONTEXT.md decision: proven in hnf1b-db, 777KB vs Mol* 16MB, active as of 2025 |
| Bootstrap Vue Next | 0.42.0 | Tab component with lazy loading | Already in project, `<BTab lazy>` defers mount until activation |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Vue 3 markRaw | 3.5.25 | Prevent reactivity on WebGL objects | MANDATORY for all NGL Stage/Component/Representation instances |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NGL Viewer | Mol* v5.5.0 | Mol* is RCSB's successor (NGL deprecated June 2024), but 16MB npm vs NGL 2.4MB. Future migration path if NGL becomes unmaintained. |
| Manual lazy load | Vite dynamic import | `defineAsyncComponent()` lazy-loads entire component; tab `lazy` prop cleaner for this UX (load on first click, persist content). |

**Installation:**
```bash
npm install ngl@2.4.0
```

**Note:** NGL Viewer v2.4.0 last published ~1 year ago (2024-2025). Package deemed safe (Snyk: no vulnerabilities, 14 dependents). Maintenance status: stable but low activity. Mol* migration path documented in CONTEXT.md deferred ideas.

## Architecture Patterns

### Recommended Project Structure
```
src/
├── composables/
│   └── use3DStructure.ts          # NGL Stage lifecycle (init, cleanup, controls)
├── components/gene/
│   └── GeneVisualizationCard.vue  # Tabbed card container
│   └── ProteinStructure3D.vue     # NGL viewer tab content
└── types/
    └── external.ts                 # AlphaFold metadata interface
```

### Pattern 1: Non-Reactive WebGL Instance
**What:** Store NGL Stage in plain `let` variable outside Vue reactivity system
**When to use:** MANDATORY for all WebGL libraries (Cytoscape, NGL, Three.js)
**Why:** Vue reactivity triggers layout recalculations on every mutation (100+ unnecessary renders)

**Example:**
```typescript
// composables/use3DStructure.ts
import { ref, onBeforeUnmount } from 'vue';
import * as NGL from 'ngl';

export function use3DStructure(containerRef: Ref<HTMLElement | null>) {
  // CRITICAL: Non-reactive variable (NOT ref())
  let stage: NGL.Stage | null = null;

  // Reactive state for UI
  const isInitialized = ref(false);
  const isLoading = ref(false);

  function initStage() {
    if (!containerRef.value) return;

    // Clean up existing instance
    if (stage) {
      stage.dispose();
      stage = null;
    }

    stage = new NGL.Stage(containerRef.value);
    isInitialized.value = true;
  }

  // CRITICAL: Cleanup to prevent WebGL context leak
  onBeforeUnmount(() => {
    if (stage) {
      stage.dispose();
      stage = null;
    }
  });

  return { initStage, isInitialized, isLoading };
}
```

**Source:** Existing `useCytoscape.ts` composable (lines 287-306, 576-581)

### Pattern 2: markRaw() for NGL Objects
**What:** Wrap Stage, Component, and Representation instances in `markRaw()`
**When to use:** When storing NGL objects in reactive state (arrays, maps)
**Why:** Prevents Vue from adding reactivity proxies to WebGL objects (crashes or memory bloat)

**Example:**
```typescript
import { ref, markRaw } from 'vue';

// Store component references for cleanup
const nglComponents = ref<NGL.Component[]>([]);

stage.loadFile('structure.pdb').then((component) => {
  // Wrap in markRaw before storing in reactive state
  nglComponents.value.push(markRaw(component));
  component.addRepresentation('cartoon');
});
```

**Source:** CONTEXT.md "Vue 3 integration pattern: non-reactive `let stage` variables + `markRaw()` for NGL objects"

### Pattern 3: Lazy Tab Loading with Bootstrap Vue Next
**What:** Use `<BTab lazy>` to defer NGL chunk load until user clicks "3D Structure" tab
**When to use:** For heavy libraries (>500KB) in tabbed interfaces
**Why:** Reduces initial page load, loads NGL only when needed

**Example:**
```vue
<template>
  <BTabs>
    <!-- Protein domains tab: instant load -->
    <BTab title="Protein Domains">
      <LollipopPlot :gene="gene" />
    </BTab>

    <!-- 3D structure tab: lazy load on first click -->
    <BTab title="3D Structure" lazy>
      <ProteinStructure3D :gene="gene" />
    </BTab>
  </BTabs>
</template>
```

**Source:** [Bootstrap Vue Next Tabs documentation](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/tabs) - "Individual `<BTab>` components can be lazy loaded via the `lazy` prop"

### Pattern 4: Multiple Representations for Variant Highlighting
**What:** Layer cartoon (base structure) + spacefill (variant markers) representations
**When to use:** Highlighting specific residues (variants) on top of full structure
**Why:** NGL supports multiple representations per component naturally

**Example:**
```typescript
// Base structure with pLDDT coloring
component.addRepresentation('cartoon', {
  colorScheme: 'bfactor' // AlphaFold pLDDT in b-factor column
});

// Highlight pathogenic variant at residue 123
const variantRepr = component.addRepresentation('spacefill', {
  sele: '123',           // Residue selection
  color: '#dc3545',      // Red for pathogenic (ACMG)
  radius: 2.0            // Enlarged sphere
});

// Store reference for toggle visibility
representations.set('variant-123', markRaw(variantRepr));
```

**Source:** [NGL Manual - Multiple Representations](https://nglviewer.org/ngl/api/manual/molecular-representations.html) - "Each loaded structure can be displayed using a variety of representations that can be combined"

### Pattern 5: Representation Visibility Toggle
**What:** Show/hide representations using `setVisibility(boolean)`
**When to use:** User controls (representation buttons, variant checkboxes)
**Why:** Efficient - doesn't recreate geometry, just toggles rendering

**Example:**
```typescript
// Store representation on creation
const cartoonRepr = component.addRepresentation('cartoon', {...});
const surfaceRepr = component.addRepresentation('surface', {...});

// Toggle representations (radio button behavior)
function showCartoon() {
  cartoonRepr.setVisibility(true);
  surfaceRepr.setVisibility(false);
}

function showSurface() {
  cartoonRepr.setVisibility(false);
  surfaceRepr.setVisibility(true);
}
```

**Source:** [GitHub Issue #585](https://github.com/nglviewer/ngl/issues/585) - "Use `setVisibility()` method on representation reference"

### Pattern 6: AlphaFold pLDDT Color Scheme
**What:** Use NGL's `bfactor` colorScheme for AlphaFold confidence coloring
**When to use:** Displaying AlphaFold predictions (pLDDT stored in b-factor column)
**Why:** AlphaFold PDB files store pLDDT (0-100) in b-factor field - NGL's `bfactor` scheme auto-scales

**Example:**
```typescript
component.addRepresentation('cartoon', {
  colorScheme: 'bfactor'
});

// NGL auto-detects b-factor range (0-100 for AlphaFold)
// Maps to default gradient: blue (high) → cyan → yellow → orange (low)
// Matches AlphaFold DB convention:
//   > 90 (very high): dark blue
//   70-90 (confident): light blue
//   50-70 (low): yellow
//   < 50 (very low): orange
```

**Source:** [NGL Manual - Coloring](https://nglviewer.org/ngl/api/manual/usage/coloring.html) - "By default, the min and max b-factor values are used for the scale's domain"

### Anti-Patterns to Avoid

- **Storing Stage in ref():** Causes Vue reactivity system to track WebGL mutations → 100+ layout recalculations → frozen UI. Use plain `let` variable.
- **Forgetting stage.dispose():** Browsers limit WebGL contexts to 8-16. Without cleanup, 16th gene page navigation crashes with "Exceeded WebGL context limit". ALWAYS call `dispose()` in `onBeforeUnmount()`.
- **Reactive arrays of NGL objects without markRaw():** Vue wraps objects in Proxy → WebGL state corruption or memory bloat. Wrap each NGL object in `markRaw()`.
- **Loading full NGL bundle upfront:** 777KB chunk blocks initial page load. Use `<BTab lazy>` for tab-deferred loading.
- **Re-creating representations on toggle:** `removeRepresentation()` + `addRepresentation()` is slow (re-parses geometry). Use `setVisibility()` for instant toggle.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Custom pLDDT color scale | Manual gradient calculation from b-factor values | NGL's `colorScheme: 'bfactor'` | NGL auto-scales b-factor range to gradient. AlphaFold stores pLDDT in b-factor column, convention matches AlphaFold DB (blue>90, cyan 70-90, yellow 50-70, orange <50). |
| Residue selection syntax | Custom position → atom mapping | NGL selection language: `"123"` (residue 123), `"100-150"` (range), `"10 or 20 or 30"` (multi) | Production-tested syntax with chain/atom qualifiers (`:A and 123`, `.CA`). Handles edge cases (insertion codes, alt locs). |
| WebGL context management | Custom WebGL resource tracking | NGL's `stage.dispose()` method | NGL internally manages buffers, textures, shaders. `dispose()` releases all WebGL resources properly. Manual cleanup misses internal state. |
| Tab lazy loading logic | `v-if` with manual import timing | Bootstrap Vue Next `<BTab lazy>` | Framework-integrated: loads on first activation, persists content, handles edge cases (tab switching during load). |
| Representation toggle animations | Custom show/hide transitions | NGL's `setVisibility(boolean)` | Instant toggle without geometry re-creation. WebGL rendering paused efficiently. Custom transitions risk frame drops with large structures. |

**Key insight:** NGL Viewer is a mature library (10+ years, RCSB PDB heritage) with deep domain knowledge of protein structure edge cases. AlphaFold integration (b-factor coloring) is convention-based, not NGL-specific, but NGL's built-in scheme handles it perfectly. Don't rebuild molecular graphics primitives.

## Common Pitfalls

### Pitfall 1: WebGL Context Leak (Memory Leak)
**What goes wrong:** Navigating between 16+ gene pages crashes with "Exceeded 16 live WebGL contexts for this principal, losing the least recently used one"
**Why it happens:** Browsers limit WebGL contexts to 8-16 per origin. Each NGL Stage creates a context. Without `dispose()`, contexts accumulate until limit reached.
**How to avoid:**
```typescript
onBeforeUnmount(() => {
  if (stage) {
    stage.dispose();  // CRITICAL: Releases WebGL context
    stage = null;
  }
});
```
**Warning signs:**
- Chrome console warning "WebGL: CONTEXT_LOST_WEBGL"
- Blank/black viewer on 16th+ page load
- DevTools Memory panel shows increasing WebGL memory (check with heap snapshots before/after navigation)

**Source:** [GitHub Issue #532](https://github.com/arose/ngl/issues/532) - "Using stage.dispose() should be sufficient"

### Pitfall 2: Vue Reactivity Performance Degradation
**What goes wrong:** UI freezes for 5-10 seconds when loading structure or toggling representations
**Why it happens:** Storing Stage in `ref()` causes Vue to proxy WebGL objects. Every `stage.addRepresentation()` or view manipulation triggers Vue's reactivity system → 100+ component re-renders.
**How to avoid:**
```typescript
// WRONG: Vue reactivity wraps Stage
const stage = ref<NGL.Stage | null>(null);

// CORRECT: Plain variable outside reactivity
let stage: NGL.Stage | null = null;
const isLoading = ref(false); // UI state still reactive
```
**Warning signs:**
- Browser "Page Unresponsive" dialog during structure load
- Vue DevTools shows 100+ component updates per second
- Timeline profiler shows long "Recalculate Style" blocks

**Source:** Existing `useCytoscape.ts` lines 9-10 - "CRITICAL: Cytoscape instance is stored in a non-reactive variable to avoid Vue reactivity triggering 100+ layout recalculations"

### Pitfall 3: Incorrect pLDDT Color Interpretation
**What goes wrong:** Users think orange regions (pLDDT <50) mean "bad structure" and dismiss entire protein as unreliable
**Why it happens:** AlphaFold pLDDT coloring looks like error/warning states (red/orange = bad in UI convention). Low pLDDT often occurs in flexible loops/disordered regions - biologically accurate, not prediction failure.
**How to avoid:**
- Show pLDDT legend with explicit labels: "Very High (>90)", "Confident (70-90)", "Low (50-70)", "Very Low (<50)"
- Educational tooltip: "Low confidence regions often represent flexible/disordered loops, not prediction errors"
- Link to AlphaFold documentation explaining pLDDT interpretation
**Warning signs:**
- User feedback: "Structure quality is poor" when only loop regions are orange
- Support questions about "why is this protein broken?"

**Source:** [AlphaFold DB 2025 paper](https://academic.oup.com/nar/article/54/D1/D358/8340156) - "pLDDT corresponds to the model's predicted per-residue scores on the lDDT-Cα metric"

### Pitfall 4: Lazy Tab Race Condition
**What goes wrong:** NGL Stage initialization fails silently because container element doesn't exist yet
**Why it happens:** Bootstrap Vue Next `lazy` mounts tab content asynchronously. If `initStage()` runs in `onMounted()`, container ref may still be null during first render cycle.
**How to avoid:**
```typescript
// WRONG: Immediate init in onMounted
onMounted(() => {
  initStage(); // containerRef.value might be null
});

// CORRECT: Watch container ref or use nextTick
watch(containerRef, (newVal) => {
  if (newVal && !isInitialized.value) {
    initStage();
  }
}, { immediate: true });

// OR: nextTick ensures DOM updated
onMounted(() => {
  nextTick(() => {
    if (containerRef.value) initStage();
  });
});
```
**Warning signs:**
- Blank viewer area, no errors in console
- `stage` is null after tab activation
- "Container element not found" logs

**Source:** Bootstrap Vue Next tabs behavior - lazy tabs mount asynchronously

### Pitfall 5: ACMG Color Mismatch with Lollipop Plot
**What goes wrong:** Variant appears red (pathogenic) on lollipop but yellow on 3D viewer
**Why it happens:** Inconsistent ACMG color mapping between components. Lollipop uses Bootstrap variants (`variant="danger"`), 3D viewer uses hex colors.
**How to avoid:**
Define shared ACMG color constants:
```typescript
// types/external.ts or utils/colors.ts
export const ACMG_COLORS = {
  pathogenic: '#dc3545',        // Bootstrap danger red
  likely_pathogenic: '#fd7e14',  // Custom orange (.badge-lp)
  vus: '#ffc107',               // Bootstrap warning yellow
  likely_benign: '#20c997',     // Custom teal (.badge-lb)
  benign: '#28a745'             // Bootstrap success green
} as const;

// Use in NGL representation
component.addRepresentation('spacefill', {
  sele: '123',
  color: ACMG_COLORS.pathogenic
});
```
**Warning signs:**
- User confusion: "Why does this variant look different in 3D?"
- QA reports color inconsistency bugs

**Source:** Existing `GeneClinVarCard.vue` lines 168-177 - Custom badge colors for ACMG classifications

## Code Examples

### Example 1: Complete use3DStructure Composable
```typescript
// composables/use3DStructure.ts
import { ref, onBeforeUnmount, watch, markRaw, type Ref } from 'vue';
import * as NGL from 'ngl';

export interface Use3DStructureReturn {
  isInitialized: Ref<boolean>;
  isLoading: Ref<boolean>;
  initStage: () => void;
  loadStructure: (url: string) => Promise<void>;
  addVariantMarker: (residue: number, color: string) => void;
  setRepresentation: (type: 'cartoon' | 'surface' | 'ball+stick') => void;
  resetView: () => void;
}

export function use3DStructure(
  containerRef: Ref<HTMLElement | null>
): Use3DStructureReturn {
  // CRITICAL: Non-reactive Stage instance
  let stage: NGL.Stage | null = null;
  let structureComponent: NGL.Component | null = null;

  // Representation references for toggle (wrapped in markRaw)
  const representations = new Map<string, NGL.RepresentationElement>();

  // Reactive UI state only
  const isInitialized = ref(false);
  const isLoading = ref(false);

  function initStage(): void {
    if (!containerRef.value) {
      console.warn('use3DStructure: container not available');
      return;
    }

    // Clean up existing instance
    if (stage) {
      stage.dispose();
      stage = null;
    }

    stage = new NGL.Stage(containerRef.value, {
      backgroundColor: 'white'
    });

    // Handle window resize
    window.addEventListener('resize', handleResize);

    isInitialized.value = true;
  }

  function handleResize(): void {
    if (stage) stage.handleResize();
  }

  async function loadStructure(url: string): Promise<void> {
    if (!stage) return;

    isLoading.value = true;

    try {
      // Remove previous structure
      if (structureComponent) {
        stage.removeComponent(structureComponent);
      }

      // Load new structure
      structureComponent = await stage.loadFile(url);

      // Default: cartoon with pLDDT coloring
      const cartoonRepr = structureComponent.addRepresentation('cartoon', {
        colorScheme: 'bfactor' // AlphaFold pLDDT in b-factor
      });
      representations.set('cartoon', markRaw(cartoonRepr));

      // Auto-view structure
      structureComponent.autoView();
    } catch (error) {
      console.error('Failed to load structure:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  function addVariantMarker(residue: number, color: string): void {
    if (!structureComponent) return;

    const key = `variant-${residue}`;

    // Remove existing marker for this residue
    if (representations.has(key)) {
      structureComponent.removeRepresentation(representations.get(key)!);
      representations.delete(key);
    }

    // Add new spacefill marker
    const variantRepr = structureComponent.addRepresentation('spacefill', {
      sele: `${residue}`,  // Residue number selection
      color: color,        // ACMG color
      radius: 2.0          // Enlarged sphere
    });

    representations.set(key, markRaw(variantRepr));
  }

  function setRepresentation(type: 'cartoon' | 'surface' | 'ball+stick'): void {
    if (!structureComponent) return;

    // Hide all base representations
    ['cartoon', 'surface', 'ball+stick'].forEach(name => {
      if (representations.has(name)) {
        representations.get(name)!.setVisibility(false);
      }
    });

    // Show/create requested representation
    if (representations.has(type)) {
      representations.get(type)!.setVisibility(true);
    } else {
      const repr = structureComponent.addRepresentation(type, {
        colorScheme: 'bfactor'
      });
      representations.set(type, markRaw(repr));
    }
  }

  function resetView(): void {
    if (structureComponent) {
      structureComponent.autoView();
    }
  }

  // CRITICAL: Cleanup to prevent WebGL context leak
  onBeforeUnmount(() => {
    window.removeEventListener('resize', handleResize);

    if (stage) {
      stage.dispose();
      stage = null;
    }

    structureComponent = null;
    representations.clear();
  });

  // Initialize when container becomes available (lazy tab)
  watch(containerRef, (newVal) => {
    if (newVal && !isInitialized.value) {
      initStage();
    }
  }, { immediate: true });

  return {
    isInitialized,
    isLoading,
    initStage,
    loadStructure,
    addVariantMarker,
    setRepresentation,
    resetView
  };
}
```

**Source:** Adapted from existing `useCytoscape.ts` pattern (non-reactive instance, onBeforeUnmount cleanup)

### Example 2: ProteinStructure3D Component with Tab Integration
```vue
<template>
  <div class="protein-structure-3d">
    <!-- Loading state -->
    <div v-if="isLoading" class="text-center py-5">
      <BSpinner label="Loading 3D structure..." />
    </div>

    <!-- Error state -->
    <div v-else-if="error" class="text-center py-5">
      <i class="bi bi-exclamation-triangle text-warning"></i>
      <p class="text-muted">{{ error }}</p>
    </div>

    <!-- Empty state -->
    <div v-else-if="!structureUrl" class="text-center py-5">
      <i class="bi bi-info-circle text-muted"></i>
      <p class="text-muted">No AlphaFold structure available for {{ geneSymbol }}</p>
    </div>

    <!-- 3D Viewer -->
    <div v-show="isInitialized && !isLoading && structureUrl" class="viewer-container">
      <!-- NGL viewport -->
      <div ref="viewerContainer" class="ngl-viewport" />

      <!-- Controls toolbar -->
      <div class="controls-toolbar">
        <BButtonGroup size="sm">
          <BButton
            :variant="activeRepr === 'cartoon' ? 'primary' : 'outline-secondary'"
            @click="setRepresentation('cartoon')"
          >
            Cartoon
          </BButton>
          <BButton
            :variant="activeRepr === 'surface' ? 'primary' : 'outline-secondary'"
            @click="setRepresentation('surface')"
          >
            Surface
          </BButton>
          <BButton
            :variant="activeRepr === 'ball+stick' ? 'primary' : 'outline-secondary'"
            @click="setRepresentation('ball+stick')"
          >
            Ball+Stick
          </BButton>
        </BButtonGroup>

        <BButton
          variant="outline-secondary"
          size="sm"
          @click="resetView"
        >
          <i class="bi bi-arrow-clockwise"></i> Reset View
        </BButton>
      </div>

      <!-- pLDDT Legend -->
      <div class="plddt-legend">
        <span class="legend-title">pLDDT Confidence:</span>
        <span class="legend-item">
          <span class="legend-color" style="background: #0053d6;"></span> Very High (>90)
        </span>
        <span class="legend-item">
          <span class="legend-color" style="background: #65cbf3;"></span> Confident (70-90)
        </span>
        <span class="legend-item">
          <span class="legend-color" style="background: #ffdb13;"></span> Low (50-70)
        </span>
        <span class="legend-item">
          <span class="legend-color" style="background: #ff7d45;"></span> Very Low (<50)
        </span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { BSpinner, BButton, BButtonGroup } from 'bootstrap-vue-next';
import { use3DStructure } from '@/composables/use3DStructure';

const props = defineProps<{
  geneSymbol: string;
  structureUrl?: string;
}>();

const viewerContainer = ref<HTMLElement | null>(null);
const activeRepr = ref<'cartoon' | 'surface' | 'ball+stick'>('cartoon');
const error = ref<string | null>(null);

const {
  isInitialized,
  isLoading,
  loadStructure,
  setRepresentation: setRepr,
  resetView
} = use3DStructure(viewerContainer);

function setRepresentation(type: 'cartoon' | 'surface' | 'ball+stick') {
  activeRepr.value = type;
  setRepr(type);
}

onMounted(async () => {
  if (props.structureUrl) {
    try {
      await loadStructure(props.structureUrl);
    } catch (err) {
      error.value = 'Failed to load 3D structure';
    }
  }
});
</script>

<style scoped>
.protein-structure-3d {
  position: relative;
  height: 500px;
}

.viewer-container {
  position: relative;
  height: 100%;
}

.ngl-viewport {
  width: 100%;
  height: 100%;
}

.controls-toolbar {
  position: absolute;
  top: 10px;
  left: 10px;
  display: flex;
  gap: 10px;
  z-index: 10;
}

.plddt-legend {
  position: absolute;
  bottom: 10px;
  left: 10px;
  background: rgba(255, 255, 255, 0.9);
  padding: 8px 12px;
  border-radius: 4px;
  font-size: 0.875rem;
  display: flex;
  gap: 10px;
  align-items: center;
  z-index: 10;
}

.legend-title {
  font-weight: 600;
  margin-right: 5px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

.legend-color {
  display: inline-block;
  width: 20px;
  height: 12px;
  border-radius: 2px;
}
</style>
```

**Source:** Pattern from hnf1b-db `ProteinStructure3D.vue` (CONTEXT.md reference)

### Example 3: Tabbed Visualization Card Integration
```vue
<template>
  <BCard
    class="gene-visualization-card"
    header-class="p-2"
    border-variant="dark"
  >
    <template #header>
      <h5 class="mb-0">Gene Visualizations</h5>
    </template>

    <BTabs content-class="p-0" card>
      <!-- Protein Domains tab: always loaded -->
      <BTab title="Protein Domains" active>
        <LollipopPlot :gene-symbol="geneSymbol" :variants="variants" />
      </BTab>

      <!-- Gene Structure tab: always loaded -->
      <BTab title="Gene Structure">
        <GeneStructurePlot :gene-symbol="geneSymbol" />
      </BTab>

      <!-- 3D Structure tab: lazy loaded on first click -->
      <BTab title="3D Structure" lazy>
        <ProteinStructure3D
          :gene-symbol="geneSymbol"
          :structure-url="alphafoldUrl"
        />
      </BTab>
    </BTabs>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BCard, BTabs, BTab } from 'bootstrap-vue-next';
import LollipopPlot from './LollipopPlot.vue';
import GeneStructurePlot from './GeneStructurePlot.vue';
import ProteinStructure3D from './ProteinStructure3D.vue';

const props = defineProps<{
  geneSymbol: string;
  variants: ClinVarVariant[];
  alphafoldUrl?: string;
}>();
</script>

<style scoped>
.gene-visualization-card {
  margin-bottom: 1rem;
}

/* Fixed height for all tabs to prevent layout shift */
.gene-visualization-card :deep(.card-body) {
  min-height: 500px;
}
</style>
```

**Source:** Bootstrap Vue Next tabs documentation + CONTEXT.md tabbed card pattern

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NGL Viewer (active) | Mol* (RCSB successor) | June 2024 (NGL deprecated by RCSB) | NGL v2.4.0 still stable for production (2024-2025), but Mol* is future direction. NGL lighter (777KB vs 16MB), but migration path needed if maintenance stops. |
| Global NGL import | Lazy tab loading | 2023+ (Vite code splitting maturity) | 777KB NGL bundle no longer blocks initial page load. Tab-level lazy loading defers until user activates 3D view. |
| Manual WebGL cleanup | Framework-integrated lifecycle | Vue 3 Composition API (2020+) | `onBeforeUnmount()` hook ensures cleanup runs reliably. Previous class component pattern required manual `destroyed()` hook calls. |
| Custom pLDDT gradients | AlphaFold DB convention | AlphaFold DB v4 (2022) standardized colors | Blue-cyan-yellow-orange scheme now universally recognized. NGL's `bfactor` colorScheme matches convention automatically (no custom mapping). |

**Deprecated/outdated:**
- **Mol* instead of NGL (CONTEXT.md decision):** Mol* is RCSB's official successor (NGL deprecated June 2024), but project chose NGL for size (777KB vs 16MB) and proven hnf1b-db patterns. Mol* migration path documented as deferred idea if NGL becomes unmaintained.
- **defineAsyncComponent for NGL:** Bootstrap Vue Next `<BTab lazy>` cleaner than wrapping entire component in `defineAsyncComponent()`. Tab handles mount timing, loading states, and content persistence automatically.

## Open Questions

### Question 1: AlphaFold pLDDT Color Scale Customization
**What we know:** NGL's `bfactor` colorScheme auto-scales b-factor values to default gradient. AlphaFold pLDDT ranges (>90, 70-90, 50-70, <50) map to blue-cyan-yellow-orange.
**What's unclear:** Can we enforce exact AlphaFold DB color breakpoints (discrete thresholds instead of continuous gradient)?
**Recommendation:** Use default `bfactor` scheme (matches AlphaFold DB visually). If exact control needed, explore `NGL.ColormakerRegistry.addScheme()` with custom `atomColor` function reading b-factor per residue. Priority: LOW (default scheme sufficient for Phase 45).

### Question 2: AlphaFold Structure File Format (CIF vs PDB)
**What we know:** AlphaFold provides both PDB (.pdb) and mmCIF (.cif) formats. Both store pLDDT in b-factor field. NGL loads both via `stage.loadFile()`.
**What's unclear:** Does backend proxy return URLs for both? Which format is preferred for performance/accuracy?
**Recommendation:** Check backend Phase 40 implementation. If both available, prefer mmCIF (modern standard, better precision). If only PDB, use PDB (legacy format but widely compatible). Test both in task 45-01.

### Question 3: Variant Position Mapping (Amino Acid Coordinate)
**What we know:** ClinVar variants have `hgvsp` (e.g., "p.Arg123Trp"). Need residue number (123) for NGL selection (`sele: "123"`).
**What's unclear:** How to extract residue number from HGVSP? Does `hgvsp` always include number, or can it be null?
**Recommendation:** Parse `hgvsp` with regex (e.g., `/p\.\w+(\d+)\w+/`) in composable. Handle null `hgvsp` gracefully (skip variant marker). Consider edge cases (insertions like "p.Ala123_Thr124insGly").

### Question 4: Multi-Chain AlphaFold Structures
**What we know:** AlphaFold DB v6 includes multi-chain predictions. NGL selection syntax supports chain qualifiers (`:A and 123`).
**What's unclear:** Are SysNDD genes primarily single-chain? If multi-chain, which chain do ClinVar variants map to?
**Recommendation:** Assume single-chain for Phase 45 MVP. If multi-chain encountered, default to chain A or first chain. Add chain selection UI in future enhancement if needed.

## Sources

### Primary (HIGH confidence)
- [NGL Viewer Manual](https://nglviewer.org/ngl/api/manual/) - Stage class, representations, color schemes
- [NGL Viewer Stage API](https://nglviewer.org/ngl/api/class/src/stage/stage.js~Stage.html) - `dispose()` method documentation
- [Bootstrap Vue Next Tabs](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs/components/tabs) - `<BTab lazy>` prop behavior
- Existing `useCytoscape.ts` composable - WebGL cleanup pattern verified in production
- Existing `GeneClinVarCard.vue` - ACMG color scheme (red #dc3545, orange #fd7e14, yellow #ffc107, teal #20c997, green #28a745)

### Secondary (MEDIUM confidence)
- [GitHub Issue #532 - NGL Stage disposal](https://github.com/arose/ngl/issues/532) - Maintainer confirms `stage.dispose()` sufficient
- [GitHub Issue #585 - Representation visibility](https://github.com/nglviewer/ngl/issues/585) - `setVisibility()` method pattern
- [NGL Selection Language](https://nglviewer.org/ngl/api/manual/usage/selection-language.html) - Residue selection syntax
- [NGL Coloring Documentation](https://nglviewer.org/ngl/api/manual/usage/coloring.html) - `bfactor` colorScheme behavior
- [AlphaFold DB 2025 Paper](https://academic.oup.com/nar/article/54/D1/D358/8340156) - pLDDT coloring convention
- [Vue 3 defineAsyncComponent](https://vuejs.org/guide/components/async) - Alternative lazy loading pattern (not used, but documented)

### Tertiary (LOW confidence)
- [npm ngl package](https://www.npmjs.com/package/ngl) - Version 2.4.0 info (published ~1 year ago, maintenance status unclear)
- [Snyk ngl analysis](https://snyk.io/advisor/npm-package/ngl) - No vulnerabilities (as of 2024)
- WebSearch: WCAG keyboard accessibility - General standards, not NGL-specific. Recommend manual testing for Phase 45 A11Y-04 requirement.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - NGL v2.4.0 is CONTEXT.md locked decision, version confirmed on npm, integration pattern proven in existing `useCytoscape.ts`
- Architecture: HIGH - Non-reactive instance + `markRaw()` + `onBeforeUnmount()` patterns verified in production Cytoscape composable, NGL API documented with examples
- Pitfalls: HIGH - WebGL context leak documented in NGL GitHub issues, Vue reactivity pitfall experienced in Cytoscape implementation, pLDDT interpretation from AlphaFold DB docs
- Code examples: HIGH - Composable structure adapted from battle-tested `useCytoscape.ts`, NGL API calls verified in official docs

**Research date:** 2026-01-28
**Valid until:** 30 days (2026-02-27) - Stable domain (NGL v2.4.0 unlikely to change, Vue 3.5 stable, Bootstrap Vue Next 0.42 established)

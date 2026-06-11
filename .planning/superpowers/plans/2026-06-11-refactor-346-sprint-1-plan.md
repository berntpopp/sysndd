# Refactor #346 Sprint 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Execute Sprint 1 of the #346 continuous refactor: tighten the file-size ratchet baseline, split `useD3Lollipop.ts` (1125 lines) into a `composables/d3-lollipop/` module directory, extract the delete-confirmation modal out of `TablesLogs.vue` (1221 lines), and create the WP1–WP9 tracking sub-issues.

**Architecture:** Behavior-preserving extractions only. Public APIs are unchanged: `useD3Lollipop`/`LollipopOptions`/`D3LollipopState`/`PlotMargin` stay importable from `@/composables`; `TablesLogs.vue` keeps its name, props, and the `deleteMode`/`deleteLogs()` surface its Vitest spec drives. All mutable D3 closure state moves into a single shared context object so aliasing semantics are preserved across module boundaries.

**Tech Stack:** Vue 3 (Options API in TablesLogs, composables in TS), D3.js, Vitest + MSW, bash ratchet script, gh CLI.

**Spec:** `.planning/superpowers/specs/2026-06-11-continuous-refactor-346-workpackages-design.md`

---

### Task 1: Branch setup

**Files:** none (git only)

- [ ] **Step 1: Create the sprint branch from clean master**

```bash
cd /home/bernt-popp/development/sysndd
git status --porcelain   # expect empty
git checkout -b refactor/346-sprint-1
```

Expected: on branch `refactor/346-sprint-1`.

---

### Task 2: WP0 — tighten the ratchet baseline

**Files:**
- Modify: `scripts/code-quality-file-size-baseline.tsv`

- [ ] **Step 1: Rewrite the baseline from current actual sizes**

```bash
bash scripts/code-quality-audit.sh --write-baseline
```

- [ ] **Step 2: Verify the diff is only downward**

```bash
git diff --stat scripts/code-quality-file-size-baseline.tsv
git diff scripts/code-quality-file-size-baseline.tsv
```

Expected: entries for `app/src/views/curate/ModifyEntity.vue` (598), `api/endpoints/external_endpoints.R` (579), `api/endpoints/review_endpoints.R` (576) are REMOVED (now under 600); ~10 other entries decrease (e.g. `api/endpoints/admin_endpoints.R` 1368→1084, `app/src/components/analyses/AnalyseGeneClusters.vue` 1387→1270). No entry increases and no new entry appears. If any entry increases, STOP — that's a bug in the working tree, not the baseline.

- [ ] **Step 3: Verify the audit passes**

```bash
make code-quality-audit
```

Expected: `code-quality-audit: OK`.

- [ ] **Step 4: Commit**

```bash
git add scripts/code-quality-file-size-baseline.tsv
git commit -m "chore(quality): tighten file-size ratchet baseline to current actuals (#346)"
```

---

### Task 3: d3-lollipop — extract pure helpers with TDD

**Files:**
- Create: `app/src/composables/d3-lollipop/lollipop-helpers.ts`
- Create: `app/src/composables/d3-lollipop/lollipop-helpers.spec.ts`
- Modify: `app/src/composables/useD3Lollipop.ts` (remove lines 85–180, import instead)

The five pure functions and the constants block at `useD3Lollipop.ts:85-180` move verbatim into a helpers module. They are currently module-private; they become exported (internal to the d3-lollipop directory; NOT re-exported from `@/composables`).

- [ ] **Step 1: Write the failing test**

Create `app/src/composables/d3-lollipop/lollipop-helpers.spec.ts`:

```typescript
import { describe, expect, it } from 'vitest';
import { normalizeEffectType } from '@/types/protein';
import type { LollipopFilterState } from '@/types/protein';
import {
  AGGREGATION_THRESHOLD,
  MIN_MARKER_RADIUS,
  MAX_MARKER_RADIUS,
  calculateAggregatedRadius,
  calculateDynamicOpacity,
  determineRenderingMode,
  isClassificationVisible,
  isEffectTypeVisible,
} from './lollipop-helpers';

function makeFilterState(overrides: Partial<LollipopFilterState> = {}): LollipopFilterState {
  return {
    pathogenic: true,
    likelyPathogenic: false,
    vus: true,
    likelyBenign: false,
    benign: true,
    ...overrides,
  } as LollipopFilterState;
}

describe('lollipop-helpers', () => {
  it('isClassificationVisible maps classes to filter flags and defaults unknown to visible', () => {
    const fs = makeFilterState();
    expect(isClassificationVisible('Pathogenic', fs)).toBe(true);
    expect(isClassificationVisible('Likely pathogenic', fs)).toBe(false);
    expect(isClassificationVisible('Uncertain significance', fs)).toBe(true);
    expect(isClassificationVisible('Likely benign', fs)).toBe(false);
    expect(isClassificationVisible('Benign', fs)).toBe(true);
  });

  it('isEffectTypeVisible shows all when effectFilters is missing', () => {
    expect(isEffectTypeVisible('missense_variant', makeFilterState())).toBe(true);
  });

  it('isEffectTypeVisible respects the normalized effect-type flag', () => {
    const effectType = normalizeEffectType('missense_variant');
    const fs = makeFilterState({
      effectFilters: { [effectType]: false } as LollipopFilterState['effectFilters'],
    });
    expect(isEffectTypeVisible('missense_variant', fs)).toBe(false);
  });

  it('calculateDynamicOpacity combines density and zoom and clamps to bounds', () => {
    // 1 visible variant at full view: densityFactor=1, zoomFactor=0.4 -> 0.7
    expect(calculateDynamicOpacity(1, 1)).toBeCloseTo(0.7, 5);
    // huge count at full view clamps to MIN_OPACITY (0.25)
    expect(calculateDynamicOpacity(10000, 1)).toBeCloseTo(0.25, 5);
    // tiny count fully zoomed clamps to MAX_OPACITY (0.95)
    expect(calculateDynamicOpacity(1, 0)).toBeCloseTo(0.95, 5);
  });

  it('calculateAggregatedRadius scales by sqrt of count share within bounds', () => {
    expect(calculateAggregatedRadius(9, 9)).toBeCloseTo(MAX_MARKER_RADIUS, 5);
    expect(calculateAggregatedRadius(0, 9)).toBeCloseTo(MIN_MARKER_RADIUS, 5);
  });

  it('determineRenderingMode switches at the aggregation threshold', () => {
    expect(determineRenderingMode(AGGREGATION_THRESHOLD)).toBe('individual');
    expect(determineRenderingMode(AGGREGATION_THRESHOLD + 1)).toBe('aggregated');
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd app && npx vitest run src/composables/d3-lollipop/lollipop-helpers.spec.ts
```

Expected: FAIL — cannot resolve `./lollipop-helpers`.

- [ ] **Step 3: Create the helpers module**

Create `app/src/composables/d3-lollipop/lollipop-helpers.ts`. Move the content of `useD3Lollipop.ts` lines 85–180 verbatim, adding `export` to every constant and function, plus the type imports they need:

```typescript
// composables/d3-lollipop/lollipop-helpers.ts

/**
 * Pure constants and helper functions for the D3 lollipop plot.
 * Internal to the d3-lollipop module directory; not part of the
 * public composables API.
 */

import type { LollipopFilterState, PathogenicityClass, EffectType } from '@/types/protein';
import { normalizeEffectType } from '@/types/protein';
import type { PlotMargin } from './useD3Lollipop';

// Default options
export const DEFAULT_WIDTH = 800;
export const DEFAULT_HEIGHT = 250;
export const DEFAULT_MARGIN: PlotMargin = { top: 60, right: 30, bottom: 60, left: 50 };

// Visual constants
export const BACKBONE_HEIGHT = 14;
export const STEM_BASE_HEIGHT = 18;
export const STEM_STACK_OFFSET = 8;
export const MARKER_RADIUS = 5;
export const MARKER_STROKE_WIDTH = 1;

// Adaptive rendering thresholds
export const AGGREGATION_THRESHOLD = 500;
export const MAX_STACK_DEPTH = 8;
export const MIN_OPACITY = 0.25;
export const MAX_OPACITY = 0.95;
export const DENSITY_THRESHOLD = 200;
export const MIN_MARKER_RADIUS = 3;
export const MAX_MARKER_RADIUS = 12;

// ... move isClassificationVisible, isEffectTypeVisible,
// calculateDynamicOpacity, calculateAggregatedRadius,
// determineRenderingMode here VERBATIM from useD3Lollipop.ts:106-180,
// each with `export function` instead of `function`.
```

NOTE: if importing `PlotMargin` from `./useD3Lollipop` creates a circular import once Task 4 moves the composable, define `PlotMargin` inline here in Task 4 and re-export it from the composable; for this task the file still lives at `app/src/composables/useD3Lollipop.ts`, so import from `../useD3Lollipop`.

- [ ] **Step 4: Update `useD3Lollipop.ts` to import from the new module**

Delete lines 85–180 from `app/src/composables/useD3Lollipop.ts` and add to its imports:

```typescript
import {
  DEFAULT_WIDTH,
  DEFAULT_HEIGHT,
  DEFAULT_MARGIN,
  BACKBONE_HEIGHT,
  STEM_BASE_HEIGHT,
  STEM_STACK_OFFSET,
  MARKER_RADIUS,
  MARKER_STROKE_WIDTH,
  AGGREGATION_THRESHOLD,
  MAX_STACK_DEPTH,
  MIN_OPACITY,
  MAX_OPACITY,
  DENSITY_THRESHOLD,
  MIN_MARKER_RADIUS,
  MAX_MARKER_RADIUS,
  calculateAggregatedRadius,
  calculateDynamicOpacity,
  determineRenderingMode,
  isClassificationVisible,
  isEffectTypeVisible,
} from './d3-lollipop/lollipop-helpers';
```

Then remove any names from that import list that the remaining composable body does not actually use (lint will flag them).

- [ ] **Step 5: Run the test and type-check to verify they pass**

```bash
cd app && npx vitest run src/composables/d3-lollipop/lollipop-helpers.spec.ts && npm run type-check
```

Expected: PASS, type-check clean.

- [ ] **Step 6: Commit**

```bash
git add app/src/composables/d3-lollipop/ app/src/composables/useD3Lollipop.ts
git commit -m "refactor(app): extract pure d3-lollipop helpers with unit tests (#346)"
```

---

### Task 4: d3-lollipop — split tooltip/render/export modules, move composable into the directory

**Files:**
- Create: `app/src/composables/d3-lollipop/lollipop-context.ts`
- Create: `app/src/composables/d3-lollipop/lollipop-tooltip.ts`
- Create: `app/src/composables/d3-lollipop/lollipop-render.ts`
- Create: `app/src/composables/d3-lollipop/lollipop-export.ts`
- Create: `app/src/composables/d3-lollipop/index.ts`
- Move+Modify: `app/src/composables/useD3Lollipop.ts` → `app/src/composables/d3-lollipop/useD3Lollipop.ts`
- Modify: `app/src/composables/index.ts` (re-export path only)

**Aliasing rule (critical):** the composable's mutable closure variables (`svg`, `mainGroup`, `xScale`, `xScaleOriginal`, `brush`, `tooltipDiv`, `currentData`, `currentFilterState`, `isTooltipLocked`, `lockedVariant`) become properties of ONE context object created inside `useD3Lollipop()`. Extracted functions take `ctx` as their first parameter and read/write `ctx.<prop>` — never destructure mutable props into locals that outlive a statement. This preserves the closure's mutation semantics exactly.

- [ ] **Step 1: Create the context type**

Create `app/src/composables/d3-lollipop/lollipop-context.ts`:

```typescript
// composables/d3-lollipop/lollipop-context.ts

import type * as d3 from 'd3';
import type { Ref } from 'vue';
import type { ProteinPlotData, ProcessedVariant, LollipopFilterState } from '@/types/protein';
import type { LollipopOptions, PlotMargin } from './useD3Lollipop';

/**
 * Shared mutable state for one lollipop plot instance. Created once per
 * useD3Lollipop() call; extracted modules receive it as `ctx` and mutate
 * its properties in place (same aliasing semantics as the original closure).
 */
export interface LollipopContext {
  svg: d3.Selection<SVGSVGElement, unknown, null, undefined> | null;
  mainGroup: d3.Selection<SVGGElement, unknown, null, undefined> | null;
  xScale: d3.ScaleLinear<number, number> | null;
  xScaleOriginal: d3.ScaleLinear<number, number> | null;
  brush: d3.BrushBehavior<unknown> | null;
  tooltipDiv: d3.Selection<HTMLDivElement, unknown, null, undefined> | null;
  currentData: ProteinPlotData | null;
  currentFilterState: LollipopFilterState | null;
  isTooltipLocked: boolean;
  lockedVariant: ProcessedVariant | null;
  // resolved options (immutable after creation)
  options: LollipopOptions;
  width: number;
  height: number;
  margin: PlotMargin;
  innerWidth: number;
  innerHeight: number;
  // reactive state shared with the component
  isInitialized: Ref<boolean>;
  isLoading: Ref<boolean>;
  currentZoomDomain: Ref<[number, number] | null>;
}
```

(Adjust the property list to exactly match the closure variables present in the file — the list above mirrors `useD3Lollipop.ts:208-233`.)

- [ ] **Step 2: Extract tooltip functions**

Create `app/src/composables/d3-lollipop/lollipop-tooltip.ts`. Move these closure functions verbatim, converting each to `export function <name>(ctx: LollipopContext, ...originalParams)` and rewriting references to closure variables as `ctx.<name>`:

| Function | Original location |
|---|---|
| `showTooltip` | useD3Lollipop.ts:305–384 |
| `hideTooltip` | useD3Lollipop.ts:389–392 |
| `dismissLockedTooltip` | useD3Lollipop.ts:397–403 |
| `showDomainTooltip` | useD3Lollipop.ts:408–451 |
| `showAggregatedTooltip` | useD3Lollipop.ts:537–599 |

Keep their existing imports (`PATHOGENICITY_COLORS`, `EFFECT_TYPE_COLORS`, helper constants from `./lollipop-helpers`).

- [ ] **Step 3: Extract render functions**

Create `app/src/composables/d3-lollipop/lollipop-render.ts` with the same `ctx`-first conversion:

| Function | Original location |
|---|---|
| `renderBackbone` | useD3Lollipop.ts:456–469 |
| `renderDomains` | useD3Lollipop.ts:474–532 |
| `renderVariants` | useD3Lollipop.ts:605–840 |
| `renderAxis` | useD3Lollipop.ts:845–861 |

`renderVariants` calls tooltip functions and the option callbacks: import the tooltip functions from `./lollipop-tooltip` and call them as `showTooltip(ctx, ...)`; option callbacks stay `ctx.options.onVariantClick?.(...)`.

- [ ] **Step 4: Extract export functions**

Create `app/src/composables/d3-lollipop/lollipop-export.ts` with `exportSVG` (useD3Lollipop.ts:1019–1035) and `exportPNG` (useD3Lollipop.ts:1041–1101), converted to `export function exportSVG(ctx: LollipopContext): string | null` and `export function exportPNG(ctx: LollipopContext, scale?: number): Promise<string | null>` (preserve the original default for `scale`).

- [ ] **Step 5: Move and slim the composable**

```bash
git mv app/src/composables/useD3Lollipop.ts app/src/composables/d3-lollipop/useD3Lollipop.ts
```

Then edit `d3-lollipop/useD3Lollipop.ts`:
- Keep: interface definitions (`PlotMargin`, `LollipopOptions`, `D3LollipopState`), `initializePlot`, `setupBrush`, `renderPlotInternal`, `renderPlot`, `resetZoom`, `cleanup`, lifecycle hooks (`onMounted`/`onBeforeUnmount`).
- Replace the individual closure `let` variables with one `const ctx: LollipopContext = { svg: null, mainGroup: null, ..., options, width, height, margin, innerWidth, innerHeight, isInitialized, isLoading, currentZoomDomain }` and rewrite remaining in-file references from bare names to `ctx.<name>`.
- The kept functions call extracted ones as `renderBackbone(ctx)`, `showTooltip(ctx, event, variant)`, `exportSVG(ctx)`, etc. The returned `D3LollipopState` object wraps them: `exportSVG: () => exportSVGModule(ctx)` (import with aliases to avoid name clashes, e.g. `import { exportSVG as exportSVGFrom } from './lollipop-export'`).
- Fix the `lollipop-helpers.ts` import of `PlotMargin` to `from './useD3Lollipop'` (same directory now).

- [ ] **Step 6: Create the barrel and rewire the public export**

Create `app/src/composables/d3-lollipop/index.ts`:

```typescript
export { useD3Lollipop } from './useD3Lollipop';
export type { LollipopOptions, D3LollipopState, PlotMargin } from './useD3Lollipop';
```

In `app/src/composables/index.ts` change the two lines (currently ~106–107):

```typescript
export { useD3Lollipop } from './d3-lollipop';
export type { LollipopOptions, D3LollipopState, PlotMargin } from './d3-lollipop';
```

- [ ] **Step 7: Verify**

```bash
cd app && npm run type-check && npx vitest run src/composables/d3-lollipop/lollipop-helpers.spec.ts && npm run lint -- --no-fix src/composables/d3-lollipop src/composables/index.ts 2>/dev/null || npx eslint src/composables/d3-lollipop src/composables/index.ts
```

Expected: type-check clean, helpers spec passes, no new lint errors. Also confirm every new file is under 600 lines:

```bash
wc -l app/src/composables/d3-lollipop/*.ts
```

Expected: each file < 600.

- [ ] **Step 8: Commit**

```bash
git add app/src/composables/
git commit -m "refactor(app): split useD3Lollipop into d3-lollipop module directory (#346)"
```

---

### Task 5: TablesLogs — extract LogDeleteModal child component

**Files:**
- Create: `app/src/components/small/LogDeleteModal.vue`
- Modify: `app/src/components/tables/TablesLogs.vue` (template 419–477, data 703–708, methods 1105–1134)
- Test (existing, must stay green): `app/src/components/tables/TablesLogs.spec.ts`

**Contract:** the spec drives `vm.deleteMode = 'all'; await vm.deleteLogs()` directly (TablesLogs.spec.ts:263-264), so `deleteMode`, `isDeleting`, and `deleteLogs()` STAY on the parent. The child owns only presentation + the DELETE-confirmation text state, with `v-model` for visibility, `v-model:delete-mode`, and a `confirm` emit.

- [ ] **Step 1: Create the child component**

Create `app/src/components/small/LogDeleteModal.vue`:

```vue
<template>
  <BModal
    :model-value="modelValue"
    title="Delete Logs"
    header-bg-variant="danger"
    header-text-variant="light"
    centered
    @update:model-value="$emit('update:modelValue', $event)"
    @hidden="onHidden"
  >
    <div class="text-center mb-3">
      <i class="bi bi-exclamation-triangle-fill text-danger fs-1" />
    </div>

    <!-- Delete mode selection -->
    <div class="mb-3">
      <label class="form-label fw-semibold">What to delete:</label>
      <BFormSelect
        :model-value="deleteMode"
        class="mb-2"
        @update:model-value="$emit('update:deleteMode', $event)"
      >
        <option value="all">All logs ({{ totalRows.toLocaleString() }} entries)</option>
        <option value="3">Logs older than 3 days</option>
        <option value="7">Logs older than 7 days</option>
        <option value="14">Logs older than 14 days</option>
        <option value="30">Logs older than 30 days</option>
      </BFormSelect>
    </div>

    <p class="text-center">
      <strong>Warning:</strong>
      <span v-if="deleteMode === 'all'">
        This will permanently delete all {{ totalRows.toLocaleString() }} log entries.
      </span>
      <span v-else> This will permanently delete logs older than {{ deleteMode }} days. </span>
    </p>
    <p class="text-center text-muted small">
      This action cannot be undone. Type <code>DELETE</code> to confirm.
    </p>
    <BFormInput
      v-model="deleteConfirmText"
      placeholder="Type DELETE to confirm"
      class="text-center"
      :state="deleteConfirmText === 'DELETE' ? true : deleteConfirmText ? false : null"
    />
    <template #footer>
      <BButton variant="secondary" @click="$emit('update:modelValue', false)"> Cancel </BButton>
      <BButton
        variant="danger"
        :disabled="deleteConfirmText !== 'DELETE' || isDeleting"
        @click="$emit('confirm')"
      >
        <BSpinner v-if="isDeleting" small class="me-1" />
        {{
          isDeleting ? 'Deleting...' : deleteMode === 'all' ? 'Delete All Logs' : `Delete Old Logs`
        }}
      </BButton>
    </template>
  </BModal>
</template>

<script>
export default {
  name: 'LogDeleteModal',
  props: {
    modelValue: { type: Boolean, default: false },
    deleteMode: { type: String, default: 'all' },
    totalRows: { type: Number, default: 0 },
    isDeleting: { type: Boolean, default: false },
  },
  emits: ['update:modelValue', 'update:deleteMode', 'confirm'],
  data() {
    return { deleteConfirmText: '' };
  },
  methods: {
    onHidden() {
      this.deleteConfirmText = '';
      this.$emit('update:deleteMode', 'all');
    },
  },
};
</script>
```

NOTE: match the existing component style — if other `components/small/*.vue` register `BModal`/`BButton` etc. explicitly or rely on global registration, copy whatever `LogDetailDrawer.vue` does (check its `<script>` imports first and mirror them).

- [ ] **Step 2: Replace the inline modal in TablesLogs.vue**

Replace template lines 419–477 (`<BModal v-if="showDeleteModal" ...>...</BModal>`) with:

```vue
      <!-- Delete Logs Confirmation Modal -->
      <LogDeleteModal
        v-if="showDeleteModal"
        v-model="showDeleteModal"
        v-model:delete-mode="deleteMode"
        :total-rows="totalRows"
        :is-deleting="isDeleting"
        @confirm="deleteLogs"
      />
```

In `<script>`: import and register `LogDeleteModal` next to `LogDetailDrawer` (import from `@/components/small/LogDeleteModal.vue`; add to `components`); remove `deleteConfirmText` from `data()` (keep `showDeleteModal`, `deleteMode`, `isDeleting`); delete the `resetDeleteModal()` method and the `this.resetDeleteModal()` call inside `deleteLogs()` (the child resets itself on hidden); keep the rest of `deleteLogs()` unchanged.

- [ ] **Step 3: Run the existing spec**

```bash
cd app && npx vitest run src/components/tables/TablesLogs.spec.ts
```

Expected: PASS unchanged (it drives `vm.deleteMode`/`vm.deleteLogs()` which still exist on the parent).

- [ ] **Step 4: Type-check and lint**

```bash
cd app && npm run type-check && npx eslint src/components/small/LogDeleteModal.vue src/components/tables/TablesLogs.vue
```

Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add app/src/components/small/LogDeleteModal.vue app/src/components/tables/TablesLogs.vue
git commit -m "refactor(app): extract LogDeleteModal from TablesLogs (#346)"
```

---

### Task 6: TablesLogs — move normalizeSelectOptions to the formatters module

> **As shipped:** during execution the function turned out to be duplicated across 8
> components, so it was centralized as `normalizeSelectOptions` in a new shared
> `app/src/utils/selectOptions.ts` (with `app/src/utils/__tests__/selectOptions.spec.ts`)
> instead of the log-specific `logTableFormatters.ts` below. TablesLogs delegates to it;
> the 7 remaining duplicate copies migrate in WP2/WP3 (#395/#396).

**Files:**
- Modify: `app/src/components/tables/logTableFormatters.ts`
- Modify: `app/src/components/tables/TablesLogs.vue` (method at 1086–1094)

- [ ] **Step 1: Add the function to logTableFormatters.ts**

Append to `app/src/components/tables/logTableFormatters.ts` (match the file's existing typing style):

```typescript
/**
 * Normalize select options for BFormSelect (replacement for treeselect normalizer).
 */
export function normalizeLogSelectOptions(
  options: unknown,
): Array<{ value: unknown; text: unknown }> {
  if (!options || !Array.isArray(options)) return [];
  return options.map((opt) => {
    if (typeof opt === 'object' && opt !== null) {
      const o = opt as { id?: unknown; value?: unknown; label?: unknown; text?: unknown };
      return { value: o.id || o.value, text: o.label || o.text || o.id };
    }
    return { value: opt, text: opt };
  });
}
```

- [ ] **Step 2: Use it from TablesLogs.vue**

Add `normalizeLogSelectOptions` to the existing `./logTableFormatters` import in TablesLogs.vue; replace the `normalizeSelectOptions(options)` method body with `return normalizeLogSelectOptions(options);` ONLY if the template references `normalizeSelectOptions`; if nothing in the template/script calls it (check with grep below), delete the method entirely.

```bash
grep -n "normalizeSelectOptions" app/src/components/tables/TablesLogs.vue
```

- [ ] **Step 3: Verify**

```bash
cd app && npx vitest run src/components/tables/TablesLogs.spec.ts && npm run type-check
```

Expected: PASS, clean.

- [ ] **Step 4: Commit**

```bash
git add app/src/components/tables/logTableFormatters.ts app/src/components/tables/TablesLogs.vue
git commit -m "refactor(app): move select-option normalization into logTableFormatters (#346)"
```

---

### Task 7: Final baseline rewrite + full verification

**Files:**
- Modify: `scripts/code-quality-file-size-baseline.tsv`

- [ ] **Step 1: Rewrite the baseline and inspect**

```bash
bash scripts/code-quality-audit.sh --write-baseline
git diff scripts/code-quality-file-size-baseline.tsv
```

Expected: `app/src/composables/useD3Lollipop.ts` entry GONE (path moved; every `d3-lollipop/*.ts` file is under 600 so no replacement entries); `app/src/components/tables/TablesLogs.vue` entry decreased (~1221 → ~1100). No upward changes, no new entries.

- [ ] **Step 2: Full frontend verification**

```bash
make code-quality-audit && make lint-app && cd app && npm run type-check && npm run test:unit
```

Expected: all pass. (If pre-existing unrelated test failures appear, compare against `git stash`-free master state before concluding — only failures introduced by this branch block.)

- [ ] **Step 3: Commit**

```bash
git add scripts/code-quality-file-size-baseline.tsv
git commit -m "chore(quality): ratchet baseline down after sprint-1 refactors (#346)"
```

---

### Task 8: Create WP sub-issues and update #346

**Files:** none (GitHub only)

- [ ] **Step 1: Create one sub-issue per workpackage WP1–WP9**

For each WP in the spec's workpackage table (`.planning/superpowers/specs/2026-06-11-continuous-refactor-346-workpackages-design.md`), run `gh issue create` with title `Refactor WP<N> (<theme>): <files summary> (#346)` and a body containing: the WP's file list with current line counts, the extraction strategy from the spec, the definition of done (behavior preserved; baseline only moves down; `make code-quality-audit` + targeted checks pass), and `Part of #346.`

Example for WP1:

```bash
gh issue create --title "Refactor WP1 (D3/visualization frontend) toward 600-line ceiling (#346)" --body "$(cat <<'EOF'
Part of #346. Files (current lines):
- app/src/components/gene/GeneStructurePlotWithVariants.vue (1306)
- app/src/composables/useD3Lollipop.ts (1125) — split in Sprint 1 (refactor/346-sprint-1)
- app/src/components/gene/GenomicVisualizationTabs.vue (748)
- app/src/components/gene/ProteinDomainLollipopPlot.vue (713)
- app/src/components/gene/VariantPanel.vue (671)
- app/src/composables/useCytoscape.ts (603)

Strategy: split composables into module directories (helpers/scales/tooltip/render/brush-zoom) keeping public API via barrel export; unify shared tooltip/export logic across the D3 plots.

Definition of done: behavior preserved; baseline entries only move down (scripts/code-quality-audit.sh --write-baseline); make code-quality-audit, make lint-app, npm run type-check, targeted Vitest pass.

See .planning/superpowers/specs/2026-06-11-continuous-refactor-346-workpackages-design.md (WP1).
EOF
)"
```

Repeat for WP2–WP9 with their file lists and strategies from the spec.

- [ ] **Step 2: Comment on #346 with the plan**

```bash
gh issue comment 346 --body "Structured into workpackages WP1–WP9 with sprint plan: see .planning/superpowers/specs/2026-06-11-continuous-refactor-346-workpackages-design.md and sub-issues <list the created issue numbers>. Sprint 1 (ratchet tightening + useD3Lollipop split + TablesLogs extraction) is in PR <fill after Task 9>."
```

(Post this comment after Task 9 if you prefer to include the PR link in one shot.)

---

### Task 9: Push branch and open the Sprint 1 PR

- [ ] **Step 1: Pre-push gate**

```bash
make pre-commit
```

Expected: passes. If an R-suite step is unrelated-flaky, confirm the failure also occurs on master before proceeding.

- [ ] **Step 2: Push and create PR**

```bash
git push -u origin refactor/346-sprint-1
gh pr create --title "refactor: #346 Sprint 1 — ratchet tightening, d3-lollipop split, TablesLogs extraction" --body "$(cat <<'EOF'
## Summary
Sprint 1 of the #346 continuous refactor (see .planning/superpowers/specs/2026-06-11-continuous-refactor-346-workpackages-design.md):
- WP0: ratchet baseline tightened to current actuals (3 entries removed, ~10 tightened)
- WP1: useD3Lollipop.ts (1125 lines) split into composables/d3-lollipop/ modules, public API unchanged, new unit tests for pure helpers
- WP2: TablesLogs.vue delete-confirmation modal extracted to LogDeleteModal.vue; select-option normalization moved to logTableFormatters

Behavior-preserving only; baseline entries only move down.

## Verification
- make code-quality-audit ✓
- make lint-app ✓
- cd app && npm run type-check ✓
- cd app && npm run test:unit (TablesLogs.spec.ts + new lollipop-helpers.spec.ts) ✓

Part of #346.
EOF
)"
```

---

## Self-review notes

- Spec coverage: WP0 (Task 2/7), Sprint-1 lollipop split (Tasks 3–4), Sprint-1 TablesLogs extraction (Tasks 5–6), sub-issue tracking (Task 8), PR (Task 9). S2+ sprints intentionally out of scope.
- Type consistency: `LollipopContext` property list mirrors useD3Lollipop.ts:208-233; `normalizeLogSelectOptions` name used consistently in Task 6.
- Known judgment points for the executor: exact import style in LogDeleteModal.vue (mirror LogDetailDrawer.vue), unused-constant pruning in Task 3 Step 4, and `PlotMargin` import direction in Task 4 Step 5.

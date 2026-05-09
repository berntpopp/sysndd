# Table Modernization Hybrid Responsive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modernize the shared table experience with a dense desktop table shell and compact mobile record rows for curation comparisons, entities, genes, and panels.

**Architecture:** Add a shared `app/src/components/table/` shell, loader, and mobile-list wrapper, then migrate the four target views onto it without changing data fetching or API timing. Keep desktop tables intact and render page-specific mobile rows below the `md` breakpoint instead of relying on Bootstrap stacked table output.

**Tech Stack:** Vue 3, TypeScript, Bootstrap Vue Next, Vite, Vitest, Playwright, Lighthouse.

---

## File Structure

- Create: `app/src/components/table/TableShell.vue`
  - Shared frame for title, metadata, actions, toolbar, loading, desktop table, and mobile list.
- Create: `app/src/components/table/TableLoadingState.vue`
  - Skeleton loader with stable height for table and mobile list loading.
- Create: `app/src/components/table/MobileTableList.vue`
  - Wrapper for mobile rows, empty states, and pagination-adjacent spacing.
- Create: `app/src/components/analysis/CurationComparisonMobileRows.vue`
  - Compact mobile rows for `/CurationComparisons/Table`.
- Create: `app/src/components/tables/EntitiesMobileRows.vue`
  - Compact mobile rows for entity records.
- Create: `app/src/components/tables/GenesMobileRows.vue`
  - Compact mobile rows for gene records.
- Create: `app/src/components/panels/PanelsMobileRows.vue`
  - Compact mobile rows for panel gene records.
- Modify: `app/src/components/table/GenericTable.vue`
  - Add opt-out for Bootstrap stacked mode.
- Modify: `app/src/components/analysis/AnalysesCurationComparisonsTable.vue`
  - Use `TableShell`, desktop table, and mobile comparison rows.
- Modify: `app/src/components/tables/TablesEntities.vue`
  - Use `TableShell`, desktop `GenericTable`, and mobile entity rows.
- Modify: `app/src/components/tables/TablesGenes.vue`
  - Use `TableShell`, desktop `BTable`, and mobile gene rows.
- Modify: `app/src/components/panels/PanelsTable.vue`
  - Use `TableShell`, desktop `BTable`, and mobile panel rows.
- Modify: `app/src/composables/useExcelExport.ts`
  - Lazy-load `exceljs` only when exporting.
- Test: `app/src/components/table/TableShell.spec.ts`
- Test: `app/src/components/table/GenericTable.spec.ts`
- Test: `app/src/components/tables/EntitiesMobileRows.spec.ts`
- Test: `app/src/components/tables/GenesMobileRows.spec.ts`
- Test: `app/src/components/panels/PanelsMobileRows.spec.ts`
- Test: `app/src/components/analysis/CurationComparisonMobileRows.spec.ts`
- Test: `app/tests/e2e/tables-responsive.spec.ts`

## Guardrails

- Do not change API calls, endpoint paths, query parameters, SWR composables, cache store behavior, or request timing.
- Keep existing table sort, filter, pagination, copy, download, and row expansion behavior.
- Do not remove columns from desktop tables.
- Avoid refactoring unrelated table consumers.
- Do not introduce a new table library.
- Use `apply_patch` for manual edits.

### Task 1: Shared Table Shell and Loader

**Files:**
- Create: `app/src/components/table/TableShell.vue`
- Create: `app/src/components/table/TableLoadingState.vue`
- Create: `app/src/components/table/TableShell.spec.ts`

- [ ] **Step 1: Write failing TableShell tests**

Create `app/src/components/table/TableShell.spec.ts`:

```ts
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import TableShell from './TableShell.vue'

describe('TableShell', () => {
  it('renders title, description, meta, actions, toolbar, and body slots', () => {
    const wrapper = mount(TableShell, {
      props: {
        title: 'Entities',
        description: 'Gene-inheritance-disease records',
        meta: '2,605 records',
      },
      slots: {
        actions: '<button type="button">Export</button>',
        toolbar: '<label>Search<input aria-label="Search entities" /></label>',
        default: '<table><tbody><tr><td>ARID1B</td></tr></tbody></table>',
      },
    })

    expect(wrapper.text()).toContain('Entities')
    expect(wrapper.text()).toContain('Gene-inheritance-disease records')
    expect(wrapper.text()).toContain('2,605 records')
    expect(wrapper.find('button').text()).toBe('Export')
    expect(wrapper.find('input[aria-label="Search entities"]').exists()).toBe(true)
    expect(wrapper.find('td').text()).toBe('ARID1B')
  })

  it('uses the loading slot when loading is true', () => {
    const wrapper = mount(TableShell, {
      props: {
        title: 'Genes',
        loading: true,
      },
      slots: {
        loading: '<div data-testid="loading">Loading genes</div>',
        default: '<div data-testid="body">Loaded</div>',
      },
    })

    expect(wrapper.find('[data-testid="loading"]').exists()).toBe(true)
    expect(wrapper.find('[data-testid="body"]').exists()).toBe(false)
  })
})
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
cd app && npx vitest run src/components/table/TableShell.spec.ts
```

Expected: fail because `TableShell.vue` does not exist.

- [ ] **Step 3: Implement `TableLoadingState.vue`**

Create `app/src/components/table/TableLoadingState.vue`:

```vue
<template>
  <div
    class="table-loading-state"
    :class="`table-loading-state--${mode}`"
    role="status"
    aria-live="polite"
    :aria-label="label"
  >
    <span class="visually-hidden">{{ label }}</span>
    <div v-for="row in rows" :key="row" class="table-loading-state__row">
      <span class="table-loading-state__cell table-loading-state__cell--primary" />
      <span class="table-loading-state__cell" />
      <span class="table-loading-state__cell" />
      <span class="table-loading-state__cell table-loading-state__cell--short" />
    </div>
  </div>
</template>

<script setup lang="ts">
withDefaults(
  defineProps<{
    label?: string
    rows?: number
    mode?: 'table' | 'cards'
  }>(),
  {
    label: 'Loading table data',
    rows: 8,
    mode: 'table',
  },
)
</script>

<style scoped>
.table-loading-state {
  display: grid;
  gap: 0.5rem;
}

.table-loading-state__row {
  display: grid;
  grid-template-columns: minmax(7rem, 1.4fr) repeat(2, minmax(5rem, 1fr)) minmax(4rem, 0.6fr);
  gap: 0.75rem;
  min-height: 2.75rem;
  align-items: center;
  padding: 0.625rem 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
  background: #fff;
}

.table-loading-state__cell {
  display: block;
  height: 0.75rem;
  border-radius: 999px;
  background: linear-gradient(90deg, #eef2f7 25%, #f8fafc 37%, #eef2f7 63%);
  background-size: 400% 100%;
  animation: table-loading-shimmer 1.4s ease infinite;
}

.table-loading-state__cell--primary {
  height: 0.95rem;
}

.table-loading-state__cell--short {
  width: 65%;
}

.table-loading-state--cards .table-loading-state__row {
  grid-template-columns: 1fr;
  min-height: 6rem;
}

@keyframes table-loading-shimmer {
  0% {
    background-position: 100% 0;
  }

  100% {
    background-position: 0 0;
  }
}

@media (max-width: 767.98px) {
  .table-loading-state__row {
    grid-template-columns: 1fr;
    min-height: 5.5rem;
  }
}
</style>
```

- [ ] **Step 4: Implement `TableShell.vue`**

Create `app/src/components/table/TableShell.vue`:

```vue
<template>
  <section class="table-shell" :aria-busy="loading ? 'true' : 'false'">
    <header class="table-shell__header">
      <div class="table-shell__heading">
        <div class="table-shell__title-line">
          <h2 class="table-shell__title">{{ title }}</h2>
          <span v-if="meta" class="table-shell__meta">{{ meta }}</span>
        </div>
        <p v-if="description" class="table-shell__description">{{ description }}</p>
      </div>
      <div v-if="$slots.actions" class="table-shell__actions">
        <slot name="actions" />
      </div>
    </header>

    <div v-if="$slots.toolbar" class="table-shell__toolbar">
      <slot name="toolbar" />
    </div>

    <div class="table-shell__body">
      <slot v-if="loading" name="loading">
        <TableLoadingState />
      </slot>
      <slot v-else />
    </div>
  </section>
</template>

<script setup lang="ts">
import TableLoadingState from './TableLoadingState.vue'

defineProps<{
  title: string
  description?: string
  meta?: string
  loading?: boolean
}>()
</script>

<style scoped>
.table-shell {
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 0.75rem;
  background: #fff;
  box-shadow: 0 0.5rem 1.5rem rgba(15, 23, 42, 0.04);
  overflow: clip;
}

.table-shell__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 1rem;
  padding: 1rem 1rem 0.75rem;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
}

.table-shell__heading {
  min-width: 0;
}

.table-shell__title-line {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.table-shell__title {
  margin: 0;
  color: #111827;
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.table-shell__meta {
  border-radius: 999px;
  background: #eef2ff;
  color: #3730a3;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1;
  padding: 0.35rem 0.55rem;
}

.table-shell__description {
  max-width: 58rem;
  margin: 0.35rem 0 0;
  color: #475569;
  font-size: 0.875rem;
  line-height: 1.35;
}

.table-shell__actions {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.4rem;
}

.table-shell__toolbar {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  background: #f8fafc;
}

.table-shell__body {
  padding: 0.75rem 1rem 1rem;
}

@media (max-width: 767.98px) {
  .table-shell__header {
    display: grid;
  }

  .table-shell__actions {
    justify-content: flex-start;
  }

  .table-shell__body,
  .table-shell__toolbar {
    padding-inline: 0.75rem;
  }
}
</style>
```

- [ ] **Step 5: Run the TableShell test**

Run:

```bash
cd app && npx vitest run src/components/table/TableShell.spec.ts
```

Expected: pass.

- [ ] **Step 6: Commit Task 1**

Run:

```bash
git add app/src/components/table/TableShell.vue app/src/components/table/TableLoadingState.vue app/src/components/table/TableShell.spec.ts
git commit -m "feat: add shared table shell"
```

### Task 2: GenericTable Responsive Opt-Out

**Files:**
- Modify: `app/src/components/table/GenericTable.vue`
- Test: `app/src/components/table/GenericTable.spec.ts`

- [ ] **Step 1: Write failing GenericTable test**

Create or extend `app/src/components/table/GenericTable.spec.ts`:

```ts
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import GenericTable from './GenericTable.vue'

const fields = [{ key: 'symbol', label: 'Gene', sortable: true }]
const items = [{ symbol: 'ARID1B' }]

describe('GenericTable responsive mode', () => {
  it('keeps the existing stacked md mode by default', () => {
    const wrapper = mount(GenericTable, {
      props: {
        items,
        fields,
        sortBy: 'symbol',
        sortDesc: false,
        loading: false,
      },
      global: {
        stubs: {
          BTable: {
            props: ['stacked'],
            template: '<div data-testid="b-table" :data-stacked="stacked"><slot /></div>',
          },
        },
      },
    })

    expect(wrapper.find('[data-testid="b-table"]').attributes('data-stacked')).toBe('md')
  })

  it('can disable Bootstrap stacked output for hybrid mobile layouts', () => {
    const wrapper = mount(GenericTable, {
      props: {
        items,
        fields,
        sortBy: 'symbol',
        sortDesc: false,
        loading: false,
        stackedMode: false,
      },
      global: {
        stubs: {
          BTable: {
            props: ['stacked'],
            template: '<div data-testid="b-table" :data-stacked="String(stacked)"><slot /></div>',
          },
        },
      },
    })

    expect(wrapper.find('[data-testid="b-table"]').attributes('data-stacked')).toBe('false')
  })
})
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
cd app && npx vitest run src/components/table/GenericTable.spec.ts
```

Expected: fail because `stackedMode` is not implemented.

- [ ] **Step 3: Add the `stackedMode` prop**

Modify `app/src/components/table/GenericTable.vue` script props:

```ts
const props = withDefaults(
  defineProps<{
    items: Record<string, unknown>[]
    fields: TableField[]
    sortBy?: string
    sortDesc?: boolean
    loading?: boolean
    emptyText?: string
    stackedMode?: false | 'sm' | 'md' | 'lg' | 'xl'
  }>(),
  {
    sortBy: '',
    sortDesc: false,
    loading: false,
    emptyText: 'No records found',
    stackedMode: 'md',
  },
)
```

Update the `BTable` binding:

```vue
<BTable
  :items="items"
  :fields="fields"
  :busy="loading"
  :stacked="props.stackedMode"
  head-variant="light"
  show-empty
  fixed
  hover
  sort-icon-left
  no-local-sorting
  class="entities-table"
  :sort-by="sortBy"
  :sort-desc="sortDesc"
  @sort-changed="$emit('sort-changed', $event)"
>
```

- [ ] **Step 4: Run GenericTable tests**

Run:

```bash
cd app && npx vitest run src/components/table/GenericTable.spec.ts
```

Expected: pass.

- [ ] **Step 5: Commit Task 2**

Run:

```bash
git add app/src/components/table/GenericTable.vue app/src/components/table/GenericTable.spec.ts
git commit -m "feat: allow generic table stacked opt out"
```

### Task 3: Shared Mobile List and Curation Comparison Rows

**Files:**
- Create: `app/src/components/table/MobileTableList.vue`
- Create: `app/src/components/analysis/CurationComparisonMobileRows.vue`
- Create: `app/src/components/analysis/CurationComparisonMobileRows.spec.ts`
- Modify: `app/src/components/analysis/AnalysesCurationComparisonsTable.vue`

- [ ] **Step 1: Write failing curation mobile rows test**

Create `app/src/components/analysis/CurationComparisonMobileRows.spec.ts`:

```ts
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import CurationComparisonMobileRows from './CurationComparisonMobileRows.vue'

describe('CurationComparisonMobileRows', () => {
  it('renders a dense source status strip and expandable source details', async () => {
    const wrapper = mount(CurationComparisonMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            sysndd: true,
            clingen: false,
            panelapp: true,
            gencc: false,
            omim: true,
            orphanet: false,
            decipher: true,
          },
        ],
      },
    })

    expect(wrapper.text()).toContain('ARID1B')
    expect(wrapper.findAll('[data-testid="source-chip"]')).toHaveLength(7)
    expect(wrapper.text()).not.toContain('ClinGen')

    await wrapper.get('button[aria-expanded="false"]').trigger('click')

    expect(wrapper.get('button').attributes('aria-expanded')).toBe('true')
    expect(wrapper.text()).toContain('ClinGen')
    expect(wrapper.text()).toContain('Not present')
  })
})
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
cd app && npx vitest run src/components/analysis/CurationComparisonMobileRows.spec.ts
```

Expected: fail because the component does not exist.

- [ ] **Step 3: Implement `MobileTableList.vue`**

Create `app/src/components/table/MobileTableList.vue`:

```vue
<template>
  <div class="mobile-table-list" role="list" :aria-label="label">
    <p v-if="!items.length" class="mobile-table-list__empty">{{ emptyText }}</p>
    <slot v-for="(item, index) in items" v-else :key="getKey(item, index)" :item="item" :index="index" />
  </div>
</template>

<script setup lang="ts" generic="T extends Record<string, unknown>">
const props = withDefaults(
  defineProps<{
    items: T[]
    label: string
    emptyText?: string
    itemKey?: keyof T | ((item: T, index: number) => string | number)
  }>(),
  {
    emptyText: 'No records found',
  },
)

function getKey(item: T, index: number): string | number {
  if (typeof props.itemKey === 'function') return props.itemKey(item, index)
  if (props.itemKey && item[props.itemKey] != null) return String(item[props.itemKey])
  return index
}
</script>

<style scoped>
.mobile-table-list {
  display: grid;
  gap: 0.625rem;
}

.mobile-table-list__empty {
  margin: 0;
  padding: 1rem;
  border: 1px dashed rgba(15, 23, 42, 0.2);
  border-radius: 0.5rem;
  color: #64748b;
  background: #f8fafc;
}
</style>
```

- [ ] **Step 4: Implement curation comparison mobile rows**

Create `app/src/components/analysis/CurationComparisonMobileRows.vue`:

```vue
<template>
  <MobileTableList :items="items" label="Curation comparison records" :item-key="rowKey">
    <template #default="{ item, index }">
      <article class="comparison-mobile-row" role="listitem">
        <div class="comparison-mobile-row__main">
          <strong class="comparison-mobile-row__symbol">{{ getText(item, 'symbol') }}</strong>
          <button
            class="btn btn-sm btn-outline-secondary comparison-mobile-row__toggle"
            type="button"
            :aria-expanded="expandedIndex === index ? 'true' : 'false'"
            @click="expandedIndex = expandedIndex === index ? null : index"
          >
            Details
          </button>
        </div>
        <div class="comparison-mobile-row__sources" aria-label="Source presence">
          <span
            v-for="source in sources"
            :key="source.key"
            data-testid="source-chip"
            class="comparison-mobile-row__source-chip"
            :class="{ 'comparison-mobile-row__source-chip--present': Boolean(item[source.key]) }"
            :title="`${source.label}: ${Boolean(item[source.key]) ? 'Present' : 'Not present'}`"
          >
            {{ source.short }}
          </span>
        </div>
        <dl v-if="expandedIndex === index" class="comparison-mobile-row__details">
          <template v-for="source in sources" :key="source.key">
            <dt>{{ source.label }}</dt>
            <dd>{{ Boolean(item[source.key]) ? 'Present' : 'Not present' }}</dd>
          </template>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import MobileTableList from '@/components/table/MobileTableList.vue'

type ComparisonRow = Record<string, unknown>

defineProps<{
  items: ComparisonRow[]
}>()

const expandedIndex = ref<number | null>(null)

const sources = [
  { key: 'sysndd', label: 'SysNDD', short: 'S' },
  { key: 'clingen', label: 'ClinGen', short: 'C' },
  { key: 'panelapp', label: 'PanelApp', short: 'P' },
  { key: 'gencc', label: 'GenCC', short: 'G' },
  { key: 'omim', label: 'OMIM', short: 'O' },
  { key: 'orphanet', label: 'Orphanet', short: 'Or' },
  { key: 'decipher', label: 'DECIPHER', short: 'D' },
]

function rowKey(item: ComparisonRow, index: number): string {
  return `${getText(item, 'symbol') || 'row'}-${index}`
}

function getText(item: ComparisonRow, key: string): string {
  const value = item[key]
  return typeof value === 'string' || typeof value === 'number' ? String(value) : ''
}
</script>

<style scoped>
.comparison-mobile-row {
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 0.625rem;
  background: #fff;
}

.comparison-mobile-row__main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.comparison-mobile-row__symbol {
  min-width: 0;
  color: #111827;
  font-size: 0.95rem;
}

.comparison-mobile-row__sources {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.55rem;
}

.comparison-mobile-row__source-chip {
  min-width: 1.75rem;
  border: 1px solid #cbd5e1;
  border-radius: 999px;
  color: #64748b;
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1;
  padding: 0.3rem 0.4rem;
  text-align: center;
}

.comparison-mobile-row__source-chip--present {
  border-color: #15803d;
  color: #166534;
  background: #dcfce7;
}

.comparison-mobile-row__details {
  display: grid;
  grid-template-columns: minmax(7rem, 1fr) auto;
  gap: 0.35rem 0.75rem;
  margin: 0.75rem 0 0;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
  font-size: 0.84rem;
}

.comparison-mobile-row__details dt,
.comparison-mobile-row__details dd {
  margin: 0;
}
</style>
```

- [ ] **Step 5: Run the mobile row test**

Run:

```bash
cd app && npx vitest run src/components/analysis/CurationComparisonMobileRows.spec.ts
```

Expected: pass.

- [ ] **Step 6: Wire curation comparisons to TableShell**

In `app/src/components/analysis/AnalysesCurationComparisonsTable.vue`:

- Import `TableShell`, `TableLoadingState`, and `CurationComparisonMobileRows`.
- Wrap the existing header/actions/toolbar/table in `TableShell`.
- Keep the existing `GenericTable` and pass `:stacked-mode="false"`.
- Add Bootstrap utility classes so desktop and mobile are mutually exclusive:

```vue
<div class="d-none d-md-block">
  <GenericTable
    :items="tableItems"
    :fields="tableFields"
    :loading="loading"
    :stacked-mode="false"
    @sort-changed="onSortChanged"
  />
</div>
<div class="d-md-none">
  <CurationComparisonMobileRows :items="tableItems" />
</div>
```

- Give help buttons explicit labels:

```vue
<BButton aria-label="Show curation comparison table help" />
```

- [ ] **Step 7: Run focused tests**

Run:

```bash
cd app && npx vitest run src/components/analysis/CurationComparisonMobileRows.spec.ts src/components/table/TableShell.spec.ts src/components/table/GenericTable.spec.ts
```

Expected: pass.

- [ ] **Step 8: Commit Task 3**

Run:

```bash
git add app/src/components/table/MobileTableList.vue app/src/components/analysis/CurationComparisonMobileRows.vue app/src/components/analysis/CurationComparisonMobileRows.spec.ts app/src/components/analysis/AnalysesCurationComparisonsTable.vue
git commit -m "feat: add responsive curation comparison rows"
```

### Task 4: Entities and Genes Mobile Rows

**Files:**
- Create: `app/src/components/tables/EntitiesMobileRows.vue`
- Create: `app/src/components/tables/EntitiesMobileRows.spec.ts`
- Create: `app/src/components/tables/GenesMobileRows.vue`
- Create: `app/src/components/tables/GenesMobileRows.spec.ts`
- Modify: `app/src/components/tables/TablesEntities.vue`
- Modify: `app/src/components/tables/TablesGenes.vue`

- [ ] **Step 1: Write failing entity mobile row test**

Create `app/src/components/tables/EntitiesMobileRows.spec.ts`:

```ts
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import EntitiesMobileRows from './EntitiesMobileRows.vue'

describe('EntitiesMobileRows', () => {
  it('renders entity, gene, disease, inheritance, and compact status chips', async () => {
    const wrapper = mount(EntitiesMobileRows, {
      props: {
        items: [
          {
            entity_id: 57,
            symbol: 'ARID1B',
            disease_name: 'Coffin-Siris syndrome',
            inheritance: 'AD',
            category: 'Definitive',
            ndd: 'Yes',
          },
        ],
      },
    })

    expect(wrapper.text()).toContain('Entity 57')
    expect(wrapper.text()).toContain('ARID1B')
    expect(wrapper.text()).toContain('Coffin-Siris syndrome')
    expect(wrapper.text()).toContain('AD')
    expect(wrapper.findAll('[data-testid="entity-chip"]').length).toBeGreaterThanOrEqual(2)

    await wrapper.get('button[aria-expanded="false"]').trigger('click')
    expect(wrapper.get('button').attributes('aria-expanded')).toBe('true')
  })
})
```

- [ ] **Step 2: Write failing gene mobile row test**

Create `app/src/components/tables/GenesMobileRows.spec.ts`:

```ts
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import GenesMobileRows from './GenesMobileRows.vue'

describe('GenesMobileRows', () => {
  it('renders gene, entity count, inheritance, category, and details toggle', async () => {
    const wrapper = mount(GenesMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            gene_name: 'AT-rich interaction domain 1B',
            inheritance: 'AD',
            category: 'Definitive',
            ndd: 'Yes',
            entities_count: 3,
          },
        ],
      },
    })

    expect(wrapper.text()).toContain('ARID1B')
    expect(wrapper.text()).toContain('3 entities')
    expect(wrapper.text()).toContain('AT-rich interaction domain 1B')
    expect(wrapper.text()).toContain('Definitive')

    await wrapper.get('button[aria-expanded="false"]').trigger('click')
    expect(wrapper.get('button').attributes('aria-expanded')).toBe('true')
  })
})
```

- [ ] **Step 3: Run failing tests**

Run:

```bash
cd app && npx vitest run src/components/tables/EntitiesMobileRows.spec.ts src/components/tables/GenesMobileRows.spec.ts
```

Expected: fail because the components do not exist.

- [ ] **Step 4: Implement `EntitiesMobileRows.vue`**

Create `app/src/components/tables/EntitiesMobileRows.vue` using this structure:

```vue
<template>
  <MobileTableList :items="items" label="Entity records" :item-key="rowKey">
    <template #default="{ item, index }">
      <article class="entity-mobile-row" role="listitem">
        <div class="entity-mobile-row__topline">
          <span class="entity-mobile-row__id">Entity {{ getText(item, 'entity_id') }}</span>
          <strong class="entity-mobile-row__gene">{{ getText(item, 'symbol') }}</strong>
          <button
            class="btn btn-sm btn-outline-secondary entity-mobile-row__toggle"
            type="button"
            :aria-expanded="expandedIndex === index ? 'true' : 'false'"
            @click="expandedIndex = expandedIndex === index ? null : index"
          >
            Details
          </button>
        </div>
        <p class="entity-mobile-row__disease">{{ getText(item, 'disease_name') || getText(item, 'disease') }}</p>
        <div class="entity-mobile-row__chips">
          <span v-if="getText(item, 'inheritance')" data-testid="entity-chip" class="entity-mobile-row__chip">{{ getText(item, 'inheritance') }}</span>
          <span v-if="getText(item, 'category')" data-testid="entity-chip" class="entity-mobile-row__chip">{{ getText(item, 'category') }}</span>
          <span v-if="getText(item, 'ndd')" data-testid="entity-chip" class="entity-mobile-row__chip">NDD {{ getText(item, 'ndd') }}</span>
        </div>
        <dl v-if="expandedIndex === index" class="entity-mobile-row__details">
          <template v-for="field in detailFields" :key="field.key">
            <dt>{{ field.label }}</dt>
            <dd>{{ getText(item, field.key) || '-' }}</dd>
          </template>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import MobileTableList from '@/components/table/MobileTableList.vue'

type EntityRow = Record<string, unknown>

defineProps<{
  items: EntityRow[]
}>()

const expandedIndex = ref<number | null>(null)
const detailFields = [
  { key: 'omim_id', label: 'OMIM' },
  { key: 'hgnc_id', label: 'HGNC' },
  { key: 'comment', label: 'Comment' },
]

function rowKey(item: EntityRow, index: number): string {
  return `${getText(item, 'entity_id') || 'entity'}-${index}`
}

function getText(item: EntityRow, key: string): string {
  const value = item[key]
  return typeof value === 'string' || typeof value === 'number' ? String(value) : ''
}
</script>

<style scoped>
.entity-mobile-row {
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 0.625rem;
  background: #fff;
}

.entity-mobile-row__topline {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: 0.5rem;
  align-items: center;
}

.entity-mobile-row__id,
.entity-mobile-row__gene {
  min-width: 0;
}

.entity-mobile-row__id {
  color: #475569;
  font-size: 0.78rem;
  font-weight: 700;
}

.entity-mobile-row__gene {
  color: #111827;
}

.entity-mobile-row__disease {
  margin: 0.45rem 0 0;
  color: #334155;
  font-size: 0.86rem;
  line-height: 1.3;
}

.entity-mobile-row__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.55rem;
}

.entity-mobile-row__chip {
  border-radius: 999px;
  background: #f1f5f9;
  color: #334155;
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1;
  padding: 0.32rem 0.48rem;
}

.entity-mobile-row__details {
  display: grid;
  grid-template-columns: minmax(5rem, auto) minmax(0, 1fr);
  gap: 0.35rem 0.75rem;
  margin: 0.75rem 0 0;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
  font-size: 0.84rem;
}

.entity-mobile-row__details dt,
.entity-mobile-row__details dd {
  margin: 0;
}
</style>
```

- [ ] **Step 5: Implement `GenesMobileRows.vue`**

Create `app/src/components/tables/GenesMobileRows.vue` with the same mobile row pattern and these domain fields:

```vue
<template>
  <MobileTableList :items="items" label="Gene records" :item-key="rowKey">
    <template #default="{ item, index }">
      <article class="gene-mobile-row" role="listitem">
        <div class="gene-mobile-row__topline">
          <strong class="gene-mobile-row__symbol">{{ getText(item, 'symbol') }}</strong>
          <span class="gene-mobile-row__count">{{ entityCount(item) }}</span>
          <button
            class="btn btn-sm btn-outline-secondary"
            type="button"
            :aria-expanded="expandedIndex === index ? 'true' : 'false'"
            @click="expandedIndex = expandedIndex === index ? null : index"
          >
            Details
          </button>
        </div>
        <p class="gene-mobile-row__name">{{ getText(item, 'gene_name') || getText(item, 'name') }}</p>
        <div class="gene-mobile-row__chips">
          <span v-if="getText(item, 'inheritance')" class="gene-mobile-row__chip">{{ getText(item, 'inheritance') }}</span>
          <span v-if="getText(item, 'category')" class="gene-mobile-row__chip">{{ getText(item, 'category') }}</span>
          <span v-if="getText(item, 'ndd')" class="gene-mobile-row__chip">NDD {{ getText(item, 'ndd') }}</span>
        </div>
        <dl v-if="expandedIndex === index" class="gene-mobile-row__details">
          <dt>HGNC</dt>
          <dd>{{ getText(item, 'hgnc_id') || '-' }}</dd>
          <dt>OMIM</dt>
          <dd>{{ getText(item, 'omim_id') || '-' }}</dd>
          <dt>Comment</dt>
          <dd>{{ getText(item, 'comment') || '-' }}</dd>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import MobileTableList from '@/components/table/MobileTableList.vue'

type GeneRow = Record<string, unknown>

defineProps<{
  items: GeneRow[]
}>()

const expandedIndex = ref<number | null>(null)

function rowKey(item: GeneRow, index: number): string {
  return `${getText(item, 'symbol') || 'gene'}-${index}`
}

function entityCount(item: GeneRow): string {
  const raw = item.entities_count ?? item.entity_count ?? item.entities
  const value = typeof raw === 'number' || typeof raw === 'string' ? Number(raw) : 0
  return `${value} ${value === 1 ? 'entity' : 'entities'}`
}

function getText(item: GeneRow, key: string): string {
  const value = item[key]
  return typeof value === 'string' || typeof value === 'number' ? String(value) : ''
}
</script>

<style scoped>
.gene-mobile-row {
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 0.625rem;
  background: #fff;
}

.gene-mobile-row__topline {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 0.5rem;
  align-items: center;
}

.gene-mobile-row__symbol {
  min-width: 0;
  color: #111827;
}

.gene-mobile-row__count {
  border-radius: 999px;
  background: #eef2ff;
  color: #3730a3;
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1;
  padding: 0.32rem 0.48rem;
}

.gene-mobile-row__name {
  margin: 0.45rem 0 0;
  color: #334155;
  font-size: 0.86rem;
  line-height: 1.3;
}

.gene-mobile-row__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.55rem;
}

.gene-mobile-row__chip {
  border-radius: 999px;
  background: #f1f5f9;
  color: #334155;
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1;
  padding: 0.32rem 0.48rem;
}

.gene-mobile-row__details {
  display: grid;
  grid-template-columns: minmax(5rem, auto) minmax(0, 1fr);
  gap: 0.35rem 0.75rem;
  margin: 0.75rem 0 0;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
  font-size: 0.84rem;
}

.gene-mobile-row__details dt,
.gene-mobile-row__details dd {
  margin: 0;
}
</style>
```

- [ ] **Step 6: Run mobile row tests**

Run:

```bash
cd app && npx vitest run src/components/tables/EntitiesMobileRows.spec.ts src/components/tables/GenesMobileRows.spec.ts
```

Expected: pass.

- [ ] **Step 7: Wire `TablesEntities.vue`**

In `app/src/components/tables/TablesEntities.vue`:

- Import `TableShell`, `TableLoadingState`, and `EntitiesMobileRows`.
- Move existing header, controls, `GenericTable`, pagination, and filters into `TableShell` slots.
- Preserve the existing data-loading function, watchers, route handling, computed fields, and emitted events.
- Render desktop and mobile regions:

```vue
<div class="d-none d-md-block">
  <GenericTable
    :items="items"
    :fields="fields"
    :loading="loading"
    :stacked-mode="false"
    @sort-changed="onSortChanged"
  />
</div>
<div class="d-md-none">
  <EntitiesMobileRows :items="items" />
</div>
```

- [ ] **Step 8: Wire `TablesGenes.vue`**

In `app/src/components/tables/TablesGenes.vue`:

- Import `TableShell`, `TableLoadingState`, and `GenesMobileRows`.
- Keep the existing `BTable` for desktop and set it in a `d-none d-md-block` wrapper.
- Render `GenesMobileRows` in a `d-md-none` wrapper.
- Update the details action class to meet contrast:

```vue
<BButton
  size="sm"
  variant="outline-primary"
  class="fw-semibold"
  :aria-label="`Show details for ${row.item.symbol}`"
>
  Show
</BButton>
```

- [ ] **Step 9: Run focused tests**

Run:

```bash
cd app && npx vitest run src/components/tables/EntitiesMobileRows.spec.ts src/components/tables/GenesMobileRows.spec.ts src/components/table/TableShell.spec.ts src/components/table/GenericTable.spec.ts
```

Expected: pass.

- [ ] **Step 10: Commit Task 4**

Run:

```bash
git add app/src/components/tables/EntitiesMobileRows.vue app/src/components/tables/EntitiesMobileRows.spec.ts app/src/components/tables/GenesMobileRows.vue app/src/components/tables/GenesMobileRows.spec.ts app/src/components/tables/TablesEntities.vue app/src/components/tables/TablesGenes.vue
git commit -m "feat: add responsive entity and gene table rows"
```

### Task 5: Panels Mobile Rows and Toolbar Cleanup

**Files:**
- Create: `app/src/components/panels/PanelsMobileRows.vue`
- Create: `app/src/components/panels/PanelsMobileRows.spec.ts`
- Modify: `app/src/components/panels/PanelsTable.vue`

- [ ] **Step 1: Write failing panels mobile row test**

Create `app/src/components/panels/PanelsMobileRows.spec.ts`:

```ts
import { mount } from '@vue/test-utils'
import { describe, expect, it } from 'vitest'
import PanelsMobileRows from './PanelsMobileRows.vue'

describe('PanelsMobileRows', () => {
  it('renders symbol, category, inheritance, and expandable selected fields', async () => {
    const wrapper = mount(PanelsMobileRows, {
      props: {
        items: [
          {
            symbol: 'ARID1B',
            disease_name: 'Coffin-Siris syndrome',
            category: 'Definitive',
            inheritance: 'AD',
            hgnc_id: 'HGNC:18040',
          },
        ],
        selectedFieldKeys: ['hgnc_id'],
      },
    })

    expect(wrapper.text()).toContain('ARID1B')
    expect(wrapper.text()).toContain('Coffin-Siris syndrome')
    expect(wrapper.text()).toContain('Definitive')
    expect(wrapper.text()).toContain('AD')
    expect(wrapper.text()).not.toContain('HGNC:18040')

    await wrapper.get('button[aria-expanded="false"]').trigger('click')
    expect(wrapper.text()).toContain('HGNC:18040')
  })
})
```

- [ ] **Step 2: Run the failing test**

Run:

```bash
cd app && npx vitest run src/components/panels/PanelsMobileRows.spec.ts
```

Expected: fail because `PanelsMobileRows.vue` does not exist.

- [ ] **Step 3: Implement `PanelsMobileRows.vue`**

Create `app/src/components/panels/PanelsMobileRows.vue`:

```vue
<template>
  <MobileTableList :items="items" label="Panel records" :item-key="rowKey">
    <template #default="{ item, index }">
      <article class="panel-mobile-row" role="listitem">
        <div class="panel-mobile-row__topline">
          <strong class="panel-mobile-row__symbol">{{ getText(item, 'symbol') }}</strong>
          <span v-if="getText(item, 'category')" class="panel-mobile-row__chip">{{ getText(item, 'category') }}</span>
          <button
            class="btn btn-sm btn-outline-secondary"
            type="button"
            :aria-expanded="expandedIndex === index ? 'true' : 'false'"
            @click="expandedIndex = expandedIndex === index ? null : index"
          >
            Details
          </button>
        </div>
        <p class="panel-mobile-row__disease">{{ getText(item, 'disease_name') || getText(item, 'disease') }}</p>
        <div class="panel-mobile-row__chips">
          <span v-if="getText(item, 'inheritance')" class="panel-mobile-row__chip">{{ getText(item, 'inheritance') }}</span>
          <span v-if="getText(item, 'hgnc_id')" class="panel-mobile-row__chip">{{ getText(item, 'hgnc_id') }}</span>
        </div>
        <dl v-if="expandedIndex === index" class="panel-mobile-row__details">
          <template v-for="fieldKey in selectedFieldKeys" :key="fieldKey">
            <dt>{{ fieldLabel(fieldKey) }}</dt>
            <dd>{{ getText(item, fieldKey) || '-' }}</dd>
          </template>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import MobileTableList from '@/components/table/MobileTableList.vue'

type PanelRow = Record<string, unknown>

defineProps<{
  items: PanelRow[]
  selectedFieldKeys: string[]
}>()

const expandedIndex = ref<number | null>(null)

function rowKey(item: PanelRow, index: number): string {
  return `${getText(item, 'symbol') || 'panel'}-${index}`
}

function fieldLabel(key: string): string {
  return key
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function getText(item: PanelRow, key: string): string {
  const value = item[key]
  return typeof value === 'string' || typeof value === 'number' ? String(value) : ''
}
</script>

<style scoped>
.panel-mobile-row {
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 0.625rem;
  background: #fff;
}

.panel-mobile-row__topline {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto auto;
  gap: 0.5rem;
  align-items: center;
}

.panel-mobile-row__symbol {
  min-width: 0;
  color: #111827;
}

.panel-mobile-row__disease {
  margin: 0.45rem 0 0;
  color: #334155;
  font-size: 0.86rem;
  line-height: 1.3;
}

.panel-mobile-row__chips {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.55rem;
}

.panel-mobile-row__chip {
  border-radius: 999px;
  background: #f1f5f9;
  color: #334155;
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1;
  padding: 0.32rem 0.48rem;
}

.panel-mobile-row__details {
  display: grid;
  grid-template-columns: minmax(5rem, auto) minmax(0, 1fr);
  gap: 0.35rem 0.75rem;
  margin: 0.75rem 0 0;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
  font-size: 0.84rem;
}

.panel-mobile-row__details dt,
.panel-mobile-row__details dd {
  margin: 0;
}
</style>
```

- [ ] **Step 4: Wire `PanelsTable.vue`**

In `app/src/components/panels/PanelsTable.vue`:

- Import `TableShell`, `TableLoadingState`, and `PanelsMobileRows`.
- Keep existing category, inheritance, column-selection, sorting, pagination, and download logic.
- Put controls in the `TableShell` toolbar slot with a wrapping `.table-toolbar-grid`.
- Put the existing `BTable` inside a `d-none d-md-block` wrapper.
- Add mobile rows:

```vue
<div class="d-md-none">
  <PanelsMobileRows :items="items" :selected-field-keys="selectedColumnKeys" />
</div>
```

- Give any help button a direct accessible name:

```vue
<BButton aria-label="Show panel table column help" />
```

- [ ] **Step 5: Run panels tests**

Run:

```bash
cd app && npx vitest run src/components/panels/PanelsMobileRows.spec.ts src/components/table/TableShell.spec.ts
```

Expected: pass.

- [ ] **Step 6: Commit Task 5**

Run:

```bash
git add app/src/components/panels/PanelsMobileRows.vue app/src/components/panels/PanelsMobileRows.spec.ts app/src/components/panels/PanelsTable.vue
git commit -m "feat: add responsive panel table rows"
```

### Task 6: Lazy Excel Export Import

**Files:**
- Modify: `app/src/composables/useExcelExport.ts`

- [ ] **Step 1: Inspect current import**

Run:

```bash
rg "exceljs|ExcelJS" app/src/composables app/src -n
```

Expected: `useExcelExport.ts` has a top-level `exceljs` import.

- [ ] **Step 2: Move `exceljs` to a dynamic import**

In `app/src/composables/useExcelExport.ts`, remove the top-level import:

```ts
import ExcelJS from 'exceljs'
```

Inside the export function, load the dependency only when export is requested:

```ts
const ExcelJS = (await import('exceljs')).default
const workbook = new ExcelJS.Workbook()
```

If the function is not already async, change it to async and update callers to `await exportToExcel(...)` or handle the returned promise in the existing click handler.

- [ ] **Step 3: Run type-check**

Run:

```bash
cd app && npm run type-check
```

Expected: pass.

- [ ] **Step 4: Build or inspect chunks**

Run:

```bash
cd app && npm run build
```

Expected: production build succeeds and `exceljs` is emitted as an async chunk or no longer appears in the initial app chunk names.

- [ ] **Step 5: Commit Task 6**

Run:

```bash
git add app/src/composables/useExcelExport.ts
git commit -m "perf: lazy load excel export dependency"
```

### Task 7: Playwright Responsive Regression Spec

**Files:**
- Create: `app/tests/e2e/tables-responsive.spec.ts`

- [ ] **Step 1: Create Playwright responsive spec**

Create `app/tests/e2e/tables-responsive.spec.ts`:

```ts
import { expect, test } from '@playwright/test'

const routes = [
  { name: 'curation comparisons', path: '/CurationComparisons/Table', maxMobileRowHeight: 155 },
  { name: 'entities', path: '/Entities?sort=%2Bentity_id&page_size=10', maxMobileRowHeight: 155 },
  { name: 'genes', path: '/Genes?sort=%2Bsymbol&page_after=0&page_size=10', maxMobileRowHeight: 145 },
  { name: 'panels', path: '/Panels/All/All', maxMobileRowHeight: 155 },
]

for (const route of routes) {
  test(`${route.name} has no horizontal overflow on mobile`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 })
    await page.goto(route.path)
    await page.waitForLoadState('networkidle')

    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)
    expect(overflow).toBeLessThanOrEqual(1)
  })

  test(`${route.name} renders compact mobile records`, async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 })
    await page.goto(route.path)
    await page.waitForLoadState('networkidle')

    const rows = page.locator('[role="listitem"]')
    await expect(rows.first()).toBeVisible()

    const firstFive = await rows.evaluateAll((elements) =>
      elements.slice(0, 5).map((element) => element.getBoundingClientRect().height),
    )
    const average = firstFive.reduce((sum, height) => sum + height, 0) / firstFive.length
    expect(average).toBeLessThanOrEqual(route.maxMobileRowHeight)
  })

  test(`${route.name} keeps desktop table semantics`, async ({ page }) => {
    await page.setViewportSize({ width: 1366, height: 900 })
    await page.goto(route.path)
    await page.waitForLoadState('networkidle')

    await expect(page.locator('table').first()).toBeVisible()
    await expect(page.locator('thead').first()).toBeVisible()
  })
}
```

- [ ] **Step 2: Run Playwright stack and focused spec**

Run:

```bash
make playwright-stack
cd app && npx playwright test tests/e2e/tables-responsive.spec.ts
cd .. && make playwright-stack-down
```

Expected: pass. If the local stack cannot start because required services or ports are unavailable, record the exact failing command and continue with Vitest, type-check, and manual browser evidence.

- [ ] **Step 3: Commit Task 7**

Run:

```bash
git add app/tests/e2e/tables-responsive.spec.ts
git commit -m "test: cover responsive table layouts"
```

### Task 8: Full Verification and Visual Review

**Files:**
- Modify only files required by failures found in this task.

- [ ] **Step 1: Run formatting check**

Run:

```bash
cd app && npm run format:check
```

Expected: pass. If it fails, run `cd app && npm run format`, inspect the diff, and commit formatting changes with the related task commit if possible.

- [ ] **Step 2: Run frontend lint**

Run:

```bash
make lint-app
```

Expected: pass with no new lint errors.

- [ ] **Step 3: Run frontend type-check**

Run:

```bash
cd app && npm run type-check
```

Expected: pass.

- [ ] **Step 4: Run frontend unit tests**

Run:

```bash
cd app && npm run test:unit
```

Expected: pass.

- [ ] **Step 5: Run pre-commit gate**

Run:

```bash
make pre-commit
```

Expected: pass, allowing existing unrelated warnings only if they were already present and are not new failures.

- [ ] **Step 6: Capture responsive screenshots**

Use Playwright or the browser at these widths: 390, 768, 1024, 1366, and 1440 px. Check every target route:

```text
/CurationComparisons/Table
/Entities?sort=%2Bentity_id&page_size=10
/Genes?sort=%2Bsymbol&page_after=0&page_size=10
/Panels/All/All
```

Expected:

- No horizontal overflow.
- Mobile rows are compact before expansion.
- Desktop tables are still visible and sortable.
- Toolbars wrap cleanly.
- Loading state reserves space and does not collapse the page.

- [ ] **Step 7: Run Lighthouse**

Run Lighthouse mobile and desktop against the four target routes. Expected:

- No new accessibility failures.
- Curation and panel help controls no longer fail accessible-name audits.
- Genes details button no longer fails contrast.
- Panels CLS is lower than the previous local baseline of 0.27.

- [ ] **Step 8: Commit fixes from verification**

Run:

```bash
git status --short
git add app/src app/tests/e2e
git commit -m "fix: polish responsive table verification issues"
```

Skip the commit if `git status --short` is clean.

## Execution Notes

- Prefer `superpowers:subagent-driven-development` for implementation. Assign each task to a fresh worker and review between tasks.
- Keep commits task-sized so visual regressions can be isolated quickly.
- If a task discovers that a component uses different field names from the samples in this plan, adapt the row component by reading the existing field definitions in that component, not by changing the API response.
- The Playwright spec is local-only and should not be treated as a CI workflow unless the repository changes that policy separately.

## Self-Review

- Spec coverage: Tasks 1-5 cover shell, loader, desktop preservation, mobile compact rows, accessibility labels, and panel/entity/gene/comparison page migration. Task 6 covers eager export dependency loading. Task 7 covers responsive regression. Task 8 covers verification and Lighthouse review.
- Placeholder scan: The plan contains concrete files, commands, expected results, and implementation snippets for every code-producing task.
- Type consistency: Shared component names and prop names are consistent across tasks: `TableShell`, `TableLoadingState`, `MobileTableList`, `stackedMode`, `EntitiesMobileRows`, `GenesMobileRows`, `PanelsMobileRows`, and `CurationComparisonMobileRows`.

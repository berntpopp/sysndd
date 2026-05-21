# Manage Re-Review Manual Assignment Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the manual entity assignment workflow UI from `ManageReReview.vue` into a focused child component while preserving current behavior and typed API boundaries.

**Architecture:** `ManageReReview.vue` remains the orchestrator for data loading, mutations, validation, toast/aria announcements, and refresh side effects. The new `ManualEntityAssignmentPanel.vue` is a controlled presentational component that receives state through props and emits user actions back to the parent.

**Tech Stack:** Vue 3 Options API parent, Vue SFC child component, TypeScript/Vitest/Vue Test Utils, MSW, Bootstrap-Vue-Next stubs, typed API clients in `app/src/api/*`, SysNDD code-quality audit.

---

## Execution Rules

- Work in `/home/bernt-popp/development/sysndd` on a normal branch. Do not create git worktrees.
- Follow TDD for every slice: strengthen tests, run focused tests against unchanged production behavior where applicable, make the smallest production change, rerun focused tests.
- Preserve public routes, typed API-client boundaries, API payloads, toast copy, aria announcement copy, and visible UI copy.
- Do not move re-review API calls into the child component.
- Do not extract reassign/recalculate modals in this PR.
- Do not add raw axios calls or direct `localStorage` access.
- Do not raise `scripts/code-quality-file-size-baseline.tsv`; lower `ManageReReview.vue` only if the final line count is below the current baseline.
- Commit each cohesive slice separately.

## File Map

- Modify: `app/src/views/curate/ManageReReview.spec.ts`
  - Add/strengthen parent-level behavior coverage before extraction.
- Create: `app/src/views/curate/components/ManualEntityAssignmentPanel.vue`
  - Controlled UI component for manual entity assignment.
- Create: `app/src/views/curate/components/ManualEntityAssignmentPanel.spec.ts`
  - Component contract tests for rendering and emits.
- Modify: `app/src/views/curate/ManageReReview.vue`
  - Replace the manual assignment template block with the new child component.
- Modify downward only: `scripts/code-quality-file-size-baseline.tsv`
  - Lower `app/src/views/curate/ManageReReview.vue` if it shrinks below `1708`.

## Task 1: Parent Safety Net For Manual Assignment

**Files:**
- Modify: `app/src/views/curate/ManageReReview.spec.ts`
- Read only: `app/src/views/curate/ManageReReview.vue`

- [ ] **Step 1: Add parent-level rendered behavior coverage**

In `app/src/views/curate/ManageReReview.spec.ts`, add these fields to `ManageReReviewVm` if missing:

```ts
activeBatchMode: 'criteria' | 'manual' | null;
entityAssignUserId: number | null;
entityAssignBatchName: string;
selectedEntityIds: number[];
availableEntities: Array<Record<string, unknown>>;
availableEntityTotal: number;
manualEntityFilter: string | null;
previewBoundaryGene: string | null;
previewGeneCount: number;
previewEntityCount: number;
```

In `mountManageReReview()`, make sure the existing stubs include `BAlert` so the boundary alert can render:

```ts
BAlert: {
  props: ['variant', 'show'],
  template: '<div :data-variant="variant"><slot /></div>',
},
```

Also replace the existing `BTable` stub in `mountManageReReview()` with an item-rendering stub so the unchanged parent template can render manual assignment rows through its slots:

```ts
BTable: {
  name: 'BTable',
  props: ['items', 'fields', 'tbodyTrClass', 'busy'],
  template:
    '<table><tbody><tr v-for="item in items" :key="item.entity_id" :class="tbodyTrClass ? tbodyTrClass(item) : undefined"><td><slot name="cell(selected)" :item="item" /></td><td><slot name="cell(entity_id)" :item="item" /></td><td>{{ item.gene_symbol }}</td><td><slot name="cell(disease_ontology_name)" :item="item" /></td><td>{{ item.review_date }}</td><td>{{ item.status_name }}</td></tr></tbody></table>',
},
```

Add this test under `describe('ManageReReview.vue — typed client migration behavior', () => { ... })`:

```ts
it('renders manual entity assignment state from loaded entities', async () => {
  primeAuth('re-review-manual-panel-token');

  server.use(
    http.get('*/api/re_review/entities/available', ({ request }) => {
      const query = new URL(request.url).searchParams;
      expect(query.get('page')).toBe('1');
      expect(query.get('page_size')).toBe('100');
      return HttpResponse.json({
        data: [
          {
            entity_id: 11,
            gene_symbol: 'ARID1B',
            disease_ontology_name: 'ARID1B disorder',
            review_date: '2026-01-01',
            status_name: 'Definitive',
          },
        ],
        meta: { total: 4 },
      });
    })
  );

  const wrapper = await mountManageReReview();
  const component = vm(wrapper);
  component.activeBatchMode = 'manual';
  component.selectedEntityIds = [11];
  await wrapper.vm.$nextTick();

  expect(wrapper.text()).toContain('Manual pick');
  expect(wrapper.text()).toContain('ARID1B');
  expect(wrapper.text()).toContain('ARID1B disorder');
  expect(wrapper.text()).toContain('Showing 1 of 4 available entities.');
  expect(wrapper.text()).toContain('Assign 1 selected');
});
```

Add this test for the boundary alert through the normal mount helper:

```ts
it('renders the manual assignment boundary-gene alert in manual mode', async () => {
  primeAuth('re-review-boundary-panel-token');

  const wrapper = await mountManageReReview();
  const component = vm(wrapper);
  component.activeBatchMode = 'manual';
  component.previewBoundaryGene = 'HGNC:4585';
  component.previewGeneCount = 2;
  component.previewEntityCount = 6;
  await wrapper.vm.$nextTick();

  expect(wrapper.find('[data-testid="batch-boundary-gene-alert"]').exists()).toBe(true);
  expect(wrapper.text()).toContain('HGNC:4585');
  expect(wrapper.text()).toContain('6 entities');
});
```

- [ ] **Step 2: Run the parent spec against unchanged production behavior**

Run:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts
```

Expected: PASS after spec-harness fixes only. If the new tests fail because a stub does not render enough DOM, fix the stub. Do not create the new component yet.

- [ ] **Step 3: Commit the parent safety net**

Run:

```bash
git add app/src/views/curate/ManageReReview.spec.ts
git commit -m "test: cover manual re-review assignment panel behavior"
```

Expected: one test-only commit.

## Task 2: ManualEntityAssignmentPanel Contract

**Files:**
- Create: `app/src/views/curate/components/ManualEntityAssignmentPanel.vue`
- Create: `app/src/views/curate/components/ManualEntityAssignmentPanel.spec.ts`

- [ ] **Step 1: Write the component contract spec**

Create `app/src/views/curate/components/ManualEntityAssignmentPanel.spec.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';

import ManualEntityAssignmentPanel from './ManualEntityAssignmentPanel.vue';

const baseProps = {
  userOptions: [
    { value: 3, text: 'Curator A' },
    { value: 4, text: 'Reviewer B' },
  ],
  entityAssignUserId: null,
  entityAssignBatchName: '',
  selectedEntityIds: [11],
  availableEntities: [
    {
      entity_id: 11,
      gene_symbol: 'ARID1B',
      disease_ontology_name: 'ARID1B disorder',
      review_date: '2026-01-01',
      status_name: 'Definitive',
    },
    {
      entity_id: 22,
      gene_symbol: 'SCN2A',
      disease_ontology_name: 'SCN2A disorder',
      review_date: '2026-02-01',
      status_name: 'Moderate',
    },
  ],
  availableEntityTotal: 7,
  entitySelectFields: [
    { key: 'selected', label: '' },
    { key: 'entity_id', label: 'ID' },
    { key: 'gene_symbol', label: 'Gene' },
    { key: 'disease_ontology_name', label: 'Disease' },
    { key: 'review_date', label: 'Last Review' },
    { key: 'status_name', label: 'Status' },
  ],
  manualEntityFilter: '',
  isLoadingEntities: false,
  isAssigningEntities: false,
  boundaryGeneAlertVisible: false,
  boundaryGeneAlertMessage: '',
};

function mountSubject(props = {}) {
  return mount(ManualEntityAssignmentPanel, {
    props: { ...baseProps, ...props },
    global: {
      stubs: {
        BFormGroup: {
          props: ['label'],
          template: '<div><label>{{ label }}</label><slot /></div>',
        },
        BFormSelect: {
          props: ['modelValue', 'options'],
          emits: ['update:modelValue'],
          template:
            '<select :value="modelValue" @change="$emit(`update:modelValue`, Number($event.target.value))"><slot name="first" /><option v-for="option in options" :key="option.value" :value="option.value">{{ option.text }}</option></select>',
        },
        BFormInput: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<input :value="modelValue" @input="$emit(`update:modelValue`, $event.target.value)" />',
        },
        BButton: {
          props: ['disabled'],
          template: '<button :disabled="disabled" @click="$emit(`click`)"><slot /></button>',
        },
        BSpinner: { template: '<span data-testid="spinner" />' },
        BAlert: {
          props: ['variant', 'show'],
          template: '<div :data-variant="variant"><slot /></div>',
        },
        TableSearchInput: {
          props: ['modelValue'],
          emits: ['update:modelValue', 'update', 'clear'],
          template:
            '<input aria-label="Search available entities" :value="modelValue" @input="$emit(`update:modelValue`, $event.target.value); $emit(`update`)" @keyup.esc="$emit(`clear`)" />',
        },
        BTable: {
          props: ['items', 'fields', 'tbodyTrClass', 'busy'],
          template:
            '<table><tbody><tr v-for="item in items" :key="item.entity_id" :class="tbodyTrClass(item)"><td><slot name="cell(selected)" :item="item" /></td><td><slot name="cell(entity_id)" :item="item" /></td><td>{{ item.gene_symbol }}</td><td><slot name="cell(disease_ontology_name)" :item="item" /></td><td>{{ item.review_date }}</td><td>{{ item.status_name }}</td></tr></tbody></table>',
        },
      },
    },
  });
}

describe('ManualEntityAssignmentPanel', () => {
  it('renders controls, selected count, entity rows, and available total', () => {
    const wrapper = mountSubject();

    expect(wrapper.text()).toContain('Assign to');
    expect(wrapper.text()).toContain('Batch name');
    expect(wrapper.text()).toContain('1');
    expect(wrapper.text()).toContain('selected');
    expect(wrapper.text()).toContain('ARID1B');
    expect(wrapper.text()).toContain('SCN2A disorder');
    expect(wrapper.text()).toContain('Showing 2 of 7 available entities.');
    expect(wrapper.find('tr').classes()).toContain('re-review-pick-table__row--selected');
  });

  it('disables assignment until a user and selected entity are present', async () => {
    const disabledWrapper = mountSubject({ selectedEntityIds: [], entityAssignUserId: null });
    expect(disabledWrapper.findAll('button').some((button) => button.text().includes('Assign') && button.attributes('disabled') !== undefined)).toBe(true);
    expect(disabledWrapper.findAll('button').find((button) => button.text().includes('Clear'))?.attributes('disabled')).toBeDefined();

    const enabledWrapper = mountSubject({ selectedEntityIds: [11], entityAssignUserId: 3 });
    expect(enabledWrapper.findAll('button').find((button) => button.text().includes('Assign'))?.attributes('disabled')).toBeUndefined();
    expect(enabledWrapper.findAll('button').find((button) => button.text().includes('Clear'))?.attributes('disabled')).toBeUndefined();
  });

  it('emits model updates and manual assignment actions', async () => {
    const wrapper = mountSubject({ entityAssignUserId: 3 });

    await wrapper.find('select').setValue('4');
    await wrapper.find('input').setValue('named-batch');
    await wrapper.find('[aria-label="Search available entities"]').setValue('SCN2A');
    await wrapper.find('[aria-label="Select entity 22"]').trigger('change');
    await wrapper.findAll('button').find((button) => button.text().includes('Assign'))!.trigger('click');
    await wrapper.findAll('button').find((button) => button.text().includes('Refresh entities'))!.trigger('click');
    await wrapper.findAll('button').find((button) => button.text().includes('Clear'))!.trigger('click');
    await wrapper.findAll('button').find((button) => button.text().includes('Close setup'))!.trigger('click');

    expect(wrapper.emitted('update:entityAssignUserId')?.at(-1)).toEqual([4]);
    expect(wrapper.emitted('update:entityAssignBatchName')?.at(-1)).toEqual(['named-batch']);
    expect(wrapper.emitted('update:manualEntityFilter')?.at(-1)).toEqual(['SCN2A']);
    expect(wrapper.emitted('toggle-entity-selection')?.at(-1)).toEqual([22]);
    expect(wrapper.emitted('assign-entities')).toHaveLength(1);
    expect(wrapper.emitted('refresh-entities')).toBeTruthy();
    expect(wrapper.emitted('clear-selection')).toHaveLength(1);
    expect(wrapper.emitted('close')).toHaveLength(1);
  });

  it('renders boundary-gene alert copy when requested', () => {
    const wrapper = mountSubject({
      boundaryGeneAlertVisible: true,
      boundaryGeneAlertMessage: 'Batch is gene-atomic for HGNC:4585.',
    });

    expect(wrapper.find('[data-testid="batch-boundary-gene-alert"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('HGNC:4585');
  });
});
```

- [ ] **Step 2: Run the new spec to verify the component is missing**

Run:

```bash
cd app && npx vitest run src/views/curate/components/ManualEntityAssignmentPanel.spec.ts
```

Expected: FAIL because `ManualEntityAssignmentPanel.vue` does not exist.

- [ ] **Step 3: Create the component**

Create `app/src/views/curate/components/ManualEntityAssignmentPanel.vue`:

```vue
<template>
  <div class="re-review-mode-panel re-review-section__body--assignment">
    <div class="re-review-mode-intro">
      <strong>Manual pick</strong>
      <span>Select exact entities, assign a user, then create the exception batch.</span>
      <BButton
        size="sm"
        variant="outline-secondary"
        class="ms-auto"
        @click="$emit('close')"
      >
        Close setup
      </BButton>
    </div>

    <div class="re-review-manual-controls">
      <div class="re-review-assignment-grid">
        <BFormGroup label="Assign to" label-for="entity-assign-user" class="mb-0">
          <BFormSelect
            id="entity-assign-user"
            :model-value="entityAssignUserId"
            :options="userOptions"
            size="sm"
            aria-label="Select user to assign selected entities to"
            @update:model-value="$emit('update:entityAssignUserId', $event)"
          >
            <template #first>
              <option :value="null" disabled>Select a user</option>
            </template>
          </BFormSelect>
        </BFormGroup>

        <BFormGroup label="Batch name" label-for="entity-assign-batch-name" class="mb-0">
          <BFormInput
            id="entity-assign-batch-name"
            :model-value="entityAssignBatchName"
            size="sm"
            placeholder="Auto-generated"
            aria-label="Custom name for the new batch"
            @update:model-value="$emit('update:entityAssignBatchName', $event)"
          />
        </BFormGroup>
      </div>

      <div class="re-review-button-row">
        <BButton
          variant="primary"
          size="sm"
          :disabled="selectedEntityIds.length === 0 || !entityAssignUserId || isAssigningEntities"
          @click="$emit('assign-entities')"
        >
          <BSpinner v-if="isAssigningEntities" small class="me-1" />
          <i v-else class="bi bi-person-plus me-1" aria-hidden="true" />
          Assign {{ selectedEntityIds.length || '' }} selected
        </BButton>
        <BButton
          variant="outline-secondary"
          size="sm"
          aria-label="Refresh entity list"
          @click="$emit('refresh-entities')"
        >
          <i class="bi bi-arrow-clockwise me-1" aria-hidden="true" />
          Refresh entities
        </BButton>
      </div>
    </div>

    <BFormGroup
      label="Entities"
      label-for="entity-select-table"
      class="mb-3 re-review-entity-picker"
    >
      <div class="re-review-picker-toolbar">
        <TableSearchInput
          :model-value="manualEntityFilter"
          placeholder="Search available entities"
          :debounce-time="300"
          @update:model-value="$emit('update:manualEntityFilter', $event)"
          @update="$emit('refresh-entities')"
          @clear="$emit('refresh-entities')"
        />
        <div class="re-review-picker-toolbar__meta">
          <strong>{{ selectedEntityIds.length }}</strong>
          selected
        </div>
        <BButton
          size="sm"
          variant="outline-secondary"
          :disabled="selectedEntityIds.length === 0"
          @click="$emit('clear-selection')"
        >
          Clear
        </BButton>
      </div>
      <BTable
        id="entity-select-table"
        :items="availableEntities"
        :fields="entitySelectFields"
        small
        hover
        responsive
        :busy="isLoadingEntities"
        :tbody-tr-class="manualEntityRowClass"
        class="re-review-pick-table"
      >
        <template #table-busy>
          <div class="text-center my-2">
            <BSpinner class="align-middle" />
            <strong class="ms-2">Loading entities...</strong>
          </div>
        </template>
        <template #cell(selected)="row">
          <input
            type="checkbox"
            class="form-check-input re-review-row-checkbox"
            :checked="isEntitySelected(row.item.entity_id)"
            :aria-label="`Select entity ${row.item.entity_id}`"
            @change="$emit('toggle-entity-selection', row.item.entity_id)"
          />
        </template>
        <template #cell(entity_id)="row">
          <span class="font-monospace">#{{ row.item.entity_id }}</span>
        </template>
        <template #cell(disease_ontology_name)="row">
          <span class="re-review-disease-cell" :title="row.item.disease_ontology_name">
            {{ row.item.disease_ontology_name }}
          </span>
        </template>
      </BTable>
      <small class="text-muted d-block mt-1">
        Showing {{ availableEntities.length }} of {{ availableEntityTotal }} available entities.
      </small>
    </BFormGroup>

    <BAlert
      v-if="boundaryGeneAlertVisible"
      variant="warning"
      show
      class="my-3"
      data-testid="batch-boundary-gene-alert"
    >
      <i class="bi bi-exclamation-triangle me-1" aria-hidden="true" />
      {{ boundaryGeneAlertMessage }}
    </BAlert>
  </div>
</template>

<script setup lang="ts">
interface UserOption {
  value: number;
  text: string;
  role?: string;
}

interface EntityRow {
  entity_id: number;
  gene_symbol?: string;
  disease_ontology_name?: string;
  review_date?: string;
  status_name?: string;
  [key: string]: unknown;
}

interface TableField {
  key: string;
  label: string;
  sortable?: boolean;
  thStyle?: Record<string, string>;
}

const props = defineProps<{
  userOptions: UserOption[];
  entityAssignUserId: number | null;
  entityAssignBatchName: string;
  selectedEntityIds: number[];
  availableEntities: EntityRow[];
  availableEntityTotal: number;
  entitySelectFields: TableField[];
  manualEntityFilter: string | null;
  isLoadingEntities: boolean;
  isAssigningEntities: boolean;
  boundaryGeneAlertVisible: boolean;
  boundaryGeneAlertMessage: string;
}>();

defineEmits<{
  'update:entityAssignUserId': [value: number | null];
  'update:entityAssignBatchName': [value: string];
  'update:manualEntityFilter': [value: string | null];
  'assign-entities': [];
  'refresh-entities': [];
  'clear-selection': [];
  'toggle-entity-selection': [entityId: number];
  close: [];
}>();

function isEntitySelected(entityId: number) {
  return props.selectedEntityIds.includes(entityId);
}

function manualEntityRowClass(item: EntityRow | null) {
  return item && props.selectedEntityIds.includes(item.entity_id)
    ? 're-review-pick-table__row--selected'
    : '';
}
</script>
```

- [ ] **Step 4: Run the child spec**

Run:

```bash
cd app && npx vitest run src/views/curate/components/ManualEntityAssignmentPanel.spec.ts
```

Expected: PASS. If stubs fail due template TypeScript syntax in string templates, simplify the stub template expressions and keep assertions equivalent.

- [ ] **Step 5: Commit the child component contract**

Run:

```bash
git add app/src/views/curate/components/ManualEntityAssignmentPanel.vue app/src/views/curate/components/ManualEntityAssignmentPanel.spec.ts
git commit -m "test: cover manual re-review assignment panel"
```

Expected: one child-component commit.

## Task 3: Replace Parent Manual Assignment Template

**Files:**
- Modify: `app/src/views/curate/ManageReReview.vue`
- Modify: `app/src/views/curate/ManageReReview.spec.ts` if stubs need the child component passthrough
- Modify downward only: `scripts/code-quality-file-size-baseline.tsv`

- [ ] **Step 1: Import and register the new component**

In `app/src/views/curate/ManageReReview.vue`, add the import:

```js
import ManualEntityAssignmentPanel from '@/views/curate/components/ManualEntityAssignmentPanel.vue';
```

Register it:

```js
components: {
  AuthenticatedPageShell,
  BatchCriteriaForm,
  AriaLiveRegion,
  IconLegend,
  TableShell,
  GenericTable,
  TableSearchInput,
  TablePaginationControls,
  ManualEntityAssignmentPanel,
},
```

- [ ] **Step 2: Replace only the manual assignment block**

Replace the current `<div v-else class="re-review-mode-panel re-review-section__body--assignment">...</div>` manual-pick block with:

```vue
<ManualEntityAssignmentPanel
  v-else
  v-model:entity-assign-user-id="entityAssignUserId"
  v-model:entity-assign-batch-name="entityAssignBatchName"
  v-model:manual-entity-filter="manualEntityFilter"
  :user-options="user_options"
  :selected-entity-ids="selectedEntityIds"
  :available-entities="availableEntities"
  :available-entity-total="availableEntityTotal"
  :entity-select-fields="entitySelectFields"
  :is-loading-entities="isLoadingEntities"
  :is-assigning-entities="isAssigningEntities"
  :boundary-gene-alert-visible="boundaryGeneAlertVisible"
  :boundary-gene-alert-message="boundaryGeneAlertMessage"
  @assign-entities="handleEntityAssignment"
  @refresh-entities="loadAvailableEntities"
  @clear-selection="clearManualSelection"
  @toggle-entity-selection="toggleEntitySelection"
  @close="activeBatchMode = null"
/>
```

Do not change the parent methods in this step.

- [ ] **Step 3: Remove parent-only methods that moved into the child**

Remove these methods from `ManageReReview.vue` only after the child is wired:

```js
isEntitySelected(entityId) {
  return this.selectedEntityIds.includes(entityId);
},
manualEntityRowClass(item) {
  return item && this.selectedEntityIds.includes(item.entity_id)
    ? 're-review-pick-table__row--selected'
    : '';
},
```

Keep these parent methods:

```js
toggleEntitySelection(entityId) {
  if (this.selectedEntityIds.includes(entityId)) {
    this.selectedEntityIds = this.selectedEntityIds.filter((id) => id !== entityId);
    return;
  }
  this.selectedEntityIds = [...this.selectedEntityIds, entityId];
},
clearManualSelection() {
  this.selectedEntityIds = [];
},
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts src/views/curate/components/ManualEntityAssignmentPanel.spec.ts
```

Expected: PASS. If parent stubs hide the child component, remove the child from stubs or use a passthrough stub that emits the same events.

- [ ] **Step 5: Run type-check**

Run:

```bash
cd app && npm run type-check
```

Expected: PASS. Fix any SFC prop/event type mismatch without changing the component contract.

- [ ] **Step 6: Ratchet the file-size baseline if applicable**

Run:

```bash
wc -l app/src/views/curate/ManageReReview.vue
rg -n '^app/src/views/curate/ManageReReview.vue\\s+' scripts/code-quality-file-size-baseline.tsv
```

If the new line count is below `1708`, update only that TSV entry downward. Do not raise it.

- [ ] **Step 7: Run code-quality audit**

Run:

```bash
git diff --check
make code-quality-audit
```

Expected: both commands exit 0.

- [ ] **Step 8: Commit the extraction**

Run:

```bash
git add app/src/views/curate/ManageReReview.vue app/src/views/curate/ManageReReview.spec.ts scripts/code-quality-file-size-baseline.tsv
git commit -m "refactor: extract manual re-review assignment panel"
```

Expected: one behavior-preserving extraction commit.

## Task 4: Final Verification And Handoff

**Files:**
- Inspect: full diff

- [ ] **Step 1: Run focused verification**

Run:

```bash
cd app && npx vitest run src/views/curate/ManageReReview.spec.ts src/views/curate/components/ManualEntityAssignmentPanel.spec.ts
cd app && npm run type-check
git diff --check
make code-quality-audit
```

Expected: all commands exit 0.

- [ ] **Step 2: Run broader pre-commit verification**

Run:

```bash
make pre-commit
```

Expected: exit 0. Record any existing warnings/skips that do not fail the command.

- [ ] **Step 3: Run local CI if environment permits**

Run:

```bash
make ci-local
```

Expected: exit 0. If blocked by environment, record the exact command and error.

- [ ] **Step 4: Inspect the final diff for SysNDD code-quality risks**

Run:

```bash
git diff --stat HEAD~3..HEAD
git show --stat --oneline --decorate --no-renames HEAD
```

Review for:

- no raw axios or direct `localStorage` access added
- no API payload changes
- `ManageReReview.vue` shrank
- no unrelated files changed
- baseline entry lowered only if applicable

- [ ] **Step 5: Handoff summary**

Summarize:

- commits created
- tests/checks run and results
- final `ManageReReview.vue` line count and baseline action
- deferred follow-ups: reassign/recalculate modal extraction and possible manual assignment composable

<!-- components/review/ReviewTable.vue -->
<template>
  <BCard
    header-tag="header"
    body-class="p-0"
    header-class="p-1"
    border-variant="dark"
    header-bg-variant="dark"
    header-text-variant="light"
  >
    <template #header>
      <BRow class="align-items-center">
        <BCol>
          <h5 class="mb-0 text-start fw-bold">
            {{ title }}
            <BBadge variant="primary" class="ms-2"> {{ totalRows }} {{ totalRowsLabel }} </BBadge>
          </h5>
        </BCol>
        <BCol class="text-end">
          <div class="d-flex align-items-center justify-content-end gap-2">
            <BButton
              v-b-tooltip.hover.bottom
              variant="danger"
              size="sm"
              :title="approveAllTitle"
              :aria-label="approveAllAriaLabel"
              @click="$emit('approve-all')"
            >
              <i class="bi bi-check2-all me-1" aria-hidden="true" />
              Approve All
            </BButton>
            <BButton
              v-b-tooltip.hover.bottom
              variant="outline-light"
              size="sm"
              title="Refresh data"
              aria-label="Refresh table data"
              @click="$emit('refresh')"
            >
              <i class="bi bi-arrow-clockwise" aria-hidden="true" />
            </BButton>
          </div>
        </BCol>
      </BRow>
    </template>

    <BRow class="px-3 py-2 align-items-center">
      <BCol cols="12" md="4" lg="3" class="mb-2 mb-md-0">
        <BInputGroup size="sm">
          <template #prepend>
            <BInputGroupText>
              <i class="bi bi-search" />
            </BInputGroupText>
          </template>
          <BFormInput
            id="filter-input"
            :model-value="filterText"
            type="search"
            placeholder="Search any field..."
            debounce="500"
            @update:model-value="$emit('update:filterText', String($event ?? ''))"
          />
        </BInputGroup>
      </BCol>
      <BCol cols="12" md="4" lg="4" class="mb-2 mb-md-0" />
      <BCol
        cols="12"
        md="4"
        lg="5"
        class="d-flex align-items-center justify-content-end gap-2 flex-wrap"
      >
        <BInputGroup prepend="Per page" size="sm">
          <BFormSelect
            id="per-page-select"
            :model-value="perPage"
            :options="pageOptions"
            size="sm"
            @update:model-value="$emit('update:perPage', Number($event))"
          />
        </BInputGroup>
        <BPagination
          :model-value="currentPage"
          :total-rows="totalRows"
          :per-page="perPage"
          size="sm"
          class="mb-0"
          limit="2"
          @update:model-value="$emit('update:currentPage', Number($event))"
        />
      </BCol>
    </BRow>

    <BRow class="px-3 pb-2 align-items-center">
      <BCol cols="6" md="2" class="mb-2 mb-md-0">
        <BFormSelect
          :model-value="categoryFilter"
          size="sm"
          :options="categoryOptions"
          aria-label="Filter by category"
          @update:model-value="$emit('update:categoryFilter', ($event as string) ?? null)"
        />
      </BCol>
      <BCol cols="6" md="2" class="mb-2 mb-md-0">
        <BFormSelect
          :model-value="userFilter"
          size="sm"
          :options="userOptions"
          aria-label="Filter by user"
          @update:model-value="$emit('update:userFilter', ($event as string) ?? null)"
        />
      </BCol>
      <BCol cols="6" md="2" class="mb-2 mb-md-0">
        <BInputGroup size="sm">
          <template #prepend>
            <BInputGroupText class="small"> From </BInputGroupText>
          </template>
          <BFormInput
            :model-value="dateStart"
            type="date"
            size="sm"
            aria-label="Filter from date"
            @update:model-value="$emit('update:dateStart', String($event ?? '') || null)"
          />
        </BInputGroup>
      </BCol>
      <BCol cols="6" md="2" class="mb-2 mb-md-0">
        <BInputGroup size="sm">
          <template #prepend>
            <BInputGroupText class="small"> To </BInputGroupText>
          </template>
          <BFormInput
            :model-value="dateEnd"
            type="date"
            size="sm"
            aria-label="Filter to date"
            @update:model-value="$emit('update:dateEnd', String($event ?? '') || null)"
          />
        </BInputGroup>
      </BCol>
      <BCol cols="12" md="4" class="d-flex align-items-center flex-wrap gap-1">
        <BBadge
          v-if="categoryFilter"
          variant="secondary"
          class="d-flex align-items-center gap-1"
          style="cursor: pointer"
          @click="$emit('update:categoryFilter', null)"
        >
          {{ categoryFilter }}
          <i class="bi bi-x" />
        </BBadge>
        <BBadge
          v-if="userFilter"
          variant="secondary"
          class="d-flex align-items-center gap-1"
          style="cursor: pointer"
          @click="$emit('update:userFilter', null)"
        >
          {{ userFilter }}
          <i class="bi bi-x" />
        </BBadge>
        <BBadge
          v-if="dateStart"
          variant="secondary"
          class="d-flex align-items-center gap-1"
          style="cursor: pointer"
          @click="$emit('update:dateStart', null)"
        >
          From: {{ dateStart }}
          <i class="bi bi-x" />
        </BBadge>
        <BBadge
          v-if="dateEnd"
          variant="secondary"
          class="d-flex align-items-center gap-1"
          style="cursor: pointer"
          @click="$emit('update:dateEnd', null)"
        >
          To: {{ dateEnd }}
          <i class="bi bi-x" />
        </BBadge>
      </BCol>
    </BRow>

    <div class="px-3 pb-2">
      <IconLegend :legend-items="legendItems" />
    </div>

    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <!--
      The BTable prop types (`TableField<T>`, `BTableSortBy`) are tightly
      parameterised in bootstrap-vue-next. We carry plain shapes on the
      props boundary so the view stays portable; a single `any` cast here
      bridges to BVN without polluting the public API of this component.
    -->
    <!-- eslint-disable @typescript-eslint/no-explicit-any -->
    <BTable
      v-else
      :items="(items as any)"
      :fields="(fields as any)"
      :busy="isBusy"
      :current-page="currentPage"
      :per-page="perPage"
      :filter="filterText"
      :sort-by="(sortBy as any)"
      stacked="md"
      head-variant="light"
      show-empty
      small
      fixed
      striped
      hover
      sort-icon-left
      @update:sort-by="(e: any) => $emit('update:sortBy', e as SortBy[])"
      @filtered="(e: any) => $emit('filtered', e as unknown[])"
    >
      <!-- Expose BTable slots to the parent so row templates stay there. -->
      <template
        v-for="(_, slotName) in $slots"
        :key="slotName"
        #[slotName]="slotProps"
      >
        <slot :name="slotName" v-bind="slotProps || {}" />
      </template>
    </BTable>
  </BCard>
</template>

<script setup lang="ts">
import type { PropType } from 'vue';
import type { SortBy, TableField } from '@/types/components';
import IconLegend from '@/components/accessibility/IconLegend.vue';

export interface LegendItem {
  icon: string;
  color?: string;
  label: string;
}

defineProps({
  title: { type: String, default: 'Approve Reviews' },
  /** Plural resource noun rendered in the "X reviews" badge — override for status/other streams. */
  totalRowsLabel: { type: String, default: 'reviews' },
  /** Tooltip text on the "Approve All" button. */
  approveAllTitle: { type: String, default: 'Approve all pending reviews' },
  /** aria-label on the "Approve All" button. */
  approveAllAriaLabel: { type: String, default: 'Approve all reviews' },
  items: { type: Array as PropType<unknown[]>, required: true },
  fields: { type: Array as PropType<TableField[]>, required: true },
  totalRows: { type: Number, required: true },
  currentPage: { type: Number, required: true },
  perPage: { type: Number, required: true },
  pageOptions: { type: Array as PropType<number[]>, required: true },
  sortBy: { type: Array as PropType<SortBy[]>, required: true },
  filterText: { type: String as PropType<string | null>, default: null },
  categoryFilter: { type: String as PropType<string | null>, default: null },
  userFilter: { type: String as PropType<string | null>, default: null },
  dateStart: { type: String as PropType<string | null>, default: null },
  dateEnd: { type: String as PropType<string | null>, default: null },
  categoryOptions: {
    type: Array as PropType<Array<{ value: string | null; text: string }>>,
    required: true,
  },
  userOptions: {
    type: Array as PropType<Array<{ value: string | null; text: string }>>,
    required: true,
  },
  legendItems: { type: Array as PropType<LegendItem[]>, required: true },
  isBusy: { type: Boolean, default: false },
  loading: { type: Boolean, default: false },
});

defineEmits<{
  (e: 'approve-all'): void;
  (e: 'refresh'): void;
  (e: 'update:currentPage', value: number): void;
  (e: 'update:perPage', value: number): void;
  (e: 'update:sortBy', value: SortBy[]): void;
  (e: 'update:filterText', value: string): void;
  (e: 'update:categoryFilter', value: string | null): void;
  (e: 'update:userFilter', value: string | null): void;
  (e: 'update:dateStart', value: string | null): void;
  (e: 'update:dateEnd', value: string | null): void;
  (e: 'filtered', value: unknown[]): void;
}>();
</script>

<!-- views/review/components/ReviewQueueTable.vue -->
<!--
  Re-review queue table extracted from `Review.vue` during W6 of v11.1
  finish-hardening. Owns the BCard wrapper, the icon legend, the search
  + column-filter + quick-filter row, the pagination controls, and the
  BTable itself with all its cell templates.

  All state is owned by the parent's composables — this component is a
  presentational shell. Filter v-models pass through via `update:*`
  emits; row-action clicks emit `info-review` / `info-status` /
  `info-submit` / `info-approve`. The parent decides how to react.

  Cell templates that bind on the row data live HERE because they are
  table-internal (each row's badges + icons are not orchestration). The
  per-row UI components (`EntityBadge`, `GeneBadge`, …) are imported
  locally so the parent doesn't carry their registration anymore.
-->
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
            Re-review table
            <BBadge variant="primary" class="ms-2"> {{ totalRows }} entities </BBadge>
          </h5>
        </BCol>
        <BCol class="text-end">
          <div class="d-flex align-items-center justify-content-end gap-2">
            <!-- Curation mode switch -->
            <BFormCheckbox
              v-if="curatorMode"
              :model-value="curationSelected"
              switch
              size="sm"
              class="mb-0 text-light"
              @update:model-value="$emit('update:curationSelected', $event)"
            >
              Curation mode
            </BFormCheckbox>

            <!-- User info (compact) -->
            <span class="d-none d-md-inline text-light small">
              <i :class="'bi bi-' + userIcon[user.user_role[0]]" />
              {{ user.user_name[0] }}
            </span>

            <!-- Refresh button -->
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

    <!-- Icon Legend -->
    <div class="px-3 pt-2">
      <IconLegend :legend-items="legendItems" title="Category & Re-review Status Icons" />
    </div>

    <!-- Search, filters, and pagination row (single consolidated row) -->
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
            :model-value="filter"
            type="search"
            placeholder="Search any field..."
            debounce="500"
            @update:model-value="$emit('update:filter', $event)"
          />
        </BInputGroup>
      </BCol>

      <BCol cols="6" md="2" lg="2" class="mb-2 mb-md-0">
        <BFormSelect
          :model-value="categoryFilter"
          size="sm"
          :options="categoryFilterOptions"
          aria-label="Filter by category"
          @update:model-value="$emit('update:categoryFilter', $event)"
        />
      </BCol>
      <BCol cols="6" md="2" lg="2" class="mb-2 mb-md-0">
        <BFormSelect
          :model-value="userFilter"
          size="sm"
          :options="userFilterOptions"
          aria-label="Filter by user"
          @update:model-value="$emit('update:userFilter', $event)"
        />
      </BCol>

      <BCol
        cols="12"
        md="4"
        lg="5"
        class="d-flex align-items-center justify-content-end gap-2 flex-wrap"
      >
        <div class="d-flex align-items-center flex-wrap gap-1 me-2">
          <BBadge
            v-for="qf in activeQuickFilters"
            :key="qf.key"
            variant="secondary"
            class="d-flex align-items-center gap-1"
            style="cursor: pointer"
            @click="$emit('remove-quick-filter', qf.key)"
          >
            {{ qf.label }}
            <i class="bi bi-x" />
          </BBadge>
          <BDropdown
            v-if="availableQuickFilters.length > 0"
            size="sm"
            variant="outline-secondary"
            text="+ Filter"
            class="quick-filter-dropdown"
            toggle-class="py-0 px-2"
          >
            <BDropdownItem
              v-for="qf in availableQuickFilters"
              :key="qf.key"
              @click="$emit('add-quick-filter', qf.key)"
            >
              {{ qf.label }}
            </BDropdownItem>
          </BDropdown>
          <BBadge
            v-if="totalRows === 0 && (filter === null || filter === '') && !curationSelected"
            variant="warning"
            pill
            style="cursor: pointer"
            @click="$emit('new-batch')"
          >
            <i class="bi bi-plus-circle me-1" />
            New batch
          </BBadge>
        </div>

        <BInputGroup prepend="Per page" size="sm">
          <BFormSelect
            id="per-page-select"
            :model-value="perPage"
            :options="pageOptions"
            size="sm"
            @update:model-value="$emit('update:perPage', $event)"
          />
        </BInputGroup>

        <BPagination
          :model-value="currentPage"
          :total-rows="totalRows"
          :per-page="perPage"
          size="sm"
          class="mb-0"
          limit="2"
          @update:model-value="$emit('update:currentPage', $event)"
        />
      </BCol>
    </BRow>

    <BTable
      :items="filteredItems"
      :fields="fields"
      :busy="isBusy"
      :current-page="currentPage"
      :per-page="perPage"
      :filter="filter"
      :filter-included-fields="filterOn"
      :sort-by="sortBy"
      stacked="md"
      head-variant="light"
      show-empty
      small
      fixed
      striped
      hover
      sort-icon-left
      :empty-text="emptyText"
      @update:sort-by="$emit('update:sortBy', $event)"
      @filtered="$emit('filtered', $event)"
    >
      <template #cell(actions)="row">
        <BButton
          v-b-tooltip.hover.left
          size="sm"
          class="me-1 btn-xs"
          variant="outline-primary"
          title="Edit review"
          :aria-label="`Edit review for sysndd:${row.item.entity_id}`"
          @click="$emit('info-review', row.item, row.index, $event.target)"
        >
          <i class="bi bi-pencil-square" aria-hidden="true" />
        </BButton>

        <BButton
          v-b-tooltip.hover.top
          size="sm"
          class="me-1 btn-xs"
          variant="outline-secondary"
          title="Edit status"
          :aria-label="`Edit status for sysndd:${row.item.entity_id}`"
          @click="$emit('info-status', row.item, row.index, $event.target)"
        >
          <i class="bi bi-stoplights" aria-hidden="true" />
        </BButton>

        <BButton
          v-if="!curationSelected"
          v-b-tooltip.hover.top
          size="sm"
          class="me-1 btn-xs"
          :variant="row.item.re_review_review_saved ? 'success' : 'outline-success'"
          title="Submit entity review"
          :aria-label="`Submit review for sysndd:${row.item.entity_id}`"
          @click="$emit('info-submit', row.item, row.index, $event.target)"
        >
          <i class="bi bi-send-check" aria-hidden="true" />
        </BButton>

        <BButton
          v-if="curationSelected"
          v-b-tooltip.hover.right
          size="sm"
          class="me-1 btn-xs"
          variant="danger"
          title="Approve entity review/status"
          :aria-label="`Approve review/status for sysndd:${row.item.entity_id}`"
          @click="$emit('info-approve', row.item, row.index, $event.target)"
        >
          <i class="bi bi-check-circle-fill" aria-hidden="true" />
        </BButton>
      </template>

      <template #cell(entity_id)="data">
        <EntityBadge
          :entity-id="data.item.entity_id"
          :link-to="'/Entities/' + data.item.entity_id"
          size="sm"
        />
      </template>

      <template #cell(symbol)="data">
        <GeneBadge
          :symbol="data.item.symbol"
          :hgnc-id="data.item.hgnc_id"
          :link-to="'/Genes/' + data.item.hgnc_id"
          size="sm"
        />
      </template>

      <template #cell(disease_ontology_name)="data">
        <DiseaseBadge
          :name="data.item.disease_ontology_name"
          :ontology-id="data.item.disease_ontology_id_version"
          :link-to="
            '/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')
          "
          :max-length="35"
          size="sm"
        />
      </template>

      <template #cell(hpo_mode_of_inheritance_term_name)="data">
        <InheritanceBadge
          :full-name="data.item.hpo_mode_of_inheritance_term_name"
          :hpo-term="data.item.hpo_mode_of_inheritance_term"
          size="sm"
        />
      </template>

      <template #cell(category)="data">
        <div class="overflow-hidden text-truncate text-center">
          <span v-if="data.item.category" v-b-tooltip.hover.top :title="data.item.category">
            <CategoryIcon :category="data.item.category" size="sm" :show-title="false" />
          </span>
          <span v-else class="text-muted">—</span>
        </div>
      </template>

      <template #cell(ndd_phenotype_word)="data">
        <div class="overflow-hidden text-truncate text-center">
          <span v-b-tooltip.hover.left :title="nddIconText[data.item.ndd_phenotype_word]">
            <NddIcon :status="data.item.ndd_phenotype_word" size="sm" :show-title="false" />
          </span>
        </div>
      </template>

      <template #cell(review_date)="data">
        <div class="d-flex align-items-center gap-1">
          <span
            v-b-tooltip.hover.top
            :title="dataAgeText[dateYearAge(data.item.review_date, 3)]"
            class="d-inline-flex align-items-center justify-content-center rounded-circle"
            :class="`bg-${dataAgeStyle[dateYearAge(data.item.review_date, 3)]}-subtle text-${dataAgeStyle[dateYearAge(data.item.review_date, 3)]}`"
            style="width: 24px; height: 24px; font-size: 0.75rem"
          >
            <i class="bi bi-calendar3" />
          </span>
          <span class="small text-muted">
            {{ data.item.review_date.substring(0, 10) }}
          </span>
        </div>
      </template>

      <template #cell(review_user_name)="data">
        <div class="d-flex align-items-center gap-1">
          <span
            v-b-tooltip.hover.top
            :title="data.item.review_user_role"
            class="d-inline-flex align-items-center justify-content-center rounded-circle"
            :class="`bg-${userStyle[data.item.review_user_role]}-subtle text-${userStyle[data.item.review_user_role]}`"
            style="width: 24px; height: 24px; font-size: 0.75rem"
          >
            <i :class="'bi bi-' + userIcon[data.item.review_user_role]" />
          </span>
          <span class="small">
            {{ data.item.review_user_name }}
          </span>
        </div>
      </template>
    </BTable>
  </BCard>
</template>

<script>
import IconLegend from '@/components/accessibility/IconLegend.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';

export default {
  name: 'ReviewQueueTable',
  components: {
    IconLegend,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
    CategoryIcon,
    NddIcon,
  },
  props: {
    // Data
    filteredItems: { type: Array, required: true },
    fields: { type: Array, required: true },
    isBusy: { type: Boolean, default: false },
    totalRows: { type: Number, required: true },
    legendItems: { type: Array, required: true },
    user: { type: Object, required: true },
    curatorMode: { type: [Boolean, Number], default: 0 },
    emptyText: { type: String, default: '' },

    // Filter state (v-model bindings)
    filter: { type: String, default: null },
    filterOn: { type: Array, default: () => [] },
    categoryFilter: { type: String, default: null },
    userFilter: { type: String, default: null },
    sortBy: { type: Array, default: () => [] },

    categoryFilterOptions: { type: Array, default: () => [] },
    userFilterOptions: { type: Array, default: () => [] },
    activeQuickFilters: { type: Array, default: () => [] },
    availableQuickFilters: { type: Array, default: () => [] },

    // Pagination
    currentPage: { type: Number, default: 1 },
    perPage: { type: Number, default: 25 },
    pageOptions: { type: Array, default: () => [10, 25, 50, 100] },

    curationSelected: { type: Boolean, default: false },

    // Design tokens
    userIcon: { type: Object, default: () => ({}) },
    userStyle: { type: Object, default: () => ({}) },
    nddIconText: { type: Object, default: () => ({}) },
    dataAgeText: { type: Object, default: () => ({}) },
    dataAgeStyle: { type: Object, default: () => ({}) },

    // Per-row helpers
    dateYearAge: { type: Function, required: true },
  },
  emits: [
    'refresh',
    'new-batch',
    'add-quick-filter',
    'remove-quick-filter',
    'info-review',
    'info-status',
    'info-submit',
    'info-approve',
    'filtered',
    'update:filter',
    'update:categoryFilter',
    'update:userFilter',
    'update:sortBy',
    'update:currentPage',
    'update:perPage',
    'update:curationSelected',
  ],
};
</script>

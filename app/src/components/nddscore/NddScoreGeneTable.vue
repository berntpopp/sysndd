<template>
  <TableShell
    title="Gene predictions"
    :meta="totalLabel"
    description="Machine-learning NDDScore gene association predictions from the active release; these are not manually curated SysNDD classifications."
    :loading="tableShellLoading"
  >
    <template #actions>
      <div class="mb-1 text-end">
        <TableDownloadLinkCopyButtons
          :downloading="isExporting"
          remove-filters-title="Click to remove all filters."
          :remove-filters-variant="hasActiveFilters ? 'warning' : 'info'"
          @request-excel="requestExcel"
          @copy-link="copyLinkToClipboard"
          @remove-filters="removeFilters"
        />
      </div>
    </template>

    <template #toolbar>
      <BRow>
        <BCol class="my-1" sm="8">
          <TableSearchInput
            v-model="search"
            placeholder="Search gene symbol or HGNC ID"
            :debounce-time="350"
            :loading="loading"
            @update:model-value="handleSearchChange"
            @clear="handleSearchChange"
          />
        </BCol>

        <BCol class="my-1" sm="4">
          <BContainer>
            <TablePaginationControls
              :total-rows="total"
              :initial-per-page="pageSize"
              :current-page="page"
              :page-options="[10, 25, 50, 100]"
              @page-change="handlePageChange"
              @per-page-change="handlePageSizeChange"
            />
          </BContainer>
        </BCol>
      </BRow>
    </template>

    <!-- Desktop: fixed-layout prediction table -->
    <div class="d-none d-md-block">
      <GenericTable
        :items="rows"
        :fields="fields"
        :sort-by="sortBy"
        :fixed-layout="true"
        :stacked-mode="false"
        :is-busy="loading"
        @update-sort="handleSortUpdate"
      >
        <template #column-header="{ data }">
          <div
            class="nddscore-gene-table__col-label"
            :aria-label="data.label"
            :aria-describedby="columnHelp[data.column] ? `col-help-${data.column}` : undefined"
          >
            {{ data.label }}
            <span
              v-if="columnHelp[data.column]"
              :id="`col-help-${data.column}`"
              class="visually-hidden"
            >{{ columnHelp[data.column] }}</span>
            <i
              v-if="columnHelp[data.column]"
              v-b-tooltip.hover.bottom
              :title="columnHelp[data.column]"
              class="bi bi-info-circle ms-1 nddscore-gene-table__col-help"
              aria-hidden="true"
            />
          </div>
        </template>

        <template #filter-controls>
          <td v-for="field in fields" :key="field.key" role="presentation">
            <BDropdown
              v-if="field.filterType === 'range'"
              :auto-close="false"
              variant="outline-secondary"
              size="sm"
              :class="rangeFilterDropdownClass(field)"
              :toggle-class="rangeFilterToggleClass(field)"
              menu-class="nddscore-gene-table__filter-menu"
              :aria-label="`${field.label} filter: ${rangeFilterLabel(field)}`"
            >
              <template #button-content>
                {{ rangeFilterLabel(field) }}
              </template>

              <BDropdownForm class="nddscore-gene-table__range-menu" @submit.prevent>
                <BFormSelect
                  v-model="rangeFilters[rangeKey(field.key)].operator"
                  :options="rangeOperatorOptions"
                  size="sm"
                  :aria-label="`${field.label} filter operator`"
                  @update:model-value="handleRangeOperatorChange(field.key)"
                />
                <BFormInput
                  v-if="rangeFilters[rangeKey(field.key)].operator !== 'any'"
                  v-model="rangeFilters[rangeKey(field.key)].value"
                  :aria-label="`${field.label} filter value`"
                  :placeholder="rangeValuePlaceholder(field)"
                  type="number"
                  :step="field.numericStep ?? '1'"
                  size="sm"
                  @click="removeSearch"
                  @update:model-value="handleColumnFilterChange"
                />
                <BFormInput
                  v-if="rangeFilters[rangeKey(field.key)].operator === 'range'"
                  v-model="rangeFilters[rangeKey(field.key)].valueMax"
                  :aria-label="`${field.label} upper filter value`"
                  placeholder="to"
                  type="number"
                  :step="field.numericStep ?? '1'"
                  size="sm"
                  @click="removeSearch"
                  @update:model-value="handleColumnFilterChange"
                />
              </BDropdownForm>
              <BDropdownDivider />
              <div class="nddscore-gene-table__filter-actions">
                <BButton
                  variant="link"
                  size="sm"
                  class="text-decoration-none p-0"
                  :disabled="rangeFilters[rangeKey(field.key)].operator === 'any'"
                  @click="clearRangeFilter(field.key)"
                >
                  Clear
                </BButton>
              </div>
            </BDropdown>

            <BFormInput
              v-else-if="field.filterType === 'text'"
              v-model="columnFilters[field.key]"
              :placeholder="'Filter ' + field.label"
              :aria-label="`Filter by ${field.label}`"
              type="search"
              autocomplete="off"
              size="sm"
              class="nddscore-gene-table__filter-control"
              @click="removeSearch"
              @update:model-value="handleColumnFilterChange"
            />

            <BFormSelect
              v-else-if="field.filterType === 'select'"
              v-model="columnFilters[field.key]"
              :options="selectOptionsFor(field)"
              size="sm"
              :aria-label="`Filter by ${field.label}`"
              :class="filterControlClass(field.key)"
              @update:model-value="
                removeSearch();
                handleColumnFilterChange();
              "
            />

            <BDropdown
              v-else-if="field.filterType === 'multi-select'"
              :auto-close="false"
              variant="outline-secondary"
              size="sm"
              :class="hpoFilterDropdownClass"
              :toggle-class="hpoFilterToggleClass"
              menu-class="nddscore-gene-table__hpo-menu"
              :aria-label="`Predicted HPO terms filter: ${hpoFilterLabel}`"
              data-testid="nddscore-hpo-filter"
            >
              <template #button-content>
                {{ hpoFilterLabel }}
              </template>

              <BDropdownForm @submit.prevent>
                <BFormInput
                  v-model="hpoTermSearch"
                  placeholder="Search HPO terms"
                  type="search"
                  size="sm"
                  autocomplete="off"
                  aria-label="Search HPO terms"
                />
              </BDropdownForm>
              <BDropdownDivider />
              <div class="nddscore-gene-table__hpo-options">
                <BDropdownItemButton
                  v-for="option in filteredHpoTermOptions"
                  :key="option.value"
                  :active="hpoTermFilter.includes(option.value)"
                  :data-testid="`nddscore-hpo-option-${option.value}`"
                  @click="toggleHpoTerm(option.value)"
                >
                  <i
                    class="bi me-2"
                    :class="
                      hpoTermFilter.includes(option.value)
                        ? 'bi-check-square text-primary'
                        : 'bi-square text-muted'
                    "
                    aria-hidden="true"
                  />
                  {{ option.text }}
                </BDropdownItemButton>
                <BDropdownText v-if="filteredHpoTermOptions.length === 0">
                  No matching HPO terms
                </BDropdownText>
              </div>
              <BDropdownDivider />
              <div class="nddscore-gene-table__filter-actions">
                <BButton
                  variant="link"
                  size="sm"
                  class="text-decoration-none p-0"
                  :disabled="!hpoTermFilter.length"
                  @click="clearHpoTerms"
                >
                  Clear
                </BButton>
              </div>
            </BDropdown>
          </td>
        </template>

        <template #cell-gene_symbol="{ row }">
          <GeneBadge
            :symbol="displayValue(row.gene_symbol)"
            :hgnc-id="displayValue(row.hgnc_id)"
            :link-to="detailPath(row)"
            size="sm"
          />
        </template>

        <template #cell-hgnc_id="{ row }">
          <RouterLink class="nddscore-gene-table__id-link" :to="detailPath(row)">
            {{ displayValue(row.hgnc_id) }}
          </RouterLink>
        </template>

        <template #cell-ndd_score="{ row }">
          <span class="nddscore-gene-table__numeric">{{ formatDecimal(row.ndd_score, 3) }}</span>
        </template>

        <template #cell-rank="{ row }">
          <span class="nddscore-gene-table__numeric">{{ displayValue(row.rank) }}</span>
        </template>

        <template #cell-percentile="{ row }">
          <span class="nddscore-gene-table__numeric">{{ formatPercentile(row.percentile) }}</span>
        </template>

        <template #cell-risk_tier="{ row }">
          <span :class="['sysndd-chip', riskChipClass(row.risk_tier)]">
            {{ displayValue(row.risk_tier) }}
          </span>
        </template>

        <template #cell-confidence_tier="{ row }">
          <span :class="['sysndd-chip', confidenceChipClass(row.confidence_tier)]">
            {{ displayValue(row.confidence_tier) }}
          </span>
        </template>

        <template #cell-known_sysndd_gene="{ row }">
          <RouterLink
            v-if="isKnownGene(row.known_sysndd_gene)"
            v-b-tooltip.hover.left
            :to="`/Genes/${row.hgnc_id}`"
            class="nddscore-gene-table__gene-link sysndd-chip sysndd-chip--blue"
            title="Open the curated SysNDD gene page for this HGNC identifier."
          >
            Known
          </RouterLink>
          <span v-else class="sysndd-chip sysndd-chip--neutral">New</span>
        </template>

        <template #cell-model_split="{ row }">
          <span class="sysndd-chip sysndd-chip--neutral nddscore-gene-table__chip">
            {{ displayValue(row.model_split) }}
          </span>
        </template>

        <template #cell-top_inheritance_mode="{ row }">
          <span class="sysndd-chip sysndd-chip--blue nddscore-gene-table__chip">
            {{ displayValue(row.top_inheritance_mode) }}
          </span>
        </template>

        <template #cell-top_hpo_predictions_json="{ row }">
          <span
            v-b-tooltip.hover.left
            class="nddscore-gene-table__hpo"
            :title="topHpoTooltip(row.top_hpo_predictions_json)"
          >
            {{ topHpoLabel(row.top_hpo_predictions_json, row.n_predicted_hpo) }}
          </span>
        </template>
      </GenericTable>
    </div>

    <!-- Mobile: purpose-built prediction record rows -->
    <div class="d-md-none">
      <NddScoreGeneMobileRows :items="rows" />
    </div>

    <div v-if="!loading && !rows.length" class="nddscore-gene-table__empty">
      No gene predictions found.
    </div>
    <BAlert v-if="loadError" variant="warning" show class="mt-3 mb-0">
      <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
      {{ loadError }}
    </BAlert>
  </TableShell>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router';
import {
  BAlert,
  BButton,
  BCol,
  BContainer,
  BDropdown,
  BDropdownDivider,
  BDropdownForm,
  BDropdownItemButton,
  BDropdownText,
  BFormInput,
  BFormSelect,
  BRow,
} from 'bootstrap-vue-next';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import NddScoreGeneMobileRows from './NddScoreGeneMobileRows.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import {
  displayValue,
  formatDecimal,
  formatPercentile,
  isKnownGene,
  topHpoLabel,
  topHpoTooltip,
} from './nddScoreGeneTableFormatters';
import { useNddScoreGeneTable } from './useNddScoreGeneTable';

defineOptions({
  name: 'NddScoreGeneTable',
});

/** Map risk_tier values to AA-compliant sysndd-chip modifier classes. */
function riskChipClass(value: unknown): string {
  switch (String(value).toLowerCase()) {
    case 'very high':
    case 'high':
      return 'sysndd-chip--danger';
    case 'moderate':
      return 'sysndd-chip--warning';
    case 'low':
    case 'very low':
      return 'sysndd-chip--neutral';
    default:
      return 'sysndd-chip--neutral';
  }
}

/** Map confidence_tier values to AA-compliant sysndd-chip modifier classes. */
function confidenceChipClass(value: unknown): string {
  switch (String(value).toLowerCase()) {
    case 'high':
      return 'sysndd-chip--success';
    case 'medium':
    case 'moderate':
      return 'sysndd-chip--info';
    default:
      return 'sysndd-chip--neutral';
  }
}

const {
  rows,
  total,
  page,
  pageSize,
  loading,
  loadError,
  search,
  hpoTermFilter,
  hpoTermSearch,
  isExporting,
  rangeOperatorOptions,
  fields,
  columnFilters,
  rangeFilters,
  columnHelp,
  totalLabel,
  tableShellLoading,
  hasActiveFilters,
  sortBy,
  filteredHpoTermOptions,
  hpoFilterLabel,
  hpoFilterToggleClass,
  hpoFilterDropdownClass,
  selectOptionsFor,
  rangeKey,
  rangeValuePlaceholder,
  rangeFilterLabel,
  rangeFilterToggleClass,
  rangeFilterDropdownClass,
  filterControlClass,
  handleRangeOperatorChange,
  clearRangeFilter,
  toggleHpoTerm,
  clearHpoTerms,
  requestExcel,
  copyLinkToClipboard,
  removeFilters,
  handleSearchChange,
  handleColumnFilterChange,
  handleSortUpdate,
  handlePageChange,
  handlePageSizeChange,
  removeSearch,
  detailPath,
} = useNddScoreGeneTable();
</script>

<style scoped src="./NddScoreGeneTable.styles.css"></style>

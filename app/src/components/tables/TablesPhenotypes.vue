<template>
  <div class="container-fluid py-2">
    <TableShell
      title="Phenotype search"
      :heading-level="headingLevel"
      :meta="`Associated entities: ${totalRows}`"
      :description="`Loaded ${perPage}/${totalRows} in ${executionTime}`"
      :loading="loading"
    >
      <template v-if="!loading && showFilterControls" #actions>
        <BButton
          v-b-tooltip.hover.bottom
          class="me-1"
          size="sm"
          title="Download data as Excel file."
          @click="requestSelectedExcel()"
        >
          <i class="bi bi-table mx-1" />
          <i v-if="!downloading" class="bi bi-download" />
          <BSpinner v-if="downloading" small />
          .xlsx
        </BButton>

        <BButton
          v-b-tooltip.hover.bottom
          class="me-1"
          size="sm"
          title="Copy link to this page."
          aria-label="Copy link to this page"
          variant="success"
          @click="copyLinkToClipboard()"
        >
          <i class="bi bi-link" />
        </BButton>

        <BButton
          v-b-tooltip.hover.bottom
          size="sm"
          class="me-1"
          aria-label="Remove all filters"
          :title="
            'The table is ' +
            (filter_string === '' || filter_string === null || filter_string === 'null'
              ? 'not'
              : '') +
            ' filtered.' +
            (filter_string === '' || filter_string === null || filter_string === 'null'
              ? ''
              : ' Click to remove all filters.')
          "
          :variant="
            filter_string === '' || filter_string === null || filter_string === 'null'
              ? 'info'
              : 'warning'
          "
          @click="removeFilters()"
        >
          <i class="bi bi-filter" />
        </BButton>
      </template>

      <template v-if="!loading" #toolbar>
        <BRow class="align-items-center gx-2">
          <BCol class="my-1" sm="6">
            <PhenotypeFilterToolbar
              v-if="showFilterControls"
              :phenotype-options="phenotypes_options"
              :selected-ids="filter.modifier_phenotype_id.content"
              @toggle="togglePhenotype"
              @remove="removePhenotype"
              @clear-all="clearAllPhenotypes"
            />
          </BCol>

          <BCol class="my-1 d-flex align-items-center" sm="2">
            <div class="logic-toggle">
              <button
                type="button"
                class="logic-btn"
                :class="{ active: !checked }"
                @click="setLogicMode(false)"
              >
                AND
              </button>
              <button
                type="button"
                class="logic-btn"
                :class="{ active: checked }"
                @click="setLogicMode(true)"
              >
                OR
              </button>
            </div>
          </BCol>

          <BCol class="my-1" sm="4">
            <TablePaginationControls
              v-if="totalRows > perPage || showPaginationControls"
              :total-rows="totalRows"
              :initial-per-page="perPage"
              :page-options="pageOptions"
              :current-page="currentPage"
              @page-change="handlePageChange"
              @per-page-change="handlePerPageChange"
            />
          </BCol>
        </BRow>
      </template>

      <template #loading>
        <TableLoadingState label="Loading phenotype-associated entities" />
      </template>

      <div class="d-none d-md-block">
        <BTable
          :items="items"
          :fields="fields"
          :sort-by="sortBy"
          :busy="isBusy"
          :stacked="false"
          head-variant="light"
          show-empty
          small
          fixed
          hover
          class="public-data-table"
          sort-icon-left
          no-local-sorting
          @update:sort-by="handleSortByUpdate"
        >
          <!-- custom formatted header -->
          <template #head()="data">
            <!-- Tooltip via directive VALUE (not :title) so counts update on filter; see AGENTS.md (bvn v-b-tooltip). -->
            <div
              v-b-tooltip.hover.top="
                getTooltipText(
                  fields.find((f) => f.label === data.label) || {
                    key: data.column,
                    label: data.label,
                  }
                )
              "
            >
              {{ truncate(data.label.replace(/( word)|( name)/g, ''), 20) }}
            </div>
          </template>

          <!-- Filter row in table header - Bootstrap-Vue-Next uses #thead-top instead of slot="top-row" -->
          <!-- role="presentation" removes the row from the table accessibility tree so
               axe/Lighthouse does not flag the filter <td> cells as lacking column headers
               (td-has-header). Filter inputs are independently labelled via aria-label. -->
          <template #thead-top>
            <tr v-if="showFilterControls" role="presentation">
              <td v-for="field in fields" :key="field.key" role="presentation">
                <BFormInput
                  v-if="field.filterable"
                  v-model="filter[field.key].content"
                  :placeholder="' .. ' + truncate(field.label, 20) + ' .. '"
                  :aria-label="'Filter by ' + field.label"
                  debounce="500"
                  type="search"
                  autocomplete="off"
                  @click="removeSearch()"
                  @update:model-value="filtered()"
                />

                <!-- TODO: treeselect disabled pending Bootstrap-Vue-Next migration -->
                <label
                  v-if="field.selectable"
                  :for="'select_' + field.key"
                  :aria-label="'Filter by ' + field.label"
                >
                  <BFormSelect
                    :id="'select_' + field.key"
                    v-model="filter[field.key].content"
                    :options="field.selectOptions"
                    size="sm"
                    @update:model-value="
                      removeSearch();
                      filtered();
                    "
                  >
                    <template #first>
                      <BFormSelectOption :value="null">
                        .. {{ truncate(field.label, 20) }} ..
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>
                </label>

                <!-- TODO: treeselect disabled pending Bootstrap-Vue-Next migration -->
                <label
                  v-if="
                    field.multi_selectable && field.selectOptions && field.selectOptions.length > 0
                  "
                  :for="'multiselect_' + field.key"
                  :aria-label="'Filter by ' + field.label"
                >
                  <BFormSelect
                    :id="'multiselect_' + field.key"
                    v-model="filter[field.key].content"
                    :options="normalizeSelectOptions(field.selectOptions)"
                    size="sm"
                    @update:model-value="
                      removeSearch();
                      filtered();
                    "
                  >
                    <template #first>
                      <BFormSelectOption :value="null">
                        .. {{ truncate(field.label, 20) }} ..
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>
                </label>
              </td>
            </tr>
          </template>

          <template #cell(details)="row">
            <BButton
              class="btn-xs fw-semibold"
              variant="outline-primary"
              :aria-label="`${row.expansionShowing ? 'Hide' : 'Show'} details for entity ${
                row.item.entity_id
              }`"
              @click="row.toggleExpansion"
            >
              {{ row.expansionShowing ? 'Hide' : 'Show' }}
            </BButton>
          </template>

          <template #row-expansion="row">
            <BCard>
              <BTable :items="[row.item]" :fields="fields_details" stacked small />
            </BCard>
          </template>

          <template #cell(entity_id)="data">
            <EntityBadge
              :entity-id="data.item.entity_id"
              :link-to="withCurrentReturnTo('/Entities/' + data.item.entity_id)"
              size="sm"
            />
          </template>

          <template #cell(symbol)="data">
            <GeneBadge
              :symbol="data.item.symbol"
              :hgnc-id="data.item.hgnc_id"
              :link-to="withCurrentReturnTo('/Genes/' + data.item.hgnc_id)"
              size="sm"
            />
          </template>

          <template #cell(disease_ontology_name)="data">
            <DiseaseBadge
              :name="data.item.disease_ontology_name"
              :ontology-id="data.item.disease_ontology_id_version"
              :link-to="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"
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

          <template #cell(ndd_phenotype_word)="data">
            <span v-b-tooltip.hover.left :title="ndd_icon_text[data.item.ndd_phenotype_word]">
              <NddIcon :status="data.item.ndd_phenotype_word" size="sm" :show-title="false" />
            </span>
          </template>

          <template #cell(category)="data">
            <span v-b-tooltip.hover.left :title="data.item.category">
              <CategoryIcon :category="data.item.category" size="sm" :show-title="false" />
            </span>
          </template>
        </BTable>
      </div>

      <div class="d-md-none">
        <PhenotypesMobileRows :items="items" />
      </div>
    </TableShell>
  </div>
</template>

<script>
// Thin shell: all phenotype-table state/loading/cursor/url-sync lives in the
// usePhenotypeEntitiesTable composable; the phenotype multi-select toolbar
// markup lives in PhenotypeFilterToolbar.vue.
import { defineComponent } from 'vue';

// Import Bootstrap-Vue-Next BTable
import { BTable } from 'bootstrap-vue-next';

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

// Import table components
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableShell from '@/components/table/TableShell.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';
import PhenotypesMobileRows from '@/components/tables/PhenotypesMobileRows.vue';
import PhenotypeFilterToolbar from '@/components/tables/PhenotypeFilterToolbar.vue';

import { normalizeSelectOptions } from '@/utils/selectOptions';
import { usePhenotypeEntitiesTable } from './usePhenotypeEntitiesTable';

export default defineComponent({
  name: 'TablesPhenotypes',
  components: {
    BTable,
    CategoryIcon,
    NddIcon,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
    TablePaginationControls,
    TableShell,
    TableLoadingState,
    PhenotypesMobileRows,
    PhenotypeFilterToolbar,
  },
  props: {
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Phenotype table' },
    // Heading level for the TableShell title; standalone /Phenotypes passes 1 (default 2 when embedded).
    headingLevel: { type: Number, default: 2 },
    sortInput: { type: String, default: 'entity_id' },
    filterInput: { type: String, default: 'all(modifier_phenotype_id,HP:0001249)' },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default:
        'entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,modifier_phenotype_id',
    },
  },
  setup(props) {
    return {
      ...usePhenotypeEntitiesTable(props),
      // Shared select-option normalizer used by the table-header filter row.
      normalizeSelectOptions,
    };
  },
});
</script>

<style scoped>
/* Styles for TablesPhenotypes.vue.
   The phenotype multi-select control styles live in PhenotypeFilterToolbar.css;
   this file keeps the table-shell / logic-toggle styles owned by the parent. */

.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
.input-group > .input-group-prepend {
  flex: 0 0 35%;
}
.input-group .input-group-text {
  width: 100%;
}

/* AND/OR Toggle - Pill Button Group */
.logic-toggle {
  display: inline-flex;
  border: 1px solid #ced4da;
  border-radius: 20px;
  overflow: hidden;
  background: #f8f9fa;
}

.logic-btn {
  padding: 6px 14px;
  border: none;
  background: transparent;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--neutral-700);
  cursor: pointer;
  transition: all 0.15s ease;
}

.logic-btn:first-child {
  border-right: 1px solid var(--border-subtle);
}

.logic-btn:hover:not(.active) {
  background: var(--neutral-200);
}

.logic-btn.active {
  background: var(--medical-blue-700);
  color: #fff;
}
</style>

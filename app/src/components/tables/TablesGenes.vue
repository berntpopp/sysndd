<!-- components/tables/TablesGenes.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <TableShell
            :title="headerLabel"
            :heading-level="headingLevel"
            :meta="'Genes: ' + totalRows"
            :description="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
            :loading="loading"
          >
            <template v-if="!loading" #actions>
              <div v-if="showFilterControls" class="mb-1 text-end">
                <TableDownloadLinkCopyButtons
                  :downloading="downloading"
                  :remove-filters-title="removeFiltersButtonTitle"
                  :remove-filters-variant="removeFiltersButtonVariant"
                  @request-excel="requestExcel"
                  @copy-link="copyLinkToClipboard"
                  @remove-filters="removeFilters"
                />
              </div>
            </template>

            <template v-if="!loading" #toolbar>
              <!-- User Interface controls -->
              <BRow>
                <BCol class="my-1" sm="8">
                  <TableSearchInput
                    v-model="filter['any'].content"
                    :placeholder="'Search any field by typing here'"
                    :debounce-time="500"
                    @input="filtered"
                  />
                </BCol>

                <BCol class="my-1" sm="4">
                  <BContainer v-if="totalRows > perPage || showPaginationControls">
                    <TablePaginationControls
                      :total-rows="totalRows"
                      :initial-per-page="perPage"
                      :page-options="pageOptions"
                      :current-page="currentPage"
                      @page-change="handlePageChange"
                      @per-page-change="handlePerPageChange"
                    />
                  </BContainer>
                </BCol>
              </BRow>
              <!-- User Interface controls -->
            </template>

            <template #loading>
              <TableLoadingState mode="cards" />
            </template>

            <!-- Main table element -->
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
                  <tr role="presentation">
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
                          field.multi_selectable &&
                          field.selectOptions &&
                          field.selectOptions.length > 0
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
                    :aria-label="
                      (row.expansionShowing ? 'Hide details for ' : 'Show details for ') +
                      row.item.symbol
                    "
                    @click="row.toggleExpansion"
                  >
                    {{ row.expansionShowing ? 'Hide' : 'Show' }}
                  </BButton>
                </template>

                <template #row-expansion="row">
                  <BCard>
                    <BTable
                      :items="row.item.entities"
                      :fields="fields_details"
                      head-variant="light"
                      show-empty
                      small
                      fixed
                      sort-icon-left
                    >
                      <template #cell(entity_id)="data">
                        <EntityBadge
                          :entity-id="data.item.entity_id"
                          :link-to="withCurrentReturnTo('/Entities/' + data.item.entity_id)"
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

                      <template #cell(ndd_phenotype_word)="data">
                        <div
                          v-b-tooltip.hover.left
                          :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                        >
                          <NddIcon
                            :status="data.item.ndd_phenotype_word"
                            size="sm"
                            :show-title="false"
                          />
                        </div>
                      </template>

                      <template #cell(category)="data">
                        <div v-b-tooltip.hover.left :title="data.item.category">
                          <CategoryIcon
                            :category="data.item.category"
                            size="sm"
                            :show-title="false"
                          />
                        </div>
                      </template>

                      <template #cell(hpo_mode_of_inheritance_term_name)="data">
                        <InheritanceBadge
                          :full-name="data.item.hpo_mode_of_inheritance_term_name"
                          :hpo-term="data.item.hpo_mode_of_inheritance_term"
                          size="sm"
                        />
                      </template>
                    </BTable>
                  </BCard>
                </template>

                <template #cell(symbol)="data">
                  <GeneBadge
                    :symbol="data.item.symbol"
                    :hgnc-id="data.item.hgnc_id"
                    :link-to="withCurrentReturnTo('/Genes/' + data.item.hgnc_id)"
                    size="sm"
                  />
                </template>

                <template #cell(hpo_mode_of_inheritance_term_name)="data">
                  <div class="d-flex flex-wrap gap-1">
                    <InheritanceBadge
                      v-for="item in data.item.entities"
                      :key="item.hpo_mode_of_inheritance_term_name + item.entity_id"
                      :full-name="item.hpo_mode_of_inheritance_term_name"
                      :hpo-term="item.hpo_mode_of_inheritance_term"
                      size="sm"
                    />
                  </div>
                </template>

                <template #cell(category)="data">
                  <div class="d-flex flex-wrap gap-1">
                    <span
                      v-for="item in data.item.entities"
                      :key="item.category + item.entity_id"
                      v-b-tooltip.hover.left
                      :title="item.category"
                    >
                      <CategoryIcon :category="item.category" size="sm" :show-title="false" />
                    </span>
                  </div>
                </template>

                <template #cell(ndd_phenotype_word)="data">
                  <div class="d-flex flex-wrap gap-1">
                    <span
                      v-for="item in data.item.entities"
                      :key="item.ndd_phenotype_word + item.entity_id"
                      v-b-tooltip.hover.left
                      :title="ndd_icon_text[item.ndd_phenotype_word]"
                    >
                      <NddIcon :status="item.ndd_phenotype_word" size="sm" :show-title="false" />
                    </span>
                  </div>
                </template>

                <template #cell(entities_count)="data">
                  <BBadge variant="secondary" pill class="px-2">
                    {{ data.item.entities_count }}
                  </BBadge>
                </template>
              </BTable>
            </div>
            <div class="d-md-none">
              <GenesMobileRows :items="items" />
            </div>
          </TableShell>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
// Thin shell: all gene-table state/loading/cursor/url-sync lives in the
// useGenesTable composable; the static column/detail-field configuration
// lives in geneTableConfig.ts.
//
// TODO: vue3-treeselect disabled pending Bootstrap-Vue-Next migration
// import the Treeselect component
// import Treeselect from '@zanmato/vue3-treeselect';
// import the Treeselect styles
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';

import { defineComponent } from 'vue';

// Import Bootstrap-Vue-Next components
import { BTable, BCard } from 'bootstrap-vue-next';

// Import the Table components
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import TableShell from '@/components/table/TableShell.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';
import GenesMobileRows from '@/components/tables/GenesMobileRows.vue';

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';

import { normalizeSelectOptions } from '@/utils/selectOptions';
import { useGenesTable } from './useGenesTable';

export default defineComponent({
  name: 'TablesGenes',
  // TODO: Treeselect disabled pending Bootstrap-Vue-Next migration
  components: {
    // Components used within TablesGenes
    BTable,
    BCard,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    TableSearchInput,
    TableShell,
    TableLoadingState,
    GenesMobileRows,
    CategoryIcon,
    NddIcon,
    GeneBadge,
    InheritanceBadge,
    EntityBadge,
    DiseaseBadge,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'gene',
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Genes table' },
    // Heading level for the TableShell title; standalone /Genes passes 1 (default 2 when embedded).
    headingLevel: { type: Number, default: 2 },
    sortInput: { type: String, default: '+symbol' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default:
        'symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details',
    },
  },
  setup(props) {
    return {
      ...useGenesTable(props),
      // Shared select-option normalizer used by the table-header filter row.
      normalizeSelectOptions,
    };
  },
});
</script>

<style scoped>
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
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
:deep(.vue-treeselect__placeholder) {
  color: #6c757d !important;
}
:deep(.vue-treeselect__control) {
  color: #6c757d !important;
}
</style>

<!-- components/tables/TablesEntities.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <TableShell
            :title="headerLabel"
            :heading-level="headingLevel"
            :meta="'Entities: ' + totalRows"
            :description="'Loaded ' + perPage + '/' + totalRows + ' in ' + executionTime"
            :loading="loading"
          >
            <template #actions>
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

            <template #toolbar>
              <!-- User Interface controls -->
              <BRow v-if="showSearchInput || totalRows > perPage || showPaginationControls">
                <BCol v-if="showSearchInput" class="my-1" sm="8">
                  <TableSearchInput
                    v-model="filter['any'].content"
                    :placeholder="'Search any field by typing here'"
                    :debounce-time="500"
                    @update:model-value="filtered"
                  />
                </BCol>

                <BCol v-if="totalRows > perPage || showPaginationControls" class="my-1" sm="4">
                  <BContainer>
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
              <TableLoadingState :rows="skeletonRows" data-testid="entities-skeleton" />
            </template>

            <!-- Main table element -->
            <div class="d-none d-md-block">
              <GenericTable
                :items="items"
                :fields="fields"
                :field-details="fields_details"
                :sort-by="sortBy"
                :stacked-mode="false"
                @update-sort="handleSortUpdate"
              >
                <!-- Column header tooltips -->
                <template #column-header="{ data }">
                  <!-- Tooltip via directive VALUE (not :title) so counts update on filter; see AGENTS.md (bvn v-b-tooltip). -->
                  <div
                    v-b-tooltip.hover.bottom="
                      getTooltipText(
                        fields.find((f) => f.label === data.label) || {
                          key: data.column,
                          label: data.label,
                        }
                      )
                    "
                  >
                    {{ formatHeaderLabel(data.label) }}
                  </div>
                </template>

                <!-- Custom filter fields slot -->
                <template v-if="showFilterControls" #filter-controls>
                  <td v-for="field in fields" :key="field.key" role="presentation">
                    <BFormInput
                      v-if="field.filterable"
                      v-model="filter[field.key].content"
                      :placeholder="'Filter ' + field.label + '...'"
                      :aria-label="'Filter by ' + field.label"
                      debounce="500"
                      type="search"
                      autocomplete="off"
                      @click="removeSearch()"
                      @update:model-value="filtered()"
                    />

                    <label
                      v-if="
                        field.selectable && field.selectOptions && field.selectOptions.length > 0
                      "
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
                            Any {{ field.label }}
                          </BFormSelectOption>
                        </template>
                      </BFormSelect>
                    </label>
                    <BSpinner
                      v-else-if="
                        field.selectable &&
                        (!field.selectOptions || field.selectOptions.length === 0)
                      "
                      small
                      label="Loading..."
                    />

                    <!-- Multi-select: temporarily use BFormSelect instead of treeselect for compatibility -->
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
                            Any {{ field.label }}
                          </BFormSelectOption>
                        </template>
                      </BFormSelect>
                    </label>
                    <BSpinner
                      v-else-if="
                        field.multi_selectable &&
                        (!field.selectOptions || field.selectOptions.length === 0)
                      "
                      small
                      label="Loading..."
                    />
                  </td>
                </template>
                <!-- Custom filter fields slot -->

                <template #cell-entity_id="{ row }">
                  <EntityBadge
                    :entity-id="row.entity_id"
                    :link-to="withCurrentReturnTo('/Entities/' + row.entity_id)"
                    size="sm"
                  />
                </template>

                <template #cell-symbol="{ row }">
                  <GeneBadge
                    :symbol="row.symbol"
                    :hgnc-id="row.hgnc_id"
                    :link-to="withCurrentReturnTo('/Genes/' + row.hgnc_id)"
                    size="sm"
                  />
                </template>

                <template #cell-disease_ontology_name="{ row }">
                  <DiseaseBadge
                    :name="row.disease_ontology_name"
                    :ontology-id="row.disease_ontology_id_version"
                    :link-to="'/Ontology/' + row.disease_ontology_id_version.replace(/_.+/g, '')"
                    :max-length="35"
                    size="sm"
                  />
                </template>

                <!-- Custom slot for the 'hpo_mode_of_inheritance_term_name' column -->
                <template #cell-hpo_mode_of_inheritance_term_name="{ row }">
                  <InheritanceBadge
                    :full-name="row.hpo_mode_of_inheritance_term_name"
                    :hpo-term="row.hpo_mode_of_inheritance_term"
                    size="sm"
                  />
                </template>

                <!-- Custom slot for the 'ndd_phenotype_word' column -->
                <template #cell-ndd_phenotype_word="{ row }">
                  <span v-b-tooltip.hover.left :title="ndd_icon_text[row.ndd_phenotype_word]">
                    <NddIcon :status="row.ndd_phenotype_word" size="sm" :show-title="false" />
                  </span>
                </template>

                <!-- Custom slot for the 'category' column -->
                <template #cell-category="{ row }">
                  <span v-b-tooltip.hover.left :title="row.category">
                    <CategoryIcon :category="row.category" size="sm" :show-title="false" />
                  </span>
                </template>
                <!-- Custom slot for the 'category' column -->

                <!-- Row expansion extra: appended after GenericTable's default detail card.
                     The default card (with copy button and long-text class) is preserved;
                     we only inject the fetch trigger + LinkedOntologies strip here. -->
                <template #row-expansion-extra="{ row }">
                  <div @vue:mounted="fetchEntityMappings(row.entity_id)">
                    <LinkedOntologies
                      layout="strip"
                      :data="getEntityMappingState(row.entity_id).data"
                      :loading="getEntityMappingState(row.entity_id).loading"
                    />
                  </div>
                </template>
                <!-- Row expansion extra -->
              </GenericTable>
            </div>
            <div class="d-md-none">
              <EntitiesMobileRows :items="items" />
            </div>
            <!-- Main table element -->
          </TableShell>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
/**
 * TablesEntities Component
 *
 * This component is responsible for displaying and managing a table of entities.
 * It includes features such as a searchable input, pagination controls, and downloadable links.
 *
 * @component
 * @example
 * <TablesEntities
 *  showFilterControls={true}
 *  showSearchInput={true}
 *  showPaginationControls={true}
 *  headerLabel="Entities table"
 *  sortInput="+entity_id"
 *  filterInput={null}
 *  fieldsInput={null}
 *  pageAfterInput="0"
 *  pageSizeInput=10
 *  fspecInput="entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details"
 * />
 */

// Import the Table components
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import TableShell from '@/components/table/TableShell.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';
import EntitiesMobileRows from '@/components/tables/EntitiesMobileRows.vue';

// Import badge components
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

// Disease ontology outlinks
import LinkedOntologies from '@/components/disease/LinkedOntologies.vue';

// State/data-loading/URL-sync orchestration (issue #346)
import { useEntitiesTable } from './useEntitiesTable';

export default {
  name: 'TablesEntities',
  components: {
    // Components used within TablesEntities
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    TableSearchInput,
    GenericTable,
    TableShell,
    TableLoadingState,
    EntitiesMobileRows,
    CategoryIcon,
    NddIcon,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
    LinkedOntologies,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'entity',
    },
    showFilterControls: { type: Boolean, default: true },
    showSearchInput: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Entities table' },
    sortInput: { type: String, default: '+entity_id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default:
        'entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details',
    },
    disableUrlSync: { type: Boolean, default: false },
    // Heading level for the TableShell title. Standalone page (/Entities) passes 1;
    // embedded usages (e.g. the gene-detail "Associated" table) keep the default 2
    // so the page keeps exactly one route-level <h1>.
    headingLevel: { type: Number, default: 2 },
    // Number of skeleton rows to display while loading. Default is 8 (for full /Entities table),
    // embedded usage passes smaller values (e.g. 2 on gene detail) to match expected row count and prevent CLS.
    skeletonRows: { type: Number, default: 8 },
  },
  setup(props) {
    const table = useEntitiesTable(props);
    const formatHeaderLabel = (label) => {
      if (!label) return '';
      if (/hpo mode of inheritance/i.test(label)) return 'Inheritance';
      return table.truncate(label.replace(/( word)|( name)/g, ''), 20);
    };
    return {
      ...table,
      formatHeaderLabel,
    };
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

:deep(.entities-table thead th) {
  letter-spacing: 0;
}

/* Card styling improvements */
:deep(.card) {
  border-radius: var(--radius-md, 0.5rem);
  box-shadow: var(--shadow-sm, 0 1px 3px rgba(0, 0, 0, 0.08));
}

:deep(.card-header) {
  background-color: var(--surface-subtle);
  border-bottom: 1px solid var(--border-subtle);
}
</style>

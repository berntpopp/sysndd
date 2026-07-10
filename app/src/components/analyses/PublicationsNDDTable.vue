<!-- src/components/analyses/PublicationsNDDTable.vue -->
<template>
  <div>
    <!-- Show an overlay spinner while loading -->
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <!-- Once loaded, show the table container -->
    <AnalysisPanel
      v-else
      title="SysNDD curated publications"
      :description="
        'Publications: ' +
        totalRows +
        ' · Loaded ' +
        perPage +
        '/' +
        totalRows +
        ' in ' +
        executionTime
      "
    >
      <template #actions>
        <TableDownloadLinkCopyButtons
          v-if="showFilterControls"
          :downloading="downloading"
          :remove-filters-title="removeFiltersButtonTitle"
          :remove-filters-variant="removeFiltersButtonVariant"
          @request-excel="requestExcel"
          @copy-link="copyLinkToClipboard"
          @remove-filters="removeFilters"
        />
      </template>

      <!-- Controls (search + pagination) -->
      <BRow>
        <!-- Search box for "any" field -->
        <BCol class="my-1" sm="8">
          <TableSearchInput
            v-model="filter.any.content"
            :placeholder="'Search any field by typing here'"
            :debounce-time="500"
            @input="filtered"
          />
        </BCol>

        <!-- Pagination controls -->
        <BCol class="my-1" sm="4">
          <BContainer v-if="totalRows > perPage || showPaginationControls">
            <!--
                    TablePaginationControls will emit:
                    @page-change="handlePageChange"
                    @per-page-change="handlePerPageChange"
                  -->
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
      <!-- Controls (search + pagination) -->

      <!-- Main GenericTable -->
      <GenericTable
        :items="items"
        :fields="fields"
        :field-details="fields_details"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @update-sort="handleSortUpdate"
      >
        <!-- Custom filter fields slot -->
        <template v-if="showFilterControls" #filter-controls>
          <td v-for="field in fields" :key="field.key" role="presentation">
            <BFormInput
              v-if="field.filterable"
              v-model="filter[field.key].content"
              :placeholder="'Filter ' + truncate(field.label, 20)"
              :aria-label="`Filter by ${field.label}`"
              debounce="500"
              type="search"
              autocomplete="off"
              @click="removeSearch()"
              @update="filtered()"
            />

            <BFormSelect
              v-if="field.selectable"
              v-model="filter[field.key].content"
              :options="field.selectOptions"
              :aria-label="`Filter by ${field.label}`"
              type="search"
              @input="removeSearch()"
              @change="filtered()"
            >
              <template #first>
                <BFormSelectOption value="null">
                  .. {{ truncate(field.label, 20) }} ..
                </BFormSelectOption>
              </template>
            </BFormSelect>

            <!-- TODO: treeselect disabled pending Bootstrap-Vue-Next migration -->
            <label
              v-if="field.multi_selectable && field.selectOptions && field.selectOptions.length > 0"
              :for="'select_' + field.key"
              :aria-label="`Filter by ${field.label}`"
            >
              <BFormSelect
                :id="'select_' + field.key"
                v-model="filter[field.key].content"
                :options="normalizeSelectOptions(field.selectOptions)"
                size="sm"
                @change="
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
        </template>
        <!-- Custom filter fields slot -->

        <!-- Custom slot for 'publication_id' - links to PubMed -->
        <template #cell-publication_id="{ row }">
          <a
            :href="getPubMedUrl(row.publication_id)"
            target="_blank"
            rel="noopener noreferrer"
            class="publication-link"
            :aria-label="`Open PubMed article ${row.publication_id} in new tab`"
          >
            <span class="publication-badge">
              <i class="bi bi-journal-medical me-1" />
              <span class="publication-id">{{ row.publication_id }}</span>
              <i class="bi bi-box-arrow-up-right ms-1 external-icon" />
            </span>
          </a>
        </template>

        <!-- Custom slot for 'Title' -->
        <template #cell-Title="{ row }">
          <div v-b-tooltip.hover.top class="title-cell" :title="row.Title">
            <span class="title-text">{{ truncate(row.Title, 60) }}</span>
          </div>
        </template>

        <!-- Custom slot for 'Journal' -->
        <template #cell-Journal="{ row }">
          <span v-if="row.Journal" class="journal-badge">
            <i class="bi bi-book me-1" />
            {{ truncate(row.Journal, 35) }}
          </span>
          <span v-else class="text-muted">—</span>
        </template>

        <!-- Custom slot for 'Publication_date' -->
        <template #cell-Publication_date="{ row }">
          <span v-if="row.Publication_date" class="date-badge">
            <i class="bi bi-calendar3 me-1" />
            {{ formatDate(row.Publication_date) }}
          </span>
          <span v-else class="text-muted">—</span>
        </template>

        <!-- Custom row details for expanded publication info -->
        <template #row-expansion="{ row }">
          <div class="publication-details">
            <!-- Abstract -->
            <div v-if="row.Abstract" class="details-section">
              <h6 class="details-label"><i class="bi bi-file-text me-2" />Abstract</h6>
              <p class="details-abstract">{{ row.Abstract }}</p>
            </div>

            <div class="details-row">
              <!-- Authors -->
              <div v-if="row.Lastname || row.Firstname" class="details-section details-authors">
                <h6 class="details-label"><i class="bi bi-people me-2" />Authors</h6>
                <p class="details-text">{{ formatAuthors(row.Lastname, row.Firstname) }}</p>
              </div>

              <!-- Keywords -->
              <div v-if="row.Keywords" class="details-section details-keywords">
                <h6 class="details-label"><i class="bi bi-tags me-2" />Keywords</h6>
                <div class="keywords-container">
                  <span
                    v-for="(keyword, idx) in parseKeywords(row.Keywords)"
                    :key="idx"
                    class="keyword-tag"
                  >
                    {{ keyword }}
                  </span>
                </div>
              </div>
            </div>

            <!-- Empty state -->
            <p v-if="!row.Abstract && !row.Lastname && !row.Keywords" class="text-muted">
              No additional details available for this publication.
            </p>
          </div>
        </template>
      </GenericTable>
      <!-- Main GenericTable -->
    </AnalysisPanel>
  </div>
</template>

<script>
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import AnalysisPanel from '@/components/analyses/AnalysisPanel.vue';

import { usePublicationsTable } from './usePublicationsTable';

export default {
  name: 'PublicationsNDDTable',
  components: {
    AnalysisPanel,
    TableSearchInput,
    TablePaginationControls,
    TableDownloadLinkCopyButtons,
    GenericTable,
  },
  props: {
    apiEndpoint: {
      type: String,
      default: 'publication', // So it references /api/publication
    },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Publications table' },
    sortInput: { type: String, default: '+publication_id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default: 'publication_id,Title,Journal,Publication_date,Abstract,Lastname,Firstname,Keywords',
    },
  },
  setup(props) {
    return usePublicationsTable(props);
  },
};
</script>

<style scoped>
/* Publication table styling */
.publication-link {
  text-decoration: none;
  display: inline-block;
}

/* PMID badge: --medical-blue-700 on --medical-blue-50 ≈ 7.1:1 ✓ AAA */
.publication-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.2em 0.45em;
  font-size: 0.75em;
  font-weight: 500;
  background-color: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-700, #0d47a1);
  border-radius: var(--radius-sm, 0.25rem);
  transition: all 0.15s ease-in-out;
}

.publication-link:hover .publication-badge {
  background-color: var(--medical-blue-700, #0d47a1);
  color: #fff;
}

.publication-id {
  font-family: var(--font-family-mono, 'SFMono-Regular', Menlo, Monaco, Consolas, monospace);
}

.external-icon {
  font-size: 0.75em;
  opacity: 0.7;
}

.title-cell {
  max-width: 400px;
}

.title-text {
  color: var(--neutral-900, #212121);
  line-height: 1.4;
}

/* Journal badge: --neutral-700 on --neutral-100 ≈ 5.4:1 ✓ AA */
.journal-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.25em 0.5em;
  font-size: 0.85em;
  background-color: var(--neutral-100, #f5f5f5);
  color: var(--neutral-700, #616161);
  border-radius: var(--radius-sm, 0.25rem);
  border: 1px solid var(--neutral-300, #e0e0e0);
}

/* Date badge: neutral metadata — --neutral-700 on --neutral-100 ≈ 5.4:1 ✓ AA.
   Green success token is reserved for actual status; dates are neutral. */
.date-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.15em 0.4em;
  font-size: 0.75em;
  background-color: var(--neutral-100, #f5f5f5);
  color: var(--neutral-700, #616161);
  border-radius: var(--radius-sm, 0.25rem);
  border: 1px solid var(--neutral-300, #e0e0e0);
  white-space: nowrap;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

/* Publication details expanded row */
.publication-details {
  padding: 1.25rem 1.5rem;
  background: #fafbfc;
  border-radius: 0.5rem;
  margin: 0.75rem 1rem;
  border: 1px solid var(--neutral-200, #eeeeee);
  box-shadow: inset 0 1px 3px rgba(0, 0, 0, 0.04);
}

.details-section {
  margin-bottom: 1.25rem;
}

.details-section:last-child {
  margin-bottom: 0;
}

/* Section label: --neutral-700 on white ≈ 5.7:1 ✓ AA */
.details-label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--neutral-700, #616161);
  margin-bottom: 0.6rem;
  padding-bottom: 0.35rem;
  border-bottom: 1px solid var(--neutral-200, #eeeeee);
  display: flex;
  align-items: center;
}

/* Icon in section label: --medical-blue-700 on white ≈ 8.6:1 ✓ AAA */
.details-label i {
  color: var(--medical-blue-700, #0d47a1);
  opacity: 0.8;
}

.details-abstract {
  font-size: 0.875rem;
  line-height: 1.7;
  color: var(--neutral-900, #212121);
  margin: 0;
  text-align: justify;
  padding: 0.5rem 0;
}

.details-row {
  display: grid;
  grid-template-columns: minmax(180px, 1fr) minmax(300px, 3fr);
  gap: 2rem;
  padding-top: 0.5rem;
  border-top: 1px solid var(--neutral-200, #eeeeee);
  margin-top: 0.25rem;
}

.details-authors {
  min-width: 0;
}

.details-keywords {
  min-width: 0;
}

/* Body text: --neutral-700 on white ≈ 5.7:1 ✓ AA */
.details-text {
  font-size: 0.875rem;
  color: var(--neutral-700, #616161);
  margin: 0;
  line-height: 1.5;
}

.keywords-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

/* Keyword chip: --medical-blue-700 on --medical-blue-50 ≈ 7.1:1 ✓ AAA */
.keyword-tag {
  display: inline-block;
  padding: 0.25em 0.6em;
  font-size: 0.7rem;
  font-weight: 500;
  background-color: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-700, #0d47a1);
  border-radius: var(--radius-full, 9999px);
  white-space: nowrap;
  border: 1px solid rgba(13, 71, 161, 0.15);
}

/* Text truncation for table cells */
.title-cell {
  max-width: 350px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

:deep(.entities-table td) {
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Ensure journal badge truncates properly */
.journal-badge {
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Mobile responsive adjustments */
@media (max-width: 767px) {
  .publication-details {
    padding: 0.75rem;
  }

  .details-row {
    flex-direction: column;
    gap: 1rem;
  }

  .details-authors,
  .details-keywords {
    min-width: auto;
  }

  .title-cell {
    max-width: 200px;
  }
}
</style>

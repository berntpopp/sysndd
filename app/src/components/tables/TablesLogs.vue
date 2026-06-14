<!-- src/components/tables/TablesLogs.vue -->
<template>
  <div class="container-fluid logs-table">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <!-- User Interface controls -->
          <TableShell
            :title="headerLabel"
            :meta="`${totalRows.toLocaleString()} log entries`"
            :description="`Loaded ${perPage}/${totalRows} in ${executionTime}`"
            :aria-busy="isBusy ? 'true' : 'false'"
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

            <template #toolbar>
              <LogFilterToolbar
                v-model:mobile-sort-value="mobileSortValue"
                :filter="filter"
                :total-rows="totalRows"
                :per-page="perPage"
                :show-pagination-controls="showPaginationControls"
                :page-options="pageOptions"
                :current-page="currentPage"
                :method-options="method_options"
                :status-options="status_options"
                :mobile-sort-options="mobileSortOptions"
                :items-length="items.length"
                :has-active-filters="hasActiveFilters"
                :active-filters="activeFilters"
                @update-filter="setFilterField"
                @page-change="handlePageChange"
                @per-page-change="handlePerPageChange"
                @show-delete="showDeleteModal = true"
                @clear-filter="clearFilter"
                @remove-filters="removeFilters"
              />
            </template>
            <!-- User Interface controls -->

            <div
              v-if="isBusy"
              data-testid="logs-loading-state"
              class="logs-loading-state"
              role="status"
              aria-live="polite"
              aria-busy="true"
            >
              <BSpinner small class="me-2" />
              Loading logs...
            </div>

            <!-- Empty state when no logs match filters -->
            <div v-else-if="items.length === 0" class="text-center py-4">
              <i class="bi bi-journal-x fs-1 text-muted" />
              <p class="text-muted mt-2">No logs match your filters</p>
              <BButton v-if="hasActiveFilters" variant="link" @click="removeFilters">
                Clear filters
              </BButton>
            </div>

            <!-- Main table element -->
            <GenericTable
              v-else-if="items.length > 0"
              class="d-none d-md-table"
              :items="items"
              :fields="fields"
              :field-details="fields_details"
              :sort-by="sortBy"
              @update-sort="handleSortUpdate"
            >
              <!-- Custom filter fields slot -->
              <template v-if="showFilterControls" #filter-controls>
                <td v-for="field in fields" :key="field.key" role="presentation">
                  <BFormInput
                    v-if="field.filterable"
                    v-model="filter[field.key].content"
                    :placeholder="' .. ' + truncate(field.label, 20) + ' .. '"
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
                    size="sm"
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
                    v-if="
                      field.multi_selectable &&
                      field.selectOptions &&
                      field.selectOptions.length > 0
                    "
                    :for="'select_' + field.key"
                    :aria-label="field.label"
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

              <template #cell-id="{ row }">
                <BBadge variant="primary">
                  {{ row.id }}
                </BBadge>
              </template>

              <template #cell-agent="{ row }">
                <div v-b-tooltip.hover.top class="overflow-hidden text-truncate" :title="row.agent">
                  <BBadge pill variant="info">
                    {{ truncate(row.agent, 50) }}
                  </BBadge>
                </div>
              </template>

              <template #cell-status="{ row }">
                <BBadge :variant="getStatusVariant(row.status)">
                  {{ row.status }}
                </BBadge>
              </template>

              <template #cell-request_method="{ row }">
                <BBadge :variant="getMethodVariant(row.request_method)">
                  {{ row.request_method }}
                </BBadge>
              </template>

              <template #cell-path="{ row }">
                <div
                  v-b-tooltip.hover.top
                  class="overflow-hidden text-truncate font-monospace small"
                  style="max-width: 200px"
                  :title="row.path + (row.query ? row.query : '')"
                >
                  {{ row.path }}
                </div>
              </template>

              <template #cell-duration="{ row }">
                <span
                  v-b-tooltip.hover
                  :class="getDurationClass(row.duration)"
                  :title="`${row.duration}ms response time`"
                >
                  {{ formatDuration(row.duration) }}
                </span>
              </template>

              <template #cell-address="{ row }">
                <span class="font-monospace small">{{ row.address }}</span>
              </template>

              <template #cell-timestamp="{ row }">
                <div v-b-tooltip.hover.top :title="formatAbsoluteTime(row.timestamp)">
                  {{ formatRelativeTime(row.timestamp) }}
                </div>
              </template>

              <template #cell-modified="{ row }">
                <div v-b-tooltip.hover.top :title="formatAbsoluteTime(row.modified)">
                  {{ formatRelativeTime(row.modified) }}
                </div>
              </template>

              <template #cell-actions="{ row }">
                <BButton
                  v-b-tooltip.hover
                  size="sm"
                  variant="outline-primary"
                  title="View details"
                  @click="handleRowClick(row)"
                >
                  <i class="bi bi-eye" />
                </BButton>
              </template>
            </GenericTable>
            <LogMobileRows
              v-if="!isBusy && items.length > 0"
              class="d-md-none"
              :items="items"
              @view="handleRowClick"
            />
            <!-- Main table element -->
          </TableShell>
        </BCol>
      </BRow>

      <!-- Log Detail Drawer -->
      <LogDetailDrawer
        v-model="showLogDetail"
        :log="selectedLog"
        :can-navigate-prev="canNavigatePrev"
        :can-navigate-next="canNavigateNext"
        @navigate-prev="navigateToPreviousLog"
        @navigate-next="navigateToNextLog"
      />

      <!-- Delete Logs Confirmation Modal: stays mounted (no v-if) so the
           modal's @hidden lifecycle fires and owns the state reset -->
      <LogDeleteModal
        v-model="showDeleteModal"
        v-model:delete-mode="deleteMode"
        :total-rows="totalRows"
        :is-deleting="isDeleting"
        @confirm="deleteLogs"
      />

      <!-- Large-export confirmation (replaces window.confirm): only shown when
           the export exceeds the row threshold. -->
      <ConfirmActionModal
        v-model="showExportModal"
        title="Export a large number of logs?"
        :message="`This export contains ${totalRows.toLocaleString()} rows and may take a while. Continue?`"
        confirm-label="Export"
        confirm-variant="primary"
        header-bg-variant="primary"
        header-text-variant="light"
        :busy="downloading"
        @confirm="doExportExcel"
      />
    </BContainer>
  </div>
</template>

<script>
// Thin shell: all log-table state/loading/cursor/url-sync lives in the
// useLogTable composable; the toolbar markup lives in LogFilterToolbar.vue.
import { defineComponent } from 'vue';

import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import LogDetailDrawer from '@/components/small/LogDetailDrawer.vue';
import LogDeleteModal from '@/components/small/LogDeleteModal.vue';
import TableShell from '@/components/table/TableShell.vue';
import LogMobileRows from '@/views/admin/components/LogMobileRows.vue';
import LogFilterToolbar from './LogFilterToolbar.vue';
import ConfirmActionModal from '@/components/ui/ConfirmActionModal.vue';

import { normalizeSelectOptions } from '@/utils/selectOptions';
import { useLogTable } from './useLogTable';

export default defineComponent({
  name: 'TablesLogs',
  components: {
    TableDownloadLinkCopyButtons,
    GenericTable,
    LogDetailDrawer,
    LogDeleteModal,
    TableShell,
    LogMobileRows,
    LogFilterToolbar,
    ConfirmActionModal,
  },
  props: {
    apiEndpoint: { type: String, default: 'logs' },
    showFilterControls: { type: Boolean, default: true },
    showPaginationControls: { type: Boolean, default: true },
    headerLabel: { type: String, default: 'Logging table' },
    sortInput: { type: String, default: '-id' },
    filterInput: { type: String, default: null },
    fieldsInput: { type: String, default: null },
    pageAfterInput: { type: String, default: '0' },
    pageSizeInput: { type: Number, default: 10 },
    fspecInput: {
      type: String,
      default:
        'id,timestamp,address,agent,host,request_method,path,query,post,status,duration,file,modified',
    },
  },
  setup(props) {
    return {
      ...useLogTable(props),
      // Shared select-option normalizer used by the table-header filter row.
      normalizeSelectOptions,
    };
  },
});
</script>

<style scoped>
/* Scoped styles for TablesLogs.vue (extracted from the SFC). */

/* Button styles */
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

.logs-table {
  padding-bottom: max(1rem, var(--app-footer-height, 48px));
}

.logs-loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 14rem;
  color: #526070;
  font-size: 0.875rem;
}

/* Input group styles */
.input-group > .input-group-prepend {
  flex: 0 0 35%;
}
.input-group .input-group-text {
  width: 100%;
}

/* Badge container styles */
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* Treeselect placeholder styles (legacy) */
:deep(.vue-treeselect__placeholder) {
  color: #6c757d !important;
}
:deep(.vue-treeselect__control) {
  color: #6c757d !important;
}

/* Row hover effect. Rows are not clickable (the detail drawer opens from the
   per-row "view" button, which is keyboard-operable), so no pointer cursor. */
:deep(.table tbody tr) {
  transition: background-color 0.15s ease-in-out;
}

:deep(.table tbody tr:hover) {
  background-color: rgba(var(--bs-primary-rgb), 0.075);
}
</style>

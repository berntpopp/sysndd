<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <!-- User Interface controls -->
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
                    Approve Status
                    <BBadge variant="primary" class="ms-2"> {{ totalRows }} statuses </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <div class="d-flex align-items-center justify-content-end gap-2">
                    <!-- Approve all status button -->
                    <BButton
                      v-b-tooltip.hover.bottom
                      variant="danger"
                      size="sm"
                      title="Approve all pending statuses"
                      aria-label="Approve all statuses"
                      @click="checkAllApprove"
                    >
                      <i class="bi bi-check2-all me-1" aria-hidden="true" />
                      Approve All
                    </BButton>
                    <!-- Refresh button -->
                    <BButton
                      v-b-tooltip.hover.bottom
                      variant="outline-light"
                      size="sm"
                      title="Refresh data"
                      aria-label="Refresh table data"
                      @click="loadStatusTableData()"
                    >
                      <i class="bi bi-arrow-clockwise" aria-hidden="true" />
                    </BButton>
                  </div>
                </BCol>
              </BRow>
            </template>
            <!-- User Interface controls -->

            <!-- Search, filters, and pagination row -->
            <BRow class="px-3 py-2 align-items-center">
              <!-- Search input -->
              <BCol cols="12" md="4" lg="3" class="mb-2 mb-md-0">
                <BInputGroup size="sm">
                  <template #prepend>
                    <BInputGroupText>
                      <i class="bi bi-search" />
                    </BInputGroupText>
                  </template>
                  <BFormInput
                    id="filter-input"
                    v-model="filter"
                    type="search"
                    placeholder="Search any field..."
                    debounce="500"
                  />
                </BInputGroup>
              </BCol>

              <!-- Spacer for alignment -->
              <BCol cols="12" md="4" lg="4" class="mb-2 mb-md-0" />

              <!-- Pagination controls -->
              <BCol
                cols="12"
                md="4"
                lg="5"
                class="d-flex justify-content-end align-items-center gap-2"
              >
                <BInputGroup size="sm" class="w-auto">
                  <template #prepend>
                    <BInputGroupText>Per page</BInputGroupText>
                  </template>
                  <BFormSelect
                    id="per-page-select"
                    v-model="perPage"
                    :options="pageOptions"
                    size="sm"
                    style="width: 70px"
                  />
                </BInputGroup>

                <BPagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  size="sm"
                  class="my-0"
                  last-number
                />
              </BCol>
            </BRow>

            <!-- Column filters -->
            <BRow class="px-3 pb-2 align-items-center">
              <BCol cols="6" md="2" class="mb-2 mb-md-0">
                <BFormSelect
                  v-model="categoryFilter"
                  size="sm"
                  :options="categoryFilterOptions"
                  aria-label="Filter by category"
                />
              </BCol>
              <BCol cols="6" md="2" class="mb-2 mb-md-0">
                <BFormSelect
                  v-model="userFilter"
                  size="sm"
                  :options="userFilterOptions"
                  aria-label="Filter by user"
                />
              </BCol>
              <BCol cols="6" md="2" class="mb-2 mb-md-0">
                <BInputGroup size="sm">
                  <template #prepend>
                    <BInputGroupText class="small"> From </BInputGroupText>
                  </template>
                  <BFormInput
                    v-model="dateRangeStart"
                    type="date"
                    size="sm"
                    aria-label="Filter from date"
                  />
                </BInputGroup>
              </BCol>
              <BCol cols="6" md="2" class="mb-2 mb-md-0">
                <BInputGroup size="sm">
                  <template #prepend>
                    <BInputGroupText class="small"> To </BInputGroupText>
                  </template>
                  <BFormInput
                    v-model="dateRangeEnd"
                    type="date"
                    size="sm"
                    aria-label="Filter to date"
                  />
                </BInputGroup>
              </BCol>
              <!-- Active filter tags -->
              <BCol cols="12" md="4" class="d-flex align-items-center flex-wrap gap-1">
                <BBadge
                  v-if="categoryFilter"
                  variant="secondary"
                  class="d-flex align-items-center gap-1"
                  style="cursor: pointer"
                  @click="categoryFilter = null"
                >
                  {{ categoryFilter }}
                  <i class="bi bi-x" />
                </BBadge>
                <BBadge
                  v-if="userFilter"
                  variant="secondary"
                  class="d-flex align-items-center gap-1"
                  style="cursor: pointer"
                  @click="userFilter = null"
                >
                  {{ userFilter }}
                  <i class="bi bi-x" />
                </BBadge>
                <BBadge
                  v-if="dateRangeStart"
                  variant="secondary"
                  class="d-flex align-items-center gap-1"
                  style="cursor: pointer"
                  @click="dateRangeStart = null"
                >
                  From: {{ dateRangeStart }}
                  <i class="bi bi-x" />
                </BBadge>
                <BBadge
                  v-if="dateRangeEnd"
                  variant="secondary"
                  class="d-flex align-items-center gap-1"
                  style="cursor: pointer"
                  @click="dateRangeEnd = null"
                >
                  To: {{ dateRangeEnd }}
                  <i class="bi bi-x" />
                </BBadge>
              </BCol>
            </BRow>
            <!-- Column filters -->
            <!-- Table Interface controls -->

            <!-- Icon legend -->
            <div class="px-3 pb-2">
              <IconLegend :legend-items="legendItems" />
            </div>

            <!-- Main table -->
            <BSpinner v-if="loading_status_approve" label="Loading..." class="float-center m-5" />
            <BTable
              v-else
              :items="columnFilteredItems"
              :fields="fields_StatusTable"
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
              @update:sort-by="handleSortByUpdate"
              @filtered="onFiltered"
            >
              <template #cell(entity_id)="data">
                <EntityBadge
                  :entity-id="data.item.entity_id"
                  :link-to="'/Entities/' + data.item.entity_id"
                />
              </template>

              <template #cell(symbol)="data">
                <GeneBadge
                  :symbol="data.item.symbol"
                  :hgnc-id="data.item.hgnc_id"
                  :link-to="'/Genes/' + data.item.hgnc_id"
                />
              </template>

              <template #cell(disease_ontology_name)="data">
                <DiseaseBadge
                  :name="data.item.disease_ontology_name"
                  :ontology-id="data.item.disease_ontology_id_version"
                  :max-length="40"
                  :link-to="
                    '/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')
                  "
                />
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <InheritanceBadge
                  :full-name="data.item.hpo_mode_of_inheritance_term_name"
                  :hpo-term="data.item.hpo_mode_of_inheritance_term"
                />
              </template>

              <template #cell(category)="data">
                <CategoryIcon :category="data.item.category" size="sm" :show-title="true" />
              </template>

              <template #cell(problematic)="data">
                <span
                  v-b-tooltip.hover.top
                  :title="problematic_text[data.item.problematic]"
                  class="d-inline-flex align-items-center justify-content-center rounded-circle"
                  :class="
                    data.item.problematic
                      ? 'bg-danger-subtle text-danger'
                      : 'bg-success-subtle text-success'
                  "
                  style="width: 24px; height: 24px; font-size: 0.75rem"
                >
                  <i
                    :class="
                      data.item.problematic
                        ? 'bi bi-exclamation-triangle-fill'
                        : 'bi bi-check-circle-fill'
                    "
                  />
                </span>
              </template>

              <template #cell(comment)="data">
                <div
                  v-if="data.item.comment"
                  :id="'comment-status-' + data.item.status_id"
                  class="text-truncate-multiline small text-popover-trigger"
                  style="max-width: 150px"
                >
                  {{ data.item.comment }}
                </div>
                <BPopover
                  v-if="data.item.comment"
                  :target="'comment-status-' + data.item.status_id"
                  triggers="hover focus"
                  placement="top"
                  custom-class="wide-popover"
                >
                  <template #title>
                    <i class="bi bi-chat-left-text me-1" />
                    Comment
                  </template>
                  <div class="popover-text-content">
                    {{ data.item.comment }}
                  </div>
                </BPopover>
                <span v-else class="text-muted small">—</span>
              </template>

              <template #cell(status_date)="data">
                <div class="d-flex align-items-center gap-1">
                  <span
                    v-b-tooltip.hover.top
                    :title="data.item.status_date"
                    class="d-inline-flex align-items-center justify-content-center rounded-circle bg-secondary-subtle text-secondary"
                    style="width: 24px; height: 24px; font-size: 0.75rem"
                  >
                    <i class="bi bi-calendar3" />
                  </span>
                  <span class="small text-muted">
                    {{ data.item.status_date.substring(0, 10) }}
                  </span>
                </div>
              </template>

              <template #cell(status_user_name)="data">
                <div class="d-flex align-items-center gap-1">
                  <span
                    v-b-tooltip.hover.top
                    :title="data.item.status_user_role"
                    class="d-inline-flex align-items-center justify-content-center rounded-circle"
                    :class="`bg-${user_style[data.item.status_user_role]}-subtle text-${user_style[data.item.status_user_role]}`"
                    style="width: 24px; height: 24px; font-size: 0.75rem"
                  >
                    <i :class="'bi bi-' + user_icon[data.item.status_user_role]" />
                  </span>
                  <span class="small">
                    {{ data.item.status_user_name }}
                  </span>
                </div>
              </template>

              <template #cell(actions)="row">
                <BButton
                  v-b-tooltip.hover.left
                  size="sm"
                  class="me-1 btn-xs"
                  variant="outline-primary"
                  title="Toggle details"
                  :aria-label="`Toggle details for entity ${row.item.entity_id}`"
                  @click="row.toggleDetails"
                >
                  <i
                    :class="'bi bi-' + (row.detailsShowing ? 'eye-slash' : 'eye')"
                    aria-hidden="true"
                  />
                </BButton>

                <BButton
                  v-b-tooltip.hover.left
                  size="sm"
                  class="me-1 btn-xs"
                  variant="secondary"
                  :title="
                    row.item.review_change ? 'Edit status (review change pending)' : 'Edit status'
                  "
                  :aria-label="`Edit status for entity ${row.item.entity_id}${row.item.review_change ? ' (review change pending)' : ''}`"
                  @click="infoStatus(row.item, row.index, $event.target)"
                >
                  <span class="position-relative d-inline-block" style="font-size: 0.9em">
                    <i class="bi bi-pen" aria-hidden="true" />
                    <i
                      v-if="row.item.review_change"
                      class="bi bi-exclamation-triangle-fill position-absolute text-warning"
                      style="top: -0.3em; right: -0.5em; font-size: 0.7em"
                      aria-hidden="true"
                    />
                  </span>
                </BButton>

                <BButton
                  v-b-tooltip.hover.right
                  size="sm"
                  class="me-1 btn-xs"
                  variant="danger"
                  title="Approve status"
                  :aria-label="`Approve status for entity ${row.item.entity_id}`"
                  @click="infoApproveStatus(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-check2-circle" aria-hidden="true" />
                </BButton>

                <BButton
                  v-b-tooltip.hover.right
                  size="sm"
                  class="me-1 btn-xs"
                  variant="outline-danger"
                  title="Dismiss status"
                  :aria-label="`Dismiss status for entity ${row.item.entity_id}`"
                  @click="infoDismissStatus(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-x-circle" aria-hidden="true" />
                </BButton>

                <BButton
                  v-if="row.item.duplicate === 'yes'"
                  v-b-tooltip.hover.right
                  variant="warning"
                  title="Multiple pending statuses for this entity"
                  :aria-label="`Warning: Multiple pending statuses for entity ${row.item.entity_id}`"
                  size="sm"
                  class="me-1 btn-xs"
                >
                  <i class="bi bi-exclamation-triangle-fill" aria-hidden="true" />
                </BButton>
              </template>

              <template #row-details="row">
                <BCard class="mb-2 border-0 shadow-sm" body-class="p-3">
                  <div class="row g-3">
                    <!-- Status Info Section -->
                    <div class="col-md-4">
                      <h6 class="text-muted small text-uppercase fw-semibold mb-2">
                        <i class="bi bi-info-circle me-1" />
                        Status Details
                      </h6>
                      <div class="d-flex flex-column gap-2">
                        <div class="d-flex align-items-center gap-2">
                          <span class="text-muted small" style="min-width: 80px">Status ID:</span>
                          <BBadge variant="secondary">{{ row.item.status_id }}</BBadge>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                          <span class="text-muted small" style="min-width: 80px">Category:</span>
                          <BBadge :variant="stoplights_style[row.item.category]">
                            {{ row.item.category }}
                          </BBadge>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                          <span class="text-muted small" style="min-width: 80px">Problematic:</span>
                          <BBadge :variant="row.item.problematic ? 'danger' : 'success'">
                            {{ row.item.problematic ? 'Yes' : 'No' }}
                          </BBadge>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                          <span class="text-muted small" style="min-width: 80px">Active:</span>
                          <BBadge :variant="row.item.is_active ? 'success' : 'secondary'">
                            {{ row.item.is_active ? 'Yes' : 'No' }}
                          </BBadge>
                        </div>
                      </div>
                    </div>

                    <!-- Comment Section -->
                    <div class="col-md-8">
                      <h6 class="text-muted small text-uppercase fw-semibold mb-2">
                        <i class="bi bi-chat-left-text me-1" />
                        Comment
                      </h6>
                      <div
                        v-if="row.item.comment"
                        class="bg-light rounded p-2 small"
                        style="max-height: 120px; overflow-y: auto"
                      >
                        {{ row.item.comment }}
                      </div>
                      <span v-else class="text-muted small fst-italic">No comment available</span>
                    </div>
                  </div>
                </BCard>
              </template>
            </BTable>
            <!-- Main table -->
          </BCard>
        </BCol>
      </BRow>

      <!-- Approve modal -->
      <BModal
        :id="approveModal.id"
        :ref="approveModal.id"
        size="md"
        centered
        ok-title="Approve"
        ok-variant="success"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        header-close-label="Close"
        @ok="handleStatusOk"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-check-circle-fill me-2 text-success" />
            <span class="fw-semibold">Approve Status</span>
          </div>
        </template>

        <div class="text-center py-3">
          <div class="mb-3">
            <i class="bi bi-question-circle text-primary" style="font-size: 2.5rem" />
          </div>
          <p class="mb-2">
            You have finished checking this status for entity
            <BBadge variant="primary" class="mx-1">
              {{ approveModal.title }}
            </BBadge>
          </p>
          <p class="text-muted small">Click <strong>Approve</strong> to confirm and submit.</p>

          <div
            v-if="approveModal.hasDuplicates"
            class="alert alert-info small text-start mt-3 mb-0"
          >
            <i class="bi bi-info-circle me-1" />
            Other pending statuses for this entity will be automatically dismissed.
          </div>
        </div>
      </BModal>
      <!-- Approve modal -->

      <!-- Dismiss modal -->
      <BModal
        :id="dismissModal.id"
        :ref="dismissModal.id"
        size="md"
        centered
        ok-title="Dismiss"
        ok-variant="danger"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        header-close-label="Close"
        @ok="handleDismissOk"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-x-circle-fill me-2 text-danger" />
            <span class="fw-semibold">Dismiss Status</span>
          </div>
        </template>

        <div class="text-center py-3">
          <div class="mb-3">
            <i class="bi bi-x-circle text-danger" style="font-size: 2.5rem" />
          </div>
          <p class="mb-2">
            Dismiss this pending status for entity
            <BBadge variant="primary" class="mx-1">
              {{ dismissModal.title }}
            </BBadge>
            ?
          </p>
          <p class="text-muted small">
            The status will be removed from the pending queue. This does not delete the record.
          </p>
        </div>
      </BModal>
      <!-- Dismiss modal -->

      <!-- Modify status modal -->
      <BModal
        :id="statusModal.id"
        :ref="statusModal.id"
        size="lg"
        centered
        ok-title="Save Status"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        header-close-label="Close"
        :busy="loading_status_modal"
        @ok="submitStatusChange"
        @hide="onStatusModalHide"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-stoplights me-2 text-secondary" />
            <span class="fw-semibold">Edit Status</span>
          </div>
        </template>

        <template #footer="{ ok, cancel }">
          <div class="w-100 d-flex justify-content-between align-items-center">
            <div class="d-flex align-items-center gap-2 text-muted small">
              <span>
                <i
                  :class="
                    'bi bi-' +
                    user_icon[status_info.status_user_role] +
                    ' text-' +
                    user_style[status_info.status_user_role]
                  "
                />
                <span class="ms-1">{{ status_info.status_user_name }}</span>
              </span>
              <BBadge :variant="user_style[status_info.status_user_role]" pill>
                {{ status_info.status_user_role }}
              </BBadge>
            </div>

            <div class="d-flex gap-2">
              <BButton variant="outline-secondary" @click="cancel()"> Cancel </BButton>
              <BButton variant="primary" @click="ok()">
                <i class="bi bi-check-lg me-1" />
                Save Status
              </BButton>
            </div>
          </div>
        </template>

        <!-- Entity Context Header -->
        <div class="bg-light rounded-3 p-3 mb-3">
          <div class="d-flex flex-wrap align-items-center gap-2">
            <BLink :href="'/Entities/' + status_info.entity_id" target="_blank">
              <BBadge variant="primary"> sysndd:{{ status_info.entity_id }} </BBadge>
            </BLink>
            <BLink :href="'/Genes/' + entity_info.symbol" target="_blank">
              <BBadge v-b-tooltip.hover.bottom pill variant="success" :title="entity_info.hgnc_id">
                {{ entity_info.symbol }}
              </BBadge>
            </BLink>
            <BLink
              :href="'/Ontology/' + entity_info.disease_ontology_id_version.replace(/_.+/g, '')"
              target="_blank"
            >
              <BBadge
                v-b-tooltip.hover.bottom
                pill
                variant="secondary"
                :title="
                  entity_info.disease_ontology_name + '; ' + entity_info.disease_ontology_id_version
                "
              >
                {{ truncate(entity_info.disease_ontology_name, 40) }}
              </BBadge>
            </BLink>
            <BBadge
              v-b-tooltip.hover.bottom
              pill
              variant="info"
              :title="
                entity_info.hpo_mode_of_inheritance_term_name +
                ' (' +
                entity_info.hpo_mode_of_inheritance_term +
                ')'
              "
            >
              {{ inheritance_short_text[entity_info.hpo_mode_of_inheritance_term_name] }}
            </BBadge>
          </div>
        </div>

        <BOverlay :show="loading_status_modal" rounded="sm">
          <BForm ref="form" @submit.stop.prevent="submitStatusChange">
            <!-- Classification Section -->
            <div class="mb-3">
              <h6 class="fw-semibold mb-2">
                <i class="bi bi-stoplights me-1" />
                Classification
              </h6>
              <BFormGroup
                label="Status Category"
                label-class="fw-semibold small"
                label-for="status-select"
              >
                <BFormSelect
                  v-if="status_options && status_options.length > 0"
                  id="status-select"
                  v-model="status_info.category_id"
                  :options="normalizeStatusOptions(status_options)"
                  size="sm"
                >
                  <template #first>
                    <BFormSelectOption :value="null"> Select status... </BFormSelectOption>
                  </template>
                </BFormSelect>
              </BFormGroup>
            </div>

            <!-- Entity Flags Section -->
            <div class="mb-3">
              <h6 class="fw-semibold mb-2">
                <i class="bi bi-flag me-1" />
                Entity Flags
              </h6>
              <BFormGroup class="mb-0">
                <BFormCheckbox id="removeSwitch" v-model="status_info.problematic" switch>
                  Suggest removal
                </BFormCheckbox>
              </BFormGroup>
            </div>

            <!-- Notes Section -->
            <div class="mb-3">
              <h6 class="fw-semibold mb-2">
                <i class="bi bi-chat-left-text me-1" />
                Notes
              </h6>
              <BFormGroup
                label="Comment"
                label-class="fw-semibold small"
                label-for="status-textarea-comment"
              >
                <BFormTextarea
                  id="status-textarea-comment"
                  v-model="status_info.comment"
                  rows="2"
                  size="sm"
                  placeholder="Why should this entity's status be changed?"
                />
              </BFormGroup>
            </div>
          </BForm>
        </BOverlay>
      </BModal>
      <!-- Modify status modal -->

      <!-- Check approve all modal -->
      <BModal
        id="approveAllModal"
        ref="approveAllModal"
        size="md"
        centered
        ok-title="Approve All"
        ok-variant="danger"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        header-close-label="Close"
        @ok="handleAllStatusOk"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-exclamation-triangle-fill me-2 text-danger" />
            <span class="fw-semibold">Approve All Statuses</span>
          </div>
        </template>

        <div class="text-center py-3">
          <div class="mb-3">
            <i class="bi bi-exclamation-triangle text-danger" style="font-size: 2.5rem" />
          </div>
          <p class="mb-2">
            You are about to approve <strong>ALL</strong> {{ totalRows }} pending statuses.
          </p>
          <p class="text-muted small mb-3">
            This action cannot be undone. Please confirm by toggling the switch below.
          </p>
          <div class="d-flex justify-content-center">
            <BFormCheckbox id="approveAllSwitch" v-model="approve_all_selected" switch size="lg">
              <strong>{{ approve_all_selected ? 'Yes, approve all' : 'No, cancel' }}</strong>
            </BFormCheckbox>
          </div>
        </div>
      </BModal>
      <!-- Check approve all modal -->

      <!-- ARIA live region for screen reader announcements -->
      <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />

      <!-- Confirm discard unsaved changes dialog -->
      <ConfirmDiscardDialog
        ref="confirmDiscardDialog"
        modal-id="approve-status-confirm-discard"
        @discard="onConfirmDiscard"
        @keep-editing="pendingDiscardTarget = null"
      />
    </BContainer>
  </div>
</template>

<script>
// TODO: vue3-treeselect disabled pending Bootstrap-Vue-Next migration
// import the Treeselect component
// import Treeselect from '@zanmato/vue3-treeselect';
// import the Treeselect styles
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';

import { useToast, useColorAndSymbols, useText, useAriaLive } from '@/composables';

// Import the utilities file
import Utils from '@/assets/js/utils';

import Status from '@/assets/js/classes/submission/submissionStatus';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Import reusable badge components
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import IconLegend from '@/components/accessibility/IconLegend.vue';
import ConfirmDiscardDialog from '@/components/ui/ConfirmDiscardDialog.vue';

export default {
  name: 'ApproveStatus',
  components: {
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
    CategoryIcon,
    AriaLiveRegion,
    IconLegend,
    ConfirmDiscardDialog,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();
    const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();

    return {
      makeToast,
      ...colorAndSymbols,
      ...text,
      a11yMessage,
      a11yPoliteness,
      announce,
    };
  },
  data() {
    return {
      statusLoadedData: null, // Snapshot of status values when loaded
      legendItems: [
        { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
        { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
        { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
        { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
        { icon: 'bi bi-check-circle-fill', color: '#198754', label: 'No problems' },
        { icon: 'bi bi-exclamation-triangle-fill', color: '#dc3545', label: 'Problematic' },
        {
          icon: 'bi bi-exclamation-triangle-fill',
          color: '#ffc107',
          label: 'Review change pending',
        },
        {
          icon: 'bi bi-exclamation-triangle-fill',
          color: '#ffc107',
          label: 'Multiple pending statuses',
        },
        { icon: 'bi bi-eye', color: '#0d6efd', label: 'Toggle details' },
        { icon: 'bi bi-pen', color: '#6c757d', label: 'Edit status' },
        { icon: 'bi bi-check2-circle', color: '#dc3545', label: 'Approve status' },
        { icon: 'bi bi-x-circle', color: '#dc3545', label: 'Dismiss status' },
      ],
      problematic_text: {
        0: 'No problems',
        1: 'Entity status marked problematic',
      },
      items_StatusTable: [],
      fields_StatusTable: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-start',
        },
        {
          key: 'symbol',
          label: 'Gene',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-start',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-start',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          class: 'text-start',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'category',
          label: 'Category',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'comment',
          label: 'Comment',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'problematic',
          label: 'Problematic',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'status_date',
          label: 'Status date',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'status_user_name',
          label: 'User',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-start',
        },
      ],
      fields_details_StatusTable: [
        {
          key: 'status_id',
          label: 'Status ID',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-start',
        },
        {
          key: 'status_date',
          label: 'Status date',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'status_user_name',
          label: 'Status user',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'is_active',
          label: 'Active',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'comment',
          label: 'Comment',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
      ],
      statusModal: {
        id: 'status-modal',
        title: '',
        content: [],
      },
      entity_info: {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      },
      status_info: new Status(),
      status_options: [],
      totalRows: 0,
      currentPage: 1,
      perPage: 100,
      pageOptions: [10, 25, 50, 100],
      categoryFilter: null,
      userFilter: null,
      dateRangeStart: null,
      dateRangeEnd: null,
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'status_user_name', order: 'asc' }],
      filter: null,
      filterOn: [],
      approveModal: {
        id: 'approve-modal',
        title: '',
        content: [],
        hasDuplicates: false,
      },
      dismissModal: {
        id: 'dismiss-modal',
        title: '',
        statusId: null,
      },
      approve_all_selected: false,
      switch_approve_text: { true: 'Yes', false: 'No' },
      loading_status_approve: true,
      loading_status_modal: true,
      isBusy: true,
      pendingDiscardTarget: null, // 'status' — tracks which modal triggered discard confirm
    };
  },
  computed: {
    hasStatusChanges() {
      if (!this.statusLoadedData) return false;
      return (
        this.status_info.category_id !== this.statusLoadedData.category_id ||
        (this.status_info.comment || '') !== this.statusLoadedData.comment ||
        Boolean(this.status_info.problematic) !== this.statusLoadedData.problematic
      );
    },
    // Category filter options from unique values in items
    categoryFilterOptions() {
      const categories = [...new Set(this.items_StatusTable.map((item) => item.category))].filter(
        Boolean
      );
      return [
        { value: null, text: 'All Categories' },
        ...categories.map((cat) => ({ value: cat, text: cat })),
      ];
    },
    // User filter options from unique values in items
    userFilterOptions() {
      const users = [
        ...new Set(this.items_StatusTable.map((item) => item.status_user_name)),
      ].filter(Boolean);
      return [
        { value: null, text: 'All Users' },
        ...users.map((user) => ({ value: user, text: user })),
      ];
    },
    columnFilteredItems() {
      let items = this.items_StatusTable;

      // Filter by category (ApproveStatus uses 'category' field)
      if (this.categoryFilter) {
        items = items.filter((item) => item.category === this.categoryFilter);
      }

      // Filter by user name (exact match from dropdown)
      if (this.userFilter) {
        items = items.filter((item) => item.status_user_name === this.userFilter);
      }

      // Filter by date range
      if (this.dateRangeStart || this.dateRangeEnd) {
        items = items.filter((item) => {
          if (!item.status_date) return false;
          const itemDate = new Date(item.status_date.substring(0, 10));
          if (this.dateRangeStart) {
            const startDate = new Date(this.dateRangeStart);
            if (itemDate < startDate) return false;
          }
          if (this.dateRangeEnd) {
            const endDate = new Date(this.dateRangeEnd);
            if (itemDate > endDate) return false;
          }
          return true;
        });
      }

      return items;
    },
  },
  watch: {
    categoryFilter() {
      this.currentPage = 1;
      this.totalRows = this.columnFilteredItems.length;
    },
    userFilter() {
      this.currentPage = 1;
      this.totalRows = this.columnFilteredItems.length;
    },
    dateRangeStart() {
      this.currentPage = 1;
      this.totalRows = this.columnFilteredItems.length;
    },
    dateRangeEnd() {
      this.currentPage = 1;
      this.totalRows = this.columnFilteredItems.length;
    },
  },
  mounted() {
    this.loadStatusList();
  },
  methods: {
    async loadStatusList() {
      this.loading_status_approve = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.status_options = response.data;

        this.loadStatusTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadStatusTableData() {
      this.isBusy = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/status`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.items_StatusTable = response.data;
        this.totalRows = response.data.length;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();

      this.isBusy = false;
      this.loading_status_approve = false;
    },
    async loadStatusInfo(status_id) {
      this.loading_status_modal = true;

      const apiGetURL = `${import.meta.env.VITE_API_URL}/api/status/${status_id}`;

      try {
        const response = await this.axios.get(apiGetURL);

        // compose entity
        this.status_info = new Status(
          response.data[0].category_id,
          response.data[0].comment,
          response.data[0].problematic
        );

        this.status_info.status_id = response.data[0].status_id;
        this.status_info.status_user_role = response.data[0].status_user_role;
        this.status_info.status_user_name = response.data[0].status_user_name;
        this.status_info.entity_id = response.data[0].entity_id;

        this.statusLoadedData = {
          category_id: this.status_info.category_id,
          comment: this.status_info.comment || '',
          problematic: this.status_info.problematic || false,
        };

        this.loading_status_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async getEntity(entity_input) {
      const apiGetURL = `${import.meta.env.VITE_API_URL}/api/entity?filter=equals(entity_id,${
        entity_input
      })`;

      try {
        const response = await this.axios.get(apiGetURL);
        // assign to local variable
        [this.entity_info] = response.data.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitStatusChange() {
      // Silent skip when nothing changed
      if (!this.hasStatusChanges) {
        this.$refs[this.statusModal.id].hide();
        return;
      }
      // Mark busy so the hide handler allows modal close during save
      this.isBusy = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/update`;

      // remove additional data before submission
      // TODO: replace this workaround
      this.status_info.status_user_name = null;
      this.status_info.status_user_role = null;
      this.status_info.entity_id = null;

      // perform update PUT request
      try {
        await this.axios.put(
          apiUrl,
          { status_json: this.status_info },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );

        const message = 'The new status for this entity has been submitted successfully.';
        this.makeToast(message, 'Success', 'success');
        this.announce(message);
        this.resetForm();
        this.loadStatusTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Error submitting status', 'assertive');
      }
    },
    resetForm() {
      this.entity_info = {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      };
      this.status_info = new Status();
      this.statusLoadedData = null;
    },
    onStatusModalHide(event) {
      if (this.pendingDiscardTarget === 'status') {
        this.pendingDiscardTarget = null;
        return;
      }
      if (this.hasStatusChanges && !this.isBusy) {
        event.preventDefault();
        this.pendingDiscardTarget = 'status';
        this.$refs.confirmDiscardDialog.show();
      }
    },
    onConfirmDiscard() {
      if (this.pendingDiscardTarget === 'status') {
        this.$refs[this.statusModal.id].hide();
      }
    },
    infoApproveStatus(item, _index, _button) {
      this.approveModal.title = `sysndd:${item.entity_id}`;
      this.approveModal.hasDuplicates = item.duplicate === 'yes';
      this.loadStatusInfo(item.status_id);
      this.$refs[this.approveModal.id].show();
    },
    infoDismissStatus(item, _index, _button) {
      this.dismissModal.title = `sysndd:${item.entity_id}`;
      this.dismissModal.statusId = item.status_id;
      this.$refs[this.dismissModal.id].show();
    },
    async handleDismissOk(_bvModalEvt) {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/approve/${
        this.dismissModal.statusId
      }?status_ok=false`;

      try {
        await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );

        this.announce('Status dismissed successfully');
        this.loadStatusTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Error dismissing status', 'assertive');
      }
    },
    infoStatus(item, _index, _button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadStatusInfo(item.status_id);
      this.$refs[this.statusModal.id].show();
    },
    async handleStatusOk(_bvModalEvt) {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/approve/${
        this.status_info.status_id
      }?status_ok=true`;

      try {
        await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );

        this.announce('Status approved successfully');
        this.loadStatusTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Error approving status', 'assertive');
      }
    },
    async handleAllStatusOk() {
      if (this.approve_all_selected) {
        const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/approve/all?status_ok=true`;
        try {
          this.axios.put(
            apiUrl,
            {},
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            }
          );

          this.loadStatusTableData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    normalizeStatus(node) {
      return {
        id: node.category_id,
        label: node.category,
      };
    },
    // Normalize status options for BFormSelect
    // API returns { id, label } format
    normalizeStatusOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return options.map((opt) => ({
        value: opt.id,
        text: opt.label,
      }));
    },
    checkAllApprove() {
      this.$refs.approveAllModal.show();
    },
    onFiltered(filteredItems) {
      // Trigger pagination to update the number of buttons/pages due to filtering
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    // Function to truncate a string to a specified length.
    // If the string is longer than the specified length, it adds '...' to the end.
    // imported from utils.js
    truncate(str, n) {
      // Use the utility function here
      return Utils.truncate(str, n);
    },
    /**
     * Handles sortBy updates from Bootstrap-Vue-Next BTable
     * @param {Array} newSortBy - Array of sort objects [{key, order}]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
    },
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

/* Multi-line text truncation with ellipsis */
.text-truncate-multiline {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
  line-height: 1.4;
}

/* Cursor style for popover triggers */
.text-popover-trigger {
  cursor: help;
  border-bottom: 1px dotted #6c757d;
}

.text-popover-trigger:hover {
  background-color: rgba(0, 123, 255, 0.05);
  border-radius: 2px;
}
</style>

<!-- Non-scoped styles for popovers (rendered outside component DOM) -->
<style>
/* Wide popover for comment text */
.wide-popover {
  max-width: 400px !important;
}

.wide-popover .popover-header {
  font-size: 0.85rem;
  font-weight: 600;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
}

.wide-popover .popover-body {
  max-height: 250px;
  overflow-y: auto;
  font-size: 0.85rem;
  line-height: 1.5;
}

.popover-text-content {
  white-space: pre-wrap;
  word-break: break-word;
}
</style>

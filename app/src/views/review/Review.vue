<!-- views/review/Review.vue -->
<template>
  <div class="container-fluid">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
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
                    Re-review table
                    <BBadge
                      variant="primary"
                      class="ms-2"
                    >
                      {{ totalRows }} entities
                    </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <div class="d-flex align-items-center justify-content-end gap-2">
                    <!-- Curation mode switch -->
                    <BFormCheckbox
                      v-if="curator_mode"
                      v-model="curation_selected"
                      switch
                      size="sm"
                      class="mb-0 text-light"
                    >
                      Curation mode
                    </BFormCheckbox>

                    <!-- User info (compact) -->
                    <span class="d-none d-md-inline text-light small">
                      <i :class="'bi bi-' + user_icon[user.user_role[0]]" />
                      {{ user.user_name[0] }}
                    </span>

                    <!-- Refresh button -->
                    <BButton
                      v-b-tooltip.hover.bottom
                      variant="outline-light"
                      size="sm"
                      title="Refresh data"
                      aria-label="Refresh table data"
                      @click="loadReReviewData()"
                    >
                      <i class="bi bi-arrow-clockwise" />
                    </BButton>
                  </div>
                </BCol>
              </BRow>
            </template>

            <!-- Search, filters, and pagination row (single consolidated row) -->
            <BRow class="px-3 py-2 align-items-center">
              <!-- Search input -->
              <BCol
                cols="12"
                md="4"
                lg="3"
                class="mb-2 mb-md-0"
              >
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

              <!-- Column filters (always visible) -->
              <BCol
                cols="6"
                md="2"
                lg="2"
                class="mb-2 mb-md-0"
              >
                <BFormSelect
                  v-model="categoryFilter"
                  size="sm"
                  :options="categoryFilterOptions"
                  aria-label="Filter by category"
                />
              </BCol>
              <BCol
                cols="6"
                md="2"
                lg="2"
                class="mb-2 mb-md-0"
              >
                <BFormSelect
                  v-model="userFilter"
                  size="sm"
                  :options="userFilterOptions"
                  aria-label="Filter by user"
                />
              </BCol>

              <!-- Quick filters -->
              <BCol
                cols="12"
                md="4"
                lg="5"
                class="d-flex align-items-center justify-content-end gap-2 flex-wrap"
              >
                <!-- Quick filter tags -->
                <div class="d-flex align-items-center flex-wrap gap-1 me-2">
                  <BBadge
                    v-for="qf in activeQuickFilters"
                    :key="qf.key"
                    variant="secondary"
                    class="d-flex align-items-center gap-1"
                    style="cursor: pointer"
                    @click="removeQuickFilter(qf.key)"
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
                      @click="addQuickFilter(qf.key)"
                    >
                      {{ qf.label }}
                    </BDropdownItem>
                  </BDropdown>
                  <!-- New batch button -->
                  <BBadge
                    v-if="
                      (totalRows === 0) &&
                        ((filter === null) || (filter === '')) &&
                        !curation_selected
                    "
                    variant="warning"
                    pill
                    style="cursor: pointer"
                    @click="newBatchApplication()"
                  >
                    <i class="bi bi-plus-circle me-1" />
                    New batch
                  </BBadge>
                </div>

                <!-- Pagination controls -->
                <BInputGroup
                  prepend="Per page"
                  size="sm"
                >
                  <BFormSelect
                    id="per-page-select"
                    v-model="perPage"
                    :options="pageOptions"
                    size="sm"
                  />
                </BInputGroup>

                <BPagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  size="sm"
                  class="mb-0"
                  limit="2"
                />
              </BCol>
            </BRow>
            <!-- User Interface controls -->

            <!-- Main table element -->
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
              :empty-text="empty_table_text[curation_selected]"
              @update:sort-by="handleSortByUpdate"
              @filtered="onFiltered"
            >
              <template #cell(actions)="row">
                <!-- Edit Review button -->
                <BButton
                  v-b-tooltip.hover.left
                  size="sm"
                  class="me-1 btn-xs"
                  variant="outline-primary"
                  title="Edit review"
                  :aria-label="`Edit review for sysndd:${row.item.entity_id}`"
                  @click="infoReview(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-pencil-square" />
                </BButton>

                <!-- Edit Status button -->
                <BButton
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  variant="outline-secondary"
                  title="Edit status"
                  :aria-label="`Edit status for sysndd:${row.item.entity_id}`"
                  @click="infoStatus(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-stoplights" />
                </BButton>

                <!-- Submit button for review mode -->
                <BButton
                  v-if="!curation_selected"
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  :variant="row.item.re_review_review_saved ? 'success' : 'outline-success'"
                  title="Submit entity review"
                  :aria-label="`Submit review for sysndd:${row.item.entity_id}`"
                  @click="infoSubmit(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-send-check" />
                </BButton>

                <!-- Approve button for curation mode -->
                <BButton
                  v-if="curation_selected"
                  v-b-tooltip.hover.right
                  size="sm"
                  class="me-1 btn-xs"
                  variant="danger"
                  title="Approve entity review/status"
                  :aria-label="`Approve review/status for sysndd:${row.item.entity_id}`"
                  @click="infoApprove(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-check-circle-fill" />
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

              <template #cell(category)="data">
                <div class="overflow-hidden text-truncate text-center">
                  <span v-if="data.item.category" v-b-tooltip.hover.top :title="data.item.category">
                    <CategoryIcon
                      :category="data.item.category"
                      size="sm"
                      :show-title="false"
                    />
                  </span>
                  <span v-else class="text-muted">—</span>
                </div>
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <div class="overflow-hidden text-truncate text-center">
                  <span v-b-tooltip.hover.left :title="ndd_icon_text[data.item.ndd_phenotype_word]">
                    <NddIcon
                      :status="data.item.ndd_phenotype_word"
                      size="sm"
                      :show-title="false"
                    />
                  </span>
                </div>
              </template>

              <template #cell(review_date)="data">
                <div class="d-flex align-items-center gap-1">
                  <span
                    v-b-tooltip.hover.top
                    :title="data_age_text[dateYearAge(data.item.review_date, 3)]"
                    class="d-inline-flex align-items-center justify-content-center rounded-circle"
                    :class="`bg-${data_age_style[dateYearAge(data.item.review_date, 3)]}-subtle text-${data_age_style[dateYearAge(data.item.review_date, 3)]}`"
                    style="width: 24px; height: 24px; font-size: 0.75rem;"
                  >
                    <i class="bi bi-calendar3" />
                  </span>
                  <span class="small text-muted">
                    {{ data.item.review_date.substring(0,10) }}
                  </span>
                </div>
              </template>

              <template #cell(review_user_name)="data">
                <div class="d-flex align-items-center gap-1">
                  <span
                    v-b-tooltip.hover.top
                    :title="data.item.review_user_role"
                    class="d-inline-flex align-items-center justify-content-center rounded-circle"
                    :class="`bg-${user_style[data.item.review_user_role]}-subtle text-${user_style[data.item.review_user_role]}`"
                    style="width: 24px; height: 24px; font-size: 0.75rem;"
                  >
                    <i :class="'bi bi-' + user_icon[data.item.review_user_role]" />
                  </span>
                  <span class="small">
                    {{ data.item.review_user_name }}
                  </span>
                </div>
              </template>
            </BTable>
          </BCard>
        </BCol>
      </BRow>

      <!-- 1) Review modal -->
      <BModal
        :id="reviewModal.id"
        :ref="reviewModal.id"
        size="xl"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        :busy="reviewFormLoading"
        @show="onReviewModalShow"
        @ok="submitReviewChange"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-pencil-square me-2 text-primary" />
            <span class="fw-semibold">Edit Review</span>
          </div>
        </template>

        <template #footer="{ ok, cancel }">
          <div class="w-100 d-flex justify-content-between align-items-center">
            <div class="d-flex align-items-center gap-2 text-muted small">
              <span
                v-if="reviewFormIsSaving"
                class="d-flex align-items-center gap-1"
              >
                <BSpinner
                  small
                  variant="secondary"
                />
                <span>Saving...</span>
              </span>
              <span v-if="review_info.review_user_name" class="d-flex align-items-center gap-1">
                <i :class="'bi bi-' + user_icon[review_info.review_user_role]" />
                <span>{{ review_info.review_user_name }}</span>
                <span class="text-muted">·</span>
                <span>{{ review_info.review_date?.substring(0,10) }}</span>
              </span>
            </div>
            <div class="d-flex gap-2">
              <BButton
                variant="outline-secondary"
                @click="cancel()"
              >
                Cancel
              </BButton>
              <BButton
                variant="primary"
                @click="ok()"
              >
                <i class="bi bi-check-lg me-1" />
                Save Review
              </BButton>
            </div>
          </div>
        </template>

        <!-- Entity context header -->
        <div class="bg-light rounded-3 p-3 mb-4">
          <h6 class="text-muted mb-2 small text-uppercase fw-semibold">
            <i class="bi bi-info-circle me-1" />
            Entity Details
          </h6>
          <div class="d-flex flex-wrap gap-2">
            <EntityBadge
              v-if="review_info.entity_id"
              :entity-id="review_info.entity_id"
              :link-to="'/Entities/' + review_info.entity_id"
              size="sm"
            />
            <GeneBadge
              :symbol="entity_info.symbol"
              :hgnc-id="entity_info.hgnc_id"
              :link-to="'/Genes/' + entity_info.hgnc_id"
              size="sm"
            />
            <DiseaseBadge
              :name="entity_info.disease_ontology_name"
              :ontology-id="entity_info.disease_ontology_id_version"
              :link-to="'/Ontology/' + entity_info.disease_ontology_id_version.replace(/_.+/g, '')"
              :max-length="35"
              size="sm"
            />
            <InheritanceBadge
              :full-name="entity_info.hpo_mode_of_inheritance_term_name"
              :hpo-term="entity_info.hpo_mode_of_inheritance_term"
              size="sm"
            />
          </div>
        </div>

        <!-- Review form section -->
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-journal-text me-2" />
          Review Information
        </h6>

        <ReviewFormFields
          v-model="reviewFormData"
          :phenotypes-options="phenotypes_options"
          :variation-options="variation_ontology_options"
          :loading="reviewFormLoading"
        />
      </BModal>
      <!-- 1) Review modal -->

      <!-- 2) Status modal -->
      <BModal
        :id="statusModal.id"
        :ref="statusModal.id"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        :busy="statusFormLoading"
        @show="onStatusModalShow"
        @ok="submitStatusChange"
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
              <span
                v-if="statusFormIsSaving"
                class="d-flex align-items-center gap-1"
              >
                <BSpinner
                  small
                  variant="secondary"
                />
                <span>Saving...</span>
              </span>
              <span v-if="statusFormData.status_user_name" class="d-flex align-items-center gap-1">
                <i :class="'bi bi-' + user_icon[statusFormData.status_user_role]" />
                <span>{{ statusFormData.status_user_name }}</span>
                <span class="text-muted">·</span>
                <span>{{ statusFormData.status_date?.substring(0,10) }}</span>
              </span>
            </div>
            <div class="d-flex gap-2">
              <BButton
                variant="outline-secondary"
                @click="cancel()"
              >
                Cancel
              </BButton>
              <BButton
                variant="primary"
                @click="ok()"
              >
                <i class="bi bi-check-lg me-1" />
                Save Status
              </BButton>
            </div>
          </div>
        </template>

        <!-- Entity context header -->
        <div class="bg-light rounded-3 p-3 mb-4">
          <h6 class="text-muted mb-2 small text-uppercase fw-semibold">
            <i class="bi bi-info-circle me-1" />
            Entity Details
          </h6>
          <div class="d-flex flex-wrap gap-2">
            <EntityBadge
              v-if="statusFormData.entity_id"
              :entity-id="statusFormData.entity_id"
              :link-to="'/Entities/' + statusFormData.entity_id"
              size="sm"
            />
            <GeneBadge
              :symbol="entity_info.symbol"
              :hgnc-id="entity_info.hgnc_id"
              :link-to="'/Genes/' + entity_info.hgnc_id"
              size="sm"
            />
            <DiseaseBadge
              :name="entity_info.disease_ontology_name"
              :ontology-id="entity_info.disease_ontology_id_version"
              :link-to="'/Ontology/' + entity_info.disease_ontology_id_version.replace(/_.+/g, '')"
              :max-length="35"
              size="sm"
            />
            <InheritanceBadge
              :full-name="entity_info.hpo_mode_of_inheritance_term_name"
              :hpo-term="entity_info.hpo_mode_of_inheritance_term"
              size="sm"
            />
          </div>
        </div>

        <BOverlay
          :show="statusFormLoading"
          rounded="sm"
        >
          <BForm
            ref="form"
            @submit.stop.prevent="submitStatusChange"
          >
            <!-- Status Classification Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3">
              <i class="bi bi-diagram-3 me-2" />
              Classification
            </h6>

            <BFormGroup
              label="Status Category"
              label-for="status-select"
              class="mb-3"
            >
              <template #label>
                <span class="fw-semibold">Status Category</span>
                <BBadge
                  id="popover-badge-help-status"
                  pill
                  href="#"
                  variant="info"
                  class="ms-2"
                  style="cursor: help;"
                >
                  <i class="bi bi-question-circle-fill" />
                </BBadge>
              </template>
              <BFormSelect
                v-if="status_options && status_options.length > 0"
                id="status-select"
                v-model="statusFormData.category_id"
                :options="normalizeStatusOptions(status_options)"
              >
                <template #first>
                  <BFormSelectOption :value="null">
                    Select status...
                  </BFormSelectOption>
                </template>
              </BFormSelect>
            </BFormGroup>

            <BPopover
              target="popover-badge-help-status"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Status instructions
              </template>
              Please refer to the curation manual for details on the categories.
            </BPopover>

            <!-- Removal Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
              <i class="bi bi-exclamation-triangle me-2" />
              Entity Flags
            </h6>

            <BFormGroup class="mb-3">
              <template #label>
                <span class="fw-semibold">Removal Flag</span>
                <BBadge
                  id="popover-badge-help-removal"
                  pill
                  href="#"
                  variant="info"
                  class="ms-2"
                  style="cursor: help;"
                >
                  <i class="bi bi-question-circle-fill" />
                </BBadge>
              </template>
              <BFormCheckbox
                id="removeSwitch"
                v-model="statusFormData.problematic"
                switch
              >
                Suggest removal of this entity
              </BFormCheckbox>
            </BFormGroup>

            <BPopover
              target="popover-badge-help-removal"
              variant="info"
              triggers="focus"
            >
              <template #title>
                Removal instructions
              </template>
              SysNDD does not forget, meaning that entities will not be deleted
              but they can be deactivated. Deactivated entities will not be
              displayed on the website. Typically duplicate entities should be
              deactivated especially if there is a more specific disease name.
            </BPopover>

            <!-- Comment Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
              <i class="bi bi-chat-left-text me-2" />
              Notes
            </h6>

            <BFormGroup
              label="Comment"
              label-for="status-textarea-comment"
              class="mb-0"
            >
              <template #label>
                <span class="fw-semibold">Comment</span>
              </template>
              <BFormTextarea
                id="status-textarea-comment"
                v-model="statusFormData.comment"
                rows="3"
                placeholder="Why should this entity's status be changed..."
              />
            </BFormGroup>
          </BForm>
        </BOverlay>
      </BModal>
      <!-- 2) Status modal -->

      <!-- 3) Submit modal -->
      <BModal
        :id="submitModal.id"
        :ref="submitModal.id"
        size="md"
        centered
        ok-title="Submit Review"
        ok-variant="success"
        cancel-variant="outline-secondary"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        @ok="handleSubmitOk"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-send-check me-2 text-success" />
            <span class="fw-semibold">Submit Review</span>
          </div>
        </template>

        <div class="text-center py-3">
          <div class="mb-3">
            <span
              class="d-inline-flex align-items-center justify-content-center rounded-circle bg-success-subtle text-success"
              style="width: 64px; height: 64px; font-size: 1.5rem;"
            >
              <i class="bi bi-check2-circle" />
            </span>
          </div>
          <p class="mb-2">
            You have finished the re-review of entity
          </p>
          <p class="mb-3">
            <BBadge variant="primary" class="fs-6">
              {{ submitModal.title }}
            </BBadge>
          </p>
          <p class="text-muted small mb-0">
            Ready to submit for curator approval?
          </p>
        </div>
      </BModal>
      <!-- 3) Submit modal -->

      <!-- 4) Approve modal -->
      <BModal
        :id="approveModal.id"
        :ref="approveModal.id"
        size="md"
        centered
        ok-title="Approve"
        ok-variant="success"
        cancel-variant="outline-secondary"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        @ok="handleApproveOk"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-check-circle-fill me-2 text-success" />
            <span class="fw-semibold">Approve Entity</span>
          </div>
        </template>

        <!-- Entity context -->
        <div class="bg-light rounded-3 p-3 mb-4">
          <div class="d-flex align-items-center gap-2">
            <span class="text-muted small">Entity:</span>
            <BBadge variant="primary">
              {{ approveModal.title }}
            </BBadge>
          </div>
        </div>

        <!-- Approval options -->
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-check2-square me-2" />
          Select Items to Approve
        </h6>

        <div class="d-flex flex-column gap-2 mb-4">
          <BFormCheckbox
            id="approveReviewSwitch"
            v-model="review_approved"
            switch
          >
            <span class="fw-semibold">Review</span>
            <span class="text-muted small d-block">Approve the clinical synopsis and annotations</span>
          </BFormCheckbox>

          <BFormCheckbox
            id="approveStatusSwitch"
            v-model="status_approved"
            switch
          >
            <span class="fw-semibold">Status</span>
            <span class="text-muted small d-block">Approve the entity classification status</span>
          </BFormCheckbox>
        </div>

        <!-- Danger zone -->
        <div class="border border-warning rounded-3 p-3 bg-warning-subtle">
          <h6 class="text-warning mb-2">
            <i class="bi bi-exclamation-triangle me-1" />
            Other Actions
          </h6>
          <BButton
            size="sm"
            variant="outline-warning"
            @click="handleUnsetSubmission(), hideModal(approveModal.id)"
          >
            <i class="bi bi-unlock me-1" />
            Unsubmit Review
          </BButton>
          <p class="text-muted small mb-0 mt-2">
            Return this entity to the reviewer for further changes
          </p>
        </div>
      </BModal>
      <!-- 4) Approve modal -->
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols, useText } from '@/composables';
import useStatusForm from '@/views/curate/composables/useStatusForm';
import useReviewForm from '@/views/curate/composables/useReviewForm';
import ReviewFormFields from '@/views/curate/components/ReviewFormFields.vue';

// Import UI components for consistent icons and badges
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';

export default {
  name: 'ReviewView',
  components: {
    ReviewFormFields,
    CategoryIcon,
    NddIcon,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();

    // Initialize status form composable
    const statusForm = useStatusForm();
    const {
      formData: statusFormData,
      loading: statusFormLoading,
      isSaving: statusFormIsSaving,
    } = statusForm;

    // Initialize review form composable
    const reviewForm = useReviewForm();
    const {
      formData: reviewFormData,
      loading: reviewFormLoading,
      isSaving: reviewFormIsSaving,
    } = reviewForm;

    return {
      makeToast,
      ...colorAndSymbols,
      ...text,
      statusFormData,
      statusFormLoading,
      statusFormIsSaving,
      statusForm,
      reviewFormData,
      reviewFormLoading,
      reviewFormIsSaving,
      reviewForm,
    };
  },
  data() {
    return {
      items: [],
      fields: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
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
          class: 'text-center',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: true,
          class: 'text-center',
        },
        {
          key: 'review_date',
          label: 'Review date',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'review_user_name',
          label: 'User',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-center',
        },
      ],
      totalRows: 1,
      currentPage: 1,
      perPage: 25,
      pageOptions: [10, 25, 50, 100],
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'entity_id', order: 'asc' }],
      filter: null,
      filterOn: [],
      // Column filter controls
      categoryFilter: null,
      userFilter: null,
      quickFilters: {
        pending: false,
        submitted: false,
        needsStatus: false,
      },
      // Quick filter definitions
      quickFilterDefs: [
        { key: 'pending', label: 'Pending Review' },
        { key: 'submitted', label: 'Submitted' },
        { key: 'needsStatus', label: 'Needs Status' },
      ],
      reviewModal: {
        id: 'review-modal',
        title: '',
        content: [],
      },
      statusModal: {
        id: 'status-modal',
        title: '',
        content: [],
      },
      submitModal: {
        id: 'submit-modal',
        title: '',
        content: [],
      },
      approveModal: {
        id: 'approve-modal',
        title: '',
        content: [],
      },
      review: [{ synopsis: '' }],
      review_fields: [
        { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-start' },
      ],
      status_options: [],
      status_info: new Status(),
      loading_status_modal: true,
      entity_info: {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      },
      review_info: new Review(),
      phenotypes_options: [],
      variation_ontology_options: [],
      curation_selected: false,
      review_approved: false,
      status_approved: false,
      curator_mode: 0,
      loading: true,
      user: {
        user_id: [],
        user_name: [],
        email: [],
        user_role: [],
        user_created: [],
        abbreviation: [],
        orcid: [],
        exp: [],
      },
      isBusy: true,
    };
  },
  computed: {
    sortOptions() {
      // Create an options list from our fields
      return this.fields
        .filter((f) => f.sortable)
        .map((f) => ({ text: f.label, value: f.key }));
    },
    // Quick filter computed properties
    activeQuickFilters() {
      return this.quickFilterDefs.filter((qf) => this.quickFilters[qf.key]);
    },
    availableQuickFilters() {
      return this.quickFilterDefs.filter((qf) => !this.quickFilters[qf.key]);
    },
    // Category filter options from unique values in items
    categoryFilterOptions() {
      const categories = [...new Set(this.items.map((item) => item.category))].filter(Boolean);
      return [
        { value: null, text: 'All Categories' },
        ...categories.map((cat) => ({ value: cat, text: cat })),
      ];
    },
    // User filter options from unique values in items
    userFilterOptions() {
      const users = [...new Set(this.items.map((item) => item.review_user_name))].filter(Boolean);
      return [
        { value: null, text: 'All Users' },
        ...users.map((user) => ({ value: user, text: user })),
      ];
    },
    // Filtered items based on category and user filters
    filteredItems() {
      let result = this.items;

      // Apply category filter
      if (this.categoryFilter) {
        result = result.filter((item) => item.category === this.categoryFilter);
      }

      // Apply user filter
      if (this.userFilter) {
        result = result.filter((item) => item.review_user_name === this.userFilter);
      }

      // Apply quick filters
      if (this.quickFilters.pending) {
        result = result.filter((item) => !item.re_review_review_saved);
      }
      if (this.quickFilters.submitted) {
        result = result.filter((item) => item.re_review_review_saved && !item.approved);
      }
      if (this.quickFilters.needsStatus) {
        result = result.filter((item) => !item.status_id || !item.re_review_status_saved);
      }

      return result;
    },
  },
  watch: {
    // used to reload table when switching curator mode
    curation_selected() {
      this.loadReReviewData();
    },
    // Update totalRows when filters change
    filteredItems: {
      handler(newItems) {
        this.totalRows = newItems.length;
      },
      immediate: true,
    },
  },
  mounted() {
    if (localStorage.user) {
      this.user = JSON.parse(localStorage.user);
      this.curator_mode = (this.user.user_role[0] === 'Administrator')
        || (this.user.user_role[0] === 'Curator');
      console.log(this.user.user_role[0]);
      console.log(this.curator_mode);
    }
    this.loadReReviewData();
    this.loadPhenotypesList();
    this.loadVariationOntologyList();
    this.loadStatusList();
  },
  methods: {
    /**
     * Transform phenotype/variation tree to make all modifiers selectable children.
     * API returns: "present: X" as parent with [uncertain, variable, rare, absent] as children.
     * We want: "X" as parent with [present, uncertain, variable, rare, absent] as children.
     */
    transformModifierTree(nodes) {
      if (!Array.isArray(nodes)) return [];
      return nodes.map((node) => {
        // Extract phenotype name from "present: Phenotype Name" format
        const phenotypeName = node.label.replace(/^present:\s*/, '');
        // Extract the HP/ontology code from the ID (e.g., "1-HP:0001999" -> "HP:0001999")
        const ontologyCode = node.id.replace(/^\d+-/, '');

        // Create new parent with just the phenotype name
        const newParent = {
          id: `parent-${ontologyCode}`,
          label: phenotypeName,
          children: [
            // Add "present" as first child (the original parent node, now selectable)
            {
              id: node.id,
              label: `present: ${phenotypeName}`,
            },
            // Add all other modifiers as children with phenotype name for context
            ...(node.children || []).map((child) => {
              const modifier = child.label.replace(/:\s*.*$/, '');
              return {
                id: child.id,
                label: `${modifier}: ${phenotypeName}`,
              };
            }),
          ],
        };

        return newParent;
      });
    },
    async loadPhenotypesList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        const rawData = Array.isArray(response.data)
          ? response.data
          : response.data?.data || [];
        // Transform to make all modifiers selectable
        this.phenotypes_options = this.transformModifierTree(rawData);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.phenotypes_options = [];
      }
    },
    async loadVariationOntologyList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/variation_ontology?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        const rawData = Array.isArray(response.data)
          ? response.data
          : response.data?.data || [];
        // Transform to make all modifiers selectable
        this.variation_ontology_options = this.transformModifierTree(rawData);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.variation_ontology_options = [];
      }
    },
    async loadStatusList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.status_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    normalizeStatus(node) {
      return {
        id: node.category_id,
        label: node.category,
      };
    },
    // Normalize status options for BFormSelect
    normalizeStatusOptions(options) {
      if (!options || !Array.isArray(options)) return [];
      return options.map((opt) => ({
        value: opt.id,
        text: opt.label,
      }));
    },
    onFiltered(filteredItems) {
      // Trigger pagination to update the number of buttons/pages due to filtering
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    resetApproveModal() {
      this.status_approved = false;
      this.review_approved = false;
    },
    async infoReview(item, index, button) {
      this.reviewModal.title = `sysndd:${item.entity_id}`;
      await this.getEntity(item.entity_id);

      // Clear any existing draft and load fresh data from server
      this.reviewForm.clearDraft();
      await this.reviewForm.loadReviewData(item.review_id, item.re_review_review_saved);

      // Load review metadata for footer display
      await this.loadReviewInfo(item.review_id, item.re_review_review_saved);

      this.$refs[this.reviewModal.id].show();
    },
    async infoStatus(item, index, button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      await this.getEntity(item.entity_id);

      // Clear any existing draft and load fresh data from server
      this.statusForm.clearDraft();
      await this.statusForm.loadStatusData(item.status_id, item.re_review_status_saved);

      this.$refs[this.statusModal.id].show();
    },
    infoSubmit(item, index, button) {
      this.submitModal.title = `sysndd:${item.entity_id}`;
      this.entity = [];
      this.entity.push(item);
      this.$refs[this.submitModal.id].show();
    },
    infoApprove(item, index, button) {
      this.approveModal.title = `sysndd:${item.entity_id}`;
      this.entity = [];
      this.entity.push(item);
      this.$refs[this.approveModal.id].show();
    },
    async loadReReviewData() {
      this.isBusy = true;
      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/re_review/table?curate=${
        this.curation_selected}`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });

        this.items = response.data.data || [];
        this.totalRows = response.data.data?.length || 0;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.isBusy = false;
      this.loading = false;
    },
    async getEntity(entity_input) {
      const apiGetURL = `${import.meta.env.VITE_API_URL
      }/api/entity?filter=equals(entity_id,${
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
    async loadReviewInfo(review_id, re_review_review_saved) {
      // Load form data via composable
      await this.reviewForm.loadReviewData(review_id, re_review_review_saved);

      // Also load metadata for modal footer display
      const apiGetReviewURL = `${import.meta.env.VITE_API_URL}/api/review/${review_id}`;
      try {
        const response_review = await this.axios.get(apiGetReviewURL);
        if (response_review.data && response_review.data.length > 0) {
          this.review_info.review_id = response_review.data[0].review_id;
          this.review_info.entity_id = response_review.data[0].entity_id;
          this.review_info.review_user_name = response_review.data[0].review_user_name;
          this.review_info.review_user_role = response_review.data[0].review_user_role;
          this.review_info.review_date = response_review.data[0].review_date;
          this.review_info.re_review_review_saved = re_review_review_saved;
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadStatusInfo(status_id, re_review_status_saved) {
      this.loading_status_modal = true;

      const apiGetURL = `${import.meta.env.VITE_API_URL}/api/status/${status_id}`;

      try {
        const response = await this.axios.get(apiGetURL);

        // compose entity
        this.status_info = new Status(
          response.data[0].category_id,
          response.data[0].comment,
          response.data[0].problematic,
        );

        this.status_info.status_id = response.data[0].status_id;
        this.status_info.entity_id = response.data[0].entity_id;
        this.status_info.status_user_name = response.data[0].status_user_name;
        this.status_info.status_user_role = response.data[0].status_user_role;
        this.status_info.status_date = response.data[0].status_date;
        this.status_info.re_review_status_saved = re_review_status_saved;

        this.loading_status_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitStatusChange() {
      try {
        // Check if status exists (has status_id) to determine create vs update
        // Note: re_review_status_saved only tracks if saved during THIS re-review cycle
        const isUpdate = this.statusFormData.status_id != null;
        await this.statusForm.submitForm(isUpdate, true); // reReview = true
        this.makeToast('Status submitted successfully', 'Success', 'success');
        this.statusForm.resetForm();
        this.loadReReviewData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitReviewChange() {
      try {
        // Check if review exists (has review_id) to determine create vs update
        // Note: re_review_review_saved only tracks if saved during THIS re-review cycle
        const isUpdate = this.review_info.review_id != null;
        await this.reviewForm.submitForm(isUpdate, true); // reReview = true
        this.makeToast('Review submitted successfully', 'Success', 'success');
        this.reviewForm.resetForm();
        this.loadReReviewData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    resetForm() {
      // status
      this.statusForm.resetForm();

      // review
      this.reviewForm.resetForm();
      this.entity_info = {
        entity_id: 0,
        symbol: '',
        hgnc_id: '',
        disease_ontology_id_version: '',
        disease_ontology_name: '',
        hpo_mode_of_inheritance_term_name: '',
        hpo_mode_of_inheritance_term: '',
      };
      this.review_info = new Review();
    },
    async handleSubmitOk(bvModalEvt) {
      const re_review_submission = {};

      re_review_submission.re_review_entity_id = this.entity[0].re_review_entity_id;
      re_review_submission.re_review_submitted = 1;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/submit`;
      try {
        const response = await this.axios.put(
          apiUrl,
          { submit_json: re_review_submission },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.loadReReviewData();
    },
    async handleApproveOk(bvModalEvt) {
      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/re_review/approve/${
        this.entity[0].re_review_entity_id
      }?status_ok=${
        this.status_approved
      }&review_ok=${
        this.review_approved}`;

      try {
        const response = await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.resetApproveModal();
      this.loadReReviewData();
    },
    async handleUnsetSubmission(bvModalEvt) {
      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/re_review/unsubmit/${
        this.entity[0].re_review_entity_id}`;

      try {
        const response = await this.axios.put(
          apiUrl,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.resetApproveModal();
      this.loadReReviewData();
    },
    async newBatchApplication() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/re_review/batch/apply`;

      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.makeToast('Application send.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    saved(any_id) {
      // TODO: implement this server side and with real logic :D
      // check if id is new
      let number_return = 0;
      if (any_id <= 3650) {
        number_return = 0;
      } else {
        number_return = 1;
      }
      return number_return;
    },
    // Function to truncate a string to a specified length.
    // If the string is longer than the specified length, it adds '...' to the end.
    // imported from utils.js
    truncate(str, n) {
      // Use the utility function here
      return Utils.truncate(str, n);
    },
    dateYearAge(date, rounding) {
      // calculate the age based on the difference from current date
      // round to nearest input argument "rounding"
      return Math.round((Date.now() - Date.parse(date)) / 1000 / 60 / 60 / 24 / 365 / rounding) * rounding;
    },
    hideModal(id) {
      this.$refs[id].hide();
    },
    /**
     * Handles sortBy updates from Bootstrap-Vue-Next BTable
     * @param {Array} newSortBy - Array of sort objects [{key, order}]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
    },
    onReviewModalShow() {
      // Data is already loaded by infoReview() before show() is called
      // Do not reset here - it would clear the loaded data
      // The form state is managed by infoReview() which calls clearDraft() then loadReviewData()
    },
    onStatusModalShow() {
      // Data is already loaded by infoStatus() before show() is called
      // Do not reset here - it would clear the loaded data
      // The form state is managed by infoStatus() which calls clearDraft() then loadStatusData()
    },
    // Quick filter methods
    addQuickFilter(key) {
      this.quickFilters[key] = true;
    },
    removeQuickFilter(key) {
      this.quickFilters[key] = false;
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
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

</style>

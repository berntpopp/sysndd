<!-- views/curate/ApproveReview.vue -->
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
                    Approve Reviews
                    <BBadge variant="primary" class="ms-2"> {{ totalRows }} reviews </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
                  <div class="d-flex align-items-center justify-content-end gap-2">
                    <!-- Approve all reviews button -->
                    <BButton
                      v-b-tooltip.hover.bottom
                      variant="danger"
                      size="sm"
                      title="Approve all pending reviews"
                      aria-label="Approve all reviews"
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
                      @click="loadReviewTableData()"
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
                class="d-flex align-items-center justify-content-end gap-2 flex-wrap"
              >
                <BInputGroup prepend="Per page" size="sm">
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
            <BSpinner v-if="loading_review_approve" label="Loading..." class="float-center m-5" />
            <BTable
              v-else
              :items="columnFilteredItems"
              :fields="fields_ReviewTable"
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

              <template #cell(synopsis)="data">
                <div
                  v-if="data.item.synopsis"
                  :id="'synopsis-' + data.item.entity_id"
                  class="text-truncate-multiline small text-popover-trigger"
                  style="max-width: 200px"
                >
                  {{ data.item.synopsis }}
                </div>
                <BPopover
                  v-if="data.item.synopsis"
                  :target="'synopsis-' + data.item.entity_id"
                  triggers="hover focus"
                  placement="top"
                  custom-class="wide-popover"
                >
                  <template #title>
                    <i class="bi bi-file-text me-1" />
                    Clinical Synopsis
                  </template>
                  <div class="popover-text-content">
                    {{ data.item.synopsis }}
                  </div>
                </BPopover>
                <span v-else class="text-muted small">—</span>
              </template>

              <template #cell(comment)="data">
                <div
                  v-if="data.item.comment"
                  :id="'comment-' + data.item.entity_id"
                  class="text-truncate-multiline small text-popover-trigger"
                  style="max-width: 150px"
                >
                  {{ data.item.comment }}
                </div>
                <BPopover
                  v-if="data.item.comment"
                  :target="'comment-' + data.item.entity_id"
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

              <template #cell(review_date)="data">
                <div class="d-flex align-items-center gap-1">
                  <span
                    v-b-tooltip.hover.top
                    :title="data.item.review_date"
                    class="d-inline-flex align-items-center justify-content-center rounded-circle bg-secondary-subtle text-secondary"
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
                    :class="`bg-${user_style[data.item.review_user_role]}-subtle text-${user_style[data.item.review_user_role]}`"
                    style="width: 24px; height: 24px; font-size: 0.75rem"
                  >
                    <i :class="'bi bi-' + user_icon[data.item.review_user_role]" />
                  </span>
                  <span class="small">
                    {{ data.item.review_user_name }}
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
                  title="Edit review"
                  :aria-label="`Edit review for entity ${row.item.entity_id}`"
                  @click="infoReview(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-pen" aria-hidden="true" />
                </BButton>

                <BButton
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  :variant="stoplights_style[row.item.active_category]"
                  :title="row.item.status_change ? 'Edit new status' : 'Edit status'"
                  :aria-label="`${row.item.status_change ? 'Edit new status' : 'Edit status'} for entity ${row.item.entity_id}`"
                  @click="infoStatus(row.item, row.index, $event.target)"
                >
                  <span class="position-relative d-inline-block" style="font-size: 0.9em">
                    <i class="bi bi-stoplights" aria-hidden="true" />
                    <i
                      v-if="row.item.status_change"
                      class="bi bi-exclamation-triangle-fill position-absolute"
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
                  title="Approve review"
                  :aria-label="`Approve review for entity ${row.item.entity_id}`"
                  @click="infoApproveReview(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-check2-circle" aria-hidden="true" />
                </BButton>
                <BButton
                  v-if="row.item.duplicate === 'yes'"
                  v-b-tooltip.hover.right
                  variant="danger"
                  title="Multiple unapproved reviews for this entity"
                  :aria-label="`Warning: Multiple unapproved reviews for entity ${row.item.entity_id}`"
                  size="sm"
                  class="me-1 btn-xs"
                >
                  <i class="bi bi-exclamation-triangle-fill" aria-hidden="true" />
                </BButton>
              </template>

              <template #row-details="row">
                <BCard class="mb-2 border-0 shadow-sm" body-class="p-3">
                  <div class="row g-3">
                    <!-- Entity Info Section -->
                    <div class="col-md-4">
                      <h6 class="text-muted small text-uppercase fw-semibold mb-2">
                        <i class="bi bi-info-circle me-1" />
                        Entity Details
                      </h6>
                      <div class="d-flex flex-column gap-2">
                        <div class="d-flex align-items-center gap-2">
                          <span class="text-muted small" style="min-width: 80px">Review ID:</span>
                          <BBadge variant="secondary">{{ row.item.review_id }}</BBadge>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                          <span class="text-muted small" style="min-width: 80px">Ontology:</span>
                          <code class="small">{{ row.item.disease_ontology_id_version }}</code>
                        </div>
                        <div class="d-flex align-items-center gap-2">
                          <span class="text-muted small" style="min-width: 80px">Primary:</span>
                          <BBadge :variant="row.item.is_primary ? 'success' : 'secondary'">
                            {{ row.item.is_primary ? 'Yes' : 'No' }}
                          </BBadge>
                        </div>
                      </div>
                    </div>

                    <!-- Synopsis Section -->
                    <div class="col-md-8">
                      <h6 class="text-muted small text-uppercase fw-semibold mb-2">
                        <i class="bi bi-file-text me-1" />
                        Full Synopsis
                      </h6>
                      <div
                        v-if="row.item.synopsis"
                        class="bg-light rounded p-2 small"
                        style="max-height: 120px; overflow-y: auto"
                      >
                        {{ row.item.synopsis }}
                      </div>
                      <span v-else class="text-muted small fst-italic">No synopsis available</span>

                      <!-- Comment if exists -->
                      <div v-if="row.item.comment" class="mt-3">
                        <h6 class="text-muted small text-uppercase fw-semibold mb-2">
                          <i class="bi bi-chat-left-text me-1" />
                          Comment
                        </h6>
                        <div class="bg-warning-subtle rounded p-2 small">
                          {{ row.item.comment }}
                        </div>
                      </div>
                    </div>
                  </div>
                </BCard>
              </template>
            </BTable>
            <!-- Main table -->
          </BCard>
        </BCol>
      </BRow>

      <!-- 1) Approve modal -->
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
        header-close-label="Close"
        @ok="handleApproveOk"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-check-circle-fill me-2 text-success" />
            <span class="fw-semibold">Approve Review</span>
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

        <div class="text-center py-2">
          <p class="mb-3">
            You have finished checking this review and are ready to <strong>approve</strong> it?
          </p>
        </div>

        <div v-if="entity.status_change">
          <!-- Status approval section -->
          <h6 class="text-muted border-bottom pb-2 mb-3">
            <i class="bi bi-stoplights me-2" />
            Status Change Detected
          </h6>

          <BFormCheckbox id="approveStatusSwitch" v-model="status_approved" switch>
            <span class="fw-semibold">Also approve new status</span>
            <span class="text-muted small d-block"
              >A status change was submitted with this review</span
            >
          </BFormCheckbox>
        </div>
      </BModal>
      <!-- 1) Approve modal -->

      <!-- 2) Modify review modal -->
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
        header-close-label="Close"
        :busy="loading_review_modal"
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
              <span v-if="review_info.review_user_name" class="d-flex align-items-center gap-1">
                <i :class="'bi bi-' + user_icon[review_info.review_user_role]" />
                <span>{{ review_info.review_user_name }}</span>
                <span class="text-muted">·</span>
                <span>{{ review_info.review_user_role }}</span>
              </span>
              <span v-if="entity_info.category" class="d-flex align-items-center gap-1">
                <span class="text-muted">·</span>
                <CategoryIcon :category="entity_info.category" size="sm" :show-title="true" />
              </span>
            </div>
            <div class="d-flex gap-2">
              <BButton variant="outline-secondary" @click="cancel()"> Cancel </BButton>
              <BButton variant="primary" @click="ok()">
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

        <!-- Review form section header -->
        <h6 class="text-muted border-bottom pb-2 mb-3">
          <i class="bi bi-journal-text me-2" />
          Review Information
        </h6>

        <BOverlay :show="loading_review_modal" rounded="sm">
          <BForm ref="form" @submit.stop.prevent="submitReviewChange">
            <!-- Synopsis Section -->
            <BFormGroup label="Synopsis" label-for="review-textarea-synopsis" class="mb-3">
              <template #label>
                <span class="fw-semibold">Synopsis</span>
              </template>
              <BFormTextarea
                id="review-textarea-synopsis"
                v-model="review_info.synopsis"
                rows="3"
                placeholder="Clinical synopsis of the entity..."
              />
            </BFormGroup>

            <!-- Phenotype Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
              <i class="bi bi-activity me-2" />
              Phenotypes & Variation
            </h6>

            <BFormGroup label="Phenotypes" label-for="review-phenotype-select" class="mb-3">
              <template #label>
                <span class="fw-semibold">Phenotypes</span>
              </template>
              <TreeMultiSelect
                v-if="phenotypes_options && phenotypes_options.length > 0"
                id="review-phenotype-select"
                v-model="select_phenotype"
                :options="phenotypes_options"
                placeholder="Select phenotypes..."
                search-placeholder="Search phenotypes (name or HP:ID)..."
              />
            </BFormGroup>

            <BFormGroup label="Variation Ontology" label-for="review-variation-select" class="mb-3">
              <template #label>
                <span class="fw-semibold">Variation Ontology</span>
              </template>
              <TreeMultiSelect
                v-if="variation_ontology_options && variation_ontology_options.length > 0"
                id="review-variation-select"
                v-model="select_variation"
                :options="variation_ontology_options"
                placeholder="Select variations..."
                search-placeholder="Search variation types..."
              />
            </BFormGroup>

            <!-- Literature Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
              <i class="bi bi-journal-bookmark me-2" />
              Literature References
            </h6>

            <BFormGroup label="Publications" label-for="review-publications-select" class="mb-3">
              <template #label>
                <span class="fw-semibold">Publications</span>
              </template>
              <BFormTags
                v-model="select_additional_references"
                input-id="review-literature-select"
                no-outer-focus
                class="my-0"
                separator=",;"
                :tag-validator="tagValidatorPMID"
                remove-on-delete
              >
                <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                  <BInputGroup class="my-0">
                    <BFormInput
                      v-bind="inputAttrs"
                      placeholder="Enter PMIDs separated by comma or semicolon"
                      class="form-control"
                      v-on="inputHandlers"
                    />
                    <BButton variant="outline-secondary" @click="addTag()"> Add </BButton>
                  </BInputGroup>

                  <div class="d-flex flex-wrap gap-1 mt-2">
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <BLink
                        :href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')"
                        target="_blank"
                        class="text-light"
                      >
                        <i class="bi bi-box-arrow-up-right me-1" />
                        {{ tag }}
                      </BLink>
                    </BFormTag>
                  </div>
                </template>
              </BFormTags>
            </BFormGroup>

            <BFormGroup label="GeneReviews" label-for="review-genereviews-select" class="mb-3">
              <template #label>
                <span class="fw-semibold">GeneReviews</span>
              </template>
              <BFormTags
                v-model="select_gene_reviews"
                input-id="review-genereviews-select"
                no-outer-focus
                class="my-0"
                separator=",;"
                :tag-validator="tagValidatorPMID"
                remove-on-delete
              >
                <template #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }">
                  <BInputGroup class="my-0">
                    <BFormInput
                      v-bind="inputAttrs"
                      placeholder="Enter PMIDs separated by comma or semicolon"
                      class="form-control"
                      v-on="inputHandlers"
                    />
                    <BButton variant="outline-secondary" @click="addTag()"> Add </BButton>
                  </BInputGroup>

                  <div class="d-flex flex-wrap gap-1 mt-2">
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <BLink
                        :href="'https://pubmed.ncbi.nlm.nih.gov/' + tag.replace('PMID:', '')"
                        target="_blank"
                        class="text-light"
                      >
                        <i class="bi bi-box-arrow-up-right me-1" />
                        {{ tag }}
                      </BLink>
                    </BFormTag>
                  </div>
                </template>
              </BFormTags>
            </BFormGroup>

            <!-- Comment Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
              <i class="bi bi-chat-left-text me-2" />
              Notes
            </h6>

            <BFormGroup label="Comment" label-for="review-textarea-comment" class="mb-0">
              <template #label>
                <span class="fw-semibold">Comment</span>
              </template>
              <BFormTextarea
                id="review-textarea-comment"
                v-model="review_info.comment"
                rows="3"
                placeholder="Additional comments to this entity relevant for the curator..."
              />
            </BFormGroup>
          </BForm>
        </BOverlay>
      </BModal>
      <!-- 2) Modify review modal -->

      <!-- 3) Status modal -->
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
        header-close-label="Close"
        :busy="loading_status_modal"
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
              <span v-if="status_info.status_user_name" class="d-flex align-items-center gap-1">
                <i :class="'bi bi-' + user_icon[status_info.status_user_role]" />
                <span>{{ status_info.status_user_name }}</span>
                <span class="text-muted">·</span>
                <span>{{ status_info.status_date?.substring(0, 10) }}</span>
              </span>
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

        <!-- Entity context header -->
        <div class="bg-light rounded-3 p-3 mb-4">
          <h6 class="text-muted mb-2 small text-uppercase fw-semibold">
            <i class="bi bi-info-circle me-1" />
            Entity Details
          </h6>
          <div class="d-flex flex-wrap gap-2">
            <EntityBadge
              v-if="status_info.entity_id"
              :entity-id="status_info.entity_id"
              :link-to="'/Entities/' + status_info.entity_id"
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

        <BOverlay :show="loading_status_modal" rounded="sm">
          <BForm ref="form" @submit.stop.prevent="submitStatusChange">
            <!-- Status Classification Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3">
              <i class="bi bi-diagram-3 me-2" />
              Classification
            </h6>

            <BFormGroup label="Status Category" label-for="status-select" class="mb-3">
              <template #label>
                <span class="fw-semibold">Status Category</span>
                <BBadge
                  id="popover-badge-help-status"
                  pill
                  href="#"
                  variant="info"
                  class="ms-2"
                  style="cursor: help"
                >
                  <i class="bi bi-question-circle-fill" />
                </BBadge>
              </template>
              <BFormSelect
                v-if="status_options && status_options.length > 0"
                id="status-select"
                v-model="status_info.category_id"
                :options="normalizeStatusOptions(status_options)"
              >
                <template #first>
                  <BFormSelectOption :value="null"> Select status... </BFormSelectOption>
                </template>
              </BFormSelect>
            </BFormGroup>

            <BPopover target="popover-badge-help-status" variant="info" triggers="focus">
              <template #title> Status instructions </template>
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
                  style="cursor: help"
                >
                  <i class="bi bi-question-circle-fill" />
                </BBadge>
              </template>
              <BFormCheckbox id="removeSwitch" v-model="status_info.problematic" switch>
                Suggest removal of this entity
              </BFormCheckbox>
            </BFormGroup>

            <BPopover target="popover-badge-help-removal" variant="info" triggers="focus">
              <template #title> Removal instructions </template>
              SysNDD does not forget, meaning that entities will not be deleted but they can be
              deactivated. Deactivated entities will not be displayed on the website. Typically
              duplicate entities should be deactivated especially if there is a more specific
              disease name.
            </BPopover>

            <!-- Comment Section -->
            <h6 class="text-muted border-bottom pb-2 mb-3 mt-4">
              <i class="bi bi-chat-left-text me-2" />
              Notes
            </h6>

            <BFormGroup label="Comment" label-for="status-textarea-comment" class="mb-0">
              <template #label>
                <span class="fw-semibold">Comment</span>
              </template>
              <BFormTextarea
                id="status-textarea-comment"
                v-model="status_info.comment"
                rows="3"
                placeholder="Why should this entity's status be changed..."
              />
            </BFormGroup>
          </BForm>
        </BOverlay>
      </BModal>
      <!-- 3) Status modal -->

      <!-- 4) Check approve all modal -->
      <BModal
        id="approveAllModal"
        ref="approveAllModal"
        size="md"
        centered
        ok-title="Approve All"
        ok-variant="danger"
        cancel-variant="outline-secondary"
        no-close-on-esc
        no-close-on-backdrop
        header-class="border-bottom-0 pb-0"
        footer-class="border-top-0 pt-0"
        header-close-label="Close"
        @ok="handleAllReviewsOk"
      >
        <template #title>
          <div class="d-flex align-items-center">
            <i class="bi bi-check2-all me-2 text-danger" />
            <span class="fw-semibold">Approve All Reviews</span>
          </div>
        </template>

        <div class="text-center py-3">
          <div class="mb-3">
            <span
              class="d-inline-flex align-items-center justify-content-center rounded-circle bg-danger-subtle text-danger"
              style="width: 64px; height: 64px; font-size: 1.5rem"
            >
              <i class="bi bi-exclamation-triangle" />
            </span>
          </div>
          <p class="mb-2">Are you sure you want to approve <strong>ALL</strong> reviews?</p>
          <p class="text-muted small mb-3">
            This will approve {{ totalRows }} pending reviews at once.
          </p>
        </div>

        <div class="border border-danger rounded-3 p-3 bg-danger-subtle">
          <BFormCheckbox id="confirmApproveAllSwitch" v-model="approve_all_selected" switch>
            <span class="fw-semibold"
              >{{ switch_approve_text[approve_all_selected] }}, I confirm this action</span
            >
          </BFormCheckbox>
        </div>
      </BModal>
      <!-- 4) Check approve all modal -->

      <!-- ARIA live region for screen reader announcements -->
      <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols, useText, useAriaLive } from '@/composables';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';

// Import UI components for consistent icons and badges
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import IconLegend from '@/components/accessibility/IconLegend.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ApproveReview',
  components: {
    TreeMultiSelect,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
    CategoryIcon,
    AriaLiveRegion,
    IconLegend,
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
      legendItems: [
        { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
        { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
        { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
        { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
        {
          icon: 'bi bi-exclamation-triangle-fill',
          color: '#dc3545',
          label: 'Status change pending',
        },
        { icon: 'bi bi-eye', color: '#0d6efd', label: 'Toggle details' },
        { icon: 'bi bi-pen', color: '#6c757d', label: 'Edit review' },
        { icon: 'bi bi-check2-circle', color: '#dc3545', label: 'Approve review' },
      ],
      phenotypes_options: [],
      variation_ontology_options: [],
      items_ReviewTable: [],
      fields_ReviewTable: [
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
          key: 'synopsis',
          label: 'Clinical synopsis',
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
          class: 'text-start',
        },
      ],
      fields_details_ReviewTable: [
        {
          key: 'review_id',
          label: 'Review ID',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-start',
        },
        {
          key: 'review_date',
          label: 'Review date',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'disease_ontology_id_version',
          label: 'Ontology ID version',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease ontology name',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'review_user_name',
          label: 'Review user',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'is_primary',
          label: 'Primary',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'synopsis',
          label: 'Clinical synopsis',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
      ],
      totalRows: 0,
      currentPage: 1,
      perPage: 100,
      pageOptions: [10, 25, 50, 100],
      categoryFilter: null,
      userFilter: null,
      dateRangeStart: null,
      dateRangeEnd: null,
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'review_user_name', order: 'asc' }],
      filter: null,
      filterOn: [],
      entity: {},
      approveModal: {
        id: 'approve-modal',
        title: '',
        content: [],
      },
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
      select_phenotype: [],
      select_variation: [],
      select_additional_references: [],
      select_gene_reviews: [],
      approve_all_selected: false,
      switch_approve_text: { true: 'Yes', false: 'No' },
      loading_review_approve: true,
      loading_review_modal: true,
      status_approved: false,
      isBusy: true,
    };
  },
  computed: {
    // Category filter options from unique values in items
    categoryFilterOptions() {
      const categories = [
        ...new Set(this.items_ReviewTable.map((item) => item.active_category)),
      ].filter(Boolean);
      return [
        { value: null, text: 'All Categories' },
        ...categories.map((cat) => ({ value: cat, text: cat })),
      ];
    },
    // User filter options from unique values in items
    userFilterOptions() {
      const users = [
        ...new Set(this.items_ReviewTable.map((item) => item.review_user_name)),
      ].filter(Boolean);
      return [
        { value: null, text: 'All Users' },
        ...users.map((user) => ({ value: user, text: user })),
      ];
    },
    columnFilteredItems() {
      let items = this.items_ReviewTable;

      // Filter by category (active_category)
      if (this.categoryFilter) {
        items = items.filter((item) => item.active_category === this.categoryFilter);
      }

      // Filter by user name (exact match from dropdown)
      if (this.userFilter) {
        items = items.filter((item) => item.review_user_name === this.userFilter);
      }

      // Filter by date range
      if (this.dateRangeStart || this.dateRangeEnd) {
        items = items.filter((item) => {
          if (!item.review_date) return false;
          const itemDate = new Date(item.review_date.substring(0, 10));
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
    select_additional_references: {
      handler(newVal) {
        const sanitizedValues = newVal.map(this.sanitizeInput);
        if (!this.arraysAreEqual(this.select_additional_references, sanitizedValues)) {
          this.select_additional_references = sanitizedValues;
        }
      },
      deep: true,
    },
    select_gene_reviews: {
      handler(newVal) {
        const sanitizedValues = newVal.map(this.sanitizeInput);
        if (!this.arraysAreEqual(this.select_gene_reviews, sanitizedValues)) {
          this.select_gene_reviews = sanitizedValues;
        }
      },
      deep: true,
    },
  },
  mounted() {
    this.loadStatusList();
    this.loadPhenotypesList();
    this.loadVariationOntologyList();
    this.loadReviewTableData();
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
    async loadStatusList() {
      this.loading_status_approve = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/status?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.status_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadPhenotypesList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        const rawData = Array.isArray(response.data) ? response.data : response.data?.data || [];
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
        const rawData = Array.isArray(response.data) ? response.data : response.data?.data || [];
        // Transform to make all modifiers selectable
        this.variation_ontology_options = this.transformModifierTree(rawData);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.variation_ontology_options = [];
      }
    },
    async loadReviewTableData() {
      // TODO: currently we show 200 entries sorted by user
      // TODO: need to replace with server side pagination
      // TODO: implement saved user settings for table configs
      this.isBusy = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/review`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.items_ReviewTable = response.data;
        this.totalRows = response.data.length;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();

      this.isBusy = false;
      this.loading_review_approve = false;
    },
    async loadReviewInfo(review_id) {
      this.loading_review_modal = true;

      const apiGetReviewURL = `${import.meta.env.VITE_API_URL}/api/review/${review_id}`;
      const apiGetPhenotypesURL = `${import.meta.env.VITE_API_URL}/api/review/${
        review_id
      }/phenotypes`;
      const apiGetVariationURL = `${import.meta.env.VITE_API_URL}/api/review/${review_id}/variation`;
      const apiGetPublicationsURL = `${import.meta.env.VITE_API_URL}/api/review/${
        review_id
      }/publications`;

      try {
        const response_review = await this.axios.get(apiGetReviewURL);
        const response_phenotypes = await this.axios.get(apiGetPhenotypesURL);
        const response_variation = await this.axios.get(apiGetVariationURL);
        const response_publications = await this.axios.get(apiGetPublicationsURL);

        // define phenotype specific attributes as constants from response
        const new_phenotype = response_phenotypes.data.map(
          (item) => new Phenotype(item.phenotype_id, item.modifier_id)
        );
        this.select_phenotype = response_phenotypes.data.map(
          (item) => `${item.modifier_id}-${item.phenotype_id}`
        );

        // define variation specific attributes as constants from response
        const new_variation = response_variation.data.map(
          (item) => new Variation(item.vario_id, item.modifier_id)
        );
        this.select_variation = response_variation.data.map(
          (item) => `${item.modifier_id}-${item.vario_id}`
        );

        // define publication specific attributes as constants from response
        const literature_gene_reviews = response_publications.data
          .filter((item) => item.publication_type === 'gene_review')
          .map((item) => item.publication_id);

        const literature_additional_references = response_publications.data
          .filter((item) => item.publication_type === 'additional_references')
          .map((item) => item.publication_id);

        this.select_additional_references = literature_additional_references;
        this.select_gene_reviews = literature_gene_reviews;

        const new_literature = new Literature(
          literature_additional_references,
          literature_gene_reviews
        );

        // compose review
        this.review_info = new Review(
          response_review.data[0].synopsis,
          new_literature,
          new_phenotype,
          new_variation,
          response_review.data[0].comment
        );

        this.review_info.review_id = response_review.data[0].review_id;
        this.review_info.entity_id = response_review.data[0].entity_id;
        this.review_info.review_user_name = response_review.data[0].review_user_name;
        this.review_info.review_user_role = response_review.data[0].review_user_role;

        this.loading_review_modal = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
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
        this.status_info.entity_id = response.data[0].entity_id;
        this.status_info.status_user_role = response.data[0].status_user_role;
        this.status_info.status_user_name = response.data[0].status_user_name;
        this.status_info.status_date = response.data[0].status_date;
        this.status_info.status_approved = response.data[0].status_approved;

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
    async submitReviewChange() {
      this.isBusy = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/review/update`;

      // define literature specific attributes as constants from inputs
      // first clean the arrays
      const select_additional_references_clean = this.select_additional_references.map((element) =>
        this.sanitizeInput(element)
      );

      const select_gene_reviews_clean = this.select_gene_reviews.map((element) =>
        this.sanitizeInput(element)
      );

      const replace_literature = new Literature(
        select_additional_references_clean,
        select_gene_reviews_clean
      );

      // compose phenotype specific attributes as constants from inputs
      const replace_phenotype = this.select_phenotype.map(
        (item) => new Phenotype(item.split('-')[1], item.split('-')[0])
      );

      // compose variation ontology specific attributes as constants from inputs
      const replace_variation_ontology = this.select_variation.map(
        (item) => new Variation(item.split('-')[1], item.split('-')[0])
      );

      // assign to object
      this.review_info.literature = replace_literature;
      this.review_info.phenotypes = replace_phenotype;
      this.review_info.variation_ontology = replace_variation_ontology;

      // perform update PUT request
      try {
        await this.axios.put(
          apiUrl,
          { review_json: this.review_info },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );

        const message = 'The new review for this entity has been submitted successfully.';
        this.makeToast(message, 'Success', 'success');
        this.announce(message);
        this.resetForm();
        this.loadReviewTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async submitStatusChange() {
      if (this.status_info.status_approved === 0) {
        // PUT to update if not approved
        const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/update`;

        // remove additional data before submission
        // TODO: replace this workaround
        this.status_info.status_user_name = null;
        this.status_info.status_user_role = null;
        this.status_info.entity_id = null;
        this.status_info.status_approved = null;

        // perform update PUT request
        try {
          const response = await this.axios.put(
            apiUrl,
            { status_json: this.status_info },
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            }
          );

          this.makeToast(
            `${'The new status for this entity has been submitted ' + '(status '}${
              response.status
            } (${response.statusText}).`,
            'Success',
            'success'
          );
          this.resetForm();
          this.loadReviewTableData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
          this.announce('Error submitting status', 'assertive');
        }
      } else if (this.status_info.status_approved === 1) {
        // POST to create new status if approved
        const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/create`;

        // remove additional data before submission
        // TODO: replace this workaround
        this.status_info.status_user_name = null;
        this.status_info.status_user_role = null;
        this.status_info.status_approved = null;

        // perform update PUT request
        try {
          await this.axios.post(
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
          this.loadReviewTableData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
          this.announce('Error submitting status', 'assertive');
        }
      }
    },
    infoReview(item, _index, _button) {
      this.reviewModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadReviewInfo(item.review_id);
      this.$refs[this.reviewModal.id].show();
    },
    infoApproveReview(item, _index, _button) {
      this.approveModal.title = `sysndd:${item.entity_id}`;
      this.entity = {};
      this.entity = item;
      this.$refs[this.approveModal.id].show();
    },
    async handleApproveOk(_bvModalEvt) {
      const apiUrlReview = `${import.meta.env.VITE_API_URL}/api/review/approve/${
        this.entity.review_id
      }?review_ok=true`;

      try {
        await this.axios.put(
          apiUrlReview,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          }
        );
        this.announce('Review approved successfully');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Error approving review', 'assertive');
      }

      // only call status EP if status should be approved too
      if (this.status_approved === true && this.entity.status_change === 1) {
        const apiUrlStatus = `${import.meta.env.VITE_API_URL}/api/status/approve/${
          this.entity.newest_status
        }?status_ok=true`;

        try {
          await this.axios.put(
            apiUrlStatus,
            {},
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            }
          );
          this.announce('Status also approved');
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
          this.announce('Error approving status', 'assertive');
        }
      }

      this.resetApproveModal();
      this.loadReviewTableData();
    },
    async handleAllReviewsOk() {
      if (this.approve_all_selected) {
        const apiUrl = `${import.meta.env.VITE_API_URL}/api/review/approve/all?review_ok=true`;
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

          this.loadReviewTableData();
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
      this.review_info = new Review();
      this.select_phenotype = [];
      this.select_variation = [];
      this.select_additional_references = [];
      this.select_gene_reviews = [];
    },
    infoStatus(item, _index, _button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadStatusInfo(item.newest_status);
      this.$refs[this.statusModal.id].show();
    },
    resetApproveModal() {
      this.status_approved = false;
    },
    tagValidatorPMID(tag) {
      // Individual PMID tag validator function
      const tag_copy = this.sanitizeInput(tag);
      return (
        !Number.isNaN(Number(tag_copy.replaceAll('PMID:', ''))) &&
        tag_copy.includes('PMID:') &&
        tag_copy.replace('PMID:', '').length > 4 &&
        tag_copy.replace('PMID:', '').length < 9
      );
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
     * Sanitizes the input by removing extra white spaces, especially for PubMed IDs.
     * Expected input format: "PMID: 123456"
     * Output format: "PMID:123456"
     * @param {String} input - The input string to be sanitized.
     * @return {String} The sanitized string.
     */
    sanitizeInput(input) {
      if (!input) return '';

      // Split the input based on ':' (e.g., "PMID: 123456")
      const parts = input.split(':');

      // Check if the input format is as expected
      if (parts.length !== 2 || !parts[0].trim().startsWith('PMID')) return input;

      // Trim whitespace from both parts and rejoin them
      return `${parts[0].trim()}:${parts[1].trim()}`;
    },
    arraysAreEqual(array1, array2) {
      if (array1.length !== array2.length) {
        return false;
      }
      return array1.every((value, index) => value === array2[index]);
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
/* Wide popover for synopsis/comment text */
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

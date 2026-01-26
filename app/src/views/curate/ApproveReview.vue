<!-- views/curate/ApproveReview.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
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
          >
            <template #header>
              <h6 class="mb-1 text-start font-weight-bold">
                Approve new reviews
              </h6>
            </template>
            <!-- User Interface controls -->

            <!-- button for approve all -->
            <BForm
              ref="form"
              class="p-1"
              @submit.stop.prevent="checkAllApprove"
            >
              <BButton
                size="sm"
                type="submit"
                variant="dark"
              >
                <i class="bi bi-check2-circle mx-1" />
                Approve all reviews
              </BButton>
            </BForm>
            <!-- button for approve all -->

            <!-- Table Interface controls -->
            <BRow>
              <BCol class="my-1">
                <BFormGroup class="mb-1">
                  <BInputGroup
                    prepend="Search"
                    size="sm"
                  >
                    <BFormInput
                      id="filter-input"
                      v-model="filter"
                      type="search"
                      placeholder="any field by typing here"
                      debounce="500"
                    />
                  </BInputGroup>
                </BFormGroup>
              </BCol>

              <BCol class="my-1" />

              <BCol class="my-1" />

              <BCol class="my-1">
                <BInputGroup
                  prepend="Per page"
                  class="mb-1"
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
                  align="fill"
                  size="sm"
                  class="my-0"
                  last-number
                />
              </BCol>
            </BRow>

            <!-- Column filters -->
            <BRow class="mb-2 px-2">
              <BCol md="3">
                <BFormGroup
                  label="Category"
                  label-size="sm"
                  class="mb-0"
                >
                  <BFormSelect
                    v-model="categoryFilter"
                    :options="categoryOptions"
                    size="sm"
                  >
                    <template #first>
                      <BFormSelectOption :value="null">
                        All Categories
                      </BFormSelectOption>
                    </template>
                  </BFormSelect>
                </BFormGroup>
              </BCol>
              <BCol md="3">
                <BFormGroup
                  label="User"
                  label-size="sm"
                  class="mb-0"
                >
                  <BFormInput
                    v-model="userFilter"
                    type="search"
                    placeholder="Filter by user..."
                    size="sm"
                    debounce="300"
                  />
                </BFormGroup>
              </BCol>
              <BCol md="3">
                <BFormGroup
                  label="From Date"
                  label-size="sm"
                  class="mb-0"
                >
                  <BFormInput
                    v-model="dateRangeStart"
                    type="date"
                    size="sm"
                  />
                </BFormGroup>
              </BCol>
              <BCol md="3">
                <BFormGroup
                  label="To Date"
                  label-size="sm"
                  class="mb-0"
                >
                  <BFormInput
                    v-model="dateRangeEnd"
                    type="date"
                    size="sm"
                  />
                </BFormGroup>
              </BCol>
            </BRow>
            <!-- Column filters -->
            <!-- Table Interface controls -->

            <!-- Main table -->
            <BSpinner
              v-if="loading_review_approve"
              label="Loading..."
              class="float-center m-5"
            />
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
                <div>
                  <BLink :href="'/Entities/' + data.item.entity_id">
                    <BBadge
                      variant="primary"
                      style="cursor: pointer"
                    >
                      sysndd:{{ data.item.entity_id }}
                    </BBadge>
                  </BLink>
                </div>
              </template>

              <template #cell(symbol)="data">
                <div class="font-italic">
                  <BLink :href="'/Genes/' + data.item.hgnc_id">
                    <BBadge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="success"
                      :title="data.item.hgnc_id"
                    >
                      {{ data.item.symbol }}
                    </BBadge>
                  </BLink>
                </div>
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="overflow-hidden text-truncate">
                  <BLink
                    :href="
                      '/Ontology/' +
                        data.item.disease_ontology_id_version.replace(/_.+/g, '')
                    "
                    target="_blank"
                  >
                    <BBadge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="secondary"
                      :title="
                        data.item.disease_ontology_name +
                          '; ' +
                          data.item.disease_ontology_id_version
                      "
                    >
                      {{ truncate(data.item.disease_ontology_name, 40) }}
                    </BBadge>
                  </BLink>
                </div>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div class="overflow-hidden text-truncate">
                  <BBadge
                    v-b-tooltip.hover.leftbottom
                    pill
                    variant="info"
                    class="justify-content-md-center"
                    size="1.3em"
                    :title="
                      data.item.hpo_mode_of_inheritance_term_name +
                        ' (' +
                        data.item.hpo_mode_of_inheritance_term +
                        ')'
                    "
                  >
                    {{
                      inheritance_short_text[
                        data.item.hpo_mode_of_inheritance_term_name
                      ]
                    }}
                  </BBadge>
                </div>
              </template>

              <template #cell(synopsis)="data">
                <div>
                  <BFormTextarea
                    v-b-tooltip.hover.leftbottom
                    plaintext
                    size="sm"
                    rows="1"
                    :value="data.item.synopsis"
                    :aria-label="'Synopsis for ' + data.item.entity_id"
                    :title="data.item.synopsis"
                  />
                </div>
              </template>

              <template #cell(comment)="data">
                <div>
                  <BFormTextarea
                    v-b-tooltip.hover.leftbottom
                    plaintext
                    size="sm"
                    rows="1"
                    :value="data.item.comment"
                    :aria-label="'Comment for ' + data.item.entity_id"
                    :title="data.item.comment"
                  />
                </div>
              </template>

              <template #cell(review_date)="data">
                <div>
                  <i class="bi bi-pen" />
                  <BBadge
                    v-b-tooltip.hover.right
                    variant="light"
                    :title="data.item.review_date"
                    class="ms-1"
                  >
                    {{ data.item.review_date.substring(0,10) }}
                  </BBadge>
                </div>
              </template>

              <template #cell(review_user_name)="data">
                <div>
                  <i :class="'bi bi-' + user_icon[data.item.review_user_role] + ' text-' + user_style[data.item.review_user_role]" />
                  <BBadge
                    v-b-tooltip.hover.right
                    :variant="user_style[data.item.review_user_role]"
                    :title="data.item.review_user_role"
                    class="ms-1"
                  >
                    {{ data.item.review_user_name }}
                  </BBadge>
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
                  <i :class="'bi bi-' + (row.detailsShowing ? 'eye-slash' : 'eye')" />
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
                  <i class="bi bi-pen" />
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
                  <span
                    class="position-relative d-inline-block"
                    style="font-size: 0.9em;"
                  >
                    <i class="bi bi-stoplights" />
                    <i
                      v-if="row.item.status_change"
                      class="bi bi-exclamation-triangle-fill position-absolute"
                      style="top: -0.3em; right: -0.5em; font-size: 0.7em;"
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
                  <i class="bi bi-check2-circle" />
                </BButton>
                <BButton
                  v-if="row.item.duplicate==='yes'"
                  v-b-tooltip.hover.right
                  variant="danger"
                  title="Multiple unapproved reviews for this entity"
                  :aria-label="`Warning: Multiple unapproved reviews for entity ${row.item.entity_id}`"
                  size="sm"
                  class="me-1 btn-xs"
                >
                  <i class="bi bi-exclamation-triangle-fill" />
                </BButton>
              </template>

              <template #row-details="row">
                <BCard>
                  <BTable
                    :items="[row.item]"
                    :fields="fields_details_ReviewTable"
                    stacked
                    small
                  />
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
        size="sm"
        centered
        ok-title="Approve"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        @ok="handleApproveOk"
      >
        <template #modal-title>
          <h4>
            Entity:
            <BBadge variant="primary">
              {{ approveModal.title }}
            </BBadge>
          </h4>
        </template>

        You have finished checking this review and
        <span class="font-weight-bold">want to submit it</span>?

        <div
          v-if="entity.status_change"
        >
          <div>
            Also approve new status?
          </div>

          <div class="custom-control custom-switch">
            <input
              id="approveStatusSwitch"
              v-model="status_approved"
              type="checkbox"
              button-variant="info"
              class="custom-control-input"
            >
            <label
              class="custom-control-label"
              for="approveStatusSwitch"
            >Status</label>
          </div>
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
        header-bg-variant="dark"
        header-text-variant="light"
        :busy="loading_review_modal"
        @ok="submitReviewChange"
      >
        <template #modal-title>
          <h4>
            Modify review for entity:
            <BLink
              :href="'/Entities/' + review_info.entity_id"
              target="_blank"
            >
              <BBadge variant="primary">
                sysndd:{{ review_info.entity_id }}
              </BBadge>
            </BLink>
            <BLink
              :href="'/Genes/' + entity_info.symbol"
              target="_blank"
            >
              <BBadge
                v-b-tooltip.hover.leftbottom
                pill
                variant="success"
                :title="entity_info.hgnc_id"
              >
                {{ entity_info.symbol }}
              </BBadge>
            </BLink>
            <BLink
              :href="
                '/Ontology/' +
                  entity_info.disease_ontology_id_version.replace(/_.+/g, '')
              "
              target="_blank"
            >
              <BBadge
                v-b-tooltip.hover.leftbottom
                pill
                variant="secondary"
                :title="
                  entity_info.disease_ontology_name +
                    '; ' +
                    entity_info.disease_ontology_id_version
                "
              >
                {{ truncate(entity_info.disease_ontology_name, 40) }}
              </BBadge>
            </BLink>
            <BBadge
              v-b-tooltip.hover.leftbottom
              pill
              variant="info"
              class="justify-content-md-center"
              size="1.3em"
              :title="
                entity_info.hpo_mode_of_inheritance_term_name +
                  ' (' +
                  entity_info.hpo_mode_of_inheritance_term +
                  ')'
              "
            >
              {{
                inheritance_short_text[
                  entity_info.hpo_mode_of_inheritance_term_name
                ]
              }}
            </BBadge>
          </h4>
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-start">
              Review by:
              <i :class="'bi bi-' + user_icon[review_info.review_user_role] + ' text-' + user_style[review_info.review_user_role]" />
              <BBadge
                :variant="user_style[review_info.review_user_role]"
                class="ms-1"
              >
                {{ review_info.review_user_name }}
              </BBadge>
              <BBadge
                :variant="user_style[review_info.review_user_role]"
                class="ms-1"
              >
                {{ review_info.review_user_role }}
              </BBadge>
            </p>

            <p class="float-start px-1">
              Current status:
              <BAvatar
                v-b-tooltip.hover.top
                size="1.4em"
                :variant="stoplights_style[entity_info.category_id]"
                :title="entity_info.category"
              >
                <i class="bi bi-stoplights" />
              </BAvatar>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <BButton
              variant="primary"
              class="float-end me-2"
              @click="ok()"
            >
              Save review
            </BButton>
            <BButton
              variant="secondary"
              class="float-end me-2"
              @click="cancel()"
            >
              Cancel
            </BButton>
          </div>
        </template>

        <BOverlay
          :show="loading_review_modal"
          rounded="sm"
        >
          <BForm
            ref="form"
            @submit.stop.prevent="submitReviewChange"
          >
            <!-- Synopsis textarea -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-synopsis"
            >Synopsis</label>
            <BFormTextarea
              id="review-textarea-synopsis"
              v-model="review_info.synopsis"
              rows="3"
              size="sm"
            />
            <!-- Synopsis textarea -->

            <!-- Phenotype select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-phenotype-select"
            >Phenotypes</label>

            <TreeMultiSelect
              v-if="phenotypes_options && phenotypes_options.length > 0"
              id="review-phenotype-select"
              v-model="select_phenotype"
              :options="phenotypes_options"
              placeholder="Select phenotypes..."
              search-placeholder="Search phenotypes (name or HP:ID)..."
            />
            <!-- Phenotype select -->

            <!-- Variation y select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-variation-select"
            >Variation ontology</label>

            <TreeMultiSelect
              v-if="variation_ontology_options && variation_ontology_options.length > 0"
              id="review-variation-select"
              v-model="select_variation"
              :options="variation_ontology_options"
              placeholder="Select variations..."
              search-placeholder="Search variation types..."
            />
            <!-- Variation ontology select -->

            <!-- publications tag form with links out -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-publications-select"
            >Publications</label>
            <BFormTags
              v-model="select_additional_references"
              input-id="review-literature-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <BInputGroup class="my-0">
                  <BFormInput
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <BButton
                    variant="secondary"
                    size="sm"
                    @click="addTag()"
                  >
                    Add
                  </BButton>
                </BInputGroup>

                <div class="d-inline-block">
                  <h6>
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <BLink
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                            tag.replace('PMID:', '')
                        "
                        target="_blank"
                        class="text-light"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ tag }}
                      </BLink>
                    </BFormTag>
                  </h6>
                </div>
              </template>
            </BFormTags>
            <!-- publications tag form with links out -->

            <!-- genereviews tag form with links out -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-genereviews-select"
            >Genereviews</label>
            <BFormTags
              v-model="select_gene_reviews"
              input-id="review-genereviews-select"
              no-outer-focus
              class="my-0"
              separator=",;"
              :tag-validator="tagValidatorPMID"
              remove-on-delete
            >
              <template
                #default="{ tags, inputAttrs, inputHandlers, addTag, removeTag }"
              >
                <BInputGroup class="my-0">
                  <BFormInput
                    v-bind="inputAttrs"
                    placeholder="Enter PMIDs separated by comma or semicolon"
                    class="form-control"
                    size="sm"
                    v-on="inputHandlers"
                  />
                  <BButton
                    variant="secondary"
                    size="sm"
                    @click="addTag()"
                  >
                    Add
                  </BButton>
                </BInputGroup>

                <div class="d-inline-block">
                  <h6>
                    <BFormTag
                      v-for="tag in tags"
                      :key="tag"
                      :title="tag"
                      variant="secondary"
                      @remove="removeTag(tag)"
                    >
                      <BLink
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                            tag.replace('PMID:', '')
                        "
                        target="_blank"
                        class="text-light"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ tag }}
                      </BLink>
                    </BFormTag>
                  </h6>
                </div>
              </template>
            </BFormTags>
            <!-- genereviews tag form with links out -->

            <!-- Review comment textarea -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="review-textarea-comment"
            >Comment</label>
            <BFormTextarea
              id="review-textarea-comment"
              v-model="review_info.comment"
              rows="2"
              size="sm"
              placeholder="Additional comments to this entity relevant for the curator."
            />
            <!-- Review comment textarea -->
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
        header-bg-variant="dark"
        header-text-variant="light"
        :busy="loading_status_modal"
        @ok="submitStatusChange"
      >
        <template #modal-title>
          <h4>
            Modify status for entity:
            <BLink
              :href="'/Entities/' + status_info.entity_id"
              target="_blank"
            >
              <BBadge variant="primary">
                sysndd:{{ status_info.entity_id }}
              </BBadge>
            </BLink>
            <BLink
              :href="'/Genes/' + entity_info.symbol"
              target="_blank"
            >
              <BBadge
                v-b-tooltip.hover.leftbottom
                pill
                variant="success"
                :title="entity_info.hgnc_id"
              >
                {{ entity_info.symbol }}
              </BBadge>
            </BLink>
            <BLink
              :href="
                '/Ontology/' +
                  entity_info.disease_ontology_id_version.replace(/_.+/g, '')
              "
              target="_blank"
            >
              <BBadge
                v-b-tooltip.hover.leftbottom
                pill
                variant="secondary"
                :title="
                  entity_info.disease_ontology_name +
                    '; ' +
                    entity_info.disease_ontology_id_version
                "
              >
                {{ truncate(entity_info.disease_ontology_name, 40) }}
              </BBadge>
            </BLink>
            <BBadge
              v-b-tooltip.hover.leftbottom
              pill
              variant="info"
              class="justify-content-md-center"
              size="1.3em"
              :title="
                entity_info.hpo_mode_of_inheritance_term_name +
                  ' (' +
                  entity_info.hpo_mode_of_inheritance_term +
                  ')'
              "
            >
              {{
                inheritance_short_text[
                  entity_info.hpo_mode_of_inheritance_term_name
                ]
              }}
            </BBadge>
          </h4>
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-start">
              Status by:
              <i :class="'bi bi-' + user_icon[status_info.status_user_role] + ' text-' + user_style[status_info.status_user_role]" />
              <BBadge
                :variant="user_style[status_info.status_user_role]"
                class="ms-1"
              >
                {{ status_info.status_user_name }}
              </BBadge>
              <BBadge
                :variant="user_style[status_info.status_user_role]"
                class="ms-1"
              >
                {{ status_info.status_user_role }}
              </BBadge>
              <BBadge
                variant="dark"
                class="ms-1"
              >
                {{ status_info.status_date }}
              </BBadge>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <BButton
              variant="primary"
              class="float-end me-2"
              @click="ok()"
            >
              Save status
            </BButton>
            <BButton
              variant="secondary"
              class="float-end me-2"
              @click="cancel()"
            >
              Cancel
            </BButton>
          </div>
        </template>

        <BOverlay
          :show="loading_status_modal"
          rounded="sm"
        >
          <BForm
            ref="form"
            @submit.stop.prevent="submitStatusChange"
          >
            <!-- Status select -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="status-select"
            >Status</label>

            <BBadge
              id="popover-badge-help-status"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>

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

            <BFormSelect
              v-if="status_options && status_options.length > 0"
              id="status-select"
              v-model="status_info.category_id"
              :options="normalizeStatusOptions(status_options)"
              size="sm"
            >
              <template #first>
                <BFormSelectOption :value="null">
                  Select status...
                </BFormSelectOption>
              </template>
            </BFormSelect>
            <!-- Status select -->

            <!-- Suggest removal switch -->
            <label
              class="mr-sm-2 font-weight-bold"
              for="removeSwitch"
            >Removal</label>

            <BBadge
              id="popover-badge-help-removal"
              pill
              href="#"
              variant="info"
            >
              <i class="bi bi-question-circle-fill" />
            </BBadge>

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

            <div class="custom-control custom-switch">
              <input
                id="removeSwitch"
                v-model="status_info.problematic"
                type="checkbox"
                button-variant="info"
                class="custom-control-input"
              >
              <label
                class="custom-control-label"
                for="removeSwitch"
              >Suggest removal</label>
            </div>
            <!-- Suggest removal switch -->

            <label
              class="mr-sm-2 font-weight-bold"
              for="status-textarea-comment"
            >Comment</label>
            <BFormTextarea
              id="status-textarea-comment"
              v-model="status_info.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entities status be changed."
            />
          </BForm>
        </BOverlay>
      </BModal>
      <!-- 3) Status modal -->

      <!-- 4) Check approve all modal -->
      <BModal
        id="approveAllModal"
        ref="approveAllModal"
        size="lg"
        centered
        ok-title="Submit"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        title="Approve all reviews"
        @ok="handleAllReviewsOk"
      >
        <p class="my-4">
          Are you sure you want to
          <span class="font-weight-bold">approve ALL</span> reviews below?
        </p>
        <div class="custom-control custom-switch">
          <input
            id="removeSwitch"
            v-model="approve_all_selected"
            type="checkbox"
            button-variant="info"
            class="custom-control-input"
          >
          <label
            class="custom-control-label"
            for="removeSwitch"
          ><b>{{ switch_approve_text[approve_all_selected] }}</b></label>
        </div>
      </BModal>
      <!-- 4) Check approve all modal -->
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols, useText } from '@/composables';
import useModalControls from '@/composables/useModalControls';
import TreeMultiSelect from '@/components/forms/TreeMultiSelect.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

import Entity from '@/assets/js/classes/submission/submissionEntity';
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
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();

    return {
      makeToast,
      ...colorAndSymbols,
      ...text,
    };
  },
  data() {
    return {
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
    categoryOptions() {
      return Object.keys(this.stoplights_style).map((key) => ({
        value: key,
        text: key,
      }));
    },
    columnFilteredItems() {
      let items = this.items_ReviewTable;

      // Filter by category (active_category)
      if (this.categoryFilter) {
        items = items.filter((item) => item.active_category === this.categoryFilter);
      }

      // Filter by user name (case-insensitive partial match)
      if (this.userFilter) {
        const searchTerm = this.userFilter.toLowerCase();
        items = items.filter(
          (item) => item.review_user_name && item.review_user_name.toLowerCase().includes(searchTerm),
        );
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
        this.phenotypes_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadVariationOntologyList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/list/variation_ontology?tree=true`;
      try {
        const response = await this.axios.get(apiUrl);
        this.variation_ontology_options = response.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
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
      const apiGetPhenotypesURL = `${import.meta.env.VITE_API_URL
      }/api/review/${
        review_id
      }/phenotypes`;
      const apiGetVariationURL = `${import.meta.env.VITE_API_URL}/api/review/${review_id}/variation`;
      const apiGetPublicationsURL = `${import.meta.env.VITE_API_URL
      }/api/review/${
        review_id
      }/publications`;

      try {
        const response_review = await this.axios.get(apiGetReviewURL);
        const response_phenotypes = await this.axios.get(apiGetPhenotypesURL);
        const response_variation = await this.axios.get(apiGetVariationURL);
        const response_publications = await this.axios.get(apiGetPublicationsURL);

        // define phenotype specific attributes as constants from response
        const new_phenotype = response_phenotypes.data.map((item) => new Phenotype(item.phenotype_id, item.modifier_id));
        this.select_phenotype = response_phenotypes.data.map((item) => `${item.modifier_id}-${item.phenotype_id}`);

        // define variation specific attributes as constants from response
        const new_variation = response_variation.data.map((item) => new Variation(item.vario_id, item.modifier_id));
        this.select_variation = response_variation.data.map((item) => `${item.modifier_id}-${item.vario_id}`);

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
          literature_gene_reviews,
        );

        // compose review
        this.review_info = new Review(
          response_review.data[0].synopsis,
          new_literature,
          new_phenotype,
          new_variation,
          response_review.data[0].comment,
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
          response.data[0].problematic,
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
    async submitReviewChange() {
      this.isBusy = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/review/update`;

      // define literature specific attributes as constants from inputs
      // first clean the arrays
      const select_additional_references_clean = this.select_additional_references.map(
        (element) => this.sanitizeInput(element),
      );

      const select_gene_reviews_clean = this.select_gene_reviews.map(
        (element) => this.sanitizeInput(element),
      );

      const replace_literature = new Literature(
        select_additional_references_clean,
        select_gene_reviews_clean,
      );

      // compose phenotype specific attributes as constants from inputs
      const replace_phenotype = this.select_phenotype.map((item) => new Phenotype(item.split('-')[1], item.split('-')[0]));

      // compose variation ontology specific attributes as constants from inputs
      const replace_variation_ontology = this.select_variation.map((item) => new Variation(item.split('-')[1], item.split('-')[0]));

      // assign to object
      this.review_info.literature = replace_literature;
      this.review_info.phenotypes = replace_phenotype;
      this.review_info.variation_ontology = replace_variation_ontology;

      // perform update PUT request
      try {
        const response = await this.axios.put(
          apiUrl,
          { review_json: this.review_info },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );

        this.makeToast(
          `${'The new review for this entity has been submitted '
            + '(status '}${
            response.status
          } (${
            response.statusText
          }).`,
          'Success',
          'success',
        );
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
            },
          );

          this.makeToast(
            `${'The new status for this entity has been submitted '
              + '(status '}${
              response.status
            } (${
              response.statusText
            }).`,
            'Success',
            'success',
          );
          this.resetForm();
          this.loadReviewTableData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
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
          const response = await this.axios.post(
            apiUrl,
            { status_json: this.status_info },
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            },
          );

          this.makeToast(
            `${'The new status for this entity has been submitted '
              + '(status '}${
              response.status
            } (${
              response.statusText
            }).`,
            'Success',
            'success',
          );
          this.resetForm();
          this.loadReviewTableData();
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    infoReview(item, index, button) {
      this.reviewModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadReviewInfo(item.review_id);
      const { showModal } = useModalControls();
      showModal(this.reviewModal.id);
    },
    infoApproveReview(item, index, button) {
      this.approveModal.title = `sysndd:${item.entity_id}`;
      this.entity = {};
      this.entity = item;
      const { showModal } = useModalControls();
      showModal(this.approveModal.id);
    },
    async handleApproveOk(bvModalEvt) {
      const apiUrlReview = `${import.meta.env.VITE_API_URL
      }/api/review/approve/${
        this.entity.review_id
      }?review_ok=true`;

      try {
        const response = await this.axios.put(
          apiUrlReview,
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

      // only call status EP if status should be approved too
      if (this.status_approved === true && this.entity.status_change === 1) {
        const apiUrlStatus = `${import.meta.env.VITE_API_URL
        }/api/status/approve/${
          this.entity.newest_status
        }?status_ok=true`;

        try {
          const response = await this.axios.put(
            apiUrlStatus,
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
      }

      this.resetApproveModal();
      this.loadReviewTableData();
    },
    async handleAllReviewsOk() {
      if (this.approve_all_selected) {
        const apiUrl = `${import.meta.env.VITE_API_URL
        }/api/review/approve/all?review_ok=true`;
        try {
          const response = this.axios.put(
            apiUrl,
            {},
            {
              headers: {
                Authorization: `Bearer ${localStorage.getItem('token')}`,
              },
            },
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
        value: opt.category_id,
        text: opt.category,
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
    infoStatus(item, index, button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadStatusInfo(item.newest_status);
      const { showModal } = useModalControls();
      showModal(this.statusModal.id);
    },
    resetApproveModal() {
      this.status_approved = false;
    },
    tagValidatorPMID(tag) {
      // Individual PMID tag validator function
      const tag_copy = this.sanitizeInput(tag);
      return (
        !Number.isNaN(Number(tag_copy.replaceAll('PMID:', '')))
        && tag_copy.includes('PMID:')
        && tag_copy.replace('PMID:', '').length > 4
        && tag_copy.replace('PMID:', '').length < 9
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

</style>

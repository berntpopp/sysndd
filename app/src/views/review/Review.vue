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
            :header-bg-variant="header_style[curation_selected]"
          >
            <template #header>
              <BRow>
                <BCol>
                  <h6 class="mb-1 text-start font-weight-bold">
                    Re-review table
                    <BBadge variant="primary">
                      Entities: {{ totalRows }}
                    </BBadge>
                  </h6>
                </BCol>
                <BCol>
                  <h6 class="mb-1 text-end font-weight-bold">
                    <i :class="'bi bi-' + user_icon[user.user_role[0]] + ' text-' + user_style[user.user_role[0]]" />
                    <BBadge
                      :variant="user_style[user.user_role[0]]"
                      class="ms-1"
                    >
                      {{ user.user_name[0] }}
                    </BBadge>
                    <BBadge
                      :variant="user_style[user.user_role[0]]"
                      class="ms-1"
                    >
                      {{ user.user_role[0] }}
                    </BBadge>
                    <BBadge
                      v-if="
                        (totalRows === 0) &
                          ((filter === null) | (filter === '')) &
                          !curation_selected
                      "
                      href="#"
                      variant="warning"
                      pill
                      @click="newBatchApplication()"
                    >
                      New batch
                    </BBadge>
                    <div
                      v-if="curator_mode"
                      class="custom-control custom-switch"
                    >
                      <input
                        id="curationSwitch"
                        v-model="curation_selected"
                        type="checkbox"
                        button-variant="info"
                        class="custom-control-input"
                      >
                      <label
                        class="custom-control-label"
                        for="curationSwitch"
                      >Switch to curation</label>
                    </div>
                  </h6>
                </BCol>
              </BRow>
            </template>

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
            <!-- User Interface controls -->

            <!-- Main table element -->
            <BTable
              :items="items"
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
                <BButton
                  v-b-tooltip.hover.left
                  size="sm"
                  class="me-1 btn-xs"
                  variant="secondary"
                  title="edit review"
                  @click="infoReview(row.item, row.index, $event.target)"
                >
                  <i
                    class="bi bi-pen"
                    :class="'text-' + review_style[saved(row.item.review_id)]"
                  />
                </BButton>

                <BButton
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  :variant="stoplights_style[row.item.category_id]"
                  title="edit status"
                  @click="infoStatus(row.item, row.index, $event.target)"
                >
                  <i
                    class="bi bi-stoplights"
                    :class="'text-' + status_style[saved(row.item.status_id)]"
                  />
                </BButton>

                <!-- Button for review mode -->
                <BButton
                  v-if="!curation_selected"
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  :variant="saved_style[row.item.re_review_review_saved]"
                  title="submit entity review"
                  @click="infoSubmit(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-check2-circle" />
                </BButton>

                <!-- Button for curation mode -->
                <BButton
                  v-if="curation_selected"
                  v-b-tooltip.hover.right
                  size="sm"
                  class="me-1 btn-xs"
                  variant="danger"
                  title="approve entity review/status"
                  @click="infoApprove(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-check2-circle" />
                </BButton>
              </template>

              <template #cell(entity_id)="data">
                <div class="overflow-hidden text-truncate">
                  <BLink
                    :href="'/Entities/' + data.item.entity_id"
                    target="_blank"
                  >
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
                <div class="font-italic overflow-hidden text-truncate">
                  <BLink
                    :href="'/Genes/' + data.item.hgnc_id"
                    target="_blank"
                  >
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

              <template #cell(ndd_phenotype_word)="data">
                <div class="overflow-hidden text-truncate">
                  <BAvatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                    :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                  >
                    <i :class="'bi bi-' + ndd_icon[data.item.ndd_phenotype_word]" />
                  </BAvatar>
                </div>
              </template>

              <template #cell(review_date)="data">
                <div>
                  <i class="bi bi-pen" />
                  <BBadge
                    v-b-tooltip.hover.right
                    :variant="data_age_style[dateYearAge(data.item.review_date, 3)]"
                    :title="data_age_text[dateYearAge(data.item.review_date, 3)]"
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
        header-bg-variant="dark"
        header-text-variant="light"
        :busy="reviewFormLoading"
        @show="onReviewModalShow"
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
              <BBadge
                variant="dark"
                class="ms-1"
              >
                {{ review_info.review_date }}
              </BBadge>
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

        <div v-if="reviewForm.isSaving || reviewForm.lastSavedFormatted" class="mb-2">
          <span v-if="reviewForm.isSaving" class="text-muted small">
            <BSpinner small /> Saving draft...
          </span>
          <span v-else-if="reviewForm.lastSavedFormatted" class="text-muted small">
            <i class="bi bi-save" /> Draft saved {{ reviewForm.lastSavedFormatted }}
          </span>
        </div>

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
        header-bg-variant="dark"
        header-text-variant="light"
        :busy="statusFormLoading"
        @show="onStatusModalShow"
        @ok="submitStatusChange"
      >
        <template #modal-title>
          <h4>
            Modify status for entity:
            <BLink
              :href="'/Entities/' + statusFormData.entity_id"
              target="_blank"
            >
              <BBadge variant="primary">
                sysndd:{{ statusFormData.entity_id }}
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
              <i :class="'bi bi-' + user_icon[statusFormData.status_user_role] + ' text-' + user_style[statusFormData.status_user_role]" />
              <BBadge
                :variant="user_style[statusFormData.status_user_role]"
                class="ms-1"
              >
                {{ statusFormData.status_user_name }}
              </BBadge>
              <BBadge
                :variant="user_style[statusFormData.status_user_role]"
                class="ms-1"
              >
                {{ statusFormData.status_user_role }}
              </BBadge>
              <BBadge
                variant="dark"
                class="ms-1"
              >
                {{ statusFormData.status_date }}
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
          :show="statusFormLoading"
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
              v-model="statusFormData.category_id"
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
                v-model="statusFormData.problematic"
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
              v-model="statusFormData.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entities status be changed."
            />
          </BForm>
        </BOverlay>
      </BModal>
      <!-- 2) Status modal -->

      <!-- 3) Submit modal -->
      <BModal
        :id="submitModal.id"
        size="sm"
        centered
        ok-title="Submit review"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        @ok="handleSubmitOk"
      >
        <template #modal-title>
          <h4>
            Entity:
            <BBadge variant="primary">
              {{ submitModal.title }}
            </BBadge>
          </h4>
        </template>

        You have finished the re-review of this entity and
        <span class="font-weight-bold">want to submit it</span>?
      </BModal>
      <!-- 3) Submit modal -->

      <!-- 4) Approve modal -->
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
        What should be approved ?

        <div class="custom-control custom-switch">
          <input
            id="approveReviewSwitch"
            v-model="review_approved"
            type="checkbox"
            button-variant="info"
            class="custom-control-input"
          >
          <label
            class="custom-control-label"
            for="approveReviewSwitch"
          >Review</label>
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

        <div>
          <BButton
            size="sm"
            variant="warning"
            @click="handleUnsetSubmission(), hideModal(approveModal.id)"
          >
            <i class="bi bi-unlock" /> Unsubmit
          </BButton>
        </div>
      </BModal>
      <!-- 4) Approve modal -->
    </BContainer>
  </div>
</template>

<script>
import { useToast, useColorAndSymbols, useText } from '@/composables';
import useModalControls from '@/composables/useModalControls';
import useStatusForm from '@/views/curate/composables/useStatusForm';
import useReviewForm from '@/views/curate/composables/useReviewForm';
import ReviewFormFields from '@/views/curate/components/ReviewFormFields.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';

export default {
  name: 'ReviewView',
  components: {
    ReviewFormFields,
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
    } = statusForm;

    // Initialize review form composable
    const reviewForm = useReviewForm();
    const {
      formData: reviewFormData,
      loading: reviewFormLoading,
    } = reviewForm;

    return {
      makeToast,
      ...colorAndSymbols,
      ...text,
      statusFormData,
      statusFormLoading,
      statusForm,
      reviewFormData,
      reviewFormLoading,
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
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: true,
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
      totalRows: 1,
      currentPage: 1,
      perPage: 10,
      pageOptions: [10, 25, 50, 200],
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'entity_id', order: 'asc' }],
      filter: null,
      filterOn: [],
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
  },
  watch: {
    // used to reload table when switching curator mode
    curation_selected() {
      this.loadReReviewData();
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
        value: opt.category_id,
        text: opt.category,
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

      // Check for existing draft before loading server data
      if (this.reviewForm.checkForDraft()) {
        // Show confirmation dialog
        const restore = window.confirm(
          'You have unsaved changes from a previous session. Would you like to restore them?',
        );
        if (restore) {
          this.reviewForm.restoreFromDraft();
        } else {
          this.reviewForm.clearDraft();
          await this.reviewForm.loadReviewData(item.review_id, item.re_review_review_saved);
        }
      } else {
        await this.reviewForm.loadReviewData(item.review_id, item.re_review_review_saved);
      }

      const { showModal } = useModalControls();
      showModal(this.reviewModal.id);
    },
    async infoStatus(item, index, button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      await this.getEntity(item.entity_id);

      // Check for existing draft before loading server data
      if (this.statusForm.checkForDraft()) {
        const restore = window.confirm(
          'You have unsaved changes from a previous session. Would you like to restore them?',
        );
        if (restore) {
          this.statusForm.restoreFromDraft();
        } else {
          this.statusForm.clearDraft();
          await this.statusForm.loadStatusData(item.status_id, item.re_review_status_saved);
        }
      } else {
        await this.statusForm.loadStatusData(item.status_id, item.re_review_status_saved);
      }

      const { showModal } = useModalControls();
      showModal(this.statusModal.id);
    },
    infoSubmit(item, index, button) {
      this.submitModal.title = `sysndd:${item.entity_id}`;
      this.entity = [];
      this.entity.push(item);
      const { showModal } = useModalControls();
      showModal(this.submitModal.id);
    },
    infoApprove(item, index, button) {
      this.approveModal.title = `sysndd:${item.entity_id}`;
      this.entity = [];
      this.entity.push(item);
      const { showModal } = useModalControls();
      showModal(this.approveModal.id);
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

        this.items = response.data;
        this.totalRows = response.data.length;
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
        const isUpdate = this.statusFormData.re_review_status_saved === 1;
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
        const isUpdate = this.review_info.re_review_review_saved === 1;
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
      const { hideModal: closeModal } = useModalControls();
      closeModal(id);
    },
    /**
     * Handles sortBy updates from Bootstrap-Vue-Next BTable
     * @param {Array} newSortBy - Array of sort objects [{key, order}]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
    },
    onReviewModalShow() {
      // Reset form state immediately on show (FORM-07: prevents stale data flash)
      this.reviewForm.resetForm();
    },
    onStatusModalShow() {
      // Reset form state immediately on show (FORM-07: prevents stale data flash)
      this.statusForm.resetForm();
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

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
            header-bg-variant="dark"
            header-text-variant="light"
          >
            <template #header>
              <BRow class="align-items-center">
                <BCol>
                  <h5 class="mb-0 text-start fw-bold">
                    Approve Status
                    <BBadge
                      variant="primary"
                      class="ms-2"
                    >
                      {{ totalRows }} statuses
                    </BBadge>
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
                      <i class="bi bi-check2-all me-1" />
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
                      <i class="bi bi-arrow-clockwise" />
                    </BButton>
                  </div>
                </BCol>
              </BRow>
            </template>
            <!-- User Interface controls -->

            <!-- Search, filters, and pagination row -->
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

              <!-- Spacer for alignment -->
              <BCol
                cols="12"
                md="4"
                lg="4"
                class="mb-2 mb-md-0"
              />

              <!-- Pagination controls -->
              <BCol
                cols="12"
                md="4"
                lg="5"
                class="d-flex justify-content-end align-items-center gap-2"
              >
                <BInputGroup
                  size="sm"
                  class="w-auto"
                >
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
              v-if="loading_status_approve"
              label="Loading..."
              class="float-center m-5"
            />
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
                <EntityBadge :entity-id="data.item.entity_id" />
              </template>

              <template #cell(symbol)="data">
                <GeneBadge
                  :symbol="data.item.symbol"
                  :hgnc-id="data.item.hgnc_id"
                />
              </template>

              <template #cell(disease_ontology_name)="data">
                <DiseaseBadge
                  :disease-name="data.item.disease_ontology_name"
                  :disease-id="data.item.disease_ontology_id_version"
                  :max-length="40"
                />
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <InheritanceBadge
                  :term-name="data.item.hpo_mode_of_inheritance_term_name"
                  :term-id="data.item.hpo_mode_of_inheritance_term"
                />
              </template>

              <template #cell(category)="data">
                <div>
                  <BAvatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    :variant="stoplights_style[data.item.category]"
                    :title="data.item.category"
                  >
                    <i class="bi bi-stoplights" />
                  </BAvatar>
                </div>
              </template>

              <template #cell(problematic)="data">
                <div>
                  <BAvatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    :variant="problematic_style[data.item.problematic]"
                    :title="problematic_text[data.item.problematic]"
                  >
                    <i :class="'bi bi-' + problematic_symbol[data.item.problematic]" />
                  </BAvatar>
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
                    :title="data.item.comment"
                  />
                </div>
              </template>

              <template #cell(status_date)="data">
                <div class="d-flex align-items-center">
                  <BAvatar
                    size="1.4em"
                    variant="light"
                    class="me-1"
                  >
                    <i class="bi bi-calendar3 text-muted" />
                  </BAvatar>
                  <span
                    v-b-tooltip.hover.right
                    class="text-muted small"
                    :title="data.item.status_date"
                  >
                    {{ data.item.status_date.substring(0,10) }}
                  </span>
                </div>
              </template>

              <template #cell(status_user_name)="data">
                <div class="d-flex align-items-center">
                  <BAvatar
                    size="1.4em"
                    :variant="user_style[data.item.status_user_role]"
                    class="me-1"
                  >
                    <i :class="'bi bi-' + user_icon[data.item.status_user_role]" />
                  </BAvatar>
                  <span
                    v-b-tooltip.hover.right
                    :title="data.item.status_user_role"
                  >
                    {{ data.item.status_user_name }}
                  </span>
                </div>
              </template>

              <template #cell(actions)="row">
                <div class="d-flex gap-1">
                  <BButton
                    v-b-tooltip.hover.top
                    size="sm"
                    class="btn-xs"
                    variant="outline-secondary"
                    title="Edit status"
                    :aria-label="`Edit status for entity ${row.item.entity_id}`"
                    @click="infoStatus(row.item, row.index, $event.target)"
                  >
                    <i class="bi bi-pencil" />
                  </BButton>

                  <BButton
                    v-b-tooltip.hover.top
                    size="sm"
                    class="btn-xs"
                    variant="outline-success"
                    title="Approve status"
                    :aria-label="`Approve status for entity ${row.item.entity_id}`"
                    @click="infoApproveStatus(row.item, row.index, $event.target)"
                  >
                    <i class="bi bi-check-lg" />
                  </BButton>
                </div>
              </template>

              <template #row-details="row">
                <BCard>
                  <BTable
                    :items="[row.item]"
                    :fields="fields_details_StatusTable"
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
            <i class="bi bi-question-circle text-primary" style="font-size: 2.5rem;" />
          </div>
          <p class="mb-2">
            You have finished checking this status for entity
            <BBadge variant="primary" class="mx-1">
              {{ approveModal.title }}
            </BBadge>
          </p>
          <p class="text-muted small">
            Click <strong>Approve</strong> to confirm and submit.
          </p>
        </div>
      </BModal>
      <!-- Approve modal -->

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
              <span>
                <i :class="'bi bi-' + user_icon[status_info.status_user_role] + ' text-' + user_style[status_info.status_user_role]" />
                <span class="ms-1">{{ status_info.status_user_name }}</span>
              </span>
              <BBadge
                :variant="user_style[status_info.status_user_role]"
                pill
              >
                {{ status_info.status_user_role }}
              </BBadge>
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

        <!-- Entity Context Header -->
        <div class="bg-light rounded-3 p-3 mb-3">
          <div class="d-flex flex-wrap align-items-center gap-2">
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
                v-b-tooltip.hover.bottom
                pill
                variant="success"
                :title="entity_info.hgnc_id"
              >
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
                :title="entity_info.disease_ontology_name + '; ' + entity_info.disease_ontology_id_version"
              >
                {{ truncate(entity_info.disease_ontology_name, 40) }}
              </BBadge>
            </BLink>
            <BBadge
              v-b-tooltip.hover.bottom
              pill
              variant="info"
              :title="entity_info.hpo_mode_of_inheritance_term_name + ' (' + entity_info.hpo_mode_of_inheritance_term + ')'"
            >
              {{ inheritance_short_text[entity_info.hpo_mode_of_inheritance_term_name] }}
            </BBadge>
          </div>
        </div>

        <BOverlay
          :show="loading_status_modal"
          rounded="sm"
        >
          <BForm
            ref="form"
            @submit.stop.prevent="submitStatusChange"
          >
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
                    <BFormSelectOption :value="null">
                      Select status...
                    </BFormSelectOption>
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
                <BFormCheckbox
                  id="removeSwitch"
                  v-model="status_info.problematic"
                  switch
                >
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
            <i class="bi bi-exclamation-triangle text-danger" style="font-size: 2.5rem;" />
          </div>
          <p class="mb-2">
            You are about to approve <strong>ALL</strong> {{ totalRows }} pending statuses.
          </p>
          <p class="text-muted small mb-3">
            This action cannot be undone. Please confirm by toggling the switch below.
          </p>
          <div class="d-flex justify-content-center">
            <BFormCheckbox
              id="approveAllSwitch"
              v-model="approve_all_selected"
              switch
              size="lg"
            >
              <strong>{{ approve_all_selected ? 'Yes, approve all' : 'No, cancel' }}</strong>
            </BFormCheckbox>
          </div>
        </div>
      </BModal>
      <!-- Check approve all modal -->
    </BContainer>
  </div>
</template>

<script>
// TODO: vue3-treeselect disabled pending Bootstrap-Vue-Next migration
// import the Treeselect component
// import Treeselect from '@zanmato/vue3-treeselect';
// import the Treeselect styles
// import '@zanmato/vue3-treeselect/dist/vue3-treeselect.min.css';

import { useToast, useColorAndSymbols, useText } from '@/composables';

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

export default {
  name: 'ApproveStatus',
  components: {
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
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
      },
      approve_all_selected: false,
      switch_approve_text: { true: 'Yes', false: 'No' },
      loading_status_approve: true,
      loading_status_modal: true,
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
      let items = this.items_StatusTable;

      // Filter by category (ApproveStatus uses 'category' field)
      if (this.categoryFilter) {
        items = items.filter((item) => item.category === this.categoryFilter);
      }

      // Filter by user name (case-insensitive partial match)
      if (this.userFilter) {
        const searchTerm = this.userFilter.toLowerCase();
        items = items.filter(
          (item) => item.status_user_name && item.status_user_name.toLowerCase().includes(searchTerm),
        );
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
          response.data[0].problematic,
        );

        this.status_info.status_id = response.data[0].status_id;
        this.status_info.status_user_role = response.data[0].status_user_role;
        this.status_info.status_user_name = response.data[0].status_user_name;
        this.status_info.entity_id = response.data[0].entity_id;

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
    async submitStatusChange() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/status/update`;

      // remove additional data before submission
      // TODO: replace this workaround
      this.status_info.status_user_name = null;
      this.status_info.status_user_role = null;
      this.status_info.entity_id = null;

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
        this.loadStatusTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
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
    },
    infoApproveStatus(item, index, button) {
      this.approveModal.title = `sysndd:${item.entity_id}`;
      this.loadStatusInfo(item.status_id);
      this.$refs[this.approveModal.id].show();
    },
    infoStatus(item, index, button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadStatusInfo(item.status_id);
      this.$refs[this.statusModal.id].show();
    },
    async handleStatusOk(bvModalEvt) {
      const apiUrl = `${import.meta.env.VITE_API_URL
      }/api/status/approve/${
        this.status_info.status_id
      }?status_ok=true`;

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

        this.loadStatusTableData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async handleAllStatusOk() {
      if (this.approve_all_selected) {
        const apiUrl = `${import.meta.env.VITE_API_URL
        }/api/status/approve/all?status_ok=true`;
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

:deep(.vue-treeselect__menu) {
  outline: 1px solid red;
  color: blue;
}
</style>

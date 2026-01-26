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
                Approve new status
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
                Approve all status
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
                <div>
                  <i class="bi bi-stoplights" />
                  <BBadge
                    v-b-tooltip.hover.right
                    variant="light"
                    :title="data.item.status_date"
                    class="ms-1"
                  >
                    {{ data.item.status_date.substring(0,10) }}
                  </BBadge>
                </div>
              </template>

              <template #cell(status_user_name)="data">
                <div>
                  <i :class="'bi bi-' + user_icon[data.item.status_user_role] + ' text-' + user_style[data.item.status_user_role]" />
                  <BBadge
                    v-b-tooltip.hover.right
                    :variant="user_style[data.item.status_user_role]"
                    :title="data.item.status_user_role"
                    class="ms-1"
                  >
                    {{ data.item.status_user_name }}
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
                  title="Edit status"
                  :aria-label="`Edit status for entity ${row.item.entity_id}`"
                  @click="infoStatus(row.item, row.index, $event.target)"
                >
                  <i class="bi bi-stoplights" />
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
                  <i class="bi bi-check2-circle" />
                </BButton>
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
        size="sm"
        centered
        ok-title="Approve"
        no-close-on-esc
        no-close-on-backdrop
        header-bg-variant="dark"
        header-text-variant="light"
        @ok="handleStatusOk"
      >
        <template #modal-title>
          <h4>
            Entity:
            <BBadge variant="primary">
              {{ approveModal.title }}
            </BBadge>
          </h4>
        </template>

        You have finished checking this status and
        <span class="font-weight-bold">want to submit it</span>?
      </BModal>
      <!-- Approve modal -->

      <!-- Modify status modal -->
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
            <!-- TODO: Restore treeselect when vue3-treeselect compatibility is fixed -->
            <!-- <treeselect
              id="status-select"
              v-model="status_info.category_id"
              :multiple="false"
              :options="status_options"
              :normalizer="normalizeStatus"
            /> -->
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
      <!-- Modify status modal -->

      <!-- Check approve all modal -->
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
        title="Approve all status"
        @ok="handleAllStatusOk"
      >
        <p class="my-4">
          Are you sure you want to
          <span class="font-weight-bold">approve ALL</span> status below?
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
import useModalControls from '@/composables/useModalControls';

// Import the utilities file
import Utils from '@/assets/js/utils';

import Status from '@/assets/js/classes/submission/submissionStatus';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ApproveStatus',
  // TODO: Treeselect disabled pending Bootstrap-Vue-Next migration
  components: {},
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
      const { showModal } = useModalControls();
      showModal(this.approveModal.id);
    },
    infoStatus(item, index, button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadStatusInfo(item.status_id);
      const { showModal } = useModalControls();
      showModal(this.statusModal.id);
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

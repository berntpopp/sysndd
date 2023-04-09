<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <!-- User Interface controls -->
          <b-card
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Approve new status
              </h6>
            </template>
            <!-- User Interface controls -->

            <!-- button for approve all -->
            <b-form
              ref="form"
              @submit.stop.prevent="checkAllApprove"
            >
              <b-input-group-append class="p-1">
                <b-button
                  size="sm"
                  type="submit"
                  variant="dark"
                >
                  <b-icon
                    icon="check2-circle"
                    class="mx-1"
                  />
                  Approve all status
                </b-button>
              </b-input-group-append>
            </b-form>
            <!-- button for approve all -->

            <!-- Table Interface controls -->
            <b-row>
              <b-col class="my-1">
                <b-form-group class="mb-1">
                  <b-input-group
                    prepend="Search"
                    size="sm"
                  >
                    <b-form-input
                      id="filter-input"
                      v-model="filter"
                      type="search"
                      placeholder="any field by typing here"
                      debounce="500"
                    />
                  </b-input-group>
                </b-form-group>
              </b-col>

              <b-col class="my-1" />

              <b-col class="my-1" />

              <b-col class="my-1">
                <b-input-group
                  prepend="Per page"
                  class="mb-1"
                  size="sm"
                >
                  <b-form-select
                    id="per-page-select"
                    v-model="perPage"
                    :options="pageOptions"
                    size="sm"
                  />
                </b-input-group>

                <b-pagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  align="fill"
                  size="sm"
                  class="my-0"
                  last-number
                />
              </b-col>
            </b-row>
            <!-- Table Interface controls -->

            <!-- Main table -->
            <b-spinner
              v-if="loading_status_approve"
              label="Loading..."
              class="float-center m-5"
            />
            <b-table
              v-else
              :items="items_StatusTable"
              :fields="fields_StatusTable"
              :busy="isBusy"
              :current-page="currentPage"
              :per-page="perPage"
              :filter="filter"
              :filter-included-fields="filterOn"
              :sort-by.sync="sortBy"
              :sort-desc.sync="sortDesc"
              :sort-direction="sortDirection"
              stacked="md"
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
              sort-icon-left
              @filtered="onFiltered"
            >
              <template #cell(entity_id)="data">
                <div>
                  <b-link :href="'/Entities/' + data.item.entity_id">
                    <b-badge
                      variant="primary"
                      style="cursor: pointer"
                    >
                      sysndd:{{ data.item.entity_id }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(symbol)="data">
                <div class="font-italic">
                  <b-link :href="'/Genes/' + data.item.hgnc_id">
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="success"
                      :title="data.item.hgnc_id"
                    >
                      {{ data.item.symbol }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-link
                    :href="
                      '/Ontology/' +
                        data.item.disease_ontology_id_version.replace(/_.+/g, '')
                    "
                    target="_blank"
                  >
                    <b-badge
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
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-badge
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
                  </b-badge>
                </div>
              </template>

              <template #cell(category)="data">
                <div>
                  <b-avatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    icon="stoplights"
                    :variant="stoplights_style[data.item.category]"
                    :title="data.item.category"
                  />
                </div>
              </template>

              <template #cell(problematic)="data">
                <div>
                  <b-avatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    :icon="problematic_symbol[data.item.problematic]"
                    :variant="problematic_style[data.item.problematic]"
                    :title="problematic_text[data.item.problematic]"
                  />
                </div>
              </template>

              <template #cell(comment)="data">
                <div>
                  <b-form-textarea
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
                  <b-icon
                    icon="stoplights"
                    font-scale="0.7"
                  />
                  <b-badge
                    v-b-tooltip.hover.right
                    variant="light"
                    :title="data.item.status_date"
                    class="ml-1"
                  >
                    {{ data.item.status_date.substring(0,10) }}
                  </b-badge>
                </div>
              </template>

              <template #cell(status_user_name)="data">
                <div>
                  <b-icon
                    :icon="user_icon[data.item.status_user_role]"
                    :variant="user_stlye[data.item.status_user_role]"
                    font-scale="1.0"
                  />
                  <b-badge
                    v-b-tooltip.hover.right
                    :variant="user_stlye[data.item.status_user_role]"
                    :title="data.item.status_user_role"
                    class="ml-1"
                  >
                    {{ data.item.status_user_name }}
                  </b-badge>
                </div>
              </template>

              <template #cell(actions)="row">
                <b-button
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="outline-primary"
                  @click="row.toggleDetails"
                >
                  <b-icon
                    :icon="row.detailsShowing ? 'eye-slash' : 'eye'"
                    font-scale="0.9"
                  />
                </b-button>

                <b-button
                  v-b-tooltip.hover.left
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="secondary"
                  title="Edit status"
                  @click="infoStatus(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="stoplights"
                    font-scale="0.9"
                  />
                </b-button>

                <b-button
                  v-b-tooltip.hover.right
                  size="sm"
                  class="mr-1 btn-xs"
                  variant="danger"
                  title="Approve status"
                  @click="infoApproveStatus(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="check2-circle"
                    font-scale="0.9"
                  />
                </b-button>
              </template>

              <template #row-details="row">
                <b-card>
                  <b-table
                    :items="[row.item]"
                    :fields="fields_details_StatusTable"
                    stacked
                    small
                  />
                </b-card>
              </template>
            </b-table>
            <!-- Main table -->
          </b-card>
        </b-col>
      </b-row>

      <!-- Approve modal -->
      <b-modal
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
            <b-badge variant="primary">
              {{ approveModal.title }}
            </b-badge>
          </h4>
        </template>

        You have finished checking this status and
        <span class="font-weight-bold">want to submit it</span>?
      </b-modal>
      <!-- Approve modal -->

      <!-- Modify status modal -->
      <b-modal
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
            <b-link
              :href="'/Entities/' + status_info.entity_id"
              target="_blank"
            >
              <b-badge variant="primary">
                sysndd:{{ status_info.entity_id }}
              </b-badge>
            </b-link>
            <b-link
              :href="'/Genes/' + entity_info.symbol"
              target="_blank"
            >
              <b-badge
                v-b-tooltip.hover.leftbottom
                pill
                variant="success"
                :title="entity_info.hgnc_id"
              >
                {{ entity_info.symbol }}
              </b-badge>
            </b-link>
            <b-link
              :href="
                '/Ontology/' +
                  entity_info.disease_ontology_id_version.replace(/_.+/g, '')
              "
              target="_blank"
            >
              <b-badge
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
              </b-badge>
            </b-link>
            <b-badge
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
            </b-badge>
          </h4>
        </template>

        <template #modal-footer="{ ok, cancel }">
          <div class="w-100">
            <p class="float-left">
              Status by:
              <b-icon
                :icon="user_icon[status_info.status_user_role]"
                :variant="user_stlye[status_info.status_user_role]"
                font-scale="1.0"
              />
              <b-badge
                :variant="user_stlye[status_info.status_user_role]"
                class="ml-1"
              >
                {{ status_info.status_user_name }}
              </b-badge>
              <b-badge
                :variant="user_stlye[status_info.status_user_role]"
                class="ml-1"
              >
                {{ status_info.status_user_role }}
              </b-badge>
            </p>

            <!-- Emulate built in modal footer ok and cancel button actions -->
            <b-button
              variant="primary"
              class="float-right mr-2"
              @click="ok()"
            >
              Save status
            </b-button>
            <b-button
              variant="secondary"
              class="float-right mr-2"
              @click="cancel()"
            >
              Cancel
            </b-button>
          </div>
        </template>

        <b-overlay
          :show="loading_status_modal"
          rounded="sm"
        >
          <b-form
            ref="form"
            @submit.stop.prevent="submitStatusChange"
          >
            <treeselect
              id="status-select"
              v-model="status_info.category_id"
              :multiple="false"
              :options="status_options"
              :normalizer="normalizeStatus"
            />

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
            <b-form-textarea
              id="status-textarea-comment"
              v-model="status_info.comment"
              rows="2"
              size="sm"
              placeholder="Why should this entities status be changed."
            />
          </b-form>
        </b-overlay>
      </b-modal>
      <!-- Modify status modal -->

      <!-- Check approve all modal -->
      <b-modal
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
      </b-modal>
      <!-- Check approve all modal -->
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

// import the Treeselect component
import Treeselect from '@riophae/vue-treeselect';
// import the Treeselect styles
import '@riophae/vue-treeselect/dist/vue-treeselect.css';

import Status from '@/assets/js/classes/submission/submissionStatus';

export default {
  name: 'ApproveStatus',
  // register the Treeselect component
  components: { Treeselect },
  mixins: [toastMixin, colorAndSymbolsMixin, textMixin],
  data() {
    return {
      problematic_text: {
        0: 'No problems',
        1: 'Entitiy status marked problematic',
      },
      items_StatusTable: [],
      fields_StatusTable: [
        {
          key: 'entity_id',
          label: 'Entity',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'symbol',
          label: 'Gene',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'category',
          label: 'Category',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'comment',
          label: 'Comment',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'problematic',
          label: 'Problematic',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'status_date',
          label: 'Status date',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'status_user_name',
          label: 'User',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-left',
        },
      ],
      fields_details_StatusTable: [
        {
          key: 'status_id',
          label: 'Status ID',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-left',
        },
        {
          key: 'status_date',
          label: 'Status date',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'status_user_name',
          label: 'Status user',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'is_active',
          label: 'Active',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'comment',
          label: 'Comment',
          sortable: true,
          filterable: true,
          class: 'text-left',
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
      perPage: '200',
      pageOptions: ['10', '25', '50', '200'],
      sortBy: 'status_user_name',
      sortDesc: false,
      sortDirection: 'asc',
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
  mounted() {
    this.loadStatusList();
  },
  methods: {
    async loadStatusList() {
      this.loading_status_approve = true;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/list/status?tree=true`;
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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/status`;
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
      this.isBusy = false;
      this.loading_status_approve = false;
    },
    async loadStatusInfo(status_id) {
      this.loading_status_modal = true;

      const apiGetURL = `${process.env.VUE_APP_API_URL}/api/status/${status_id}`;

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
      const apiGetURL = `${process.env.VUE_APP_API_URL
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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/status/update`;

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
      this.$root.$emit('bv::show::modal', this.approveModal.id, button);
    },
    infoStatus(item, index, button) {
      this.statusModal.title = `sysndd:${item.entity_id}`;
      this.getEntity(item.entity_id);
      this.loadStatusInfo(item.status_id);
      this.$root.$emit('bv::show::modal', this.statusModal.id, button);
    },
    async handleStatusOk(bvModalEvt) {
      const apiUrl = `${process.env.VUE_APP_API_URL
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
        const apiUrl = `${process.env.VUE_APP_API_URL
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
    checkAllApprove() {
      this.$refs.approveAllModal.show();
    },
    onFiltered(filteredItems) {
      // Trigger pagination to update the number of buttons/pages due to filtering
      this.totalRows = filteredItems.length;
      this.currentPage = 1;
    },
    truncate(str, n) {
      return str.length > n ? `${str.substr(0, n - 1)}...` : str;
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

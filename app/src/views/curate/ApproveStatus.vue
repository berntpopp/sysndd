<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">


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
          <b-form ref="form" @submit.stop.prevent="checkAllApprove">
            <b-input-group-append
                class="p-1">
              <b-button 
                size="sm"
                type="submit" 
                variant="dark"
              >
                <b-icon icon="check2-circle" class="mx-1"></b-icon>
                Approve all status
              </b-button>
            </b-input-group-append>
          </b-form>
          <!-- button for approve all -->

          <!-- Main table -->
          <b-spinner label="Loading..." v-if="loading_status_approve" class="float-center m-5"></b-spinner>
          <b-table
            :items="items_StatusTable"
            :fields="fields_StatusTable"
            :busy="isBusy"
            stacked="md"
            head-variant="light"
            show-empty
            small
            fixed
            striped
            hover
            sort-icon-left
            v-else
          >

            <template #cell(entity_id)="data">
              <div>
                <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                  <b-badge 
                  variant="primary"
                  style="cursor:pointer"
                  >
                  sysndd:{{ data.item.entity_id }}
                  </b-badge>
                </b-link>
              </div>
            </template>

            <template #cell(category)="data">
              <div>
                <b-avatar
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[data.item.category]"
                v-b-tooltip.hover.left 
                v-bind:title="data.item.category"
                >
                </b-avatar>
              </div> 
            </template>

            <template #cell(problematic)="data">
              <div>
                <b-avatar
                size="1.4em"
                :icon="problematic_symbol[data.item.problematic]"
                :variant="problematic_style[data.item.problematic]"
                v-b-tooltip.hover.left 
                v-bind:title="problematic_text[data.item.problematic]"
                >
                </b-avatar>
              </div> 
            </template>

            <template #cell(comment)="data">
              <div>
                <b-form-textarea
                  plaintext 
                  size="sm"
                  rows="1"
                  :value="data.item.comment"
                >
                </b-form-textarea>
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
                >
                </b-icon>
              </b-button>

              <b-button 
                size="sm" 
                class="mr-1 btn-xs"
                variant="secondary"
                v-b-tooltip.hover.left 
                title="Edit status"
                @click="infoStatus(row.item, row.index, $event.target)" 
                >
                  <b-icon 
                  icon="pen"
                  font-scale="0.9"
                  >
                  </b-icon>
              </b-button>

              <b-button 
                @click="infoApproveStatus(row.item, row.index, $event.target)" 
                size="sm" 
                class="mr-1 btn-xs" 
                variant="danger"
                v-b-tooltip.hover.right 
                title="Approve status"
              >
                <b-icon 
                icon="check2-circle"
                font-scale="0.9"
                >
                </b-icon>
              </b-button>

            </template>

            <template #row-details="row">
              <b-card>
                <b-table
                  :items="[row.item]"
                  :fields="fields_details_StatusTable"
                  stacked 
                  small
                >
                </b-table>
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
          <h4>Entity: 
            <b-badge variant="primary">
              {{ approveModal.title }}
            </b-badge>
          </h4>
        </template>

        You have finished checking this status and <span class="font-weight-bold">want to submit it</span>?

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
        <h4>Modify status for entity: 
          <b-badge variant="primary">
            sysndd:{{ status_info.entity_id }}
          </b-badge>
        </h4>
      </template>

      <template #modal-footer="{ ok, cancel }">
        <div class="w-100">
          <p class="float-left">
            Status by: 
            <b-icon icon="person-circle" font-scale="1.0"></b-icon> <b-badge variant="dark">  {{ status_info.status_user_name }} </b-badge> <b-badge variant="dark"> {{ status_info.status_user_role }} </b-badge>
          </p>

          <!-- Emulate built in modal footer ok and cancel button actions -->
          <b-button variant="primary" class="float-right mr-2" @click="ok()">
            Save status
          </b-button>
          <b-button variant="secondary" class="float-right mr-2" @click="cancel()">
            Cancel
          </b-button>
        </div>
      </template>

      <b-overlay :show="loading_status_modal" rounded="sm">

        <b-form ref="form" @submit.stop.prevent="submitStatusChange">

          <treeselect
            id="status-select" 
            :multiple="false"
            :options="status_options"
            v-model="status_info.category_id"
            :normalizer="normalizeStatus"
          />

          <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="removeSwitch"
            v-model="status_info.problematic"
          >
          <label class="custom-control-label" for="removeSwitch">Suggest removal</label>
          </div>

          <label class="mr-sm-2 font-weight-bold" for="status-textarea-comment">Comment</label>
          <b-form-textarea
            id="status-textarea-comment"
            rows="2"
            size="sm" 
            v-model="status_info.comment"
            placeholder="Why should this entities status be changed."
          >
          </b-form-textarea>

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
        <p class="my-4">Are you sure you want to <span class="font-weight-bold">approve ALL</span> status below?</p>
        <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="removeSwitch"
            v-model="approve_all_selected"
          >
          <label class="custom-control-label" for="removeSwitch"><b>{{ switch_approve_text[approve_all_selected] }}</b></label>
        </div>
      </b-modal>
      <!-- Check approve all modal -->

    </b-container>
  </div>
</template>


<script>
import toastMixin from '@/assets/js/mixins/toastMixin.js'
import submissionObjectsMixin from '@/assets/js/mixins/submissionObjectsMixin.js'

// import the Treeselect component
import Treeselect from '@riophae/vue-treeselect'
// import the Treeselect styles
import '@riophae/vue-treeselect/dist/vue-treeselect.css'


export default {
  // register the Treeselect component
  components: { Treeselect },
  name: 'ApproveStatus',
  mixins: [toastMixin, submissionObjectsMixin],
    data() {
      return {
        stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
        problematic_style: {"0": "success", "1": "danger"},
        problematic_symbol: {"0": "check-square", "1": "question-square"},
        problematic_text: {"0": "No problems", "1": "Entitiy status marked problematic"},
        items_StatusTable: [],
        fields_StatusTable: [
            { key: 'entity_id', label: 'Entity', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'category', label: 'Category', sortable: true, filterable: true, class: 'text-left' },
            { key: 'comment', label: 'Comment', sortable: true, filterable: true, class: 'text-left' },
            { key: 'problematic', label: 'Problematic', sortable: true, filterable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
        ],
        fields_details_StatusTable: [
            { key: 'status_id', label: 'Status ID', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'status_date', label: 'Status date', sortable: true, filterable: true, class: 'text-left' },
            { key: 'status_user_name', label: 'Status user', sortable: true, filterable: true, class: 'text-left' },
            { key: 'is_active', label: 'Active', sortable: true, filterable: true, class: 'text-left' },
            { key: 'comment', label: 'Comment', sortable: true, filterable: true, class: 'text-left' }
        ],
        statusModal: {
          id: 'status-modal',
          title: '',
          content: []
        },
        status_info: new this.Status(),
        status_options: [],
        totalRows_StatusTable: 0,
        approveModal: {
          id: 'approve-modal',
          title: '',
          content: []
        },
        approve_all_selected: false,
        switch_approve_text: {true: "Yes", false: "No"},
        loading_status_approve: true,
        loading_status_modal: true,
        isBusy: true
      };
    },
    mounted() {
      this.loadStatusList();
    },
    methods: {
        async loadStatusList() {
          this.loading_status_approve = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/list/status?tree=true';
          try {
            let response = await this.axios.get(apiUrl);
            this.status_options = response.data;

            this.loadStatusTableData();
          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }
        },
        async loadStatusTableData() {
          this.isBusy = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/status';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.items_StatusTable = response.data;
            this.totalRows_StatusTable = response.data.length;
          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }
          this.isBusy = false;
          this.loading_status_approve = false;
        },
        async loadStatusInfo(status_id) {
          this.loading_status_modal = true;

          let apiGetURL = process.env.VUE_APP_API_URL + '/api/status/' + status_id;

          try {
            let response = await this.axios.get(apiGetURL);

            // compose entity
            this.status_info = new this.Status(response.data[0].category_id, response.data[0].comment, response.data[0].problematic);

            this.status_info.status_id = response.data[0].status_id;
            this.status_info.status_user_name = response.data[0].status_user_name;
            this.status_info.status_user_role = response.data[0].status_user_role;

          this.loading_status_modal = false;

            } catch (e) {
              this.makeToast(e, 'Error', 'danger');
            }
        },
        async submitStatusChange() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/status/update';

          // perform update PUT request
          try {
            let response = await this.axios.put(apiUrl, {status_json: this.status_info}, {
               headers: {
                 'Authorization': 'Bearer ' + localStorage.getItem('token')
               }
             });

            this.makeToast('The new status for this entity has been submitted ' + '(status ' + response.status + ' (' + response.statusText + ').', 'Success', 'success');
            this.resetForm();
            this.loadStatusTableData();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }

        },
        resetForm() {
          this.status_info = new this.Status();
        },
        infoApproveStatus(item, index, button) {
          this.approveModal.title = `sysndd:${item.entity_id}`;
          this.loadStatusInfo(item.status_id);
          this.$root.$emit('bv::show::modal', this.approveModal.id, button);
        },
        infoStatus(item, index, button) {
          this.statusModal.title = `sysndd:${item.entity_id}`;
          this.loadStatusInfo(item.status_id);
          this.$root.$emit('bv::show::modal', this.statusModal.id, button);
        },
        async handleStatusOk(bvModalEvt) {

          let apiUrl = process.env.VUE_APP_API_URL + '/api/status/approve/' + this.status_info.status_id + '?status_ok=true';

          try {
            let response = await this.axios.put(apiUrl, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });

          this.loadStatusTableData();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }
        },
        async handleAllStatusOk() {
          if(this.approve_all_selected) {
              let apiUrl = process.env.VUE_APP_API_URL + '/api/status/approve/all?status_ok=true';
              try {
                let response = this.axios.put(apiUrl, {}, {
                  headers: {
                    'Authorization': 'Bearer ' + localStorage.getItem('token')
                  }
                });

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
          }
        },
        checkAllApprove() {
          this.$refs['approveAllModal'].show();
        },
    }
    };
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }

  ::v-deep .vue-treeselect__menu{
    outline:1px solid red;
    color: blue;
  }
</style>
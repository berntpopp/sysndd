<template>
  <div class="container-fluid" style="min-height:90vh">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <div>
          <b-tabs content-class="mt-3" v-model="tabIndex">

            <b-tab title="New entity" active>
              <b-spinner label="Loading..." v-if="loadingEntityNew" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
              </b-container>
            </b-tab>

            <b-tab title="Modify entity" lazy>
              <b-spinner label="Loading..." v-if="loadingEntityModify" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
              </b-container>
            </b-tab>

            <b-tab title="Review approve" lazy>
              <b-spinner label="Loading..." v-if="loadingReviewApprove" class="float-center m-5"></b-spinner>
              <b-table
                :items="items_ReviewTable"
                :fields="fields_ReviewTable"
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

              <template #cell(synopsis)="data">
                <div>
                  <b-form-textarea
                    plaintext 
                    size="sm"
                    rows="1"
                    :value="data.item.synopsis"
                  >
                  </b-form-textarea>
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
                  title="Edit review"
                  >
                    <b-icon 
                    icon="pen"
                    font-scale="0.9"
                    >
                    </b-icon>
                </b-button>

                <b-button 
                  size="sm" 
                  class="mr-1 btn-xs" 
                  variant="danger"
                  v-b-tooltip.hover.right 
                  title="Approve review"
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
                    :fields="fields_details_ReviewTable"
                    stacked 
                    small
                  >
                  </b-table>
                </b-card>
              </template>

              </b-table>
            </b-tab>

            <b-tab title="Status approve" lazy>
              <b-spinner label="Loading..." v-if="loadingStatusApprove" class="float-center m-5"></b-spinner>
              <b-table
                :items="items_StatusTable"
                :fields="fields_StatusTable"
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
                  >
                    <b-icon 
                    icon="pen"
                    font-scale="0.9"
                    >
                    </b-icon>
                </b-button>

                <b-button 
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
            </b-tab>

            <b-tab title="Users approve" lazy>
              <b-spinner label="Loading..." v-if="loadingUsersApprove" class="float-center m-5"></b-spinner>
                <b-table
                :items="items_UsersTable"
                stacked="md"
                head-variant="light"
                show-empty
                small
                fixed
                striped
                hover
                sort-icon-left
                empty-text="Currently no open user applications."
                v-else
              >

                <template #cell(user_role)="row">

                  <b-form-select 
                    class="form-control"
                    size="sm"
                    :options="role_options"
                    v-model="row.item.user_role"
                    @input="handleUserChangeRole(row.item.user_id, row.item.user_role)"
                  >
                  </b-form-select>

                </template>

                <template #cell(approved)="row">
                  <b-button 
                    size="sm" 
                    @click="infoApproveUser(row.item, row.index, $event.target)" 
                    class="mr-1 btn-xs" 
                    v-b-tooltip.hover.top 
                    title="Manage user approval"
                    :variant="user_approval_style[row.item.approved]"
                  >
                    <b-icon 
                    icon="hand-thumbs-up"
                    font-scale="0.9"
                    >
                    </b-icon>
                    <b-icon 
                    icon="hand-thumbs-down"
                    font-scale="0.9"
                    >
                    </b-icon>
                  </b-button>
                </template>

              </b-table>
            </b-tab>

            <b-tab title="Re-review managment" lazy>
              <b-spinner label="Loading..." v-if="loadingReReviewManagment" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
                
              <!-- User Interface controls -->
              <b-card 
              header-tag="header"
              bg-variant="light"
              >
                <b-col>
                  <b-row>
                    <b-col class="my-1">

                      <!-- button and select for new batch assignment -->
                      <b-input-group
                      prepend="Username"
                      size="sm"
                      >
                        <b-form-select
                        :options="user_options"
                        v-model="user_id_assignment"
                        >
                        </b-form-select>
                        <b-input-group-append>
                          <b-button 
                          block size="sm"
                          @click="handleNewBatchAssignment"
                          >
                            <b-icon icon="plus-square" class="mx-1"></b-icon>
                            Assign new batch
                          </b-button>
                        </b-input-group-append>
                      </b-input-group>

                    </b-col>

                    <b-col class="my-1">
                    </b-col>
                  </b-row>
                </b-col>
              </b-card>
              <!-- User Interface controls -->

                <b-table
                :items="items_ReReviewTable"
                stacked="md"
                head-variant="light"
                show-empty
                small
                fixed
                striped
                hover
                sort-icon-left
              >

                <template #cell(re_review_batch)="data">
                  <b-button 
                    size="sm" 
                    class="mr-1 btn-xs" 
                    v-b-tooltip.hover.top 
                    title="unassign this batch"
                    variant="danger"
                    @click="handleBatchUnAssignment(data.item.re_review_batch)"
                  >
                    <b-icon 
                    icon="file-earmark-minus"
                    font-scale="0.9"
                    >
                    </b-icon>
                    {{ data.item.re_review_batch }}
                  </b-button>
                </template>

              </b-table>
              </b-container>
            </b-tab>

          </b-tabs>
          </div>
          
        </b-col>
      </b-row>


      <!-- Manage user approval modal -->
      <b-modal 
      :id="approveUserModal.id" 
      size="lg" 
      centered 
      ok-title="Submit" 
      no-close-on-esc 
      no-close-on-backdrop 
      header-bg-variant="dark" 
      header-text-variant="light" 
      @hide="resetUserApproveModal" 
      @ok="handleUserApproveOk"
      >
        <template #modal-title>
          <h4>Manage application from: 
            <b-badge variant="primary">
              {{ approveUserModal.title }}
            </b-badge>
          </h4>
        </template>
        What should happen to this user ?

          <div class="custom-control custom-switch">
          <input 
            type="checkbox" 
            button-variant="info"
            class="custom-control-input" 
            id="approveUserSwitch"
            v-model="user_approved"
          >
          <label class="custom-control-label" for="approveUserSwitch"><b>{{ switch_user_approval_text[user_approved] }}</b></label>
          </div>

      </b-modal>
      <!-- Manage user approval modal -->

    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Curate',
    data() {
      return {
        stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
        problematic_style: {"0": "success", "1": "danger"},
        problematic_symbol: {"0": "check-square", "1": "question-square"},
        problematic_text: {"0": "No problems", "1": "Entitiy status marked problematic"},
        role_options: [],
        user_options: [],
        user_id_assignment: 0,
        switch_user_approval_text: {true: "Approve user", false: "Delete application"},
        user_approval_style: {0: "danger", 1: "primary"},
        loadingEntityNew: true,
        loadingEntityModify: true,
        loadingReviewApprove: true,
        loadingStatusApprove: true,
        loadingUsersApprove: true,
        items_UsersTable: [],
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
            { key: 'status_user_id', label: 'Status user ID', sortable: true, filterable: true, class: 'text-left' },
            { key: 'is_active', label: 'Active', sortable: true, filterable: true, class: 'text-left' },
            { key: 'comment', label: 'Comment', sortable: true, filterable: true, class: 'text-left' }
        ],
        items_ReviewTable: [],
        fields_ReviewTable: [
            { key: 'entity_id', label: 'Entity', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'synopsis', label: 'Clinical synopsis', sortable: true, filterable: true, class: 'text-left' },
            { key: 'comment', label: 'Comment', sortable: true, filterable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
        ],
        fields_details_ReviewTable: [
            { key: 'review_id', label: 'Review ID', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 'review_date', label: 'Review date', sortable: true, filterable: true, class: 'text-left' },
            { key: 'review_user_id', label: 'Review user ID', sortable: true, filterable: true, class: 'text-left' },
            { key: 'is_primary', label: 'Primary', sortable: true, filterable: true, class: 'text-left' },
            { key: 'synopsis', label: 'Clinical synopsis', sortable: true, filterable: true, class: 'text-left' }
        ],
        totalRows_UsersTable: 0,
        totalRows_StatusTable: 0,
        totalRows_ReviewTable: 0,
        approveUserModal: {
          id: 'approve-usermodal',
          title: '',
          content: []
        },
        approve_user: [],
        user_approved: false, 
        loadingReReviewManagment: true,
        items_ReReviewTable: [],
        totalRows_ReReviewTable: 0,
        tabIndex: 0
      };
    },
    mounted() {
      this.loadRoleList();
      this.loadUserList();
    },
    watch: {
      tabIndex(value) {
        if (value === 5 & this.loadingReReviewManagment) {
          this.loadReReviewTableData();
        } else if (value === 4 & this.loadingUsersApprove) {
          this.loadUserTableData();
        } else if (value === 3 & this.loadingUsersApprove) {
          this.loadStatusTableData();
        } else if (value === 2 & this.loadingUsersApprove) {
          this.loadReviewTableData();
        }
      }
    },
    methods: {
        async loadRoleList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/user/role_list';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.role_options = response.data.map(item => {
              return { value: item.role, text: item.role };
            });
          } catch (e) {
            console.error(e);
          }
        },
        async loadUserList() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/user/list?roles=Curator,Reviewer';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.user_options = response.data.map(item => {
              return { value: item.user_id, text: item.user_name, role: item.user_role};
            });
          } catch (e) {
            console.error(e);
          }
        },
        infoApproveUser(item, index, button) {
          this.approveUserModal.title = `${item.user_name}`;
          this.approve_user = [];
          this.approve_user.push(item);
          this.$root.$emit('bv::show::modal', this.approveUserModal.id, button);
        },
        resetUserApproveModal() {
          this.approveUserModal = {id: 'approve-usermodal', title: '',content: []};
          this.approve_user = [];
          this.user_approved = false;
        },
        async loadReReviewTableData() {
          this.loadingReReviewManagment = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/re_review/assignment_table';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.items_ReReviewTable = response.data;
            this.totalRows_ReReviewTable = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loadingReReviewManagment = false;
        },
        async loadUserTableData() {
          this.loadingUsersApprove = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/user/table';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.items_UsersTable = response.data;
            this.totalRows_UsersTable = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loadingUsersApprove = false;
        },
        async loadStatusTableData() {
          this.loadingStatusApprove = true;
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
            console.error(e);
          }
          this.loadingStatusApprove = false;
        },
        async loadReviewTableData() {
          this.loadingReviewApprove = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/review';
          try {
            let response = await this.axios.get(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
            this.items_ReviewTable = response.data;
            this.totalRows_ReviewTable = response.data.length;
          } catch (e) {
            console.error(e);
          }
          this.loadingReviewApprove = false;
        },
        async handleUserApproveOk(bvModalEvt) {

          let apiUrl = process.env.VUE_APP_API_URL + '/api/user/approval?user_id=' + this.approve_user[0].user_id + '&status_approval=' + this.user_approved;

          try {
            let response = await this.axios.put(apiUrl, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
          } catch (e) {
            console.error(e);
          }
        this.resetUserApproveModal();
        this.loadUserTableData();
        },
        async handleUserChangeRole(user_id, user_role) {

          let apiUrl = process.env.VUE_APP_API_URL + '/api/user/change_role?user_id=' + user_id + '&role_assigned=' + user_role;

          try {
            let response = await this.axios.put(apiUrl, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
          } catch (e) {
            console.error(e);
          }
        },
        async handleNewBatchAssignment() {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/re_review/batch/assign?user_id=' + this.user_id_assignment;

          try {
            let response = await this.axios.put(apiUrl, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
          } catch (e) {
            console.error(e);
          }
        this.loadReReviewTableData();
        },
        async handleBatchUnAssignment(batch_id) {
          let apiUrl = process.env.VUE_APP_API_URL + '/api/re_review/batch/unassign?re_review_batch=' + batch_id;

          try {
            let response = await this.axios.delete(apiUrl, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });
          } catch (e) {
            console.error(e);
          }
        this.loadReReviewTableData();
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
</style>
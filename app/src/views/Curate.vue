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

            <b-tab title="Modify entity">
              <b-spinner label="Loading..." v-if="loadingEntityModify" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
              </b-container>
            </b-tab>

            <b-tab title="Review approve">
              <b-spinner label="Loading..." v-if="loadingReviewApprove" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
              </b-container>
            </b-tab>

            <b-tab title="Status approve">
              <b-spinner label="Loading..." v-if="loadingStatusApprove" class="float-center m-5"></b-spinner>
              <b-container fluid v-else>
              </b-container>
            </b-tab>

            <b-tab title="Users approve">
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

            <b-tab title="Re-review managment">
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
        totalRows_UsersTable: 0,
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
console.log(this.user_id_assignment);
          let apiUrl = process.env.VUE_APP_API_URL + '/api/re_review/new_batch/assign?user_id=' + this.user_id_assignment;

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
<!-- views/curate/ApproveUser.vue -->
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
                Approve new user applications
              </h6>
            </template>
            <!-- User Interface controls -->

            <!-- Main table -->
            <b-spinner
              v-if="loadingUsersApprove"
              label="Loading..."
              class="float-center m-5"
            />
            <b-table
              v-else
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
            >
              <template #cell(user_role)="row">
                <b-form-select
                  v-model="row.item.user_role"
                  class="form-control"
                  size="sm"
                  :options="role_options"
                  @input="
                    handleUserChangeRole(row.item.user_id, row.item.user_role)
                  "
                />
              </template>

              <template #cell(approved)="row">
                <b-button
                  v-b-tooltip.hover.top
                  size="sm"
                  class="mr-1 btn-xs"
                  title="Manage user approval"
                  :variant="user_approval_style[row.item.approved]"
                  @click="infoApproveUser(row.item, row.index, $event.target)"
                >
                  <b-icon
                    icon="hand-thumbs-up"
                    font-scale="0.9"
                  />
                  <b-icon
                    icon="hand-thumbs-down"
                    font-scale="0.9"
                  />
                </b-button>
              </template>
            </b-table>
            <!-- Main table -->
          </b-card>
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
          <h4>
            Manage application from:
            <b-badge variant="primary">
              {{ approveUserModal.title }}
            </b-badge>
          </h4>
        </template>
        What should happen to this user ?

        <div class="custom-control custom-switch">
          <input
            id="approveUserSwitch"
            v-model="user_approved"
            type="checkbox"
            button-variant="info"
            class="custom-control-input"
          >
          <label
            class="custom-control-label"
            for="approveUserSwitch"
          ><b>{{ switch_user_approval_text[user_approved] }}</b></label>
        </div>
      </b-modal>
      <!-- Manage user approval modal -->
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';

export default {
  name: 'ApproveStatus',
  mixins: [toastMixin, colorAndSymbolsMixin],
  data() {
    return {
      role_options: [],
      user_options: [],
      switch_user_approval_text: {
        true: 'Approve user',
        false: 'Delete application',
      },
      items_UsersTable: [],
      totalRows_UsersTable: 0,
      loadingUsersApprove: true,
      approveUserModal: {
        id: 'approve-usermodal',
        title: '',
        content: [],
      },
      user_approved: false,
    };
  },
  mounted() {
    this.loadRoleList();
    this.loadUserList();
    this.loadUserTableData();
  },
  methods: {
    async loadUserTableData() {
      this.loadingUsersApprove = true;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/user/table`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.items_UsersTable = response.data;
        this.totalRows_UsersTable = response.data.length;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.loadingUsersApprove = false;
    },
    async loadRoleList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/user/role_list`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.role_options = response.data.map((item) => ({ value: item.role, text: item.role }));
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadUserList() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/user/list?roles=Curator,Reviewer`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.user_options = response.data.map((item) => ({
          value: item.user_id,
          text: item.user_name,
          role: item.user_role,
        }));
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    infoApproveUser(item, index, button) {
      this.approveUserModal.title = `${item.user_name}`;
      this.approve_user = [];
      this.approve_user.push(item);
      this.$root.$emit('bv::show::modal', this.approveUserModal.id, button);
    },
    resetUserApproveModal() {
      this.approveUserModal = {
        id: 'approve-usermodal',
        title: '',
        content: [],
      };
      this.approve_user = [];
      this.user_approved = false;
    },
    async handleUserApproveOk(bvModalEvt) {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/user/approval?user_id=${
        this.approve_user[0].user_id
      }&status_approval=${
        this.user_approved}`;

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
      this.resetUserApproveModal();
      this.loadUserTableData();
    },
    async handleUserChangeRole(user_id, user_role) {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/user/change_role?user_id=${
        user_id
      }&role_assigned=${
        user_role}`;

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

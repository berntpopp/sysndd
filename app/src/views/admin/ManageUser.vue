<!-- views/admin/ManageUser.vue -->
<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <h3>Manage User Rights</h3>
          <b-card
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <b-spinner
              v-if="isLoading"
              label="Loading..."
              class="m-5"
            />
            <GenericTable
              v-else
              :items="users"
              :fields="fields"
              :sort-by.sync="sortBy"
              :sort-desc.sync="sortDesc"
            >
              <!-- Custom slot for the 'actions' column -->
              <template v-slot:cell-actions="{ row }">
                <div>
                  <b-button
                    v-b-tooltip.hover.top
                    size="sm"
                    class="mr-1 btn-xs"
                    title="Edit user"
                    @click="editUser(row, $event.target)"
                  >
                    <b-icon
                      icon="pen"
                      font-scale="0.9"
                    />
                  </b-button>
                  <b-button
                    v-b-tooltip.hover.top
                    size="sm"
                    class="mr-1 btn-xs"
                    title="Delete user"
                    @click="promptDeleteUser(row, $event.target)"
                  >
                    <b-icon
                      icon="x"
                      font-scale="0.9"
                    />
                  </b-button>
                </div>
              </template>
            </GenericTable>
          </b-card>
        </b-col>
      </b-row>

      <!-- Modal for user deletion confirmation -->
      <b-modal
        :id="deleteUserModal.id"
        title="Confirm Deletion"
        ok-title="Delete"
        ok-variant="danger"
        cancel-title="Cancel"
        cancel-variant="secondary"
        @ok="confirmDeleteUser"
      >
        Are you sure you want to delete the user <strong>{{ userToDelete.user_name }}</strong>?
      </b-modal>

      <!-- Update User Modal -->
      <b-modal
        :id="updateUserModal.id"
        title="Update User"
        ok-title="Update"
        ok-variant="primary"
        cancel-title="Cancel"
        @ok="updateUserData"
      >
        <b-form @submit.prevent="updateUserData">
          <!-- Dynamically create form inputs for each user attribute -->
          <b-form-group
            v-for="field in editableFields"
            :key="field.key"
            :label="field.label + ':'"
            :label-for="'input-' + field.key"
          >
            <b-form-input
              :id="'input-' + field.key"
              v-model="userToUpdate[field.key]"
            />
          </b-form-group>
        </b-form>
      </b-modal>
    </b-container>
  </div>
</template>

<script>
import GenericTable from '@/components/small/GenericTable.vue';
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'ManageUser',
  components: {
    GenericTable,
  },
  mixins: [toastMixin],
  data() {
    return {
      role_options: [],
      user_options: [],
      users: [],
      fields: [
        {
          key: 'user_name',
          label: 'User name',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'email',
          label: 'E-mail',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'orcid',
          label: 'ORCID',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'abbreviation',
          label: 'Abbreviation',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'first_name',
          label: 'First name',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'family_name',
          label: 'Family name',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'user_role',
          label: 'Role',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'comment',
          label: 'Comment',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'approved',
          label: 'Approved',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-center',
        },
      ],
      isLoading: false,
      sortBy: 'user_id',
      sortDesc: false,
      showDeleteModal: false,
      userToDelete: {},
      userToUpdate: {},
      deleteUserModal: {
        id: 'delete-usermodal',
        title: '',
        content: [],
      },
      updateUserModal: {
        id: 'update-usermodal',
        title: '',
        content: [],
      },
    };
  },
  computed: {
    editableFields() {
      // Filter out non-editable fields like 'actions' and 'user_id'
      return this.fields.filter(
        (field) => field.key !== 'actions' && field.key !== 'user_id',
      );
    },
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
        this.users = response.data;
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
    promptDeleteUser(item, button) {
      this.deleteUserModal.title = `${item.user_name}`;
      this.userToDelete = item;
      this.$root.$emit('bv::show::modal', this.deleteUserModal.id, button);
    },
    async confirmDeleteUser() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/user/delete`;
      try {
        const response = await this.axios.delete(apiUrl, {
          data: { user_id: this.userToDelete.user_id },
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        if (response.status === 200) {
          this.makeToast('User deleted successfully', 'Success', 'success');
          // Filter out the deleted user from the local state instead of reloading from the server
          this.users = this.users.filter((user) => user.user_id !== this.userToDelete.user_id);
        } else {
          throw new Error('Failed to delete the user.');
        }
      } catch (e) {
        this.makeToast(e.message, 'Error', 'danger');
      }
      // Hide the modal after the operation is complete
      this.$root.$emit('bv::hide::modal', this.deleteUserModal.id);
      // Clear the selected user to delete
      this.userToDelete = {};
    },
    editUser(item, button) {
      this.updateUserModal.title = `${item.user_name}`;
      this.userToUpdate = item;
      this.$root.$emit('bv::show::modal', this.updateUserModal.id, button);
    },
    async updateUserData() {
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/user/update`;
      try {
        const response = await this.axios.put(
          apiUrl,
          { user_details: this.userToUpdate },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
        if (response.status === 200) {
          this.makeToast('User updated successfully', 'Success', 'success');
          // Update the user in the local state
          const index = this.users.findIndex((u) => u.user_id === this.userToUpdate.user_id);
          if (index !== -1) {
            this.users.splice(index, 1, this.userToUpdate);
          }
        } else {
          throw new Error('Failed to update the user.');
        }
      } catch (e) {
        this.makeToast(e.message, 'Error', 'danger');
      }
      // Close the modal after the update
      this.$bvModal.hide(this.updateUserModal.id);
      // Reset the userToUpdate object
      this.userToUpdate = {};
    },
  },
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

<!-- views/admin/ManageUser.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <h3>Manage User Rights</h3>
          <BCard
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <BSpinner
              v-if="isLoading"
              label="Loading..."
              class="m-5"
            />
            <GenericTable
              v-else
              :items="users"
              :fields="fields"
              :sort-by="sortBy"
              @update:sort-by="handleSortByUpdate"
            >
              <template v-slot:cell-actions="{ row }">
                <div>
                  <BButton
                    v-b-tooltip.hover.top
                    size="sm"
                    class="me-1 btn-xs"
                    title="Edit user"
                    @click="editUser(row, $event.target)"
                  >
                    <i class="bi bi-pen" />
                  </BButton>
                  <BButton
                    v-b-tooltip.hover.top
                    size="sm"
                    class="me-1 btn-xs"
                    title="Delete user"
                    @click="promptDeleteUser(row, $event.target)"
                  >
                    <i class="bi bi-x" />
                  </BButton>
                </div>
              </template>
              <template v-slot:cell-approved="{ row }">
                <BBadge :variant="row.approved ? 'success' : 'danger'">
                  {{ row.approved ? 'Approved' : 'Unapproved' }}
                </BBadge>
              </template>
            </GenericTable>
          </BCard>
        </BCol>
      </BRow>

      <BModal
        :id="deleteUserModal.id"
        title="Confirm Deletion"
        ok-title="Delete"
        ok-variant="danger"
        cancel-title="Cancel"
        cancel-variant="secondary"
        @ok="confirmDeleteUser"
      >
        Are you sure you want to delete the user <strong>{{ userToDelete.user_name }}</strong>?
      </BModal>

      <BModal
        :id="updateUserModal.id"
        title="Update User"
        ok-title="Update"
        ok-variant="primary"
        cancel-title="Cancel"
        @ok="onUpdateSubmit"
      >
        <form @submit.prevent="onUpdateSubmit">
          <!-- User name -->
          <BFormGroup
            label="User name:"
            label-for="input-user_name"
          >
            <BFormInput
              id="input-user_name"
              v-model="userToUpdate.user_name"
              type="text"
              :state="userNameMeta.touched ? (userNameError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="userNameError">
              {{ userNameError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Email -->
          <BFormGroup
            label="E-mail:"
            label-for="input-email"
          >
            <BFormInput
              id="input-email"
              v-model="userToUpdate.email"
              type="email"
              :state="emailMeta.touched ? (emailError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="emailError">
              {{ emailError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- ORCID -->
          <BFormGroup
            label="ORCID:"
            label-for="input-orcid"
          >
            <BFormInput
              id="input-orcid"
              v-model="userToUpdate.orcid"
              type="text"
              :state="orcidMeta.touched ? (orcidError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="orcidError">
              {{ orcidError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Abbreviation -->
          <BFormGroup
            label="Abbreviation:"
            label-for="input-abbreviation"
          >
            <BFormInput
              id="input-abbreviation"
              v-model="userToUpdate.abbreviation"
              type="text"
              :state="abbreviationMeta.touched ? (abbreviationError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="abbreviationError">
              {{ abbreviationError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- First name -->
          <BFormGroup
            label="First name:"
            label-for="input-first_name"
          >
            <BFormInput
              id="input-first_name"
              v-model="userToUpdate.first_name"
              type="text"
              :state="firstNameMeta.touched ? (firstNameError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="firstNameError">
              {{ firstNameError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Family name -->
          <BFormGroup
            label="Family name:"
            label-for="input-family_name"
          >
            <BFormInput
              id="input-family_name"
              v-model="userToUpdate.family_name"
              type="text"
              :state="familyNameMeta.touched ? (familyNameError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="familyNameError">
              {{ familyNameError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Role -->
          <BFormGroup
            label="Role:"
            label-for="input-user_role"
          >
            <BFormInput
              id="input-user_role"
              v-model="userToUpdate.user_role"
              type="text"
              :state="userRoleMeta.touched ? (userRoleError ? false : true) : null"
            />
            <BFormInvalidFeedback v-if="userRoleError">
              {{ userRoleError }}
            </BFormInvalidFeedback>
          </BFormGroup>

          <!-- Comment -->
          <BFormGroup
            label="Comment:"
            label-for="input-comment"
          >
            <BFormInput
              id="input-comment"
              v-model="userToUpdate.comment"
              type="text"
            />
          </BFormGroup>

          <!-- Approved -->
          <BFormGroup
            label="Approved:"
            label-for="input-approved"
          >
            <BFormCheckbox
              id="input-approved"
              v-model="userToUpdate.approved"
            >
              User is approved
            </BFormCheckbox>
          </BFormGroup>
        </form>
      </BModal>
    </BContainer>
  </div>
</template>

<script>
import { useForm, useField, defineRule } from 'vee-validate';
import { required, min, max, email } from '@vee-validate/rules';
import GenericTable from '@/components/small/GenericTable.vue';
import useToast from '@/composables/useToast';
import useModalControls from '@/composables/useModalControls';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Define validation rules globally
defineRule('required', required);
defineRule('min', min);
defineRule('max', max);
defineRule('email', email);

export default {
  name: 'ManageUser',
  components: {
    GenericTable,
  },
  setup() {
    const { makeToast } = useToast();

    // Setup form validation with vee-validate 4
    const { handleSubmit, resetForm, setValues } = useForm();

    // Define fields with validation
    const {
      value: userName,
      errorMessage: userNameError,
      meta: userNameMeta,
    } = useField('user_name', 'required|min:2|max:50');

    const {
      value: userEmail,
      errorMessage: emailError,
      meta: emailMeta,
    } = useField('email', 'required|email');

    const {
      value: orcid,
      errorMessage: orcidError,
      meta: orcidMeta,
    } = useField('orcid', 'required');

    const {
      value: abbreviation,
      errorMessage: abbreviationError,
      meta: abbreviationMeta,
    } = useField('abbreviation', 'required');

    const {
      value: firstName,
      errorMessage: firstNameError,
      meta: firstNameMeta,
    } = useField('first_name', 'required|min:2|max:50');

    const {
      value: familyName,
      errorMessage: familyNameError,
      meta: familyNameMeta,
    } = useField('family_name', 'required|min:2|max:50');

    const {
      value: userRole,
      errorMessage: userRoleError,
      meta: userRoleMeta,
    } = useField('user_role', 'required');

    return {
      makeToast,
      handleSubmit,
      resetForm,
      setValues,
      userName,
      userNameError,
      userNameMeta,
      userEmail,
      emailError,
      emailMeta,
      orcid,
      orcidError,
      orcidMeta,
      abbreviation,
      abbreviationError,
      abbreviationMeta,
      firstName,
      firstNameError,
      firstNameMeta,
      familyName,
      familyNameError,
      familyNameMeta,
      userRole,
      userRoleError,
      userRoleMeta,
    };
  },
  data() {
    return {
      role_options: [],
      user_options: [],
      users: [],
      fields: [
        {
          key: 'user_name', label: 'User name', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'email', label: 'E-mail', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'orcid', label: 'ORCID', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'abbreviation', label: 'Abbreviation', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'first_name', label: 'First name', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'family_name', label: 'Family name', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'user_role', label: 'Role', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'comment', label: 'Comment', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        {
          key: 'approved', label: 'Approved', sortable: true, sortDirection: 'asc', class: 'text-start',
        },
        { key: 'actions', label: 'Actions', class: 'text-center' },
      ],
      isLoading: false,
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'user_id', order: 'asc' }],
      showDeleteModal: false,
      userToDelete: {},
      userToUpdate: {},
      deleteUserModal: { id: 'delete-usermodal', title: '', content: [] },
      updateUserModal: { id: 'update-usermodal', title: '', content: [] },
    };
  },
  mounted() {
    this.loadRoleList();
    this.loadUserList();
    this.loadUserTableData();
  },
  methods: {
    onUpdateSubmit() {
      this.handleSubmit(() => {
        this.updateUserData();
      })();
    },
    async loadUserTableData() {
      this.isLoading = true;
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/table`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        this.users = response.data;
      } catch (e) {
        this.makeToast(e.message, 'Error', 'danger');
      }

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();

      this.isLoading = false;
    },
    async loadRoleList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/role_list`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        this.role_options = response.data.map((item) => ({ value: item.role, text: item.role }));
      } catch (e) {
        this.makeToast(e.message, 'Error', 'danger');
      }
    },
    async loadUserList() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/list?roles=Curator,Reviewer`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        this.user_options = response.data.map((item) => ({ value: item.user_id, text: item.user_name, role: item.user_role }));
      } catch (e) {
        this.makeToast(e.message, 'Error', 'danger');
      }
    },
    promptDeleteUser(item, button) {
      this.deleteUserModal.title = `${item.user_name}`;
      this.userToDelete = item;
      const { showModal } = useModalControls();
      showModal(this.deleteUserModal.id);
    },
    async confirmDeleteUser() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/delete`;
      try {
        const response = await this.axios.delete(apiUrl, {
          data: { user_id: this.userToDelete.user_id },
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        if (response.status === 200) {
          this.makeToast('User deleted successfully', 'Success', 'success');
          this.users = this.users.filter((user) => user.user_id !== this.userToDelete.user_id);
        } else {
          throw new Error('Failed to delete the user.');
        }
      } catch (e) {
        this.makeToast(e.message, 'Error', 'danger');
      }
      const { hideModal } = useModalControls();
      hideModal(this.deleteUserModal.id);
      this.userToDelete = {};
    },
    editUser(item, button) {
      this.updateUserModal.title = `${item.user_name}`;
      this.userToUpdate = { ...item };
      // Sync vee-validate fields with the user data
      this.setValues({
        user_name: item.user_name,
        email: item.email,
        orcid: item.orcid,
        abbreviation: item.abbreviation,
        first_name: item.first_name,
        family_name: item.family_name,
        user_role: item.user_role,
      });
      const { showModal } = useModalControls();
      showModal(this.updateUserModal.id);
    },
    async updateUserData() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/user/update`;
      try {
        const response = await this.axios.put(apiUrl, { user_details: this.userToUpdate }, {
          headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
        });
        if (response.status === 200) {
          this.makeToast('User updated successfully', 'Success', 'success');
          this.loadUserTableData(); // Reload the table data
        } else {
          throw new Error('Failed to update the user.');
        }
      } catch (e) {
        this.makeToast(e.message, 'Error', 'danger');
      }
      this.userToUpdate = {};
    },
    /**
     * Handles sortBy updates from Bootstrap-Vue-Next GenericTable
     * @param {Array} newSortBy - Array of sort objects [{key, order}]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
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

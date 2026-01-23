<!-- src/views/curate/ManageReReview.vue -->
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
              <div class="d-flex justify-content-between align-items-center">
                <h6 class="mb-1 text-start font-weight-bold">
                  Manage re-review submissions
                  <BBadge
                    id="popover-badge-help-manage"
                    pill
                    href="#"
                    variant="info"
                  >
                    <i class="bi bi-question-circle-fill" />
                  </BBadge>
                  <BPopover
                    target="popover-badge-help-manage"
                    variant="info"
                    triggers="focus"
                  >
                    <template #title>
                      Re-review Submissions Management
                    </template>
                    Use this section to manage re-review submissions. You can assign new batches to users and view the details of each batch.
                  </BPopover>
                </h6>
              </div>
            </template>

            <BCol>
              <BRow>
                <BCol class="my-1">
                  <!-- button and select for new batch assignment -->
                  <BInputGroup
                    prepend="Username"
                    size="sm"
                  >
                    <BFormSelect
                      v-model="user_id_assignment"
                      :options="user_options"
                      class="username-select"
                    />
                    <BButton
                      block
                      size="sm"
                      variant="primary"
                      @click="handleNewBatchAssignment"
                    >
                      <i class="bi bi-plus-square mx-1" />
                      Assign new batch
                    </BButton>
                  </BInputGroup>
                  <small class="text-muted">Select a user and click "Assign new batch" to assign a new re-review batch to the selected user.</small>
                </BCol>

                <BCol class="my-1" />
              </BRow>
            </BCol>
            <!-- User Interface controls -->

            <BRow class="my-2">
              <BCol>
                <BPagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  align="fill"
                  size="sm"
                />
              </BCol>
              <BCol class="text-end">
                <BFormSelect
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                />
              </BCol>
            </BRow>
            <BTable
              :items="items_ReReviewTable"
              :fields="fields_ReReviewTable"
              :per-page="perPage"
              :current-page="currentPage"
              stacked="md"
              head-variant="light"
              show-empty
              small
              fixed
              striped
              hover
              sort-icon-left
              @filtered="onFiltered"
              @sort-changed="onSortChanged"
            >
              <template #cell(user_name)="row">
                <i class="bi bi-person-circle" />
                <BBadge variant="dark">
                  {{ row.item.user_name }}
                </BBadge>
              </template>

              <template #cell(actions)="data">
                <BButton
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  title="Unassign this batch"
                  variant="danger"
                  @click="handleBatchUnAssignment(data.item.re_review_batch)"
                >
                  <i class="bi bi-file-earmark-minus" />
                </BButton>
              </template>
            </BTable>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ApproveStatus',
  mixins: [toastMixin],
  data() {
    return {
      user_options: [],
      user_id_assignment: 0,
      items_ReReviewTable: [],
      fields_ReReviewTable: [
        {
          key: 'user_name',
          label: 'Username',
          sortable: true,
          filterable: true,
          sortDirection: 'desc',
          class: 'text-start',
        },
        {
          key: 're_review_batch',
          label: 'Re-review batch ID',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 're_review_review_saved',
          label: 'Review saved count',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 're_review_status_saved',
          label: 'Status saved count',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 're_review_submitted',
          label: 'Re-review submitted count',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 're_review_approved',
          label: 'Re-review approved count',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'entity_count',
          label: 'Total entities in batch',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        { key: 'actions', label: 'Actions' },
      ],
      currentPage: 1,
      perPage: 50,
      totalRows: 0,
      pageOptions: [
        { value: 5, text: '5' },
        { value: 10, text: '10' },
        { value: 20, text: '20' },
        { value: 50, text: '50' },
      ],
    };
  },
  mounted() {
    this.loadUserList();
    this.loadReReviewTableData();
  },
  methods: {
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
    async loadReReviewTableData() {
      this.loadingReReviewManagment = true;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/re_review/assignment_table`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.items_ReReviewTable = response.data;
        this.totalRows = response.data.length;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();

      this.loadingReReviewManagment = false;
    },
    async handleNewBatchAssignment() {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/re_review/batch/assign?user_id=${
        this.user_id_assignment}`;

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
        this.makeToast('New batch assigned successfully.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.loadReReviewTableData();
    },
    async handleBatchUnAssignment(batch_id) {
      const apiUrl = `${process.env.VUE_APP_API_URL
      }/api/re_review/batch/unassign?re_review_batch=${
        batch_id}`;

      try {
        const response = await this.axios.delete(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.makeToast('Batch unassigned successfully.', 'Success', 'success');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.loadReReviewTableData();
    },
    onFiltered(filteredItems) {
      this.totalRows = filteredItems.length;
    },
    onSortChanged(ctx) {
      // Handle sort change if needed
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

.username-select {
  background-color: #f8f9fa;
  border: 1px solid #ced4da;
  border-radius: 0.25rem;
  padding: 0.25rem 0.5rem;
  transition: border-color 0.15s ease-in-out, box-shadow 0.15s ease-in-out;
}

.username-select:focus {
  border-color: #80bdff;
  outline: 0;
  box-shadow: 0 0 0 0.2rem rgba(0, 123, 255, 0.25);
}
</style>

<!-- src/views/curate/ManageReReview.vue -->
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
              <div class="d-flex justify-content-between align-items-center">
                <h6 class="mb-1 text-left font-weight-bold">
                  Manage re-review submissions
                  <b-badge
                    id="popover-badge-help-manage"
                    pill
                    href="#"
                    variant="info"
                  >
                    <b-icon icon="question-circle-fill" />
                  </b-badge>
                  <b-popover
                    target="popover-badge-help-manage"
                    variant="info"
                    triggers="focus"
                  >
                    <template #title>
                      Re-review Submissions Management
                    </template>
                    Use this section to manage re-review submissions. You can assign new batches to users and view the details of each batch.
                  </b-popover>
                </h6>
              </div>
            </template>

            <b-col>
              <b-row>
                <b-col class="my-1">
                  <!-- button and select for new batch assignment -->
                  <b-input-group
                    prepend="Username"
                    size="sm"
                  >
                    <b-form-select
                      v-model="user_id_assignment"
                      :options="user_options"
                      class="username-select"
                    />
                    <b-input-group-append>
                      <b-button
                        block
                        size="sm"
                        variant="primary"
                        @click="handleNewBatchAssignment"
                      >
                        <b-icon
                          icon="plus-square"
                          class="mx-1"
                        />
                        Assign new batch
                      </b-button>
                    </b-input-group-append>
                  </b-input-group>
                  <small class="text-muted">Select a user and click "Assign new batch" to assign a new re-review batch to the selected user.</small>
                </b-col>

                <b-col class="my-1" />
              </b-row>
            </b-col>
            <!-- User Interface controls -->

            <b-row class="my-2">
              <b-col>
                <b-pagination
                  v-model="currentPage"
                  :total-rows="totalRows"
                  :per-page="perPage"
                  align="fill"
                  size="sm"
                />
              </b-col>
              <b-col class="text-right">
                <b-form-select
                  v-model="perPage"
                  :options="pageOptions"
                  size="sm"
                />
              </b-col>
            </b-row>
            <b-table
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
                <b-icon
                  icon="person-circle"
                  font-scale="1.0"
                />
                <b-badge variant="dark">
                  {{ row.item.user_name }}
                </b-badge>
              </template>

              <template #cell(actions)="data">
                <b-button
                  v-b-tooltip.hover.top
                  size="sm"
                  class="me-1 btn-xs"
                  title="Unassign this batch"
                  variant="danger"
                  @click="handleBatchUnAssignment(data.item.re_review_batch)"
                >
                  <b-icon
                    icon="file-earmark-minus"
                    font-scale="0.9"
                  />
                </b-button>
              </template>
            </b-table>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
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
          class: 'text-left',
        },
        {
          key: 're_review_batch',
          label: 'Re-review batch ID',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 're_review_review_saved',
          label: 'Review saved count',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 're_review_status_saved',
          label: 'Status saved count',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 're_review_submitted',
          label: 'Re-review submitted count',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 're_review_approved',
          label: 'Re-review approved count',
          sortable: true,
          filterable: true,
          class: 'text-left',
        },
        {
          key: 'entity_count',
          label: 'Total entities in batch',
          sortable: true,
          filterable: true,
          class: 'text-left',
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

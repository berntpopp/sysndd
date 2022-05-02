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
                Manage re-review submissions
              </h6>
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
          <!-- User Interface controls -->

                <b-table
                :items="items_ReReviewTable"
                :fields="fields_ReReviewTable"
                stacked="md"
                head-variant="light"
                show-empty
                small
                fixed
                striped
                hover
                sort-icon-left
              >
                <template #cell(user_name)="row">
                  <b-icon icon="person-circle" font-scale="1.0"></b-icon> <b-badge variant="dark">  {{ row.item.user_name }} </b-badge>
                </template>

                <template #cell(actions)="data">
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
import toastMixin from '@/assets/js/mixins/toastMixin.js'

export default {
  name: 'ApproveStatus',
  mixins: [toastMixin],
    data() {
      return {
        user_options: [],
        user_id_assignment: 0,
        items_ReReviewTable: [],
        fields_ReReviewTable: [
            { key: 'user_name', label: 'Username', sortable: true, filterable: true, sortDirection: 'desc', class: 'text-left' },
            { key: 're_review_batch', label: 'Re-review batch ID', sortable: true, filterable: true, class: 'text-left' },
            { key: 're_review_review_saved', label: 'Review saved count', sortable: true, filterable: true, class: 'text-left' },
            { key: 're_review_status_saved', label: 'Status saved count', sortable: true, filterable: true, class: 'text-left' },
            { key: 're_review_submitted', label: 'Re-review submitted count', sortable: true, filterable: true, class: 'text-left' },
            { key: 're_review_approved', label: 'Re-review approved count', sortable: true, filterable: true, class: 'text-left' },
            { key: 'entity_count', label: 'Total entities in batch', sortable: true, filterable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
        ],
      };
    },
    mounted() {
      this.loadUserList();
      this.loadReReviewTableData();
    },
    methods: {
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
            this.makeToast(e, 'Error', 'danger');
          }
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
            this.makeToast(e, 'Error', 'danger');
          }
          this.loadingReReviewManagment = false;
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
            this.makeToast(e, 'Error', 'danger');
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
            this.makeToast(e, 'Error', 'danger');
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
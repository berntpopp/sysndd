<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">


          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          bg-variant="light"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Approve new reviews
              </h6>
            </template>
          </b-card>
          <!-- User Interface controls -->

          <!-- Main table -->
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
          <!-- Main table -->

        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>

export default {
  name: 'ApproveReview',
    data() {
      return {
        loadingReviewApprove: true,
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
        totalRows_ReviewTable: 0,
      };
    },
    mounted() {
      this.loadReviewTableData();
    },
    methods: {
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
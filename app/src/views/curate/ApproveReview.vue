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
                Approve new reviews
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
                Approve all reviews
              </b-button>
            </b-input-group-append>
          </b-form>
          <!-- button for approve all -->

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
                @click="infoApproveReview(row.item, row.index, $event.target)" 
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
      @ok="handleApproveOk"
      >
        <template #modal-title>
          <h4>Entity: 
            <b-badge variant="primary">
              {{ approveModal.title }}
            </b-badge>
          </h4>
        </template>

      </b-modal>
      <!-- Approve modal -->


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
      title="Approve all reviews" 
      @ok="handleAllReviewsOk"
      >
        <p class="my-4">Are you sure you want to <span class="font-weight-bold">approve ALL</span> reviews below?</p>
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

export default {
  name: 'ApproveReview',
  mixins: [toastMixin],
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
        entity: [],
        approveModal: {
          id: 'approve-modal',
          title: '',
          content: []
        },
        approve_all_selected: false,
        switch_approve_text: {true: "Yes", false: "No"},
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
            this.makeToast(e, 'Error', 'danger');
          }
          this.loadingReviewApprove = false;
        },
        infoReview(item, index, button) {
          this.reviewModal.title = `sysndd:${item.entity_id}`;
          this.entity = [];
          this.entity.push(item);
          
          this.loadReviewInfo(item.review_id);
          this.$root.$emit('bv::show::modal', this.reviewModal.id, button);
        },
        infoApproveReview(item, index, button) {
          this.approveModal.title = `sysndd:${item.entity_id}`;
          this.entity = [];
          this.entity.push(item);
          this.$root.$emit('bv::show::modal', this.approveModal.id, button);
        },
        async handleApproveOk(bvModalEvt) {

          let apiUrl = process.env.VUE_APP_API_URL + '/api/review/approve/' + this.entity[0].review_id + '?review_ok=true';

          try {
            let response = await this.axios.put(apiUrl, {}, {
              headers: {
                'Authorization': 'Bearer ' + localStorage.getItem('token')
              }
            });

          this.loadReviewTableData();

          } catch (e) {
            this.makeToast(e, 'Error', 'danger');
          }
        },
        async handleAllReviewsOk() {
          if(this.approve_all_selected) {
            this.items_ReviewTable.forEach((x, i) => {
                  let apiUrl = process.env.VUE_APP_API_URL + '/api/review/approve/' + x.review_id + '?review_ok=true';
                  try {
                    let response = this.axios.put(apiUrl, {}, {
                      headers: {
                        'Authorization': 'Bearer ' + localStorage.getItem('token')
                      }
                    });

                  this.loadReviewTableData();

                  } catch (e) {
                    this.makeToast(e, 'Error', 'danger');
                  }
              }
            );
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
</style>
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
              <b-container fluid v-else>
              </b-container>
            </b-tab>

          </b-tabs>
          </div>
          
        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Curate',
    data() {
      return {
        loadingEntityNew: true,
        loadingEntityModify: true,
        loadingReviewApprove: true,
        loadingStatusApprove: true,
        loadingUsersApprove: true,
        tabIndex: 0
      };
    }
  }
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
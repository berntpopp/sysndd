<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="10">

          <h3>Curate</h3>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Curate',
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
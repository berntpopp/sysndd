<template>
  <div class="container-fluid centered">
    <b-container>
      <b-row class="justify-content-md-center py-4">
        <b-col md="6" align-self="center">
            <h1>
              404
            </h1>
            <h2>
              Page Not Found
            </h2>
          </b-col>
        </b-row>
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'PageNotFound',
  }
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
  .centered {
    display: flex;
    align-items: center;
    justify-content: center;
    min-height:calc(100vh - 100px);
  }
</style>
<template>
  <div class="container-fluid" style="padding-top: 80px;">
    <b-container fluid>

      <b-row class="justify-content-md-center mt-8">
        <b-col col md="10">

          <h3>Panels</h3>

          <b-card no-body>
            <b-tabs card>
              <b-tab title="Definitive All" active>
                <b-card-text>Tab contents 0</b-card-text>
              </b-tab>
              <b-tab title="Definitive Recessive">
                <b-card-text>Tab contents 1</b-card-text>
              </b-tab>
              <b-tab title="Definitive Dominant">
                <b-card-text>Tab contents 2</b-card-text>
              </b-tab>
              <b-tab title="Definitive Other">
                <b-card-text>Tab contents 3</b-card-text>
              </b-tab>
            </b-tabs>
          </b-card>

        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
export default {
  name: 'Panels',
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
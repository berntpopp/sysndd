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
                Modify an existing entity
              </h6>
            </template>
          </b-card>
          <!-- User Interface controls -->


        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>

export default {
  name: 'ApproveStatus',
    data() {
      return {
      };
    },
    mounted() {
    },
    methods: {
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
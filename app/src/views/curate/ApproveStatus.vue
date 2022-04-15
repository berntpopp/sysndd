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

            <b-container fluid>
              <form ref="form" @submit.stop.prevent="handleSubmit">

          <b-row>
            <!-- column 1 -->
            <b-col class="my-1">

            </b-col>

            <!-- column 2 -->
            <b-col class="my-1">

            </b-col>

            <!-- column 3 -->
            <b-col class="my-1">
              
            </b-col>

            <!-- column 4 -->
            <b-col class="my-1">
              
            </b-col>

            <!-- column 5 -->
            <b-col class="my-1">
              
            </b-col>
          </b-row>


              </form>
            </b-container>
          </b-card>

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
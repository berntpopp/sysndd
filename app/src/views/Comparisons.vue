<template>
  <div class="container-fluid" style="min-height:90vh">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="8">

  <div>
    <UpSetJS :sets="sets" :width="width" :height="height" @hover="hover" :selection="selection"></UpSetJS>
  </div>
        </b-col>
      </b-row>
      
    </b-container>
  </div>
</template>


<script>
  import UpSetJS, { extractSets, ISets, ISet } from '@upsetjs/vue';

  export default {
  name: 'Comparisions',
    components: {
      UpSetJS,
    },
    data() {
      return {
        elems: [],
        width: 100,
        height: 100,
        selection: null,
      };
    },
    computed: {
      sets() {
        return extractSets(this.elems);
      },
    },
    mounted() {
      this.loadComparisonsUpsetData();
      const bb = this.$el.getBoundingClientRect();
      this.width = bb.width;
      this.height = bb.height;
    },
    methods: {
        async loadComparisonsUpsetData() {
          this.loading = true;
          let apiUrl = process.env.VUE_APP_API_URL + '/api/statistics/comparisons_upset';
          try {
            let response = await this.axios.get(apiUrl);
            this.elems = response.data;
            console.log(this.elems);
          } catch (e) {
            console.error(e);
          }
        },
      hover(s) {
        this.selection = s;
      },
      },
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

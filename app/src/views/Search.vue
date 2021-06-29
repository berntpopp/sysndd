<template>
  <div class="container-fluid" style="padding-top: 80px;">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
      <b-row class="justify-content-md-center mt-8">
        <b-col col md="8">

          <h3>Search term: {{ $route.params.search_term }}</h3>

          <b-table
              :items="search"
              :fields="search_fields"
              small
          >

            <template #cell(results)="data">
              <b-link v-bind:href="data.item.link">
                <div style="cursor:pointer">{{ data.item.results }}</div>
              </b-link>
            </template>

            <template #cell(entity_id)="data">
              <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                <div style="cursor:pointer">sysndd:{{ data.item.entity_id }}</div>
              </b-link>
            </template>

          </b-table>

          </b-col>
        </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Gene',
  data() {
        return {
          search: [],
          search_fields: [
            { key: 'results', label: 'Results', class: 'text-left' },
            { key: 'search', label: 'Search', class: 'text-left' },
            { key: 'entity_id', label: 'Entity', class: 'text-left' },
            { key: 'searchdist', label: 'Searchdist', class: 'text-left' }
          ],
          loading: true
      }
  },
  computed: {
    formartedItems() {
      if (!this.search) return []
      return this.search.map(item => {
        item._rowVariant  = this.getVariant(item.searchdist)
        return item
      })
    }
  },
  mounted() {
    this.loadSearchInfo();
    },
  methods: {
  async loadSearchInfo() {
    this.loading = true;
    let apiSearchURL = process.env.VUE_APP_API_URL + '/api/search/' + this.$route.params.search_term + '?helper=false';
    try {
      let response_search = await this.axios.get(apiSearchURL);

      this.search = response_search.data;

      } catch (e) {
       console.error(e);
      }
    
      if (this.search.length == 1) {
        this.$router.push(this.search[0].link);
      } else {
      this.loading = false;
      this.formartedItems();
      }
    },
  getVariant(searchdist) {
		if (searchdist <= 0.05) {
			return 'success';
		} else if (searchdist < 0.1) {
			return 'warning';
		} else if (searchdist >= 0.1) {
			return 'danger';
		}
	}
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
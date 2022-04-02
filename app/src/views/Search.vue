<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
      <b-row class="justify-content-md-center py-2">
        <b-col col md="8">

          <h3>Search term: {{ $route.params.search_term }}</h3>

          <b-table
              :items="search"
              :fields="search_fields"
              small
          >

            <template #cell(results)="data">
              <b-link v-bind:href="data.item.link">
                <div>
                   <b-badge 
                  :variant="result_variant[data.item.search]"
                  style="cursor:pointer"
                  >
                  {{ data.item.results }}
                  </b-badge>
                </div>
              </b-link>
            </template>

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

          </b-table>

          </b-col>
        </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Search',
    metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Search',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Search table shows results of database searches and their similarity when no exact terms was identified.' },
      { vmid: 'robots', name: 'robots', content: 'noindex' }
    ]
  },
  data() {
        return {
          result_variant: {"entity_id": "primary", "symbol": "success", "disease_ontology_id_version": "secondary", "disease_ontology_name": "secondary"},
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
      this.formatedItems();
      }
    },
    formatedItems() {
      if (!this.search) return []
      return this.search.map(item => {
        item._rowVariant  = this.getVariant(item.searchdist)
        return item
      })
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
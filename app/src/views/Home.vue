<template>
  <div class="container-fluid" style="min-height:90vh">
    <b-container fluid v-if="loading"> <b-spinner label="Loading..." class="spinner float-center m-5"></b-spinner> </b-container>
    <b-container fluid v-else>

        <b-row class="justify-content-md-center py-2">
          <b-col md="12">

            <b-jumbotron class="text-left" style="padding-top: 5px; padding-bottom: 5px">

              <template #lead>
                The expert curated database of gene disease relationships in neurodevelopmental disorders.
              </template>

              <b-input-group class="mb-2">
                <b-form-input 
                autofocus
                list="search-list" 
                type="search" 
                placeholder="Search SysNDD-db" 
                size="md"
                autocomplete="off" 
                v-model="search_input"
                @input="loadSearchInfo"
                @keydown.native="keydown_handler"
                >
                </b-form-input>
                
                <b-datalist id="search-list" :options="search"></b-datalist>

                <b-input-group-append>
                  <b-button
                  variant="outline-primary"
                  size="md"
                  :disabled="search_input.length < 2"
                  v-bind:href="'/Search/' + search_input" >
                    <b-icon icon="search"></b-icon>
                  </b-button>
                </b-input-group-append>
              </b-input-group>

            </b-jumbotron>

            <b-card-group deck>
              <b-card header-tag="header">
                <template #header>
                  <h6 class="mb-0 font-weight-bold">Curated entities</h6>
                </template>
                <b-img :src="image" fluid alt="Fluid image"></b-img>
                <b-card-text class="text-left">
                  NDD genes since the SysID publication
                  <b-link href="https://pubmed.ncbi.nlm.nih.gov/26748517/" target="_blank"> 
                  (Kochinke & Zweier et al. 2016)
                  </b-link>.
                </b-card-text>
              </b-card>


              <b-card header-tag="header">
                <template #header>
                  <h6 class="mb-0 font-weight-bold">Current gene statistics ({{ last_update }})</h6>
                </template>
                <b-card-text class="text-left">
                  <b-table
                      :items="genes_statistics"
                      :fields="genes_statistics_fields"
                      stacked="md"
                      head-variant="light"
                      show-empty
                      small
                  >

                  <template #cell(n)="data">
                    <b-link v-bind:href="'/Panels/' + data.item.category + '/' + data.item.inheritance ">
                      <div style="cursor:pointer">{{ data.item.n }}</div>
                    </b-link>
                  </template>

                  <template #cell(actions)="row">
                    <b-button class="btn-xs" @click="row.toggleDetails" variant="outline-primary">
                      {{ row.detailsShowing ? 'hide' : 'show' }}
                    </b-button>
                  </template>

                  <template #row-details="row">
                    <b-card>
                      <b-table
                        :items="row.item.groups"
                        :fields="genes_statistics_details_fields"
                        head-variant="light"
                        show-empty
                        small
                        fixed
                        striped
                        sort-icon-left
                      >

                        <template #cell(n)="data">
                          <b-link v-bind:href="'/Panels/' + data.item.category + '/' + data.item.inheritance ">
                            <div style="cursor:pointer">{{ data.item.n }}</div>
                          </b-link>
                        </template>

                      </b-table>
                    </b-card>
                  </template>

                  </b-table>
                </b-card-text>
              </b-card>


              <b-card header-tag="header">
                <template #header>
                  <h6 class="mb-0 font-weight-bold">Gene news</h6>
                </template>
                <b-card-text class="text-left">
                  
                  <b-table
                    :items="news"
                    :fields="news_fields"
                    stacked="md"
                    head-variant="light"
                    show-empty
                    small
                    fixed
                    style="width: 100%; white-space: nowrap;"
                  >
                    
                    <template #table-colgroup="scope">
                      <col
                        v-for="field in scope.fields"
                        :key="field.key"
                        :style="{ width: field.key === 'symbol' ? '30%' : '70%' }"
                      >
                    </template>

                    <template #cell(symbol)="data">
                      <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                        <div class="font-italic text-truncate" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</div> 
                      </b-link>
                    </template>

                    <template #cell(disease_ontology_name)="data">
                        <div class="truncated" v-b-tooltip.hover.leftbottom v-bind:title="data.item.disease_ontology_name">{{ data.item.disease_ontology_name }}</div> 
                    </template>

                  </b-table>

                </b-card-text>
              </b-card>
            </b-card-group>   

          </b-col>
        </b-row>

    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Home',
  data() {
        return {
          search_input: '',
          search: [],
          last_update: '',
          genes_statistics: [],
          genes_statistics_fields: [
            { key: 'category', label: 'Category', class: 'text-left' },
            { key: 'n', label: 'Count', class: 'text-left' },
            { key: 'actions', label: 'Details' }
          ],
          genes_statistics_details_fields: [
            { key: 'inheritance', label: 'Inheritance' },
            { key: 'n', label: 'Count', class: 'text-left' }
          ],
          news: [],
          news_fields: [
            { key: 'symbol', label: 'Symbol', class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              class: 'text-left'
            }
          ],
          loading: true,
          image: ''
      }
  }, 
  mounted() {
    this.loadStatisticsAndNewsInfo();
    },
  methods: {
  async loadStatisticsAndNewsInfo() {
    this.loading = true;
    let apiStatisticsGenesURL = process.env.VUE_APP_API_URL + '/api/statistics/genes';
    let apiNewsURL = process.env.VUE_APP_API_URL + '/api/statistics/news';
    let apiNewsLastUpdate = process.env.VUE_APP_API_URL + '/api/statistics/last_update';
    let apiNewsEntitiesPlot = process.env.VUE_APP_API_URL + '/api/statistics/entities_plot';

    try {
      let response_statistics_genes = await this.axios.get(apiStatisticsGenesURL);
      let response_news = await this.axios.get(apiNewsURL);
      let response_last_update = await this.axios.get(apiNewsLastUpdate);
      let response_entities_plot = await this.axios.get(apiNewsEntitiesPlot);

      this.genes_statistics = response_statistics_genes.data;
      this.news = response_news.data;
      this.last_update = response_last_update.data[0].last_update;
      this.image = 'data:image/png;base64,'.concat(this.image.concat(response_entities_plot.data)) ;

      } catch (e) {
       console.error(e);
      }
    this.loading = false;
    },
  async loadSearchInfo() {
    let apiSearchURL = process.env.VUE_APP_API_URL + '/api/search/' + this.search_input;
    try {
      let response_search = await this.axios.get(apiSearchURL);
      this.search = response_search.data;
      } catch (e) {
       console.error(e);
      }
    },
  keydown_handler(event) {
     if (event.which === 13 & this.search_input.length > 1) {
        this.$router.push('/Search/' + this.search_input);
     }
    }
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
.truncated {
    display: block;
    white-space: nowrap; /* forces text to single line */
    overflow: hidden;
    text-overflow: ellipsis;
}
</style>

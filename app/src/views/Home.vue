<template>
  <div class="container-fluid" style="padding-top: 80px;">
    <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>

        <b-row class="justify-content-md-center mt-8">
          <b-col md="10">

            <b-jumbotron class="text-left" style="padding-top: 5px; padding-bottom: 5px">
              <template #header>Welcome to SysNDD,</template>

              <template #lead>
                a manually curated database of gene disease relationships in neurodevelopmental disorders
              </template>

              <hr class="my-4">

              <b-input-group class="mb-2">
                <b-form-input type="search" placeholder="Search the database" size="md"></b-form-input>
                  <b-input-group-append>
                    <b-button variant="outline-primary" size="md">
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
                  NDD associated genes curated over the years after the initial SysID
                  (<b-link href="https://pubmed.ncbi.nlm.nih.gov/26748517/" target="_blank"> 
                  Kochinke & Zweier et al. 2016
                  </b-link>)
                  import.
                </b-card-text>
              </b-card>

              <b-card header-tag="header">
                <template #header>
                  <h6 class="mb-0 font-weight-bold">Current statistics ({{ last_update }})</h6>
                </template>
                <b-card-text class="text-left">
                  <b-table
                      :items="genes_statistics"
                      :fields="genes_statistics_fields"
                      small
                  >
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
          >
            
            <template #cell(symbol)="data">
              <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                <div class="font-italic" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</div> 
              </b-link>
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
          last_update: '',
          genes_statistics: [],
          genes_statistics_fields: [
            { key: 'category', label: 'Category', class: 'text-left' },
            { key: 'inheritance', label: 'Inheritance', class: 'text-left' },
            { key: 'n', label: 'Count', class: 'text-left' },
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
    } 
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>
h3 {
  margin: 40px 0 0;
}
ul {
  list-style-type: none;
  padding: 0;
}
li {
  display: inline-block;
  margin: 0 10px;
}
a {
  color: #42b983;
}
</style>

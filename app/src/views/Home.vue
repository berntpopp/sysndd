<template>
  <div class="container-fluid" style="padding-top: 80px;">
        <b-row class="justify-content-md-center mt-8">
          <b-col col md="10">

            <b-jumbotron class="text-left">
              <template #header>Welcome to SysNDD,</template>

              <template #lead>
                a manually curated database of gene disease relationships in neurodevelopmental disorders
              </template>

              <hr class="my-4">

                  <b-input-group class="mb-2">
                    <b-form-input type="search" placeholder="Search the database"  size="lg"></b-form-input>
                      <b-input-group-append>
                        <b-button variant="outline-primary">
                          <b-icon icon="search"></b-icon>
                        </b-button>
                      </b-input-group-append>
                  </b-input-group>

            </b-jumbotron>

  
            <b-card-group deck>
              <b-card header-tag="header">
                <template #header>
                  <h6 class="mb-0">Curated entities</h6>
                </template>
                <b-card-text class="text-left">
                  The SysNDD database contains gene disease relationships manually curated from the literature based on the previous curation effort in SysID.
                  Our long-term goal is incorporation of the SysNDD/SysID data into other gene disease relationship databases like the Orphanet ontology.
                  To allow interoperability and mapping between gene-, phenotype- or disease-oriented databases we center our approach around curated gene-inheritance-disease units, so caleld entities, 
                  which are annotated with a predefined list of NDD associated phenotypes.
                </b-card-text>
              </b-card>

              <b-card header-tag="header">
                <template #header>
                  <h6 class="mb-0">Current statistics</h6>
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
                  <h6 class="mb-0">Gene news</h6>
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
            <template #cell(entity_id)="data">
              <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                <div style="cursor:pointer">sysndd:{{ data.item.entity_id }}</div>
              </b-link>
            </template>
            
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

  </div>
</template>

<script>
export default {
  name: 'Home',
  data() {
        return {
          genes_statistics: [],
          genes_statistics_fields: [
            { key: 'category', label: 'Category', class: 'text-left' },
            { key: 'inheritance', label: 'Inheritance', class: 'text-left' },
            { key: 'n', label: 'Count', class: 'text-left' },
          ],
          news: [],
          news_fields: [
            { key: 'entity_id', label: 'Entity', class: 'text-left' },
            { key: 'symbol', label: 'Symbol', class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              class: 'text-left'
            }
          ]
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
    try {
      let response_statistics_genes = await this.axios.get(apiStatisticsGenesURL);
      let response_news = await this.axios.get(apiNewsURL);

      this.genes_statistics = response_statistics_genes.data;
      this.news = response_news.data;

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

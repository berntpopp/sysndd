<template>
  <div class="container-fluid" style="min-height:90vh">

    <b-container fluid>

        <b-row class="justify-content-md-center py-2">
          <b-col md="12">

            <b-jumbotron class="text-left" style="padding-top: 5px; padding-bottom: 5px">

              <template #lead>
                The expert curated database of gene disease relationships in neurodevelopmental disorders (NDDs).
              </template>

              <b-input-group class="mb-2">
                <b-form-input 
                autofocus
                list="search-list" 
                type="search" 
                placeholder="Search the SysNDD-db by genes, entities and diseases using names or identifiers" 
                size="md"
                autocomplete="off" 
                v-model="search_input"
                @input="loadSearchInfo"
                @keydown.native="keydown_handler"
                >
                </b-form-input>
                
                <b-form-datalist id="search-list" 
                :options="search"
                >
                </b-form-datalist>

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

            <b-container fluid v-if="loading" style="min-height:50vh"> 
              <b-spinner label="Loading..." class="spinner float-center m-5"></b-spinner>
            </b-container>

            <b-card-group deck v-else>
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

                  <template #cell(category)="data">
                    <div>
                      <b-avatar
                      size="1.4em"
                      icon="stoplights"
                      :variant="stoplights_style[data.item.category]"
                      >
                      </b-avatar> {{ data.item.category }}
                    </div> 
                  </template>

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

                        <template #cell(inheritance)="data">
                          <div>
                            <b-badge 
                            pill 
                            variant="info" 
                            class="justify-content-md-center" 
                            size="1.3em"
                            >
                            {{ inheritance_short_text[data.item.inheritance] }}
                            </b-badge> {{ data.item.inheritance }}
                          </div>
                        </template>

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
                        :style="{ width: field.key === 'symbol' ? '35%' : '65%' }"
                      >
                    </template>

                    <template #cell(symbol)="data">
                      <div class="overflow-hidden text-truncate font-italic">
                        <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                          <b-badge pill variant="success" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</b-badge>
                        </b-link>
                      </div>
                    </template>

                    <template #cell(disease_ontology_name)="data">
                      <div class="overflow-hidden text-truncate">
                        <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version"> 
                          <b-badge pill variant="secondary" 
                          v-b-tooltip.hover.leftbottom 
                          v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version"
                          >
                          {{ truncate(data.item.disease_ontology_name, 40) }}
                          </b-badge>
                        </b-link>
                      </div>
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
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          inheritance_short_text: {"Dominant": "AD", "Recessive": "AR", "X-linked": "X", "Other": "M/S"},
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
    if (this.search[0] === this.search_input & isNaN(this.search_input)) {
      this.$router.push('/Search/' + this.search_input);
    }
    },
  keydown_handler(event) {
     if (event.which === 13 & this.search_input.length > 1) {
        this.$router.push('/Search/' + this.search_input);
     }
    },
  truncate(str, n) {
    return (str.length > n) ? str.substr(0, n-1) + '...' : str;
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
.truncated {
    display: block;
    white-space: nowrap; /* forces text to single line */
    overflow: hidden;
    text-overflow: ellipsis;
}
</style>
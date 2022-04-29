<template>
  <div class="bg-gradient">

    <b-container fluid>

        <b-row class="justify-content-md-center">
          <b-col md="12">

        <b-row class="justify-content-md-center">
          <b-col md="8">
            <b-container fluid="sm" class="py-3">
              <h3 class="text-center font-weight-bold">
                Welcome to SysNDD, 
              </h3>

              <h4 class="text-center">
                the expert curated database of gene disease relationships in <mark>neurodevelopmental disorders</mark> (NDD).
              </h4>
            </b-container>

            <b-input-group class="mb-2 p-2">
              <b-form-input 
              autofocus
              class="border-dark"
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
                variant="outline-dark"
                size="md"
                :disabled="search_input.length < 2"
                v-bind:href="'/Search/' + search_input" >
                  <b-icon icon="search"></b-icon>
                </b-button>
              </b-input-group-append>
            </b-input-group>

          </b-col>
        </b-row>

        <b-row>
          <b-col md="6">

              <b-card 
                header-tag="header"
                class="my-3 text-left"
                body-class="p-0"
                header-class="p-1"
                border-variant="dark"
              >
                <template #header>
                  <h5 class="mb-0 font-weight-bold">Current gene statistics</h5>
                </template>
                <b-card-text class="text-left">

                <b-skeleton-wrapper :loading="loading_statistics">
                  <template #loading>
                    <b-skeleton-table
                      :rows="2"
                      :columns="3"
                      :table-props="{ bordered: false, striped: false, small: true}"
                    ></b-skeleton-table>
                  </template>

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

                </b-skeleton-wrapper>

                </b-card-text>
              </b-card>


              <b-card 
                header-tag="header"
                class="my-3 text-left"
                body-class="p-0"
                header-class="p-1"
                border-variant="dark"
              >
                <template #header>
                  <h5 class="mb-0 font-weight-bold">Gene news</h5>
                </template>
                <b-card-text class="text-left">

                <b-skeleton-wrapper :loading="loading_statistics">
                  <template #loading>
                    <b-skeleton-table
                      :rows="3"
                      :columns="2"
                      :table-props="{ bordered: false, striped: false, small: true }"
                    ></b-skeleton-table>
                  </template>

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

                </b-skeleton-wrapper>

                </b-card-text>
              </b-card>
          </b-col>

          <b-col md="6" align-self="center">
            <div class="container-fluid text-left py-2 my-3">

              <span class="word">NDD comprise <mark>developmental delay</mark> (DD), <mark>intellectual disability</mark> (ID) and <mark>autism spectrum disorder</mark> (ASD). </span><br>
              <span class="word">This clinically and genetically extremely <mark>heterogeneous</mark> disease group affects <mark>about 2% of newborns</mark>. </span><br>
              <span class="word">SysNDD aims to empower clinical diagnostics, counseling and research for NDDs though <mark>expert curation</mark>. </span><br>

              <span class="word">We define “gene-inheritance-disease” units as “<mark>entities</mark>”. </span><br> 
              <span class="word">They are color coded throughout the website: <b-badge variant="primary">Entity:
                          <b-badge pill variant="success">Gene</b-badge> 
                          <b-badge pill variant="info">Inheritance</b-badge> 
                          <b-badge pill variant="secondary">Disease</b-badge> 
                        </b-badge></span><br>
                <span class="word">The SysNDD tool allows browsing and download of tabular views for curated NDD entity components in the <mark>Tables</mark> section. It offers multiple <mark>Analyses</mark> sections for genes, phenotypes and comparisions with other curation efforts. </span><br>

            </div>
          </b-col>

        </b-row>
          </b-col>
        </b-row>

    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Home',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Home',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Home view shows current information about NDD (attention-deficit/hyperactivity disorder (ADHD), autism, learning disabilities, intellectual disability) entities .' },
      { vmid: 'keywords', name: 'keywords', content: 'neurodevelopmental disorders, NDD, autism, ASD, learning disabilities, intellectual disability, ID, attention-deficit/hyperactivity disorder, ADHD' },
      { vmid: 'author', name: 'author', content: 'SysNDD database' }
    ]
  },
  data() {
        return {
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          inheritance_short_text: {"Dominant": "AD", "Recessive": "AR", "X-linked": "X", "Other": "M/S"},
          search_input: '',
          search: [],
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
          loading: false,
          loading_statistics: true,
          loading_news: true,
      }
  }, 
  mounted() {

    },
  created() {
    // watch the params of the route to fetch the data again
    this.$watch(
      () => this.$route.params,
      () => {
        this.loadStatistics();
        this.loadNews();
      },
      // fetch the data when the view is created and the data is
      // already being observed
      { immediate: true }
    )
  },
  methods: {
  async loadStatistics() {
    this.loading_statistics = true;

    let apiStatisticsGenesURL = process.env.VUE_APP_API_URL + '/api/statistics/genes';

    try {
      let response_statistics_genes = await this.axios.get(apiStatisticsGenesURL);

      this.genes_statistics = response_statistics_genes.data;

      this.loading_statistics = false;

      } catch (e) {
       console.error(e);
      }
    },
  async loadNews() {
    this.loading_news = true;

    let apiNewsURL = process.env.VUE_APP_API_URL + '/api/statistics/news?n=5';

    try {
      let response_news = await this.axios.get(apiNewsURL);

      this.news = response_news.data;

      this.loading_news = false;

      } catch (e) {
       console.error(e);
      }
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
.bg-gradient {
  margin:0px;
  height:100%;
  min-height:calc(100vh - 100px);
  background-image: linear-gradient(-225deg, #E3FDF5 0%, #FFE6FA 100%);
}
.border-dark {
    border: 1;
    border-color: #000;
}
.word {
  font-size: 1.25em;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #EAADBA;
}
.circle {
  height: 150px;
  width: 150px;
  border-radius: 20%;
  background-color: #FFF;
  margin: 0 5px 5px 0;
  float: left;
  -webkit-shape-outside: circle();
  shape-outside: circle();
}
</style>
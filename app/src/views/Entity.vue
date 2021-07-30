<template>
  <div class="container-fluid" style="padding-top: 80px;">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
      <b-row class="justify-content-md-center my-2">
        <b-col col md="10">
          <h3>Entity: 
            <b-badge variant="info">
              sysndd:{{ $route.params.sysndd_id }}
            </b-badge>
          </h3>

            <b-table
                :items="entity"
                :fields="entity_fields"
                stacked
                small
            >
                <template #cell(symbol)="data">
                  <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                    <div class="font-italic" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</div> 
                  </b-link>
                </template>

                <template #cell(disease_ontology_name)="data">
                  <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"> 
                    <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version">{{ data.item.disease_ontology_name }}</div> 
                  </b-link>

                      <b-button 
                      v-if="data.item.disease_ontology_id_version.includes('OMIM')"
                      class="btn-xs mx-2" 
                      variant="outline-primary"
                      v-bind:src="data.item.publications" 
                      v-bind:href="'https://www.omim.org/entry/' + data.item.disease_ontology_id_version.replace('OMIM:', '').replace(/_.+/g, '')"
                      target="_blank"
                      >
                        <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                        {{ data.item.disease_ontology_id_version.replace(/_.+/g, '') }}
                      </b-button>

                      <b-button 
                      v-if="data.item.disease_ontology_id_version.includes('MONDO')"
                      class="btn-xs mx-2" 
                      variant="outline-primary"
                      v-bind:src="data.item.publications" 
                      v-bind:href="'http://purl.obolibrary.org/obo/' + data.item.disease_ontology_id_version.replace(':', '_')"
                      target="_blank"
                      >
                        <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                        {{ data.item.disease_ontology_id_version }}
                      </b-button>

                </template>
                
                <template #cell(hpo_mode_of_inheritance_term_name)="data">
                    <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.hpo_mode_of_inheritance_term">{{ data.item.hpo_mode_of_inheritance_term_name.replace(" inheritance", "") }}</div> 
                </template>

            </b-table>


            <b-table
                :items="status"
                :fields="status_fields"
                stacked
                small
            >
            </b-table>


            <b-table
                :items="review"
                :fields="review_fields"
                stacked
                small
            >
            </b-table>


            <b-table
                :items="publications_table"
                stacked
                small
            >
              <template #cell(publications)="data">
                <b-row>
                  <b-row v-for="publication in publications" :key="publication.publication_id"> 
                    <b-col>
                      <b-button 
                      class="btn-xs mx-2" 
                      variant="outline-primary"
                      v-bind:src="data.item.publications" 
                      v-bind:href="'https://pubmed.ncbi.nlm.nih.gov/' + publication.publication_id.replace('PMID:', '')" 
                      target="_blank" 
                      v-b-tooltip.hover.bottom v-bind:title="publication.publication_status"
                      >
                        <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                        {{ publication.publication_id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>
            </b-table>

            <b-table
                :items="phenotypes_table"
                stacked
                small
            >
              <template #cell(phenotypes)="data">
                <b-row>
                  <b-row v-for="phenotype in phenotypes" :key="phenotype.phenotype_id"> 
                    <b-col>
                      <b-button 
                      class="btn-xs mx-2"
                      variant="outline-dark"
                      v-bind:src="data.item.phenotypes" 
                      v-bind:href="'https://hpo.jax.org/app/browse/term/' + phenotype.phenotype_id" 
                      target="_blank" 
                      v-b-tooltip.hover.bottom
                      v-bind:title="phenotype.phenotype_id"
                      >
                      <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                      {{ phenotype.HPO_term }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>
            </b-table>


          </b-col>
        </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Entity',
  data() {
        return {
          entity: [],
          entity_fields: [
            { key: 'symbol', label: 'Gene Symbol', sortable: true, class: 'text-left' },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'hpo_mode_of_inheritance_term_name',
              label: 'Inheritance',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'ndd_phenotype', label: 'NDD Association', sortable: true, class: 'text-left' }
          ],
          status: [],
          status_fields: [
            { key: 'category', label: 'Association Category', class: 'text-left' },
          ],
          review: [],
          review_fields: [
            { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-left' },
          ],
          publications: [],
          publications_table: [{ publications: ""}],
          phenotypes: [],
          phenotypes_table: [{ phenotypes: ""}],
          loading: true
      }
  }, 
  mounted() {
    this.loadEntityInfo();
    },
  methods: {
  async loadEntityInfo() {
    this.loading = true;
    let apiEntityURL = process.env.VUE_APP_API_URL + '/api/entities/' + this.$route.params.sysndd_id;
    let apiStatusURL = process.env.VUE_APP_API_URL + '/api/entities/' + this.$route.params.sysndd_id + '/status';
    let apiReviewURL = process.env.VUE_APP_API_URL + '/api/entities/' + this.$route.params.sysndd_id + '/review';
    let apiPublicationsURL = process.env.VUE_APP_API_URL + '/api/entities/' + this.$route.params.sysndd_id + '/publications';
    let apiPhenotypesURL = process.env.VUE_APP_API_URL + '/api/entities/' + this.$route.params.sysndd_id + '/phenotypes';
    try {
      let response_entity = await this.axios.get(apiEntityURL);
      let response_status = await this.axios.get(apiStatusURL);
      let response_review = await this.axios.get(apiReviewURL);
      let response_publications = await this.axios.get(apiPublicationsURL);
      let response_phenotypes = await this.axios.get(apiPhenotypesURL);
      this.entity = response_entity.data;
      this.status = response_status.data;
      this.review = response_review.data;
      this.publications = response_publications.data;
      this.phenotypes = response_phenotypes.data;
      } catch (e) {
       console.error(e);
      }
    this.loading = false;
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
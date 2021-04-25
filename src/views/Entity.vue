<template>
  <div class="container-fluid" style="padding-top: 80px;">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
        <h1>sysndd:{{ $route.params.sysndd_id }}</h1>
    </b-container>

    <b-table
        :items="entity"
        :fields="entity_fields"
        stacked
        small
    >
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
            <b-button class="btn-xs" v-bind:title="data.item.publications" v-bind:href="'https://pubmed.ncbi.nlm.nih.gov/' + publication.publication_id.replace('PMID:', '')" target="_blank" variant="outline-primary"> {{ publication.publication_id }}</b-button>
          </b-col>
        </b-row>
      </b-row>
    </template>
  </b-table>

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
            }
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
          publications_fields: [
            { key: 'publication_id', label: 'PMID', class: 'text-left' },
          ],
          publications_table: [{ publications: ""}],
          loading: true
      }
  }, 
  mounted() {
    this.loadEntityInfo();
    },
  methods: {
  async loadEntityInfo() {
    this.loading = true;
    let apiEntityURL = 'http://127.0.0.1:7777/api/entities/' + this.$route.params.sysndd_id;
    let apiStatusURL = 'http://127.0.0.1:7777/api/entities/' + this.$route.params.sysndd_id + '/status';
    let apiReviewURL = 'http://127.0.0.1:7777/api/entities/' + this.$route.params.sysndd_id + '/review';
    let apiPublicationsURL = 'http://127.0.0.1:7777/api/entities/' + this.$route.params.sysndd_id + '/publications';
    try {
      let response_entity = await this.axios.get(apiEntityURL);
      let response_status = await this.axios.get(apiStatusURL);
      let response_review = await this.axios.get(apiReviewURL);
      let response_publications = await this.axios.get(apiPublicationsURL);
      this.entity = response_entity.data;
      this.status = response_status.data;
      this.review = response_review.data;
      this.publications = response_publications.data;
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
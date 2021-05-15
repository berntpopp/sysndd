<template>
  <div class="container-fluid" style="padding-top: 80px;">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
      <b-row class="justify-content-md-center mt-8">
        <b-col col md="10">

          <h3>Gene: {{ $route.params.hgnc_id }}</h3>

          <b-table
              :items="gene"
              :fields="gene_fields"
              stacked
              small
          >
              <template #cell(symbol)="data">
                <b-link v-bind:href="'https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/' + data.item.hgnc_id" target="_blank"> 
                  <div class="font-italic" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</div> 
                </b-link>
              </template>

              <template #cell(entrez_id)="data">
                <b-link v-bind:href="'https://www.ncbi.nlm.nih.gov/gene/' + data.item.entrez_id" target="_blank"> 
                  <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.entrez_id">{{ data.item.entrez_id }}</div> 
                </b-link>
              </template>

              <template #cell(ensembl_gene_id)="data">
                <b-link v-bind:href="'https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=' + data.item.ensembl_gene_id" target="_blank"> 
                  <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.ensembl_gene_id">{{ data.item.ensembl_gene_id }}</div> 
                </b-link>
              </template>

              <template #cell(ucsc_id)="data">
                <b-link v-bind:href="'https://genome-euro.ucsc.edu/cgi-bin/hgGene?hgg_gene=' + data.item.ucsc_id" target="_blank"> 
                  <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.ucsc_id">{{ data.item.ucsc_id }}</div> 
                </b-link>
              </template>

              <template #cell(uniprot_ids)="data">
                <b-link v-bind:href="'https://www.uniprot.org/uniprot/' + data.item.uniprot_ids" target="_blank"> 
                  <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.uniprot_ids">{{ data.item.uniprot_ids }}</div> 
                </b-link>
              </template>

          </b-table>
        
          <h3>Associated phenotypes</h3>

          <!-- associated entities table element -->
          <b-table
            :items="entities_data"
            :fields="entities_data_fields"
            :current-page="currentPage"
            :per-page="perPage"
            :filter="filter"
            :filter-included-fields="filterOn"
            :sort-by.sync="sortBy"
            :sort-desc.sync="sortDesc"
            :sort-direction="sortDirection"
            stacked="md"
            head-variant="light"
            show-empty
            small
            fixed
            striped
            hover
            sort-icon-left
          >

            <template #cell(actions)="row">
              <b-button class="btn-xs" @click="row.toggleDetails" variant="outline-primary">
                {{ row.detailsShowing ? 'Hide' : 'Show' }} Details
              </b-button>
            </template>

            <template #row-details="row">
              <b-card>
                <ul>
                  <li v-for="(value, key) in row.item" :key="key">{{ key }}: {{ value }}</li>
                </ul>
              </b-card>
            </template>


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

            <template #cell(disease_ontology_name)="data">
              <b-link v-bind:href="'/Disease/' + data.item.disease_ontology_id_version"> 
                <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version">{{ truncate(data.item.disease_ontology_name, 20) }}</div> 
              </b-link>
            </template>

            <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div v-b-tooltip.hover.leftbottom v-bind:title="data.item.hpo_mode_of_inheritance_term">{{ data.item.hpo_mode_of_inheritance_term_name.replace(" inheritance", "") }}</div> 
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
          gene: [],
          gene_fields: [
            { key: 'symbol', label: 'Gene Symbol', sortable: true, class: 'text-left' },
            { key: 'name', label: 'Gene Name', sortable: true, class: 'text-left' },
            { key: 'entrez_id', label: 'Entrez ID', sortable: true, class: 'text-left' },
            { key: 'ensembl_gene_id', label: 'Ensembl ID', sortable: true, class: 'text-left' },
            { key: 'ucsc_id', label: 'UCSC ID', sortable: true, class: 'text-left' },
            { key: 'ccds_id', label: 'CCDS ID', sortable: true, class: 'text-left' },
            { key: 'uniprot_ids', label: 'UniProt ID', sortable: true, class: 'text-left' },
          ],
          entities_data: [],
          entities_data_fields: [
            { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-left' },
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
            { key: 'ndd_phenotype', label: 'NDD Association', sortable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
          ],
          loading: true
      }
  }, 
  mounted() {
    this.loadEntityInfo();
    },
  methods: {
  async loadEntityInfo() {
    this.loading = true;
    let apiGeneURL = process.env.VUE_APP_API_URL + '/api/genes/' + this.$route.params.hgnc_id;
    let apiEntitiesByGeneURL = process.env.VUE_APP_API_URL + '/api/genes/' + this.$route.params.hgnc_id + '/entities';
    try {
      let response_gene = await this.axios.get(apiGeneURL);
      let response_entities_by_gene = await this.axios.get(apiEntitiesByGeneURL);
      this.gene = response_gene.data;
      this.entities_data = response_entities_by_gene.data;

      } catch (e) {
       console.error(e);
      }
    this.loading = false;
    },
    truncate(str, n){
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
</style>
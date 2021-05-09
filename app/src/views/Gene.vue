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
    try {
      let response_gene = await this.axios.get(apiGeneURL);
      this.gene = response_gene.data;
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
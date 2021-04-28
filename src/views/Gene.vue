<template>
  <div class="container-fluid" style="padding-top: 80px;">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
        <h2>Gene: {{ $route.params.hgnc_id }}</h2>
    </b-container>

    <b-table
        :items="gene"
        :fields="gene_fields"
        stacked
        small
    >
        <template #cell(symbol)="data">
          <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
            <div class="font-italic" v-b-tooltip.hover.leftbottom v-bind:title="data.item.hgnc_id">{{ data.item.symbol }}</div> 
          </b-link>
        </template>

    </b-table>


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
    let apiGeneURL = 'http://127.0.0.1:7777/api/genes/' + this.$route.params.hgnc_id;
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
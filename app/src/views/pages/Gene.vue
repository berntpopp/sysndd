<template>
  <div class="container-fluid bg-gradient">

  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
      <b-row class="justify-content-md-center py-2" align-v="center">
        <b-col col md="12">

          <!-- Gene overview card -->
          <b-card 
          header-tag="header"
          class="my-3 text-left"
          body-class="p-0"
          header-class="p-1"
          border-variant="dark"
          >

            <template #header>
              <h3 class="mb-1 text-left font-weight-bold">Gene: 
                <b-badge pill variant="success">
                  {{ $route.params.symbol }}
                </b-badge>
              </h3>
            </template>

            <b-table
                :items="gene"
                :fields="gene_fields"
                stacked
                small
            >
                <template #cell(symbol)="data">
                  <b-row>
                    <b-row v-for="id in data.item.symbol" :key="id"> 
                        <b-col>
                          <div class="font-italic">
                            <b-link v-bind:href="'/Genes/' + id"> 
                              <b-badge
                              pill
                              variant="success"
                              class="mx-2" 
                              v-b-tooltip.hover.leftbottom 
                              v-bind:title="id"
                              >
                              {{ id }}
                              </b-badge>
                            </b-link>
                          </div> 

                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://www.genenames.org/data/gene-symbol-report/#!/symbol/'+ id" 
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            <span class="font-italic"> {{ id }} </span>
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(name)="data">
                <b-row>
                    <b-row v-for="id in data.item.name" :key="id">
                        <b-col>
                          <span class="font-italic mx-2"> {{ id }} </span>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(entrez_id)="data">
                <b-row>
                    <b-row v-for="id in data.item.entrez_id" :key="id">
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://www.ncbi.nlm.nih.gov/gene/'+ id"
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(ensembl_gene_id)="data">
                <b-row>
                    <b-row v-for="id in data.item.ensembl_gene_id" :key="id">
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://www.ensembl.org/Homo_sapiens/Gene/Summary?g='+ id"
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(ucsc_id)="data">
                <b-row>
                    <b-row v-for="id in data.item.ucsc_id" :key="id">
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://genome-euro.ucsc.edu/cgi-bin/hgGene?hgg_gene='+ id + '&db=hg38'"
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(ccds_id)="data">
                  <b-row>
                    <b-row v-for="id in data.item.ccds_id" :key="id"> 
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://www.ncbi.nlm.nih.gov/CCDS/CcdsBrowse.cgi?REQUEST=CCDS&DATA='+ id"
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(uniprot_ids)="data">
                  <b-row>
                    <b-row v-for="id in data.item.uniprot_ids" :key="id"> 
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://www.uniprot.org/uniprot/'+ id"
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(omim_id)="data">
                  <b-row>
                    <b-row v-for="id in data.item.omim_id" :key="id"> 
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://www.omim.org/entry/'+ id"
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            *{{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(mgd_id)="data">
                  <b-row>
                    <b-row v-for="id in data.item.mgd_id" :key="id"> 
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'http://www.informatics.jax.org/marker/'+ id"
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(rgd_id)="data">
                  <b-row>
                    <b-row v-for="id in data.item.rgd_id" :key="id">
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://rgd.mcw.edu/rgdweb/report/gene/main.html?id='+ id"
                          v-if="id"
                          target="_blank"
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

                <template #cell(STRING_id)="data">
                  <b-row>
                    <b-row v-for="id in data.item.STRING_id" :key="id"> 
                        <b-col>
                          <b-button 
                          class="btn-xs mx-2" 
                          variant="outline-primary"
                          v-bind:src="id" 
                          v-bind:href="'https://string-db.org/network/'+ id" 
                          v-if="id"
                          target="_blank" 
                          >
                            <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                            {{ id }}
                          </b-button>
                        </b-col>
                      </b-row>
                    </b-row>
                </template>

            </b-table>          
          </b-card>
          <!-- Gene overview card -->


          <!-- Associated entities card -->
          <b-card 
          header-tag="header"
          body-class="p-0"
          header-class="p-1"
          border-variant="dark"
          >

            <template #header>
              <h3 class="mb-1 text-left font-weight-bold">
                <b-badge variant="primary">Associated entities</b-badge>
              </h3>
            </template>


            <!-- associated entities table element -->
            <b-table
              :items="entities_data"
              :fields="entities_data_fields"
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
                  <b-table
                    :items="[row.item]"
                    stacked 
                    small
                  >
                  </b-table>
                </b-card>
              </template>


              <template #cell(entity_id)="data">
                <div>
                  <b-link v-bind:href="'/Entities/' + data.item.entity_id">
                    <b-badge 
                    variant="primary"
                    style="cursor:pointer"
                    >
                    sysndd:{{ data.item.entity_id }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(symbol)="data">
                <div class="font-italic">
                  <b-link v-bind:href="'/Genes/' + data.item.hgnc_id"> 
                    <b-badge pill variant="success"
                    v-b-tooltip.hover.leftbottom 
                    v-bind:title="data.item.hgnc_id"
                    >
                    {{ data.item.symbol }}
                    </b-badge>
                  </b-link>
                </div> 
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-link v-bind:href="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"> 
                    <b-badge 
                    pill 
                    variant="secondary"
                    v-b-tooltip.hover.leftbottom
                    v-bind:title="data.item.disease_ontology_name + '; ' + data.item.disease_ontology_id_version"
                    >
                    {{ truncate(data.item.disease_ontology_name, 40) }}
                    </b-badge>
                  </b-link>
                </div> 
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div>
                  <b-badge 
                  pill 
                  variant="info" 
                  class="justify-content-md-center" 
                  size="1.3em"
                  v-b-tooltip.hover.leftbottom 
                  v-bind:title="data.item.hpo_mode_of_inheritance_term_name + ' (' + data.item.hpo_mode_of_inheritance_term + ')'"
                  >
                  {{ inheritance_short_text[data.item.hpo_mode_of_inheritance_term_name] }}
                  </b-badge>
                </div>
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <div>
                  <b-avatar 
                  size="1.4em" 
                  :icon="ndd_icon[data.item.ndd_phenotype_word]"
                  :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                  v-b-tooltip.hover.left 
                  v-bind:title="ndd_icon_text[data.item.ndd_phenotype_word]"
                  >
                  </b-avatar>
                </div> 
              </template>

            </b-table>
          </b-card>
          <!-- Associated entities card -->

          </b-col>
        </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin.js'

export default {
  name: 'Gene',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Gene',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'This Gene view shows specific information for a gene.' }
    ]
  },
  data() {
        return {
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "NOT associated with NDD", "Yes": "associated with NDD"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "X-linked inheritance, other": "Xo", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "Mit", "Somatic mutation": "Som"},
          gene: [],
          gene_fields: [
            { key: 'symbol', label: 'HGNC Symbol', sortable: true, class: 'text-left' },
            { key: 'name', label: 'Gene Name', sortable: true, class: 'text-left' },
            { key: 'entrez_id', label: 'Entrez', sortable: true, class: 'text-left' },
            { key: 'ensembl_gene_id', label: 'Ensembl', sortable: true, class: 'text-left' },
            { key: 'ucsc_id', label: 'UCSC', sortable: true, class: 'text-left' },
            { key: 'ccds_id', label: 'CCDS', sortable: true, class: 'text-left' },
            { key: 'uniprot_ids', label: 'UniProt', sortable: true, class: 'text-left' },
            { key: 'omim_id', label: 'OMIM gene', sortable: true, class: 'text-left' },
            { key: 'mgd_id', label: 'MGI', sortable: true, class: 'text-left' },
            { key: 'rgd_id', label: 'RGD', sortable: true, class: 'text-left' },
            { key: 'STRING_id', label: 'STRING', sortable: true, class: 'text-left' },
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
            { key: 'ndd_phenotype_word', label: 'NDD', sortable: true, class: 'text-left' },
            { key: 'actions', label: 'Actions' }
          ],
          totalRows: 0,
          loading: true
      }
  }, 
  mounted() {
    this.loadGeneInfo();
    },
  methods: {
  async loadGeneInfo() {
    this.loading = true;
    let apiGeneURL = process.env.VUE_APP_API_URL + '/api/gene/' + this.$route.params.symbol + '?input_type=hgnc';
    let apiGeneSymbolURL = process.env.VUE_APP_API_URL + '/api/gene/' + this.$route.params.symbol + '?input_type=symbol';
    let apiEntitiesByGeneSymbolURL = process.env.VUE_APP_API_URL + '/api/entity?filter=equals(symbol,' + this.$route.params.symbol + ')&page[size]=all';
    let apiEntitiesByGeneURL = process.env.VUE_APP_API_URL + '/api/entity?filter=equals(hgnc_id,' + this.$route.params.symbol + ')&page[size]=all';

    try {
      let response_gene = await this.axios.get(apiGeneURL);
      let response_symbol = await this.axios.get(apiGeneSymbolURL);
      let response_entities_by_gene = await this.axios.get(apiEntitiesByGeneURL);
      let response_entities_by_symbol = await this.axios.get(apiEntitiesByGeneSymbolURL);


      if (response_gene.data.length == 0 && response_symbol.data.length == 0) {
          this.$router.push('/PageNotFound');
      } else {
        if (response_gene.data.length == 0) {
          this.gene = response_symbol.data;
          this.entities_data = response_entities_by_symbol.data.data;
          this.totalRows = response_entities_by_symbol.data.data.length;
        } else {
          this.gene = response_gene.data;
          this.entities_data = response_entities_by_gene.data.data;
          this.totalRows = response_entities_by_gene.data.data.length;
        }
      }

      } catch (e) {
       this.makeToast(e, 'Error', 'danger');
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
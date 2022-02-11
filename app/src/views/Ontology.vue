<template>
  <div class="container-fluid" style="min-height:90vh">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
      <b-row class="justify-content-md-center py-2">
        <b-col col md="10">
          <h3>Disease: 
            <b-badge pill variant="secondary">
              {{ $route.params.disease_term }}
            </b-badge>
          </h3>

            <b-table
                :items="ontology"
                :fields="ontology_fields"
                stacked
                small
            >

              <template #cell(disease_ontology_id_version)="data">
                <b-row>
                  <b-row v-for="id in data.item.disease_ontology_id_version.split(';')" :key="id"> 
                      <b-col>
                      <div>
                          <b-link v-bind:href="'/Ontology/' + id.replace(/_.+/g, '')"> 
                            <b-badge 
                            pill 
                            variant="secondary"
                            v-b-tooltip.hover.leftbottom
                            >
                            {{ id }}
                            </b-badge>
                          </b-link>
                        </div>

                        <b-button 
                        class="btn-xs mx-2" 
                        variant="outline-primary"
                        v-bind:src="data.item.disease_ontology_id_version.split(';')" 
                        v-bind:href="'https://www.omim.org/entry/'+ id.replace(/OMIM:/g,'')" 
                        target="_blank" 
                        >
                          <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                          {{ id }}
                        </b-button>
                      </b-col>
                    </b-row>
                  </b-row>
              </template>

              <template #cell(disease_ontology_name)="data">
                <div>
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


              <template #cell(DOID)="data">
                <b-row>
                  <b-row v-for="id in data.item.DOID.split(';')" :key="id"> 
                      <b-col>
                        <b-button 
                        class="btn-xs mx-2" 
                        variant="outline-primary"
                        v-bind:src="data.item.DOID.split(';')" 
                        v-bind:href="'https://disease-ontology.org/term/'+ id" 
                        target="_blank" 
                        >
                          <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                          {{ id }}
                        </b-button>
                      </b-col>
                    </b-row>
                  </b-row>
              </template>

              <template #cell(MONDO)="data">
                <b-row>
                  <b-row v-for="id in data.item.MONDO.split(';')" :key="id"> 
                      <b-col>
                        <b-button 
                        class="btn-xs mx-2" 
                        variant="outline-primary"
                        v-bind:src="data.item.MONDO.split(';')" 
                        v-bind:href="'http://purl.obolibrary.org/obo/'+ id.replace(':', '_')" 
                        target="_blank" 
                        >
                          <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                          {{ id }}
                        </b-button>
                      </b-col>
                    </b-row>
                  </b-row>
              </template>

              <template #cell(Orphanet)="data">
                <b-row>
                  <b-row v-for="id in data.item.Orphanet.split(';')" :key="id"> 
                      <b-col>
                        <b-button 
                        class="btn-xs mx-2" 
                        variant="outline-primary"
                        v-bind:src="data.item.Orphanet.split(';')" 
                        v-bind:href="'https://www.orpha.net/consor/cgi-bin/OC_Exp.php?Expert='+ id.replace('Orphanet:', '') + '&lng=EN'" 
                        target="_blank" 
                        >
                          <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                          {{ id }}
                        </b-button>
                      </b-col>
                    </b-row>
                  </b-row>
              </template>

              <template #cell(UMLS)="data">
                <b-row>
                  <b-row v-for="id in data.item.UMLS.split(';')" :key="id"> 
                      <b-col>
                        <b-button 
                        class="btn-xs mx-2" 
                        variant="outline-primary"
                        v-bind:src="data.item.UMLS.split(';')" 
                        v-bind:href="'https://www.ncbi.nlm.nih.gov/medgen/'+ id.replace('UMLS:', '')" 
                        target="_blank" 
                        >
                          <b-icon icon="box-arrow-up-right" font-scale="0.8"></b-icon>
                          {{ id }}
                        </b-button>
                      </b-col>
                    </b-row>
                  </b-row>
              </template>

              <template #cell(EFO)="data">
                <b-row>
                  <b-row v-for="id in data.item.EFO.split(';')" :key="id"> 
                      <b-col>
                        <b-button 
                        class="btn-xs mx-2" 
                        variant="outline-primary"
                        v-bind:src="data.item.EFO.split(';')" 
                        v-bind:href="'http://www.ebi.ac.uk/efo/'+ id.replace(':', '_')" 
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

        
          <h3><b-badge variant="primary">Associated entities</b-badge></h3>

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
                  :fields="fields_details"
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

            <template #cell(ndd_phenotype)="data">
              <div>
                <b-avatar 
                size="1.4em" 
                :icon="ndd_icon[data.item.ndd_phenotype]"
                :variant="ndd_icon_style[data.item.ndd_phenotype]"
                v-b-tooltip.hover.left 
                v-bind:title="ndd_icon_text[data.item.ndd_phenotype]"
                >
                </b-avatar>
              </div> 
            </template>

            <template #cell(category)="data">
              <div>
                <b-avatar
                size="1.4em"
                icon="stoplights"
                :variant="stoplights_style[data.item.category]"
                v-b-tooltip.hover.left 
                v-bind:title="data.item.category"
                >
                </b-avatar>
              </div> 
            </template>
            
          </b-table>


          </b-col>
        </b-row>
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'Ontology',
  data() {
        return {
          stoplights_style: {"Definitive": "success", "Moderate": "primary", "Limited": "warning", "Refuted": "danger"},
          ndd_icon: {"No": "x", "Yes": "check"},
          ndd_icon_style: {"No": "warning", "Yes": "success"},
          ndd_icon_text: {"No": "not associated with NDDs", "Yes": "associated with NDDs"},
          inheritance_short_text: {"Autosomal dominant inheritance": "AD", "Autosomal recessive inheritance": "AR", "X-linked inheritance": "X", "X-linked recessive inheritance": "XR", "X-linked dominant inheritance": "XD", "Mitochondrial inheritance": "M", "Somatic mutation": "S", "Semidominant mode of inheritance": "sD"},
          ontology: [],
          ontology_fields: [
            { 
              key: 'disease_ontology_id_version', 
              label: 'Versions', 
              sortable: true, 
              class: 'text-left' 
            },
            {
              key: 'disease_ontology_name',
              label: 'Disease',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            {
              key: 'hpo_mode_of_inheritance_term',
              label: 'Inheritance',
              sortable: true,
              class: 'text-left',
              sortByFormatted: true,
              filterByFormatted: true
            },
            { key: 'DOID', label: 'DOID', sortable: true, class: 'text-left' },
            { key: 'MONDO', label: 'MONDO', sortable: true, class: 'text-left' },
            { key: 'Orphanet', label: 'Orphanet', sortable: true, class: 'text-left' },
            { key: 'UMLS', label: 'UMLS', sortable: true, class: 'text-left' },
            { key: 'EFO', label: 'EFO', sortable: true, class: 'text-left' }
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
            { key: 'ndd_phenotype', label: 'NDD', sortable: true, class: 'text-left' },
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
    let apiDiseaseOntologyURL = process.env.VUE_APP_API_URL + '/api/ontology/' + this.$route.params.disease_term;
    let apiDiseaseNameURL = process.env.VUE_APP_API_URL + '/api/ontology/name/' + this.$route.params.disease_term;
    let apiEntitiesByOntologyURL = process.env.VUE_APP_API_URL + '/api/ontology/' + this.$route.params.disease_term + '/entities';
    let apiEntitiesByNameURL = process.env.VUE_APP_API_URL + '/api/ontology/name/' + this.$route.params.disease_term + '/entities';

    try {
      let response_ontology = await this.axios.get(apiDiseaseOntologyURL);
      let response_name = await this.axios.get(apiDiseaseNameURL);
      let response_entities_by_ontology = await this.axios.get(apiEntitiesByOntologyURL);
      let response_entities_by_name = await this.axios.get(apiEntitiesByNameURL);

      if (response_ontology.data == 0) {
        this.ontology = response_name.data;
        this.entities_data = response_entities_by_name.data;
      } else {
        this.ontology = response_ontology.data;
        this.entities_data = response_entities_by_ontology.data;
      }

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
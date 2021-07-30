<template>
  <div class="container-fluid">
  <b-spinner label="Loading..." v-if="loading" class="float-center m-5"></b-spinner>
    <b-container fluid v-else>
      <b-row class="justify-content-md-center mt-8">
        <b-col col md="10">
          <h3>Disease: 
            <b-badge variant="info">
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

    try {
      let response_ontology = await this.axios.get(apiDiseaseOntologyURL);
      let response_name = await this.axios.get(apiDiseaseNameURL);

      if (response_ontology.data == 0) {
        this.ontology = response_name.data;
      } else {
        this.ontology = response_ontology.data;
      }

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
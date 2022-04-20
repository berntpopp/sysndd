<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">


          <!-- User Interface controls -->
          <b-card 
          header-tag="header"
          bg-variant="light"
          align="left"
          >
            <template #header>
              <h6 class="mb-1 text-left font-weight-bold">
                Modify an existing entity
              </h6>
            </template>
          <!-- User Interface controls -->

            <b-card
              class="my-2"
              title="1. Select an entity"
            >

              <b-row>
                <b-col class="my-1">

                  <treeselect
                    id="entity-select" 
                    :multiple="false"
                    :async="true"
                    :load-options="loadEntityInfo"
                    v-model="entity_input"
                    :normalizer="normalizer"
                    required
                  />

                </b-col>
              </b-row>

            </b-card>

            <b-card
              class="my-2"
              title="2. Options to modify the above selected entity"
              v-if="entity_input"
            >

              <b-row>
                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button 
                      size="sm"
                      variant="dark"
                    >
                      <b-icon icon="pen" font-scale="1.0"></b-icon> 
                      <b-icon icon="link" font-scale="1.0"></b-icon> 
                      Rename disease
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button 
                      size="sm"
                      variant="dark"
                    >
                      <b-icon icon="x" font-scale="1.0"></b-icon> 
                      <b-icon icon="link" font-scale="1.0"></b-icon> 
                      Deactivate entity
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button 
                      size="sm"
                      variant="dark"
                    >
                      <b-icon icon="pen" font-scale="1.0"></b-icon> 
                      <b-icon icon="clipboard-plus" font-scale="1.0"></b-icon> 
                      Modify review
                    </b-button>
                  </b-input-group-append>
                </b-col>

                <b-col class="my-1">
                  <b-input-group-append>
                    <b-button 
                      size="sm"
                      variant="dark"
                    >
                      <b-icon icon="pen" font-scale="1.0"></b-icon> 
                      <b-icon icon="stoplights" font-scale="1.0"></b-icon> 
                      Modify status
                    </b-button>
                  </b-input-group-append>
                </b-col>
              </b-row>

            </b-card>

          </b-card>

        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>
  // import the Treeselect component
  import Treeselect from '@riophae/vue-treeselect'
  // import the Treeselect styles
  import '@riophae/vue-treeselect/dist/vue-treeselect.css'


export default {
  // register the Treeselect component
  components: { Treeselect },
  name: 'ApproveStatus',
    data() {
      return {
        entity_input: null,
      };
    },
    mounted() {
    },
    methods: {
        async loadEntityInfo({searchQuery, callback}) {
          let apiSearchURL = process.env.VUE_APP_API_URL + '/api/entity?filter=contains(any,' + searchQuery + ')';

          try {
            let response_search = await this.axios.get(apiSearchURL);

            callback(null, response_search.data.data);
            } catch (e) {
            console.error(e);
            }
        },
        normalizer(node) {
          return {
            id: node.entity_id,
            label: "sysndd:" + node.entity_id + " (" + node.symbol + " - " + node.disease_ontology_id_version + " - " + node.hpo_mode_of_inheritance_term_name + ")",
          }
        },
    }
    };
</script>


<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
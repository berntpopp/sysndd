<template>
  <div class="container-fluid bg-gradient">
    <b-spinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <b-container
      v-else
      fluid
    >
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <!-- Ontology overview card -->
          <b-card
            header-tag="header"
            class="my-3 text-left"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-left font-weight-bold">
                Disease:
                <b-badge
                  pill
                  variant="secondary"
                >
                  {{ $route.params.disease_term }}
                </b-badge>
              </h3>
            </template>

            <b-table
              :items="ontology"
              :fields="ontology_fields"
              stacked
              small
              fixed
              style="width: 100%; white-space: nowrap"
            >
              <template #cell(disease_ontology_id_version)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.disease_ontology_id_version"
                    :key="id"
                  >
                    <b-col>
                      <div class="overflow-hidden text-truncate font-italic">
                        <b-link :href="'/Ontology/' + id.replace(/_.+/g, '')">
                          <b-badge
                            v-b-tooltip.hover.leftbottom
                            pill
                            class="mx-2"
                            variant="secondary"
                          >
                            {{ id }}
                          </b-badge>
                        </b-link>
                      </div>

                      <b-button
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="data.item.disease_ontology_id_version"
                        :href="
                          'https://www.omim.org/entry/' +
                            id.replace(/OMIM:/g, '').replace(/_.+/g, '')
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(disease_ontology_name)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.disease_ontology_name"
                    :key="id"
                  >
                    <b-col>
                      <b-link :href="'/Ontology/' + id">
                        <b-badge
                          v-b-tooltip.hover.leftbottom
                          pill
                          class="mx-2"
                          variant="secondary"
                          :title="id"
                        >
                          {{ truncate(id, 40) }}
                        </b-badge>
                      </b-link>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.hpo_mode_of_inheritance_term_name"
                    :key="id"
                  >
                    <b-col>
                      <b-badge
                        v-if="id"
                        v-b-tooltip.hover.leftbottom
                        pill
                        class="mx-2"
                        variant="info"
                        size="1.3em"
                        :title="
                          id +
                            ' (' +
                            data.item.hpo_mode_of_inheritance_term +
                            ')'
                        "
                      >
                        {{ id }}
                      </b-badge>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(DOID)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.DOID"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://disease-ontology.org/term/' + id"
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(MONDO)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.MONDO"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="
                          'http://purl.obolibrary.org/obo/' +
                            id.replace(':', '_')
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>

              <template #cell(Orphanet)="data">
                <b-row>
                  <b-row
                    v-for="id in data.item.Orphanet"
                    :key="id"
                  >
                    <b-col>
                      <b-button
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="data.item.Orphanet"
                        :href="
                          'https://www.orpha.net/consor/cgi-bin/OC_Exp.php?Expert=' +
                            id.replace('Orphanet:', '') +
                            '&lng=EN'
                        "
                        target="_blank"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>
            </b-table>
          </b-card>
          <!-- Ontology overview card -->

          <!-- Associated entities card -->

          <TablesEntities
            v-if="ontology.length !== 0"
            :show-filter-controls="false"
            :show-pagination-controls="false"
            header-label="Associated "
            :filter-input="'any(disease_ontology_id_version,' +
              ontology[0].disease_ontology_id_version.join(',') + ')'"
          />

          <!-- Associated entities card -->
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';

// Import the utilities file
import Utils from '@/assets/js/utils';

export default {
  name: 'Ontology',
  mixins: [toastMixin, colorAndSymbolsMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Ontology',
    // all titles will be injected into this template
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en',
    },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content: 'This Ontology view shows specific information for a disease.',
      },
    ],
  },
  data() {
    return {
      ontology: [],
      ontology_fields: [
        {
          key: 'disease_ontology_id_version',
          label: 'Versions',
          sortable: true,
          class: 'text-left',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          class: 'text-left',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'DOID', label: 'DOID', sortable: true, class: 'text-left',
        },
        {
          key: 'MONDO', label: 'MONDO', sortable: true, class: 'text-left',
        },
        {
          key: 'Orphanet',
          label: 'Orphanet',
          sortable: true,
          class: 'text-left',
        },
      ],
      totalRows: 0,
      currentPage: 1,
      perPage: '10',
      pageOptions: ['10', '25', '50', '200'],
      sortBy: '',
      sortDesc: false,
      sortDirection: 'asc',
      loading: true,
    };
  },
  mounted() {
    this.loadOntologyInfo();
  },
  methods: {
    async loadOntologyInfo() {
      this.loading = true;
      console.log(this.$route.params.disease_term);
      const apiDiseaseOntologyURL = `${process.env.VUE_APP_API_URL
      }/api/ontology/${
        encodeURIComponent(this.$route.params.disease_term)
      }?input_type=ontology_id`;
      const apiDiseaseNameURL = `${process.env.VUE_APP_API_URL
      }/api/ontology/${
        encodeURIComponent(this.$route.params.disease_term)
      }?input_type=ontology_name`;

      try {
        const response_ontology = await this.axios.get(apiDiseaseOntologyURL);
        const response_name = await this.axios.get(apiDiseaseNameURL);

        if (
          response_ontology.data.length === 0
          && response_name.data.length === 0
        ) {
          this.$router.push('/PageNotFound');
        } else if (response_ontology.data === 0) {
          this.ontology = response_name.data;
        } else {
          this.ontology = response_ontology.data;
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
      this.loading = false;
    },
    // Function to truncate a string to a specified length.
    // If the string is longer than the specified length, it adds '...' to the end.
    // imported from utils.js
    truncate(str, n) {
      // Use the utility function here
      return Utils.truncate(str, n);
    },
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>

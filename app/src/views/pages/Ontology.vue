<!-- views/pages/Ontology.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BSpinner
      v-if="loading"
      label="Loading..."
      class="float-center m-5"
    />
    <BContainer
      v-else
      fluid
    >
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <!-- Ontology overview card -->
          <BCard
            header-tag="header"
            class="my-3 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-start font-weight-bold d-flex align-items-center gap-2">
                Disease:
                <DiseaseBadge
                  :name="$route.params.disease_term"
                  :link-to="'/Ontology/' + $route.params.disease_term"
                  :max-length="0"
                  size="lg"
                  :show-title="false"
                />
              </h3>
            </template>

            <BTable
              :items="ontology"
              :fields="ontology_fields"
              stacked
              small
              fixed
              style="width: 100%; white-space: nowrap"
            >
              <template #cell(disease_ontology_id_version)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.disease_ontology_id_version"
                    :key="id"
                  >
                    <BCol class="d-flex align-items-center flex-wrap gap-2 mb-1">
                      <DiseaseBadge
                        :name="id"
                        :link-to="'/Ontology/' + id.replace(/_.+/g, '')"
                        :max-length="0"
                        :show-title="false"
                      />

                      <BButton
                        class="btn-xs"
                        variant="outline-primary"
                        :src="data.item.disease_ontology_id_version"
                        :href="
                          'https://www.omim.org/entry/' +
                            id.replace(/OMIM:/g, '').replace(/_.+/g, '')
                        "
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(disease_ontology_name)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.disease_ontology_name"
                    :key="id"
                  >
                    <BCol>
                      <DiseaseBadge
                        :name="id"
                        :link-to="'/Ontology/' + id"
                        :max-length="50"
                      />
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <BRow>
                  <BRow
                    v-for="(id, index) in data.item.hpo_mode_of_inheritance_term_name"
                    :key="id"
                  >
                    <BCol>
                      <InheritanceBadge
                        v-if="id"
                        :full-name="id"
                        :hpo-term="Array.isArray(data.item.hpo_mode_of_inheritance_term) ? data.item.hpo_mode_of_inheritance_term[index] : data.item.hpo_mode_of_inheritance_term"
                        :use-abbreviation="false"
                        class="mb-1"
                      />
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(DOID)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.DOID"
                    :key="id"
                  >
                    <BCol>
                      <BButton
                        v-if="id"
                        class="btn-xs mx-2"
                        variant="outline-primary"
                        :src="id"
                        :href="'https://disease-ontology.org/term/' + id"
                        target="_blank"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(MONDO)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.MONDO"
                    :key="id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>

              <template #cell(Orphanet)="data">
                <BRow>
                  <BRow
                    v-for="id in data.item.Orphanet"
                    :key="id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>
          </BCard>
          <!-- Ontology overview card -->

          <!-- Associated entities card -->

          <TablesEntities
            v-if="ontology.length !== 0 && ontology[0].disease_ontology_id_version"
            :show-filter-controls="false"
            :show-pagination-controls="false"
            header-label="Associated "
            :filter-input="'any(disease_ontology_id_version,' +
              (Array.isArray(ontology[0].disease_ontology_id_version)
                ? ontology[0].disease_ontology_id_version.join(',')
                : ontology[0].disease_ontology_id_version) + ')'"
          />

          <!-- Associated entities card -->
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import { useToast, useColorAndSymbols } from '@/composables';

// Import the utilities file
import Utils from '@/assets/js/utils';

import TablesEntities from '@/components/tables/TablesEntities.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

export default {
  name: 'Ontology',
  components: {
    TablesEntities,
    DiseaseBadge,
    InheritanceBadge,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();

    useHead({
      title: 'Ontology',
      meta: [
        {
          name: 'description',
          content: 'This Ontology view shows specific information for a disease.',
        },
      ],
    });

    return {
      makeToast,
      ...colorAndSymbols,
    };
  },
  data() {
    return {
      ontology: [],
      ontology_fields: [
        {
          key: 'disease_ontology_id_version',
          label: 'Versions',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          sortable: true,
          class: 'text-start',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'hpo_mode_of_inheritance_term_name',
          label: 'Inheritance',
          sortable: true,
          class: 'text-start',
          sortByFormatted: true,
          filterByFormatted: true,
        },
        {
          key: 'DOID', label: 'DOID', sortable: true, class: 'text-start',
        },
        {
          key: 'MONDO', label: 'MONDO', sortable: true, class: 'text-start',
        },
        {
          key: 'Orphanet',
          label: 'Orphanet',
          sortable: true,
          class: 'text-start',
        },
      ],
      totalRows: 0,
      currentPage: 1,
      perPage: 10,
      pageOptions: [10, 25, 50, 200],
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
      const apiDiseaseOntologyURL = `${import.meta.env.VITE_API_URL
      }/api/ontology/${
        encodeURIComponent(this.$route.params.disease_term)
      }?input_type=ontology_id`;
      const apiDiseaseNameURL = `${import.meta.env.VITE_API_URL
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

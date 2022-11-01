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
          <!-- Entity overview card -->
          <b-card
            header-tag="header"
            class="my-3 text-left"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-left font-weight-bold">
                Entity:
                <b-badge variant="primary">
                  sysndd:{{ $route.params.entity_id }}
                </b-badge>
              </h3>
            </template>

            <b-table
              :items="entity"
              :fields="entity_fields"
              stacked
              small
              fixed
              style="width: 100%; white-space: nowrap"
            >
              <template #cell(symbol)="data">
                <div class="overflow-hidden text-truncate font-italic">
                  <b-link :href="'/Genes/' + data.item.hgnc_id">
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="success"
                      :title="data.item.hgnc_id"
                    >
                      {{ data.item.symbol }}
                    </b-badge>
                  </b-link>
                </div>
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-link
                    :href="
                      '/Ontology/' +
                        data.item.disease_ontology_id_version.replace(/_.+/g, '')
                    "
                  >
                    <b-badge
                      v-b-tooltip.hover.leftbottom
                      pill
                      variant="secondary"
                      :title="
                        data.item.disease_ontology_name +
                          '; ' +
                          data.item.disease_ontology_id_version
                      "
                    >
                      {{ data.item.disease_ontology_name }}
                    </b-badge>
                  </b-link>
                </div>

                <b-button
                  v-if="data.item.disease_ontology_id_version.includes('OMIM')"
                  class="btn-xs mx-2"
                  variant="outline-primary"
                  :href="
                    'https://www.omim.org/entry/' +
                      data.item.disease_ontology_id_version
                        .replace('OMIM:', '')
                        .replace(/_.+/g, '')
                  "
                  target="_blank"
                >
                  <b-icon
                    icon="box-arrow-up-right"
                    font-scale="0.8"
                  />
                  {{
                    data.item.disease_ontology_id_version.replace(/_.+/g, "")
                  }}
                </b-button>

                <b-button
                  v-if="data.item.disease_ontology_id_version.includes('MONDO')"
                  class="btn-xs mx-2"
                  variant="outline-primary"
                  :href="
                    'http://purl.obolibrary.org/obo/' +
                      data.item.disease_ontology_id_version.replace(':', '_')
                  "
                  target="_blank"
                >
                  <b-icon
                    icon="box-arrow-up-right"
                    font-scale="0.8"
                  />
                  {{ data.item.disease_ontology_id_version }}
                </b-button>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <div class="overflow-hidden text-truncate">
                  <b-badge
                    v-b-tooltip.hover.leftbottom
                    pill
                    variant="info"
                    class="justify-content-md-center"
                    size="1.3em"
                    :title="
                      data.item.hpo_mode_of_inheritance_term_name +
                        ' (' +
                        data.item.hpo_mode_of_inheritance_term +
                        ')'
                    "
                  >
                    {{
                      inheritance_short_text[
                        data.item.hpo_mode_of_inheritance_term_name
                      ]
                    }}
                  </b-badge>
                </div>
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <div>
                  <b-avatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    :icon="ndd_icon[data.item.ndd_phenotype_word]"
                    :variant="ndd_icon_style[data.item.ndd_phenotype_word]"
                    :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                  />
                </div>
              </template>
            </b-table>

            <b-table
              :items="status"
              :fields="status_fields"
              stacked
              small
            >
              <template #cell(category)="data">
                <div>
                  <b-avatar
                    v-b-tooltip.hover.left
                    size="1.4em"
                    icon="stoplights"
                    :variant="stoplights_style[data.item.category]"
                    :title="data.item.category"
                  />
                </div>
              </template>
            </b-table>

            <b-table
              :items="review"
              :fields="review_fields"
              stacked
              small
            >
              <template #cell(synopsis)="data">
                <b-card
                  border-variant="dark"
                  align="left"
                >
                  <b-card-text>
                    {{ data.item.synopsis }}
                  </b-card-text>
                </b-card>
              </template>
            </b-table>

            <b-table
              :items="publications_table"
              stacked
              small
            >
              <template #cell(publications)>
                <b-row>
                  <b-row
                    v-for="publication in publications"
                    :key="publication.publication_id"
                  >
                    <b-col>
                      <b-button
                        v-b-tooltip.hover.bottom
                        class="btn-xs mx-2"
                        :variant="publication_style[publication.publication_type]"
                        :href="
                          'https://pubmed.ncbi.nlm.nih.gov/' +
                            publication.publication_id.replace('PMID:', '')
                        "
                        target="_blank"
                        :title="publication_hover_text[publication.publication_type]"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ publication.publication_id }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>
            </b-table>

            <b-table
              :items="phenotypes_table"
              stacked
              small
            >
              <template #cell(phenotypes)>
                <b-row>
                  <b-row
                    v-for="phenotype in phenotypes"
                    :key="phenotype.phenotype_id"
                  >
                    <b-col>
                      <b-button
                        v-b-tooltip.hover.bottom
                        class="btn-xs mx-2"
                        :variant="modifier_style[phenotype.modifier_id]"
                        :href="
                          'https://hpo.jax.org/app/browse/term/' +
                            phenotype.phenotype_id
                        "
                        target="_blank"
                        :title="modifier_text[phenotype.modifier_id] + '; ' + phenotype.phenotype_id"
                      >
                        <b-icon
                          icon="box-arrow-up-right"
                          font-scale="0.8"
                        />
                        {{ phenotype.HPO_term }}
                      </b-button>
                    </b-col>
                  </b-row>
                </b-row>
              </template>
            </b-table>
          </b-card>
          <!-- Entity overview card -->
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

export default {
  name: 'Entity',
  mixins: [toastMixin, colorAndSymbolsMixin, textMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Entity',
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
        content: 'This Entity view shows specific information for an entity.',
      },
    ],
  },
  data() {
    return {
      entity: [],
      entity_fields: [
        {
          key: 'symbol',
          label: 'Gene Symbol',
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
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: true,
          class: 'text-left',
        },
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
      publications_table: [{ publications: '' }],
      phenotypes: [],
      phenotypes_table: [{ phenotypes: '' }],
      loading: true,
    };
  },
  mounted() {
    this.loadEntity();
  },
  methods: {
    async loadEntity() {
      this.loading = true;

      const apiEntityURL = `${process.env.VUE_APP_API_URL
      }/api/entity?filter=equals(entity_id,${
        this.$route.params.entity_id
      })`;

      try {
        const response_entity = await this.axios.get(apiEntityURL);
        this.entity = response_entity.data.data;

        if (this.entity.length === 0) {
          this.$router.push('/PageNotFound');
        } else {
          this.loadEntityInfo();
        }
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadEntityInfo() {
      const apiStatusURL = `${process.env.VUE_APP_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/status`;
      const apiReviewURL = `${process.env.VUE_APP_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/review`;
      const apiPublicationsURL = `${process.env.VUE_APP_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/publications`;
      const apiPhenotypesURL = `${process.env.VUE_APP_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/phenotypes`;

      try {
        const response_status = await this.axios.get(apiStatusURL);
        const response_review = await this.axios.get(apiReviewURL);
        const response_publications = await this.axios.get(apiPublicationsURL);
        const response_phenotypes = await this.axios.get(apiPhenotypesURL);

        this.status = response_status.data;
        this.review = response_review.data;
        this.publications = response_publications.data;
        this.phenotypes = response_phenotypes.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.loading = false;
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

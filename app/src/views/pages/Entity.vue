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
          <!-- Entity overview card -->
          <BCard
            header-tag="header"
            class="my-3 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-start font-weight-bold d-flex align-items-center gap-2">
                Entity:
                <EntityBadge
                  :entity-id="$route.params.entity_id"
                  :link-to="'/Entities/' + $route.params.entity_id"
                  size="lg"
                />
              </h3>
            </template>

            <BTable
              :items="entity"
              :fields="entity_fields"
              stacked
              small
              fixed
              style="width: 100%; white-space: nowrap"
            >
              <template #cell(symbol)="data">
                <GeneBadge
                  :symbol="data.item.symbol"
                  :hgnc-id="data.item.hgnc_id"
                  :link-to="'/Genes/' + data.item.hgnc_id"
                />
              </template>

              <template #cell(disease_ontology_name)="data">
                <div class="d-flex align-items-center flex-wrap gap-2">
                  <DiseaseBadge
                    :name="data.item.disease_ontology_name"
                    :ontology-id="data.item.disease_ontology_id_version"
                    :link-to="'/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')"
                    :max-length="0"
                  />

                  <BButton
                    v-if="data.item.disease_ontology_id_version.includes('OMIM')"
                    class="btn-xs"
                    variant="outline-primary"
                    :href="
                      'https://www.omim.org/entry/' +
                        data.item.disease_ontology_id_version
                          .replace('OMIM:', '')
                          .replace(/_.+/g, '')
                    "
                    target="_blank"
                  >
                    <i class="bi bi-box-arrow-up-right" />
                    {{
                      data.item.disease_ontology_id_version.replace(/_.+/g, "")
                    }}
                  </BButton>

                  <BButton
                    v-if="data.item.disease_ontology_id_version.includes('MONDO')"
                    class="btn-xs"
                    variant="outline-primary"
                    :href="
                      'http://purl.obolibrary.org/obo/' +
                        data.item.disease_ontology_id_version.replace(':', '_')
                    "
                    target="_blank"
                  >
                    <i class="bi bi-box-arrow-up-right" />
                    {{ data.item.disease_ontology_id_version }}
                  </BButton>
                </div>
              </template>

              <template #cell(hpo_mode_of_inheritance_term_name)="data">
                <InheritanceBadge
                  :full-name="data.item.hpo_mode_of_inheritance_term_name"
                  :hpo-term="data.item.hpo_mode_of_inheritance_term"
                />
              </template>

              <template #cell(ndd_phenotype_word)="data">
                <span v-b-tooltip.hover.left :title="ndd_icon_text[data.item.ndd_phenotype_word]">
                  <NddIcon :status="data.item.ndd_phenotype_word" :show-title="false" />
                </span>
              </template>
            </BTable>

            <BTable
              :items="status"
              :fields="status_fields"
              stacked
              small
            >
              <template #cell(category)="data">
                <span v-b-tooltip.hover.left :title="data.item.category">
                  <CategoryIcon :category="data.item.category" :show-title="false" />
                </span>
              </template>
            </BTable>

            <BTable
              :items="review"
              :fields="review_fields"
              stacked
              small
            >
              <template #cell(synopsis)="data">
                <BCard
                  border-variant="dark"
                  align="left"
                >
                  <BCardText>
                    {{ data.item.synopsis }}
                  </BCardText>
                </BCard>
              </template>
            </BTable>

            <BTable
              :items="publications_table"
              stacked
              small
            >
              <template #cell(publications)>
                <BRow>
                  <BRow
                    v-for="publication in publications"
                    :key="publication.publication_id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ publication.publication_id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>

            <BTable
              :items="genereviews_table"
              stacked
              small
            >
              <template #cell(genereviews)>
                <BRow>
                  <BRow
                    v-for="publication in genereviews"
                    :key="publication.publication_id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ publication.publication_id }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>

            <BTable
              :items="phenotypes_table"
              stacked
              small
            >
              <template #cell(phenotypes)>
                <BRow>
                  <BRow
                    v-for="phenotype in phenotypes"
                    :key="phenotype.phenotype_id"
                  >
                    <BCol>
                      <BButton
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
                        <i class="bi bi-box-arrow-up-right" />
                        {{ phenotype.HPO_term }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>

            <BTable
              :items="variation_table"
              stacked
              small
            >
              <template #cell(variation)>
                <BRow>
                  <BRow
                    v-for="variant in variation"
                    :key="variant.vario_id"
                  >
                    <BCol>
                      <BButton
                        v-b-tooltip.hover.bottom
                        class="btn-xs mx-2"
                        :variant="modifier_style[variant.modifier_id]"
                        :href="
                          'http://aber-owl.net/ontology/VARIO/#/Browse/%3Chttp%3A%2F%2Fpurl.obolibrary.org%2Fobo%2F' +
                            variant.vario_id.replace(':', '_') + '%3E'
                        "
                        target="_blank"
                        :title="modifier_text[variant.modifier_id] + '; ' + variant.vario_id"
                      >
                        <i class="bi bi-box-arrow-up-right" />
                        {{ variant.vario_name }}
                      </BButton>
                    </BCol>
                  </BRow>
                </BRow>
              </template>
            </BTable>
          </BCard>
          <!-- Entity overview card -->
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import { useToast, useColorAndSymbols, useText } from '@/composables';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

export default {
  name: 'Entity',
  components: {
    CategoryIcon,
    NddIcon,
    EntityBadge,
    GeneBadge,
    DiseaseBadge,
    InheritanceBadge,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();

    useHead({
      title: 'Entity',
      meta: [
        {
          name: 'description',
          content: 'This Entity view shows specific information for an entity.',
        },
      ],
    });

    return {
      makeToast,
      ...colorAndSymbols,
      ...text,
    };
  },
  data() {
    return {
      entity: [],
      entity_fields: [
        {
          key: 'symbol',
          label: 'Gene Symbol',
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
          key: 'ndd_phenotype_word',
          label: 'NDD',
          sortable: true,
          class: 'text-start',
        },
      ],
      status: [],
      status_fields: [
        { key: 'category', label: 'Association Category', class: 'text-start' },
      ],
      review: [],
      review_fields: [
        { key: 'synopsis', label: 'Clinical Synopsis', class: 'text-start' },
      ],
      publications: [],
      publications_table: [{ publications: '' }],
      genereviews: [],
      genereviews_table: [{ genereviews: '' }],
      phenotypes: [],
      phenotypes_table: [{ phenotypes: '' }],
      variation: [],
      variation_table: [{ variation: '' }],
      loading: true,
    };
  },
  mounted() {
    this.loadEntity();
  },
  methods: {
    async loadEntity() {
      this.loading = true;

      const apiEntityURL = `${import.meta.env.VITE_API_URL
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
      const apiStatusURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/status`;

      const apiReviewURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/review`;

      const apiPublicationsURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/publications`;

      const apiPhenotypesURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/phenotypes`;

      const apiVariationURL = `${import.meta.env.VITE_API_URL
      }/api/entity/${
        this.$route.params.entity_id
      }/variation`;

      try {
        const response_status = await this.axios.get(apiStatusURL);
        const response_review = await this.axios.get(apiReviewURL);
        const response_publications = await this.axios.get(apiPublicationsURL);
        const response_phenotypes = await this.axios.get(apiPhenotypesURL);
        const response_variation = await this.axios.get(apiVariationURL);

        this.status = response_status.data;
        this.review = response_review.data;
        this.publications = response_publications.data.filter((publication) => publication.publication_type === 'additional_references');
        this.genereviews = response_publications.data.filter((publication) => publication.publication_type === 'gene_review');
        this.phenotypes = response_phenotypes.data;
        this.variation = response_variation.data;
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

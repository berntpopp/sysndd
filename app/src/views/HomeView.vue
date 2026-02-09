<template>
  <div class="bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center">
        <BCol md="12">
          <BRow class="justify-content-md-center">
            <BCol md="8">
              <BContainer fluid="lg" class="py-3">
                <!-- This is the welcome message that users see when they visit the website. -->
                <h3 class="text-center font-weight-bold">Welcome to SysNDD,</h3>

                <h4 class="text-center">
                  the expert curated database of gene disease relationships in
                  <mark>neurodevelopmental</mark> <mark>disorders</mark> (NDD).
                </h4>
              </BContainer>

              <SearchCombobox
                placeholder-string="Search by genes, entities and diseases using names or identifiers"
                :in-navbar="false"
              />
            </BCol>
          </BRow>

          <BRow>
            <BCol md="6">
              <BCard
                header-tag="header"
                class="my-3 text-start"
                body-class="p-0"
                header-class="p-1"
                border-variant="dark"
              >
                <template #header>
                  <h5 class="mb-0 font-weight-bold">
                    Current database statistics, last update:
                    <transition name="fade" mode="out-in">
                      <span :key="last_update">
                        {{ last_update }}
                      </span>
                    </transition>
                  </h5>
                </template>

                <!-- first statistics table for entities -->
                <!-- This table displays statistics about the various entities in the database. -->
                <h5 class="mb-0 font-weight-bold mx-2">
                  <mark>Entities</mark>
                </h5>
                <BCardText class="text-start">
                  <!-- Each row in the table is generated from the data in `entity_statistics.data`. -->
                  <BTable
                    :items="entity_statistics.data"
                    :fields="statistics_fields"
                    stacked="lg"
                    head-variant="light"
                    show-empty
                    small
                  >
                    <template #cell(category)="data">
                      <div class="d-flex align-items-center gap-2">
                        <CategoryIcon :category="data.item.category" size="sm" />
                        {{ data.item.category }}
                      </div>
                    </template>

                    <template #cell(n)="data">
                      <BLink :href="'/Entities?filter=any(category,' + data.item.category + ')'">
                        <div style="cursor: pointer">
                          {{ data.item.n }}
                        </div>
                      </BLink>
                    </template>

                    <template #cell(actions)="row">
                      <BButton class="btn-xs" variant="outline-primary" @click="row.toggleDetails">
                        {{ row.detailsShowing ? 'hide' : 'show' }}
                      </BButton>
                    </template>

                    <!-- These are the details that appear when a row in the entities table is clicked. -->
                    <template #row-details="row">
                      <BCard>
                        <BTable
                          :items="row.item.groups"
                          :fields="statistics_details_fields"
                          head-variant="light"
                          show-empty
                          small
                          fixed
                          striped
                          sort-icon-left
                        >
                          <template #cell(inheritance)="data">
                            <div>
                              <BBadge
                                pill
                                variant="info"
                                class="justify-content-md-center px-1 mx-1"
                                size="1.3em"
                              >
                                {{ inheritance_overview_text[data.item.inheritance] }}
                              </BBadge>
                              {{ data.item.inheritance }}
                            </div>
                          </template>

                          <template #cell(n)="data">
                            <BLink
                              :href="
                                '/Entities?filter=any(category,' +
                                data.item.category +
                                '),any(hpo_mode_of_inheritance_term_name,' +
                                inheritance_link[data.item.inheritance].join(',') +
                                ')'
                              "
                            >
                              <div style="cursor: pointer">
                                {{ data.item.n }}
                              </div>
                            </BLink>
                          </template>
                        </BTable>
                      </BCard>
                    </template>
                  </BTable>
                </BCardText>
                <!-- first statistics table for entities -->

                <hr class="dashed" />

                <!-- second statistics table for genes -->
                <!-- This table displays statistics about the genes in the database. -->
                <h5 class="mb-0 font-weight-bold mx-2"><mark>Genes</mark> (links to Panels)</h5>
                <BCardText class="text-start">
                  <!-- Each row in the table is generated from the data in `gene_statistics.data`. -->
                  <BTable
                    :items="gene_statistics.data"
                    :fields="statistics_fields"
                    stacked="lg"
                    head-variant="light"
                    show-empty
                    small
                  >
                    <template #cell(category)="data">
                      <div class="d-flex align-items-center gap-2">
                        <CategoryIcon :category="data.item.category" size="sm" />
                        {{ data.item.category }}
                      </div>
                    </template>

                    <template #cell(n)="data">
                      <BLink :href="'/Panels/' + data.item.category + '/' + data.item.inheritance">
                        <div style="cursor: pointer">
                          {{ data.item.n }}
                        </div>
                      </BLink>
                    </template>

                    <template #cell(actions)="row">
                      <BButton class="btn-xs" variant="outline-primary" @click="row.toggleDetails">
                        {{ row.detailsShowing ? 'hide' : 'show' }}
                      </BButton>
                    </template>

                    <!-- These are the details that appear when a row in the genes table is clicked. -->
                    <template #row-details="row">
                      <BCard>
                        <BTable
                          :items="row.item.groups"
                          :fields="statistics_details_fields"
                          head-variant="light"
                          show-empty
                          small
                          fixed
                          striped
                          sort-icon-left
                        >
                          <template #cell(inheritance)="data">
                            <div>
                              <BBadge
                                pill
                                variant="info"
                                class="justify-content-md-center px-1 mx-1"
                                size="1.3em"
                              >
                                {{ inheritance_overview_text[data.item.inheritance] }}
                              </BBadge>
                              {{ data.item.inheritance }}
                            </div>
                          </template>

                          <template #cell(n)="data">
                            <BLink
                              :href="'/Panels/' + data.item.category + '/' + data.item.inheritance"
                            >
                              <div style="cursor: pointer">
                                {{ data.item.n }}
                              </div>
                            </BLink>
                          </template>
                        </BTable>
                      </BCard>
                    </template>
                  </BTable>
                </BCardText>
                <!-- second statistics table for genes -->
              </BCard>

              <BCard
                header-tag="header"
                class="my-3 text-start"
                body-class="p-0"
                header-class="p-1"
                border-variant="dark"
              >
                <template #header>
                  <!-- This section displays new entities added to the database. -->
                  <h5 class="mb-0 font-weight-bold">New entities</h5>
                </template>
                <transition name="fade" mode="out-in">
                  <BCardText class="text-start">
                    <BTable
                      :items="news"
                      :fields="news_fields"
                      stacked="lg"
                      head-variant="light"
                      show-empty
                      small
                      fixed
                      style="width: 100%; white-space: nowrap"
                    >
                      <template #table-colgroup="scope">
                        <col
                          v-for="field in scope.fields"
                          :key="field.key"
                          :style="{ width: field.width }"
                        />
                      </template>

                      <template #cell(entity_id)="data">
                        <EntityBadge
                          :entity-id="data.item.entity_id"
                          :link-to="'/Entities/' + data.item.entity_id"
                          :title="'Entry date: ' + data.item.entry_date"
                          size="sm"
                        />
                      </template>

                      <template #cell(symbol)="data">
                        <GeneBadge
                          :symbol="data.item.symbol"
                          :hgnc-id="data.item.hgnc_id"
                          :link-to="'/Genes/' + data.item.hgnc_id"
                          size="sm"
                        />
                      </template>

                      <template #cell(disease_ontology_name)="data">
                        <DiseaseBadge
                          :name="data.item.disease_ontology_name"
                          :ontology-id="data.item.disease_ontology_id_version"
                          :link-to="'/Ontology/' + data.item.disease_ontology_id_version"
                          :max-length="35"
                          size="sm"
                        />
                      </template>

                      <template #cell(inheritance_filter)="data">
                        <InheritanceBadge
                          :full-name="data.item.inheritance_filter"
                          :hpo-term="data.item.hpo_mode_of_inheritance_term"
                          size="sm"
                        />
                      </template>

                      <template #cell(category)="data">
                        <div v-b-tooltip.hover.left :title="data.item.category">
                          <CategoryIcon
                            :category="data.item.category"
                            size="sm"
                            :show-title="false"
                          />
                        </div>
                      </template>

                      <template #cell(ndd_phenotype_word)="data">
                        <div
                          v-b-tooltip.hover.left
                          :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                        >
                          <NddIcon
                            :status="data.item.ndd_phenotype_word"
                            size="sm"
                            :show-title="false"
                          />
                        </div>
                      </template>
                    </BTable>
                  </BCardText>
                </transition>
              </BCard>
            </BCol>

            <BCol md="6">
              <div class="container-fluid text-start py-2 my-3">
                <span class="word"
                  >NDD comprise <mark>developmental delay</mark> (DD),
                  <mark>intellectual disability</mark> (ID) and
                  <mark>autism spectrum disorder</mark> (ASD). </span
                ><br /><br />

                <span class="word"
                  >This clinically and genetically extremely <mark>heterogeneous</mark> disease
                  group affects <mark>about 2% of newborns</mark>. </span
                ><br /><br />

                <span class="word"
                  >SysNDD aims to empower clinical diagnostics, counseling and research for NDDs
                  through <mark>expert curation</mark>. </span
                ><br /><br />

                <span class="word"
                  >We define “gene-inheritance-disease” units as “<mark>entities</mark>”, </span
                ><br />
                <span class="word"
                  >which are color coded throughout the website:
                  <span class="entity-concept__container">
                    <span class="entity-concept__label">Entity:</span>
                    <GeneBadge symbol="Gene" :show-title="false" size="sm" />
                    <InheritanceBadge
                      full-name="Inheritance"
                      :show-title="false"
                      :use-abbreviation="false"
                      size="sm"
                    />
                    <DiseaseBadge name="Disease" :show-title="false" :max-length="0" size="sm" />
                  </span> </span
                ><br /><br />

                <span class="word"
                  >The clinical entities are divided into different “<mark>Categories</mark>”, based
                  on the strength of their association with NDD phenotypes. They are represented
                  using these differently colored stoplight symbols: </span
                ><br />
                <span class="word d-flex align-items-center flex-wrap gap-1">
                  Definitive:
                  <CategoryIcon category="Definitive" />
                  , Moderate:
                  <CategoryIcon category="Moderate" />
                  , Limited:
                  <CategoryIcon category="Limited" />
                  , Refuted:
                  <CategoryIcon category="Refuted" /> </span
                ><br />
                <span class="word"
                  >The classification criteria used for the categories are detailed in our
                  <BLink :href="DOCS_URLS.CURATION_CRITERIA" target="_blank"> Documentation </BLink>
                  on GitHub.<br />
                  In the <mark>Panel</mark> views, which are aggregated by gene, we assign the
                  highest category of associated entities to the gene. </span
                ><br /><br />

                <span class="word"
                  >The SysNDD tool allows browsing and download of tabular views for curated NDD
                  entity components in the <mark>Tables</mark> section. It offers multiple
                  <mark>Analyses</mark> sections for genes, phenotypes and comparisons with other
                  curation efforts. </span
                ><br />
              </div>
            </BCol>
          </BRow>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { gsap } from 'gsap';

import { useHead } from '@unhead/vue';
import { useToast, useColorAndSymbols, useText } from '@/composables';

// Import the utilities file
import Utils from '@/assets/js/utils';

// Importing initial objects from a constants file to avoid hardcoding them in this component
import INIT_OBJ from '@/assets/js/constants/init_obj_constants';

// Import documentation URLs from constants
import { DOCS_URLS } from '@/constants/docs';

// Import the apiService to make the API calls
import apiService from '@/assets/js/services/apiService';

// Import global components
import SearchCombobox from '@/components/small/SearchCombobox.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import NddIcon from '@/components/ui/NddIcon.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

export default {
  name: 'HomeView',
  components: {
    SearchCombobox,
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
      title: 'Home',
      meta: [
        {
          name: 'description',
          content:
            'The Home view shows current information about NDD (attention-deficit/hyperactivity disorder (ADHD), autism, learning disabilities, intellectual disability) entities .',
        },
        {
          name: 'keywords',
          content:
            'neurodevelopmental disorders, NDD, autism, ASD, learning disabilities, intellectual disability, ID, attention-deficit/hyperactivity disorder, ADHD',
        },
        { name: 'author', content: 'SysNDD database' },
      ],
    });

    return {
      makeToast,
      ...colorAndSymbols,
      ...text,
      DOCS_URLS,
    };
  },
  data() {
    return {
      search_input: '',
      search_keys: [],
      search_object: {},
      entity_statistics: INIT_OBJ.ENTITY_STAT_INIT,
      gene_statistics: INIT_OBJ.GENE_STAT_INIT,
      statistics_fields: [
        { key: 'category', label: 'Category', class: 'text-start' },
        { key: 'n', label: 'Count', class: 'text-start' },
        { key: 'actions', label: 'Details' },
      ],
      statistics_details_fields: [
        { key: 'inheritance', label: 'Inheritance' },
        { key: 'n', label: 'Count', class: 'text-start' },
      ],
      news: INIT_OBJ.NEWS_INIT,
      news_fields: [
        {
          key: 'entity_id',
          label: 'Entity',
          class: 'text-start',
          width: '20%',
        },
        {
          key: 'symbol',
          label: 'Symbol',
          class: 'text-start',
          width: '15%',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          class: 'text-start',
          width: '30%',
        },
        {
          key: 'inheritance_filter',
          label: 'Inh.',
          class: 'text-start',
          width: '10%',
        },
        {
          key: 'category',
          label: 'Category',
          class: 'text-start',
          width: '15%',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          class: 'text-start',
          width: '10%',
        },
      ],
      loadingStates: {
        statistics: false,
        news: false,
      },
    };
  },
  computed: {
    last_update() {
      // If entity_statistics does not exist, return a default message
      if (!this.entity_statistics) {
        return 'Data not available';
      }

      const date_last_update = new Date(this.entity_statistics.meta[0].last_update);
      return date_last_update.toLocaleDateString();
    },
  },
  watch: {
    'entity_statistics.data': {
      handler(after, before) {
        this.animateOnChange(after, before);
      },
      deep: true,
    },
    'gene_statistics.data': {
      handler(after, before) {
        this.animateOnChange(after, before);
      },
      deep: true,
    },
  },
  created() {
    // watch the params of the route to fetch the data again
    this.$watch(
      () => this.$route.params,
      () => {
        this.loadStatistics();
        this.loadNews();
      },
      // fetch the data when the view is created and the data is
      // already being observed
      { immediate: true }
    );
  },
  methods: {
    // Function to animate changes in data.
    // This uses the GSAP library to create a transition effect.
    animateOnChange(after, before) {
      for (let i = 0; i < after.length; i += 1) {
        if (before[i].n !== after[i].n) {
          gsap.fromTo(
            after[i],
            {
              n: before[i].n,
            },
            {
              duration: 1.0,
              n: after[i].n,
              onUpdate: () => {
                after[i].n = Math.round(after[i].n);
                this.$forceUpdate();
              },
            }
          );
        }
      }
    },
    // Function to load statistical data from the API.
    // The function sets a loading flag, makes the API request,
    // and then clears the loading flag when complete.
    async loadStatistics() {
      this.loadingStates.statistics = true;
      try {
        // use the functions from apiService asset to make calls to the API
        this.entity_statistics = await apiService.fetchStatistics('entity');
        this.gene_statistics = await apiService.fetchStatistics('gene');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingStates.statistics = false;
      }
    },
    // Function to load news data from the API.
    // The function sets a loading flag, makes the API request,
    // and then clears the loading flag when complete.
    async loadNews() {
      this.loadingStates.news = true;
      try {
        // use the functions from apiService asset to make calls to the API
        this.news = await apiService.fetchNews(5);
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingStates.news = false;
      }
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
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
hr.dashed {
  border-top: 2px dashed #999;
}
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s;
}
.fade-enter,
.fade-leave-to {
  opacity: 0;
}
/* Entity concept visual explanation */
.entity-concept__container {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.3rem 0.5rem;
  border-radius: 1rem;
  background: linear-gradient(145deg, #0d6efd 0%, #0a58ca 100%);
  border: 1.5px solid #084298;
  box-shadow:
    0 2px 4px rgba(0, 0, 0, 0.15),
    inset 0 1px 2px rgba(255, 255, 255, 0.2);
}
.entity-concept__label {
  color: white;
  font-weight: 600;
  font-size: 0.75rem;
  text-shadow: 0 1px 1px rgba(0, 0, 0, 0.2);
}
</style>

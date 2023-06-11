<template>
  <div class="bg-gradient">
    <b-container fluid>
      <b-row class="justify-content-md-center">
        <b-col md="12">
          <b-row class="justify-content-md-center">
            <b-col md="8">
              <b-container
                fluid="lg"
                class="py-3"
              >
                <h3 class="text-center font-weight-bold">
                  Welcome to SysNDD,
                </h3>

                <h4 class="text-center">
                  the expert curated database of gene disease relationships in
                  <mark>neurodevelopmental</mark> <mark>disorders</mark> (NDD).
                </h4>
              </b-container>

              <b-input-group class="mb-2 p-2">
                <b-form-input
                  v-model="search_input"
                  autofocus
                  class="border-dark"
                  list="search-list"
                  type="search"
                  placeholder="Search by genes, entities and diseases using names or identifiers"
                  size="md"
                  autocomplete="off"
                  debounce="300"
                  @update="loadSearchInfo"
                  @keydown.native="handleSearchInputKeydown"
                />

                <b-form-datalist
                  id="search-list"
                  :options="search_keys"
                />

                <b-input-group-append>
                  <b-button
                    variant="outline-dark"
                    size="md"
                    :disabled="search_input.length < 2"
                    @click="handleSearchInputKeydown"
                  >
                    <b-icon icon="search" />
                  </b-button>
                </b-input-group-append>
              </b-input-group>
            </b-col>
          </b-row>

          <b-row>
            <b-col md="6">
              <b-card
                header-tag="header"
                class="my-3 text-left"
                body-class="p-0"
                header-class="p-1"
                border-variant="dark"
              >
                <template #header>
                  <h5 class="mb-0 font-weight-bold">
                    Current database statistics, last update:
                    <transition
                      name="fade"
                      mode="out-in"
                    >
                      <span :key="last_update">
                        {{ last_update }}
                      </span>
                    </transition>
                  </h5>
                </template>

                <!-- first statistics table for entities -->
                <h5 class="mb-0 font-weight-bold mx-2">
                  <mark>Entities</mark>
                </h5>
                <b-card-text class="text-left">
                  <b-table
                    :items="entity_statistics.data"
                    :fields="statistics_fields"
                    stacked="lg"
                    head-variant="light"
                    show-empty
                    small
                  >
                    <template #cell(category)="data">
                      <div>
                        <b-avatar
                          size="1.4em"
                          icon="stoplights"
                          :variant="stoplights_style[data.item.category]"
                        />
                        {{ data.item.category }}
                      </div>
                    </template>

                    <template #cell(n)="data">
                      <b-link
                        :href="
                          '/Entities?filter=any(category,' +
                            data.item.category +
                            ')'
                        "
                      >
                        <div style="cursor: pointer">
                          {{ data.item.n }}
                        </div>
                      </b-link>
                    </template>

                    <template #cell(actions)="row">
                      <b-button
                        class="btn-xs"
                        variant="outline-primary"
                        @click="row.toggleDetails"
                      >
                        {{ row.detailsShowing ? "hide" : "show" }}
                      </b-button>
                    </template>

                    <template #row-details="row">
                      <b-card>
                        <b-table
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
                              <b-badge
                                pill
                                variant="info"
                                class="justify-content-md-center px-1 mx-1"
                                size="1.3em"
                              >
                                {{
                                  inheritance_overview_text[
                                    data.item.inheritance
                                  ]
                                }}
                              </b-badge>
                              {{ data.item.inheritance }}
                            </div>
                          </template>

                          <template #cell(n)="data">
                            <b-link
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
                            </b-link>
                          </template>
                        </b-table>
                      </b-card>
                    </template>
                  </b-table>
                </b-card-text>
                <!-- first statistics table for entities -->

                <hr class="dashed">

                <!-- second statistics table for genes -->
                <h5 class="mb-0 font-weight-bold mx-2">
                  <mark>Genes</mark> (links to Panels)
                </h5>
                <b-card-text class="text-left">
                  <b-table
                    :items="gene_statistics.data"
                    :fields="statistics_fields"
                    stacked="lg"
                    head-variant="light"
                    show-empty
                    small
                  >
                    <template #cell(category)="data">
                      <div>
                        <b-avatar
                          size="1.4em"
                          icon="stoplights"
                          :variant="stoplights_style[data.item.category]"
                        />
                        {{ data.item.category }}
                      </div>
                    </template>

                    <template #cell(n)="data">
                      <b-link
                        :href="
                          '/Panels/' +
                            data.item.category +
                            '/' +
                            data.item.inheritance
                        "
                      >
                        <div style="cursor: pointer">
                          {{ data.item.n }}
                        </div>
                      </b-link>
                    </template>

                    <template #cell(actions)="row">
                      <b-button
                        class="btn-xs"
                        variant="outline-primary"
                        @click="row.toggleDetails"
                      >
                        {{ row.detailsShowing ? "hide" : "show" }}
                      </b-button>
                    </template>

                    <template #row-details="row">
                      <b-card>
                        <b-table
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
                              <b-badge
                                pill
                                variant="info"
                                class="justify-content-md-center px-1 mx-1"
                                size="1.3em"
                              >
                                {{
                                  inheritance_overview_text[
                                    data.item.inheritance
                                  ]
                                }}
                              </b-badge>
                              {{ data.item.inheritance }}
                            </div>
                          </template>

                          <template #cell(n)="data">
                            <b-link
                              :href="
                                '/Panels/' +
                                  data.item.category +
                                  '/' +
                                  data.item.inheritance
                              "
                            >
                              <div style="cursor: pointer">
                                {{ data.item.n }}
                              </div>
                            </b-link>
                          </template>
                        </b-table>
                      </b-card>
                    </template>
                  </b-table>
                </b-card-text>
                <!-- second statistics table for genes -->
              </b-card>

              <b-card
                header-tag="header"
                class="my-3 text-left"
                body-class="p-0"
                header-class="p-1"
                border-variant="dark"
              >
                <template #header>
                  <h5 class="mb-0 font-weight-bold">
                    New entities
                  </h5>
                </template>
                <transition
                  name="fade"
                  mode="out-in"
                >
                  <b-card-text class="text-left">
                    <b-table
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
                        >
                      </template>

                      <template #cell(entity_id)="data">
                        <div>
                          <b-link :href="'/Entities/' + data.item.entity_id">
                            <b-badge
                              v-b-tooltip.hover.rightbottom
                              variant="primary"
                              style="cursor: pointer"
                              :title="'Entry date: ' + data.item.entry_date"
                            >
                              sysndd:{{ data.item.entity_id }}
                            </b-badge>
                          </b-link>
                        </div>
                      </template>

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
                                data.item.disease_ontology_id_version
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
                              {{
                                truncate(data.item.disease_ontology_name, 40)
                              }}
                            </b-badge>
                          </b-link>
                        </div>
                      </template>

                      <template #cell(inheritance_filter)="data">
                        <div>
                          <b-badge
                            v-b-tooltip.hover.leftbottom
                            pill
                            variant="info"
                            class="justify-content-md-center px-1 mx-1"
                            size="1.3em"
                            :title="
                              data.item.inheritance_filter +
                                ' (' +
                                data.item.hpo_mode_of_inheritance_term +
                                ')'
                            "
                          >
                            {{
                              inheritance_overview_text[
                                data.item.inheritance_filter
                              ]
                            }}
                          </b-badge>
                        </div>
                      </template>

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

                      <template #cell(ndd_phenotype_word)="data">
                        <div>
                          <b-avatar
                            v-b-tooltip.hover.left
                            size="1.4em"
                            :icon="ndd_icon[data.item.ndd_phenotype_word]"
                            :variant="
                              ndd_icon_style[data.item.ndd_phenotype_word]
                            "
                            :title="ndd_icon_text[data.item.ndd_phenotype_word]"
                          />
                        </div>
                      </template>
                    </b-table>
                  </b-card-text>
                </transition>
              </b-card>
            </b-col>

            <b-col md="6">
              <div class="container-fluid text-left py-2 my-3">
                <span
                  class="word"
                >NDD comprise <mark>developmental delay</mark> (DD),
                  <mark>intellectual disability</mark> (ID) and
                  <mark>autism spectrum disorder</mark> (ASD). </span><br><br>

                <span
                  class="word"
                >This clinically and genetically extremely
                  <mark>heterogeneous</mark> disease group affects
                  <mark>about 2% of newborns</mark>. </span><br><br>

                <span
                  class="word"
                >SysNDD aims to empower clinical diagnostics, counseling and
                  research for NDDs through <mark>expert curation</mark>. </span><br><br>

                <span
                  class="word"
                >We define “gene-inheritance-disease” units as
                  “<mark>entities</mark>”, </span><br>
                <span
                  class="word"
                >which are color coded throughout the website:
                  <b-badge
                    variant="primary"
                  >Entity:
                    <b-badge
                      pill
                      variant="success"
                    >Gene</b-badge>
                    <b-badge
                      pill
                      variant="info"
                    >Inheritance</b-badge>
                    <b-badge
                      pill
                      variant="secondary"
                    >Disease</b-badge>
                  </b-badge> </span><br><br>

                <span
                  class="word"
                >The clinical entities are divided into different
                  “<mark>Categories</mark>”, based on the strength of their
                  association with NDD phenotypes. They are represented using
                  these differently colored stoplight symbols: </span><br>
                <span class="word">
                  Definitive:
                  <b-avatar
                    size="1.4em"
                    icon="stoplights"
                    :variant="stoplights_style['Definitive']"
                  />
                  , Moderate:
                  <b-avatar
                    size="1.4em"
                    icon="stoplights"
                    :variant="stoplights_style['Moderate']"
                  />
                  , Limited:
                  <b-avatar
                    size="1.4em"
                    icon="stoplights"
                    :variant="stoplights_style['Limited']"
                  />
                  , Refuted:
                  <b-avatar
                    size="1.4em"
                    icon="stoplights"
                    :variant="stoplights_style['Refuted']"
                  /> </span><br>
                <span
                  class="word"
                >The classification criteria used for the categories are
                  detailed in our
                  <b-link
                    href="https://berntpopp.github.io/sysndd/curation-criteria.html"
                    target="_blank"
                  >
                    Documentation
                  </b-link>
                  on GitHub.<br>
                  In the <mark>Panel</mark> views, which are aggregated by gene,
                  we assign the highest category of associated entities to the
                  gene. </span><br><br>

                <span
                  class="word"
                >The SysNDD tool allows browsing and download of tabular views
                  for curated NDD entity components in the
                  <mark>Tables</mark> section. It offers multiple
                  <mark>Analyses</mark> sections for genes, phenotypes and
                  comparisons with other curation efforts. </span><br>
              </div>
            </b-col>
          </b-row>
        </b-col>
      </b-row>
    </b-container>

    <b-alert
      class="position-fixed fixed-bottom m-0 rounded-0 text-left"
      style="z-index: 2000; font-size: 0.8rem"
      variant="danger"
      :show="!banner_acknowledged"
    >
      <b-row>
        <b-col md="1">
          <b-icon
            icon="exclamation-triangle"
            font-scale="2.0"
          />
        </b-col>
        <b-col md="10">
          <h6 class="alert-heading">
            Usage policy
          </h6>
          The information on this website is not intended for direct diagnostic
          use or medical decision-making without review by a genetics
          professional. Individuals should not change their health behavior on
          the basis of information contained on this website. SysNDD does not
          independently verify the information gathered from external sources.
          If you have questions about specific gene-disease claims, please
          contact the respective primary sources. If you have questions about
          the representation of the data on this website, please contact support
          [at] sysndd.org.<br><br>

          <h6 class="alert-heading">
            Data privacy
          </h6>
          The SysNDD website does not use cookies and tries to be completely
          stateless for regular users. Our parent domain unibe.ch uses cookies
          which we do not control (<b-link
            href="https://www.unibe.ch/legal_notice/index_eng.html"
            target="_blank"
          >
            see legal notice here
          </b-link>). Server side programs keep error logs to improve SysNDD. These are
          deleted regularly.
        </b-col>
        <b-col md="1">
          <b-button
            variant="outline-dark"
            size="sm"
            @click="acknowledgeBanner()"
          >
            Dismiss
          </b-button>
        </b-col>
      </b-row>
    </b-alert>
  </div>
</template>

<script>
import { gsap } from 'gsap';

import toastMixin from '@/assets/js/mixins/toastMixin';
import colorAndSymbolsMixin from '@/assets/js/mixins/colorAndSymbolsMixin';
import textMixin from '@/assets/js/mixins/textMixin';

// Importing initial objects from a constants file to avoid hardcoding them in this component
import INIT_OBJ from '@/assets/js/constants/init_obj_constants';

export default {
  name: 'Home',
  mixins: [toastMixin, colorAndSymbolsMixin, textMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Home',
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
        content:
          'The Home view shows current information about NDD (attention-deficit/hyperactivity disorder (ADHD), autism, learning disabilities, intellectual disability) entities .',
      },
      {
        vmid: 'keywords',
        name: 'keywords',
        content:
          'neurodevelopmental disorders, NDD, autism, ASD, learning disabilities, intellectual disability, ID, attention-deficit/hyperactivity disorder, ADHD',
      },
      { vmid: 'author', name: 'author', content: 'SysNDD database' },
    ],
  },
  data() {
    return {
      search_input: '',
      search_keys: [],
      search_object: {},
      entity_statistics: INIT_OBJ.ENTITY_STAT_INIT,
      gene_statistics: INIT_OBJ.GENE_STAT_INIT,
      statistics_fields: [
        { key: 'category', label: 'Category', class: 'text-left' },
        { key: 'n', label: 'Count', class: 'text-left' },
        { key: 'actions', label: 'Details' },
      ],
      statistics_details_fields: [
        { key: 'inheritance', label: 'Inheritance' },
        { key: 'n', label: 'Count', class: 'text-left' },
      ],
      news: INIT_OBJ.NEWS_INIT,
      news_fields: [
        {
          key: 'entity_id',
          label: 'Entity',
          class: 'text-left',
          width: '20%',
        },
        {
          key: 'symbol',
          label: 'Symbol',
          class: 'text-left',
          width: '15%',
        },
        {
          key: 'disease_ontology_name',
          label: 'Disease',
          class: 'text-left',
          width: '30%',
        },
        {
          key: 'inheritance_filter',
          label: 'Inh.',
          class: 'text-left',
          width: '10%',
        },
        {
          key: 'category',
          label: 'Category',
          class: 'text-left',
          width: '15%',
        },
        {
          key: 'ndd_phenotype_word',
          label: 'NDD',
          class: 'text-left',
          width: '10%',
        },
      ],
      loading: false,
      loading_statistics: true,
      loading_news: true,
      banner_acknowledged: false,
    };
  },
  computed: {
    last_update() {
      if (this.entity_statistics) {
        const date_last_update = new Date(this.entity_statistics.meta[0].last_update);
        return date_last_update.toLocaleDateString();
      }
      return null;
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
  mounted() {
    this.checkBanner();
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
      { immediate: true },
    );
  },
  methods: {
    checkBanner() {
      this.banner_acknowledged = localStorage.getItem('banner_acknowledged');
    },
    acknowledgeBanner() {
      localStorage.setItem('banner_acknowledged', true);
      this.banner_acknowledged = localStorage.getItem('banner_acknowledged');
    },
    animateOnChange(after, before) {
      for (let i = 0; i < after.length; i += 1) {
        if (before[i].n !== after[i].n) {
          gsap.fromTo(after[i], {
            n: before[i].n,
          }, {
            duration: 1.0,
            n: after[i].n,
            onUpdate: () => {
              after[i].n = Math.round(after[i].n);
              this.$forceUpdate();
            },
          });
        }
      }
    },
    async loadStatistics() {
      this.loading_statistics = true;

      const apiStatisticsGenesURL = `${process.env.VUE_APP_API_URL}/api/statistics/category_count?type=gene`;

      const apiStatisticsEntityURL = `${process.env.VUE_APP_API_URL}/api/statistics/category_count?type=entity`;

      try {
        const response_statistics_gene = await this.axios.get(
          apiStatisticsGenesURL,
        );

        const response_statistics_entity = await this.axios.get(
          apiStatisticsEntityURL,
        );

        this.gene_statistics = response_statistics_gene.data;

        this.entity_statistics = response_statistics_entity.data;

        this.loading_statistics = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadNews() {
      this.loading_news = true;

      const apiNewsURL = `${process.env.VUE_APP_API_URL}/api/statistics/news?n=5`;

      try {
        const response_news = await this.axios.get(apiNewsURL);

        this.news = response_news.data;

        this.loading_news = false;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }
    },
    async loadSearchInfo() {
      if (this.search_input.length > 0) {
        const apiSearchURL = `${process.env.VUE_APP_API_URL
        }/api/search/${
          this.search_input
        }?helper=true`;
        try {
          const response_search = await this.axios.get(apiSearchURL);
          let rest;
          [this.search_object, ...rest] = response_search.data;
          this.search_keys = Object.keys(response_search.data[0]);
        } catch (e) {
          this.makeToast(e, 'Error', 'danger');
        }
      }
    },
    handleSearchInputKeydown(event) {
      if (
        ((event.key === 'Enter') || (event.which === 1))
        && (this.search_input.length > 0)
        && !(this.search_object[this.search_input] === undefined)
      ) {
        this.$router.push(this.search_object[this.search_input][0].link);
        this.search_input = '';
        this.search_keys = [];
      } else if (
        ((event.key === 'Enter') || (event.which === 1))
        && (this.search_input.length > 0)
        && (this.search_object[this.search_input] === undefined)
      ) {
        this.$router.push(`/Search/${this.search_input}`);
        this.search_input = '';
        this.search_keys = [];
      }
    },
    truncate(str, n) {
      return str.length > n ? `${str.substr(0, n - 1)}...` : str;
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
.fade-enter-active, .fade-leave-active {
  transition: opacity .2s;
}
.fade-enter, .fade-leave-to {
  opacity: 0;
}
</style>

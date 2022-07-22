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
          md="8"
        >
          <!-- Gene overview card -->
          <b-card
            header-tag="header"
            class="my-3 text-left"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-left font-weight-bold">
                Top results for your search term:
                <b-badge variant="dark">
                  {{ $route.params.search_term }}
                </b-badge>
              </h3>
            </template>

            <b-table
              :items="search"
              :fields="search_fields"
              small
            >
              <template #cell(results)="data">
                <b-link :href="data.item.link">
                  <div>
                    <b-badge
                      :variant="result_variant[data.item.search]"
                      style="cursor: pointer"
                    >
                      {{ data.item.results }}
                    </b-badge>
                  </div>
                </b-link>
              </template>

              <template #cell(entity_id)="data">
                <div>
                  <b-link :href="'/Entities/' + data.item.entity_id">
                    <b-badge
                      variant="primary"
                      style="cursor: pointer"
                    >
                      sysndd:{{ data.item.entity_id }}
                    </b-badge>
                  </b-link>
                </div>
              </template>
            </b-table>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'Search',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Search',
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
          'The Search table shows results of database searches and their similarity when no exact terms was identified.',
      },
      { vmid: 'robots', name: 'robots', content: 'noindex' },
    ],
  },
  data() {
    return {
      result_variant: {
        entity_id: 'primary',
        symbol: 'success',
        disease_ontology_id_version: 'secondary',
        disease_ontology_name: 'secondary',
      },
      search: [],
      search_fields: [
        { key: 'results', label: 'Results', class: 'text-left' },
        { key: 'search', label: 'Search', class: 'text-left' },
        { key: 'entity_id', label: 'Entity', class: 'text-left' },
        { key: 'searchdist', label: 'Searchdist', class: 'text-left' },
      ],
      loading: true,
    };
  },
  mounted() {
    this.loadSearchInfo();
  },
  created() {
    // watch the params of the route to fetch the data again
    this.$watch(
      () => this.$route.params,
      () => {
        this.loadSearchInfo();
      },
      // fetch the data when the view is created and the data is
      // already being observed
      { immediate: true },
    );
  },
  methods: {
    async loadSearchInfo() {
      this.loading = true;
      const apiSearchURL = `${process.env.VUE_APP_API_URL
      }/api/search/${
        this.$route.params.search_term
      }?helper=false`;
      try {
        const response_search = await this.axios.get(apiSearchURL);

        this.search = response_search.data;
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      if (this.search.length === 1) {
        this.$router.push(this.search[0].link);
      } else {
        this.loading = false;
        this.formatedItems();
      }
    },
    formatedItems() {
      if (!this.search) return [];
      return this.search.map((item) => {
        item._rowVariant = this.getVariant(item.searchdist);
        return item;
      });
    },
    getVariant(searchdist) {
      if (searchdist <= 0.05) {
        return 'success';
      } if (searchdist < 0.1) {
        return 'warning';
      }
      return 'danger';
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

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
          md="8"
        >
          <!-- Gene overview card -->
          <BCard
            header-tag="header"
            class="my-3 text-start"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <h3 class="mb-1 text-start font-weight-bold">
                Top results for your search term:
                <BBadge variant="dark">
                  {{ $route.params.search_term }}
                </BBadge>
              </h3>
            </template>

            <BTable
              :items="search"
              :fields="search_fields"
              small
            >
              <template #cell(results)="data">
                <BLink :href="data.item.link">
                  <div>
                    <BBadge
                      :variant="result_variant[data.item.search]"
                      style="cursor: pointer"
                    >
                      {{ data.item.results }}
                    </BBadge>
                  </div>
                </BLink>
              </template>

              <template #cell(entity_id)="data">
                <EntityBadge
                  :entity-id="data.item.entity_id"
                  :link-to="'/Entities/' + data.item.entity_id"
                  size="sm"
                />
              </template>
            </BTable>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import EntityBadge from '@/components/ui/EntityBadge.vue';

export default {
  name: 'Search',
  components: {
    EntityBadge,
  },
  setup() {
    const { makeToast } = useToast();
    useHead({
      title: 'Search',
      meta: [
        {
          name: 'description',
          content:
            'The Search table shows results of database searches and their similarity when no exact terms was identified.',
        },
      ],
    });

    return { makeToast };
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
        { key: 'results', label: 'Results', class: 'text-start' },
        { key: 'search', label: 'Search', class: 'text-start' },
        { key: 'entity_id', label: 'Entity', class: 'text-start' },
        { key: 'searchdist', label: 'Searchdist', class: 'text-start' },
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
      const apiSearchURL = `${import.meta.env.VITE_API_URL
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
        this.$router.push(this.search[0].link).catch(() => {});
      } else {
        this.loading = false;
        this.formattedItems();
      }
    },
    formattedItems() {
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

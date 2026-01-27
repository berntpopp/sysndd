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
          <!-- Search results card -->
          <div class="search-results-card my-3">
            <div class="search-results-header">
              <div class="search-results-header__content">
                <i class="bi bi-search search-results-header__icon" aria-hidden="true" />
                <div>
                  <h3 class="search-results-header__title">
                    Search Results
                  </h3>
                  <p class="search-results-header__subtitle">
                    Top matches for
                    <span class="search-results-header__term">{{ $route.params.search_term }}</span>
                    <span class="search-results-header__count">&middot; {{ search.length }} results</span>
                  </p>
                </div>
              </div>
            </div>

            <div class="search-results-body">
              <table
                class="search-results-table"
                role="table"
                aria-label="Search results"
              >
                <thead>
                  <tr>
                    <th class="search-results-table__th">
                      Match
                    </th>
                    <th class="search-results-table__th">
                      Type
                    </th>
                    <th class="search-results-table__th">
                      Entity
                    </th>
                    <th class="search-results-table__th search-results-table__th--relevance">
                      Relevance
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    v-for="(item, index) in search"
                    :key="index"
                    class="search-results-table__row"
                    @click="navigateTo(item.link)"
                  >
                    <td class="search-results-table__td">
                      <BLink
                        :href="item.link"
                        class="search-results-table__match-link"
                        @click.stop
                      >
                        <BBadge
                          :variant="result_variant[item.search]"
                          class="search-results-table__match-badge"
                        >
                          {{ item.results }}
                        </BBadge>
                      </BLink>
                    </td>
                    <td class="search-results-table__td">
                      <span class="search-type-label">
                        <i
                          :class="typeIcon(item.search)"
                          class="search-type-label__icon"
                          aria-hidden="true"
                        />
                        {{ typeLabel(item.search) }}
                      </span>
                    </td>
                    <td class="search-results-table__td">
                      <EntityBadge
                        :entity-id="item.entity_id"
                        :link-to="'/Entities/' + item.entity_id"
                        size="sm"
                      />
                    </td>
                    <td class="search-results-table__td search-results-table__td--relevance">
                      <div
                        class="relevance-indicator-wrapper"
                        :data-score="'Score: ' + (1 - item.searchdist).toFixed(2) + ' · Distance: ' + item.searchdist"
                      >
                        <div class="relevance-indicator">
                          <div
                            class="relevance-indicator__bar"
                            :class="'relevance-indicator__bar--' + relevanceLevel(item.searchdist)"
                            :style="{ width: relevancePercent(item.searchdist) + '%' }"
                          />
                        </div>
                        <span
                          class="relevance-indicator__label"
                          :class="'relevance-indicator__label--' + relevanceLevel(item.searchdist)"
                        >
                          {{ relevanceText(item.searchdist) }}
                        </span>
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
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
  name: 'SearchView',
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
      }
    },
    navigateTo(link) {
      this.$router.push(link).catch(() => {});
    },
    typeLabel(searchType) {
      const labels = {
        symbol: 'Gene Symbol',
        entity_id: 'Entity ID',
        disease_ontology_id_version: 'Disease ID',
        disease_ontology_name: 'Disease Name',
      };
      return labels[searchType] || searchType;
    },
    typeIcon(searchType) {
      const icons = {
        symbol: 'bi bi-dna',
        entity_id: 'bi bi-tag',
        disease_ontology_id_version: 'bi bi-bookmark',
        disease_ontology_name: 'bi bi-file-medical',
      };
      return icons[searchType] || 'bi bi-search';
    },
    relevanceLevel(searchdist) {
      if (searchdist <= 0.05) return 'excellent';
      if (searchdist < 0.1) return 'good';
      if (searchdist < 0.2) return 'fair';
      return 'low';
    },
    relevancePercent(searchdist) {
      // Map distance 0..0.3 → bar width 100..10%
      const pct = Math.max(10, Math.round((1 - searchdist / 0.3) * 100));
      return Math.min(100, pct);
    },
    relevanceText(searchdist) {
      if (searchdist <= 0.05) return 'Excellent';
      if (searchdist < 0.1) return 'Good';
      if (searchdist < 0.2) return 'Fair';
      return 'Partial';
    },
  },
};
</script>

<style scoped>
/* ── Card container ──────────────────────────────────────────── */
.search-results-card {
  background: #fff;
  border-radius: 0.75rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08), 0 4px 12px rgba(0, 0, 0, 0.04);
  overflow: hidden;
  border: 1px solid var(--neutral-200, #eeeeee);
}

/* ── Header ──────────────────────────────────────────────────── */
.search-results-header {
  padding: 1.25rem 1.5rem;
  background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
  border-bottom: 1px solid var(--neutral-200, #e0e0e0);
}

.search-results-header__content {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.search-results-header__icon {
  font-size: 1.75rem;
  color: var(--medical-blue-600, #1565c0);
  opacity: 0.8;
}

.search-results-header__title {
  font-size: 1.25rem;
  font-weight: 700;
  margin: 0;
  color: var(--neutral-900, #212121);
}

.search-results-header__subtitle {
  font-size: 0.875rem;
  color: var(--neutral-600, #757575);
  margin: 0.125rem 0 0;
}

.search-results-header__term {
  font-weight: 600;
  color: var(--medical-blue-700, #1565c0);
  background: var(--medical-blue-50, #e3f2fd);
  padding: 0.1rem 0.5rem;
  border-radius: 0.25rem;
  font-family: 'SF Mono', 'Monaco', 'Inconsolata', 'Roboto Mono', monospace;
}

.search-results-header__count {
  color: var(--neutral-500, #9e9e9e);
  margin-left: 0.25rem;
}

/* ── Table ────────────────────────────────────────────────────── */
.search-results-body {
  overflow: hidden;
}

.search-results-table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

.search-results-table__th {
  padding: 0.5rem 0.75rem;
  font-size: 0.65rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--neutral-500, #9e9e9e);
  border-bottom: 2px solid var(--neutral-200, #e0e0e0);
  text-align: left;
  white-space: nowrap;
}

/* Column widths */
.search-results-table__th:nth-child(1) { width: 30%; }     /* Match */
.search-results-table__th:nth-child(2) { width: 20%; }     /* Type */
.search-results-table__th:nth-child(3) { width: 22%; }     /* Entity */
.search-results-table__th--relevance { width: 28%; }        /* Relevance */

.search-results-table__row {
  cursor: pointer;
  transition: background-color 0.15s ease;
  border-bottom: 1px solid var(--neutral-100, #f5f5f5);
}

.search-results-table__row:last-child {
  border-bottom: none;
}

.search-results-table__row:hover {
  background-color: var(--medical-blue-50, #e3f2fd);
}

.search-results-table__row:active {
  background-color: var(--medical-blue-100, #bbdefb);
}

.search-results-table__td {
  padding: 0.5rem 0.75rem;
  vertical-align: middle;
  font-size: 0.8125rem;
  color: var(--neutral-800, #424242);
}

.search-results-table__td--relevance {
  overflow: visible;
  position: relative;
}

/* ── Match badge ──────────────────────────────────────────────── */
.search-results-table__match-link {
  text-decoration: none !important;
}

.search-results-table__match-badge {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.2rem 0.5rem;
  border-radius: 0.375rem;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  display: inline-block;
}

.search-results-table__match-badge:hover {
  transform: translateY(-1px);
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.15);
}

/* ── Type label ───────────────────────────────────────────────── */
.search-type-label {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.7rem;
  color: var(--neutral-600, #616161);
  background: var(--neutral-50, #fafafa);
  padding: 0.2rem 0.45rem;
  border-radius: 1rem;
  border: 1px solid var(--neutral-200, #e0e0e0);
  white-space: nowrap;
}

.search-type-label__icon {
  font-size: 0.65rem;
  opacity: 0.7;
}

/* ── Relevance indicator ──────────────────────────────────────── */
.relevance-indicator-wrapper {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  position: relative;
  cursor: default;
}

/* Hover tooltip showing numeric score */
.relevance-indicator-wrapper::after {
  content: attr(data-score);
  position: absolute;
  bottom: calc(100% + 6px);
  left: 50%;
  transform: translateX(-50%);
  padding: 0.35rem 0.6rem;
  background: var(--neutral-800, #333);
  color: #fff;
  font-size: 0.7rem;
  font-weight: 500;
  white-space: nowrap;
  border-radius: 0.375rem;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  pointer-events: none;
  opacity: 0;
  transition: opacity 0.15s ease;
  z-index: 10;
}

/* Tooltip arrow */
.relevance-indicator-wrapper::before {
  content: '';
  position: absolute;
  bottom: calc(100% + 2px);
  left: 50%;
  transform: translateX(-50%);
  border: 4px solid transparent;
  border-top-color: var(--neutral-800, #333);
  pointer-events: none;
  opacity: 0;
  transition: opacity 0.15s ease;
  z-index: 10;
}

.relevance-indicator-wrapper:hover::after,
.relevance-indicator-wrapper:hover::before {
  opacity: 1;
}

.relevance-indicator {
  width: 48px;
  height: 5px;
  background: var(--neutral-100, #f5f5f5);
  border-radius: 3px;
  overflow: hidden;
  flex-shrink: 0;
}

.relevance-indicator__bar {
  height: 100%;
  border-radius: 3px;
  transition: width 0.4s ease;
}

.relevance-indicator__bar--excellent {
  background: linear-gradient(90deg, #2e7d32, #43a047);
}

.relevance-indicator__bar--good {
  background: linear-gradient(90deg, #1565c0, #1e88e5);
}

.relevance-indicator__bar--fair {
  background: linear-gradient(90deg, #e65100, #f57c00);
}

.relevance-indicator__bar--low {
  background: linear-gradient(90deg, #c62828, #ef5350);
}

.relevance-indicator__label {
  font-size: 0.7rem;
  font-weight: 600;
  white-space: nowrap;
}

.relevance-indicator__label--excellent {
  color: #2e7d32;
}

.relevance-indicator__label--good {
  color: #1565c0;
}

.relevance-indicator__label--fair {
  color: #e65100;
}

.relevance-indicator__label--low {
  color: #c62828;
}

/* ── Responsive ───────────────────────────────────────────────── */
@media (max-width: 576px) {
  .search-results-header {
    padding: 0.75rem;
  }

  .search-results-header__icon {
    display: none;
  }

  .search-results-table__th,
  .search-results-table__td {
    padding: 0.375rem 0.5rem;
  }
}

/* ── Accessibility ────────────────────────────────────────────── */
@media (prefers-reduced-motion: reduce) {
  .search-results-table__row,
  .search-results-table__match-badge,
  .relevance-indicator__bar,
  .relevance-indicator-wrapper::after,
  .relevance-indicator-wrapper::before {
    transition: none;
  }

  .search-results-table__match-badge:hover {
    transform: none;
  }
}
</style>

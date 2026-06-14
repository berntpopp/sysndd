<template>
  <div class="home-page">
    <section class="home-hero" aria-labelledby="home-title">
      <div class="home-hero__content">
        <h1 id="home-title" class="home-hero__title">SysNDD</h1>
        <p class="home-hero__summary">
          Curated gene-disease relationships for clinical diagnostics, counseling, and research.
        </p>
      </div>

      <div class="home-search" aria-label="Search SysNDD">
        <SearchCombobox placeholder-string="Search genes, diseases, IDs" :in-navbar="false" />
      </div>
    </section>

    <main class="home-layout">
      <div class="home-layout__primary">
        <HomeStatsPanel
          :entity-statistics="entity_statistics"
          :gene-statistics="gene_statistics"
          :last-update="last_update"
          :inheritance-overview-text="inheritance_overview_text"
          :inheritance-link="inheritance_link"
          :loading="loadingStates.statistics"
          :error="errors.statistics"
        />

        <HomeNewsPanel
          :news="news"
          :loading="loadingStates.news"
          :error="errors.news"
        />
      </div>

      <aside class="home-layout__secondary" aria-label="SysNDD concepts">
        <HomeConceptPanel :docs-url="DOCS_URLS.CURATION_CRITERIA" />
      </aside>
    </main>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
// Import composables directly (not via the '@/composables' barrel): the barrel
// statically re-exports heavy composables (use3DStructure->ngl, useMarkdownRenderer,
// useCytoscape/useNetworkData->d3, exceljs) that Rollup cannot tree-shake out, so
// pulling anything from it dragged ~600 KB of unused code onto the home critical path.
import useToast from '@/composables/useToast';
import useText from '@/composables/useText';

// Importing initial objects from a constants file to avoid hardcoding them in this component
import INIT_OBJ from '@/assets/js/constants/init_obj_constants';

// Import documentation URLs from constants
import { DOCS_URLS } from '@/constants/docs';

// Import the apiService to make the API calls
import apiService from '@/assets/js/services/apiService';

// Import global components
import SearchCombobox from '@/components/small/SearchCombobox.vue';
import HomeStatsPanel from '@/components/home/HomeStatsPanel.vue';
import HomeNewsPanel from '@/components/home/HomeNewsPanel.vue';
import HomeConceptPanel from '@/components/home/HomeConceptPanel.vue';

// gsap is loaded lazily so the dataviz bundle (d3/upsetjs/gsap) stays off the
// home page's critical render path. It is only needed for the count-up
// animation that runs *after* statistics load, so a dynamic import that races
// the API call costs nothing perceptible while removing the dataviz code from
// the home page's first load.
let gsapLib = null;
let gsapPromise = null;
function ensureGsap() {
  if (gsapLib) return Promise.resolve(gsapLib);
  if (!gsapPromise) {
    gsapPromise = import('gsap')
      .then((mod) => {
        gsapLib = mod.gsap;
        return gsapLib;
      })
      .catch(() => null);
  }
  return gsapPromise;
}

export default {
  name: 'HomeView',
  components: {
    SearchCombobox,
    HomeStatsPanel,
    HomeNewsPanel,
    HomeConceptPanel,
  },
  setup() {
    const { makeToast } = useToast();
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
      news: INIT_OBJ.NEWS_INIT,
      loadingStates: {
        statistics: false,
        news: false,
      },
      errors: {
        statistics: null,
        news: null,
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
    // Kick off the gsap import in parallel with the first data load so the
    // count-up animation is ready by the time statistics arrive.
    ensureGsap();
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
      // If gsap hasn't finished loading yet, the reactive values already hold
      // their final numbers — just render them without the count-up tween.
      if (!gsapLib) {
        ensureGsap();
        this.$forceUpdate();
        return;
      }
      for (let i = 0; i < after.length; i += 1) {
        if (before[i].n !== after[i].n) {
          gsapLib.fromTo(
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
      this.errors.statistics = null;
      try {
        // use the functions from apiService asset to make calls to the API
        this.entity_statistics = await apiService.fetchStatistics('entity');
        this.gene_statistics = await apiService.fetchStatistics('gene');
      } catch (e) {
        this.errors.statistics = 'Statistics could not be loaded. Please try again later.';
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
      this.errors.news = null;
      try {
        // use the functions from apiService asset to make calls to the API
        this.news = await apiService.fetchNews(5);
      } catch (e) {
        this.errors.news = 'Recent entities could not be loaded. Please try again later.';
        this.makeToast(e, 'Error', 'danger');
      } finally {
        this.loadingStates.news = false;
      }
    },
  },
};
</script>

<style scoped>
.home-page {
  box-sizing: border-box;
  min-height: 100%;
  padding: 0.75rem 1rem 1.5rem;
  background: #f6f8fb;
  text-align: left;
}

.home-hero {
  display: grid;
  grid-template-columns: minmax(0, 0.95fr) minmax(20rem, 0.85fr);
  gap: 1.25rem;
  align-items: center;
  width: min(100%, 1480px);
  margin: 0 auto 1rem;
  padding: 1.1rem 1rem;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background: #fff;
  box-shadow: 0 1px 3px rgba(15, 23, 42, 0.08);
}

.home-hero__title {
  margin: 0;
  color: var(--neutral-900, #172033);
  font-size: var(--font-size-xl, 1.25rem);
  font-weight: var(--font-weight-semibold, 600);
  line-height: 1.2;
}

.home-hero__summary {
  max-width: 44rem;
  margin: 0.25rem 0 0;
  color: var(--neutral-600, #526070);
  font-size: 0.875rem;
  line-height: 1.45;
}

.home-search {
  min-width: 0;
}

.home-layout {
  display: grid;
  grid-template-columns: minmax(0, 1.35fr) minmax(24rem, 0.65fr);
  gap: 1rem;
  width: min(100%, 1480px);
  margin: 0 auto;
  align-items: start;
}

.home-layout__primary {
  display: grid;
  gap: 1rem;
  min-width: 0;
}

.home-layout__secondary {
  min-width: 0;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s;
}
.fade-enter,
.fade-leave-to {
  opacity: 0;
}

@media (max-width: 991.98px) {
  .home-hero,
  .home-layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 575.98px) {
  .home-page {
    padding: 0.5rem 0.75rem 1rem;
  }

  .home-hero {
    gap: 0.8rem;
    padding: 0.9rem 0.75rem;
  }

  .home-hero__summary {
    font-size: 0.875rem;
  }
}
</style>

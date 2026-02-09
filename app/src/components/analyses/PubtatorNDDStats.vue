<!-- src/components/analyses/PubtatorNDDStats.vue -->
<template>
  <BContainer fluid>
    <BCard header-tag="header" body-class="p-0" header-class="p-1" border-variant="dark">
      <template #header>
        <div class="d-flex justify-content-between align-items-center">
          <h6 class="mb-1 text-start font-weight-bold">
            PubTator NDD Statistics
            <mark
              v-b-tooltip.hover.leftbottom
              title="Shows aggregated statistics from PubTator gene-publication associations."
            >
              (Summary &amp; Bar Plots)
            </mark>
            <BBadge id="popover-badge-help-pubtator-stats" pill href="#" variant="info">
              <i class="bi bi-question-circle-fill" />
            </BBadge>
            <BPopover target="popover-badge-help-pubtator-stats" variant="info" triggers="focus">
              <template #title> About PubTator NDD Statistics </template>
              <p>
                <strong>PubTator</strong> is NCBI's text mining service that identifies genes
                mentioned in biomedical literature. These statistics show the distribution of
                NDD-related publications per gene from our cached PubTator searches.
              </p>
              <p class="mb-0">
                <strong>How to use:</strong><br />
                - <em>Summary cards</em>: Quick overview of gene coverage<br />
                - <em>Top Genes</em>: Shows genes with most publication mentions<br />
                - <em>Publications by Gene Count</em>: Histogram of how many publications mention N
                genes<br />
                - Adjust <em>Min Count</em> to filter genes with few mentions<br />
                - Adjust <em>Top N</em> to show more/fewer bars
              </p>
            </BPopover>
          </h6>
        </div>
      </template>

      <!-- Summary Stats Cards -->
      <BRow class="p-3">
        <BCol md="4">
          <BCard class="text-center h-100" border-variant="primary">
            <template #header>
              <small class="text-muted">Total Genes</small>
            </template>
            <BCardBody class="py-2">
              <BSpinner v-if="loadingStats" small />
              <template v-else>
                <h3 class="mb-0 text-primary">
                  {{ isFilterActive ? filteredTotal : totalGenes }}
                </h3>
                <small v-if="isFilterActive" class="text-muted">
                  of {{ totalGenes }} total
                </small>
              </template>
            </BCardBody>
          </BCard>
        </BCol>
        <BCol md="4">
          <BCard class="text-center h-100" border-variant="info">
            <template #header>
              <small class="text-muted">Literature Only</small>
            </template>
            <BCardBody class="py-2">
              <BSpinner v-if="loadingStats" small />
              <template v-else>
                <h3 class="mb-0 text-info">
                  {{ isFilterActive ? filteredNovel : novelGenes }}
                </h3>
                <small v-if="isFilterActive" class="text-muted">
                  of {{ novelGenes }} total
                </small>
                <small v-else class="text-muted">(not yet curated)</small>
              </template>
            </BCardBody>
          </BCard>
        </BCol>
        <BCol md="4">
          <BCard class="text-center h-100" border-variant="success">
            <template #header>
              <small class="text-muted">Curated</small>
            </template>
            <BCardBody class="py-2">
              <BSpinner v-if="loadingStats" small />
              <template v-else>
                <h3 class="mb-0 text-success">
                  {{ isFilterActive ? filteredCurated : inSysnddGenes }}
                </h3>
                <small v-if="isFilterActive" class="text-muted">
                  of {{ inSysnddGenes }} total
                </small>
                <small v-else class="text-muted">(in SysNDD)</small>
              </template>
            </BCardBody>
          </BCard>
        </BCol>
      </BRow>

      <!-- Active filter indicator -->
      <div v-if="isFilterActive && !loadingStats" class="text-center pb-1">
        <small class="text-muted">
          <i class="bi bi-funnel-fill me-1" />
          Showing genes with &ge;{{ minCount }} publications
          <template v-if="displayedCount < filteredTotal">
            (top {{ displayedCount }} of {{ filteredTotal }})
          </template>
        </small>
      </div>

      <!-- User Interface controls -->
      <BRow class="p-2">
        <BCol class="my-1" :sm="selectedCategory === 'gene' ? 4 : 6">
          <BInputGroup prepend="Category" class="mb-1" size="sm">
            <BFormSelect
              v-model="selectedCategory"
              :options="categoryOptions"
              size="sm"
              @change="processAndPlot"
            />
          </BInputGroup>
        </BCol>

        <!-- Min Count only applies to gene category (filters genes by publication count) -->
        <BCol v-if="selectedCategory === 'gene'" class="my-1" sm="4">
          <BInputGroup prepend="Min Count" class="mb-1" size="sm">
            <BFormInput v-model.number="minCount" type="number" min="1" step="1" debounce="500" />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" :sm="selectedCategory === 'gene' ? 4 : 6">
          <BInputGroup
            :prepend="selectedCategory === 'gene' ? 'Top N' : 'Max Bins'"
            class="mb-1"
            size="sm"
          >
            <BFormInput
              v-model.number="topN"
              type="number"
              min="5"
              max="100"
              step="5"
              debounce="500"
            />
          </BInputGroup>
        </BCol>
      </BRow>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <BSpinner v-if="loading" label="Loading..." class="spinner" />
        <div v-show="!loading" id="pubtator_stats_dataviz" class="svg-container" />
        <div
          v-if="!loading && selectedCategory === 'gene'"
          class="d-flex justify-content-center gap-2 pb-3"
        >
          <BBadge variant="success" pill>
            <i class="bi bi-check-circle me-1" />
            Curated
          </BBadge>
          <BBadge variant="info" pill>
            <i class="bi bi-journal-text me-1" />
            Literature Only
          </BBadge>
        </div>
      </div>
    </BCard>
  </BContainer>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import * as d3 from 'd3';
import axios from 'axios';
import useToast from '@/composables/useToast';

// Types
interface GeneData {
  gene_symbol: string;
  publication_count: number;
  is_novel?: number;
  hgnc_id?: string;
}

interface StatsDataItem {
  name: string;
  count: number;
  isNovel?: number;
  hgncId?: string;
}

// Composables
const { makeToast } = useToast();
const router = useRouter();

// User selections
const selectedCategory = ref('gene');
const categoryOptions = [
  { value: 'gene', text: 'Top Genes by Publication Count' },
  { value: 'publication', text: 'Publications by Gene Count' },
];

// Filters
const minCount = ref(5);
const topN = ref(30);

// Data from the API
const rawGeneData = ref<GeneData[]>([]);
const statsData = ref<StatsDataItem[]>([]);

// Loading states
const loading = ref(true);
const loadingStats = ref(true);

// Computed stats for summary cards — totals (unfiltered)
const totalGenes = computed(() => rawGeneData.value.length);
const novelGenes = computed(() => rawGeneData.value.filter((g) => g.is_novel === 1).length);
const inSysnddGenes = computed(() => rawGeneData.value.filter((g) => g.is_novel === 0).length);

// Filtered counts (genes matching minCount threshold)
const filteredGeneData = computed(() =>
  rawGeneData.value.filter((g) => g.publication_count >= minCount.value),
);
const filteredTotal = computed(() => filteredGeneData.value.length);
const filteredNovel = computed(() => filteredGeneData.value.filter((g) => g.is_novel === 1).length);
const filteredCurated = computed(() =>
  filteredGeneData.value.filter((g) => g.is_novel === 0).length,
);

// Whether the minCount filter is actively narrowing results
const isFilterActive = computed(
  () => selectedCategory.value === 'gene' && minCount.value > 1,
);

// Number of bars actually displayed (limited by topN)
const displayedCount = computed(() => Math.min(statsData.value.length, topN.value));

// Watch minCount changes - needs to re-process data and re-plot
watch(minCount, () => {
  if (rawGeneData.value.length > 0) {
    processAndPlot();
  }
});

// Watch topN changes - only needs to re-plot (data slice changes)
watch(topN, () => {
  if (statsData.value.length > 0) {
    generateBarPlot();
  }
});

/**
 * Fetches PubTator gene statistics from the API
 */
async function fetchStats() {
  loading.value = true;
  loadingStats.value = true;

  const baseUrl = `${import.meta.env.VITE_API_URL}/api/publication/pubtator/genes`;
  const params = new URLSearchParams();
  params.set('page_size', '2000'); // Get enough data for stats
  params.set('fields', 'gene_symbol,publication_count,is_novel,hgnc_id');

  const apiUrl = `${baseUrl}?${params.toString()}`;

  try {
    const response = await axios.get(apiUrl, { withCredentials: true });
    // Store the raw gene data - each item has gene_symbol, publication_count, and is_novel
    rawGeneData.value = (response.data.data || []).map((item: Record<string, unknown>) => ({
      gene_symbol: String(item.gene_symbol || 'Unknown'),
      publication_count: Number(item.publication_count) || 0,
      is_novel: item.is_novel !== undefined ? Number(item.is_novel) : undefined,
      hgnc_id: item.hgnc_id ? String(item.hgnc_id) : undefined,
    }));
    loadingStats.value = false;
    processAndPlot();
  } catch (error) {
    makeToast(error, 'Error fetching PubTator stats', 'danger');
  } finally {
    loading.value = false;
  }
}

/**
 * Process the raw data and generate the plot
 */
function processAndPlot() {
  processStatsData();
  generateBarPlot();
}

/**
 * Processes raw gene data into statistics based on selected category
 */
function processStatsData() {
  if (selectedCategory.value === 'gene') {
    // Gene category: each gene with its publication count
    statsData.value = rawGeneData.value
      .filter((item) => item.publication_count >= minCount.value)
      .map((item) => ({
        name: item.gene_symbol,
        count: item.publication_count,
        isNovel: item.is_novel,
        hgncId: item.hgnc_id,
      }))
      .sort((a, b) => b.count - a.count);
  } else {
    // Publication category: histogram of publication counts
    // Group genes by their publication_count value
    const histogram: Record<number, number> = {};
    rawGeneData.value.forEach((item) => {
      const count = item.publication_count;
      histogram[count] = (histogram[count] || 0) + 1;
    });

    statsData.value = Object.entries(histogram)
      .map(([pubCount, geneCount]) => ({
        name: `${pubCount} pubs`,
        count: geneCount,
      }))
      .sort((a, b) => parseInt(a.name, 10) - parseInt(b.name, 10));
  }
}

// Bar color constants matching summary cards and PubtatorNDDGenes badges
const COLOR_CURATED = '#198754'; // Bootstrap success
const COLOR_LITERATURE_ONLY = '#0dcaf0'; // Bootstrap info
const COLOR_DEFAULT = '#5470c6'; // Histogram / fallback

/**
 * Returns bar fill color based on curation status
 */
function barFill(d: StatsDataItem): string {
  if (selectedCategory.value !== 'gene') return COLOR_DEFAULT;
  if (d.isNovel === 0) return COLOR_CURATED;
  if (d.isNovel === 1) return COLOR_LITERATURE_ONLY;
  return COLOR_DEFAULT;
}

/**
 * Builds a bar chart from the processed statistics
 */
function generateBarPlot() {
  const isGeneMode = selectedCategory.value === 'gene';

  // Always remove old svg and tooltip first
  d3.select('#pubtator_stats_dataviz').select('svg').remove();
  d3.select('#pubtator_stats_dataviz').select('.tooltip').remove();
  d3.select('#pubtator_stats_dataviz').select('.no-data-message').remove();

  // Handle empty data case - show message instead of stale chart
  if (!statsData.value || statsData.value.length === 0) {
    d3.select('#pubtator_stats_dataviz')
      .append('div')
      .attr('class', 'no-data-message text-center text-muted py-5')
      .html(
        `<i class="bi bi-inbox" style="font-size: 3rem;"></i><br/>
        <strong>No data matches current filters</strong><br/>
        <small>Try lowering the Min Count value</small>`
      );
    return;
  }

  // Limit to top N entries
  const data = statsData.value.slice(0, topN.value);

  // set dimensions
  const margin = {
    top: 30,
    right: 30,
    bottom: 150,
    left: 60,
  };
  const width = 760 - margin.left - margin.right;
  const height = 450 - margin.top - margin.bottom;

  // append the SVG
  const svg = d3
    .select('#pubtator_stats_dataviz')
    .append('svg')
    .attr('id', 'pubtator-stats-svg')
    .attr('viewBox', '0 0 760 450')
    .attr('preserveAspectRatio', 'xMinYMin meet')
    .append('g')
    .attr('transform', `translate(${margin.left},${margin.top})`);

  // X axis
  const x = d3
    .scaleBand()
    .range([0, width])
    .domain(data.map((d) => d.name))
    .padding(0.2);

  const xAxisGroup = svg
    .append('g')
    .attr('class', 'x-axis')
    .attr('transform', `translate(0,${height})`)
    .call(d3.axisBottom(x));

  xAxisGroup
    .selectAll('text')
    .attr('transform', 'translate(-10,0)rotate(-45)')
    .style('text-anchor', 'end')
    .style('font-size', '10px');

  // In gene mode, color and make X-axis labels clickable
  if (isGeneMode) {
    const labelLookup = new Map(data.map((d) => [d.name, d]));

    xAxisGroup
      .selectAll<SVGTextElement, string>('text')
      .each(function (this: SVGTextElement, labelText: string) {
        const item = labelLookup.get(labelText);
        if (!item) return;

        d3.select(this)
          .style('fill', barFill(item))
          .style('font-weight', 'bold')
          .style('cursor', item.hgncId ? 'pointer' : 'default')
          .on('click', () => {
            if (item.hgncId) {
              router.push(`/Genes/${item.hgncId}`);
            }
          });
      });
  }

  // Y axis
  const maxY = d3.max(data, (d) => d.count) || 0;
  const y = d3
    .scaleLinear()
    .domain([0, maxY * 1.1])
    .range([height, 0]);
  svg.append('g').call(d3.axisLeft(y));

  // Y axis label
  svg
    .append('text')
    .attr('transform', 'rotate(-90)')
    .attr('y', 0 - margin.left)
    .attr('x', 0 - height / 2)
    .attr('dy', '1em')
    .style('text-anchor', 'middle')
    .style('font-size', '12px')
    .text(isGeneMode ? 'Publication Count' : 'Number of Genes');

  // Create a tooltip element
  const tooltip = d3
    .select('#pubtator_stats_dataviz')
    .append('div')
    .attr('class', 'tooltip')
    .style('opacity', 0)
    .style('background-color', 'white')
    .style('border', 'solid 1px')
    .style('border-radius', '5px')
    .style('padding', '5px')
    .style('position', 'absolute')
    .style('pointer-events', 'none');

  const mouseover = function (this: SVGRectElement) {
    tooltip.style('opacity', 1);
    d3.select(this).style('stroke', 'black').style('opacity', 1);
  };

  const mousemove = function (this: SVGRectElement, event: MouseEvent, d: StatsDataItem) {
    tooltip
      .html(`<strong>${d.name}</strong><br>Count: ${d.count}`)
      .style('left', `${event.layerX + 20}px`)
      .style('top', `${event.layerY + 20}px`);
  };

  const mouseleave = function (this: SVGRectElement) {
    tooltip.style('opacity', 0);
    d3.select(this).style('stroke', 'none');
  };

  // bars
  const bars = svg
    .selectAll('mybar')
    .data(data)
    .enter()
    .append('rect')
    .attr('x', (d) => x(d.name) || 0)
    .attr('y', (d) => y(d.count))
    .attr('width', x.bandwidth())
    .attr('height', (d) => height - y(d.count))
    .attr('fill', (d) => barFill(d))
    .on('mouseover', mouseover)
    .on('mousemove', mousemove)
    .on('mouseleave', mouseleave);

  // In gene mode, make bars clickable for navigation
  if (isGeneMode) {
    bars
      .style('cursor', (d) => (d.hgncId ? 'pointer' : 'default'))
      .attr('role', 'button')
      .attr('aria-label', (d) => `View gene page for ${d.name}`)
      .on('click', (_event: MouseEvent, d: StatsDataItem) => {
        if (d.hgncId) {
          router.push(`/Genes/${d.hgncId}`);
        }
      });
  }
}

// Lifecycle
onMounted(async () => {
  await fetchStats();
});
</script>

<style scoped>
.svg-container {
  display: inline-block;
  position: relative;
  width: 100%;
  max-width: 900px;
  vertical-align: top;
  overflow: hidden;
  min-height: 450px;
}
.svg-container svg {
  display: inline-block;
  position: absolute;
  top: 0;
  left: 0;
}
.spinner {
  width: 2rem;
  height: 2rem;
  margin: 5rem auto;
  display: block;
}
.tooltip {
  pointer-events: none;
  font-size: 0.9rem;
}
.no-data-message {
  min-height: 300px;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
}
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>

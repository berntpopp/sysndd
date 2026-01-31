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
              (Bar Plots)
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

      <!-- User Interface controls -->
      <BRow class="p-2">
        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Category" class="mb-1" size="sm">
            <BFormSelect
              v-model="selectedCategory"
              :options="categoryOptions"
              size="sm"
              @change="generateBarPlot"
            />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Min Count" class="mb-1" size="sm">
            <BFormInput
              v-model="minCount"
              type="number"
              min="1"
              step="1"
              debounce="500"
              @change="processAndPlot"
            />
          </BInputGroup>
        </BCol>

        <BCol class="my-1" sm="4">
          <BInputGroup prepend="Top N" class="mb-1" size="sm">
            <BFormInput
              v-model="topN"
              type="number"
              min="5"
              max="100"
              step="5"
              debounce="500"
              @change="generateBarPlot"
            />
          </BInputGroup>
        </BCol>
      </BRow>

      <!-- Content with overlay spinner -->
      <div class="position-relative">
        <BSpinner v-if="loading" label="Loading..." class="spinner" />
        <div v-show="!loading" id="pubtator_stats_dataviz" class="svg-container" />
      </div>
    </BCard>
  </BContainer>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import * as d3 from 'd3';
import axios from 'axios';
import useToast from '@/composables/useToast';

// Types
interface GeneData {
  gene_symbol: string;
  publication_count: number;
}

interface StatsDataItem {
  name: string;
  count: number;
}

// Composables
const { makeToast } = useToast();

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

// Loading state
const loading = ref(true);

/**
 * Fetches PubTator gene statistics from the API
 */
async function fetchStats() {
  loading.value = true;

  const baseUrl = `${import.meta.env.VITE_API_URL}/api/publication/pubtator/genes`;
  const params = new URLSearchParams();
  params.set('page_size', '2000'); // Get enough data for stats
  params.set('fields', 'gene_symbol,publication_count'); // Only need these for stats

  const apiUrl = `${baseUrl}?${params.toString()}`;

  try {
    const response = await axios.get(apiUrl);
    // Store the raw gene data - each item has gene_symbol and publication_count
    rawGeneData.value = (response.data.data || []).map((item: Record<string, unknown>) => ({
      gene_symbol: String(item.gene_symbol || 'Unknown'),
      publication_count: Number(item.publication_count) || 0,
    }));
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

/**
 * Builds a bar chart from the processed statistics
 */
function generateBarPlot() {
  if (!statsData.value || statsData.value.length === 0) return;

  // remove old svg and tooltip
  d3.select('#pubtator_stats_dataviz').select('svg').remove();
  d3.select('#pubtator_stats_dataviz').select('.tooltip').remove();

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

  svg
    .append('g')
    .attr('transform', `translate(0,${height})`)
    .call(d3.axisBottom(x))
    .selectAll('text')
    .attr('transform', 'translate(-10,0)rotate(-45)')
    .style('text-anchor', 'end')
    .style('font-size', '10px');

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
    .text(selectedCategory.value === 'gene' ? 'Publication Count' : 'Number of Genes');

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
  svg
    .selectAll('mybar')
    .data(data)
    .enter()
    .append('rect')
    .attr('x', (d) => x(d.name) || 0)
    .attr('y', (d) => y(d.count))
    .attr('width', x.bandwidth())
    .attr('height', (d) => height - y(d.count))
    .attr('fill', '#5470c6')
    .on('mouseover', mouseover)
    .on('mousemove', mousemove)
    .on('mouseleave', mouseleave);
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
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>

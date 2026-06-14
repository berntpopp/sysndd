<template>
  <div class="chart-wrapper" style="position: relative; height: 350px">
    <BSpinner
      v-if="loading"
      label="Loading chart..."
      class="position-absolute top-50 start-50 translate-middle"
    />
    <p
      v-else-if="isEmpty"
      class="text-muted text-center position-absolute top-50 start-50 translate-middle mb-0"
      data-testid="contributor-bar-empty"
    >
      No contributor data for the selected period.
    </p>
    <Bar v-else :data="chartData" :options="chartOptions" role="img" :aria-label="ariaLabel" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Bar } from 'vue-chartjs';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
  type ChartOptions,
} from 'chart.js';
import { BSpinner } from 'bootstrap-vue-next';
import { CHART_PRIMARY } from '@/utils/chartColors';

// Tree-shaken Chart.js registration
ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

interface Contributor {
  user_name: string;
  entity_count: number;
}

interface Props {
  contributors: Contributor[];
  loading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
});

const isEmpty = computed(() => props.contributors.length === 0);

const ariaLabel = computed(() => {
  const top = props.contributors[0];
  return top
    ? `Top contributors by entity submissions, ${props.contributors.length} curators, leader ${top.user_name} with ${top.entity_count} entities.`
    : 'Top contributors by entity submissions, no data.';
});

const chartData = computed(() => ({
  labels: props.contributors.map((c) => c.user_name),
  datasets: [
    {
      label: 'Entities',
      data: props.contributors.map((c) => c.entity_count),
      backgroundColor: CHART_PRIMARY,
      borderColor: CHART_PRIMARY,
      borderWidth: 1,
    },
  ],
}));

const chartOptions: ChartOptions<'bar'> = {
  responsive: true,
  maintainAspectRatio: false, // Critical for Bootstrap card compatibility
  indexAxis: 'y', // Horizontal bars for easier name reading
  plugins: {
    legend: {
      display: false, // Hide legend for single dataset
    },
    tooltip: {
      callbacks: {
        label: (context) => `${context.parsed.x} entities`,
      },
    },
  },
  scales: {
    x: {
      beginAtZero: true,
      ticks: {
        precision: 0, // Integer counts only
      },
    },
  },
};
</script>

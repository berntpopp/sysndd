<template>
  <div class="chart-wrapper" style="position: relative; height: 350px">
    <BSpinner
      v-if="loading"
      label="Loading chart..."
      class="position-absolute top-50 start-50 translate-middle"
    />
    <Bar v-else :data="chartData" :options="chartOptions" />
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

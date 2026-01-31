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

// Tree-shaken Chart.js registration
ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

// Paul Tol Muted palette - colorblind safe
const COLORS = {
  submitted: '#6699CC', // Muted blue (submitted but not approved)
  approved: '#009E73', // Okabe-Ito bluish green (approved)
};

interface Reviewer {
  user_name: string;
  submitted_count: number;
  approved_count: number;
}

interface Props {
  reviewers: Reviewer[];
  loading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
});

const chartData = computed(() => ({
  labels: props.reviewers.map((r) => r.user_name),
  datasets: [
    {
      label: 'Approved',
      data: props.reviewers.map((r) => r.approved_count),
      backgroundColor: COLORS.approved,
      borderColor: COLORS.approved,
      borderWidth: 1,
    },
    {
      label: 'Pending',
      data: props.reviewers.map((r) => r.submitted_count - r.approved_count),
      backgroundColor: COLORS.submitted,
      borderColor: COLORS.submitted,
      borderWidth: 1,
    },
  ],
}));

const chartOptions: ChartOptions<'bar'> = {
  responsive: true,
  maintainAspectRatio: false,
  indexAxis: 'y', // Horizontal bars for easier name reading
  plugins: {
    legend: {
      display: true,
      position: 'bottom',
    },
    tooltip: {
      callbacks: {
        label: (context) => `${context.dataset.label}: ${context.parsed.x} re-reviews`,
      },
    },
  },
  scales: {
    x: {
      stacked: true,
      beginAtZero: true,
      ticks: {
        precision: 0,
      },
    },
    y: {
      stacked: true,
    },
  },
};
</script>

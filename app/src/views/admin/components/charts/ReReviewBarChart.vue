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
import { REVIEW_STATUS_COLORS } from '@/utils/chartColors';

// Tree-shaken Chart.js registration
ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

interface Reviewer {
  user_name: string;
  total_assigned: number;
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
      backgroundColor: REVIEW_STATUS_COLORS.approved,
      borderColor: REVIEW_STATUS_COLORS.approved,
      borderWidth: 1,
    },
    {
      label: 'Pending Review',
      data: props.reviewers.map((r) => Math.max(0, r.submitted_count - r.approved_count)),
      backgroundColor: REVIEW_STATUS_COLORS.submitted,
      borderColor: REVIEW_STATUS_COLORS.submitted,
      borderWidth: 1,
    },
    {
      label: 'Not Yet Submitted',
      data: props.reviewers.map((r) => Math.max(0, r.total_assigned - r.submitted_count)),
      backgroundColor: REVIEW_STATUS_COLORS.notSubmitted,
      borderColor: REVIEW_STATUS_COLORS.notSubmitted,
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

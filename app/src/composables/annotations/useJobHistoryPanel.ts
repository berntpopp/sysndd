// composables/annotations/useJobHistoryPanel.ts
/**
 * Job-history panel state + actions for Manage Annotations.
 *
 * Bundles the durable async-job history table concern that previously lived
 * inline in `ManageAnnotations.vue`: the row data, search-filtered and
 * paginated derivations, the CSV download, the page-link copy, and the
 * "clear all filters" reset. It composes `useJobHistoryUrlState` so the view
 * gets the URL-synced table controls plus the data wiring from one seam.
 *
 * Behavior, network calls, and the rendered table contract are unchanged —
 * this is a cohesive extraction, not a behavior change.
 */

import { ref, computed, type Ref, type ComputedRef } from 'vue';
import type { RouteLocationNormalizedLoaded } from 'vue-router';
import { unwrapValue } from '@/composables/annotations/useAnnotationFormatters';
import * as api from '@/composables/annotations/useAnnotationsApi';
import {
  useJobHistoryUrlState,
  type JobHistoryUrlStateReturn,
} from '@/composables/annotations/useJobHistoryUrlState';
import type { JobHistoryItem } from '@/components/annotations/JobHistoryCard.vue';

export interface UseJobHistoryPanelOptions {
  onToast: ReturnType<typeof import('@/composables/useToast').default>['makeToast'];
}

export interface UseJobHistoryPanelReturn extends JobHistoryUrlStateReturn {
  jobHistory: Ref<JobHistoryItem[]>;
  jobHistoryLoading: Ref<boolean>;
  jobHistoryFields: Array<{ key: string; label: string; sortable: boolean }>;
  filteredJobHistory: ComputedRef<JobHistoryItem[]>;
  paginatedJobHistory: ComputedRef<JobHistoryItem[]>;
  loadJobHistory: () => Promise<void>;
  downloadJobHistory: () => Promise<void>;
  copyPageLink: () => void;
  clearAllFilters: () => void;
}

export function useJobHistoryPanel(
  route: RouteLocationNormalizedLoaded,
  options: UseJobHistoryPanelOptions
): UseJobHistoryPanelReturn {
  const { onToast } = options;

  const urlState = useJobHistoryUrlState(route);
  const {
    currentPage,
    pageSize,
    searchFilter,
    clearAllFilters: resetTableState,
  } = urlState;

  const jobHistory = ref<JobHistoryItem[]>([]);
  const jobHistoryLoading = ref(false);

  const jobHistoryFields = [
    { key: 'operation', label: 'Job Type', sortable: true },
    { key: 'status', label: 'Status', sortable: true },
    { key: 'submitted_at', label: 'Started', sortable: true },
    { key: 'duration_seconds', label: 'Duration', sortable: true },
    { key: 'error_message', label: 'Error', sortable: false },
  ];

  function clearAllFilters(): void {
    resetTableState();
    onToast('All filters cleared', 'Filters Reset', 'info');
  }

  const filteredJobHistory = computed<JobHistoryItem[]>(() => {
    if (!searchFilter.value.trim()) return jobHistory.value;
    const search = searchFilter.value.toLowerCase();
    return jobHistory.value.filter(
      (job) =>
        job.operation.toLowerCase().includes(search) ||
        job.status.toLowerCase().includes(search) ||
        (job.error_message && job.error_message.toLowerCase().includes(search))
    );
  });

  const paginatedJobHistory = computed<JobHistoryItem[]>(() => {
    const start = (currentPage.value - 1) * pageSize.value;
    return filteredJobHistory.value.slice(start, start + pageSize.value);
  });

  async function loadJobHistory(): Promise<void> {
    jobHistoryLoading.value = true;
    try {
      jobHistory.value = await api.fetchJobHistory(20);
    } catch (error) {
      console.warn('Failed to fetch job history:', error);
      jobHistory.value = [];
    } finally {
      jobHistoryLoading.value = false;
    }
  }

  async function downloadJobHistory(): Promise<void> {
    try {
      const rows = await api.fetchJobHistoryRaw(1000);
      if (rows.length === 0) {
        onToast('No job history to download', 'Info', 'info');
        return;
      }
      const headers = ['Job ID', 'Operation', 'Status', 'Started', 'Duration (s)', 'Error'];
      const csvRows = rows.map((job) => [
        unwrapValue(job.job_id),
        unwrapValue(job.operation),
        unwrapValue(job.status),
        unwrapValue(job.submitted_at),
        unwrapValue(job.duration_seconds) ?? '',
        unwrapValue(job.error_message) ?? '',
      ]);
      const csv = [
        headers.join(','),
        ...csvRows.map((row) => row.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')),
      ].join('\n');
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `job_history_${new Date().toISOString().split('T')[0]}.csv`;
      link.click();
      URL.revokeObjectURL(url);
      onToast('Job history downloaded', 'Success', 'success');
    } catch (error) {
      onToast('Failed to download job history', 'Error', 'danger');
      console.error('Download error:', error);
    }
  }

  function copyPageLink(): void {
    navigator.clipboard
      .writeText(window.location.href)
      .then(() => onToast('Page link copied to clipboard', 'Copied', 'success'))
      .catch(() => onToast('Failed to copy link', 'Error', 'danger'));
  }

  return {
    ...urlState,
    jobHistory,
    jobHistoryLoading,
    jobHistoryFields,
    filteredJobHistory,
    paginatedJobHistory,
    loadJobHistory,
    downloadJobHistory,
    copyPageLink,
    clearAllFilters,
  };
}

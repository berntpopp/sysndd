/**
 * usePubtatorAdminPanel - view-level orchestration for ManagePubtator.vue
 *
 * Wraps the lower-level `usePubtatorAdmin` cache/job composable and adds the
 * page's own form state (query, page count, hard-update flag), the inline
 * feedback banner, the clear-all modal flag, and the four action handlers
 * that translate composable calls into feedback messages.
 *
 * Extracted from `ManagePubtator.vue` (refactor #346 WP6 / #399) so the view
 * is a thin template + single composable call. Behavior, network calls, and
 * the rendered structure are unchanged.
 */

import { ref, computed } from 'vue';
import { usePubtatorAdmin } from '@/composables/usePubtatorAdmin';
import { extractApiErrorMessage } from '@/utils/api-errors';

export type FeedbackVariant = 'success' | 'danger' | 'info' | 'warning';

/** Default PubTator query seeded in the textarea (unchanged from the view). */
const DEFAULT_QUERY =
  '("intellectual disability" OR "mental retardation" OR "autism" OR "epilepsy" OR "neurodevelopmental disorder" OR "neurodevelopmental disease" OR "epileptic encephalopathy") AND (gene OR syndrome) AND (variant OR mutation)';

export function usePubtatorAdminPanel() {
  const admin = usePubtatorAdmin();
  const {
    lastStatus,
    getCacheStatus,
    submitFetchJob,
    clearCache,
    backfillGeneSymbols,
    resetJob,
  } = admin;

  // Form state
  const query = ref(DEFAULT_QUERY);
  const maxPages = ref(50);
  const clearOld = ref(false);

  // UI state
  const showClearAllModal = ref(false);

  // Feedback banner
  const feedbackMessage = ref('');
  const feedbackVariant = ref<FeedbackVariant>('info');
  let statusCheckGeneration = 0;

  const feedbackIcon = computed(() => {
    switch (feedbackVariant.value) {
      case 'success':
        return 'bi bi-check-circle-fill';
      case 'danger':
        return 'bi bi-exclamation-triangle-fill';
      case 'warning':
        return 'bi bi-exclamation-circle-fill';
      default:
        return 'bi bi-info-circle-fill';
    }
  });

  const cacheStateLabel = computed(() => {
    if (!lastStatus.value) return 'No status';
    return lastStatus.value.cached ? 'Cached' : 'Not cached';
  });

  function formatDate(dateStr: string | null): string {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleString();
  }

  async function checkStatus(): Promise<void> {
    if (!query.value.trim()) return;
    const generation = ++statusCheckGeneration;
    feedbackMessage.value = '';

    try {
      await getCacheStatus(query.value);
    } catch (err) {
      if (generation !== statusCheckGeneration) return;
      feedbackMessage.value = extractApiErrorMessage(err, 'Failed to check cache status');
      feedbackVariant.value = 'danger';
    }
  }

  async function submitFetch(): Promise<void> {
    if (!query.value.trim()) return;
    feedbackMessage.value = '';
    resetJob(); // Clear any previous job state

    try {
      await submitFetchJob(query.value, maxPages.value, clearOld.value);
      feedbackMessage.value = `Job submitted! Fetching ${maxPages.value} pages (~${Math.round((maxPages.value * 2.5) / 60)} min)`;
      feedbackVariant.value = 'info';
    } catch (err) {
      feedbackMessage.value = extractApiErrorMessage(err, 'Failed to submit fetch job');
      feedbackVariant.value = 'danger';
    }
  }

  async function backfillGenes(): Promise<void> {
    if (!lastStatus.value?.query_id) return;
    feedbackMessage.value = '';

    try {
      const backfillResult = await backfillGeneSymbols(lastStatus.value.query_id);
      feedbackMessage.value = backfillResult.message;
      feedbackVariant.value = 'success';
    } catch (err) {
      feedbackMessage.value = extractApiErrorMessage(err, 'Failed to backfill gene symbols');
      feedbackVariant.value = 'danger';
    }
  }

  async function clearAllCache(): Promise<void> {
    feedbackMessage.value = '';

    try {
      const clearResult = await clearCache();
      feedbackMessage.value = clearResult.message ?? 'Cache cleared.';
      feedbackVariant.value = 'success';
      lastStatus.value = null;
    } catch (err) {
      feedbackMessage.value = extractApiErrorMessage(err, 'Failed to clear cache');
      feedbackVariant.value = 'danger';
    } finally {
      showClearAllModal.value = false;
    }
  }

  return {
    // Lower-level cache/job composable (state, computed, controls)
    ...admin,
    // Form state
    query,
    maxPages,
    clearOld,
    // UI state
    showClearAllModal,
    // Feedback
    feedbackMessage,
    feedbackVariant,
    feedbackIcon,
    // Local computed
    cacheStateLabel,
    // Methods
    formatDate,
    checkStatus,
    submitFetch,
    backfillGenes,
    clearAllCache,
  };
}

export default usePubtatorAdminPanel;

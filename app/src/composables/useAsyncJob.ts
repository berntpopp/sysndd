import type { Ref, ComputedRef } from 'vue';
import { ref, computed, onUnmounted } from 'vue';
import { useIntervalFn } from '@vueuse/core';
import axios from 'axios';
import { apiClient } from '@/api/client';

/**
 * Progress information for an async job
 */
export interface JobProgress {
  current: number;
  total: number;
}

interface JobStatusPayload {
  status?: string | string[];
  step?: string | string[];
  progress?: {
    current?: number | string | Array<number | string>;
    total?: number | string | Array<number | string>;
  };
  error?: string | { message?: string };
}

/**
 * Possible job status values
 */
export type JobStatus = 'idle' | 'accepted' | 'running' | 'completed' | 'failed';

/**
 * Bootstrap variant type for progress bars
 */
export type ProgressVariant = 'primary' | 'success' | 'danger';

/**
 * Options for the useAsyncJob composable
 */
export interface UseAsyncJobOptions {
  /**
   * Polling interval in milliseconds (default: 3000)
   */
  pollingInterval?: number;
  /**
   * Elapsed time update interval in milliseconds (default: 1000)
   */
  timerInterval?: number;
}

/**
 * Return type for the useAsyncJob composable
 */
export interface UseAsyncJobReturn {
  // State
  jobId: Ref<string | null>;
  status: Ref<JobStatus>;
  step: Ref<string>;
  progress: Ref<JobProgress>;
  error: Ref<string | null>;
  elapsedSeconds: Ref<number>;

  // Computed
  hasRealProgress: ComputedRef<boolean>;
  progressPercent: ComputedRef<number | null>;
  elapsedTimeDisplay: ComputedRef<string>;
  progressVariant: ComputedRef<ProgressVariant>;
  statusBadgeClass: ComputedRef<string>;
  isLoading: ComputedRef<boolean>;
  isPolling: ComputedRef<boolean>;

  // Methods
  startJob: (newJobId: string) => void;
  stopPolling: () => void;
  reset: () => void;
}

/**
 * Composable for managing async job state with polling, progress tracking, and cleanup.
 *
 * Extracted from ManageAnnotations.vue pattern. Uses VueUse useIntervalFn for
 * automatic cleanup on component unmount.
 *
 * @param statusEndpoint - Function that returns the polling URL given a job ID
 * @param options - Optional configuration for polling intervals
 * @returns Reactive state, computed properties, and control methods
 *
 * @example
 * ```ts
   * const { startJob, status, progress, elapsedTimeDisplay, stopPolling } = useAsyncJob(
   *   (jobId) => `/api/jobs/${encodeURIComponent(jobId)}/status`
   * );
 *
 * // Start tracking a job
 * const response = await axios.post('/api/start-job');
 * startJob(response.data.job_id);
 *
 * // In template:
 * // <BProgress :value="hasRealProgress ? progressPercent : 100" :striped="!hasRealProgress" />
 * // <span>{{ elapsedTimeDisplay }}</span>
 * ```
 */
export function useAsyncJob(
  statusEndpoint: (jobId: string) => string,
  options: UseAsyncJobOptions = {}
): UseAsyncJobReturn {
  const { pollingInterval = 3000, timerInterval = 1000 } = options;

  // Reactive state
  const jobId = ref<string | null>(null);
  const status = ref<JobStatus>('idle');
  const step = ref<string>('');
  const progress = ref<JobProgress>({ current: 0, total: 0 });
  const error = ref<string | null>(null);
  const startTime = ref<number | null>(null);
  const elapsedSeconds = ref<number>(0);

  // Request-ownership generation (#535 S5b). Bumped whenever the tracked job
  // changes or polling is cancelled (startJob / stopPolling / reset / unmount),
  // so an in-flight poll whose response arrives after the job changed is ignored
  // and cannot stop/fail the new job. `inFlightGeneration` provides single-flight
  // per generation so two overlapping polls of the SAME job cannot let an older
  // response overwrite a terminal result.
  let pollGeneration = 0;
  let inFlightGeneration: number | null = null;

  // Polling controls (VueUse auto-cleanup on unmount via tryOnCleanup)
  const {
    pause: pausePolling,
    resume: resumePolling,
    isActive: pollingActive,
  } = useIntervalFn(
    async () => {
      if (!jobId.value) return;
      await checkJobStatus();
    },
    pollingInterval,
    { immediate: false }
  );

  // Elapsed time counter (VueUse auto-cleanup on unmount via tryOnCleanup)
  const { pause: pauseTimer, resume: resumeTimer } = useIntervalFn(
    () => {
      if (startTime.value) {
        elapsedSeconds.value = Math.floor((Date.now() - startTime.value) / 1000);
      }
    },
    timerInterval,
    { immediate: false }
  );

  // Computed properties

  /**
   * Whether the job has real progress information (total > 0)
   */
  const hasRealProgress = computed<boolean>(() => progress.value.total > 0);

  /**
   * Progress percentage (0-100) or null if no progress data
   */
  const progressPercent = computed<number | null>(() => {
    if (progress.value.total > 0) {
      return Math.round((progress.value.current / progress.value.total) * 100);
    }
    return null;
  });

  /**
   * Elapsed time formatted as "Xm Ys" or "Ys"
   */
  const elapsedTimeDisplay = computed<string>(() => {
    const mins = Math.floor(elapsedSeconds.value / 60);
    const secs = elapsedSeconds.value % 60;
    if (mins > 0) {
      return `${mins}m ${secs}s`;
    }
    return `${secs}s`;
  });

  /**
   * Bootstrap variant for progress bar based on status
   */
  const progressVariant = computed<ProgressVariant>(() => {
    if (status.value === 'failed') return 'danger';
    if (status.value === 'completed') return 'success';
    return 'primary';
  });

  /**
   * Bootstrap badge class based on status
   */
  const statusBadgeClass = computed<string>(() => {
    const classes: Record<JobStatus, string> = {
      idle: 'bg-secondary',
      accepted: 'bg-info',
      running: 'bg-primary',
      completed: 'bg-success',
      failed: 'bg-danger',
    };
    return classes[status.value] || 'bg-secondary';
  });

  /**
   * Whether the job is currently loading (accepted or running)
   */
  const isLoading = computed<boolean>(
    () => status.value === 'accepted' || status.value === 'running'
  );

  /**
   * Whether polling is currently active
   */
  const isPolling = computed<boolean>(() => pollingActive.value);

  // Methods

  /**
   * Helper to unwrap R/Plumber array values (scalars come as single-element arrays)
   */
  function unwrapValue<T>(val: T | T[]): T {
    return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
  }

  /**
   * Check job status from the API
   */
  async function checkJobStatus(): Promise<void> {
    if (!jobId.value) return;

    const myGen = pollGeneration;
    // Single-flight per generation: if a poll for this job generation is already
    // in flight, skip this tick (a newer job generation is always allowed through).
    if (inFlightGeneration === myGen) return;
    inFlightGeneration = myGen;

    try {
      // Auth for polling is injected by the shared api client interceptor.
      // Durable job state means polling no longer depends on sticky-session
      // routing or container-local ownership.
      const data = await apiClient.get<JobStatusPayload>(statusEndpoint(jobId.value));

      // Ignore a response that arrived after the tracked job changed or polling
      // was cancelled — it must not mutate state or stop the new job's polling.
      if (myGen !== pollGeneration) return;

      // Handle job not found error
      if (data.error === 'JOB_NOT_FOUND') {
        stopPolling();
        error.value = 'Job not found';
        status.value = 'failed';
        return;
      }

      // Handle R/Plumber array wrapping
      status.value = unwrapValue(data.status) as JobStatus;
      const stepValue = unwrapValue(data.step);
      if (stepValue) {
        step.value = String(stepValue);
      }

      // Update progress if provided (unwrap R/Plumber array wrapping)
      if (data.progress) {
        progress.value = {
          current: Number(unwrapValue(data.progress.current)) || 0,
          total: Number(unwrapValue(data.progress.total)) || 0,
        };
      }

      // Handle terminal states
      if (status.value === 'completed' || status.value === 'failed') {
        stopPolling();
        if (status.value === 'failed') {
          // Extract specific error message
          error.value =
            typeof data.error === 'string' ? data.error : data.error?.message || 'Job failed';
        }
      }
    } catch (err) {
      // A stale poll's rejection must not fail or stop the new job.
      if (myGen !== pollGeneration) return;
      stopPolling();
      // Handle 404 JOB_NOT_FOUND errors from the API
      if (axios.isAxiosError(err) && err.response?.status === 404) {
        const data = err.response.data;
        if (data?.error === 'JOB_NOT_FOUND') {
          error.value = data.message || 'Job not found or expired';
          status.value = 'failed';
          return;
        }
      }
      error.value = 'Failed to check job status';
      status.value = 'failed';
    } finally {
      // Release single-flight only if this poll still owns the generation slot.
      if (inFlightGeneration === myGen) inFlightGeneration = null;
    }
  }

  /**
   * Start tracking a job by its ID
   */
  function startJob(newJobId: string): void {
    // New job → new generation, so a poll still in flight for the previous job
    // is ignored when it resolves and cannot touch this job's state.
    pollGeneration += 1;
    jobId.value = newJobId;
    status.value = 'accepted';
    step.value = 'Job submitted, starting...';
    error.value = null;
    progress.value = { current: 0, total: 0 };
    startTime.value = Date.now();
    elapsedSeconds.value = 0;

    resumePolling();
    resumeTimer();
  }

  /**
   * Stop all polling and timers
   */
  function stopPolling(): void {
    // Cancellation (public stop, terminal state, reset, or unmount) invalidates
    // any in-flight poll: bumping the generation makes its late response a no-op
    // so it cannot re-mutate state or resume/stop the shared interval.
    pollGeneration += 1;
    pausePolling();
    pauseTimer();
  }

  /**
   * Reset all state to initial values
   */
  function reset(): void {
    stopPolling();
    jobId.value = null;
    status.value = 'idle';
    step.value = '';
    progress.value = { current: 0, total: 0 };
    error.value = null;
    startTime.value = null;
    elapsedSeconds.value = 0;
  }

  // Cleanup on unmount as a safety net (VueUse already handles interval cleanup)
  onUnmounted(() => {
    stopPolling();
  });

  return {
    // State
    jobId,
    status,
    step,
    progress,
    error,
    elapsedSeconds,

    // Computed
    hasRealProgress,
    progressPercent,
    elapsedTimeDisplay,
    progressVariant,
    statusBadgeClass,
    isLoading,
    isPolling,

    // Methods
    startJob,
    stopPolling,
    reset,
  };
}

export default useAsyncJob;

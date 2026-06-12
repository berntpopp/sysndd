// Regeneration-job orchestration for the LLM Administration view. Extracted
// from ManageLLM.vue so the view stays a thinner shell. Owns the per-cluster
// async job runners, session-scoped job persistence/rehydration, tracker
// wiring, and completion watchers. LLM summaries regenerated here are
// admin-generated cached content; this composable only manages job lifecycle.

import { computed, watch, type ComputedRef, type Ref } from 'vue';
import { useAsyncJob } from '@/composables/useAsyncJob';
import type { ClusterType, RegenerationJobResponse } from '@/types/llm';

type RegenerationFeedbackVariant = 'success' | 'danger' | 'info' | 'warning';

type RegenerationRunner = ReturnType<typeof useAsyncJob>;

export interface VisibleRegenerationJob {
  type: ClusterType;
  label: string;
  runner: RegenerationRunner;
}

export interface UseLlmRegenerationJobsOptions {
  // Toast helper from the host view; kept generic to avoid a hard dependency.
  makeToast: (message: string, title: string, variant: string) => void;
  // Refreshes cache statistics after a job completes.
  fetchCacheStats: () => Promise<unknown>;
}

export interface UseLlmRegenerationJobs {
  regenerationFeedback: Ref<string>;
  regenerationFeedbackVariant: Ref<RegenerationFeedbackVariant>;
  regenerationFeedbackIcon: ComputedRef<string>;
  isAnyRegenerationLoading: ComputedRef<boolean>;
  visibleRegenerationJobs: ComputedRef<VisibleRegenerationJob[]>;
  functionalRegenerationJob: RegenerationRunner;
  phenotypeRegenerationJob: RegenerationRunner;
  rehydrateRegenerationJobs: () => void;
  startRegenerationTrackers: (
    result: RegenerationJobResponse,
    requestedType: ClusterType | 'all'
  ) => void;
}

const REGENERATION_STORAGE_KEY = 'sysndd.llm.activeRegenerationJobs.v1';

type StoredRegenerationJobs = Partial<Record<ClusterType, string>>;

const regenerationJobLabels: Record<ClusterType, string> = {
  functional: 'Functional regeneration',
  phenotype: 'Phenotype regeneration',
};

function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

function getSessionStorage(): Storage | null {
  return typeof window === 'undefined' ? null : window.sessionStorage;
}

function readStoredRegenerationJobs(): StoredRegenerationJobs {
  const storage = getSessionStorage();
  if (!storage) return {};

  try {
    const parsed = JSON.parse(storage.getItem(REGENERATION_STORAGE_KEY) || '{}') as unknown;
    if (!parsed || typeof parsed !== 'object') return {};

    return (['functional', 'phenotype'] as ClusterType[]).reduce<StoredRegenerationJobs>(
      (jobs, type) => {
        const jobId = (parsed as Record<string, unknown>)[type];
        if (typeof jobId === 'string' && jobId.length > 0) {
          jobs[type] = jobId;
        }
        return jobs;
      },
      {}
    );
  } catch {
    return {};
  }
}

function writeStoredRegenerationJobs(jobs: StoredRegenerationJobs) {
  const storage = getSessionStorage();
  if (!storage) return;

  if (Object.keys(jobs).length === 0) {
    storage.removeItem(REGENERATION_STORAGE_KEY);
    return;
  }

  storage.setItem(REGENERATION_STORAGE_KEY, JSON.stringify(jobs));
}

function persistRegenerationJob(type: ClusterType, jobId: string) {
  writeStoredRegenerationJobs({
    ...readStoredRegenerationJobs(),
    [type]: jobId,
  });
}

function clearPersistedRegenerationJob(type: ClusterType) {
  const jobs = readStoredRegenerationJobs();
  delete jobs[type];
  writeStoredRegenerationJobs(jobs);
}

function requestedClusterTypes(type: ClusterType | 'all'): ClusterType[] {
  return type === 'all' ? ['functional', 'phenotype'] : [type];
}

function jobIdFromRegenerationResult(result: RegenerationJobResponse, type: ClusterType) {
  return result.results?.[type]?.job_id ?? null;
}

export function useLlmRegenerationJobs(
  options: UseLlmRegenerationJobsOptions,
  feedback: {
    regenerationFeedback: Ref<string>;
    regenerationFeedbackVariant: Ref<RegenerationFeedbackVariant>;
  }
): UseLlmRegenerationJobs {
  const { makeToast, fetchCacheStats } = options;
  const { regenerationFeedback, regenerationFeedbackVariant } = feedback;

  const jobStatusUrl = (jobId: string) => `/api/jobs/${encodeURIComponent(jobId)}/status`;

  // Async job tracking for regeneration. The LLM endpoint can submit one child
  // job per cluster type, so each type gets its own visible tracker.
  const functionalRegenerationJob = useAsyncJob(jobStatusUrl);
  const phenotypeRegenerationJob = useAsyncJob(jobStatusUrl);

  const regenerationJobs: Record<ClusterType, RegenerationRunner> = {
    functional: functionalRegenerationJob,
    phenotype: phenotypeRegenerationJob,
  };

  const isAnyRegenerationLoading = computed(() =>
    Object.values(regenerationJobs).some((job) => job.isLoading.value)
  );

  const visibleRegenerationJobs = computed<VisibleRegenerationJob[]>(() =>
    (Object.keys(regenerationJobs) as ClusterType[])
      .map((type) => ({
        type,
        label: regenerationJobLabels[type],
        runner: regenerationJobs[type],
      }))
      .filter((job) => Boolean(job.runner.jobId.value))
  );

  const regenerationFeedbackIcon = computed(() => {
    switch (regenerationFeedbackVariant.value) {
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

  function rehydrateRegenerationJobs() {
    const storedJobs = readStoredRegenerationJobs();
    const resumed = (Object.keys(regenerationJobs) as ClusterType[]).filter((type) => {
      const jobId = storedJobs[type];
      if (!jobId || regenerationJobs[type].jobId.value) return false;

      regenerationJobs[type].startJob(jobId);
      return true;
    });

    if (resumed.length) {
      regenerationFeedback.value = `Resumed tracking ${resumed
        .map((type) => regenerationJobLabels[type].toLowerCase())
        .join(' and ')} from this browser session.`;
      regenerationFeedbackVariant.value = 'info';
    }
  }

  function startRegenerationTrackers(
    result: RegenerationJobResponse,
    requestedType: ClusterType | 'all'
  ) {
    const started: ClusterType[] = [];
    const skipped: string[] = [];

    requestedClusterTypes(requestedType).forEach((type) => {
      const child = result.results?.[type];
      const jobId = jobIdFromRegenerationResult(result, type);

      if (jobId) {
        const unwrappedJobId = unwrapValue(jobId);
        regenerationJobs[type].reset();
        regenerationJobs[type].startJob(unwrappedJobId);
        persistRegenerationJob(type, unwrappedJobId);
        started.push(type);
        return;
      }

      if (child?.skipped) {
        skipped.push(
          `${regenerationJobLabels[type]} skipped: ${child.reason || 'No job created'}`
        );
      }
    });

    if (started.length) {
      regenerationFeedback.value = `Tracking ${started
        .map((type) => regenerationJobLabels[type].toLowerCase())
        .join(' and ')}. You can leave this page and return to Logs or Cache later.`;
      regenerationFeedbackVariant.value = 'info';
      return;
    }

    if (skipped.length) {
      regenerationFeedback.value = skipped.join(' ');
      regenerationFeedbackVariant.value = 'warning';
      return;
    }

    regenerationFeedback.value =
      'No regeneration job was created. Check the API response and logs.';
    regenerationFeedbackVariant.value = 'warning';
  }

  watch(
    () => functionalRegenerationJob.status.value,
    async (newStatus) => {
      if (newStatus === 'completed') {
        clearPersistedRegenerationJob('functional');
        regenerationFeedback.value =
          'Functional regeneration completed. Cache statistics refreshed.';
        regenerationFeedbackVariant.value = 'success';
        makeToast('Functional regeneration completed', 'Success', 'success');
        await fetchCacheStats();
      } else if (newStatus === 'failed') {
        clearPersistedRegenerationJob('functional');
        regenerationFeedback.value =
          functionalRegenerationJob.error.value || 'Functional regeneration failed.';
        regenerationFeedbackVariant.value = 'danger';
        makeToast(regenerationFeedback.value, 'Error', 'danger');
      }
    }
  );

  watch(
    () => phenotypeRegenerationJob.status.value,
    async (newStatus) => {
      if (newStatus === 'completed') {
        clearPersistedRegenerationJob('phenotype');
        regenerationFeedback.value =
          'Phenotype regeneration completed. Cache statistics refreshed.';
        regenerationFeedbackVariant.value = 'success';
        makeToast('Phenotype regeneration completed', 'Success', 'success');
        await fetchCacheStats();
      } else if (newStatus === 'failed') {
        clearPersistedRegenerationJob('phenotype');
        regenerationFeedback.value =
          phenotypeRegenerationJob.error.value || 'Phenotype regeneration failed.';
        regenerationFeedbackVariant.value = 'danger';
        makeToast(regenerationFeedback.value, 'Error', 'danger');
      }
    }
  );

  return {
    regenerationFeedback,
    regenerationFeedbackVariant,
    regenerationFeedbackIcon,
    isAnyRegenerationLoading,
    visibleRegenerationJobs,
    functionalRegenerationJob,
    phenotypeRegenerationJob,
    rehydrateRegenerationJobs,
    startRegenerationTrackers,
  };
}

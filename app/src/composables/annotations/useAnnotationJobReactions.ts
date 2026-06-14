// composables/annotations/useAnnotationJobReactions.ts
//
// Reaction layer for the ManageAnnotations async jobs: watches each job's
// status and, on completion/failure, toasts and refreshes the relevant data.
// Extracted from ManageAnnotations.vue so the (oversized) SFC stays focused on
// composition + actions. Behaviour is a faithful port of the inline watchers.

import { watch, type Ref } from 'vue';
import type { useAsyncJob } from '@/composables/useAsyncJob';
import useToast from '@/composables/useToast';
import * as api from './useAnnotationsApi';
import type { OntologyBlockedState, UserOption } from '@/components/annotations/OntologyAnnotationsCard.vue';

type AsyncJob = ReturnType<typeof useAsyncJob>;
type MakeToast = ReturnType<typeof useToast>['makeToast'];

export interface AnnotationJobReactionDeps {
  ontologyJob: AsyncJob;
  forceApplyJob: AsyncJob;
  hgncJob: AsyncJob;
  comparisonsJob: AsyncJob;
  publicationRefreshJob: AsyncJob;
  ontologyBlocked: Ref<OntologyBlockedState | null>;
  forceApplyUserOptions: Ref<UserOption[]>;
  loadingForceApplyUsers: Ref<boolean>;
  makeToast: MakeToast;
  reload: {
    annotationDates: () => void;
    jobHistory: () => void;
    publicationStats: () => void;
    filteredCount: () => void;
    comparisonsMetadata: () => void;
  };
}

export function useAnnotationJobReactions(deps: AnnotationJobReactionDeps): void {
  const {
    ontologyJob,
    forceApplyJob,
    hgncJob,
    comparisonsJob,
    publicationRefreshJob,
    ontologyBlocked,
    forceApplyUserOptions,
    loadingForceApplyUsers,
    makeToast,
    reload,
  } = deps;

  const toastDone = (msg: string): void => makeToast(msg, 'Success', 'success');
  const toastFail = (msg: string): void => makeToast(msg, 'Error', 'danger');

  // Ontology update has the Phase-76 "blocked" branch, so it is handled
  // explicitly rather than via the simple done/fail helper below.
  watch(
    () => ontologyJob.status.value,
    async (newStatus) => {
      if (newStatus === 'completed') {
        try {
          const jobId = ontologyJob.jobId.value;
          if (jobId) {
            const result = await api.fetchOntologyJobResult(jobId);
            if (result && result.kind === 'blocked') {
              ontologyBlocked.value = result.state;
              forceApplyUserOptions.value = [];
              loadingForceApplyUsers.value = true;
              try {
                forceApplyUserOptions.value = await api.fetchForceApplyUsers();
              } catch {
                forceApplyUserOptions.value = [];
              } finally {
                loadingForceApplyUsers.value = false;
              }
              makeToast(
                `Ontology update blocked: ${result.state.critical_count} critical changes`,
                'Update Blocked',
                'warning'
              );
              reload.jobHistory();
              return;
            }
            const autoFixes = result && result.kind === 'ok' ? result.autoFixesApplied : 0;
            if (autoFixes > 0) {
              toastDone(`Ontology updated. ${autoFixes} entity version(s) auto-fixed.`);
            } else {
              toastDone('Ontology annotations updated successfully');
            }
          }
        } catch {
          toastDone('Ontology annotations updated successfully');
        }
        reload.annotationDates();
        reload.jobHistory();
      } else if (newStatus === 'failed') {
        toastFail(ontologyJob.error.value || 'Ontology update failed');
        reload.jobHistory();
      }
    }
  );

  // Simple done/fail reactions for the remaining jobs.
  function wire(job: AsyncJob, doneMsg: string, failMsg: string, onDone?: () => void): void {
    watch(
      () => job.status.value,
      (newStatus) => {
        if (newStatus === 'completed') {
          toastDone(doneMsg);
          onDone?.();
          reload.jobHistory();
        } else if (newStatus === 'failed') {
          toastFail(job.error.value || failMsg);
          reload.jobHistory();
        }
      }
    );
  }

  wire(
    forceApplyJob,
    'Ontology force-applied successfully. Re-review batch created for critical entities.',
    'Force-apply failed',
    () => {
      ontologyBlocked.value = null;
      reload.annotationDates();
    }
  );
  wire(hgncJob, 'HGNC data updated successfully', 'HGNC update failed', reload.annotationDates);
  wire(
    publicationRefreshJob,
    'Publications refreshed successfully',
    'Publication refresh failed',
    () => {
      reload.publicationStats();
      reload.filteredCount();
    }
  );
  wire(
    comparisonsJob,
    'Comparisons data refreshed successfully',
    'Comparisons refresh failed',
    reload.comparisonsMetadata
  );
}

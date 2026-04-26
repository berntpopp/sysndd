// app/src/views/curate/composables/useEntityMutations.ts
import { ref } from 'vue';
import { apiClient } from '@/api/client';

import Submission from '@/assets/js/classes/submission/submissionSubmission';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

const apiBase = import.meta.env.VITE_API_URL ?? '';

export type SubmittingState = 'rename' | 'deactivate' | 'review' | 'status' | null;

export interface UseEntityMutationsOptions {
  onToast?: (...args: unknown[]) => void;
  onAnnounce?: (msg: string, politeness?: 'polite' | 'assertive') => void;
}

export interface RenameArgs {
  entity_info: any;
  ontology_input: string | null;
}

export interface DeactivateArgs {
  entity_info: any;
  deactivate_check: boolean;
  replace_entity_input: number | null;
}

export interface SubmitReviewArgs {
  review_info: any;
  select_phenotype: string[];
  select_variation: string[];
  select_additional_references: string[];
  select_gene_reviews: string[];
}

export function useEntityMutations(options: UseEntityMutationsOptions = {}) {
  const { onToast, onAnnounce } = options;
  const submitting = ref<SubmittingState>(null);

  async function rename(args: RenameArgs): Promise<void> {
    submitting.value = 'rename';
    args.entity_info.disease_ontology_id_version = args.ontology_input;
    const submission = new Submission(args.entity_info);
    try {
      const response = await apiClient.raw.post(`${apiBase}/api/entity/rename`, {
        rename_json: submission,
      });
      onToast?.(
        `The new disease name for this entity has been submitted (status ${response.status} (${response.statusText}).`,
        'Success',
        'success',
      );
      onAnnounce?.('Disease name updated successfully');
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      onAnnounce?.('Failed to update disease name', 'assertive');
      throw e;
    } finally {
      submitting.value = null;
    }
  }

  async function deactivate(args: DeactivateArgs): Promise<void> {
    submitting.value = 'deactivate';
    args.entity_info.is_active = args.deactivate_check ? 0 : 1;
    args.entity_info.replaced_by =
      args.replace_entity_input === null ? null : args.replace_entity_input;
    const submission = new Submission(args.entity_info);
    try {
      const response = await apiClient.raw.post(`${apiBase}/api/entity/deactivate`, {
        deactivate_json: submission,
      });
      onToast?.(
        `The deactivation for this entity has been submitted (status ${response.status} (${response.statusText}).`,
        'Success',
        'success',
      );
      onAnnounce?.('Entity deactivation submitted successfully');
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      onAnnounce?.('Failed to deactivate entity', 'assertive');
      throw e;
    } finally {
      submitting.value = null;
    }
  }

  async function submitReview(args: SubmitReviewArgs): Promise<void> {
    submitting.value = 'review';
    const additional_clean = args.select_additional_references.map((s) => s.replace(/\s+/g, ''));
    const gene_reviews_clean = args.select_gene_reviews.map((s) => s.replace(/\s+/g, ''));
    const replace_literature = new Literature(additional_clean, gene_reviews_clean);

    const replace_phenotype = args.select_phenotype.map(
      (item) => new Phenotype(item.split('-')[1], item.split('-')[0]),
    );
    const replace_variation = args.select_variation.map(
      (item) => new Variation(item.split('-')[1], item.split('-')[0]),
    );

    args.review_info.literature = replace_literature;
    args.review_info.phenotypes = replace_phenotype;
    args.review_info.variation_ontology = replace_variation;

    try {
      const response = await apiClient.raw.post(`${apiBase}/api/review/create`, {
        review_json: args.review_info,
      });
      onToast?.(
        `The new review for this entity has been submitted (status ${response.status} (${response.statusText}).`,
        'Success',
        'success',
      );
      onAnnounce?.('Review submitted successfully');
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      onAnnounce?.('Failed to submit review', 'assertive');
      throw e;
    } finally {
      submitting.value = null;
    }
  }

  function setSubmittingState(state: SubmittingState): void {
    submitting.value = state;
  }

  return { submitting, rename, deactivate, submitReview, setSubmittingState };
}

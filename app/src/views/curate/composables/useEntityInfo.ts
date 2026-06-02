// app/src/views/curate/composables/useEntityInfo.ts
import { computed, ref } from 'vue';
import {
  listEntities,
  getEntityReview,
  getEntityPhenotypes,
  getEntityVariation,
  getEntityPublications,
  getEntityStatus,
} from '@/api/entity';

import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

export interface UseEntityInfoOptions {
  onToast?: (...args: unknown[]) => void;
}

interface ReviewSnapshot {
  synopsis: string;
  comment: string;
  phenotypes: string[];
  variationOntology: string[];
  publications: string[];
  genereviews: string[];
}

// Fields loadEntity() asks the entity-LIST endpoint (GET /api/entity/) for.
// This list MUST be a subset of the columns `ndd_entity_view` exposes
// (db/migrations/025_create_core_views.sql) + `synopsis` from the review
// left-join: the API's select_tibble_fields() hard-fails (HTTP 500) when any
// requested field is absent from the view. `is_active`, `replaced_by` and
// `details` are NOT in that view, so they must not be requested here:
//   - `details` is never read by the rename/deactivate handlers.
//   - `is_active`/`replaced_by` are set explicitly by the deactivate mutation
//     (useEntityMutations) before submit, so they don't need to be loaded.
const ENTITY_MUTATION_FIELDS = [
  'entity_id',
  'symbol',
  'hgnc_id',
  'disease_ontology_name',
  'disease_ontology_id_version',
  'hpo_mode_of_inheritance_term',
  'hpo_mode_of_inheritance_term_name',
  'category',
  'ndd_phenotype',
  'ndd_phenotype_word',
].join(',');

const arrEqual = (a: string[], b: string[]) => {
  if (a.length !== b.length) return false;
  const sa = [...a].sort();
  const sb = [...b].sort();
  return sa.every((v, i) => v === sb[i]);
};

export function useEntityInfo(options: UseEntityInfoOptions = {}) {
  const { onToast } = options;

  const entity_info = ref<Record<string, any>>({});
  const review_info = ref<any>(new Review());
  const status_info = ref<any>(new Status());

  const select_phenotype = ref<string[]>([]);
  const select_variation = ref<string[]>([]);
  const select_additional_references = ref<string[]>([]);
  const select_gene_reviews = ref<string[]>([]);

  const reviewLoadedData = ref<ReviewSnapshot | null>(null);

  const hasReviewChanges = computed(() => {
    if (!reviewLoadedData.value) return false;
    const snap = reviewLoadedData.value;
    return (
      (review_info.value.synopsis || '') !== snap.synopsis ||
      (review_info.value.comment || '') !== snap.comment ||
      !arrEqual(select_phenotype.value, snap.phenotypes) ||
      !arrEqual(select_variation.value, snap.variationOntology) ||
      !arrEqual(select_additional_references.value, snap.publications) ||
      !arrEqual(select_gene_reviews.value, snap.genereviews)
    );
  });

  async function loadEntity(entityId: number): Promise<void> {
    try {
      const response: any = await listEntities({
        filter: `equals(entity_id,${entityId})`,
        fields: ENTITY_MUTATION_FIELDS,
        page_size: '1',
        compact: true,
      });
      const data = response?.data;
      if (!Array.isArray(data) || data.length === 0) {
        onToast?.(`Entity ${entityId} not found`, 'Error', 'danger');
        entity_info.value = {};
        return;
      }
      entity_info.value = data[0];
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
      entity_info.value = {};
    }
  }

  async function loadReview(entityId: number): Promise<void> {
    try {
      const review_data: any = await getEntityReview(entityId);
      const phenotypes_data: any = await getEntityPhenotypes(entityId);
      const variation_data: any = await getEntityVariation(entityId);
      const publications_data: any = await getEntityPublications(entityId);

      const new_phenotype = phenotypes_data.map(
        (item: any) => new Phenotype(item.phenotype_id, item.modifier_id)
      );
      select_phenotype.value = phenotypes_data.map(
        (item: any) => `${item.modifier_id}-${item.phenotype_id}`
      );

      const new_variation = variation_data.map(
        (item: any) => new Variation(item.vario_id, item.modifier_id)
      );
      select_variation.value = variation_data.map(
        (item: any) => `${item.modifier_id}-${item.vario_id}`
      );

      const literature_gene_reviews = publications_data
        .filter((item: any) => item.publication_type === 'gene_review')
        .map((item: any) => item.publication_id);
      const literature_additional_references = publications_data
        .filter((item: any) => item.publication_type === 'additional_references')
        .map((item: any) => item.publication_id);

      select_additional_references.value = literature_additional_references;
      select_gene_reviews.value = literature_gene_reviews;

      const new_literature = new Literature(
        literature_additional_references,
        literature_gene_reviews
      );

      review_info.value = new Review(
        review_data[0].synopsis,
        new_literature,
        new_phenotype,
        new_variation,
        review_data[0].comment
      );
      review_info.value.review_id = review_data[0].review_id;
      review_info.value.entity_id = review_data[0].entity_id;

      reviewLoadedData.value = {
        synopsis: review_info.value.synopsis || '',
        comment: review_info.value.comment || '',
        phenotypes: [...select_phenotype.value],
        variationOntology: [...select_variation.value],
        publications: [...select_additional_references.value],
        genereviews: [...select_gene_reviews.value],
      };
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
    }
  }

  async function loadStatus(entityId: number): Promise<void> {
    try {
      const status_data: any = await getEntityStatus(entityId);
      status_info.value = new Status(
        status_data[0].category_id,
        status_data[0].comment,
        status_data[0].problematic
      );
      status_info.value.status_id = status_data[0].status_id;
      status_info.value.entity_id = status_data[0].entity_id;
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
    }
  }

  function reset(): void {
    entity_info.value = {};
    review_info.value = new Review();
    status_info.value = new Status();
    select_phenotype.value = [];
    select_variation.value = [];
    select_additional_references.value = [];
    select_gene_reviews.value = [];
    reviewLoadedData.value = null;
  }

  return {
    entity_info,
    review_info,
    status_info,
    select_phenotype,
    select_variation,
    select_additional_references,
    select_gene_reviews,
    reviewLoadedData,
    hasReviewChanges,
    loadEntity,
    loadReview,
    loadStatus,
    reset,
  };
}

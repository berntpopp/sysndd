// composables/review/useReviewApprovalActions.ts
/**
 * Composable for the HTTP plumbing behind Phase E.E5 `ApproveReview.vue`.
 *
 * The composable is factored out specifically so that Phase E.E6 can reuse
 * the load/submit functions behind the generic `ApprovalTableView`. Every
 * function takes an explicit `axiosClient` parameter so the view's
 * `getAxios()` bridge (which resolves Vue Test Utils mocks via
 * `getCurrentInstance().proxy.axios`) wins over a module-level import.
 *
 * The C1 spec drives the view's methods through `wrapper.vm.<method>()` —
 * this composable stays side-effect-free (no module-level axios calls).
 */

import type { AxiosInstance } from 'axios';
import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';
import Phenotype from '@/assets/js/classes/submission/submissionPhenotype';
import Variation from '@/assets/js/classes/submission/submissionVariation';
import Literature from '@/assets/js/classes/submission/submissionLiterature';

type AxiosLike = AxiosInstance | Record<string, unknown>;

// v11.0 closeout F2a: the inline `authHeaders()` helper that read the
// session token from localStorage and emitted it as an Authorization
// header has been removed. Every PUT/POST below used to pass
// `{ headers: authHeaders() }`; those explicit header options are gone.
// The `apiClient` request interceptor (`@/api/client`) reads
// `useAuth().token.value` and injects the Bearer header on every outbound
// call against the shared axios singleton — which the spec-provided
// `axiosClient` (either the real singleton or a Vitest mock)
// participates in.

export interface ReviewInfoPartial {
  review_id?: number | null;
  entity_id?: number | null;
  review_user_name?: string | null;
  review_user_role?: string | null;
  synopsis?: string | null;
  comment?: string | null;
  literature?: unknown;
  phenotypes?: unknown;
  variation_ontology?: unknown;
}

export interface StatusInfoPartial {
  category_id?: number | null;
  comment?: string | null;
  problematic?: boolean | null;
  status_id?: number | null;
  entity_id?: number | null;
  status_user_name?: string | null;
  status_user_role?: string | null;
  status_date?: string | null;
  status_approved?: number | null;
}

export interface ReviewLoadedSnapshot {
  synopsis: string;
  comment: string;
  phenotypes: string[];
  variationOntology: string[];
  publications: string[];
  genereviews: string[];
}

export interface LoadedReview {
  reviewInfo: ReviewInfoPartial;
  selectPhenotype: string[];
  selectVariation: string[];
  selectAdditionalReferences: string[];
  selectGeneReviews: string[];
  snapshot: ReviewLoadedSnapshot;
}

export interface LoadedStatus {
  statusInfo: StatusInfoPartial;
  snapshot: { category_id: number | null; comment: string; problematic: boolean };
}

const apiBase = (): string => import.meta.env.VITE_API_URL || '';

/**
 * Fetch the full review detail (review row + phenotypes + variation +
 * publications) for the EditReviewModal. Returns a composed
 * {reviewInfo, snapshot, ...arrays} payload that the caller assigns to its
 * reactive refs.
 */
export async function fetchReviewDetail(
  axiosClient: AxiosLike,
  reviewId: number
): Promise<LoadedReview> {
  const ax = axiosClient as AxiosInstance;
  const base = `${apiBase()}/api/review/${reviewId}`;
  const r1 = await ax.get(base);
  const r2 = await ax.get(`${base}/phenotypes`);
  const r3 = await ax.get(`${base}/variation`);
  const r4 = await ax.get(`${base}/publications`);

  const selectPhenotype = r2.data.map(
    (it: { phenotype_id: number; modifier_id: number }) => `${it.modifier_id}-${it.phenotype_id}`
  );
  const selectVariation = r3.data.map(
    (it: { vario_id: number; modifier_id: number }) => `${it.modifier_id}-${it.vario_id}`
  );
  const genereviews = r4.data
    .filter((it: { publication_type: string }) => it.publication_type === 'gene_review')
    .map((it: { publication_id: string }) => it.publication_id);
  const additional = r4.data
    .filter((it: { publication_type: string }) => it.publication_type === 'additional_references')
    .map((it: { publication_id: string }) => it.publication_id);

  const newPhenotype = r2.data.map(
    (it: { phenotype_id: number; modifier_id: number }) =>
      new Phenotype(it.phenotype_id, it.modifier_id)
  );
  const newVariation = r3.data.map(
    (it: { vario_id: number; modifier_id: number }) => new Variation(it.vario_id, it.modifier_id)
  );
  const literature = new Literature(additional, genereviews);
  const row = r1.data[0];
  const composed = new Review(
    row.synopsis,
    literature,
    newPhenotype,
    newVariation,
    row.comment
  ) as ReviewInfoPartial;
  composed.review_id = row.review_id;
  composed.entity_id = row.entity_id;
  composed.review_user_name = row.review_user_name;
  composed.review_user_role = row.review_user_role;

  return {
    reviewInfo: composed,
    selectPhenotype,
    selectVariation,
    selectAdditionalReferences: additional,
    selectGeneReviews: genereviews,
    snapshot: {
      synopsis: composed.synopsis || '',
      comment: composed.comment || '',
      phenotypes: [...selectPhenotype],
      variationOntology: [...selectVariation],
      publications: [...additional],
      genereviews: [...genereviews],
    },
  };
}

/** Fetch the status detail for EditStatusModal. */
export async function fetchStatusDetail(
  axiosClient: AxiosLike,
  statusId: number
): Promise<LoadedStatus> {
  const ax = axiosClient as AxiosInstance;
  const r = await ax.get(`${apiBase()}/api/status/${statusId}`);
  const row = r.data[0];
  const composed = new Status(row.category_id, row.comment, row.problematic) as StatusInfoPartial;
  composed.status_id = row.status_id;
  composed.entity_id = row.entity_id;
  composed.status_user_role = row.status_user_role;
  composed.status_user_name = row.status_user_name;
  composed.status_date = row.status_date;
  composed.status_approved = row.status_approved;
  return {
    statusInfo: composed,
    snapshot: {
      category_id: composed.category_id ?? null,
      comment: composed.comment || '',
      problematic: Boolean(composed.problematic),
    },
  };
}

/** Fetch the entity row used in modal headers. */
export async function fetchEntity(axiosClient: AxiosLike, entityId: number): Promise<unknown> {
  const ax = axiosClient as AxiosInstance;
  const r = await ax.get(`${apiBase()}/api/entity?filter=equals(entity_id,${entityId})`);
  return r.data.data?.[0];
}

/** Approve a single review. */
export function approveReview(axiosClient: AxiosLike, reviewId: number | string | undefined) {
  const ax = axiosClient as AxiosInstance;
  return ax.put(`${apiBase()}/api/review/approve/${reviewId}?review_ok=true`, {});
}

/** Dismiss (reject) a single review. */
export function dismissReview(axiosClient: AxiosLike, reviewId: number | string | undefined) {
  const ax = axiosClient as AxiosInstance;
  return ax.put(`${apiBase()}/api/review/approve/${reviewId}?review_ok=false`, {});
}

/** Approve the status paired with a review (status-change propagation). */
export function approveStatus(axiosClient: AxiosLike, statusId: number | string | undefined) {
  const ax = axiosClient as AxiosInstance;
  return ax.put(`${apiBase()}/api/status/approve/${statusId}?status_ok=true`, {});
}

/** Bulk-approve every pending review (admin only). */
export function approveAllReviews(axiosClient: AxiosLike) {
  const ax = axiosClient as AxiosInstance;
  return ax.put(`${apiBase()}/api/review/approve/all?review_ok=true`, {});
}

export interface ReviewSubmitPayload {
  reviewInfo: ReviewInfoPartial;
  selectPhenotype: string[];
  selectVariation: string[];
  selectAdditionalReferences: string[];
  selectGeneReviews: string[];
  sanitize: (v: string) => string;
}

/**
 * Submit a review update (after the user edits the form in EditReviewModal).
 * Mutates the passed `reviewInfo` with the recomputed literature/phenotype/
 * variation so the caller can resync its snapshot after the await resolves.
 */
export function submitReviewUpdate(axiosClient: AxiosLike, payload: ReviewSubmitPayload) {
  const ax = axiosClient as AxiosInstance;
  const arClean = payload.selectAdditionalReferences.map(payload.sanitize);
  const grClean = payload.selectGeneReviews.map(payload.sanitize);
  const literature = new Literature(arClean, grClean);
  const phenotype = payload.selectPhenotype.map(
    (it) => new Phenotype(Number(it.split('-')[1]), Number(it.split('-')[0]))
  );
  const variation = payload.selectVariation.map(
    (it) => new Variation(Number(it.split('-')[1]), Number(it.split('-')[0]))
  );
  payload.reviewInfo.literature = literature;
  payload.reviewInfo.phenotypes = phenotype;
  payload.reviewInfo.variation_ontology = variation;
  return ax.put(`${apiBase()}/api/review/update`, { review_json: payload.reviewInfo });
}

/** Submit a status update (non-approved path). */
export function submitStatusUpdate(axiosClient: AxiosLike, statusInfo: StatusInfoPartial) {
  const ax = axiosClient as AxiosInstance;
  return ax.put(`${apiBase()}/api/status/update`, { status_json: statusInfo });
}

/** Submit a status create (approved path — spawns a new status row). */
export function submitStatusCreate(axiosClient: AxiosLike, statusInfo: StatusInfoPartial) {
  const ax = axiosClient as AxiosInstance;
  return ax.post(`${apiBase()}/api/status/create`, { status_json: statusInfo });
}

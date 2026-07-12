// app/src/views/review/composables/useReviewData.ts
//
// W6 of v11.1 finish-hardening — data-loading composable for `Review.vue`.
//
// Owns:
//   - the re-review table fetch (`/api/re_review/table?curate=*`)
//   - the three lookup-list fetches that feed dropdowns/treeselects in the
//     modals (phenotype / variation_ontology / status — all `?tree=true`)
//   - the per-entity context lookup (`/api/entity/?filter=equals(entity_id,...)`)
//   - the per-review and per-status metadata lookups consumed by modal
//     footers (`/api/review/<id>` + `/api/status/<id>`)
//
// Does NOT own modal state (see `useReviewModals`), filter state (see
// `useReviewFilters`), or mutations (see `useReviewActions`). Each public
// method returns `Promise<void>` for the same reason `Review.vue`'s legacy
// methods did: callers chain `await load(); await refresh()` patterns and
// don't need the response value back — it's already in the reactive refs.

import { reactive, ref, type Ref } from 'vue';
import { listEntities } from '@/api/entity';
import {
  listPhenotypesTree,
  listStatusCategoriesTree,
  listVariationOntologyTree,
  type TreeNode,
} from '@/api/list';
import { getReviewById } from '@/api/review';
import { getStatusById } from '@/api/status';
import { getReReviewTable, type ReReviewTableRow } from '@/api/re_review';
import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ReviewEntityInfo {
  entity_id: number;
  symbol: string;
  hgnc_id: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term_name: string;
  hpo_mode_of_inheritance_term: string;
}

export interface ReviewInfo {
  review_id: number | null;
  entity_id: number | null;
  review_user_name: string | null;
  review_user_role: string | null;
  review_date: string | null;
  re_review_review_saved: number | null;
  synopsis?: string;
  literature?: unknown;
  phenotypes?: unknown;
  variation_ontology?: unknown;
  comment?: unknown;
}

export interface UseReviewDataOptions {
  /**
   * Optional error sink. Called once per rejected fetch with the original
   * error. Lets `Review.vue` route failures to its toast + aria-live
   * announcer without `useReviewData` having to know about either.
   */
  onError?: (err: unknown) => void;
}

export interface UseReviewData {
  // Table state
  items: Ref<ReReviewTableRow[]>;
  totalRows: Ref<number>;
  isBusy: Ref<boolean>;
  loading: Ref<boolean>;

  // Lookup lists
  phenotypes_options: Ref<TreeNode[]>;
  variation_ontology_options: Ref<TreeNode[]>;
  status_options: Ref<TreeNode[]>;

  // Entity / review / status context (consumed by modal footers)
  entity_info: ReviewEntityInfo;
  review_info: ReviewInfo;
  status_info: Status & {
    status_id?: number | null;
    entity_id?: number | null;
    status_user_name?: string | null;
    status_user_role?: string | null;
    status_date?: string | null;
    re_review_status_saved?: number | null;
  };
  loading_status_modal: Ref<boolean>;

  // Loaders
  loadReReviewData: (curate: boolean) => Promise<void>;
  loadPhenotypesList: () => Promise<void>;
  loadVariationOntologyList: () => Promise<void>;
  loadStatusList: () => Promise<void>;
  getEntity: (entity_input: number | string) => Promise<void>;
  loadReviewInfo: (review_id: number | string, re_review_review_saved: number) => Promise<void>;
  loadStatusInfo: (status_id: number | string, re_review_status_saved: number) => Promise<void>;

  // Reset helpers
  resetEntityContext: () => void;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const EMPTY_ENTITY_INFO: ReviewEntityInfo = {
  entity_id: 0,
  symbol: '',
  hgnc_id: '',
  disease_ontology_id_version: '',
  disease_ontology_name: '',
  hpo_mode_of_inheritance_term_name: '',
  hpo_mode_of_inheritance_term: '',
};

interface RawTreeNode {
  id: string | number;
  label: string;
  children?: Array<{ id: string | number; label: string }>;
}

interface RequestOwner {
  generation: number;
  controller: AbortController | null;
}

interface ActiveRequest {
  signal: AbortSignal;
  isCurrent: () => boolean;
}

function beginRequest(owner: RequestOwner): ActiveRequest {
  owner.generation += 1;
  owner.controller?.abort();
  const controller = new AbortController();
  const generation = owner.generation;
  owner.controller = controller;
  return {
    signal: controller.signal,
    isCurrent: () => owner.generation === generation && owner.controller === controller,
  };
}

function cancelRequest(owner: RequestOwner): void {
  owner.generation += 1;
  owner.controller?.abort();
  owner.controller = null;
}

function finishRequest(owner: RequestOwner, request: ActiveRequest): void {
  if (request.isCurrent()) owner.controller = null;
}

function isAbortError(error: unknown): boolean {
  return error instanceof DOMException && error.name === 'AbortError';
}

/**
 * The phenotype + variation_ontology APIs return a tree where the root
 * label is `present: <name>` and the children are modifiers. The view
 * presents them as `<name>` parents with `[present, uncertain, ...]`
 * children so all modifiers (including "present") are selectable. Pure
 * function — easier to test in isolation than the embedded method this
 * replaces in `Review.vue`.
 */
export function transformModifierTree(nodes: unknown): TreeNode[] {
  if (!Array.isArray(nodes)) return [];
  return nodes.map((node: RawTreeNode) => {
    const phenotypeName = node.label.replace(/^present:\s*/, '');
    const ontologyCode = String(node.id).replace(/^\d+-/, '');
    return {
      id: `parent-${ontologyCode}`,
      label: phenotypeName,
      children: [
        // Original "present" node becomes the first selectable child.
        { id: node.id, label: `present: ${phenotypeName}` },
        ...(node.children ?? []).map((child) => {
          const modifier = child.label.replace(/:\s*.*$/, '');
          return { id: child.id, label: `${modifier}: ${phenotypeName}` };
        }),
      ],
    } as TreeNode;
  });
}

// ---------------------------------------------------------------------------
// Composable
// ---------------------------------------------------------------------------

export function useReviewData(options: UseReviewDataOptions = {}): UseReviewData {
  const { onError } = options;

  // Table state
  const items = ref<ReReviewTableRow[]>([]);
  const totalRows = ref(1);
  const isBusy = ref(false);
  const loading = ref(true);

  // Lookup lists
  const phenotypes_options = ref<TreeNode[]>([]);
  const variation_ontology_options = ref<TreeNode[]>([]);
  const status_options = ref<TreeNode[]>([]);

  // Entity / review / status context
  const entity_info = reactive<ReviewEntityInfo>({ ...EMPTY_ENTITY_INFO });
  const review_info = reactive<ReviewInfo>(new Review() as ReviewInfo);
  // Initialise the legacy fields the template binds against.
  Object.assign(review_info, {
    review_id: null,
    entity_id: null,
    review_user_name: null,
    review_user_role: null,
    review_date: null,
    re_review_review_saved: null,
  });
  const status_info = reactive(new Status()) as UseReviewData['status_info'];
  const loading_status_modal = ref(true);
  const reReviewRequest: RequestOwner = { generation: 0, controller: null };
  const phenotypesRequest: RequestOwner = { generation: 0, controller: null };
  const variationRequest: RequestOwner = { generation: 0, controller: null };
  const statusListRequest: RequestOwner = { generation: 0, controller: null };
  const entityRequest: RequestOwner = { generation: 0, controller: null };
  const reviewRequest: RequestOwner = { generation: 0, controller: null };
  const statusRequest: RequestOwner = { generation: 0, controller: null };

  function reportError(err: unknown): void {
    if (onError) {
      onError(err);
    }
  }

  async function loadReReviewData(curate: boolean): Promise<void> {
    const request = beginRequest(reReviewRequest);
    isBusy.value = true;
    try {
      const payload = await getReReviewTable({ curate }, { signal: request.signal });
      if (!request.isCurrent()) return;
      // R serialises the table as `{ data, meta }`; legacy stubs may surface
      // a bare array — accept either.
      const rows = Array.isArray(payload)
        ? payload
        : ((payload as { data?: ReReviewTableRow[] } | undefined)?.data ?? []);
      items.value = rows;
      totalRows.value = rows.length;
    } catch (err) {
      if (!request.isCurrent() || isAbortError(err)) return;
      reportError(err);
    } finally {
      if (request.isCurrent()) {
        isBusy.value = false;
        loading.value = false;
        finishRequest(reReviewRequest, request);
      }
    }
  }

  async function loadPhenotypesList(): Promise<void> {
    const request = beginRequest(phenotypesRequest);
    try {
      const payload = await listPhenotypesTree({ signal: request.signal });
      if (!request.isCurrent()) return;
      phenotypes_options.value = transformModifierTree(payload);
    } catch (err) {
      if (!request.isCurrent() || isAbortError(err)) return;
      reportError(err);
      phenotypes_options.value = [];
    } finally {
      finishRequest(phenotypesRequest, request);
    }
  }

  async function loadVariationOntologyList(): Promise<void> {
    const request = beginRequest(variationRequest);
    try {
      const payload = await listVariationOntologyTree({ signal: request.signal });
      if (!request.isCurrent()) return;
      variation_ontology_options.value = transformModifierTree(payload);
    } catch (err) {
      if (!request.isCurrent() || isAbortError(err)) return;
      reportError(err);
      variation_ontology_options.value = [];
    } finally {
      finishRequest(variationRequest, request);
    }
  }

  async function loadStatusList(): Promise<void> {
    const request = beginRequest(statusListRequest);
    try {
      const payload = await listStatusCategoriesTree({ signal: request.signal });
      if (!request.isCurrent()) return;
      status_options.value = payload;
    } catch (err) {
      if (!request.isCurrent() || isAbortError(err)) return;
      reportError(err);
    } finally {
      finishRequest(statusListRequest, request);
    }
  }

  async function getEntity(entity_input: number | string): Promise<void> {
    const request = beginRequest(entityRequest);
    try {
      const payload = await listEntities({
        filter: `equals(entity_id,${entity_input})`,
      }, { signal: request.signal });
      if (!request.isCurrent()) return;
      const [first] = payload.data as Array<Partial<ReviewEntityInfo>>;
      if (first) {
        Object.assign(entity_info, EMPTY_ENTITY_INFO, first);
      }
    } catch (err) {
      if (!request.isCurrent() || isAbortError(err)) return;
      reportError(err);
    } finally {
      finishRequest(entityRequest, request);
    }
  }

  async function loadReviewInfo(
    review_id: number | string,
    re_review_review_saved: number
  ): Promise<void> {
    const request = beginRequest(reviewRequest);
    try {
      const rows = await getReviewById(review_id, { signal: request.signal });
      if (!request.isCurrent()) return;
      if (rows && rows.length > 0) {
        const row = rows[0];
        review_info.review_id = row.review_id;
        review_info.entity_id = row.entity_id;
        review_info.review_user_name = row.review_user_name;
        review_info.review_user_role = row.review_user_role;
        review_info.review_date = row.review_date;
        review_info.re_review_review_saved = re_review_review_saved;
      }
    } catch (err) {
      if (!request.isCurrent() || isAbortError(err)) return;
      reportError(err);
    } finally {
      finishRequest(reviewRequest, request);
    }
  }

  async function loadStatusInfo(
    status_id: number | string,
    re_review_status_saved: number
  ): Promise<void> {
    const request = beginRequest(statusRequest);
    loading_status_modal.value = true;
    try {
      const rows = await getStatusById(status_id, { signal: request.signal });
      if (!request.isCurrent()) return;
      if (rows && rows.length > 0) {
        const row = rows[0];
        // Replace the reactive backing object's keys (we cannot reassign
        // a reactive ref to a brand-new instance without losing the
        // shared identity callers may have captured).
        Object.assign(status_info, new Status(row.category_id, row.comment, row.problematic));
        status_info.status_id = row.status_id;
        status_info.entity_id = row.entity_id;
        status_info.status_user_name = row.status_user_name;
        status_info.status_user_role = row.status_user_role;
        status_info.status_date = row.status_date;
        status_info.re_review_status_saved = re_review_status_saved;
      }
    } catch (err) {
      if (!request.isCurrent() || isAbortError(err)) return;
      reportError(err);
    } finally {
      if (request.isCurrent()) {
        loading_status_modal.value = false;
        finishRequest(statusRequest, request);
      }
    }
  }

  function resetEntityContext(): void {
    cancelRequest(entityRequest);
    cancelRequest(reviewRequest);
    cancelRequest(statusRequest);
    loading_status_modal.value = false;
    Object.assign(entity_info, EMPTY_ENTITY_INFO);
    Object.assign(review_info, new Review() as ReviewInfo, {
      review_id: null,
      entity_id: null,
      review_user_name: null,
      review_user_role: null,
      review_date: null,
      re_review_review_saved: null,
    });
    Object.assign(status_info, new Status(), {
      status_id: null,
      entity_id: null,
      status_user_name: null,
      status_user_role: null,
      status_date: null,
      re_review_status_saved: null,
    });
  }

  return {
    items,
    totalRows,
    isBusy,
    loading,
    phenotypes_options,
    variation_ontology_options,
    status_options,
    entity_info,
    review_info,
    status_info,
    loading_status_modal,
    loadReReviewData,
    loadPhenotypesList,
    loadVariationOntologyList,
    loadStatusList,
    getEntity,
    loadReviewInfo,
    loadStatusInfo,
    resetEntityContext,
  };
}

export default useReviewData;

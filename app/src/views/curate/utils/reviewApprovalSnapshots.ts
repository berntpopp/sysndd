// views/curate/utils/reviewApprovalSnapshots.ts
/**
 * Pure "has this form drifted from what was loaded?" comparisons for
 * `ApproveReview.vue` / `useApproveReviewController`.
 *
 * Extracted so the dirty-state logic behind `hasReviewChanges` /
 * `hasStatusChanges` (used both for the submit-guard and the
 * modal-hide discard-confirmation) can be unit-tested without mounting the
 * view. Behavior is unchanged from the inline computeds it replaces:
 *  - the four review selection arrays (phenotypes, variation ontology,
 *    additional references, gene reviews) are compared order-insensitively,
 *    since `BFormTags` / `TreeMultiSelect` selection order carries no
 *    semantic meaning;
 *  - `synopsis` / `comment` (review) and `comment` (status) treat a nullish
 *    current value as an empty string, matching how the view seeds a fresh
 *    `Review`/`Status` instance;
 *  - the status `problematic` flag is coerced with `Boolean(...)` so
 *    `null`/`undefined` compares as `false`.
 *
 * `ReviewLoadedSnapshot` is re-exported from `useReviewApprovalActions` (the
 * canonical shape returned by `fetchReviewDetail`) rather than duplicated
 * here.
 */

import { arraysAreEqual } from '@/composables/review/useReviewHelpers';
import type { ReviewLoadedSnapshot } from '@/composables/review/useReviewApprovalActions';

export type { ReviewLoadedSnapshot };

export interface StatusLoadedSnapshot {
  category_id: number | null;
  comment: string;
  problematic: boolean;
}

export interface ReviewSnapshotComparable {
  synopsis?: string | null;
  comment?: string | null;
  phenotypes: string[];
  variationOntology: string[];
  publications: string[];
  genereviews: string[];
}

export interface StatusSnapshotComparable {
  category_id?: number | null;
  comment?: string | null;
  problematic?: boolean | null;
}

/**
 * Order-insensitive string-array equality. Copies both inputs before
 * sorting, so neither argument is mutated (callers may hold the same array
 * reference in reactive state).
 */
export function arraysEqualUnordered(a: string[], b: string[]): boolean {
  return arraysAreEqual([...a].sort(), [...b].sort());
}

/**
 * True when `current` differs from the last-loaded review `snapshot` in
 * synopsis, comment, or any of the four selection arrays. Returns `false`
 * (nothing to be dirty against) when no snapshot has been loaded yet.
 */
export function hasReviewSnapshotChanges(
  current: ReviewSnapshotComparable,
  snapshot: ReviewLoadedSnapshot | null
): boolean {
  if (!snapshot) return false;
  return (
    (current.synopsis || '') !== snapshot.synopsis ||
    (current.comment || '') !== snapshot.comment ||
    !arraysEqualUnordered(current.phenotypes, snapshot.phenotypes) ||
    !arraysEqualUnordered(current.variationOntology, snapshot.variationOntology) ||
    !arraysEqualUnordered(current.publications, snapshot.publications) ||
    !arraysEqualUnordered(current.genereviews, snapshot.genereviews)
  );
}

/**
 * True when `current` differs from the last-loaded status `snapshot` in
 * category, comment, or the problematic flag. Returns `false` when no
 * snapshot has been loaded yet.
 */
export function hasStatusSnapshotChanges(
  current: StatusSnapshotComparable,
  snapshot: StatusLoadedSnapshot | null
): boolean {
  if (!snapshot) return false;
  return (
    current.category_id !== snapshot.category_id ||
    (current.comment || '') !== snapshot.comment ||
    Boolean(current.problematic) !== snapshot.problematic
  );
}

// views/curate/utils/reviewApprovalSnapshots.spec.ts
import { describe, expect, it } from 'vitest';
import {
  arraysEqualUnordered,
  hasReviewSnapshotChanges,
  hasStatusSnapshotChanges,
  type ReviewLoadedSnapshot,
  type ReviewSnapshotComparable,
  type StatusLoadedSnapshot,
} from './reviewApprovalSnapshots';

describe('arraysEqualUnordered', () => {
  it('treats differently-ordered arrays with the same elements as equal', () => {
    expect(arraysEqualUnordered(['a', 'b', 'c'], ['c', 'a', 'b'])).toBe(true);
  });

  it('detects a real content difference regardless of order', () => {
    expect(arraysEqualUnordered(['a', 'b'], ['a', 'c'])).toBe(false);
  });

  it('detects a length difference', () => {
    expect(arraysEqualUnordered(['a', 'b'], ['a', 'b', 'c'])).toBe(false);
  });

  it('treats two empty arrays as equal', () => {
    expect(arraysEqualUnordered([], [])).toBe(true);
  });

  it('does not mutate its input arrays', () => {
    const a = ['b', 'a'];
    const b = ['a', 'b'];
    arraysEqualUnordered(a, b);
    expect(a).toEqual(['b', 'a']);
    expect(b).toEqual(['a', 'b']);
  });
});

describe('hasReviewSnapshotChanges', () => {
  const baseSnapshot: ReviewLoadedSnapshot = {
    synopsis: 'Synopsis text',
    comment: 'Comment text',
    phenotypes: ['1-10', '2-20'],
    variationOntology: ['1-30'],
    publications: ['PMID:1'],
    genereviews: ['PMID:2'],
  };

  const current = (): ReviewSnapshotComparable => ({
    synopsis: baseSnapshot.synopsis,
    comment: baseSnapshot.comment,
    phenotypes: [...baseSnapshot.phenotypes],
    variationOntology: [...baseSnapshot.variationOntology],
    publications: [...baseSnapshot.publications],
    genereviews: [...baseSnapshot.genereviews],
  });

  it('is false when nothing has loaded yet (snapshot is null)', () => {
    expect(hasReviewSnapshotChanges(current(), null)).toBe(false);
  });

  it('is false when current state exactly matches the loaded snapshot', () => {
    expect(hasReviewSnapshotChanges(current(), baseSnapshot)).toBe(false);
  });

  it('ignores selection-array reordering (order-insensitive)', () => {
    const reordered = current();
    reordered.phenotypes = [...baseSnapshot.phenotypes].reverse();
    expect(hasReviewSnapshotChanges(reordered, baseSnapshot)).toBe(false);
  });

  it('is sensitive to a synopsis change', () => {
    const changed = current();
    changed.synopsis = 'Different synopsis';
    expect(hasReviewSnapshotChanges(changed, baseSnapshot)).toBe(true);
  });

  it('is sensitive to a comment change', () => {
    const changed = current();
    changed.comment = 'Different comment';
    expect(hasReviewSnapshotChanges(changed, baseSnapshot)).toBe(true);
  });

  it('is sensitive to a phenotype selection content change', () => {
    const changed = current();
    changed.phenotypes = ['9-99'];
    expect(hasReviewSnapshotChanges(changed, baseSnapshot)).toBe(true);
  });

  it('is sensitive to a variation-ontology selection content change', () => {
    const changed = current();
    changed.variationOntology = ['9-99'];
    expect(hasReviewSnapshotChanges(changed, baseSnapshot)).toBe(true);
  });

  it('is sensitive to an additional-references selection content change', () => {
    const changed = current();
    changed.publications = ['PMID:999'];
    expect(hasReviewSnapshotChanges(changed, baseSnapshot)).toBe(true);
  });

  it('is sensitive to a gene-reviews selection content change', () => {
    const changed = current();
    changed.genereviews = ['PMID:999'];
    expect(hasReviewSnapshotChanges(changed, baseSnapshot)).toBe(true);
  });

  it('treats a nullish synopsis/comment as empty string, matching an empty-string snapshot', () => {
    const emptySnapshot: ReviewLoadedSnapshot = { ...baseSnapshot, synopsis: '', comment: '' };
    expect(
      hasReviewSnapshotChanges({ ...current(), synopsis: null, comment: undefined }, emptySnapshot)
    ).toBe(false);
  });
});

describe('hasStatusSnapshotChanges', () => {
  const baseSnapshot: StatusLoadedSnapshot = {
    category_id: 3,
    comment: 'Status comment',
    problematic: false,
  };

  it('is false when nothing has loaded yet (snapshot is null)', () => {
    expect(
      hasStatusSnapshotChanges({ category_id: 3, comment: 'x', problematic: true }, null)
    ).toBe(false);
  });

  it('is false when current state exactly matches the loaded snapshot', () => {
    expect(hasStatusSnapshotChanges({ ...baseSnapshot }, baseSnapshot)).toBe(false);
  });

  it('is sensitive to a category change', () => {
    expect(hasStatusSnapshotChanges({ ...baseSnapshot, category_id: 4 }, baseSnapshot)).toBe(true);
  });

  it('is sensitive to a comment change', () => {
    expect(
      hasStatusSnapshotChanges({ ...baseSnapshot, comment: 'Different' }, baseSnapshot)
    ).toBe(true);
  });

  it('is sensitive to the problematic flag toggling', () => {
    expect(
      hasStatusSnapshotChanges({ ...baseSnapshot, problematic: true }, baseSnapshot)
    ).toBe(true);
  });

  it('coerces a nullish problematic flag to false for comparison', () => {
    expect(
      hasStatusSnapshotChanges({ ...baseSnapshot, problematic: null }, baseSnapshot)
    ).toBe(false);
  });

  it('treats a nullish comment as empty string, matching an empty-string snapshot', () => {
    const emptySnapshot: StatusLoadedSnapshot = { ...baseSnapshot, comment: '' };
    expect(
      hasStatusSnapshotChanges({ ...baseSnapshot, comment: undefined }, emptySnapshot)
    ).toBe(false);
  });
});

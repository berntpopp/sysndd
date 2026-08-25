// views/curate/composables/__tests__/useReviewForm.publications.spec.ts
/**
 * #635 — the submitted publication set is exactly the curator's current selection.
 *
 * The bug this file guards: `useReviewForm.submitForm()` submitted the UNION of the
 * set loaded from the server and the set currently in the form. Removing a PMID
 * cleared it from `formData` — which is why the chip disappeared and the reporter saw
 * the UI update — and the union restored it one line before serialisation. The PUT
 * therefore carried the pre-edit set, `publication_replace_for_review()` obediently
 * re-INSERTed the row, and the save reported success. Reopening the re-review tab, or
 * approving the entity, showed the publication still attached.
 *
 * The union was introduced as a "BUG-05" guard against a reactivity failure the
 * current bindings cannot produce (`ReviewFormFields.vue` binds `v-model` straight
 * onto this composable's reactive object; `loadReviewData()` is atomic so a partial
 * load cannot open the modal; the draft is cleared before the load). It was also the
 * only reason removal worked from Modify Entity but not from re-review — the sibling
 * surfaces `useEntityInfo` and `useReviewApprovalActions` never had it.
 *
 * These assertions use `toEqual` on the whole array, never `toContain`. The defect was
 * an EXTRA entry surviving in the payload, and a containment assertion is blind to
 * that — the pre-#635 suite asserted containment and passed against the broken build.
 *
 * Split out of the sibling `useReviewForm.spec.ts` (which keeps load/validation/change
 * detection/draft coverage) to stay under the repo's 600-line file ceiling, following
 * the same one-harness-per-file pattern as `useReviewForm.provenance.spec.ts`.
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { flushPromises } from '@vue/test-utils';

const reviewApiMocks = vi.hoisted(() => ({
  getReviewById: vi.fn(),
  getReviewPhenotypes: vi.fn(),
  getReviewVariation: vi.fn(),
  getReviewPublications: vi.fn(),
  createReview: vi.fn(),
  updateReview: vi.fn(),
}));

vi.mock('@/api/review', () => reviewApiMocks);

vi.mock('@/composables/useFormDraft', () => ({
  default: vi.fn(() => ({
    hasDraft: { value: false },
    lastSavedFormatted: { value: '' },
    isSaving: { value: false },
    loadDraft: vi.fn(() => null),
    clearDraft: vi.fn(),
    checkForDraft: vi.fn(() => false),
    scheduleSave: vi.fn(),
  })),
}));

import useReviewForm from '../useReviewForm';

interface PublicationRow {
  publication_id: string;
  publication_type: string;
}

/** Wires the four read mocks; mirrors the sibling spec's helper. */
function primeReadMocks(publications: PublicationRow[], entityId = 1) {
  reviewApiMocks.getReviewById.mockResolvedValue([
    { synopsis: 'Test synopsis', comment: '', entity_id: entityId },
  ]);
  reviewApiMocks.getReviewPhenotypes.mockResolvedValue([]);
  reviewApiMocks.getReviewVariation.mockResolvedValue([]);
  reviewApiMocks.getReviewPublications.mockResolvedValue(publications);
}

/**
 * The literature block of the single review write recorded by the mocks.
 *
 * #635 asserts on EQUALITY of this set, not on containment: the bug was extra
 * entries surviving in the payload, and `toContain` cannot see those.
 */
function submittedLiterature(): { additional_references: string[]; gene_review: string[] } {
  expect(reviewApiMocks.updateReview).toHaveBeenCalledTimes(1);
  const call = reviewApiMocks.updateReview.mock.calls[0];
  return (
    call[0] as {
      review_json: { literature: { additional_references: string[]; gene_review: string[] } };
    }
  ).review_json.literature;
}

describe('useReviewForm publications', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    reviewApiMocks.updateReview.mockResolvedValue({ status: 200 });
    reviewApiMocks.createReview.mockResolvedValue({ status: 200 });
  });

  describe('#635: submitted publications are exactly the current selection', () => {
    it('stores original publications when loading review data', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
        { publication_id: 'PMID:11111111', publication_type: 'gene_review' },
      ]);

      const { formData, loadReviewData } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      // Verify publications are loaded into formData
      expect(formData.publications).toHaveLength(2);
      expect(formData.publications).toContain('PMID:12345678');
      expect(formData.publications).toContain('PMID:87654321');

      // Verify genereviews are loaded
      expect(formData.genereviews).toHaveLength(1);
      expect(formData.genereviews).toContain('PMID:11111111');
    });

    it('adding a publication keeps the existing ones', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
      ]);

      const { formData, loadReviewData, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      // Simulate user adding a new publication
      formData.publications.push('PMID:99999999');

      // Submit the form (isUpdate=true → PUT)
      await submitForm(true, true);
      await flushPromises();

      expect(reviewApiMocks.updateReview).toHaveBeenCalledTimes(1);

      expect(submittedLiterature().additional_references).toEqual([
        'PMID:12345678',
        'PMID:87654321',
        'PMID:99999999',
      ]);
    });

    it('removing one publication submits the remaining ones without it (#635)', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
      ]);

      const { formData, loadReviewData, submitForm } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      // What BFormTags does on @remove: reassign the array without that tag.
      formData.publications = formData.publications.filter((p) => p !== 'PMID:12345678');

      await submitForm(true, true);
      await flushPromises();

      expect(submittedLiterature().additional_references).toEqual(['PMID:87654321']);
    });

    it('removing every publication submits an empty set (#635)', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
      ]);

      const { formData, loadReviewData, submitForm } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      formData.publications = [];

      await submitForm(true, true);
      await flushPromises();

      expect(submittedLiterature().additional_references).toEqual([]);
    });

    it('removing a genereview does not disturb the additional references (#635)', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        { publication_id: 'PMID:11111111', publication_type: 'gene_review' },
      ]);

      const { formData, loadReviewData, submitForm } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      formData.genereviews = [];

      await submitForm(true, true);
      await flushPromises();

      const literature = submittedLiterature();
      expect(literature.gene_review).toEqual([]);
      expect(literature.additional_references).toEqual(['PMID:12345678']);
    });

    it('an add and a remove in the same save both take effect (#635)', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
        { publication_id: 'PMID:87654321', publication_type: 'additional_references' },
      ]);

      const { formData, loadReviewData, submitForm } = useReviewForm();

      await loadReviewData(1);
      await flushPromises();

      formData.publications = ['PMID:87654321', 'PMID:99999999'];

      await submitForm(true, true);
      await flushPromises();

      expect(submittedLiterature().additional_references).toEqual([
        'PMID:87654321',
        'PMID:99999999',
      ]);
    });

    it('deduplicates publications when same PMID exists in both original and form', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
      ]);

      const { formData, loadReviewData, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      // Simulate user adding the same PMID that already exists
      formData.publications.push('PMID:12345678'); // Duplicate

      // Submit the form
      await submitForm(true, true);
      await flushPromises();

      expect(submittedLiterature().additional_references).toEqual(['PMID:12345678']);
    });

    it('collapses whitespace-equivalent PMIDs into one entry', async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
      ]);

      const { formData, loadReviewData, submitForm } = useReviewForm();
      await loadReviewData(1);
      await flushPromises();

      // BFormTags holds these as two distinct tags; they are only equal once
      // sanitised, so de-duplication has to happen AFTER normalisation. The
      // previous Set-then-map order shipped both to the API.
      formData.publications = ['PMID:12345678', 'PMID: 12345678'];

      await submitForm(true, true);
      await flushPromises();

      expect(submittedLiterature().additional_references).toEqual(['PMID:12345678']);
    });

    it("a second load does not resurrect the first review's publications", async () => {
      primeReadMocks([
        { publication_id: 'PMID:12345678', publication_type: 'additional_references' },
      ]);

      const { formData, loadReviewData, resetForm, submitForm } = useReviewForm();

      // Load existing publications
      await loadReviewData(1);
      await flushPromises();

      expect(formData.publications).toHaveLength(1);

      // Reset the form
      resetForm();

      // Verify form data is cleared
      expect(formData.publications).toHaveLength(0);
      expect(formData.synopsis).toBe('');

      // Load new review data with different publications
      primeReadMocks(
        [{ publication_id: 'PMID:99999999', publication_type: 'additional_references' }],
        2
      );

      await loadReviewData(2);
      await flushPromises();

      // Submit the form - should only have the new publication, not the old one
      await submitForm(true, true);
      await flushPromises();

      expect(submittedLiterature().additional_references).toEqual(['PMID:99999999']);
    });
  });
});

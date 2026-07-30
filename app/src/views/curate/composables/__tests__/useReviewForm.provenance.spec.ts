// views/curate/composables/__tests__/useReviewForm.provenance.spec.ts
/**
 * #608 — variation-ontology provenance threading through the curation form.
 *
 * The bug this file guards: the curation form prefills its variation-ontology
 * picker from the entity's existing terms, so a curator who opened an entity to
 * fix one sentence of synopsis got EVERY existing term pre-checked and saving
 * rewrote all of them onto a new, curator-attributed review. No user action
 * distinguished "I read the papers and agree" from "I did not notice the
 * pre-checked box" — which is how machine-imported annotations became
 * indistinguishable from curated content.
 *
 * The server-side reconciliation is identity-aware and already shipped; this
 * suite locks the CLIENT half of the contract:
 *
 *   - a machine-derived term the curator never engaged is still SUBMITTED (the
 *     annotation must not vanish) but carries NO `provenance_action` key, so the
 *     server leaves it `active_unconfirmed`;
 *   - `Confirm` is the only thing that adds `provenance_action: "confirm"`;
 *   - `present` (modifier 1) and `absent` (modifier 5) for the SAME `vario_id`
 *     are independent assertions with independent state.
 *
 * The sibling `useReviewForm.spec.ts` is deliberately left untouched: it does
 * not mock `@/api/entity`, which proves the provenance fetch is opt-in and the
 * pre-#608 form still loads and submits byte-identically.
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

const entityApiMocks = vi.hoisted(() => ({
  getEntityVariation: vi.fn(),
  getEntityVariationSuggestions: vi.fn(),
}));

vi.mock('@/api/review', () => reviewApiMocks);
vi.mock('@/api/entity', () => entityApiMocks);

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

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

interface VariationFixture {
  vario_id: string;
  modifier_id: number;
  vario_name?: string;
  state?: 'active_unconfirmed' | 'confirmed' | null;
}

function provenanceRow(fixture: VariationFixture) {
  const state = fixture.state === undefined ? 'active_unconfirmed' : fixture.state;
  return {
    entity_id: 42,
    vario_id: fixture.vario_id,
    vario_name: fixture.vario_name ?? fixture.vario_id,
    modifier_id: fixture.modifier_id,
    provenance:
      state === null
        ? null
        : {
            state,
            max_strength: 1,
            sources: [
              {
                source_type: 'external_database' as const,
                source_key: 'ClinVar',
                strength: 1,
                summary: '2 records, single submitter',
              },
            ],
          },
  };
}

function suggestionRow(fixture: VariationFixture) {
  return {
    entity_id: 42,
    vario_id: fixture.vario_id,
    vario_name: fixture.vario_name ?? fixture.vario_id,
    modifier_id: fixture.modifier_id,
    state: 'suggested' as const,
    max_strength: 3,
    evidence: [
      {
        source_type: 'external_database' as const,
        source_key: 'ClinVar',
        batch_id: 'b1',
        source_version: null,
        evidence_summary: '6 records, expert panel',
        evidence_strength: 3,
        evidence_json: null,
      },
    ],
  };
}

function primeReadMocks(variation: VariationFixture[]) {
  reviewApiMocks.getReviewById.mockResolvedValue([
    { synopsis: 'A synopsis long enough to pass validation', comment: '', entity_id: 42 },
  ]);
  reviewApiMocks.getReviewPhenotypes.mockResolvedValue([]);
  reviewApiMocks.getReviewPublications.mockResolvedValue([]);
  reviewApiMocks.getReviewVariation.mockResolvedValue(
    variation.map((item) => ({ vario_id: item.vario_id, modifier_id: item.modifier_id }))
  );
}

/** Loads the review form the way the Review edit modal does. */
async function loadForm(variation: VariationFixture[], suggestions: VariationFixture[] = []) {
  primeReadMocks(variation);
  entityApiMocks.getEntityVariation.mockResolvedValue(variation.map(provenanceRow));
  entityApiMocks.getEntityVariationSuggestions.mockResolvedValue(suggestions.map(suggestionRow));

  const form = useReviewForm();
  await form.loadReviewData(1);
  await form.loadVariationProvenance();
  await flushPromises();
  return form;
}

interface SubmittedVariation {
  vario_id: unknown;
  modifier_id: unknown;
  provenance_action?: unknown;
}

function submittedVariation(): SubmittedVariation[] {
  const body = reviewApiMocks.updateReview.mock.calls[0][0] as {
    review_json: { variation_ontology: SubmittedVariation[] };
  };
  return body.review_json.variation_ontology;
}

describe('useReviewForm — #608 variation provenance', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    reviewApiMocks.updateReview.mockResolvedValue({ status: 200 });
    reviewApiMocks.createReview.mockResolvedValue({ status: 200 });
  });

  // -------------------------------------------------------------------------
  // THE regression test for the original bug.
  // -------------------------------------------------------------------------
  it('REGRESSION #608: saving without engaging a Needs-confirmation term submits it with NO provenance_action key', async () => {
    const form = await loadForm([
      { vario_id: 'VariO:0017', modifier_id: 1, vario_name: 'nonsynonymous variation' },
    ]);

    // The term is machine-derived and unconfirmed...
    expect(form.variationZones.needsConfirmation.value.map((e) => e.tag)).toEqual(['1-VariO:0017']);
    // ...and it is STILL SELECTED, so the annotation stays live.
    expect(form.formData.variationOntology).toEqual(['1-VariO:0017']);

    // The curator saves without touching it (the exact original scenario).
    await form.submitForm(true, false);
    await flushPromises();

    const submitted = submittedVariation();
    expect(submitted).toHaveLength(1);
    // Still submitted — the annotation must not vanish.
    expect(submitted[0].vario_id).toBe('VariO:0017');
    expect(submitted[0].modifier_id).toBe(1);
    // But NOT confirmed: the key must be absent, not null/undefined-valued.
    expect('provenance_action' in submitted[0]).toBe(false);
    expect(Object.keys(submitted[0])).toEqual(['vario_id', 'modifier_id']);
    // And it must survive JSON serialisation as a two-key object.
    expect(JSON.parse(JSON.stringify(submitted[0]))).toEqual({
      vario_id: 'VariO:0017',
      modifier_id: 1,
    });
  });

  it('an active_unconfirmed term lands in Needs confirmation AND stays in the submitted set', async () => {
    const form = await loadForm([
      { vario_id: 'VariO:0017', modifier_id: 1 },
      { vario_id: 'VariO:0002', modifier_id: 1, state: null },
    ]);

    expect(form.variationZones.needsConfirmation.value.map((e) => e.tag)).toEqual(['1-VariO:0017']);
    expect(form.variationZones.confirmed.value.map((e) => e.tag)).toEqual(['1-VariO:0002']);

    await form.submitForm(true, false);
    await flushPromises();

    expect(submittedVariation().map((v) => v.vario_id)).toEqual(['VariO:0017', 'VariO:0002']);
  });

  it('Confirm marks exactly that term with provenance_action "confirm"', async () => {
    const form = await loadForm([
      { vario_id: 'VariO:0017', modifier_id: 1 },
      { vario_id: 'VariO:0508', modifier_id: 1 },
    ]);

    form.variationZones.confirmTerm('1-VariO:0017');

    // It moves out of Needs confirmation into Confirmed.
    expect(form.variationZones.needsConfirmation.value.map((e) => e.tag)).toEqual(['1-VariO:0508']);
    expect(form.variationZones.confirmed.value.map((e) => e.tag)).toEqual(['1-VariO:0017']);

    await form.submitForm(true, false);
    await flushPromises();

    expect(submittedVariation()).toEqual([
      { vario_id: 'VariO:0017', modifier_id: 1, provenance_action: 'confirm' },
      { vario_id: 'VariO:0508', modifier_id: 1 },
    ]);
  });

  it('Remove drops the term from the payload entirely', async () => {
    const form = await loadForm([
      { vario_id: 'VariO:0017', modifier_id: 1 },
      { vario_id: 'VariO:0508', modifier_id: 1 },
    ]);

    form.variationZones.removeTerm('1-VariO:0017');

    expect(form.formData.variationOntology).toEqual(['1-VariO:0508']);

    await form.submitForm(true, false);
    await flushPromises();

    expect(submittedVariation()).toEqual([{ vario_id: 'VariO:0508', modifier_id: 1 }]);
  });

  it('Accept adds a suggested term WITH provenance_action "confirm"', async () => {
    const form = await loadForm(
      [{ vario_id: 'VariO:0017', modifier_id: 1 }],
      [{ vario_id: 'VariO:0508', modifier_id: 1, vario_name: 'splice variation' }]
    );

    expect(form.variationZones.suggested.value.map((e) => e.tag)).toEqual(['1-VariO:0508']);
    expect(form.formData.variationOntology).toEqual(['1-VariO:0017']);

    form.variationZones.acceptSuggestion('1-VariO:0508');

    expect(form.formData.variationOntology).toEqual(['1-VariO:0017', '1-VariO:0508']);
    expect(form.variationZones.suggested.value).toHaveLength(0);
    expect(form.variationZones.confirmed.value.map((e) => e.tag)).toEqual(['1-VariO:0508']);

    await form.submitForm(true, false);
    await flushPromises();

    expect(submittedVariation()).toEqual([
      { vario_id: 'VariO:0017', modifier_id: 1 },
      { vario_id: 'VariO:0508', modifier_id: 1, provenance_action: 'confirm' },
    ]);
  });

  it('Dismiss leaves the suggestion out of the payload and adds nothing else', async () => {
    const form = await loadForm(
      [{ vario_id: 'VariO:0017', modifier_id: 1 }],
      [{ vario_id: 'VariO:0508', modifier_id: 1 }]
    );

    form.variationZones.dismissSuggestion('1-VariO:0508');

    expect(form.variationZones.suggested.value).toHaveLength(0);
    expect(form.formData.variationOntology).toEqual(['1-VariO:0017']);

    await form.submitForm(true, false);
    await flushPromises();

    expect(submittedVariation()).toEqual([{ vario_id: 'VariO:0017', modifier_id: 1 }]);
  });

  // -------------------------------------------------------------------------
  // IDENTITY: an implementation keyed on `vario_id` alone passes every other
  // test in this file and fails this one.
  // -------------------------------------------------------------------------
  it('IDENTITY: present (1) and absent (5) for the same vario_id have independent state', async () => {
    const form = await loadForm([
      { vario_id: 'VariO:0017', modifier_id: 1 },
      { vario_id: 'VariO:0017', modifier_id: 5 },
    ]);

    expect(form.variationZones.needsConfirmation.value.map((e) => e.tag)).toEqual([
      '1-VariO:0017',
      '5-VariO:0017',
    ]);
    // The modifier is carried in TEXT on each card, not by position.
    expect(form.variationZones.needsConfirmation.value.map((e) => e.modifierLabel)).toEqual([
      'present',
      'absent',
    ]);

    form.variationZones.confirmTerm('1-VariO:0017');

    expect(form.variationZones.needsConfirmation.value.map((e) => e.tag)).toEqual(['5-VariO:0017']);
    expect(form.variationZones.confirmed.value.map((e) => e.tag)).toEqual(['1-VariO:0017']);

    await form.submitForm(true, false);
    await flushPromises();

    expect(submittedVariation()).toEqual([
      { vario_id: 'VariO:0017', modifier_id: 1, provenance_action: 'confirm' },
      { vario_id: 'VariO:0017', modifier_id: 5 },
    ]);
  });

  it('a VariO id containing a hyphen round-trips without truncation', async () => {
    const form = await loadForm([{ vario_id: 'VariO:0015-beta', modifier_id: 5 }]);

    expect(form.formData.variationOntology).toEqual(['5-VariO:0015-beta']);
    form.variationZones.confirmTerm('5-VariO:0015-beta');

    await form.submitForm(true, false);
    await flushPromises();

    const submitted = submittedVariation();
    expect(submitted).toEqual([
      { vario_id: 'VariO:0015-beta', modifier_id: 5, provenance_action: 'confirm' },
    ]);
    const wire = JSON.parse(JSON.stringify(submitted));
    expect(wire.every((v: { vario_id: unknown }) => v.vario_id !== null)).toBe(true);
  });

  it('confirming marks the form dirty, and resetForm clears the confirmed set', async () => {
    const form = await loadForm([{ vario_id: 'VariO:0017', modifier_id: 1 }]);

    expect(form.hasChanges.value).toBe(false);

    form.variationZones.confirmTerm('1-VariO:0017');
    expect(form.hasChanges.value).toBe(true);

    form.resetForm();
    expect(form.formData.variationConfirmed).toEqual([]);
    expect(form.variationZones.needsConfirmation.value).toEqual([]);
    expect(form.variationZones.suggested.value).toEqual([]);
    expect(form.hasChanges.value).toBe(false);
  });

  it('a fresh load clears session confirmations from the previous entity', async () => {
    const form = await loadForm([{ vario_id: 'VariO:0017', modifier_id: 1 }]);
    form.variationZones.confirmTerm('1-VariO:0017');
    expect(form.formData.variationConfirmed).toEqual(['1-VariO:0017']);

    primeReadMocks([{ vario_id: 'VariO:0017', modifier_id: 1 }]);
    await form.loadReviewData(2);
    await flushPromises();

    expect(form.formData.variationConfirmed).toEqual([]);
  });

  it('degrades quietly when the Curator-gated suggestions route is forbidden', async () => {
    primeReadMocks([{ vario_id: 'VariO:0017', modifier_id: 1 }]);
    entityApiMocks.getEntityVariation.mockResolvedValue([
      provenanceRow({ vario_id: 'VariO:0017', modifier_id: 1 }),
    ]);
    entityApiMocks.getEntityVariationSuggestions.mockRejectedValue(new Error('403'));

    const form = useReviewForm();
    await form.loadReviewData(1);
    await expect(form.loadVariationProvenance()).resolves.toBeUndefined();

    expect(form.variationZones.suggested.value).toEqual([]);
    expect(form.variationZones.needsConfirmation.value).toHaveLength(1);
  });

  it('is inert when the API reports no provenance and no suggestions', async () => {
    const form = await loadForm([{ vario_id: 'VariO:0002', modifier_id: 1, state: null }]);

    expect(form.variationZones.hasZones.value).toBe(false);
    expect(form.variationZones.needsConfirmation.value).toEqual([]);
    expect(form.variationZones.suggested.value).toEqual([]);

    await form.submitForm(true, false);
    await flushPromises();

    expect(submittedVariation()).toEqual([{ vario_id: 'VariO:0002', modifier_id: 1 }]);
  });
});

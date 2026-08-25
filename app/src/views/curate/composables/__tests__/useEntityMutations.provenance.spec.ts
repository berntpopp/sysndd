// #612: `provenance_action` on the ModifyEntity submit path.
//
// ModifyEntity prefills its variation picker from the entity's existing terms
// and resubmits them, so before the zone picker reached this surface a curator
// who edited one sentence of synopsis silently reattributed every
// machine-derived term to themselves. The server has always reconciled
// regardless — omission is what records a rejection, and only an explicit
// `provenance_action: "confirm"` promotes — so this is about the ACT being
// available and reaching the payload, not about correctness.
//
// The field is OMITTED, never null, when there is no action: a submission from a
// surface with no picker must serialise byte-identically to its pre-#608 self.
import { describe, it, expect } from 'vitest';

import Variation from '@/assets/js/classes/submission/submissionVariation';
import splitOntologyTag from '@/utils/ontologyTags';

/** Mirrors the mapping in useEntityMutations.submitReview. */
function buildVariation(
  tags: string[],
  provenanceActionFor?: (tag: string) => 'confirm' | undefined
): Variation[] {
  return tags.map((item) => {
    const { modifierId, ontologyId } = splitOntologyTag(item);
    return new Variation(ontologyId, modifierId, provenanceActionFor?.(item));
  });
}

describe('variation submission payload', () => {
  it('omits provenance_action entirely when nothing was confirmed', () => {
    const [term] = buildVariation(['1-VariO:0015']);
    expect(term).toEqual({ vario_id: 'VariO:0015', modifier_id: 1 });
    expect('provenance_action' in term).toBe(false);
  });

  it('omits it for a term the curator did not act on', () => {
    const [term] = buildVariation(['1-VariO:0015'], () => undefined);
    expect('provenance_action' in term).toBe(false);
  });

  it('sets it for a confirmed term', () => {
    const [term] = buildVariation(['1-VariO:0015'], (tag) =>
      tag === '1-VariO:0015' ? 'confirm' : undefined
    );
    expect(term).toMatchObject({
      vario_id: 'VariO:0015',
      modifier_id: 1,
      provenance_action: 'confirm',
    });
  });

  it('keys on the FULL tag, so present and absent decide independently', () => {
    const terms = buildVariation(['1-VariO:0015', '5-VariO:0015'], (tag) =>
      tag === '1-VariO:0015' ? 'confirm' : undefined
    );
    expect('provenance_action' in terms[0]).toBe(true);
    expect('provenance_action' in terms[1]).toBe(false);
    expect(terms[0].modifier_id).toBe(1);
    expect(terms[1].modifier_id).toBe(5);
  });

  it('splits only at the first separator so a hyphenated CURIE survives', () => {
    const [term] = buildVariation(['1-VariO:00-15']);
    expect(term.vario_id).toBe('VariO:00-15');
    expect(term.modifier_id).toBe(1);
  });
});

describe('wiring', () => {
  it('both ModifyEntity argument builders forward the action resolver', async () => {
    // The inline workflow uses reviewArgs() and the combined status+review
    // workflow uses getReviewArgs(). Wiring only one silently drops every
    // confirmation made in the other.
    const source = await import('../useModifyEntityWorkflows?raw').then((m) => m.default);
    const occurrences = source.split('provenance_action_for: variationZones.provenanceActionFor')
      .length - 1;
    expect(occurrences).toBe(2);
  });
});

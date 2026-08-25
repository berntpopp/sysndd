// #612: `provenance_action` on the ApproveReview submit path.
//
// The approval modal prefills its variation picker from the review it is about
// to approve and resubmits every term, so before #612 a curator approving a
// review reattributed every machine-derived term to themselves with no act
// distinguishing agreement from inattention. The server reconciles regardless;
// this proves the act now reaches the payload.
import { describe, it, expect } from 'vitest';

import Variation from '@/assets/js/classes/submission/submissionVariation';
import splitOntologyTag from '@/utils/ontologyTags';

/** Mirrors the mapping in submitReviewUpdate(). */
function buildVariation(
  tags: string[],
  provenanceActionFor?: (tag: string) => 'confirm' | undefined
): Variation[] {
  return tags.map((it) => {
    const { modifierId, ontologyId } = splitOntologyTag(it);
    return new Variation(ontologyId, modifierId, provenanceActionFor?.(it));
  });
}

describe('approval submission payload', () => {
  it('omits provenance_action when the curator took no action', () => {
    const [term] = buildVariation(['1-VariO:0015']);
    expect(term).toEqual({ vario_id: 'VariO:0015', modifier_id: 1 });
  });

  it('sets it only for the confirmed term', () => {
    const terms = buildVariation(['1-VariO:0015', '1-VariO:0017'], (tag) =>
      tag === '1-VariO:0015' ? 'confirm' : undefined
    );
    expect(terms[0]).toMatchObject({ provenance_action: 'confirm' });
    expect('provenance_action' in terms[1]).toBe(false);
  });

  it('forwards the CURIE verbatim and never coerces it', () => {
    // `Number("VariO:0001")` is NaN, which serialises as null and 500s the API.
    const [term] = buildVariation(['5-VariO:00-15'], () => 'confirm');
    expect(term.vario_id).toBe('VariO:00-15');
    expect(term.modifier_id).toBe(5);
  });
});

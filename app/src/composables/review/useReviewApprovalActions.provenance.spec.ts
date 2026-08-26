// #612: `provenance_action` on the ApproveReview submit path.
//
// The approval modal prefills its variation picker from the review it is about
// to approve and resubmits every term, so before #612 a curator approving a
// review reattributed every machine-derived term to themselves with no act
// distinguishing agreement from inattention. The server reconciles regardless;
// this proves the act reaches the wire.
//
// These assertions drive the REAL submitReviewUpdate() against a stub HTTP
// client and inspect the request body it actually sends. An earlier version of
// this file re-declared the mapping locally and asserted the copy, which proved
// only that the copy was correct — the production function could have stopped
// forwarding the resolver entirely and the file would have stayed green.
import { describe, it, expect, vi } from 'vitest';

import { submitReviewUpdate } from './useReviewApprovalActions';

type PutBody = { review_json: { variation_ontology: Record<string, unknown>[] } };

function makeClient() {
  const put = vi.fn().mockResolvedValue({ status: 200, statusText: 'OK' });
  return { client: { put } as never, put };
}

function submit(
  selectVariation: string[],
  provenanceActionFor?: (tag: string) => 'confirm' | undefined
) {
  const { client, put } = makeClient();
  submitReviewUpdate(client, {
    reviewInfo: { review_id: 42 } as never,
    selectPhenotype: [],
    selectVariation,
    provenanceActionFor,
    selectAdditionalReferences: [],
    selectGeneReviews: [],
    sanitize: (v: string) => v.replace(/\s+/g, ''),
  });
  const [url, body] = put.mock.calls[0] as [string, PutBody];
  return { url, terms: body.review_json.variation_ontology };
}

describe('ApproveReview submit path', () => {
  it('PUTs to /api/review/update', () => {
    expect(submit(['1-VariO:0015']).url).toMatch(/\/api\/review\/update$/);
  });

  it('omits provenance_action when the curator took no action', () => {
    const { terms } = submit(['1-VariO:0015']);
    expect(terms[0]).toEqual({ vario_id: 'VariO:0015', modifier_id: 1 });
  });

  it('omits it — never sends null — when the resolver returns undefined', () => {
    const { terms } = submit(['1-VariO:0015'], () => undefined);
    expect('provenance_action' in terms[0]).toBe(false);
  });

  it('sets it only for the confirmed term', () => {
    const { terms } = submit(['1-VariO:0015', '1-VariO:0017'], (tag) =>
      tag === '1-VariO:0015' ? 'confirm' : undefined
    );
    expect(terms[0]).toMatchObject({ provenance_action: 'confirm' });
    expect('provenance_action' in terms[1]).toBe(false);
  });

  it('keys on the FULL tag, so present and absent decide independently', () => {
    // modifier 1 (present) and 5 (absent) are different assertions with
    // independent provenance state; confirming one must not confirm the other.
    const { terms } = submit(['1-VariO:0015', '5-VariO:0015'], (tag) =>
      tag === '1-VariO:0015' ? 'confirm' : undefined
    );
    expect('provenance_action' in terms[0]).toBe(true);
    expect('provenance_action' in terms[1]).toBe(false);
    expect(terms[0].modifier_id).toBe(1);
    expect(terms[1].modifier_id).toBe(5);
  });

  it('forwards the CURIE verbatim and never coerces it', () => {
    // `Number("VariO:0001")` is NaN, which serialises as null and 500s the API;
    // splitOntologyTag() must also split only at the FIRST separator (#611).
    const { terms } = submit(['5-VariO:00-15'], () => 'confirm');
    expect(terms[0].vario_id).toBe('VariO:00-15');
    expect(terms[0].modifier_id).toBe(5);
  });
});

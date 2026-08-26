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
//
// Everything below drives the REAL production functions and asserts the body
// that reaches the HTTP client. An earlier version re-declared the mapping in
// the test file and asserted the copy, and checked the wiring by counting how
// many times a literal string appeared in the source — both of which stay green
// while the production path drops the field entirely.
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ref, computed } from 'vue';

const post = vi.fn();

vi.mock('@/api/client', () => ({
  apiClient: { raw: { post: (...args: unknown[]) => post(...args) } },
}));

import { useEntityMutations } from '../useEntityMutations';
import { useModifyEntityWorkflows } from '../useModifyEntityWorkflows';

type PostBody = { review_json: { variation_ontology: Record<string, unknown>[] } };

/** The variation_ontology array of the Nth POST /api/review/create. */
function postedTerms(call = 0): Record<string, unknown>[] {
  const [, body] = post.mock.calls[call] as [string, PostBody];
  return body.review_json.variation_ontology;
}

beforeEach(() => {
  post.mockReset();
  post.mockResolvedValue({ status: 200, statusText: 'OK' });
});

async function submitViaMutations(
  select_variation: string[],
  provenance_action_for?: (tag: string) => 'confirm' | undefined
) {
  await useEntityMutations().submitReview({
    review_info: { review_id: 7 },
    select_phenotype: [],
    select_variation,
    provenance_action_for,
    select_additional_references: [],
    select_gene_reviews: [],
  });
  return postedTerms();
}

describe('useEntityMutations.submitReview payload', () => {
  it('POSTs to /api/review/create', async () => {
    await submitViaMutations(['1-VariO:0015']);
    expect(post.mock.calls[0][0]).toMatch(/\/api\/review\/create$/);
  });

  it('omits provenance_action entirely when nothing was confirmed', async () => {
    const terms = await submitViaMutations(['1-VariO:0015']);
    expect(terms[0]).toEqual({ vario_id: 'VariO:0015', modifier_id: 1 });
    expect('provenance_action' in terms[0]).toBe(false);
  });

  it('omits it — never sends null — for a term the curator did not act on', async () => {
    const terms = await submitViaMutations(['1-VariO:0015'], () => undefined);
    expect('provenance_action' in terms[0]).toBe(false);
  });

  it('sets it for a confirmed term', async () => {
    const terms = await submitViaMutations(['1-VariO:0015'], (tag) =>
      tag === '1-VariO:0015' ? 'confirm' : undefined
    );
    expect(terms[0]).toMatchObject({
      vario_id: 'VariO:0015',
      modifier_id: 1,
      provenance_action: 'confirm',
    });
  });

  it('keys on the FULL tag, so present and absent decide independently', async () => {
    const terms = await submitViaMutations(['1-VariO:0015', '5-VariO:0015'], (tag) =>
      tag === '1-VariO:0015' ? 'confirm' : undefined
    );
    expect('provenance_action' in terms[0]).toBe(true);
    expect('provenance_action' in terms[1]).toBe(false);
    expect(terms[0].modifier_id).toBe(1);
    expect(terms[1].modifier_id).toBe(5);
  });

  it('splits only at the first separator so a hyphenated CURIE survives', async () => {
    const terms = await submitViaMutations(['1-VariO:00-15']);
    expect(terms[0].vario_id).toBe('VariO:00-15');
    expect(terms[0].modifier_id).toBe(1);
  });
});

// ---------------------------------------------------------------------------
// Both ModifyEntity argument builders, end to end.
//
// The inline workflow uses reviewArgs() and the combined status+review workflow
// uses getReviewArgs(). Wiring only one silently drops every confirmation made
// in the other -- and the TYPE system cannot catch it, because
// useCombinedStatusReview's SubmitReviewLike does not declare
// provenance_action_for and useModifyEntityWorkflows bridges the two with
// `args as never`. Only a runtime assertion on the sent body covers this.
// ---------------------------------------------------------------------------

const CONFIRMED_TAG = '1-VariO:0015';

function makeWorkflows() {
  const select_variation = ref([CONFIRMED_TAG, '5-VariO:0015']);
  const confirmed_variation_tags = ref<string[]>([]);
  const info = {
    entity_info: ref({ entity_id: 1 }),
    review_info: ref({ review_id: 7 }),
    select_phenotype: ref([]),
    select_variation,
    confirmed_variation_tags,
    select_additional_references: ref([]),
    select_gene_reviews: ref([]),
    hasReviewChanges: computed(() => true),
    loadReview: vi.fn(),
    reset: vi.fn(),
  };
  const statusForm = {
    hasChanges: computed(() => false),
    submitForm: vi.fn().mockResolvedValue(undefined),
    resetForm: vi.fn(),
    loadStatusByEntity: vi.fn(),
  };
  // `close` matters: clearActiveWorkflow() calls it, and BOTH submit handlers
  // wrap their work in `catch {}`. An incomplete stub therefore throws a
  // TypeError that is silently swallowed AFTER the POST -- the wire assertions
  // would still pass while the workflow never finished. The
  // `expect(info.reset)` assertions below exist to make that impossible.
  const modals = {
    loadingRename: ref(false),
    loadingDeactivate: ref(false),
    loadingReview: ref(false),
    loadingStatus: ref(false),
    setLoading: vi.fn(),
    close: vi.fn(),
  };
  const workflows = useModifyEntityWorkflows({
    info,
    search: { clearAll: vi.fn(), onEntitySelected: vi.fn() },
    mutations: useEntityMutations(),
    modals,
    statusForm,
    deactivate_check: ref(false),
    replace_check: ref(false),
    onToast: vi.fn(),
    announce: vi.fn(),
  } as never);
  return { workflows, statusForm, info };
}

describe('ModifyEntity workflows forward the confirmation to the wire', () => {
  it('inline review submit (reviewArgs)', async () => {
    const { workflows, info } = makeWorkflows();
    workflows.variationZones.confirmTerm(CONFIRMED_TAG);

    await workflows.onSubmitReview();

    const terms = postedTerms();
    expect(terms[0]).toMatchObject({ modifier_id: 1, provenance_action: 'confirm' });
    // The sibling assertion on the same VariO term is untouched.
    expect('provenance_action' in terms[1]).toBe(false);
    // The handler ran to completion — nothing threw into its `catch {}`.
    expect(info.reset).toHaveBeenCalled();
  });

  it('combined status+review direct approval (getReviewArgs)', async () => {
    const { workflows, statusForm, info } = makeWorkflows();
    workflows.variationZones.confirmTerm(CONFIRMED_TAG);
    workflows.combinedDirectApproval.value = true;

    await workflows.onSubmitCombined();

    const terms = postedTerms();
    expect(terms[0]).toMatchObject({ modifier_id: 1, provenance_action: 'confirm' });
    expect('provenance_action' in terms[1]).toBe(false);
    // direct_approval rides as a query param, not in the body.
    expect(post.mock.calls[0][2]).toEqual({ params: { direct_approval: true } });
    expect(statusForm.submitForm).toHaveBeenCalledWith(false, false, true);
    expect(info.reset).toHaveBeenCalled();
  });
});

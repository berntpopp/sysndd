import { describe, expect, test } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { useEntityMutations } from '../useEntityMutations';

// Lifecycle (listen / resetHandlers / close) is provided globally by
// vitest.setup.ts. This file only adds per-test handler overrides via
// `server.use(...)`.

const apiBase = import.meta.env.VITE_API_URL ?? '';

describe('useEntityMutations', () => {
  test('rename POST sends rename_json and toggles submitting', async () => {
    let received: any = null;
    server.use(
      http.post(`${apiBase}/api/entity/rename`, async ({ request }) => {
        received = await request.json();
        return HttpResponse.json({ ok: true });
      })
    );
    const m = useEntityMutations();
    expect(m.submitting.value).toBeNull();
    const p = m.rename({ entity_info: { entity_id: 1 }, ontology_input: 'MONDO:1' });
    expect(m.submitting.value).toBe('rename');
    await p;
    expect(m.submitting.value).toBeNull();
    expect(received.rename_json).toBeDefined();
  });

  test('deactivate POST sends deactivate_json with replace_entity', async () => {
    let received: any = null;
    server.use(
      http.post(`${apiBase}/api/entity/deactivate`, async ({ request }) => {
        received = await request.json();
        return HttpResponse.json({ ok: true });
      })
    );
    const m = useEntityMutations();
    await m.deactivate({
      entity_info: { entity_id: 1 },
      deactivate_check: true,
      replace_entity_input: 5,
    });
    expect(received.deactivate_json).toBeDefined();
  });

  test('submitReview POST sends review_json', async () => {
    let received: any = null;
    server.use(
      http.post(`${apiBase}/api/review/create`, async ({ request }) => {
        received = await request.json();
        return HttpResponse.json({ ok: true });
      })
    );
    const m = useEntityMutations();
    await m.submitReview({
      review_info: { synopsis: 's', comment: 'c' },
      select_phenotype: ['1-HP:0001249'],
      select_variation: ['1-VariO:0015'],
      select_additional_references: ['PMID:1'],
      select_gene_reviews: ['PMID:2'],
    });
    expect(received.review_json).toBeDefined();
    expect(received.review_json.phenotypes.length).toBe(1);
    expect(received.review_json.variation_ontology.length).toBe(1);
  });

  // Regression: #611 — hyphenated ontology CURIEs were truncated on submission.
  //
  // The curation tag is "<modifier_id>-<ontology_CURIE>". This path split it
  // with `item.split('-')[1]`, which returns only the segment BETWEEN the first
  // and second hyphen — so `'5-CURIE:part-with-hyphen'` submitted
  // `'CURIE:part'`: either a different existing term, or a non-existent one that
  // fails the connect step. `splitOntologyTag()` (utils/ontologyTags.ts) splits
  // on the FIRST separator only and exists precisely for this; `useReviewForm`
  // and `useReviewApprovalActions` already route through it.
  //
  // The tags below use the real wire shape: the prefix is always the NUMERIC
  // modifier id, because both the review subresource rows and the
  // TreeMultiSelect option ids encode it that way. `modifier_id` is therefore
  // asserted as a number, matching what the review form already submits.
  describe('#611: hyphenated ontology CURIEs survive submission intact', () => {
    test('submitReview forwards the whole CURIE, not just its first segment', async () => {
      let received: any = null;
      server.use(
        http.post(`${apiBase}/api/review/create`, async ({ request }) => {
          received = await request.json();
          return HttpResponse.json({ ok: true });
        })
      );

      const m = useEntityMutations();
      await m.submitReview({
        review_info: { synopsis: 's', comment: 'c' },
        select_phenotype: ['1-HP:0001249', '5-CURIE:part-with-hyphen'],
        select_variation: ['1-VariO:0015', '5-CURIE:part-with-hyphen'],
        select_additional_references: [],
        select_gene_reviews: [],
      });

      expect(received.review_json.phenotypes).toEqual([
        { phenotype_id: 'HP:0001249', modifier_id: 1 },
        { phenotype_id: 'CURIE:part-with-hyphen', modifier_id: 5 },
      ]);
      expect(received.review_json.variation_ontology).toEqual([
        { vario_id: 'VariO:0015', modifier_id: 1 },
        { vario_id: 'CURIE:part-with-hyphen', modifier_id: 5 },
      ]);
    });
  });

  test('error path resets submitting and surfaces toast', async () => {
    server.use(
      http.post(`${apiBase}/api/entity/rename`, () =>
        HttpResponse.json({ error: 'boom' }, { status: 500 })
      )
    );
    const toasts: unknown[][] = [];
    const m = useEntityMutations({ onToast: (...a) => toasts.push(a) });
    await expect(
      m.rename({ entity_info: { entity_id: 1 }, ontology_input: 'MONDO:1' })
    ).rejects.toBeTruthy();
    expect(m.submitting.value).toBeNull();
    expect(toasts[0]).toEqual(['boom', 'Error', 'danger']);
  });

  test('rename error toast uses API message from structured 400 response', async () => {
    const message = 'Bad Request. New disease_ontology_id_version is identical to the current one.';
    server.use(
      http.post(`${apiBase}/api/entity/rename`, () =>
        HttpResponse.json({ message }, { status: 400 })
      )
    );
    const toasts: unknown[][] = [];
    const m = useEntityMutations({ onToast: (...a) => toasts.push(a) });

    await expect(
      m.rename({ entity_info: { entity_id: 1 }, ontology_input: 'MONDO:1' })
    ).rejects.toBeTruthy();

    expect(m.submitting.value).toBeNull();
    expect(toasts[0]).toEqual([message, 'Error', 'danger']);
  });

  test('rename network error toast uses network error message', async () => {
    server.use(http.post(`${apiBase}/api/entity/rename`, () => HttpResponse.error()));
    const toasts: unknown[][] = [];
    const m = useEntityMutations({ onToast: (...a) => toasts.push(a) });

    await expect(
      m.rename({ entity_info: { entity_id: 1 }, ontology_input: 'MONDO:1' })
    ).rejects.toBeTruthy();

    expect(m.submitting.value).toBeNull();
    expect(toasts[0]).toEqual(['Network Error', 'Error', 'danger']);
  });

  test('deactivate error toast uses API message and resets submitting', async () => {
    const message = 'Bad Request. Replacement entity cannot be inactive.';
    server.use(
      http.post(`${apiBase}/api/entity/deactivate`, () =>
        HttpResponse.json({ message }, { status: 400 })
      )
    );
    const toasts: unknown[][] = [];
    const m = useEntityMutations({ onToast: (...a) => toasts.push(a) });

    await expect(
      m.deactivate({
        entity_info: { entity_id: 1 },
        deactivate_check: true,
        replace_entity_input: 5,
      })
    ).rejects.toBeTruthy();

    expect(m.submitting.value).toBeNull();
    expect(toasts[0]).toEqual([message, 'Error', 'danger']);
  });

  test('submitReview error toast uses API message from structured 409 response', async () => {
    const message = 'Conflict. Destination quadruple already exists.';
    server.use(
      http.post(`${apiBase}/api/review/create`, () =>
        HttpResponse.json({ message }, { status: 409 })
      )
    );
    const toasts: unknown[][] = [];
    const m = useEntityMutations({ onToast: (...a) => toasts.push(a) });

    await expect(
      m.submitReview({
        review_info: { synopsis: 's', comment: 'c' },
        select_phenotype: ['1-HP:0001249'],
        select_variation: ['1-VariO:0015'],
        select_additional_references: ['PMID:1'],
        select_gene_reviews: ['PMID:2'],
      })
    ).rejects.toBeTruthy();

    expect(m.submitting.value).toBeNull();
    expect(toasts[0]).toEqual([message, 'Error', 'danger']);
  });
});

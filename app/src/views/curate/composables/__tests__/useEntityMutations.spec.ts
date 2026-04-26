import { afterAll, afterEach, beforeAll, describe, expect, test } from 'vitest';
import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import { useEntityMutations } from '../useEntityMutations';

const server = setupServer();
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }));
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

const apiBase = import.meta.env.VITE_API_URL ?? '';

describe('useEntityMutations', () => {
  test('rename POST sends rename_json and toggles submitting', async () => {
    let received: any = null;
    server.use(
      http.post(`${apiBase}/api/entity/rename`, async ({ request }) => {
        received = await request.json();
        return HttpResponse.json({ ok: true });
      }),
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
      }),
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
      }),
    );
    const m = useEntityMutations();
    await m.submitReview({
      review_info: { synopsis: 's', comment: 'c' } as any,
      select_phenotype: ['present-HP:1'],
      select_variation: ['present-VARIO:1'],
      select_additional_references: ['PMID:1'],
      select_gene_reviews: ['PMID:2'],
    });
    expect(received.review_json).toBeDefined();
    expect(received.review_json.phenotypes.length).toBe(1);
    expect(received.review_json.variation_ontology.length).toBe(1);
  });

  test('error path resets submitting and surfaces toast', async () => {
    server.use(
      http.post(`${apiBase}/api/entity/rename`, () =>
        HttpResponse.json({ error: 'boom' }, { status: 500 }),
      ),
    );
    const toasts: any[] = [];
    const m = useEntityMutations({ onToast: (...a) => toasts.push(a) });
    await expect(
      m.rename({ entity_info: { entity_id: 1 }, ontology_input: 'MONDO:1' }),
    ).rejects.toBeTruthy();
    expect(m.submitting.value).toBeNull();
    expect(toasts.length).toBe(1);
  });
});

import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import {
  fetchMetadataCatalog,
  fetchMetadataRows,
  createMetadataRow,
  updateMetadataRow,
  deleteMetadataRow,
} from './metadata';

describe('api/metadata client', () => {
  afterEach(() => server.resetHandlers());

  it('fetches the vocabulary catalog', async () => {
    primeAuth();
    server.use(
      http.get('/api/metadata', () =>
        HttpResponse.json({
          data: [
            { slug: 'modifier', label: 'Modifiers', editable: true, fields: ['modifier_name'] },
            {
              slug: 'inheritance',
              label: 'Inheritance modes',
              editable: 'anchored',
              fields: ['hpo_mode_of_inheritance_term_name'],
            },
          ],
        })
      )
    );
    const catalog = await fetchMetadataCatalog();
    expect(catalog).toHaveLength(2);
    expect(catalog[0].slug).toBe('modifier');
    expect(catalog[1].editable).toBe('anchored');
  });

  it('normalises Plumber array-wrapped scalar descriptor fields', async () => {
    primeAuth();
    // Real /api/metadata serialises scalars as 1-element arrays (no jsonlite::unbox).
    server.use(
      http.get('/api/metadata', () =>
        HttpResponse.json({
          data: [
            {
              slug: ['modifier'],
              label: ['Modifiers'],
              table: ['modifier_list'],
              pk: ['modifier_id'],
              pk_type: ['integer'],
              editable: [true],
              managed: ['sysndd'],
              fields: ['modifier_name', 'allowed_phenotype'],
              has_is_active: [true],
            },
          ],
        })
      )
    );
    const catalog = await fetchMetadataCatalog();
    expect(catalog[0].slug).toBe('modifier');
    expect(catalog[0].pk).toBe('modifier_id');
    expect(catalog[0].editable).toBe(true);
    expect(catalog[0].fields).toEqual(['modifier_name', 'allowed_phenotype']);
    // pk must be a string so the view's humanizeLabel(vocab.pk) never crashes.
    expect(typeof catalog[0].pk).toBe('string');
  });

  it('lists rows for a vocabulary', async () => {
    primeAuth();
    server.use(
      http.get('/api/metadata/modifier', () =>
        HttpResponse.json({
          meta: { slug: 'modifier', label: 'Modifiers', editable: true, fields: ['modifier_name'] },
          data: [{ modifier_id: 1, modifier_name: 'present', is_active: 1 }],
        })
      )
    );
    const res = await fetchMetadataRows('modifier');
    expect(res.data).toHaveLength(1);
    expect(res.meta.slug).toBe('modifier');
  });

  it('creates a row via POST with a JSON body', async () => {
    primeAuth();
    let body: unknown;
    server.use(
      http.post('/api/metadata/modifier', async ({ request }) => {
        body = await request.json();
        return HttpResponse.json({ status: 201, message: 'OK', entry: { pk: 6 } }, { status: 201 });
      })
    );
    const result = await createMetadataRow('modifier', {
      modifier_name: 'transient',
      allowed_phenotype: 1,
    });
    expect(result.entry?.pk).toBe(6);
    expect(body).toEqual({ modifier_name: 'transient', allowed_phenotype: 1 });
  });

  it('updates a row via PUT to the id path', async () => {
    primeAuth();
    let url: URL | undefined;
    server.use(
      http.put('/api/metadata/status_category/2', ({ request }) => {
        url = new URL(request.url);
        return HttpResponse.json({ status: 200, message: 'OK', entry: { pk: 2 } });
      })
    );
    const result = await updateMetadataRow('status_category', 2, { category: 'Moderate*' });
    expect(result.status).toBe(200);
    expect(url?.pathname).toBe('/api/metadata/status_category/2');
  });

  it('surfaces the in-use delete guard error to the caller', async () => {
    primeAuth();
    server.use(
      http.delete('/api/metadata/modifier/1', () =>
        HttpResponse.json(
          { type: 'about:blank', title: 'Bad Request', detail: 'Cannot delete: in use.' },
          { status: 400 }
        )
      )
    );
    await expect(deleteMetadataRow('modifier', 1)).rejects.toThrow();
  });

  it('soft-deletes an unused row', async () => {
    primeAuth();
    server.use(
      http.delete('/api/metadata/modifier/9', () =>
        HttpResponse.json({ status: 200, message: 'OK. Vocabulary entry deactivated.' })
      )
    );
    const result = await deleteMetadataRow('modifier', 9);
    expect(result.status).toBe(200);
  });
});

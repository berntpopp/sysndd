// app/src/api/ontology.spec.ts
//
// Vitest + MSW spec for the typed ontology helpers (W3.13).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getOntology,
  listVariantOntology,
  updateVariantOntology,
  type OntologyTerm,
  type VariantOntologyListResponse,
} from './ontology';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/ontology — getOntology', () => {
  it('URL-encodes the ontology_input path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/ontology/:ontology_input', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json([]);
      })
    );

    await getOntology('OMIM:613970');
    expect(observedPath).toBe('/api/ontology/OMIM%3A613970');
  });

  it('returns the lookup array on 200', async () => {
    const ok: OntologyTerm[] = [
      {
        disease_ontology_id_version: ['OMIM:613970-2026-04-25'],
        disease_ontology_id: ['OMIM:613970'],
        disease_ontology_name: ['Some disease'],
        disease_ontology_source: ['OMIM'],
        disease_ontology_is_specific: ['1'],
        hgnc_id: ['HGNC:4586'],
        hpo_mode_of_inheritance_term: ['HP:0000006'],
        DOID: [''],
        MONDO: [''],
        Orphanet: [''],
        EFO: [''],
      },
    ];
    server.use(http.get('/api/ontology/:ontology_input', () => HttpResponse.json(ok)));

    const result = await getOntology('OMIM:613970');
    expect(result[0].disease_ontology_id[0]).toBe('OMIM:613970');
  });
});

describe('api/ontology — listVariantOntology', () => {
  it('forwards filter/sort/page_size params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: VariantOntologyListResponse = { links: {}, meta: {}, data: [] };
    server.use(
      http.get('/api/ontology/variant/table', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listVariantOntology({ filter: 'is_active:equals:1', sort: '-update_date' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('filter')).toBe('is_active:equals:1');
    expect(q.get('sort')).toBe('-update_date');
  });

  it('throws AxiosError on 403 (caller not Administrator)', async () => {
    server.use(
      http.get('/api/ontology/variant/table', () =>
        HttpResponse.json({ error: 'forbidden' }, { status: 403 })
      )
    );

    let caught: unknown;
    try {
      await listVariantOntology();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(403);
    }
  });
});

describe('api/ontology — updateVariantOntology', () => {
  it('PUTs the ontology_details body and returns the success message', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.put('/api/ontology/variant/update', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ message: 'Ontology details updated successfully.' });
      })
    );

    const result = await updateVariantOntology({
      ontology_details: { vario_id: 'VariO:0001', is_active: 0 },
    });

    expect((receivedBody as { ontology_details?: unknown }).ontology_details).toBeDefined();
    expect(result.message).toContain('updated');
  });

  it('throws AxiosError on 404 (vario_id not found)', async () => {
    server.use(
      http.put('/api/ontology/variant/update', () =>
        HttpResponse.json({ error: 'not found' }, { status: 404 })
      )
    );

    await expect(
      updateVariantOntology({ ontology_details: { vario_id: 'missing' } })
    ).rejects.toThrow();
  });
});

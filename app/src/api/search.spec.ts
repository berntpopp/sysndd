// app/src/api/search.spec.ts
//
// Vitest + MSW spec for the typed search helpers (W3.19).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  searchEntities,
  searchOntology,
  searchGene,
  searchInheritance,
  type EntitySearchRow,
  type OntologyTreeNode,
  type GeneSearchTreeNode,
} from './search';
import { server } from '@/test-utils/mocks/server';

describe('api/search — searchEntities', () => {
  it('URL-encodes the searchterm path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/search/:searchterm', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json([]);
      })
    );

    await searchEntities('GRIN 2B');
    expect(observedPath).toBe('/api/search/GRIN%202B');
  });

  it('forwards helper param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/search/:searchterm', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await searchEntities('GRIN2B', { helper: false });
    expect((observedQuery as unknown as URLSearchParams).get('helper')).toBe('false');
  });

  it('returns row results when helper=false', async () => {
    const ok: EntitySearchRow[] = [
      { entity_id: 7, search: 'symbol', results: 'GRIN2B', searchdist: 0, link: '/Genes/GRIN2B' },
    ];
    server.use(http.get('/api/search/:searchterm', () => HttpResponse.json(ok)));

    const result = await searchEntities('GRIN2B', { helper: false });
    expect((result as EntitySearchRow[])[0].results).toBe('GRIN2B');
  });
});

describe('api/search — searchOntology', () => {
  it('returns tree-shaped nodes when tree=true', async () => {
    const ok: OntologyTreeNode[] = [
      {
        id: 'OMIM:613970-2026-04-25',
        label: 'Some disease',
        disease_ontology_id_version: 'OMIM:613970-2026-04-25',
        disease_ontology_id: 'OMIM:613970',
        disease_ontology_name: 'Some disease',
        search: 'disease_ontology_name',
        searchdist: 0.0,
      },
    ];
    server.use(http.get('/api/search/ontology/:searchterm', () => HttpResponse.json(ok)));

    // The `{ tree: true }` overload narrows the return to
    // `OntologyTreeNode[]`, so no `as OntologyTreeNode[]` cast at the
    // call site (Copilot review on PR #306 — v11.1 W7 follow-up).
    const result = await searchOntology('OMIM:613970', { tree: true });
    expect(result[0].id).toBe('OMIM:613970-2026-04-25');
  });
});

describe('api/search — searchGene', () => {
  it('returns tree-shaped nodes when tree=true', async () => {
    const ok: GeneSearchTreeNode[] = [
      {
        id: 'HGNC:4586',
        label: 'GRIN2B',
        symbol: 'GRIN2B',
        name: 'glutamate ionotropic receptor NMDA type subunit 2B',
        search: 'symbol',
        searchdist: 0,
      },
    ];
    server.use(http.get('/api/search/gene/:searchterm', () => HttpResponse.json(ok)));

    // Same `{ tree: true }` overload pattern as searchOntology — the
    // return narrows to `GeneSearchTreeNode[]` without an inline cast.
    const result = await searchGene('GRIN2B', { tree: true });
    expect(result[0].symbol).toBe('GRIN2B');
  });
});

describe('api/search — searchInheritance', () => {
  it('forwards tree param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/search/inheritance/:searchterm', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await searchInheritance('Autosomal', { tree: true });
    expect((observedQuery as unknown as URLSearchParams).get('tree')).toBe('true');
  });
});

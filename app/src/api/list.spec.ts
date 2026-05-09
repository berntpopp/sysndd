// app/src/api/list.spec.ts
//
// Vitest + MSW spec for the typed list helpers (W3.10).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  listStatusCategories,
  listStatusCategoriesTree,
  listPhenotypes,
  listPhenotypesTree,
  listInheritance,
  listInheritanceTree,
  listVariationOntology,
  listVariationOntologyTree,
  type PaginatedListResponse,
  type StatusCategoryRow,
  type PhenotypeRow,
  type TreeNode,
} from './list';
import { server } from '@/test-utils/mocks/server';

describe('api/list — listStatusCategories (paginated)', () => {
  it('forwards tree=FALSE and pagination params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PaginatedListResponse<StatusCategoryRow> = {
      links: {},
      meta: {},
      data: [{ category_id: 1, category: 'Definitive' }],
    };
    server.use(
      http.get('/api/list/status', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await listStatusCategories({ page_size: '50' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('tree')).toBe('FALSE');
    expect(q.get('page_size')).toBe('50');
    expect(result.data[0].category).toBe('Definitive');
  });
});

describe('api/list — listStatusCategoriesTree', () => {
  it('forwards tree=TRUE and returns tree nodes', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: TreeNode[] = [{ id: 1, label: 'Definitive' }];
    server.use(
      http.get('/api/list/status', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await listStatusCategoriesTree();
    expect((observedQuery as unknown as URLSearchParams).get('tree')).toBe('TRUE');
    expect(result).toHaveLength(1);
  });
});

describe('api/list — listPhenotypes (paginated)', () => {
  it('returns the paginated phenotype envelope', async () => {
    const ok: PaginatedListResponse<PhenotypeRow> = {
      links: {},
      meta: {},
      data: [{ phenotype_id: 'HP:0001249', HPO_term: 'Intellectual disability' }],
    };
    server.use(http.get('/api/list/phenotype', () => HttpResponse.json(ok)));

    const result = await listPhenotypes();
    expect(result.data[0].phenotype_id).toBe('HP:0001249');
  });
});

describe('api/list — listPhenotypesTree', () => {
  it('returns tree nodes with modifier children', async () => {
    const ok: TreeNode[] = [
      {
        id: '1-HP:0001249',
        label: 'present: Intellectual disability',
        children: [{ id: '2-HP:0001249', label: 'absent: Intellectual disability' }],
      },
    ];
    server.use(http.get('/api/list/phenotype', () => HttpResponse.json(ok)));

    const result = await listPhenotypesTree();
    expect(result[0].children).toHaveLength(1);
  });
});

describe('api/list — listInheritance (paginated)', () => {
  it('returns the paginated inheritance envelope', async () => {
    const ok = {
      links: {},
      meta: {},
      data: [{ hpo_mode_of_inheritance_term: 'AD' }],
    };
    server.use(http.get('/api/list/inheritance', () => HttpResponse.json(ok)));

    const result = await listInheritance();
    expect(result.data[0].hpo_mode_of_inheritance_term).toBe('AD');
  });
});

describe('api/list — listInheritanceTree', () => {
  it('returns flat tree nodes (no children)', async () => {
    const ok: TreeNode[] = [{ id: 'AD', label: 'Autosomal dominant' }];
    server.use(http.get('/api/list/inheritance', () => HttpResponse.json(ok)));
    const result = await listInheritanceTree();
    expect(result[0].id).toBe('AD');
  });
});

describe('api/list — listVariationOntology (paginated)', () => {
  it('returns the paginated variation-ontology envelope', async () => {
    const ok = {
      links: {},
      meta: {},
      data: [{ vario_id: 'VariO:0001', vario_name: 'missense' }],
    };
    server.use(http.get('/api/list/variation_ontology', () => HttpResponse.json(ok)));

    const result = await listVariationOntology();
    expect(result.data[0].vario_id).toBe('VariO:0001');
  });
});

describe('api/list — listVariationOntologyTree', () => {
  it('returns tree nodes with modifier children', async () => {
    const ok: TreeNode[] = [
      {
        id: '1-VariO:0001',
        label: 'present: missense',
        children: [{ id: '2-VariO:0001', label: 'absent: missense' }],
      },
    ];
    server.use(http.get('/api/list/variation_ontology', () => HttpResponse.json(ok)));
    const result = await listVariationOntologyTree();
    expect(result[0].children).toHaveLength(1);
  });
});

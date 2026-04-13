// app/src/api/genes.spec.ts
/**
 * Phase E.E3 unit tests for the typed gene and uniprot-domains helpers.
 *
 * Covers:
 *   - `getGene(gene_input, input_type)`
 *   - `getGeneBySymbol(symbol)`
 *   - `listGenes(params)`
 *   - `getUniprotDomains(symbol)` (from api/external.ts)
 *
 * MSW handlers live in `@/test-utils/mocks/handlers` (registered with the
 * global server in `vitest.setup.ts`) and the fixtures live in
 * `@/test-utils/mocks/data/genes`. See `.plans/v11.0/phase-e.md` §3 Phase
 * E.E3 for the migration rationale; these tests lock in the wire shapes
 * before rewriting `GeneView.vue`.
 */

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';
import { getGene, getGeneBySymbol, listGenes } from './genes';
import { getUniprotDomains } from './external';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';
import {
  geneLookupOk,
  geneListOk,
  uniprotDomainsOk,
  UNIPROT_NOT_FOUND_SYMBOL,
} from '@/test-utils/mocks/data/genes';

describe('api/genes — typed helpers', () => {
  // ---------------------------------------------------------------------------
  // getGene
  // ---------------------------------------------------------------------------

  describe('getGene', () => {
    it('returns the 1-row lookup array for a valid HGNC id', async () => {
      const rows = await getGene('HGNC:4586', 'hgnc');

      expect(Array.isArray(rows)).toBe(true);
      expect(rows).toHaveLength(1);
      expect(rows[0].symbol).toEqual(geneLookupOk[0].symbol);
      expect(rows[0].hgnc_id).toEqual(['HGNC:4586']);
      // Phase A A2 regression guard: gnomad_constraints arrives as a scalar
      // JSON string (NOT a pipe-split array).
      expect(typeof rows[0].gnomad_constraints).toBe('string');
    });

    it('defaults input_type to "hgnc" when omitted', async () => {
      let observedInputType: string | null = null;
      server.use(
        http.get('/api/gene/:gene_input', ({ request }) => {
          observedInputType = new URL(request.url).searchParams.get('input_type');
          return HttpResponse.json(geneLookupOk);
        }),
      );

      await getGene('HGNC:4586');
      expect(observedInputType).toBe('hgnc');
    });

    it('sends input_type=symbol when explicitly requested', async () => {
      let observedInputType: string | null = null;
      server.use(
        http.get('/api/gene/:gene_input', ({ request }) => {
          observedInputType = new URL(request.url).searchParams.get('input_type');
          return HttpResponse.json(geneLookupOk);
        }),
      );

      await getGene('GRIN2B', 'symbol');
      expect(observedInputType).toBe('symbol');
    });

    it('returns an empty array for the UNKNOWN_GENE sentinel', async () => {
      const rows = await getGene('UNKNOWN_GENE', 'symbol');
      expect(Array.isArray(rows)).toBe(true);
      expect(rows).toHaveLength(0);
    });

    it('URL-encodes the gene_input path param', async () => {
      let observedPath: string | null = null;
      server.use(
        http.get('/api/gene/:gene_input', ({ params, request }) => {
          observedPath = new URL(request.url).pathname;
          // Also confirm MSW decoded the path param back to the raw value.
          expect(params.gene_input).toBe('HGNC:4586');
          return HttpResponse.json(geneLookupOk);
        }),
      );

      await getGene('HGNC:4586', 'hgnc');
      // `:` must be percent-encoded in the outgoing URL — otherwise callers
      // with symbols containing reserved characters would drop path segments.
      expect(observedPath).toBe('/api/gene/HGNC%3A4586');
    });
  });

  // ---------------------------------------------------------------------------
  // getGeneBySymbol
  // ---------------------------------------------------------------------------

  describe('getGeneBySymbol', () => {
    it('wraps getGene with input_type=symbol', async () => {
      let observedInputType: string | null = null;
      let observedSymbol: string | null = null;
      server.use(
        http.get('/api/gene/:gene_input', ({ params, request }) => {
          observedSymbol = String(params.gene_input);
          observedInputType = new URL(request.url).searchParams.get('input_type');
          return HttpResponse.json(geneLookupOk);
        }),
      );

      const rows = await getGeneBySymbol('GRIN2B');
      expect(observedSymbol).toBe('GRIN2B');
      expect(observedInputType).toBe('symbol');
      expect(rows).toHaveLength(1);
      expect(rows[0].symbol).toEqual(['GRIN2B']);
    });
  });

  // ---------------------------------------------------------------------------
  // listGenes
  // ---------------------------------------------------------------------------

  describe('listGenes', () => {
    it('returns the cursor-paginated envelope', async () => {
      const envelope = await listGenes({ page_size: '10' });

      expect(envelope).toHaveProperty('data');
      expect(envelope).toHaveProperty('meta');
      expect(envelope).toHaveProperty('links');
      expect(Array.isArray(envelope.data)).toBe(true);
      expect(envelope.data).toHaveLength(geneListOk.data.length);
      expect(envelope.data[0].symbol).toEqual(geneListOk.data[0].symbol);
    });

    it('forwards all listing params to the query string', async () => {
      let observedQuery: URLSearchParams | null = null;
      server.use(
        http.get('/api/gene', ({ request }) => {
          observedQuery = new URL(request.url).searchParams;
          return HttpResponse.json(geneListOk);
        }),
      );

      await listGenes({
        sort: 'symbol',
        filter: 'contains(symbol,GR)',
        fields: 'hgnc_id,symbol',
        page_after: 'HGNC:4586',
        page_size: '25',
        fspec: 'default',
      });

      expect(observedQuery).not.toBeNull();
      const q = observedQuery as unknown as URLSearchParams;
      expect(q.get('sort')).toBe('symbol');
      expect(q.get('filter')).toBe('contains(symbol,GR)');
      expect(q.get('fields')).toBe('hgnc_id,symbol');
      expect(q.get('page_after')).toBe('HGNC:4586');
      expect(q.get('page_size')).toBe('25');
      expect(q.get('fspec')).toBe('default');
    });

    it('works with no params (defaults)', async () => {
      const envelope = await listGenes();
      expect(envelope).toHaveProperty('data');
    });
  });
});

describe('api/external — getUniprotDomains', () => {
  it('returns the UniProt domains payload on 200', async () => {
    const data = await getUniprotDomains('GRIN2B');

    expect(data.source).toBe('uniprot');
    expect(data.gene_symbol).toBe(uniprotDomainsOk.gene_symbol);
    expect(data.accession).toBe(uniprotDomainsOk.accession);
    expect(Array.isArray(data.domains)).toBe(true);
    expect(data.domains.length).toBeGreaterThan(0);
    expect(data.domains[0]).toHaveProperty('type');
    expect(data.domains[0]).toHaveProperty('begin');
    expect(data.domains[0]).toHaveProperty('end');
  });

  it('URL-encodes the symbol path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/external/uniprot/domains/:symbol', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json(uniprotDomainsOk);
      }),
    );

    await getUniprotDomains('GRIN 2B');
    expect(observedPath).toBe('/api/external/uniprot/domains/GRIN%202B');
  });

  it('rejects with an AxiosError on the 404 sentinel branch', async () => {
    let caught: unknown;
    try {
      await getUniprotDomains(UNIPROT_NOT_FOUND_SYMBOL);
    } catch (err) {
      caught = err;
    }

    expect(caught).toBeDefined();
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(404);
    }
  });
});

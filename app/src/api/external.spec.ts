// app/src/api/external.spec.ts
//
// Vitest + MSW spec for the typed external-proxy helpers.
//
// `getUniprotDomains` already has cross-coverage in `genes.spec.ts` (it lives
// in this module but was migrated alongside the gene-lookup helpers in Phase
// E.E3). This spec focuses on the v11.1 W7 finish-hardening addition:
//
//   - getEnsemblStructure(symbol)
//
// The helper throws the underlying AxiosError on non-2xx — consumers
// (`GeneStructureCard.vue`, `GenomicVisualizationTabs.vue`) catch the error
// and map status codes to UI states.

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import { getEnsemblStructure, type EnsemblGeneStructure } from './external';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

const ensemblOk: EnsemblGeneStructure = {
  source: 'ensembl',
  gene_symbol: 'BRCA1',
  gene_id: 'ENSG00000012048',
  chromosome: '17',
  start: 43044295,
  end: 43125483,
  strand: -1,
  canonical_transcript: {
    transcript_id: 'ENST00000357654',
    start: 43044295,
    end: 43125483,
    biotype: 'protein_coding',
    exons: [
      { id: 'ENSE00003510133', start: 43044295, end: 43045802 },
      { id: 'ENSE00003666217', start: 43047642, end: 43047703 },
    ],
  },
};

describe('api/external — getEnsemblStructure', () => {
  it('returns the gene-structure payload on 200', async () => {
    server.use(
      http.get('/api/external/ensembl/structure/:symbol', ({ params }) => {
        expect(params.symbol).toBe('BRCA1');
        return HttpResponse.json(ensemblOk);
      })
    );

    const result = await getEnsemblStructure('BRCA1');
    expect(result).toEqual(ensemblOk);
    expect(result.canonical_transcript.exons).toHaveLength(2);
  });

  it('URL-encodes the symbol path segment', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/external/ensembl/structure/:symbol', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json(ensemblOk);
      })
    );

    // Symbols with special characters (rare but possible — e.g. orf-style
    // names) must be encoded so the route matches the R Plumber path.
    await getEnsemblStructure('C9orf72/foo');
    expect(observedPath).toBe('/api/external/ensembl/structure/C9orf72%2Ffoo');
  });

  it('throws AxiosError on 404 (gene not in Ensembl)', async () => {
    server.use(
      http.get('/api/external/ensembl/structure/:symbol', () =>
        HttpResponse.json(
          {
            type: 'https://sysndd.org/problems/not-found',
            title: 'Not Found',
            status: 404,
            detail: 'Gene NOPE not found in Ensembl',
            source: 'ensembl',
          },
          { status: 404 }
        )
      )
    );

    let caught: unknown;
    try {
      await getEnsemblStructure('NOPE');
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(404);
    }
  });

  it('throws AxiosError on 503 (Ensembl upstream unavailable)', async () => {
    server.use(
      http.get('/api/external/ensembl/structure/:symbol', () =>
        HttpResponse.json({ error: 'upstream' }, { status: 503 })
      )
    );
    await expect(getEnsemblStructure('BRCA1')).rejects.toThrow();
  });
});

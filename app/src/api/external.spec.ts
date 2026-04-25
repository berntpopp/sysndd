// app/src/api/external.spec.ts
//
// Vitest + MSW spec for the typed external-proxy helpers.
//
// `getUniprotDomains` already has cross-coverage in `genes.spec.ts` (it lives
// in this module but was migrated alongside the gene-lookup helpers in Phase
// E.E3). This spec focuses on the v11.1 W7 finish-hardening additions:
//
//   - getEnsemblStructure(symbol)
//   - createInternetArchiveSnapshot(url)
//
// Both helpers throw the underlying AxiosError on non-2xx — consumers
// (`GeneStructureCard.vue`, `GenomicVisualizationTabs.vue`, `HelperBadge.vue`)
// catch the error and map status codes to UI states.

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getEnsemblStructure,
  createInternetArchiveSnapshot,
  type EnsemblGeneStructure,
  type InternetArchiveSnapshot,
} from './external';
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
      }),
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
      }),
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
          { status: 404 },
        ),
      ),
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
        HttpResponse.json({ error: 'upstream' }, { status: 503 }),
      ),
    );
    await expect(getEnsemblStructure('BRCA1')).rejects.toThrow();
  });
});

describe('api/external — createInternetArchiveSnapshot', () => {
  it('forwards the URL via parameter_url and returns the snapshot envelope', async () => {
    let observedParam: string | null = null;
    const expected: InternetArchiveSnapshot = {
      job_id: 'spn2-abc123',
      url: 'https://sysndd.dbmr.unibe.ch/Genes/HGNC:4586',
      status: 'pending',
    };
    server.use(
      http.get('/api/external/internet_archive', ({ request }) => {
        observedParam = new URL(request.url).searchParams.get('parameter_url');
        return HttpResponse.json(expected);
      }),
    );

    const target = 'https://sysndd.dbmr.unibe.ch/Genes/HGNC:4586';
    const result = await createInternetArchiveSnapshot(target);
    expect(observedParam).toBe(target);
    expect(result).toEqual(expected);
    expect(result.job_id).toBe('spn2-abc123');
  });

  it('merges caller-supplied params with parameter_url', async () => {
    let observedParams: Record<string, string> = {};
    server.use(
      http.get('/api/external/internet_archive', ({ request }) => {
        const url = new URL(request.url);
        observedParams = Object.fromEntries(url.searchParams.entries());
        return HttpResponse.json({ job_id: 'spn2-merged' });
      }),
    );

    await createInternetArchiveSnapshot('https://sysndd.dbmr.unibe.ch/foo', {
      params: { capture_screenshot: 'off' },
    });
    expect(observedParams.parameter_url).toBe('https://sysndd.dbmr.unibe.ch/foo');
    expect(observedParams.capture_screenshot).toBe('off');
  });

  it('throws AxiosError on 400 (URL outside the SysNDD allowlist)', async () => {
    server.use(
      http.get('/api/external/internet_archive', () =>
        HttpResponse.json(
          {
            status: 400,
            message: "Required 'url' parameter not provided or not valid.",
          },
          { status: 400 },
        ),
      ),
    );

    let caught: unknown;
    try {
      await createInternetArchiveSnapshot('https://example.com');
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(400);
    }
  });
});

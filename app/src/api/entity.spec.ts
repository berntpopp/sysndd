// app/src/api/entity.spec.ts
//
// Vitest + MSW spec for the typed entity helpers (W3.6).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  listEntities,
  listEntitiesXlsx,
  createEntity,
  renameEntity,
  deactivateEntity,
  getEntityPhenotypes,
  getEntityVariation,
  getEntityVariationEvidence,
  getEntityVariationSuggestions,
  getEntityReview,
  getEntityStatus,
  getEntityPublications,
  type EntityListResponse,
  type EntityMutationResponse,
} from './entity';
import { normalizeVariationRows } from './entity-variation-wire';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/entity — listEntities', () => {
  it('forwards format=json + filter/fields params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: EntityListResponse = { links: {}, meta: {}, data: [] };
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listEntities({ filter: 'symbol:GRIN2B', fields: 'entity_id,symbol' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('json');
    expect(q.get('filter')).toBe('symbol:GRIN2B');
    expect(q.get('fields')).toBe('entity_id,symbol');
  });

  it('forwards compact=true to the entity endpoint when set', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ links: {}, meta: {}, data: [] });
      })
    );
    await listEntities({ filter: 'equals(symbol,GRIN2B)', compact: true });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('compact')).toBe('true');
  });

  it('does not include compact when omitted (default behaviour preserved)', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ links: {}, meta: {}, data: [] });
      })
    );
    await listEntities({ filter: 'equals(symbol,GRIN2B)' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('compact')).toBeNull();
  });

  it('forwards compact=false explicitly when caller passes it', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ links: {}, meta: {}, data: [] });
      })
    );
    await listEntities({ filter: 'equals(symbol,GRIN2B)', compact: false });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('compact')).toBe('false');
  });
});

describe('api/entity — listEntitiesXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return new HttpResponse(new Uint8Array([0x50, 0x4b, 0x03, 0x04]), {
          status: 200,
          headers: {
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        });
      })
    );

    const blob = await listEntitiesXlsx({ sort: 'entity_id' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('xlsx');
    expect(q.get('sort')).toBe('entity_id');
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/entity — createEntity', () => {
  it('POSTs the create_json body and forwards direct_approval', async () => {
    let receivedBody: unknown = null;
    let observedQuery: URLSearchParams | null = null;
    const ok: EntityMutationResponse = {
      status: 200,
      message: 'OK',
      entry: { entity_id: 7 },
    };
    server.use(
      http.post('/api/entity/create', async ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        receivedBody = await request.json();
        return HttpResponse.json(ok, { status: 201 });
      })
    );

    const result = await createEntity(
      {
        create_json: {
          entity: {
            hgnc_id: 'HGNC:4586',
            disease_ontology_id_version: 'OMIM:613970-2026-04-25',
            hpo_mode_of_inheritance_term: 'AD',
            ndd_phenotype: 1,
          },
          review: { comment: 'sample' },
          status: { category_id: 1 },
        },
      },
      { direct_approval: true }
    );

    expect((receivedBody as { create_json?: unknown }).create_json).toBeDefined();
    expect((observedQuery as unknown as URLSearchParams).get('direct_approval')).toBe('true');
    expect(result.entry?.entity_id).toBe(7);
  });

  it('throws AxiosError on 409 (duplicate)', async () => {
    server.use(
      http.post('/api/entity/create', () =>
        HttpResponse.json({ status: 409, message: 'duplicate' }, { status: 409 })
      )
    );

    let caught: unknown;
    try {
      await createEntity({
        create_json: {
          entity: {
            hgnc_id: 'HGNC:1',
            disease_ontology_id_version: 'OMIM:1-2026-01-01',
            hpo_mode_of_inheritance_term: 'AD',
            ndd_phenotype: 1,
          },
          review: {},
          status: { category_id: 1 },
        },
      });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(409);
    }
  });
});

describe('api/entity — renameEntity', () => {
  it('POSTs the rename_json body', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/entity/rename', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200, entry: { entity_id: 8 } });
      })
    );

    await renameEntity({
      rename_json: {
        entity: {
          entity_id: 7,
          hgnc_id: 'HGNC:4586',
          hpo_mode_of_inheritance_term: 'AD',
          ndd_phenotype: 1,
          disease_ontology_id_version: 'OMIM:613970-2026-05-01',
        },
      },
    });

    expect((receivedBody as { rename_json?: unknown }).rename_json).toBeDefined();
  });
});

describe('api/entity — deactivateEntity', () => {
  it('POSTs the deactivate_json body', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/entity/deactivate', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200, message: 'OK' });
      })
    );

    await deactivateEntity({
      deactivate_json: {
        entity: {
          entity_id: 7,
          hgnc_id: 'HGNC:4586',
          hpo_mode_of_inheritance_term: 'AD',
          ndd_phenotype: 1,
          is_active: 0,
          replaced_by: null,
        },
      },
    });

    expect((receivedBody as { deactivate_json?: unknown }).deactivate_json).toBeDefined();
  });
});

describe('api/entity — getEntityPhenotypes', () => {
  it('URL-encodes the path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/entity/:id/phenotypes', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json([]);
      })
    );

    await getEntityPhenotypes(7);
    expect(observedPath).toBe('/api/entity/7/phenotypes');
  });

  it('serializes current_review boolean as TRUE/FALSE for the R server', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/:id/phenotypes', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await getEntityPhenotypes(7, { current_review: false });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('current_review')).toBe('FALSE');
  });
});

describe('api/entity — getEntityVariation', () => {
  it('returns the variation rows on 200', async () => {
    server.use(
      http.get('/api/entity/:id/variation', () =>
        HttpResponse.json([
          { entity_id: 7, vario_id: 'VariO:0001', vario_name: 'missense', modifier_id: 1 },
        ])
      )
    );

    const rows = await getEntityVariation(7);
    expect(rows).toHaveLength(1);
    expect(rows[0].vario_id).toBe('VariO:0001');
  });
});

// ---------------------------------------------------------------------------
// #608 provenance wire-shape normalization
//
// Every payload below is the VERBATIM boxed shape R/Plumber emits (it does not
// auto-unbox, so `list()`-built scalars ship as length-1 arrays). Assertions use
// `toBe`, so a surviving `['confirmed']` cannot pass. The bug this guards:
// `provenance?.state === 'active_unconfirmed'` is FALSE against
// `['active_unconfirmed']`, which silently emptied the curation form's
// "Needs confirmation" zone.
// ---------------------------------------------------------------------------

/** Nested, double-wrapped manifest payload — must be passed through untouched. */
const BOXED_EVIDENCE_JSON = {
  records: [{ variation_id: ['VCV000012345'], classification: ['Pathogenic'] }],
  matched: [['OMIM:615032']],
};

const BOXED_PROVENANCE = {
  state: ['active_unconfirmed'],
  max_strength: [1],
  sources: [
    {
      source_type: ['external_database'],
      source_key: ['clinvar'],
      strength: [1],
      summary: ['2 ClinVar records, max 1 star'],
    },
  ],
};

/** Data-frame columns arrive unboxed; only the `provenance` list-column is boxed. */
const boxedVariationRow = (provenance?: unknown): Record<string, unknown> => ({
  entity_id: 7,
  vario_id: 'VariO:0017',
  vario_name: 'gain of function',
  modifier_id: 1,
  ...(provenance === undefined ? {} : { provenance }),
});

const serveVariation = (rows: Record<string, unknown>[]): void => {
  server.use(http.get('/api/entity/:id/variation', () => HttpResponse.json(rows)));
};

describe('api/entity — getEntityVariation provenance normalization', () => {
  it('unboxes the provenance scalars and every sources[] scalar', async () => {
    serveVariation([boxedVariationRow(BOXED_PROVENANCE)]);

    const rows = await getEntityVariation(7);
    const provenance = rows[0].provenance;
    expect(provenance).not.toBeNull();
    expect(provenance?.state).toBe('active_unconfirmed');
    expect(provenance?.max_strength).toBe(1);
    expect(provenance?.sources).toHaveLength(1);
    const source = provenance?.sources[0];
    expect(source?.source_type).toBe('external_database');
    expect(source?.source_key).toBe('clinvar');
    expect(source?.strength).toBe(1);
    expect(source?.summary).toBe('2 ClinVar records, max 1 star');
  });

  it('keeps provenance: null (the curator-authored contract) as null', async () => {
    serveVariation([boxedVariationRow(null)]);

    const rows = await getEntityVariation(7);
    expect(rows[0].provenance).toBeNull();
  });

  it('leaves an absent provenance key absent (pre-#608 API build)', async () => {
    serveVariation([boxedVariationRow()]);

    const rows = await getEntityVariation(7);
    expect('provenance' in rows[0]).toBe(false);
    expect(rows[0].vario_id).toBe('VariO:0017');
  });

  it('keeps an unrecorded strength as null and never coerces it to 0', async () => {
    serveVariation([
      boxedVariationRow({
        state: ['confirmed'],
        max_strength: null,
        sources: [
          {
            source_type: ['literature'],
            source_key: ['synopsis'],
            strength: null,
            summary: ['Reported in the clinical synopsis'],
          },
        ],
      }),
    ]);

    const rows = await getEntityVariation(7);
    expect(rows[0].provenance?.state).toBe('confirmed');
    expect(rows[0].provenance?.max_strength).toBeNull();
    expect(rows[0].provenance?.sources[0].strength).toBeNull();
    expect(rows[0].provenance?.sources[0].strength).not.toBe(0);
  });

  it('is idempotent — an already-unboxed payload passes through unchanged', async () => {
    const unboxed = {
      state: 'active_unconfirmed',
      max_strength: 1,
      sources: [
        {
          source_type: 'external_database',
          source_key: 'clinvar',
          strength: 1,
          summary: '2 ClinVar records, max 1 star',
        },
      ],
    };
    serveVariation([boxedVariationRow(unboxed)]);

    const rows = await getEntityVariation(7);
    expect(rows[0].provenance?.state).toBe('active_unconfirmed');
    expect(rows[0].provenance?.sources[0].strength).toBe(1);
    // Re-normalizing the already-normalized result must be a no-op.
    expect(normalizeVariationRows(rows)).toEqual(rows);
  });

  it('is idempotent for a boxed payload normalized twice', async () => {
    serveVariation([boxedVariationRow(BOXED_PROVENANCE)]);

    const once = await getEntityVariation(7);
    const twice = normalizeVariationRows(normalizeVariationRows(once));
    expect(twice[0].provenance?.state).toBe('active_unconfirmed');
    expect(twice[0].provenance?.sources[0].summary).toBe('2 ClinVar records, max 1 star');
  });
});

describe('api/entity — getEntityVariationEvidence normalization', () => {
  const serveEvidence = (): void => {
    server.use(
      http.get('/api/entity/:id/variation/:varioId/:modifierId/evidence', () =>
        HttpResponse.json({
          entity_id: [7],
          vario_id: ['VariO:0017'],
          modifier_id: [1],
          state: ['confirmed'],
          evidence: [
            {
              source_type: ['external_database'],
              source_key: ['clinvar'],
              batch_id: ['clinvar-2026-07'],
              source_version: ['2026-07-01'],
              evidence_summary: ['2 ClinVar records, max 1 star'],
              evidence_strength: [1],
              evidence_json: BOXED_EVIDENCE_JSON,
            },
            {
              source_type: ['literature'],
              source_key: ['synopsis'],
              batch_id: ['synopsis-2026-07'],
              source_version: null,
              evidence_summary: ['Reported in the clinical synopsis'],
              evidence_strength: null,
              evidence_json: null,
            },
          ],
        })
      )
    );
  };

  it('unboxes the top-level scalars and every evidence[] record scalar', async () => {
    serveEvidence();

    const response = await getEntityVariationEvidence(7, 'VariO:0017', 1);
    expect(response.entity_id).toBe(7);
    expect(response.vario_id).toBe('VariO:0017');
    expect(response.modifier_id).toBe(1);
    expect(response.state).toBe('confirmed');

    const [first, second] = response.evidence;
    expect(first.source_type).toBe('external_database');
    expect(first.source_key).toBe('clinvar');
    expect(first.batch_id).toBe('clinvar-2026-07');
    expect(first.source_version).toBe('2026-07-01');
    expect(first.evidence_summary).toBe('2 ClinVar records, max 1 star');
    expect(first.evidence_strength).toBe(1);

    // Unrecorded values stay null, never 0 / ''.
    expect(second.source_version).toBeNull();
    expect(second.evidence_strength).toBeNull();
    expect(second.evidence_strength).not.toBe(0);
  });

  it('passes evidence_json through UNTOUCHED, double-wrapping included', async () => {
    serveEvidence();

    const response = await getEntityVariationEvidence(7, 'VariO:0017', 1);
    expect(response.evidence[0].evidence_json).toEqual(BOXED_EVIDENCE_JSON);
    expect((response.evidence[0].evidence_json as { matched: unknown }).matched).toEqual([
      ['OMIM:615032'],
    ]);
    expect(response.evidence[1].evidence_json).toBeNull();
  });
});

describe('api/entity — getEntityVariationSuggestions normalization', () => {
  it('unboxes suggestion scalars and their evidence[] records', async () => {
    server.use(
      http.get('/api/entity/:id/variation/suggestions', () =>
        HttpResponse.json([
          {
            entity_id: [7],
            vario_id: ['VariO:0331'],
            vario_name: ['loss of function'],
            modifier_id: [1],
            state: ['suggested'],
            max_strength: [2],
            evidence: [
              {
                source_type: ['external_database'],
                source_key: ['clinvar'],
                batch_id: ['clinvar-2026-07'],
                source_version: ['2026-07-01'],
                evidence_summary: ['4 ClinVar records, max 2 stars'],
                evidence_strength: [2],
                evidence_json: BOXED_EVIDENCE_JSON,
              },
            ],
          },
        ])
      )
    );

    const suggestions = await getEntityVariationSuggestions(7);
    expect(suggestions).toHaveLength(1);
    const suggestion = suggestions[0];
    expect(suggestion.entity_id).toBe(7);
    expect(suggestion.vario_id).toBe('VariO:0331');
    expect(suggestion.vario_name).toBe('loss of function');
    expect(suggestion.modifier_id).toBe(1);
    expect(suggestion.state).toBe('suggested');
    expect(suggestion.max_strength).toBe(2);
    expect(suggestion.evidence[0].source_key).toBe('clinvar');
    expect(suggestion.evidence[0].evidence_strength).toBe(2);
    // Same cross-repo contract as the evidence route — never normalized.
    expect(suggestion.evidence[0].evidence_json).toEqual(BOXED_EVIDENCE_JSON);
  });

  it('returns an empty array unchanged', async () => {
    server.use(http.get('/api/entity/:id/variation/suggestions', () => HttpResponse.json([])));

    await expect(getEntityVariationSuggestions(7)).resolves.toEqual([]);
  });
});

describe('api/entity — getEntityReview', () => {
  it('returns the review rows on 200', async () => {
    server.use(
      http.get('/api/entity/:id/review', () =>
        HttpResponse.json([
          {
            entity_id: 7,
            review_id: 100,
            synopsis: 'foo',
            review_date: '2026-01-01',
            comment: null,
          },
        ])
      )
    );

    const rows = await getEntityReview(7);
    expect(rows[0].review_id).toBe(100);
  });
});

describe('api/entity — getEntityStatus', () => {
  it('returns the status rows on 200', async () => {
    server.use(
      http.get('/api/entity/:id/status', () =>
        HttpResponse.json([
          {
            status_id: 1,
            entity_id: 7,
            category: 'Definitive',
            category_id: 5,
            status_date: '2026-01-01',
            comment: null,
            problematic: 0,
          },
        ])
      )
    );

    const rows = await getEntityStatus(7);
    expect(rows[0].category).toBe('Definitive');
  });
});

describe('api/entity — getEntityPublications', () => {
  it('returns the publications on 200', async () => {
    server.use(
      http.get('/api/entity/:id/publications', () =>
        HttpResponse.json([
          {
            entity_id: 7,
            publication_id: 'PMID:12345',
            publication_type: 'gene_review',
            is_reviewed: 1,
          },
        ])
      )
    );

    const rows = await getEntityPublications(7);
    expect(rows[0].publication_id).toBe('PMID:12345');
  });
});

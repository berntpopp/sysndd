// app/src/api/disease-mappings.spec.ts
//
// Unit tests for normalizeDiseaseMappingResponse.
//
// These tests feed the EXACT array-wrapped wire shapes returned by the live
// /api/disease/mappings R/Plumber endpoint and assert that the normaliser
// produces clean, unboxed DiseaseMappingResponse values that match the type
// contract.

import { describe, it, expect } from 'vitest';
import { normalizeDiseaseMappingResponse } from './disease-mappings';

// ---------------------------------------------------------------------------
// Wire fixtures — copy-pasted from the live dev API (verified 2026-06-20)
// ---------------------------------------------------------------------------

/**
 * Populated response (status: "current") from:
 *   GET /api/disease/mappings?disease_ontology_id=OMIM:618524
 */
const WIRE_POPULATED = {
  disease_ontology_id: ['OMIM:618524'],
  disease_ontology_name: ['Congenital myopathy 16'],
  mondo_id: ['MONDO:0032797'],
  release_version: ['2026-06-02'],
  status: ['current'],
  mappings: {
    MONDO: [
      { id: ['MONDO:0032797'], label: [null], predicate: ['exactMatch'], source: ['mondo_sssom'] },
    ],
    OMIM: [{ id: ['OMIM:618524'], label: [null], predicate: [null], source: ['sysndd_native'] }],
    DOID: [
      {
        id: ['DOID:0081348'],
        label: ['congenital myopathy 16'],
        predicate: ['exactMatch'],
        source: ['mondo_sssom'],
      },
    ],
  },
};

/**
 * Missing response (status: "missing") from:
 *   GET /api/disease/mappings?entity_id=99999999
 * Plumber emits {} for NULL scalar columns (not `null`).
 */
const WIRE_MISSING = {
  disease_ontology_id: [null],
  disease_ontology_name: [null],
  mondo_id: {},
  release_version: {},
  status: ['missing'],
  mappings: [],
};

// ---------------------------------------------------------------------------
// Populated ("current") tests
// ---------------------------------------------------------------------------

describe('normalizeDiseaseMappingResponse — populated (current)', () => {
  const result = normalizeDiseaseMappingResponse(WIRE_POPULATED);

  it('unwraps status to bare string "current"', () => {
    expect(result.status).toBe('current');
  });

  it('unwraps disease_ontology_id to bare string', () => {
    expect(result.disease_ontology_id).toBe('OMIM:618524');
  });

  it('unwraps disease_ontology_name to bare string', () => {
    expect(result.disease_ontology_name).toBe('Congenital myopathy 16');
  });

  it('unwraps mondo_id to bare string', () => {
    expect(result.mondo_id).toBe('MONDO:0032797');
  });

  it('unwraps release_version to bare string', () => {
    expect(result.release_version).toBe('2026-06-02');
  });

  it('exposes MONDO prefix in mappings', () => {
    expect(result.mappings).toHaveProperty('MONDO');
    expect(result.mappings['MONDO']).toHaveLength(1);
  });

  it('unwraps mappings[MONDO][0].id to bare string', () => {
    expect(result.mappings['MONDO']![0]!.id).toBe('MONDO:0032797');
  });

  it('unwraps mappings[MONDO][0].label [null] to null', () => {
    expect(result.mappings['MONDO']![0]!.label).toBeNull();
  });

  it('unwraps mappings[MONDO][0].predicate to bare string', () => {
    expect(result.mappings['MONDO']![0]!.predicate).toBe('exactMatch');
  });

  it('unwraps mappings[MONDO][0].source to bare string', () => {
    expect(result.mappings['MONDO']![0]!.source).toBe('mondo_sssom');
  });

  it('unwraps mappings[OMIM][0].predicate [null] to null', () => {
    expect(result.mappings['OMIM']![0]!.predicate).toBeNull();
  });

  it('unwraps mappings[DOID][0].label to bare string', () => {
    expect(result.mappings['DOID']![0]!.label).toBe('congenital myopathy 16');
  });

  it('exposes exactly 3 prefix keys (MONDO, OMIM, DOID)', () => {
    expect(Object.keys(result.mappings).sort()).toEqual(['DOID', 'MONDO', 'OMIM']);
  });
});

// ---------------------------------------------------------------------------
// Missing tests
// ---------------------------------------------------------------------------

describe('normalizeDiseaseMappingResponse — missing', () => {
  const result = normalizeDiseaseMappingResponse(WIRE_MISSING);

  it('unwraps status to bare string "missing"', () => {
    expect(result.status).toBe('missing');
  });

  it('unwraps disease_ontology_id [null] to empty string (falsy)', () => {
    // [null] → null → coerced to '' by ?? ''
    expect(result.disease_ontology_id).toBe('');
  });

  it('unwraps mondo_id {} (empty object) to null', () => {
    expect(result.mondo_id).toBeNull();
  });

  it('unwraps release_version {} (empty object) to null', () => {
    expect(result.release_version).toBeNull();
  });

  it('produces empty mappings object (not an array)', () => {
    expect(result.mappings).toEqual({});
    expect(Array.isArray(result.mappings)).toBe(false);
  });
});

// ---------------------------------------------------------------------------
// Edge cases
// ---------------------------------------------------------------------------

describe('normalizeDiseaseMappingResponse — edge cases', () => {
  it('returns missing shape for null input', () => {
    const r = normalizeDiseaseMappingResponse(null);
    expect(r.status).toBe('missing');
    expect(r.mappings).toEqual({});
  });

  it('returns missing shape for undefined input', () => {
    const r = normalizeDiseaseMappingResponse(undefined);
    expect(r.status).toBe('missing');
    expect(r.mappings).toEqual({});
  });

  it('returns missing shape for non-object primitive', () => {
    const r = normalizeDiseaseMappingResponse(42);
    expect(r.status).toBe('missing');
  });

  it('passes through already-unboxed scalars (defensive passthrough)', () => {
    const alreadyUnboxed = {
      disease_ontology_id: 'OMIM:618524',
      disease_ontology_name: 'Congenital myopathy 16',
      mondo_id: 'MONDO:0032797',
      release_version: '2026-06-02',
      status: 'current',
      mappings: {},
    };
    const r = normalizeDiseaseMappingResponse(alreadyUnboxed);
    expect(r.status).toBe('current');
    expect(r.mondo_id).toBe('MONDO:0032797');
    expect(r.mappings).toEqual({});
  });
});

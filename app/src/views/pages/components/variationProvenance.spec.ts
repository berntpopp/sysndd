// app/src/views/pages/components/variationProvenance.spec.ts
//
// #608 — the two honesty rules of the provenance presentation layer, locked at
// the pure-function level so a component refactor cannot quietly break them:
//   1. absence of provenance means CURATOR-AUTHORED (and must stay silent), and
//   2. an unrecorded strength is "not recorded", never zero stars.
// Plus the plumber wire shape: nested scalars arrive as length-1 arrays.

import { describe, expect, it } from 'vitest';
import {
  clinvarVariationUrl,
  formatImportedDate,
  importedLineParts,
  normalizeEvidenceRecords,
  normalizeEvidenceState,
  normalizeVariationProvenance,
  provenanceStatusText,
  type NormalizedEvidence,
  provenanceTriggerLabel,
  sourceDisplayName,
  sourceTypeText,
  strengthDisplay,
  unwrapScalar,
} from './variationProvenance';

describe('normalizeVariationProvenance', () => {
  it('treats null, undefined, a missing key and {} as curator-authored', () => {
    expect(normalizeVariationProvenance(null)).toBeNull();
    expect(normalizeVariationProvenance(undefined)).toBeNull();
    // `{}` is what jsonlite emits for a NULL list element if the `null="null"`
    // serializer argument is ever lost — degrade to curator-authored, not to a
    // stateless affordance.
    expect(normalizeVariationProvenance({})).toBeNull();
  });

  it('accepts both the plumber length-1-array shape and plain scalars', () => {
    const wire = normalizeVariationProvenance({
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
    });
    expect(wire).toEqual({
      state: 'active_unconfirmed',
      maxStrength: 1,
      sources: [
        {
          sourceType: 'external_database',
          sourceKey: 'clinvar',
          strength: 1,
          summary: '2 ClinVar records, max 1 star',
        },
      ],
    });
    expect(
      normalizeVariationProvenance({ state: 'confirmed', max_strength: 4, sources: [] })
    ).toEqual({ state: 'confirmed', maxStrength: 4, sources: [] });
  });

  it('suppresses states the public read must never carry', () => {
    for (const state of ['suggested', 'rejected', 'nonsense', '']) {
      expect(normalizeVariationProvenance({ state: [state], sources: [] })).toBeNull();
    }
  });

  it('keeps the API source order untouched', () => {
    const prov = normalizeVariationProvenance({
      state: ['active_unconfirmed'],
      max_strength: [3],
      sources: [
        { source_key: ['synopsis'], strength: [3] },
        { source_key: ['clinvar'], strength: [1] },
      ],
    });
    expect(prov?.sources.map((s) => s.sourceKey)).toEqual(['synopsis', 'clinvar']);
  });

  it('reports an unrecorded or nonsensical strength as null rather than clamping it', () => {
    const mk = (strength: unknown) =>
      normalizeVariationProvenance({
        state: ['confirmed'],
        max_strength: strength,
        sources: [{ source_key: ['clinvar'], strength }],
      });
    for (const bad of [null, undefined, 'NA', -1, 5, 1.5, [], {}]) {
      expect(mk(bad)?.maxStrength, `max_strength for ${JSON.stringify(bad)}`).toBeNull();
      expect(mk(bad)?.sources[0].strength).toBeNull();
    }
    expect(mk([0])?.maxStrength).toBe(0);
  });
});

describe('strengthDisplay', () => {
  it('never renders an unrecorded strength as zero stars', () => {
    const d = strengthDisplay(null);
    expect(d.recorded).toBe(false);
    expect(d.text).toBe('Not recorded');
    expect(d.filled).toBe(0);
  });

  it('reports a recorded strength in text as well as a star count', () => {
    expect(strengthDisplay(0)).toMatchObject({ recorded: true, text: '0 of 4', filled: 0 });
    expect(strengthDisplay(1)).toMatchObject({ recorded: true, text: '1 of 4', filled: 1 });
    expect(strengthDisplay(4)).toMatchObject({ recorded: true, text: '4 of 4', filled: 4 });
  });
});

describe('copy helpers', () => {
  it('states provenance in words, without alarm language', () => {
    expect(provenanceStatusText('active_unconfirmed')).toBe('Not yet confirmed by a curator');
    expect(provenanceStatusText('confirmed')).toBe('Confirmed by a curator');
    for (const state of ['active_unconfirmed', 'confirmed'] as const) {
      const text = provenanceStatusText(state).toLowerCase();
      expect(text).not.toContain('error');
      expect(text).not.toContain('invalid');
      expect(text).not.toContain('problem');
    }
  });

  it('puts the state into the trigger accessible name', () => {
    expect(provenanceTriggerLabel('nonsynonymous variation', 'active_unconfirmed')).toContain(
      'machine-derived, not confirmed'
    );
    expect(provenanceTriggerLabel('nonsynonymous variation', 'confirmed')).toContain(
      'machine-derived, confirmed by a curator'
    );
  });

  it('capitalises known source keys and passes unknown ones through verbatim', () => {
    expect(sourceDisplayName('clinvar')).toBe('ClinVar');
    expect(sourceDisplayName('some_new_source')).toBe('some_new_source');
    expect(sourceDisplayName(null)).toBe('Unnamed source');
    expect(sourceTypeText('external_database')).toBe('external database');
    expect(sourceTypeText(null)).toBeNull();
  });
});

describe('normalizeEvidenceRecords', () => {
  it('omits absent fields instead of rendering placeholders', () => {
    const [record] = normalizeEvidenceRecords([
      {
        source_type: ['literature'],
        source_key: ['synopsis'],
        batch_id: ['b-1'],
        source_version: null,
        evidence_summary: ['Explicitly stated'],
        evidence_strength: [3],
        evidence_json: null,
      },
    ]);
    expect(record.sourceVersion).toBeNull();
    expect(record.records).toEqual([]);
    expect(record.matched).toEqual([]);
    expect(record.summary).toBe('Explicitly stated');
  });

  it('extracts supporting records and matched identifiers, and drops empty rows', () => {
    const [record] = normalizeEvidenceRecords([
      {
        source_key: ['clinvar'],
        evidence_json: {
          records: [
            { variation_id: ['VCV1343191'], consequence: ['missense'] },
            { irrelevant_key: ['x'] },
          ],
          matched: ['OMIM:251280', 'OMIM:123456'],
        },
      },
    ]);
    expect(record.records).toHaveLength(1);
    expect(record.records[0]).toMatchObject({
      variationId: 'VCV1343191',
      consequence: 'missense',
      classification: null,
      url: 'https://www.ncbi.nlm.nih.gov/clinvar/variation/1343191/',
    });
    expect(record.matched).toEqual(['OMIM:251280', 'OMIM:123456']);
  });

  it('handles a non-array payload without throwing', () => {
    expect(normalizeEvidenceRecords(null)).toEqual([]);
    expect(normalizeEvidenceRecords({})).toEqual([]);
  });
});

describe('clinvarVariationUrl', () => {
  it('links only a genuine ClinVar accession from the clinvar source', () => {
    expect(clinvarVariationUrl('clinvar', 'VCV1343191')).toBe(
      'https://www.ncbi.nlm.nih.gov/clinvar/variation/1343191/'
    );
    expect(clinvarVariationUrl('clinvar', '1343191')).toBe(
      'https://www.ncbi.nlm.nih.gov/clinvar/variation/1343191/'
    );
    expect(clinvarVariationUrl('clinvar', 'VCV001343191.3')).toBe(
      'https://www.ncbi.nlm.nih.gov/clinvar/variation/1343191/'
    );
    // Not clinvar, not an accession, or absent -> plain text, never a guess.
    expect(clinvarVariationUrl('synopsis', 'VCV1343191')).toBeNull();
    expect(clinvarVariationUrl('clinvar', 'chr1:123A>T')).toBeNull();
    expect(clinvarVariationUrl('clinvar', null)).toBeNull();
  });
});

describe('wire-shape helpers', () => {
  it('unwraps a length-1 array only', () => {
    expect(unwrapScalar(['x'])).toBe('x');
    expect(unwrapScalar('x')).toBe('x');
    expect(unwrapScalar([])).toBeUndefined();
    expect(unwrapScalar(['a', 'b'])).toBeUndefined();
  });

  it('accepts only served states from the evidence route', () => {
    expect(normalizeEvidenceState(['confirmed'])).toBe('confirmed');
    expect(normalizeEvidenceState('active_unconfirmed')).toBe('active_unconfirmed');
    expect(normalizeEvidenceState(['suggested'])).toBeNull();
    expect(normalizeEvidenceState(null)).toBeNull();
  });
});


// #612 — the import date. It completes the "Imported ..." line the design
// specifies, and it is the one field on this surface derived from a raw column
// rather than from stored prose, so its honesty rules are pinned here.
describe('formatImportedDate', () => {
  it('reads the calendar fields literally instead of parsing an instant', () => {
    // The API sends a MySQL DATETIME with NO zone designator. Handing that to
    // `new Date(...)` makes the engine guess a timezone, which can shift the
    // rendered day for a viewer elsewhere; the date shown must be the date
    // stored. Compared against an independently-built local date.
    const expected = new Date(2026, 1, 15).toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
    expect(formatImportedDate('2026-02-15T10:23:00')).toBe(expected);
    expect(formatImportedDate(['2026-02-15T10:23:00'])).toBe(expected);
    // A date-only value is the same date, not a different one.
    expect(formatImportedDate('2026-02-15')).toBe(expected);
  });

  it('returns null for anything it cannot vouch for', () => {
    expect(formatImportedDate(null)).toBeNull();
    expect(formatImportedDate(undefined)).toBeNull();
    expect(formatImportedDate('')).toBeNull();
    expect(formatImportedDate('not a date')).toBeNull();
    expect(formatImportedDate(12345)).toBeNull();
    // A rolled-over date would silently display 3 March; refuse instead.
    expect(formatImportedDate('2026-02-31T00:00:00')).toBeNull();
    expect(formatImportedDate('2026-13-01T00:00:00')).toBeNull();
  });
});

describe('importedLineParts', () => {
  const base: NormalizedEvidence = {
    sourceType: 'external_database',
    sourceKey: 'clinvar',
    batchId: null,
    sourceVersion: null,
    summary: null,
    strength: null,
    importedOn: null,
    records: [],
    matched: [],
  };

  it('orders date, batch, release and omits each part independently', () => {
    expect(
      importedLineParts({
        ...base,
        importedOn: '15 Feb 2026',
        batchId: 'clinvar-2026-02',
        sourceVersion: '2026-02-01',
      })
    ).toEqual(['15 Feb 2026', 'batch clinvar-2026-02', 'release 2026-02-01']);

    expect(importedLineParts({ ...base, batchId: 'b-1' })).toEqual(['batch b-1']);
    expect(importedLineParts({ ...base, importedOn: '15 Feb 2026' })).toEqual(['15 Feb 2026']);
  });

  it('returns nothing when the payload records none of the three', () => {
    // An empty array means the dialog omits the row entirely rather than
    // rendering a bare "Imported" label with no value.
    expect(importedLineParts(base)).toEqual([]);
  });
});

describe('normalizeEvidenceRecords — import date', () => {
  it('carries created_at through as a formatted date, or null when absent', () => {
    const [withDate, withoutDate] = normalizeEvidenceRecords([
      {
        source_key: ['clinvar'],
        batch_id: ['clinvar-2026-02'],
        created_at: ['2026-02-15T10:23:00'],
      },
      { source_key: ['synopsis'], batch_id: ['b-1'], created_at: null },
    ]);

    expect(withDate.importedOn).toBe(
      new Date(2026, 1, 15).toLocaleDateString(undefined, {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      })
    );
    expect(withoutDate.importedOn).toBeNull();
  });
});

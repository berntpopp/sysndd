// app/src/views/pages/components/variationEvidenceRecords.spec.ts
//
// #612: the backfill writes THREE record shapes and the pre-#612 normalizer
// understood one. The extdb2 batch rendered `consequence` alone; the synopsis
// batch rendered nothing at all, because a record carrying none of the probed
// keys is filtered out. That failure is silent BY DESIGN, so the shapes are
// pinned by a fixture shared with the R suite and with the writing repository.
import { describe, it, expect } from 'vitest';

import { evidenceShapes } from '@/test-utils/variationEvidenceShapesFixture';

import {
  EXTERNAL_FIELD_ORDER,
  LITERATURE_RECORD_KEYS,
  CLINVAR_RECORD_KEYS,
  normalizeEvidenceRecordList,
} from './variationEvidenceRecords';

/** The keys each shape's renderer actually reads. Asserted against the fixture. */
const understoodKeys: Record<string, readonly string[]> = {
  clinvar: CLINVAR_RECORD_KEYS,
  extdb2: EXTERNAL_FIELD_ORDER,
  synopsis: LITERATURE_RECORD_KEYS,
};

const shapeNames = Object.keys(evidenceShapes);

describe('record-shape contract', () => {
  it('covers the three batches the backfill actually wrote', () => {
    expect(shapeNames.sort()).toEqual(['clinvar', 'extdb2', 'synopsis']);
  });

  it.each(shapeNames)('understands exactly the keys %s declares, both directions', (name) => {
    const declared = [...evidenceShapes[name].record_keys].sort();
    const understood = [...understoodKeys[name]].sort();
    expect(understood).toEqual(declared);
  });

  it.each(shapeNames)('normalizes every %s sample record to a typed row', (name) => {
    const shape = evidenceShapes[name];
    const rows = normalizeEvidenceRecordList(
      shape.wire_sample,
      shape.source_key,
      shape.source_type
    );
    const sampleCount = (shape.wire_sample.records as unknown[]).length;
    expect(rows).toHaveLength(sampleCount);
    // A known source must never fall through to the pre-#612 generic probe.
    expect(rows.every((row) => row.kind !== 'generic')).toBe(true);
  });
});

describe('clinvar records', () => {
  const shape = evidenceShapes.clinvar;

  it('exposes stars, which the payload has always carried and the dialog never showed', () => {
    const [first] = normalizeEvidenceRecordList(shape.wire_sample, 'clinvar', 'external_database');
    expect(first).toMatchObject({
      kind: 'clinvar',
      variationId: '3382378',
      classification: 'Likely pathogenic',
      stars: 1,
      consequence: 'SO:0001587|nonsense',
    });
  });

  it('keeps the stored deep link', () => {
    const [first] = normalizeEvidenceRecordList(shape.wire_sample, 'clinvar', 'external_database');
    expect(first.kind).toBe('clinvar');
    if (first.kind !== 'clinvar') return;
    expect(first.url).toBe('https://www.ncbi.nlm.nih.gov/clinvar/variation/3382378/');
  });

  it('derives a deep link from a bare id when the payload carries no url', () => {
    const [row] = normalizeEvidenceRecordList(
      { records: [{ id: ['VCV000817069.3'] }] },
      'clinvar',
      'external_database'
    );
    expect(row.kind).toBe('clinvar');
    if (row.kind !== 'clinvar') return;
    expect(row.url).toBe('https://www.ncbi.nlm.nih.gov/clinvar/variation/817069/');
  });

  it('leaves the link null rather than guessing at a non-accession id', () => {
    const [row] = normalizeEvidenceRecordList(
      { records: [{ id: ['not-an-accession'] }] },
      'clinvar',
      'external_database'
    );
    expect(row.kind).toBe('clinvar');
    if (row.kind !== 'clinvar') return;
    expect(row.url).toBeNull();
  });

  it('treats an out-of-range star count as not recorded, never as zero stars', () => {
    const [row] = normalizeEvidenceRecordList(
      { records: [{ id: ['1'], stars: [9] }] },
      'clinvar',
      'external_database'
    );
    expect(row.kind).toBe('clinvar');
    if (row.kind !== 'clinvar') return;
    expect(row.stars).toBeNull();
  });
});

describe('external-database records', () => {
  const shape = evidenceShapes.extdb2;

  it('renders every recorded field in the fixed display order', () => {
    const [row] = normalizeEvidenceRecordList(shape.wire_sample, 'extdb2', 'external_database');
    expect(row.kind).toBe('external');
    if (row.kind !== 'external') return;
    expect(row.fields.map((field) => field.key)).toEqual([
      'confidence',
      'mechanism',
      'categorisation',
      'consequence',
      'allelic_requirement',
      'support',
      'disease',
      'layer',
    ]);
    expect(row.fields.find((field) => field.key === 'mechanism')?.value).toBe('dominant negative');
    expect(row.fields.find((field) => field.key === 'confidence')?.value).toBe('moderate');
  });

  it('omits a key the record does not carry rather than rendering it blank', () => {
    // The writer DROPS an empty field rather than writing null, so a record
    // legitimately carries a subset of its shape's keys.
    const [row] = normalizeEvidenceRecordList(
      { records: [{ mechanism: ['loss of function'] }] },
      'extdb2',
      'external_database'
    );
    expect(row.kind).toBe('external');
    if (row.kind !== 'external') return;
    expect(row.fields).toHaveLength(1);
    expect(row.fields[0]).toMatchObject({ key: 'mechanism', label: 'Mechanism' });
  });

  it('renders an unknown key under its raw name instead of dropping it', () => {
    // Dropping unknown keys is precisely what produced this bug.
    const [row] = normalizeEvidenceRecordList(
      { records: [{ novel_field: ['x'] }] },
      'extdb2',
      'external_database'
    );
    expect(row.kind).toBe('external');
    if (row.kind !== 'external') return;
    expect(row.fields).toEqual([{ key: 'novel_field', label: 'novel_field', value: 'x' }]);
  });
});

describe('literature (synopsis) records', () => {
  const shape = evidenceShapes.synopsis;

  it('preserves the negated flag through the plumber array wrapper', () => {
    // `[false]` is the wire shape. A truthiness test reads it as `true`, and
    // `asText()` renders it as the string "false" — either way a refutation
    // would present as a confirmation.
    const rows = normalizeEvidenceRecordList(shape.wire_sample, 'synopsis', 'literature');
    expect(rows.map((row) => (row.kind === 'literature' ? row.negated : undefined))).toEqual([
      false,
      true,
    ]);
  });

  it('keeps the matched text, its pattern and its sentence context', () => {
    const [first] = normalizeEvidenceRecordList(shape.wire_sample, 'synopsis', 'literature');
    expect(first).toMatchObject({
      kind: 'literature',
      matchedText: 'Haploinsufficiency',
      pattern: '\\bhaploinsufficiency\\b',
      context: 'Haploinsufficiency was posited as pathomechanism.',
    });
  });

  it('reports an unreadable negated flag as not recorded, never as "not negated"', () => {
    const [row] = normalizeEvidenceRecordList(
      { records: [{ matched_text: ['x'], negated: ['maybe'] }] },
      'synopsis',
      'literature'
    );
    expect(row.kind).toBe('literature');
    if (row.kind !== 'literature') return;
    expect(row.negated).toBeNull();
  });

  it('uses the literature renderer for any literature source, not only `synopsis`', () => {
    const [row] = normalizeEvidenceRecordList(
      { records: [{ matched_text: ['x'], negated: [false] }] },
      'some_future_corpus',
      'literature'
    );
    expect(row.kind).toBe('literature');
  });
});

describe('unknown sources and empty rows', () => {
  it('falls back to the pre-#612 generic probe rather than rendering nothing', () => {
    const [row] = normalizeEvidenceRecordList(
      { records: [{ accession: ['ACC1'], molecular_consequence: ['missense'] }] },
      'future_source',
      'external_database'
    );
    expect(row).toMatchObject({ kind: 'generic', variationId: 'ACC1', consequence: 'missense' });
  });

  it('drops a record with no renderable field rather than showing an empty bullet', () => {
    expect(normalizeEvidenceRecordList({ records: [{}] }, 'future', 'literature')).toEqual([]);
    expect(normalizeEvidenceRecordList({ records: [{}] }, 'clinvar', 'external_database')).toEqual(
      []
    );
    expect(normalizeEvidenceRecordList({ records: [{}] }, 'extdb2', 'external_database')).toEqual(
      []
    );
  });

  it('returns an empty list for a payload that is not a record container', () => {
    expect(normalizeEvidenceRecordList(null, 'clinvar', 'external_database')).toEqual([]);
    expect(normalizeEvidenceRecordList({ matched: [['OMIM:1']] }, 'clinvar', 'x')).toEqual([]);
  });

  it('still honours the legacy container aliases', () => {
    const rows = normalizeEvidenceRecordList(
      { variants: [{ accession: ['ACC1'] }] },
      'future_source',
      'external_database'
    );
    expect(rows).toHaveLength(1);
  });
});

describe('external links are never trusted from the payload', () => {
  it('derives the ClinVar link and ignores a stored one', () => {
    // `evidence_json` is written by an importer in another repository and stored
    // verbatim, so a `url` inside it is DATA. The importer builds this URL from
    // the very id beside it, so deriving loses nothing.
    const [row] = normalizeEvidenceRecordList(
      { records: [{ id: ['817069'], url: ['javascript:alert(1)'] }] },
      'clinvar',
      'external_database'
    );
    expect(row.kind).toBe('clinvar');
    if (row.kind !== 'clinvar') return;
    expect(row.url).toBe('https://www.ncbi.nlm.nih.gov/clinvar/variation/817069/');
  });

  it('drops a non-http(s) URL on an unknown source rather than rendering it clickable', () => {
    for (const hostile of ['javascript:alert(1)', 'data:text/html,<script>', 'vbscript:x']) {
      const [row] = normalizeEvidenceRecordList(
        { records: [{ accession: ['ACC1'], url: [hostile] }] },
        'future_source',
        'external_database'
      );
      expect(row.kind).toBe('generic');
      if (row.kind !== 'generic') return;
      expect(row.url).toBeNull();
    }
  });

  it('keeps a genuine https target on an unknown source', () => {
    const [row] = normalizeEvidenceRecordList(
      { records: [{ accession: ['ACC1'], url: ['https://example.org/x'] }] },
      'future_source',
      'external_database'
    );
    expect(row.kind).toBe('generic');
    if (row.kind !== 'generic') return;
    expect(row.url).toBe('https://example.org/x');
  });
});

describe('pre-#612 ClinVar aliases still render', () => {
  it('falls back to the legacy classification and consequence keys', () => {
    // Dropping a key that used to render is the regression this change fixes.
    const [row] = normalizeEvidenceRecordList(
      {
        records: [
          {
            variation_id: ['VCV1343191'],
            clinical_significance: ['Pathogenic'],
            molecular_consequence: ['missense'],
          },
        ],
      },
      'clinvar',
      'external_database'
    );
    expect(row).toMatchObject({
      kind: 'clinvar',
      variationId: 'VCV1343191',
      classification: 'Pathogenic',
      consequence: 'missense',
    });
  });
});

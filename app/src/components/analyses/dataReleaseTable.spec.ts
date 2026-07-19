import { describe, it, expect } from 'vitest';
import {
  formatReleaseBytes,
  normalizeReleaseRows,
  RELEASE_TABLE_FIELDS,
  DOI_UNASSIGNED,
} from './dataReleaseTable';
import type { ReleaseHead } from '@/api/analysis_releases';

function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
  return {
    release_id: 'asr_0123456789abcdef',
    release_version: 1,
    title: 'SysNDD analysis-snapshot release',
    status: 'published',
    content_digest: 'a'.repeat(64),
    created_at: '2026-07-01T00:00:00Z',
    published_at: '2026-07-01T00:05:00Z',
    source_data_version: '2026-07-01',
    db_release_version: '11.4.0',
    db_release_commit: 'deadbeef',
    manifest_sha256: 'b'.repeat(64),
    bundle_sha256: 'c'.repeat(64),
    license: 'CC-BY-4.0',
    file_count: 10,
    total_bytes: 1258291,
    zenodo: { record_url: null, version_doi: null, concept_doi: null },
    ...overrides,
  };
}

describe('formatReleaseBytes', () => {
  it('formats a sub-KB byte count without a decimal', () => {
    expect(formatReleaseBytes(500)).toBe('500 B');
  });

  it('formats a KB boundary', () => {
    expect(formatReleaseBytes(1536)).toBe('1.5 KB');
  });

  it('formats an MB value', () => {
    expect(formatReleaseBytes(1258291)).toBe('1.2 MB');
  });

  it('guards the zero boundary', () => {
    expect(formatReleaseBytes(0)).toBe('0 B');
  });

  it('guards negative input', () => {
    expect(formatReleaseBytes(-5)).toBe('0 B');
  });

  it('guards non-finite input (NaN, Infinity)', () => {
    expect(formatReleaseBytes(NaN)).toBe('0 B');
    expect(formatReleaseBytes(Infinity)).toBe('0 B');
    expect(formatReleaseBytes(-Infinity)).toBe('0 B');
  });
});

describe('RELEASE_TABLE_FIELDS', () => {
  it('uses only flat keys (no dots — the BVN BTable trap)', () => {
    for (const field of RELEASE_TABLE_FIELDS) {
      expect(field.key).not.toContain('.');
    }
  });

  it('surfaces the documented release columns', () => {
    const keys = RELEASE_TABLE_FIELDS.map((f) => f.key);
    expect(keys).toEqual([
      'release_id',
      'release_version',
      'published_at',
      'source_data_version',
      'file_count',
      'total_bytes_display',
      'license',
      'zenodo_version_doi',
      'actions',
    ]);
  });
});

describe('normalizeReleaseRows', () => {
  it('flattens zenodo.* into flat zenodo_* keys with no dotted keys', () => {
    const rows = normalizeReleaseRows([
      makeReleaseHead({
        zenodo: {
          record_url: 'https://zenodo.org/records/1234',
          version_doi: '10.5281/zenodo.1234',
          concept_doi: '10.5281/zenodo.1233',
        },
      }),
    ]);
    expect(rows).toHaveLength(1);
    const row = rows[0] as unknown as Record<string, unknown>;
    expect(row.zenodo_version_doi).toBe('10.5281/zenodo.1234');
    expect(row.zenodo_concept_doi).toBe('10.5281/zenodo.1233');
    expect(row.zenodo_record_url).toBe('https://zenodo.org/records/1234');
    expect(Object.keys(row).some((key) => key.includes('.'))).toBe(false);
  });

  it('formats total_bytes_display via formatReleaseBytes', () => {
    const rows = normalizeReleaseRows([makeReleaseHead({ total_bytes: 1258291 })]);
    expect(rows[0].total_bytes_display).toBe('1.2 MB');
    expect(rows[0].total_bytes).toBe(1258291);
  });

  it('maps a null zenodo.version_doi to the DOI_UNASSIGNED sentinel', () => {
    const rows = normalizeReleaseRows([
      makeReleaseHead({ zenodo: { record_url: null, version_doi: null, concept_doi: null } }),
    ]);
    expect(rows[0].zenodo_version_doi).toBe(DOI_UNASSIGNED);
    expect(rows[0].zenodo_concept_doi).toBe(DOI_UNASSIGNED);
    expect(rows[0].zenodo_record_url).toBe(DOI_UNASSIGNED);
  });

  it('falls back to created_at when published_at is null', () => {
    const rows = normalizeReleaseRows([
      makeReleaseHead({ published_at: null, created_at: '2026-06-15T00:00:00Z' }),
    ]);
    expect(rows[0].published_at).toBe('2026-06-15T00:00:00Z');
  });

  it('carries release_id, release_version, title, status, license, file_count through unchanged', () => {
    const rows = normalizeReleaseRows([
      makeReleaseHead({ release_id: 'asr_abc123', release_version: 3, file_count: 42 }),
    ]);
    expect(rows[0].release_id).toBe('asr_abc123');
    expect(rows[0].release_version).toBe(3);
    expect(rows[0].title).toBe('SysNDD analysis-snapshot release');
    expect(rows[0].status).toBe('published');
    expect(rows[0].license).toBe('CC-BY-4.0');
    expect(rows[0].file_count).toBe(42);
  });

  it('does not mutate the input and tolerates null/undefined', () => {
    const input = [makeReleaseHead()];
    const rows = normalizeReleaseRows(input);
    expect(rows).not.toBe(input);
    expect(normalizeReleaseRows(null)).toEqual([]);
    expect(normalizeReleaseRows(undefined)).toEqual([]);
  });
});

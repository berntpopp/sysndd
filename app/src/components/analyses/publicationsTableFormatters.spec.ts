import { describe, it, expect } from 'vitest';
import {
  getPubMedUrl,
  formatDate,
  formatAuthors,
  parseKeywords,
  mergePublicationFields,
  type PublicationTableField,
} from './publicationsTableFormatters';

describe('getPubMedUrl', () => {
  it('strips a PMID: prefix (case-insensitive)', () => {
    expect(getPubMedUrl('PMID:12345678')).toBe('https://pubmed.ncbi.nlm.nih.gov/12345678');
    expect(getPubMedUrl('pmid:999')).toBe('https://pubmed.ncbi.nlm.nih.gov/999');
  });

  it('accepts a bare numeric id', () => {
    expect(getPubMedUrl('12345678')).toBe('https://pubmed.ncbi.nlm.nih.gov/12345678');
  });
});

describe('formatDate', () => {
  it('returns empty string for falsy input', () => {
    expect(formatDate('')).toBe('');
    expect(formatDate(null)).toBe('');
    expect(formatDate(undefined)).toBe('');
  });

  it('formats a parseable ISO date as "Mon D, YYYY"', () => {
    expect(formatDate('2024-01-15')).toBe('Jan 15, 2024');
  });
});

describe('formatAuthors', () => {
  it('returns empty string when there are no last names', () => {
    expect(formatAuthors('', 'Jane')).toBe('');
    expect(formatAuthors(null, null)).toBe('');
  });

  it('pairs last names with first names by index', () => {
    expect(formatAuthors('Doe;Smith', 'Jane;John')).toBe('Doe Jane, Smith John');
  });

  it('falls back to last name when a first name is missing', () => {
    expect(formatAuthors('Doe;Smith', 'Jane')).toBe('Doe Jane, Smith');
  });
});

describe('parseKeywords', () => {
  it('returns empty array for falsy input', () => {
    expect(parseKeywords('')).toEqual([]);
    expect(parseKeywords(null)).toEqual([]);
  });

  it('splits, trims, and drops empty tokens', () => {
    expect(parseKeywords('epilepsy; ; autism ;')).toEqual(['epilepsy', 'autism']);
  });
});

describe('mergePublicationFields', () => {
  const inbound: PublicationTableField[] = [
    { key: 'publication_id', label: 'Publication ID', sortable: true },
    { key: 'Title', label: 'Title', sortable: true },
    { key: 'Publication_date', label: 'Publication date', sortable: true },
    { key: 'Journal', label: 'Journal', sortable: true },
    { key: 'Abstract', label: 'Abstract' },
  ];

  it('keeps only visible columns in the fixed order and appends details', () => {
    const merged = mergePublicationFields(inbound);
    expect(merged.map((f) => f.key)).toEqual([
      'publication_id',
      'Title',
      'Publication_date',
      'Journal',
      'details',
    ]);
  });

  it('applies short labels and text-start class to visible columns', () => {
    const merged = mergePublicationFields(inbound);
    const byKey = Object.fromEntries(merged.map((f) => [f.key, f]));
    expect(byKey.publication_id.label).toBe('PMID');
    expect(byKey.Publication_date.label).toBe('Date');
    expect(byKey.Title.label).toBe('Title');
    expect(byKey.Journal.class).toBe('text-start');
  });

  it('marks the appended details column non-sortable and centered', () => {
    const details = mergePublicationFields(inbound).find((f) => f.key === 'details');
    expect(details).toMatchObject({ key: 'details', class: 'text-center', sortable: false });
  });

  it('skips visible keys missing from the inbound fspec', () => {
    const merged = mergePublicationFields([{ key: 'Title', label: 'Title' }]);
    expect(merged.map((f) => f.key)).toEqual(['Title', 'details']);
  });
});

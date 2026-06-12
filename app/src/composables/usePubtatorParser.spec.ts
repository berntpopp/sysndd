import { describe, it, expect } from 'vitest';
import type { ParsedSegment } from './usePubtatorParser';
import {
  getEntityClass,
  getSegmentClass,
  getSegmentTooltip,
  usePubtatorParser,
} from './usePubtatorParser';

const seg = (overrides: Partial<ParsedSegment>): ParsedSegment =>
  ({ type: 'plain', text: '', ...overrides }) as ParsedSegment;

describe('getSegmentClass', () => {
  it('maps each entity type to its PubTator CSS class (matching getEntityClass)', () => {
    const types: ParsedSegment['type'][] = [
      'gene',
      'disease',
      'variant',
      'species',
      'chemical',
      'match',
    ];
    types.forEach((type) => {
      expect(getSegmentClass(seg({ type }))).toBe(getEntityClass(type));
    });
  });

  it('returns the expected class strings for known entity types', () => {
    expect(getSegmentClass(seg({ type: 'gene' }))).toBe('pubtator-gene');
    expect(getSegmentClass(seg({ type: 'disease' }))).toBe('pubtator-disease');
    expect(getSegmentClass(seg({ type: 'variant' }))).toBe('pubtator-variant');
    expect(getSegmentClass(seg({ type: 'species' }))).toBe('pubtator-species');
    expect(getSegmentClass(seg({ type: 'chemical' }))).toBe('pubtator-chemical');
    expect(getSegmentClass(seg({ type: 'match' }))).toBe('pubtator-match');
  });

  it('returns an empty class for plain segments', () => {
    expect(getSegmentClass(seg({ type: 'plain' }))).toBe('');
  });
});

describe('getSegmentTooltip', () => {
  it('returns an empty tooltip for plain and match segments', () => {
    expect(getSegmentTooltip(seg({ type: 'plain', text: 'foo' }))).toBe('');
    expect(getSegmentTooltip(seg({ type: 'match', text: 'foo' }))).toBe('');
  });

  it('capitalizes the type label and includes the matched text', () => {
    expect(getSegmentTooltip(seg({ type: 'gene', text: 'GRIN2B' }))).toBe('Gene: GRIN2B');
    expect(getSegmentTooltip(seg({ type: 'disease', text: 'epilepsy' }))).toBe('Disease: epilepsy');
  });

  it('appends the entity id when present', () => {
    expect(getSegmentTooltip(seg({ type: 'gene', text: 'GRIN2B', entityId: '2904' }))).toBe(
      'Gene: GRIN2B (ID: 2904)'
    );
  });
});

describe('usePubtatorParser', () => {
  it('exposes the segment display helpers', () => {
    const parser = usePubtatorParser();
    expect(parser.getSegmentClass).toBe(getSegmentClass);
    expect(parser.getSegmentTooltip).toBe(getSegmentTooltip);
    expect(parser.getEntityClass).toBe(getEntityClass);
  });
});

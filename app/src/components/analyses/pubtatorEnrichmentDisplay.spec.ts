import { describe, it, expect } from 'vitest';
import {
  formatCount,
  formatEnrichment,
  enrichmentVariant,
  enrichmentTooltip,
  fdrStars,
  fdrClass,
  fdrTooltip,
  createPubtatorGeneFields,
} from './pubtatorEnrichmentDisplay';

describe('pubtatorEnrichmentDisplay', () => {
  it('compacts large counts and dashes nulls', () => {
    expect(formatCount(282103)).toBe('282.1k');
    expect(formatCount(13459)).toBe('13.5k');
    expect(formatCount(86)).toBe('86');
    expect(formatCount(null)).toBe('—');
  });

  it('rounds enrichment ratios coarser as magnitude grows', () => {
    expect(formatEnrichment(150)).toBe('150');
    expect(formatEnrichment(17.6)).toBe('18');
    expect(formatEnrichment(2.34)).toBe('2.3');
    expect(formatEnrichment(null)).toBe('—');
  });

  it('bands the enrichment variant by strength', () => {
    expect(enrichmentVariant(10)).toBe('success');
    expect(enrichmentVariant(2)).toBe('warning');
    expect(enrichmentVariant(0.1)).toBe('secondary');
    expect(enrichmentVariant(null)).toBe('secondary');
  });

  it('assigns FDR stars by Benjamini-Hochberg thresholds', () => {
    expect(fdrStars(1e-5)).toBe('***');
    expect(fdrStars(0.005)).toBe('**');
    expect(fdrStars(0.03)).toBe('*');
    expect(fdrStars(0.2)).toBe('');
    expect(fdrStars(null)).toBe('');
  });

  it('pairs FDR class color with weight (not color alone)', () => {
    expect(fdrClass(0.01)).toContain('text-success');
    expect(fdrClass(0.5)).toBe('text-muted');
  });

  it('builds informative tooltips', () => {
    const tip = enrichmentTooltip({
      enrichment_ratio: 17.6,
      npmi: 0.32,
      observed: 86,
      background_count: 13459,
    });
    expect(tip).toContain('17.60×');
    expect(tip).toContain('NPMI: 0.320');
    expect(tip).toContain('86 of 13459');
    expect(fdrTooltip(0.001)).toContain('significant');
    expect(fdrTooltip(0.5)).toContain('not significant');
    expect(fdrTooltip(null)).toContain('No FDR');
  });

  it('exposes the enrichment columns in the gene field set', () => {
    const keys = createPubtatorGeneFields().map((f) => f.key);
    expect(keys).toContain('background_count');
    expect(keys).toContain('enrichment_ratio');
    expect(keys).toContain('fdr_bh');
    // raw count column remains for fallback sorting
    expect(keys).toContain('publication_count');
  });
});

import { describe, expect, it } from 'vitest';
import {
  displayValue,
  numericValue,
  formatDecimal,
  formatPercentile,
  riskVariant,
  confidenceVariant,
  isKnownGene,
  parseHpoPredictions,
  topHpoLabel,
  topHpoTooltip,
} from './nddScoreGeneTableFormatters';

describe('nddScoreGeneTableFormatters', () => {
  it('renders NA for empty display values', () => {
    expect(displayValue(null)).toBe('NA');
    expect(displayValue('')).toBe('NA');
    expect(displayValue('KMT2A')).toBe('KMT2A');
    expect(displayValue(0)).toBe('0');
  });

  it('parses numeric values, returning null for non-finite', () => {
    expect(numericValue('0.5')).toBe(0.5);
    expect(numericValue(42)).toBe(42);
    expect(numericValue('not-a-number')).toBeNull();
    // undefined coerces to NaN (null), but null coerces to 0 (finite).
    expect(numericValue(undefined)).toBeNull();
    expect(numericValue(null)).toBe(0);
  });

  it('formats decimals and percentiles', () => {
    expect(formatDecimal(0.98213, 3)).toBe('0.982');
    expect(formatDecimal(undefined, 3)).toBe('NA');
    expect(formatPercentile(99.5)).toBe('99.5%');
    expect(formatPercentile(undefined)).toBe('NA');
  });

  it('maps risk and confidence tiers to badge variants', () => {
    expect(riskVariant('Very High')).toBe('danger');
    expect(riskVariant('High')).toBe('warning');
    expect(riskVariant('Moderate')).toBe('info');
    expect(riskVariant('Low')).toBe('light');
    expect(confidenceVariant('High')).toBe('success');
    // GeneTable treats medium and moderate identically.
    expect(confidenceVariant('Medium')).toBe('info');
    expect(confidenceVariant('moderate')).toBe('info');
    expect(confidenceVariant('Low')).toBe('light');
  });

  it('detects known SysNDD genes from loose truthy encodings', () => {
    expect(isKnownGene(true)).toBe(true);
    expect(isKnownGene(1)).toBe(true);
    expect(isKnownGene('1')).toBe(true);
    expect(isKnownGene('true')).toBe(true);
    expect(isKnownGene(0)).toBe(false);
    expect(isKnownGene(null)).toBe(false);
  });

  it('parses HPO predictions from arrays and JSON strings', () => {
    const arr = [{ phenotype_id: 'HP:0001249' }];
    expect(parseHpoPredictions(arr)).toEqual(arr);
    expect(parseHpoPredictions(JSON.stringify(arr))).toEqual(arr);
    expect(parseHpoPredictions('not json')).toEqual([]);
    expect(parseHpoPredictions('')).toEqual([]);
  });

  it('builds the top HPO label and tooltip', () => {
    const predictions = JSON.stringify([
      { phenotype_name: 'Intellectual disability', probability: 0.91 },
      { phenotype_name: 'Seizure', probability: 0.42 },
    ]);
    expect(topHpoLabel(predictions, 2)).toBe('Intellectual disability +1');
    expect(topHpoTooltip(predictions)).toBe(
      'Intellectual disability (0.910); Seizure (0.420)'
    );
    expect(topHpoTooltip('[]')).toBe('No predicted HPO terms available.');
  });
});

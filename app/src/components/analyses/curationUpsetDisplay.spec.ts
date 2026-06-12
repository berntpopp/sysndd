import { describe, it, expect } from 'vitest';
import {
  SOURCE_COLORS,
  DEFAULT_SELECTED_SOURCES,
  computeUpsetPlotDimensions,
  normalizeUpsetSelectOptions,
  formatSourceName,
  getSourceVariant,
} from './curationUpsetDisplay';

describe('computeUpsetPlotDimensions', () => {
  it('uses the container width when present', () => {
    expect(computeUpsetPlotDimensions(760, 300)).toEqual({ width: 760, height: 500 });
  });

  it('falls back to the viewport width when no container width', () => {
    expect(computeUpsetPlotDimensions(undefined, 1000)).toEqual({ width: 1000, height: 560 });
  });

  it('clamps width to [300, 1320]', () => {
    expect(computeUpsetPlotDimensions(50, 50).width).toBe(300);
    expect(computeUpsetPlotDimensions(5000, 5000).width).toBe(1320);
  });

  it('steps height with width breakpoints', () => {
    expect(computeUpsetPlotDimensions(400, 400).height).toBe(430);
    expect(computeUpsetPlotDimensions(700, 700).height).toBe(500);
    expect(computeUpsetPlotDimensions(1000, 1000).height).toBe(560);
  });
});

describe('normalizeUpsetSelectOptions', () => {
  it('returns [] for non-arrays', () => {
    expect(normalizeUpsetSelectOptions(null)).toEqual([]);
    expect(normalizeUpsetSelectOptions(undefined)).toEqual([]);
  });

  it('prefers the list property used by the comparisons options endpoint', () => {
    expect(normalizeUpsetSelectOptions([{ list: 'SysNDD' }])).toEqual([
      { value: 'SysNDD', text: 'SysNDD' },
    ]);
  });

  it('passes primitives through', () => {
    expect(normalizeUpsetSelectOptions(['panelapp'])).toEqual([
      { value: 'panelapp', text: 'panelapp' },
    ]);
  });
});

describe('formatSourceName', () => {
  it('maps known sources to display labels', () => {
    expect(formatSourceName('panelapp')).toBe('PanelApp');
    expect(formatSourceName('gene2phenotype')).toBe('Gene2Phenotype');
  });

  it('strips underscores for unknown sources', () => {
    expect(formatSourceName('some_new_source')).toBe('some new source');
  });

  it('returns empty string for falsy input', () => {
    expect(formatSourceName('')).toBe('');
    expect(formatSourceName(null)).toBe('');
  });
});

describe('getSourceVariant', () => {
  it('maps known sources to Bootstrap variants', () => {
    expect(getSourceVariant('SysNDD')).toBe('primary');
    expect(getSourceVariant('sfari')).toBe('danger');
  });

  it('defaults unknown sources to secondary', () => {
    expect(getSourceVariant('mystery')).toBe('secondary');
  });
});

describe('palette + defaults', () => {
  it('uses Okabe-Ito blue for SysNDD', () => {
    expect(SOURCE_COLORS.SysNDD).toBe('#0072B2');
  });

  it('defaults to the three primary sources', () => {
    expect(DEFAULT_SELECTED_SOURCES).toEqual(['SysNDD', 'panelapp', 'gene2phenotype']);
  });
});

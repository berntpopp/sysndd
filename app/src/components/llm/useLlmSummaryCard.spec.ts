import { describe, expect, it } from 'vitest';
import { parseCleanString, useLlmSummaryCard } from './useLlmSummaryCard';

describe('parseCleanString', () => {
  it('returns undefined for undefined and null', () => {
    expect(parseCleanString(undefined)).toBeUndefined();
    expect(parseCleanString(null)).toBeUndefined();
  });

  it('handles standard string inputs', () => {
    expect(parseCleanString('progressive metabolic/degenerative')).toBe('progressive metabolic/degenerative');
    expect(parseCleanString('  clean text  ')).toBe('clean text');
  });

  it('unwraps array inputs from R Plumber character vectors', () => {
    expect(parseCleanString(['progressive metabolic/degenerative'])).toBe('progressive metabolic/degenerative');
    expect(parseCleanString(['term1', 'term2'])).toBe('term1, term2');
    expect(parseCleanString([])).toBeUndefined();
  });

  it('parses JSON stringified arrays with brackets and quotes', () => {
    expect(parseCleanString('[\n  "progressive metabolic/degenerative"\n]')).toBe('progressive metabolic/degenerative');
    expect(parseCleanString('[ "progressive metabolic/degenerative" ]')).toBe('progressive metabolic/degenerative');
    expect(parseCleanString('["syndromic", "metabolic"]')).toBe('syndromic, metabolic');
  });

  it('strips surrounding single or double quotes', () => {
    expect(parseCleanString('"quoted value"')).toBe('quoted value');
    expect(parseCleanString("'single quoted'")).toBe('single quoted');
    expect(parseCleanString('"""nested quotes"""')).toBe('nested quotes');
  });

  it('handles malformed brackets gracefully', () => {
    expect(parseCleanString('[malformed, brackets]')).toBe('malformed, brackets');
  });
});

describe('useLlmSummaryCard', () => {
  it('normalizes clinical_pattern properly when given an array or bracketed string', () => {
    const composableWithArray = useLlmSummaryCard({
      summary: {
        summary: 'Test summary',
        clinical_pattern: ['progressive metabolic/degenerative'],
      },
      createdAt: '2026-01-01',
    });

    expect(composableWithArray.normalizedSummary.value?.clinical_pattern).toBe(
      'progressive metabolic/degenerative'
    );

    const composableWithStringArray = useLlmSummaryCard({
      summary: {
        summary: 'Test summary',
        clinical_pattern: '[ "progressive metabolic/degenerative" ]',
      },
      createdAt: '2026-01-01',
    });

    expect(composableWithStringArray.normalizedSummary.value?.clinical_pattern).toBe(
      'progressive metabolic/degenerative'
    );
  });

  it('normalizes summary and clinical_relevance strings', () => {
    const composable = useLlmSummaryCard({
      summary: {
        summary: '  "Quoted summary text"  ',
        clinical_relevance: '["High relevance"]',
      },
      createdAt: '2026-01-01',
    });

    expect(composable.normalizedSummary.value?.summary).toBe('Quoted summary text');
    expect(composable.normalizedSummary.value?.clinical_relevance).toBe('High relevance');
  });

  it('marks judge verdict as AI evaluated with calm secondary variant and explicit automated disclosure', () => {
    const composable = useLlmSummaryCard({
      summary: {
        summary: 'Test summary',
        llm_judge_verdict: 'accept',
        llm_judge_reasoning: 'Grounded in enrichment data',
      },
      createdAt: '2026-01-01',
    });

    expect(composable.judgeVerdictLabel.value).toBe('AI evaluated');
    expect(composable.judgeVerdictVariant.value).toBe('secondary');
    expect(composable.validatedTooltip.value).toContain('Consistency verified by automated AI evaluation');
    expect(composable.validatedTooltip.value).toContain('not manual clinical curation');
    expect(composable.validatedTooltip.value).toContain('Grounded in enrichment data');
  });

  it('marks accept_with_corrections as AI evaluated (corrected)', () => {
    const composable = useLlmSummaryCard({
      summary: {
        summary: 'Test summary',
        llm_judge_verdict: 'accept_with_corrections',
      },
      createdAt: '2026-01-01',
    });

    expect(composable.judgeVerdictLabel.value).toBe('AI evaluated (corrected)');
    expect(composable.judgeVerdictVariant.value).toBe('secondary');
  });
});

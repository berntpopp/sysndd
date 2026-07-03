import { describe, it, expect } from 'vitest';
import { extractJudgeVerdict, verdictVariant } from './llm-verdict';

describe('extractJudgeVerdict', () => {
  it('reads top-level accepted shape (array-wrapped, Plumber style)', () => {
    const r = extractJudgeVerdict({
      llm_judge_verdict: ['accept_with_corrections'],
      llm_judge_reasoning: ['Removed hearing impairment; otherwise grounded.'],
      corrections_made: ['Removed "hearing impairment"'],
    });
    expect(r.verdict).toBe('accept_with_corrections');
    expect(r.reasoning).toContain('hearing');
    expect(r.correctionsMade).toEqual(['Removed "hearing impairment"']);
  });

  it('reads top-level scalar shape', () => {
    const r = extractJudgeVerdict({
      llm_judge_verdict: 'accept',
      llm_judge_reasoning: 'Fully grounded.',
    });
    expect(r.verdict).toBe('accept');
    expect(r.reasoning).toBe('Fully grounded.');
    expect(r.correctionsMade).toEqual([]);
  });

  it('reads nested rejected shape (#445)', () => {
    const r = extractJudgeVerdict({
      validation: { verdict: 'reject', reasoning: 'Molecular hallucination in summary.' },
    });
    expect(r.verdict).toBe('reject');
    expect(r.reasoning).toContain('Molecular');
  });

  it('prefers the top-level shape when both are present', () => {
    const r = extractJudgeVerdict({
      llm_judge_verdict: ['accept'],
      validation: { verdict: 'reject' },
    });
    expect(r.verdict).toBe('accept');
  });

  it('reads the unified on-demand rejected write (#490): flat + nested agree', () => {
    // llm-service.R now writes the SAME flat keys the batch path uses AND keeps
    // the nested block; the flat keys win and both carry the reject reason.
    const r = extractJudgeVerdict({
      llm_judge_verdict: 'reject',
      llm_judge_reasoning: 'over-broad, low specificity',
      validation: { verdict: 'reject', reasoning: 'over-broad, low specificity' },
    });
    expect(r.verdict).toBe('reject');
    expect(r.reasoning).toBe('over-broad, low specificity');
  });

  it('returns nulls / empty when absent', () => {
    const r = extractJudgeVerdict({ summary: 'x' });
    expect(r.verdict).toBeNull();
    expect(r.reasoning).toBeNull();
    expect(r.correctionsMade).toEqual([]);
  });

  it('is null-safe for undefined / null input', () => {
    expect(extractJudgeVerdict(undefined).verdict).toBeNull();
    expect(extractJudgeVerdict(null).reasoning).toBeNull();
  });

  it('treats blank strings as absent', () => {
    const r = extractJudgeVerdict({ llm_judge_verdict: ['  '], llm_judge_reasoning: [''] });
    expect(r.verdict).toBeNull();
    expect(r.reasoning).toBeNull();
  });
});

describe('verdictVariant', () => {
  it('maps verdicts to bootstrap variants', () => {
    expect(verdictVariant('accept')).toBe('success');
    expect(verdictVariant('accept_with_corrections')).toBe('info');
    expect(verdictVariant('low_confidence')).toBe('warning');
    expect(verdictVariant('reject')).toBe('danger');
    expect(verdictVariant(null)).toBe('secondary');
    expect(verdictVariant('unknown')).toBe('secondary');
  });
});

// utils/llm-verdict.ts
//
// Pure helpers to read the LLM-as-judge verdict + reasoning out of a cached
// summary's `summary_json`, for the admin LLM cache view (#448).
//
// The judge output is persisted in two shapes:
//   - accepted / accept_with_corrections rows: top-level
//     `summary_json.llm_judge_verdict` + `summary_json.llm_judge_reasoning`
//     (+ `corrections_made`).
//   - rejected rows (#445): nested `summary_json.validation.{verdict,reasoning}`.
// Plumber wraps JSON scalars in single-element arrays, so values may arrive as
// `["accept"]` rather than `"accept"`; `unwrap()` normalizes both.

type SummaryJson = Record<string, unknown> | null | undefined;

function unwrap(value: unknown): string | null {
  if (value == null) return null;
  if (Array.isArray(value)) return value.length ? unwrap(value[0]) : null;
  const s = String(value).trim();
  return s.length ? s : null;
}

export interface JudgeVerdict {
  verdict: string | null;
  reasoning: string | null;
  correctionsMade: string[];
}

/**
 * Extract the judge verdict, reasoning, and applied corrections from a cached
 * summary's `summary_json`, handling both the top-level (accepted) and nested
 * `validation` (rejected) shapes. Returns nulls / empty array when absent.
 */
export function extractJudgeVerdict(summaryJson: SummaryJson): JudgeVerdict {
  const j = (summaryJson ?? {}) as Record<string, unknown>;
  const nested = (j.validation ?? {}) as Record<string, unknown>;

  const verdict = unwrap(j.llm_judge_verdict) ?? unwrap(nested.verdict);
  const reasoning = unwrap(j.llm_judge_reasoning) ?? unwrap(nested.reasoning);

  const rawCorrections = j.corrections_made;
  const correctionsMade = Array.isArray(rawCorrections)
    ? rawCorrections.map((x) => String(x)).filter((s) => s.trim().length > 0)
    : [];

  return { verdict, reasoning, correctionsMade };
}

/**
 * Bootstrap variant for a judge verdict badge/alert. The return type is left to
 * inference (a literal union) so it satisfies bootstrap-vue-next's `variant`
 * prop type (`keyof BaseColorVariant`), matching the component's local helpers.
 */
export function verdictVariant(verdict: string | null) {
  switch (verdict) {
    case 'accept':
      return 'success';
    case 'accept_with_corrections':
      return 'info';
    case 'low_confidence':
      return 'warning';
    case 'reject':
      return 'danger';
    default:
      return 'secondary';
  }
}

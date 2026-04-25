// scripts/__tests__/audit-csp-violations.spec.ts
//
// Regression tests for the eval-detection regex used by the CSP audit
// script (`app/scripts/audit-csp-violations.mjs`). A Copilot review on
// PR #306 (v11.1 finish-hardening) flagged that the previous form
// `\b(?:eval|new\s+Function|Function\s*\()\s*\(` consumed a literal `(`
// inside the `Function\s*\(` alternative and then required another
// `\s*\(` immediately, so plain `Function('...')` constructor calls
// slipped past the audit. The fix folds the `(` into a single trailing
// quantifier shared by every alternative.

import { describe, it, expect, beforeEach } from 'vitest';
import { evalishRe } from '../../../scripts/audit-csp-violations.mjs';

function matches(re: RegExp, s: string): boolean {
  // The exported regex is a global flag regex; reset lastIndex per call so
  // each test exercises the regex independently.
  re.lastIndex = 0;
  return re.test(s);
}

describe('audit-csp-violations evalishRe', () => {
  beforeEach(() => {
    evalishRe.lastIndex = 0;
  });

  it('matches eval(', () => {
    expect(matches(evalishRe, "eval('alert(1)')")).toBe(true);
  });

  it('matches new Function(', () => {
    expect(matches(evalishRe, "new Function('return 1')()")).toBe(true);
  });

  it('matches plain Function( constructor calls', () => {
    // This is the case the broken regex missed.
    expect(matches(evalishRe, "Function('return 1')()")).toBe(true);
  });

  it('does not match the word Function in a comment without (', () => {
    expect(matches(evalishRe, '// Function call here')).toBe(false);
  });

  it('does not match unrelated text', () => {
    expect(matches(evalishRe, 'const x = something();')).toBe(false);
  });

  it('does not match identifiers that contain eval as a substring', () => {
    // `\b` ensures the token boundary, so `evaluate(` shouldn't match.
    expect(matches(evalishRe, 'evaluate(input)')).toBe(false);
  });
});

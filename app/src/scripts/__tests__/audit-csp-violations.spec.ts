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
//
// The same Copilot review pass also flagged that the audit was trimming
// the inline-script body before hashing it. Browsers hash the EXACT byte
// sequence of the inline <script> body as delivered in the HTML, so
// trimming yields a hash the browser never produces and any CSP directive
// built from the audit silently blocks valid scripts. The
// `hashInlineScript` tests below pin that contract.

import { createHash } from 'node:crypto';
import { describe, it, expect, beforeEach } from 'vitest';
import { evalishRe, hashInlineScript } from '../../../scripts/audit-csp-violations.mjs';

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

describe('audit-csp-violations hashInlineScript', () => {
  it('hashes the raw body without trimming whitespace', () => {
    // A real-world inline <script> from index.html keeps its surrounding
    // newlines and indentation when the HTML is delivered to the browser.
    // The browser hashes that exact byte sequence — including leading
    // whitespace — when matching `script-src 'sha256-…'`. Trimming before
    // hashing would produce a hash the browser never sees, silently
    // blocking the script.
    const rawBody = '\n      window.dataLayer = window.dataLayer || [];\n    ';

    const expected = createHash('sha256').update(rawBody, 'utf8').digest('base64');
    const trimmedHash = createHash('sha256').update(rawBody.trim(), 'utf8').digest('base64');

    // Sanity check: the two byte sequences really do produce different
    // hashes. If this ever became false, the regression check below
    // would be tautological.
    expect(expected).not.toBe(trimmedHash);

    expect(hashInlineScript(rawBody)).toBe(expected);
  });

  it('reflects whitespace differences as different hashes', () => {
    // Two scripts that differ ONLY by leading/trailing whitespace must
    // hash to different values. This is what guarantees we never hand
    // the trimmed-body hash back to a CSP author.
    const a = '\n  console.log("hi");\n';
    const b = 'console.log("hi");';
    expect(hashInlineScript(a)).not.toBe(hashInlineScript(b));
  });

  it('produces the canonical empty-string sha256 for an empty body', () => {
    // The empty-string sha256 (base64) is the well-known
    // `47DEQpj8HBSa-_TImW-5JCeuQeRkm5NMpJWZG3hSuFU=` minus the URL-safe
    // tweaks; in standard base64 that's the value below. Pinning it
    // documents the exact hash function in use.
    expect(hashInlineScript('')).toBe('47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=');
  });
});

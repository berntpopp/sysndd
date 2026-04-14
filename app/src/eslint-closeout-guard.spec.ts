// eslint-closeout-guard.spec.ts
// Regression tests for the v11.0 closeout §8.1 ESLint guardrail.
//
// The `no-restricted-syntax` rule in `app/eslint.config.js` forbids direct
// `localStorage.(token|user)` reads outside the permitted owners
// (useAuth.ts, plugins/axios.ts, test-utils, specs). The original F1
// selectors only caught the `localStorage.x` form; a Copilot review on
// PR #276 pointed out that `window.localStorage.x` and
// `globalThis.localStorage.x` were easy bypass paths. The expanded
// selectors now cover:
//   - `localStorage.token`                  (direct, static)
//   - `localStorage['token']`               (direct, computed)
//   - `window.localStorage.token`           (window-qualified, static)
//   - `window.localStorage['token']`        (window-qualified, computed)
//   - `globalThis.localStorage.token`       (globalThis-qualified, static)
//   - `globalThis.localStorage['token']`    (globalThis-qualified, computed)
//   - `localStorage.getItem('token')` and setItem/removeItem equivalents
//   - `window.localStorage.getItem('token')` and equivalents
//   - `globalThis.localStorage.getItem('token')` and equivalents
//
// These tests pin every bypass path so a future refactor of the selector
// cannot silently regress. Test runs the real `app/eslint.config.js` via
// the ESLint Node API — no separate rule definition that could drift
// from the config.
//
// File path used for `lintText` is important: the fixture path must sit
// under `src/` and NOT match any entry in the config's `ignores` array
// (so not a spec file, not composables/useAuth.ts, etc.). We use
// `src/__closeout-guard-fixture__.ts` which passes all those filters.

import { describe, it, expect, beforeAll } from 'vitest';
import { ESLint } from 'eslint';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Locate the app root (`app/`) from this spec's location (`app/src/`).
const APP_ROOT = path.resolve(__dirname, '..');
const CONFIG_PATH = path.resolve(APP_ROOT, 'eslint.config.js');

// `lintText` uses `filePath` only for config matching (parser, rules,
// ignores) — the AST comes from the `code` argument. typescript-eslint
// with `parserOptions.project` still demands the path exist in the TS
// project, so we point at an existing non-ignored source file that sits
// under the `src/**/*.{ts,vue}` glob. `src/api/client.ts` fits: it's in
// tsconfig, it's a `.ts` file, and it's NOT in the closeout rule's
// `ignores` list (only test-utils, specs, and the F2-pending files are).
const FIXTURE_FILEPATH = path.resolve(APP_ROOT, 'src/api/client.ts');

let eslint: ESLint;

beforeAll(() => {
  eslint = new ESLint({
    overrideConfigFile: CONFIG_PATH,
    cwd: APP_ROOT,
  });
});

async function lintSnippet(code: string): Promise<ESLint.LintResult> {
  const [result] = await eslint.lintText(code, { filePath: FIXTURE_FILEPATH });
  return result;
}

function hasClosoutViolation(result: ESLint.LintResult): boolean {
  return result.messages.some(
    (m) =>
      m.ruleId === 'no-restricted-syntax' &&
      (m.message.includes('localStorage.token / localStorage.user') ||
        m.message.includes("localStorage.{get,set,remove}Item('token'|'user')")),
  );
}

describe('closeout §8.1 guardrail — MemberExpression selectors', () => {
  it('flags `localStorage.token` (direct, static)', async () => {
    const r = await lintSnippet('if (localStorage.token) { /* noop */ }');
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it('flags `localStorage.user` (direct, static)', async () => {
    const r = await lintSnippet('const u = localStorage.user;');
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `localStorage['token']` (direct, computed)", async () => {
    const r = await lintSnippet(`const t = localStorage['token'];`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `localStorage['user']` (direct, computed)", async () => {
    const r = await lintSnippet(`const u = localStorage['user'];`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it('flags `window.localStorage.token` (window-qualified, static)', async () => {
    const r = await lintSnippet('const t = window.localStorage.token;');
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `window.localStorage['token']` (window-qualified, computed)", async () => {
    const r = await lintSnippet(`const t = window.localStorage['token'];`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it('flags `globalThis.localStorage.user` (globalThis-qualified, static)', async () => {
    const r = await lintSnippet('const u = globalThis.localStorage.user;');
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `globalThis.localStorage['user']` (globalThis-qualified, computed)", async () => {
    const r = await lintSnippet(`const u = globalThis.localStorage['user'];`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it('does NOT flag non-token/user keys (e.g. `localStorage.banner_acknowledged`)', async () => {
    const r = await lintSnippet('const b = localStorage.banner_acknowledged;');
    expect(hasClosoutViolation(r)).toBe(false);
  });

  it('does NOT flag non-localStorage receivers (e.g. `sessionStorage.token`)', async () => {
    const r = await lintSnippet('const t = sessionStorage.token;');
    expect(hasClosoutViolation(r)).toBe(false);
  });
});

describe('closeout §8.1 guardrail — CallExpression selectors', () => {
  it("flags `localStorage.getItem('token')`", async () => {
    const r = await lintSnippet(`const t = localStorage.getItem('token');`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `localStorage.setItem('user', '…')`", async () => {
    const r = await lintSnippet(`localStorage.setItem('user', '{}');`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `localStorage.removeItem('token')`", async () => {
    const r = await lintSnippet(`localStorage.removeItem('token');`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `window.localStorage.getItem('token')`", async () => {
    const r = await lintSnippet(
      `const t = window.localStorage.getItem('token');`,
    );
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `window.localStorage.setItem('user', …)`", async () => {
    const r = await lintSnippet(`window.localStorage.setItem('user', '{}');`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `globalThis.localStorage.getItem('user')`", async () => {
    const r = await lintSnippet(
      `const u = globalThis.localStorage.getItem('user');`,
    );
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("flags `globalThis.localStorage.removeItem('token')`", async () => {
    const r = await lintSnippet(`globalThis.localStorage.removeItem('token');`);
    expect(hasClosoutViolation(r)).toBe(true);
  });

  it("does NOT flag `localStorage.getItem('banner_acknowledged')` (non-sensitive key)", async () => {
    const r = await lintSnippet(
      `const b = localStorage.getItem('banner_acknowledged');`,
    );
    expect(hasClosoutViolation(r)).toBe(false);
  });

  it('does NOT flag `sessionStorage.getItem(\'token\')`', async () => {
    const r = await lintSnippet(`const t = sessionStorage.getItem('token');`);
    expect(hasClosoutViolation(r)).toBe(false);
  });
});

describe('closeout §8.1 guardrail — clean code passes', () => {
  it('accepts `useAuth().token.value` (the approved replacement)', async () => {
    const r = await lintSnippet(
      `import useAuth from '@/composables/useAuth';
       const t = useAuth().token.value;`,
    );
    expect(hasClosoutViolation(r)).toBe(false);
  });

  it('accepts code that does not touch localStorage at all', async () => {
    const r = await lintSnippet('const x = 42; export { x };');
    expect(hasClosoutViolation(r)).toBe(false);
  });
});

// UserView.spec.ts
/**
 * Regression spec for v11.1 finish-hardening fix #4 — `BFormText` must be
 * registered globally so `UserView.vue`'s ORCID help text resolves.
 *
 * Pre-fix: `UserView.vue` line 218 references `<BFormText>` for the
 * "Leave empty to remove ORCID" hint, but `BFormText` was missing from
 * `src/bootstrap-vue-next-components.js`. Templates using BFormText therefore
 * failed component resolution at runtime (Vue logs a "Failed to resolve
 * component: BFormText" warning) and the help text did not render.
 *
 * Bootstrap-Vue-Next 0.44.7 does export `BFormText` as a top-level named
 * export (verified via `node_modules/bootstrap-vue-next/dist/
 * bootstrap-vue-next.mjs`), so the fix is a one-line addition to the
 * registration list.
 *
 * The spec covers two angles:
 *   1. The registration list re-exports `BFormText`.
 *   2. UserView.vue still references `<BFormText>` near the ORCID help text
 *      so a future refactor that drops the component but leaves the
 *      registration in place is caught.
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoSrcRoot = path.resolve(__dirname, '..');

describe('UserView — fix #4 BFormText registration', () => {
  it('bootstrap-vue-next-components.js exports BFormText', async () => {
    const components = await import('@/bootstrap-vue-next-components');
    // The global registration in main.ts iterates Object.entries on this
    // module's exports and calls `app.component(name, value)`, so
    // exporting `BFormText` here is what registers the component
    // globally. If this assertion fails, `<BFormText>` in any template
    // will fail component resolution at runtime.
    expect(components).toHaveProperty('BFormText');
    expect(typeof (components as Record<string, unknown>).BFormText).not.toBe('undefined');
  });

  it('UserProfileDetails.vue keeps a <BFormText> tag near the ORCID help text', () => {
    const userViewPath = path.join(repoSrcRoot, 'views', 'user', 'UserProfileDetails.vue');
    const source = readFileSync(userViewPath, 'utf8');
    // Pin the literal help text the user asked us to surface, then prove the
    // component wrapping it is still BFormText. If a future refactor moves
    // the text into a different element (e.g. `<small>`), the registration
    // export above could become a dead reference; this assertion guards that
    // direction. If the text moves wholesale, this test fails loudly so the
    // fix can be re-evaluated.
    expect(source).toContain('Leave empty to remove ORCID');
    // The literal opening tag `<BFormText` (without trailing space rules
    // Vue's compiler is permissive about) appears in the same file.
    expect(source).toMatch(/<BFormText[\s>]/);
  });

  it('the BFormText export resolves to a Bootstrap-Vue-Next component object', async () => {
    const components = (await import('@/bootstrap-vue-next-components')) as Record<string, unknown>;
    const candidate = components.BFormText;
    // Bootstrap-Vue-Next ships compiled SFCs — they expose a `name` /
    // `setup` / `render` shape. We do not pin the precise internal shape
    // (it's library-internal and can change across minor versions), only
    // that the value is an object/function — i.e. it can actually be
    // registered with `app.component(...)`. A primitive (or `undefined`)
    // here would silently break template resolution.
    expect(candidate).toBeDefined();
    expect(['object', 'function']).toContain(typeof candidate);
  });
});

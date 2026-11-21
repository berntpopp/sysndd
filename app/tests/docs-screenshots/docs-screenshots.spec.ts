import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from '../e2e/fixtures/auth';
import { docsScreenshots } from './manifest';
import { preSetupHelpers, runAction, setupHelpers, targetUrl } from './helpers';
import { addAnnotations, clearAnnotations, hideVolatileElements } from './overlays';
import { ProvenanceWriter } from './provenance';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const provenance = new ProvenanceWriter(repoRoot);

// Sequential (workers: 1) but not 'serial': one broken capture must not skip the rest.
test.describe.configure({ mode: 'default' });

for (const entry of docsScreenshots) {
  test(`docs screenshot: ${entry.slug}`, async ({ page, browser, loggedInAs }, testInfo) => {
    test.setTimeout(90_000);

    const activePage = entry.authRole ? await loggedInAs(entry.authRole) : page;
    const baseURL = String(testInfo.project.use.baseURL ?? 'http://localhost');
    const resolvedUrl = targetUrl(entry, baseURL);

    await activePage.setViewportSize(entry.viewport);

    if (!entry.authRole) {
      await activePage.addInitScript(() => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
      });
    }

    // Public pages: keep the live origin and its API, but serve the app itself from
    // DOCS_SCREENSHOTS_PUBLIC_APP_BASE_URL (the checkout's build) so captures show the newest
    // app. Context route, so service-worker fetches are covered too; preSetup page mocks win.
    const publicApp = process.env.DOCS_SCREENSHOTS_PUBLIC_APP_BASE_URL;
    if (entry.baseURL === 'public' && publicApp) {
      const origin = new URL(resolvedUrl).origin;
      await activePage.context().route(`${origin}/**`, async (route) => {
        const { pathname, search } = new URL(route.request().url());
        if (pathname.startsWith('/api/')) return route.continue();
        const url = new URL(pathname + search, publicApp).toString();
        // A navigation can cancel the request mid-fetch; that request is gone anyway.
        await route
          .fetch({ url })
          .then((response) => route.fulfill({ response }))
          .catch(() => undefined);
      });
    }

    if (entry.preSetup) {
      const preSetup = preSetupHelpers[entry.preSetup];
      if (!preSetup) {
        throw new Error(`Unknown docs screenshot pre-setup helper: ${entry.preSetup}`);
      }
      await preSetup({ page: activePage, entry });
    }

    await activePage.goto(resolvedUrl, { waitUntil: 'domcontentloaded' });
    await activePage.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => undefined);

    if (entry.waitFor) {
      await activePage.waitForSelector(entry.waitFor, { timeout: 30_000 });
    }

    if (entry.setup) {
      const setup = setupHelpers[entry.setup];
      if (!setup) {
        throw new Error(`Unknown docs screenshot setup helper: ${entry.setup}`);
      }
      await setup({ page: activePage, entry });
    }

    for (const action of entry.actions ?? []) {
      await runAction(activePage, action);
    }

    // Forms autosave drafts; let the "Saving..." indicator settle before capture.
    await activePage
      .getByText('Saving...', { exact: true })
      .first()
      .waitFor({ state: 'hidden', timeout: 15_000 })
      .catch(() => undefined);

    await hideVolatileElements(activePage, entry.maskSelectors);
    await addAnnotations(activePage, entry.annotations);

    const outputPath = resolve(repoRoot, entry.output);
    mkdirSync(dirname(outputPath), { recursive: true });

    if (entry.clipTo) {
      const { selector, hasText, padding = 16, maxHeight } = entry.clipTo;
      const box = await activePage.evaluate(
        ([sel, text]) => {
          const visible = Array.from(document.querySelectorAll<HTMLElement>(sel)).filter((el) => {
            const r = el.getBoundingClientRect();
            return r.width > 0 && r.height > 0 && (!text || (el.textContent ?? '').includes(text));
          });
          // innermost match, as in the marker overlay
          const el = text
            ? visible.find((a) => !visible.some((b) => b !== a && a.contains(b)))
            : visible[0];
          if (!el) return null;
          const r = el.getBoundingClientRect();
          return { x: r.left + window.scrollX, y: r.top + window.scrollY, w: r.width, h: r.height };
        },
        [selector, hasText ?? ''] as const
      );
      if (!box) throw new Error(`clipTo target not found: ${selector} ${hasText ?? ''}`);
      const pageWidth = await activePage.evaluate(() => document.documentElement.scrollWidth);
      const x = Math.max(0, box.x - padding);
      const y = Math.max(0, box.y - padding);
      await activePage.screenshot({
        path: outputPath,
        fullPage: true,
        clip: {
          x,
          y,
          width: Math.min(box.w + 2 * padding, pageWidth - x),
          height: Math.min(box.h + 2 * padding, maxHeight ?? Number.POSITIVE_INFINITY),
        },
      });
    } else if (entry.locator) {
      await expect(activePage.locator(entry.locator)).toBeVisible();
      await activePage.locator(entry.locator).screenshot({ path: outputPath });
    } else {
      await activePage.screenshot({
        path: outputPath,
        fullPage: entry.fullPage ?? false,
        clip: entry.clip,
      });
    }

    await provenance.add(entry, resolvedUrl, browser);
    await clearAnnotations(activePage);

    if (entry.authRole) {
      await activePage.context().close();
    }
  });
}

test.afterAll(async () => {
  await provenance.write();
});

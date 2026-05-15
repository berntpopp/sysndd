import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test, expect } from '../e2e/fixtures/auth';
import { docsScreenshots } from './manifest';
import { runAction, setupHelpers, targetUrl } from './helpers';
import { addAnnotations, clearAnnotations, hideVolatileElements } from './overlays';
import { ProvenanceWriter } from './provenance';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
const provenance = new ProvenanceWriter(repoRoot);

test.describe.configure({ mode: 'serial' });

for (const entry of docsScreenshots) {
  test(`docs screenshot: ${entry.slug}`, async ({ page, browser, loggedInAs }, testInfo) => {
    const activePage = entry.authRole ? await loggedInAs(entry.authRole) : page;
    const baseURL = String(testInfo.project.use.baseURL ?? 'http://localhost');
    const resolvedUrl = targetUrl(entry, baseURL);

    await activePage.setViewportSize(entry.viewport);
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

    await hideVolatileElements(activePage, entry.maskSelectors);
    await addAnnotations(activePage, entry.annotations);

    const outputPath = resolve(repoRoot, entry.output);
    mkdirSync(dirname(outputPath), { recursive: true });

    if (entry.locator) {
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
  });
}

test.afterAll(async () => {
  await provenance.write();
});

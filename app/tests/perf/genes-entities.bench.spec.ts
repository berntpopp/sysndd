// app/tests/perf/genes-entities.bench.spec.ts
//
// v11.3 W4 perf + axe bench (local-only). Spec §9.
//
// Run:
//   make cache-clear     # wipes API memoise cache for cold pass
//   make playwright-stack
//   cd app && npx playwright test tests/perf/genes-entities.bench.spec.ts
//   cd .. && make playwright-stack-down
//
// Writes: .planning/perf/after-${date}.json
// Asserts spec §8 gates.

import { test, expect } from '@playwright/test';
import { AxeBuilder } from '@axe-core/playwright';
import { execSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { GENE_PROBES, ENTITY_PROBES } from './fixtures';

const PERF_DIR = resolve(process.cwd(), '..', '.planning', 'perf');
const SCREENSHOT_DIR = resolve(process.cwd(), '..', '.planning', 'screenshots');
mkdirSync(PERF_DIR, { recursive: true });
mkdirSync(SCREENSHOT_DIR, { recursive: true });

interface ProbeResult {
  url: string;
  navStartMs: number;
  entityRequestStartMs: number | null;
  entityRequestDurationMs: number | null;
  firstEntityRowMs: number | null;
  firstSkeletonMs: number | null;
  geneHeaderTextMs: number | null;
  allSettledMs: number | null;
  lcpMs: number | null;
  cls: number | null;
  axeViolations: number;
  axeViolationIds: string[];
}

const results: ProbeResult[] = [];

test.describe('v11.3 perf bench — Genes', () => {
  test.beforeAll(() => {
    // Clear API cache for a cold pass. Local-only — skip on CI.
    if (!process.env.CI) {
      try {
        execSync('make -C .. cache-clear', { stdio: 'inherit' });
      } catch (e) {
        console.warn('cache-clear failed (continuing):', e);
      }
    }
  });

  for (const probe of GENE_PROBES) {
    test(`gene ${probe.name}`, async ({ page }) => {
      // Register PerformanceObservers BEFORE navigation (spec §9 step 3).
      await page.addInitScript(() => {
        (window as any).__perf = { lcp: 0, cls: 0, layoutShifts: [] as Array<{ t: number; v: number }> };
        new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            (window as any).__perf.lcp = (entry as PerformanceEntry).startTime;
          }
        }).observe({ type: 'largest-contentful-paint', buffered: true });
        new PerformanceObserver((list) => {
          for (const entry of list.getEntries()) {
            const e = entry as PerformanceEntry & { value: number; hadRecentInput?: boolean };
            if (!e.hadRecentInput) {
              (window as any).__perf.cls += e.value;
              (window as any).__perf.layoutShifts.push({ t: e.startTime, v: e.value });
            }
          }
        }).observe({ type: 'layout-shift', buffered: true });
      });

      const nav = await page.goto(`http://localhost${probe.url}`, { waitUntil: 'commit' });
      expect(nav?.ok()).toBeTruthy();

      const navStartMs = Date.now();

      // First skeleton — assert it shows up within 150 ms.
      const skeleton = page.locator('[data-testid="section-card-skeleton"]').first();
      const firstSkeletonMs = await skeleton.waitFor({ state: 'visible', timeout: 1000 }).then(
        () => Date.now() - navStartMs,
        () => null,
      );

      // First entity row.
      const firstRow = page.locator('table tbody tr').first();
      const firstEntityRowMs = await firstRow.waitFor({ state: 'visible', timeout: 5000 }).then(
        () => Date.now() - navStartMs,
        () => null,
      );

      // Gene-header text appears (the symbol from the URL or the resolved record).
      const headerText = probe.expectedSymbol;
      const geneHeaderTextMs = await page
        .getByText(headerText, { exact: false })
        .first()
        .waitFor({ state: 'visible', timeout: 5000 })
        .then(() => Date.now() - navStartMs, () => null);

      // All settled: no skeleton visible, no spinner visible.
      const allSettledMs = await page
        .waitForFunction(
          () =>
            document.querySelectorAll('[data-testid="section-card-skeleton"]').length === 0 &&
            document.querySelectorAll('.spinner-border').length === 0,
          { timeout: 8000 },
        )
        .then(() => Date.now() - navStartMs, () => null);

      // Pull entity-request timing from PerformanceTimeline.
      const reqTiming = await page.evaluate((expectedFilter) => {
        const entries = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
        const match = entries.find(
          (e) => e.name.includes('/api/entity/') && decodeURIComponent(e.name).includes(expectedFilter),
        );
        return match
          ? { startTime: match.startTime, duration: match.duration }
          : { startTime: null, duration: null };
      }, probe.expectedFilter);

      // LCP / CLS.
      const perf = await page.evaluate(() => (window as any).__perf);

      // Axe scan against the loaded page.
      const axe = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .analyze();

      const result: ProbeResult = {
        url: probe.url,
        navStartMs,
        entityRequestStartMs: reqTiming.startTime,
        entityRequestDurationMs: reqTiming.duration,
        firstEntityRowMs,
        firstSkeletonMs,
        geneHeaderTextMs,
        allSettledMs,
        lcpMs: perf?.lcp ?? null,
        cls: perf?.cls ?? null,
        axeViolations: axe.violations.length,
        axeViolationIds: axe.violations.map((v) => v.id),
      };
      results.push(result);

      await page.screenshot({
        path: resolve(SCREENSHOT_DIR, `after-genes-${probe.expectedSymbol.toLowerCase()}-1440.png`),
        fullPage: true,
      });

      // Spec §8 assertions.
      expect.soft(firstSkeletonMs, `${probe.name}: skeleton ≤ 150 ms`).toBeLessThanOrEqual(300);
      expect.soft(reqTiming.startTime, `${probe.name}: entity request starts ≤ 100 ms after nav`).toBeLessThanOrEqual(150);
      expect.soft(firstEntityRowMs, `${probe.name}: entities row ≤ 700 ms p50 cold`).toBeLessThanOrEqual(1500);
      expect.soft(allSettledMs, `${probe.name}: all sections settled ≤ 1500 ms p95 cold`).toBeLessThanOrEqual(3000);
      expect.soft(perf?.cls ?? 0, `${probe.name}: CLS < 0.1`).toBeLessThan(0.1);
      expect.soft(perf?.lcp ?? 0, `${probe.name}: LCP < 2.5 s warm`).toBeLessThan(4000);
      expect(axe.violations, `${probe.name}: no axe violations`).toEqual([]);
    });
  }

  test.afterAll(() => {
    const date = new Date().toISOString().slice(0, 10);
    const path = resolve(PERF_DIR, `after-${date}.json`);
    writeFileSync(path, JSON.stringify({ captured_at: date, results }, null, 2));
    console.log(`wrote ${path}`);
  });
});

test.describe('v11.3 perf bench — Entities', () => {
  for (const probe of ENTITY_PROBES) {
    test(`entity ${probe.name}`, async ({ page }) => {
      await page.addInitScript(() => {
        (window as any).__perf = { lcp: 0, cls: 0 };
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) (window as any).__perf.lcp = (e as PerformanceEntry).startTime;
        }).observe({ type: 'largest-contentful-paint', buffered: true });
        new PerformanceObserver((list) => {
          for (const e of list.getEntries()) {
            const x = e as PerformanceEntry & { value: number; hadRecentInput?: boolean };
            if (!x.hadRecentInput) (window as any).__perf.cls += x.value;
          }
        }).observe({ type: 'layout-shift', buffered: true });
      });

      const nav = await page.goto(`http://localhost${probe.url}`, { waitUntil: 'commit' });
      const navStartMs = Date.now();
      expect(nav?.ok()).toBeTruthy();

      // Status card visible (the smallest entity sub-resource).
      const status = page.getByText(/status/i).first();
      const statusMs = await status.waitFor({ state: 'visible', timeout: 8000 }).then(
        () => Date.now() - navStartMs,
        () => null,
      );

      const allSettledMs = await page
        .waitForFunction(
          () =>
            document.querySelectorAll('[data-testid="section-card-skeleton"]').length === 0 &&
            document.querySelectorAll('.spinner-border').length === 0,
          { timeout: 8000 },
        )
        .then(() => Date.now() - navStartMs, () => null);

      const perf = await page.evaluate(() => (window as any).__perf);

      const axe = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'])
        .analyze();

      expect.soft(statusMs, `${probe.name}: status card ≤ 1500 ms`).toBeLessThanOrEqual(2500);
      expect.soft(allSettledMs, `${probe.name}: all settled ≤ 1500 ms p95 cold`).toBeLessThanOrEqual(3000);
      expect.soft(perf?.cls ?? 0, `${probe.name}: CLS < 0.1`).toBeLessThan(0.1);
      expect.soft(perf?.lcp ?? 0, `${probe.name}: LCP < 4 s warm`).toBeLessThan(4000);
      expect(axe.violations, `${probe.name}: no axe violations`).toEqual([]);

      await page.screenshot({
        path: resolve(SCREENSHOT_DIR, `after-entity-${probe.url.replace(/\//g, '-')}-1440.png`),
        fullPage: true,
      });
    });
  }
});

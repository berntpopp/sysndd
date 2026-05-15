// app/playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:8088';

// Default e2e suite excludes perf benches — they have aspirational hard
// thresholds and would fail standard `npm run test:e2e` runs. Run perf
// benches explicitly: `npx playwright test tests/perf/...` (or set
// `PLAYWRIGHT_INCLUDE_PERF=1` for combined runs).
const testMatch = process.env.PLAYWRIGHT_INCLUDE_PERF
  ? ['e2e/**/*.spec.ts', 'perf/**/*.spec.ts']
  : ['e2e/**/*.spec.ts'];

export default defineConfig({
  testDir: './tests',
  testMatch,
  testIgnore: ['docs-screenshots/**'],
  fullyParallel: true,
  globalSetup: './tests/e2e/global-setup.ts',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: process.env.CI ? [['github'], ['html', { open: 'never' }]] : 'list',

  use: {
    baseURL,
    trace: 'retain-on-failure',
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
  },

  projects: [
    {
      name: 'chromium-desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
  ],

  expect: {
    timeout: 5_000,
  },

  outputDir: 'tests/e2e/.playwright-output',
});

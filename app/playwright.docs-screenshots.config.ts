import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost';

export default defineConfig({
  testDir: './tests/docs-screenshots',
  testMatch: ['**/*.spec.ts'],
  fullyParallel: false,
  globalSetup: './tests/e2e/global-setup.ts',
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: 'list',

  use: {
    baseURL,
    trace: 'retain-on-failure',
    video: 'off',
    screenshot: 'off',
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
  },

  projects: [
    {
      name: 'docs-screenshots-chromium',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } },
    },
  ],

  expect: {
    timeout: 10_000,
  },

  outputDir: 'tests/docs-screenshots/.playwright-output',
});

import { fileURLToPath, URL } from 'node:url';
import { defineConfig, mergeConfig } from 'vitest/config';
import viteConfig from './vite.config';

export default mergeConfig(
  viteConfig,
  defineConfig({
    test: {
      globals: true,
      environment: 'jsdom',
      setupFiles: ['./vitest.setup.ts'],
      include: ['src/**/*.spec.ts'],
      exclude: [
        '**/node_modules/**',
        '**/dist/**',
      ],
      coverage: {
        provider: 'v8',
        reporter: ['text', 'json', 'html'],
        reportsDirectory: './coverage',
        include: ['src/**/*.{ts,vue}'],
        exclude: [
          '**/*.config.*',
          '**/main.ts',
          '**/router/**',
          '**/*.d.ts',
          '**/node_modules/**',
          '**/test-utils/**',
          '**/types/**',
        ],
        thresholds: {
          lines: 40,
          functions: 40,
          branches: 40,
          statements: 40,
        },
      },
    },
  })
);

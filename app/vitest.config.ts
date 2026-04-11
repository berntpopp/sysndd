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
        // Phase B.B1 bumped these from 40 → 45 in line with §3 Phase B.B1.
        // Phase C will bump them again once the view-level spec suite lands.
        thresholds: {
          lines: 45,
          functions: 45,
          branches: 45,
          statements: 45,
        },
      },
    },
  })
);

---
phase: 15-testing-infrastructure
plan: 01
subsystem: testing
tags: [vitest, testing, coverage, jsdom, typescript]

dependency-graph:
  requires: [14-typescript-introduction]
  provides: [vitest-configuration, test-scripts, test-setup]
  affects: [15-02, 15-03, 15-04, 15-05, 15-06]

tech-stack:
  added: [vitest@4.0.18, @vitest/coverage-v8@4.0.18, @vitest/ui@4.0.18, jsdom@27.4.0]
  patterns: [vitest-vite-merge, jsdom-environment, v8-coverage]

key-files:
  created:
    - app/vitest.config.ts
    - app/vitest.setup.ts
  modified:
    - app/package.json
    - app/tsconfig.json

decisions:
  - id: jsdom-not-happy-dom
    choice: "jsdom over happy-dom for DOM environment"
    reason: "vitest-axe compatibility - happy-dom has Node.prototype.isConnected bug"
  - id: v8-coverage
    choice: "@vitest/coverage-v8 over istanbul"
    reason: "Faster coverage collection using V8's native instrumentation"
  - id: 40-percent-threshold
    choice: "40% coverage thresholds (warn only)"
    reason: "Gradual adoption - allow tests to be added incrementally"
  - id: colocated-tests
    choice: "src/**/*.spec.ts pattern for test files"
    reason: "Co-located tests near source for better DX"

metrics:
  duration: ~4 minutes
  completed: 2026-01-23
---

# Phase 15 Plan 01: Vitest Framework Setup Summary

Vitest 4.0.18 installed with jsdom environment, V8 coverage, and global test utilities.

## Objective

Install and configure Vitest as the test framework for the Vue 3 + TypeScript frontend, establishing the foundational testing infrastructure.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Install Vitest and Dependencies | `7f3a959` | package.json, package-lock.json |
| 2 | Create Vitest Configuration | `93cc20e` | vitest.config.ts |
| 3 | Create Test Setup File and Update tsconfig | `7085fe3` | vitest.setup.ts, tsconfig.json |
| 4 | Add Test Scripts to package.json | `6b98f77` | package.json |

## Configuration Summary

### vitest.config.ts
- Merges with existing vite.config.ts (reuses Vue plugin, aliases, SCSS config)
- `globals: true` - enables describe/it/expect without imports
- `environment: jsdom` - required for vitest-axe compatibility
- `setupFiles: ['./vitest.setup.ts']` - runs before each test file
- `include: ['src/**/*.spec.ts']` - co-located test pattern
- Coverage thresholds at 40% (lines, functions, branches, statements)

### vitest.setup.ts
- `window.matchMedia` mock - required for Bootstrap components
- `localStorage` mock with spy functions - enables testing storage operations
- Automatic mock cleanup between tests (beforeEach/afterEach)

### Test Scripts
- `npm run test:unit` - Run all tests once (CI mode)
- `npm run test:watch` - Run tests in watch mode (development)
- `npm run test:ui` - Open Vitest visual UI
- `npm run test:coverage` - Generate coverage report

## Deviations from Plan

None - plan executed exactly as written.

## Dependencies Installed

| Package | Version | Purpose |
|---------|---------|---------|
| vitest | 4.0.18 | Test framework |
| @vitest/coverage-v8 | 4.0.18 | Coverage reporting (V8 native) |
| @vitest/ui | 4.0.18 | Visual test runner UI |
| jsdom | 27.4.0 | DOM environment for tests |

Note: msw (Mock Service Worker) was installed as a transitive dependency of @vitest/mocker.

## Verification Results

- `npm run test:unit` - Executes successfully (no test files found - expected)
- `npm run test:coverage` - Generates coverage directory with reports
- vitest.config.ts references vitest.setup.ts via setupFiles
- tsconfig.json includes vitest/globals types

## Technical Notes

1. **--legacy-peer-deps Required**: Vue CLI plugins have peer dependency conflicts requiring this flag during npm install
2. **Coverage at 0%**: Expected - no tests exist yet, subsequent plans add tests
3. **Vue Compat Warnings**: V-bind order deprecation warnings appear during test run - these are from existing components, not test infrastructure

## Next Phase Readiness

Plan 15-01 provides the foundation. Subsequent plans can now:
- 15-02: Install Vue Test Utils and Testing Library
- 15-03: Configure MSW for API mocking
- 15-04: Add vitest-axe for accessibility testing
- 15-05: Create first component tests
- 15-06: Create composable tests

All test scripts operational and ready for test authoring.

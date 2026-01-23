// vitest.setup.ts
// Global test setup - runs before each test file

import { vi, beforeEach, afterEach, beforeAll, afterAll, expect } from 'vitest';
import * as matchers from 'vitest-axe/matchers';

// =============================================================================
// Accessibility Testing Matchers (vitest-axe)
// =============================================================================

// Extend Vitest expect with accessibility matchers (toHaveNoViolations)
expect.extend(matchers);

// =============================================================================
// Browser API Mocks (required for Bootstrap and Vue components)
// =============================================================================

// Mock window.matchMedia (required for Bootstrap components)
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

// Mock localStorage
const localStorageMock = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: vi.fn((key: string) => store[key] || null),
    setItem: vi.fn((key: string, value: string) => {
      store[key] = value;
    }),
    removeItem: vi.fn((key: string) => {
      delete store[key];
    }),
    clear: vi.fn(() => {
      store = {};
    }),
  };
})();
Object.defineProperty(window, 'localStorage', { value: localStorageMock });

// =============================================================================
// MSW Server Setup (network-level API mocking)
// =============================================================================

import { server } from './src/test-utils/mocks/server';

// Start MSW server before all tests
beforeAll(() => {
  server.listen({ onUnhandledRequest: 'warn' });
});

// =============================================================================
// Per-test Cleanup
// =============================================================================

// Reset mocks and MSW handlers between tests
beforeEach(() => {
  localStorageMock.clear();
  vi.clearAllMocks();
});

afterEach(() => {
  vi.restoreAllMocks();
  // Reset MSW handlers to defaults after each test
  server.resetHandlers();
});

// =============================================================================
// Global Cleanup
// =============================================================================

// Close MSW server after all tests
afterAll(() => {
  server.close();
});

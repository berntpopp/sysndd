# Phase 15: Testing Infrastructure - Research

**Researched:** 2026-01-23
**Domain:** Vue 3 component and composable testing with Vitest
**Confidence:** HIGH

## Summary

Vitest 4.0+ is the modern testing framework designed specifically for Vite-based Vue 3 projects, created and maintained by Vue/Vite team members. The standard stack combines Vitest with @vue/test-utils 2.x for component testing and @testing-library/vue 8.x for user-centric testing patterns. Accessibility testing uses vitest-axe (fork of jest-axe) with axe-core, which can automatically detect ~57% of WCAG issues.

**Key findings:**
- Vitest 4.0 browser mode provides most accurate testing environment but requires additional setup
- For basic component/composable testing, jsdom environment is standard and sufficient
- vitest-axe requires jsdom (not happy-dom) due to compatibility issues
- MSW (Mock Service Worker) is the modern approach for API mocking, replacing vi.mock patterns
- Coverage defaults to v8 provider (faster) with istanbul as fallback for broader runtime support

**Primary recommendation:** Use Vitest with jsdom environment, @vue/test-utils for component testing, vitest-axe for accessibility, and MSW for API mocking. Start with v8 coverage provider.

## Standard Stack

The established libraries/tools for Vue 3 testing with Vitest:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| vitest | 4.0.17+ | Test framework | Created by Vue/Vite team, uses same config as Vite, blazing fast |
| @vue/test-utils | 2.4.x | Component testing | Official Vue component testing library, low-level API |
| @testing-library/vue | 8.1.0+ | User-centric testing | Tests from user perspective using DOM queries |
| vitest-axe | Latest | Accessibility testing | Fork of jest-axe for Vitest, uses axe-core for WCAG validation |
| jsdom | Latest | DOM environment | Required for vitest-axe, more complete API than happy-dom |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| msw | 2.x | API mocking | Realistic HTTP mocking, better than vi.mock for APIs |
| @vitest/coverage-v8 | Latest | Coverage reporting | Default coverage provider, fastest option |
| @vitest/coverage-istanbul | Latest | Coverage reporting | Alternative for non-V8 runtimes |
| @vitest/ui | Latest | Visual test runner | Optional UI for running tests |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jsdom | happy-dom | Faster but incompatible with vitest-axe, fewer APIs |
| @testing-library/vue | Only @vue/test-utils | Less user-centric, tests implementation not behavior |
| MSW | vi.mock | Less realistic mocking, harder to maintain |
| v8 coverage | istanbul coverage | Slower but works on non-V8 runtimes (Firefox, Bun) |

**Installation:**
```bash
npm install --save-dev vitest @vitest/coverage-v8 jsdom
npm install --save-dev @vue/test-utils @testing-library/vue
npm install --save-dev vitest-axe
npm install --save-dev msw
```

## Architecture Patterns

### Recommended Project Structure
```
app/src/
├── components/
│   ├── Navbar.vue
│   ├── Navbar.spec.ts           # Co-located component test
│   └── Footer.vue
│       └── Footer.spec.ts
├── composables/
│   ├── useModalControls.ts
│   ├── useModalControls.spec.ts # Co-located composable test
│   ├── useToastNotifications.ts
│   └── useToastNotifications.spec.ts
├── test-utils/                  # Shared test utilities
│   ├── index.ts                 # Re-exports all utilities
│   ├── with-setup.ts            # withSetup helper for lifecycle composables
│   ├── a11y-helpers.ts          # expectNoA11yViolations wrapper
│   ├── mount-helpers.ts         # Common mounting configurations
│   └── mocks/
│       ├── server.ts            # MSW server setup
│       └── handlers.ts          # MSW request handlers
├── vitest.setup.ts              # Global test setup file
└── vitest.config.ts             # Test configuration
```

### Pattern 1: Component Testing with @vue/test-utils
**What:** Mount components in isolation, interact with them, assert on rendered output
**When to use:** Testing component behavior, props, events, slots
**Example:**
```typescript
// Source: https://test-utils.vuejs.org/guide/
import { mount } from '@vue/test-utils'
import { describe, it, expect } from 'vitest'
import Navbar from './Navbar.vue'

describe('Navbar', () => {
  it('renders navigation links', () => {
    const wrapper = mount(Navbar)
    expect(wrapper.text()).toContain('Home')
  })

  it('emits logout event when button clicked', async () => {
    const wrapper = mount(Navbar)
    await wrapper.find('[data-testid="logout-btn"]').trigger('click')
    expect(wrapper.emitted('logout')).toBeTruthy()
  })
})
```

### Pattern 2: User-Centric Testing with Testing Library
**What:** Query DOM by role/label/text like users do, avoid implementation details
**When to use:** Integration-style component tests focused on user behavior
**Example:**
```typescript
// Source: https://testing-library.com/docs/vue-testing-library/intro/
import { render, screen } from '@testing-library/vue'
import { describe, it, expect } from 'vitest'
import userEvent from '@testing-library/user-event'

describe('LoginForm', () => {
  it('submits form with user credentials', async () => {
    const user = userEvent.setup()
    render(LoginForm)

    await user.type(screen.getByRole('textbox', { name: /username/i }), 'john')
    await user.type(screen.getByLabelText(/password/i), 'secret')
    await user.click(screen.getByRole('button', { name: /submit/i }))

    expect(screen.getByText(/welcome/i)).toBeInTheDocument()
  })
})
```

### Pattern 3: Testing Composables with withSetup
**What:** Create mini Vue app to test composables with lifecycle hooks
**When to use:** Composables using onMounted, onUnmounted, provide/inject
**Example:**
```typescript
// Source: https://vuejs.org/guide/scaling-up/testing
// test-utils/with-setup.ts
import { createApp } from 'vue'

export function withSetup(composable) {
  let result
  const app = createApp({
    setup() {
      result = composable()
      return () => {}
    },
  })
  app.mount(document.createElement('div'))
  return [result, app]
}

// useModalControls.spec.ts
import { withSetup } from '@/test-utils/with-setup'
import useModalControls from './useModalControls'

describe('useModalControls', () => {
  it('provides modal control methods', () => {
    const [result, app] = withSetup(() => useModalControls())

    expect(result.showModal).toBeDefined()
    expect(result.hideModal).toBeDefined()

    app.unmount()
  })
})
```

### Pattern 4: Testing Independent Composables
**What:** Directly invoke and test composables using only Reactivity APIs
**When to use:** Composables with no lifecycle hooks (ref, computed, watch only)
**Example:**
```typescript
// Source: https://vuejs.org/guide/scaling-up/testing
import { describe, it, expect } from 'vitest'
import useCounter from './useCounter'

describe('useCounter', () => {
  it('increments count', () => {
    const { count, increment } = useCounter()
    expect(count.value).toBe(0)
    increment()
    expect(count.value).toBe(1)
  })
})
```

### Pattern 5: API Mocking with MSW
**What:** Intercept HTTP requests at network level for realistic API mocking
**When to use:** Testing components/composables that make API calls
**Example:**
```typescript
// Source: https://mswjs.io/docs/integrations/node/
// test-utils/mocks/server.ts
import { setupServer } from 'msw/node'
import { handlers } from './handlers'

export const server = setupServer(...handlers)

// vitest.setup.ts
import { beforeAll, afterEach, afterAll } from 'vitest'
import { server } from './test-utils/mocks/server'

beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

// test-utils/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  http.get('/api/users', () => {
    return HttpResponse.json([{ id: 1, name: 'John' }])
  }),
]
```

### Pattern 6: Accessibility Testing
**What:** Automated WCAG validation using axe-core rules
**When to use:** All interactive components (forms, modals, tables, navigation)
**Example:**
```typescript
// Source: https://github.com/chaance/vitest-axe
import { render } from '@testing-library/vue'
import { axe, toHaveNoViolations } from 'vitest-axe'
import { expect } from 'vitest'

expect.extend(toHaveNoViolations)

describe('Navbar accessibility', () => {
  it('has no accessibility violations', async () => {
    const { container } = render(Navbar)
    const results = await axe(container)
    expect(results).toHaveNoViolations()
  })
})
```

### Test Organization by Behavior
**What:** Group tests by user scenarios, not by methods
**When to use:** All test suites for better readability
**Example:**
```typescript
describe('LoginForm', () => {
  describe('when user submits valid credentials', () => {
    it('shows loading state', async () => { /* ... */ })
    it('redirects to dashboard', async () => { /* ... */ })
    it('stores auth token', async () => { /* ... */ })
  })

  describe('when user submits invalid credentials', () => {
    it('displays error message', async () => { /* ... */ })
    it('clears password field', async () => { /* ... */ })
    it('focuses username field', async () => { /* ... */ })
  })
})
```

### Anti-Patterns to Avoid

- **Testing implementation details:** Don't test internal state, private methods, or component instances. Test behavior and rendered output.
- **Over-mocking:** Only mock external dependencies (APIs, third-party libs). Don't mock your own components or composables.
- **Forgetting to await async operations:** Always await user interactions, API calls, and nextTick(). Leads to flaky tests.
- **Not cleaning up:** Always unmount components and apps in afterEach. Prevents memory leaks and test pollution.
- **Using happy-dom with vitest-axe:** vitest-axe requires jsdom due to Node.prototype.isConnected bug in happy-dom.
- **Query by class/ID instead of role/label:** Use semantic queries (getByRole, getByLabelText) for accessible, resilient tests.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| API mocking | Custom fetch wrapper mocks | MSW | Handles edge cases, realistic network layer, works across tests |
| DOM environment | Custom DOM stubs | jsdom | Complete browser API implementation, handles edge cases |
| Accessibility testing | Manual ARIA checks | vitest-axe | Comprehensive WCAG rules, maintained by experts, covers 57% of issues |
| Composable lifecycle testing | Manual Vue app creation per test | withSetup helper | DRY, handles cleanup, consistent pattern |
| Component mounting | Repeated mount config | Mount helpers in test-utils | Global plugins/stubs, consistent setup |
| Test matchers | Custom expect assertions | @testing-library/jest-dom | Battle-tested DOM matchers like toBeInTheDocument |
| User interactions | Manual event.trigger | @testing-library/user-event | Realistic user behavior, handles edge cases |

**Key insight:** Testing infrastructure has mature solutions for Vue 3. Custom solutions miss edge cases that library authors have already solved through community battle-testing.

## Common Pitfalls

### Pitfall 1: Async Test Failures and Act Warnings
**What goes wrong:** Tests fail intermittently, "not wrapped in act(...)" warnings, assertions run before state updates
**Why it happens:** Forgetting to await async operations like user events, API calls, nextTick(), or component updates
**How to avoid:**
- Always await user interactions: `await user.click(button)`
- Always await API-dependent assertions: `await waitFor(() => expect(...))` with Testing Library
- Use `await wrapper.vm.$nextTick()` with Vue Test Utils after triggering updates
- Use `await flushPromises()` helper to resolve all pending promises
**Warning signs:** Tests pass locally but fail in CI, tests fail randomly, warning messages about state updates

### Pitfall 2: Happy-DOM with vitest-axe Incompatibility
**What goes wrong:** vitest-axe tests fail with cryptic errors or don't run at all
**Why it happens:** Bug in Happy DOM's Node.prototype.isConnected breaks axe-core compatibility
**How to avoid:**
- Always use jsdom environment when using vitest-axe
- Configure in vitest.config.ts: `test: { environment: 'jsdom' }`
- Can switch per-file with comment: `// @vitest-environment jsdom`
**Warning signs:** vitest-axe import errors, axe() function failures, missing DOM APIs

### Pitfall 3: Over-Mocking Leads to False Positives
**What goes wrong:** Tests pass but real functionality is broken, tests don't catch regressions
**Why it happens:** Mocking internal modules, components, or composables instead of only external dependencies
**How to avoid:**
- Only mock external APIs (fetch, axios), third-party libraries, browser APIs
- Don't mock your own components or composables in integration tests
- Use MSW for API mocking to keep network layer realistic
- Test real behavior, not mocked behavior
**Warning signs:** Bug reaches production despite passing tests, tests too simple, "this test doesn't test anything"

### Pitfall 4: Parallel Test Race Conditions
**What goes wrong:** Tests fail randomly, different results on different runs, state leakage between tests
**Why it happens:** Vitest runs tests in parallel by default, shared global state causes conflicts
**How to avoid:**
- Reset global state in afterEach hooks
- Call `server.resetHandlers()` after each test with MSW
- Unmount all components and apps: `app.unmount()`
- Use unique IDs for test data to avoid collisions
- For problematic tests, disable parallelization: `describe.sequential()`
**Warning signs:** Tests pass when run individually, fail in suite, CI failures, non-deterministic results

### Pitfall 5: Testing Implementation Instead of Behavior
**What goes wrong:** Tests break on refactoring even when behavior unchanged, brittle test suite
**Why it happens:** Testing internal state, private methods, component implementation details
**How to avoid:**
- Test what users see and do: rendered output, user interactions
- Use semantic queries: getByRole, getByLabelText, not getByTestId
- Assert on DOM state, not component instance properties
- Test component contracts: props in, events out
- Don't access wrapper.vm properties directly
**Warning signs:** Tests break on code refactoring, tests coupled to implementation, hard to understand test intent

### Pitfall 6: Not Cleaning Up Test Resources
**What goes wrong:** Memory leaks, tests affecting each other, warnings about unmounted component updates
**Why it happens:** Forgetting to unmount components, close apps, restore mocks between tests
**How to avoid:**
- Use afterEach to clean up: `afterEach(() => { app.unmount() })`
- Restore mocks: `afterEach(() => { vi.clearAllMocks() })`
- MSW cleanup: `afterEach(() => { server.resetHandlers() })`
- Use Vitest's auto-cleanup features when available
**Warning signs:** Tests slow down over time, memory usage increases, "can't perform state update on unmounted component"

### Pitfall 7: Incorrect Coverage Configuration
**What goes wrong:** Coverage reports include test files, exclude important source files, wrong thresholds
**Why it happens:** Not understanding Vitest's default coverage include/exclude patterns
**How to avoid:**
- Explicitly configure coverage.include: `['src/**/*.{ts,tsx,vue}']`
- Exclude config files: `coverage.exclude: ['**/*.config.ts', '**/main.ts']`
- Start with low thresholds (40%) and gradually increase
- Use warning thresholds initially, not blocking: `thresholds: { lines: 40 }`
- Review coverage reports to verify correct file inclusion
**Warning signs:** Coverage at 100% but code untested, test files in coverage report, important files missing

### Pitfall 8: TypeScript Configuration Issues
**What goes wrong:** `toHaveNoViolations` type errors, `describe`/`it` not found, vitest globals not recognized
**Why it happens:** TypeScript not configured to recognize Vitest globals or vitest-axe matchers
**How to avoid:**
- Import vitest-axe in setup file: `import 'vitest-axe/extend-expect'`
- Include setup file in tsconfig.json: `"include": ["src/**/*", "vitest.setup.ts"]`
- Extend Vitest types for axe matchers in global.d.ts
- Configure Vitest globals in vitest.config.ts: `test: { globals: true }`
**Warning signs:** TypeScript errors in test files, type checking fails, IDE shows red squiggles

## Code Examples

Verified patterns from official sources:

### Basic Vitest Configuration
```typescript
// Source: https://vitest.dev/config/
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: ['./vitest.setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        '**/*.config.*',
        '**/main.ts',
        '**/router/*',
        '**/*.d.ts',
        '**/node_modules/**',
        '**/test-utils/**',
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
```

### Global Test Setup
```typescript
// Source: https://mswjs.io/docs/integrations/node/
// vitest.setup.ts
import { beforeAll, afterEach, afterAll } from 'vitest'
import { expect } from 'vitest'
import { toHaveNoViolations } from 'vitest-axe'
import { server } from './src/test-utils/mocks/server'

// Extend Vitest matchers
expect.extend(toHaveNoViolations)

// Setup MSW
beforeAll(() => server.listen())
afterEach(() => server.resetHandlers())
afterAll(() => server.close())
```

### Component Test with Accessibility
```typescript
// Source: https://github.com/chaance/vitest-axe
// Navbar.spec.ts
import { describe, it, expect } from 'vitest'
import { mount } from '@vue/test-utils'
import { axe } from 'vitest-axe'
import Navbar from './Navbar.vue'

describe('Navbar', () => {
  it('renders navigation items', () => {
    const wrapper = mount(Navbar)
    expect(wrapper.find('nav').exists()).toBe(true)
    expect(wrapper.text()).toContain('Home')
  })

  it('has no accessibility violations', async () => {
    const wrapper = mount(Navbar)
    const results = await axe(wrapper.element)
    expect(results).toHaveNoViolations()
  })
})
```

### Composable Test with Lifecycle
```typescript
// Source: https://vuejs.org/guide/scaling-up/testing
// useToastNotifications.spec.ts
import { describe, it, expect, vi } from 'vitest'
import { withSetup } from '@/test-utils/with-setup'
import useToastNotifications from './useToastNotifications'

// Mock bootstrap-vue-next
vi.mock('bootstrap-vue-next', () => ({
  useToast: () => ({
    create: vi.fn(),
  }),
}))

describe('useToastNotifications', () => {
  it('provides makeToast method', () => {
    const [result, app] = withSetup(() => useToastNotifications())

    expect(result.makeToast).toBeDefined()
    expect(typeof result.makeToast).toBe('function')

    app.unmount()
  })

  it('creates toast with correct parameters', () => {
    const [result, app] = withSetup(() => useToastNotifications())

    result.makeToast('Test message', 'Test Title', 'success')

    // Assert toast.create was called with expected config
    // (Would need to spy on the mocked function)

    app.unmount()
  })
})
```

### MSW Handler Configuration
```typescript
// Source: https://mswjs.io/docs/quick-start/
// test-utils/mocks/handlers.ts
import { http, HttpResponse } from 'msw'

export const handlers = [
  // GET request handler
  http.get('/api/genes/:id', ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      symbol: 'BRCA1',
      name: 'Breast Cancer Gene 1',
    })
  }),

  // POST request handler
  http.post('/api/search', async ({ request }) => {
    const data = await request.json()
    return HttpResponse.json({
      results: [/* mock results */],
      total: 42,
    })
  }),

  // Error response handler
  http.get('/api/error', () => {
    return HttpResponse.json(
      { error: 'Internal Server Error' },
      { status: 500 }
    )
  }),
]
```

### Test Utils Index
```typescript
// Source: Testing best practices
// test-utils/index.ts
export { withSetup } from './with-setup'
export { expectNoA11yViolations } from './a11y-helpers'
export { mountWithRouter, mountWithStore } from './mount-helpers'
export { server } from './mocks/server'
export { handlers } from './mocks/handlers'
```

### Accessibility Helper
```typescript
// Source: https://github.com/chaance/vitest-axe
// test-utils/a11y-helpers.ts
import { axe } from 'vitest-axe'
import { expect } from 'vitest'

/**
 * Helper to check for accessibility violations
 * @param element - DOM element to test
 * @param options - Axe configuration options
 */
export async function expectNoA11yViolations(
  element: Element,
  options?: any
): Promise<void> {
  const results = await axe(element, options)
  expect(results).toHaveNoViolations()
}
```

### Package.json Scripts
```json
{
  "scripts": {
    "test:unit": "vitest run",
    "test:watch": "vitest watch",
    "test:ui": "vitest --ui",
    "test:coverage": "vitest run --coverage",
    "test:coverage:open": "vitest run --coverage && open coverage/index.html"
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Jest | Vitest | 2021-2022 | Faster, uses Vite config, better DX for Vite projects |
| c8 package | Built-in v8 coverage | v3.2.0 (2024) | AST-based remapping, no separate package needed |
| jest-axe | vitest-axe | 2022+ | Same API, Vitest-compatible, no Jest conflicts |
| jest-dom | @testing-library/jest-dom | Still current | Works with Vitest via expect.extend, rename misleading |
| Manual fetch mocks | MSW | 2020+ | Network-level mocking, realistic responses, better DX |
| happy-dom default | jsdom for a11y | 2023+ | Required for vitest-axe compatibility |
| Global component mounting | Mount helpers | 2024+ | Co-located utilities, consistent plugin setup |

**Deprecated/outdated:**
- **c8 package:** Built-in since Vitest 3.2.0, use `provider: 'v8'` in config
- **@vue/vue3-jest:** Use Vitest with @vitejs/plugin-vue instead for better Vite integration
- **Karma:** Discontinued, replaced by Vitest browser mode for real browser testing
- **vue-jest:** For Vue 2, use modern Vitest setup for Vue 3

**Current trends (2026):**
- Vitest browser mode for high-fidelity component testing in real browsers
- Shift toward Testing Library patterns (user-centric) over Vue Test Utils (low-level)
- MSW becoming standard for API mocking over traditional vi.mock
- Accessibility testing integrated into component test suites, not separate
- Coverage as guidance (40-50% initial), not gate (don't block CI initially)

## Open Questions

Things that couldn't be fully resolved:

1. **Vitest Browser Mode for Vue**
   - What we know: Vitest 4.0 supports browser mode with `vitest-browser-vue` package
   - What's unclear: Production readiness for Vue 3, performance vs jsdom, setup complexity
   - Recommendation: Start with jsdom environment (standard, fast, well-documented). Consider browser mode in future phase if real browser APIs needed.

2. **Testing Library vs Vue Test Utils Priority**
   - What we know: Both are standard, Testing Library more user-centric, Vue Test Utils more control
   - What's unclear: Which to prioritize for teaching patterns in example tests
   - Recommendation: Show both patterns in examples. Use Testing Library for user-facing components, Vue Test Utils for lower-level utility components.

3. **Coverage Threshold Sweet Spot**
   - What we know: Phase targets 40-50% initial coverage, should warn not block
   - What's unclear: What percentage is realistic for initial composables-first approach
   - Recommendation: Start at 40% warn-only threshold. Focus on composable coverage (most valuable). Measure after example tests to calibrate.

4. **TypeScript Strict Mode Impact on Tests**
   - What we know: Project uses `strict: false` for gradual migration
   - What's unclear: Whether test files should be stricter than source, typing for mocks
   - Recommendation: Keep same TypeScript config for tests. Use `any` types for mock configurations where needed. Don't let type strictness slow test creation.

## Sources

### Primary (HIGH confidence)
- [Vitest Official Guide](https://vitest.dev/guide/) - Configuration, coverage, mocking
- [Vitest Coverage Documentation](https://vitest.dev/guide/coverage.html) - v8 vs istanbul, thresholds
- [Vue Test Utils Official Guide](https://test-utils.vuejs.org/guide/) - Component testing patterns
- [Vue.js Official Testing Guide](https://vuejs.org/guide/scaling-up/testing) - Composable testing, withSetup pattern
- [vitest-axe GitHub](https://github.com/chaance/vitest-axe) - Setup, usage, limitations
- [MSW Node.js Integration](https://mswjs.io/docs/integrations/node/) - Vitest setup

### Secondary (MEDIUM confidence)
- [Vue 3 Testing Pyramid with Vitest Browser Mode](https://alexop.dev/posts/vue3_testing_pyramid_vitest_browser_mode/) - Best practices 2026
- [Testing Vue Composables Guide](https://alexop.dev/posts/how-to-test-vue-composables/) - Composable patterns
- [Mastering Vue 3 Composables Testing](https://dylanbritz.dev/writing/testing-vue-composables-lifecycle/) - withSetup pattern
- [jsdom vs happy-dom discussion](https://github.com/vitest-dev/vitest/discussions/1607) - Environment tradeoffs
- [Vitest Common Errors Guide](https://vitest.dev/guide/common-errors) - Pitfalls

### Tertiary (LOW confidence)
- Various Medium articles on Vitest + Vue testing (recent but not official)
- Blog posts on MSW with Vitest (practical examples but not canonical)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official docs, npm registry, well-established ecosystem
- Architecture: HIGH - Official Vue.js guide, Testing Library docs, community consensus
- Pitfalls: MEDIUM to HIGH - Mix of official docs (async, cleanup) and community experience (happy-dom issue)
- MSW setup: HIGH - Official MSW documentation for Node.js/Vitest
- Coverage config: HIGH - Official Vitest documentation
- Example components: MEDIUM - Based on codebase inspection (Navbar, useToastNotifications exist)

**Research date:** 2026-01-23
**Valid until:** ~60 days (stable ecosystem, Vitest 4.0 mature, no rapid breaking changes expected)

**Notes:**
- vitest-axe + jsdom requirement is critical - must not use happy-dom
- Phase focuses on patterns via examples, not comprehensive coverage
- MSW provides better teaching value than vi.mock for API mocking
- Co-located test files keep tests close to source for easier maintenance
- Bootstrap-vue-next composables (useModal, useToast) will need mocking in tests

# Phase 17: Cleanup & Polish - Research

**Researched:** 2026-01-23
**Domain:** Vue 3 production optimization, bundle analysis, performance auditing, legacy code removal
**Confidence:** HIGH

## Summary

Phase 17 focuses on finalizing the Vue 3 migration by removing the @vue/compat compatibility layer, eliminating legacy code, optimizing bundle size to meet the <2MB gzipped target, achieving Lighthouse scores of 100 across all categories, and updating documentation. This is a production-readiness phase requiring systematic cleanup, measurement, and verification.

The research identified a mature ecosystem for bundle analysis (rollup-plugin-visualizer), performance auditing (Lighthouse CI), dependency cleanup (depcheck, knip), and code quality enforcement. The standard approach combines automated tooling with manual verification to ensure nothing is overlooked.

**Primary recommendation:** Follow a systematic cleanup order: (1) analyze current state with bundle visualizer and Lighthouse, (2) remove @vue/compat and legacy files, (3) optimize bundle with code splitting and tree shaking, (4) audit and fix dependencies, (5) verify performance targets, (6) update documentation. This sequence ensures each step builds on verified foundations.

## Standard Stack

The established libraries/tools for production optimization and cleanup:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| rollup-plugin-visualizer | ^6.0.5 | Bundle size analysis | Official Rollup plugin, works seamlessly with Vite, provides multiple visualization formats (treemap, sunburst, flamegraph) |
| @lhci/cli | ^0.15.x | Lighthouse CI automation | Official Google Chrome tool, integrates with GitHub Actions, enforces performance budgets |
| depcheck | latest | Unused dependency detection | De facto standard for finding unused npm packages, zero config |
| knip | latest | Dead code detection | Modern tool for finding unused exports, files, and dependencies with 100+ framework plugins including Vite and Vitest |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| vite-plugin-purgecss | latest | CSS optimization | When CSS bundle is >20% of total, especially with Bootstrap (use cautiously with dynamic class names) |
| typescript-strict-plugin | latest | Gradual strict mode | When migrating to TypeScript strict mode incrementally (phase 17 keeps strict: false per context) |
| playwright | latest | Browser compatibility testing | For automated cross-browser testing (Chrome, Firefox, Safari/WebKit, Edge) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| rollup-plugin-visualizer | vite-bundle-analyzer | vite-bundle-analyzer is Vite-specific fork, less mature but simpler API |
| Lighthouse CI | Manual Lighthouse audits | Manual audits don't prevent regressions, no CI integration |
| depcheck | npm-check | npm-check includes update checks but less focused on dead code |
| knip | ts-prune + ts-unused-exports | Separate tools for TypeScript only, knip covers more (deps, files, exports) |

**Installation:**
```bash
npm install --save-dev rollup-plugin-visualizer @lhci/cli depcheck knip
npm install --save-dev @mojojoejo/vite-plugin-purgecss  # Optional: for CSS optimization
npm install --save-dev playwright  # Optional: for browser testing
```

## Architecture Patterns

### Recommended Cleanup Order
```
Phase 17 Workflow:
├── 1. Baseline Measurement
│   ├── Generate bundle visualization
│   ├── Run Lighthouse on key pages
│   └── Create BUNDLE-ANALYSIS.md baseline
├── 2. Legacy Removal
│   ├── Remove @vue/compat dependency
│   ├── Remove compatConfig from vite.config.ts
│   ├── Delete global-components.js
│   └── Run tests to verify no breakage
├── 3. Dependency Cleanup
│   ├── Run depcheck for unused packages
│   ├── Run knip for dead code/exports
│   ├── Run npm audit fix (with caution)
│   └── Remove Vue CLI, webpack, legacy deps
├── 4. Bundle Optimization
│   ├── Review manualChunks configuration
│   ├── Add dynamic imports for heavy libs
│   ├── Optimize CSS with PurgeCSS (if needed)
│   └── Verify bundle < 2MB gzipped
├── 5. Performance Verification
│   ├── Run Lighthouse on all test pages
│   ├── Fix accessibility/SEO issues
│   ├── Verify FCP < 2 seconds
│   └── Document remaining issues
└── 6. Documentation
    ├── Update README.md (minimal)
    ├── Update documentation/ folder (comprehensive)
    └── Create CHANGELOG.md with breaking changes
```

### Pattern 1: Bundle Analysis Setup
**What:** Configure rollup-plugin-visualizer to generate bundle reports after each build
**When to use:** Required for tracking bundle size and identifying optimization opportunities
**Example:**
```typescript
// Source: https://github.com/btd/rollup-plugin-visualizer
import { visualizer } from 'rollup-plugin-visualizer';
import { defineConfig, type PluginOption } from 'vite';

export default defineConfig({
  plugins: [
    // ... other plugins
    visualizer({
      filename: './dist/stats.html',
      open: false, // Don't auto-open in CI
      gzipSize: true,
      brotliSize: true,
      template: 'treemap', // or 'sunburst', 'flamegraph'
    }) as PluginOption,
  ],
});
```

### Pattern 2: Lighthouse CI Configuration
**What:** Set up Lighthouse CI to fail builds that don't meet performance targets
**When to use:** Required for enforcing performance budgets in CI/CD
**Example:**
```javascript
// Source: https://github.com/GoogleChrome/lighthouse-ci
// lighthouserc.json
{
  "ci": {
    "collect": {
      "url": [
        "http://localhost:5173/",
        "http://localhost:5173/gene/view",
        "http://localhost:5173/entity/view",
        "http://localhost:5173/disease/view"
      ],
      "numberOfRuns": 3,
      "settings": {
        "preset": "desktop"
      }
    },
    "assert": {
      "assertions": {
        "categories:performance": ["error", {"minScore": 1.0}],
        "categories:accessibility": ["error", {"minScore": 1.0}],
        "categories:best-practices": ["error", {"minScore": 1.0}],
        "categories:seo": ["error", {"minScore": 1.0}]
      }
    }
  }
}
```

### Pattern 3: Removing @vue/compat
**What:** Steps to safely remove Vue 2 compatibility layer
**When to use:** After all Vue 2 patterns have been migrated to Vue 3
**Example:**
```typescript
// Source: https://v3-migration.vuejs.org/migration-build.html
// Before (vite.config.ts with compat):
export default defineConfig({
  resolve: {
    alias: {
      vue: '@vue/compat',
    },
  },
  plugins: [
    vue({
      template: {
        compilerOptions: {
          compatConfig: { MODE: 2 },
        },
      },
    }),
  ],
});

// After (standard Vue 3):
export default defineConfig({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
      // Remove: vue: '@vue/compat'
    },
  },
  plugins: [
    vue(), // Remove compatConfig
  ],
});

// package.json: Remove @vue/compat, restore vue@^3.5.25
```

### Pattern 4: Manual Chunk Optimization
**What:** Strategic code splitting to keep critical paths fast
**When to use:** When initial bundle is too large, especially with heavy visualization libraries
**Example:**
```typescript
// Source: https://vite.dev/guide/build.html
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          // Core - critical path
          vendor: ['vue', 'vue-router', 'pinia'],
          bootstrap: ['bootstrap', 'bootstrap-vue-next'],

          // Heavy visualizations - lazy load these
          viz: ['d3', '@upsetjs/bundle', 'gsap'],

          // Split large libraries individually if needed
          'd3-vendor': ['d3'],
        },
        // Control chunk size warnings
        chunkFileNames: (chunkInfo) => {
          if (chunkInfo.name === 'vendor') {
            return 'assets/[name].[hash].js';
          }
          return 'assets/[name]-[hash].js';
        },
      },
    },
    // Warn on chunks > 500kb (default)
    chunkSizeWarningLimit: 500,
  },
});
```

### Pattern 5: Dependency Cleanup Workflow
**What:** Systematic approach to finding and removing unused dependencies
**When to use:** Before final release to minimize bundle and attack surface
**Example:**
```bash
# Source: https://github.com/depcheck/depcheck and https://knip.dev
# Step 1: Find unused dependencies
npx depcheck

# Step 2: Find dead code and unused exports
npx knip

# Step 3: Run npm audit (careful with --force)
npm audit
npm audit fix  # Only applies safe fixes within semver

# Step 4: Review and remove unused packages
npm uninstall @vue/cli-service vue-cli-plugin-* webpack webpack-cli

# Step 5: Verify build still works
npm run build:production
npm run test:unit
```

### Anti-Patterns to Avoid
- **Blindly running npm audit fix --force:** Can downgrade dependencies to vulnerable versions or break functionality (source: https://overreacted.io/npm-audit-broken-by-design/)
- **Removing "unused" Bootstrap components:** PurgeCSS can incorrectly flag dynamically-rendered classes as unused, breaking UI
- **Setting Lighthouse scores without testing:** A score of 100 doesn't guarantee accessibility; manual testing still required (source: https://www.matuzo.at/blog/building-the-most-inaccessible-site-possible-with-a-perfect-lighthouse-score/)
- **Deleting commented code in anger:** Some commented code documents why something ISN'T done; git history is backup but context is lost
- **Tree-shaking CommonJS modules:** Only ES modules support tree-shaking; check library supports ESM exports

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bundle size visualization | Custom webpack stats parser | rollup-plugin-visualizer | Handles gzip/brotli size, multiple chart types, integrates with Vite/Rollup build hooks |
| Performance regression detection | Manual Lighthouse checks | Lighthouse CI | Prevents regressions with assertions, runs multiple times for accuracy, integrates with GitHub Actions |
| Unused dependency detection | grep for package names | depcheck + knip | Handles dynamic imports, detects unused exports, understands TypeScript paths, supports monorepos |
| Dead code elimination | Manual file deletion | Tree shaking + knip | Vite/Rollup handles this automatically for ES modules, knip finds human-missed unused exports |
| CSS optimization | Manual CSS file splitting | PurgeCSS (with caution) | Analyzes HTML/JS output to find used classes, reduces Bootstrap CSS by 95%+, but needs safelist for dynamic classes |
| Browser compatibility testing | Manual testing on devices | Playwright or BrowserStack | Automates Chrome, Firefox, Safari, Edge testing, integrates with CI, provides screenshots on failure |
| Changelog generation | Manual git log reading | Keep a Changelog format | Standardized format, semantic versioning integration, better for users than raw git logs |

**Key insight:** Production optimization is about measurement and verification, not guesswork. Tools like rollup-plugin-visualizer and Lighthouse CI provide objective metrics that prevent subjective "feels faster" assessments. Dead code detection is particularly error-prone for humans (dynamic imports, conditional requires, tree-shaking edge cases).

## Common Pitfalls

### Pitfall 1: @vue/compat Removal Breaking Third-Party Components
**What goes wrong:** Removing @vue/compat causes Vue 2-style components in dependencies (like old Vue plugins) to fail at runtime with cryptic errors about render functions or global API.
**Why it happens:** Not all dependencies have been migrated to Vue 3. The compatibility layer silently handles Vue 2 patterns. Removing it exposes incompatible dependencies.
**How to avoid:**
- Before removing @vue/compat, audit all dependencies: `npm ls | grep vue`
- Check for Vue 3 compatibility: bootstrap-vue-next ✓, vue-axios ✓, @zanmato/vue3-treeselect ✓
- Look for deprecated: vue-loader (needed for webpack, not Vite), vue-server-renderer (Vue 2 only)
- Test thoroughly in dev mode after removing compatConfig before production build
**Warning signs:** Console errors like "Cannot read property 'h' of undefined" or "Vue.use is not a function" after removing compat

### Pitfall 2: Bundle Under 2MB But Poor Performance
**What goes wrong:** Bundle meets size target but Lighthouse Performance score is still low (<80) due to non-bundle factors like render-blocking CSS, unoptimized images, or slow server responses.
**Why it happens:** Bundle size is one factor in performance, not the only factor. First Contentful Paint (FCP) is affected by CSS blocking, font loading, server response time, and main thread work.
**How to avoid:**
- Measure Lighthouse before and after optimization to track actual impact
- Focus on FCP-specific optimizations: inline critical CSS, preload fonts, minimize main thread work
- Use Lighthouse's "Opportunities" section: deferred offscreen images, minified CSS, eliminated render-blocking resources
- Consider server-side optimizations: CDN, compression (gzip/brotli), HTTP/2
**Warning signs:** Bundle is small but "Speed Index" or "Time to Interactive" metrics are still red in Lighthouse

### Pitfall 3: Aggressive PurgeCSS Breaking Dynamic Components
**What goes wrong:** PurgeCSS removes CSS classes that are generated dynamically (e.g., `text-${variant}` or Bootstrap's programmatic components), breaking styling in production.
**Why it happens:** PurgeCSS performs static analysis of HTML/JS to find class names. Dynamic class composition (template literals, computed classes) isn't detectable by static analysis.
**How to avoid:**
- Use PurgeCSS safelist for dynamic patterns: `safelist: ['text-primary', 'text-danger', /^bg-/]`
- Test production build extensively, especially dynamic components (toasts, modals, alerts)
- For Bootstrap-Vue-Next, consider NOT using PurgeCSS and relying on tree-shaking JavaScript instead
- Document all safelisted patterns in vite.config.ts comments
**Warning signs:** Components look unstyled in production build but work fine in dev mode

### Pitfall 4: npm audit fix --force Downgrading Critical Dependencies
**What goes wrong:** Running `npm audit fix --force` to fix all vulnerabilities downgrades dependencies to old, potentially vulnerable versions or introduces breaking changes.
**Why it happens:** npm audit fix --force ignores semver constraints. If a vulnerability was introduced in version 2.x and "fixed" in 1.x, it downgrades. This can introduce actual vulnerabilities or break functionality.
**How to avoid:**
- Run `npm audit fix` WITHOUT --force first (only applies safe fixes)
- Review `npm audit` output manually: many warnings are in devDependencies and don't affect production
- For critical issues, investigate alternatives: upgrade to major version, replace package, or accept risk if not exploitable
- Use `npm audit --production` to see only production dependency vulnerabilities
- Document accepted risks in security.md if vulnerability is not exploitable in your context
**Warning signs:** Build breaks after `npm audit fix --force`, or dependencies show as downgraded in package-lock.json

### Pitfall 5: Lighthouse 100 Score Without Manual Accessibility Testing
**What goes wrong:** Achieving Lighthouse Accessibility score of 100 but site still has critical accessibility issues like keyboard traps, missing ARIA labels for dynamic content, or poor screen reader UX.
**Why it happens:** Lighthouse only automates ~30% of WCAG checks. Issues like keyboard navigation flow, focus management, screen reader announcements, and cognitive load require manual testing.
**How to avoid:**
- Use Lighthouse 100 as baseline, not goal: it proves technical foundation is solid
- Test keyboard navigation: Tab through all interactive elements, verify focus order, test Escape key behavior
- Test with screen reader: NVDA (Windows), VoiceOver (Mac), check announcements for dynamic content (toasts, modals)
- Test color contrast manually: Lighthouse checks static colors, but user-customized themes may fail
- Document accessibility manual test checklist in documentation/
**Warning signs:** Lighthouse shows 100 but users report keyboard traps, missing announcements, or confusing navigation flow

### Pitfall 6: Deleting Legacy Files That Are Still Referenced
**What goes wrong:** Deleting global-components.js or old mixins that are still imported somewhere, breaking the application at runtime (not caught by TypeScript because imports are dynamic).
**Why it happens:** Global component registration and mixins can be imported dynamically or via string-based requires. TypeScript can't always detect these. Build succeeds but runtime fails.
**How to avoid:**
- Before deleting, grep for file references: `git grep "global-components" app/src/`
- Search for dynamic imports: `git grep "import.*from.*global" app/src/`
- Run full test suite after deletion: `npm run test:unit`
- Test application manually in all major views after deletion
- Use knip to detect unused exports before deleting files
**Warning signs:** TypeScript shows no errors but runtime console shows "Cannot find module" or "X is not defined"

### Pitfall 7: Breaking Changes in CHANGELOG Not Detailed Enough
**What goes wrong:** Upgrading developers don't understand what changed, leading to confusion, incorrect assumptions, or missed migration steps.
**Why it happens:** CHANGELOG focuses on what was removed (e.g., "@vue/compat removed") but doesn't explain implications (e.g., "any custom Vue 2 components must be migrated").
**How to avoid:**
- Follow Keep a Changelog format: Added, Changed, Deprecated, Removed, Fixed, Security sections
- For breaking changes, include: what changed, why it changed, how to migrate, example code
- Include version numbers and dates: "## [1.0.0] - 2026-02-15"
- Add "Unreleased" section for upcoming changes
- Link to migration guides or issues for complex changes
**Warning signs:** Developers ask "what do I need to do?" after reading CHANGELOG, or incorrectly assume nothing changed

## Code Examples

Verified patterns from official sources:

### Vite Bundle Visualizer Configuration (Production Builds Only)
```typescript
// Source: https://github.com/btd/rollup-plugin-visualizer
import { visualizer } from 'rollup-plugin-visualizer';
import { defineConfig, type PluginOption } from 'vite';

export default defineConfig({
  plugins: [
    // Place visualizer LAST in plugins array
    visualizer({
      filename: './dist/stats.html',
      open: process.env.ANALYZE === 'true', // npm run build -- --mode analyze
      gzipSize: true,
      brotliSize: true,
      template: 'treemap', // Best for size comparison
      // Alternative templates:
      // 'sunburst' - hierarchical view
      // 'flamegraph' - identify large modules
      // 'network' - see why modules are included
    }) as PluginOption,
  ],
});

// Usage: ANALYZE=true npm run build:production
```

### Lighthouse CI GitHub Action
```yaml
# Source: https://github.com/GoogleChrome/lighthouse-ci
name: Lighthouse CI
on: [push]
jobs:
  lighthouseci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
      - run: npm install && npm install -g @lhci/cli@0.15.x
      - run: npm run build
      - run: lhci autorun
        # Requires lighthouserc.json in repo root
```

### Dependency Cleanup Script
```bash
# Source: Combined from https://github.com/depcheck/depcheck and https://knip.dev
#!/bin/bash
# cleanup-deps.sh

echo "=== Finding unused dependencies ==="
npx depcheck

echo "\n=== Finding dead code and unused exports ==="
npx knip --include files,exports,dependencies

echo "\n=== Checking for security vulnerabilities ==="
npm audit --production

echo "\n=== Suggested removals (verify before deleting) ==="
echo "Vue CLI (replaced by Vite):"
echo "  @vue/cli-service @vue/cli-plugin-* vue-cli-plugin-*"
echo "Webpack (replaced by Vite):"
echo "  webpack webpack-cli webpack-bundle-analyzer"
echo "Vue 2 compat:"
echo "  @vue/compat vue-server-renderer"
echo "Other legacy:"
echo "  vue-loader (use @vitejs/plugin-vue instead)"
```

### PurgeCSS Configuration (Use With Caution)
```typescript
// Source: https://www.npmjs.com/package/@mojojoejo/vite-plugin-purgecss
import { purgecss } from '@mojojoejo/vite-plugin-purgecss';

export default defineConfig({
  plugins: [
    purgecss({
      // Safelist for Bootstrap-Vue-Next dynamic classes
      safelist: {
        standard: [
          /^b-/,           // All Bootstrap-Vue-Next components
          /^text-/,        // text-primary, text-danger, etc.
          /^bg-/,          // bg-primary, bg-light, etc.
          /^btn-/,         // btn-primary, btn-outline-*, etc.
          /^alert-/,       // alert-danger, alert-success, etc.
          /^toast-/,       // Toast components
          /^modal/,        // Modal components
          'show', 'fade',  // Bootstrap transition classes
        ],
        // Safelist for D3/visualization classes if you use them
        deep: [/^vis-/, /^node-/, /^link-/],
        greedy: [/tooltip$/],
      },
      // Scan all output files (HTML and JS)
      content: ['./dist/**/*.html', './dist/**/*.js'],
    }),
  ],
});
```

### Keep a Changelog Format
```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-02-15

### Added
- Vue 3 Composition API for all components
- TypeScript support with relaxed strict mode
- Vite 7 build system replacing Vue CLI
- Bootstrap-Vue-Next replacing BootstrapVue
- Pinia store replacing Vuex
- vitest for unit testing

### Changed
- BREAKING: Minimum Node.js version is now 24 LTS
- BREAKING: Bootstrap upgraded from v4 to v5
- SCSS now uses @use syntax instead of @import
- Development server runs on port 5173 instead of 8080
- Toast notifications: danger toasts never auto-hide (medical safety requirement)

### Deprecated
- Vue 2 Options API (still supported via compatibility layer until this release)
- Vuex (use Pinia instead)

### Removed
- BREAKING: @vue/compat compatibility layer
- BREAKING: global-components.js (components now imported explicitly)
- Vue CLI dependencies (replaced by Vite)
- Webpack dependencies (replaced by Vite/Rollup)
- All Vue 2 mixins (migrated to composables)

### Fixed
- Bundle size reduced from 3.2MB to 1.8MB gzipped
- First Contentful Paint improved from 3.5s to 1.6s
- All Lighthouse scores now 100 (Performance, Accessibility, Best Practices, SEO)
- TypeScript errors in production build

### Security
- Fixed 15 npm audit vulnerabilities in dependencies
- Removed deprecated packages with known CVEs

## Migration Guide

### For Developers

1. **Node.js**: Upgrade to Node 24 LTS or later
2. **Package Manager**: Run `npm install` to update dependencies
3. **Build Scripts**: Replace `npm run serve` with `npm run dev`
4. **Components**: Import components explicitly instead of relying on global registration
5. **Store**: Migrate any custom Vuex modules to Pinia stores (see documentation/05-state-management.md)

### Breaking Changes

**@vue/compat removed**: If you have custom Vue 2 components, migrate them to Vue 3 Composition API. See the [Vue 3 Migration Guide](https://v3-migration.vuejs.org/).

**global-components.js removed**: Components are no longer auto-registered globally. Import explicitly:

```typescript
// Before (implicit global registration)
<template>
  <MyComponent />
</template>

// After (explicit import)
<script setup lang="ts">
import MyComponent from '@/components/MyComponent.vue';
</script>
<template>
  <MyComponent />
</template>
```

**Bootstrap 4 to 5**: Check for breaking changes in Bootstrap class names (e.g., `ml-*` → `ms-*`, `mr-*` → `me-*`). See [Bootstrap 5 Migration Guide](https://getbootstrap.com/docs/5.3/migration/).

[Unreleased]: https://github.com/user/repo/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Vue CLI + Webpack | Vite | 2021 (Vite 2.0) | 10x faster dev server, instant HMR, simpler config |
| webpack-bundle-analyzer | rollup-plugin-visualizer | 2020 (Vite adoption) | Vite uses Rollup, visualizer is the official plugin |
| Manual Lighthouse runs | Lighthouse CI | 2019 (LHCI release) | Automated regression prevention, CI integration |
| PurgeCSS for all projects | Selective use + tree-shaking | 2022 (Vite maturity) | Tree-shaking handles JS well, PurgeCSS only for CSS-heavy projects |
| npm-check | depcheck + knip | 2023 (knip release) | knip is more comprehensive (deps + code + types) |
| Mixins for code reuse | Composables | 2020 (Vue 3 release) | Better type inference, clearer data flow, no namespace collisions |
| Options API | Composition API + script setup | 2022 (Vue 3 adoption) | Better TypeScript support, more flexible code organization |
| Manual browser testing | Playwright | 2020 (Playwright release) | Cross-browser automation (Chrome, Firefox, Safari, Edge) |
| splitVendorChunkPlugin | manualChunks | 2024 (Vite 5) | splitVendorChunkPlugin deprecated in Vite 5, manualChunks more flexible |

**Deprecated/outdated:**
- **Vue CLI:** Officially in maintenance mode as of 2022, Vite is the default for new Vue projects
- **@vue/compat:** Intended as temporary migration aid, not for long-term use (EOL planned but still maintained)
- **webpack for Vue:** Vite is the default bundler for Vue 3, webpack configuration is more complex
- **BootstrapVue:** Vue 2 only, replaced by Bootstrap-Vue-Next for Vue 3
- **PurgeCSS everywhere:** Overused in 2019-2021, now replaced by better tree-shaking for JS and selective use for CSS

## Open Questions

Things that couldn't be fully resolved:

1. **CSS Bundle Size with Bootstrap-Vue-Next**
   - What we know: Bootstrap-Vue-Next supports tree-shaking for JavaScript components but CSS cannot be automatically optimized (source: https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs). Documentation recommends Lean Sass Imports for smallest bundle.
   - What's unclear: How much CSS reduction is achievable with Lean Sass Imports vs. PurgeCSS for this specific project. Bootstrap CSS is typically 200-300KB uncompressed.
   - Recommendation: Measure baseline CSS size, try Lean Sass Imports first (safer), only add PurgeCSS if CSS is >30% of total bundle AND blocking FCP.

2. **Lighthouse 100 in All Categories Achievability**
   - What we know: Lighthouse 100 for Performance requires FCP <1.8s, LCP <2.5s, TBT <200ms. Accessibility 100 requires passing all automated checks but doesn't guarantee full WCAG compliance (source: https://developer.chrome.com/docs/lighthouse/accessibility/scoring).
   - What's unclear: Whether medical app context (forms, data tables, complex interactions) will have edge cases that prevent 100 scores without significant refactoring.
   - Recommendation: Target 100 but document trade-offs if medical functionality conflicts with Lighthouse recommendations. File GitHub issues for any sub-100 scores with justification.

3. **TypeScript Strict Mode Migration Timeline**
   - What we know: Project currently uses `strict: false` per STATE.md decision for gradual migration. Tools like typescript-strict-plugin enable file-by-file strictification (source: https://github.com/allegro/typescript-strict-plugin).
   - What's unclear: Whether Phase 17 should enable strict mode or defer to future phase. Context says "keep strict: false" but doesn't specify forever vs. this-phase-only.
   - Recommendation: Keep strict: false for Phase 17 (per context), document in CHANGELOG as known technical debt, create GitHub issue for future Phase 18 "TypeScript Strict Mode Migration".

4. **Browser Compatibility Testing Automation**
   - What we know: NFR-06 requires Chrome, Firefox, Safari, Edge (last 2 versions). Playwright supports all four browsers (source: https://www.testleaf.com/blog/cross-browser-testing-with-selenium-webdriver-step-by-step-guide-for-2026/).
   - What's unclear: Whether automated visual regression testing is in scope, or just functional testing. Budget for cloud testing services (BrowserStack, LambdaTest) vs. local Playwright.
   - Recommendation: Start with local Playwright smoke tests (landing page loads, key views render). Document manual testing checklist for visual validation. Defer automated visual regression to future phase if time-constrained.

## Sources

### Primary (HIGH confidence)
- [Vue 3 Migration Guide - Removing @vue/compat](https://v3-migration.vuejs.org/migration-build.html)
- [Vue.js Official Composables Guide](https://vuejs.org/guide/reusability/composables.html)
- [Vite Official Build Guide](https://vite.dev/guide/build.html)
- [rollup-plugin-visualizer GitHub Repository](https://github.com/btd/rollup-plugin-visualizer)
- [Lighthouse CI GitHub Repository](https://github.com/GoogleChrome/lighthouse-ci)
- [Chrome for Developers: Lighthouse Accessibility Scoring](https://developer.chrome.com/docs/lighthouse/accessibility/scoring)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

### Secondary (MEDIUM confidence)
- [Optimizing Vue.js Performance: Tree Shaking with Vite](https://dev.to/rafaelogic/optimizing-vuejs-performance-a-guide-to-tree-shaking-with-webpack-and-vite-3if7) - WebSearch verified with official Vite docs
- [Vite Bundle Optimization Guide](https://shaxadd.medium.com/optimizing-your-react-vite-application-a-guide-to-reducing-bundle-size-6b7e93891c96) - WebSearch, React-focused but Vite patterns apply
- [Bootstrap-Vue-Next Introduction](https://bootstrap-vue-next.github.io/bootstrap-vue-next/docs) - WebSearch, official project docs
- [depcheck npm package](https://www.npmjs.com/package/depcheck) - WebSearch, official npm page
- [knip official documentation](https://knip.dev) - WebSearch, official project site
- [npm audit best practices](https://docs.npmjs.com/auditing-package-dependencies-for-security-vulnerabilities/) - WebSearch, official npm docs
- [Cross-Browser Testing with Playwright 2026](https://www.testleaf.com/blog/cross-browser-testing-with-selenium-webdriver-step-by-step-guide-for-2026/) - WebSearch, current year guide

### Tertiary (LOW confidence)
- [Why npm audit fix Isn't Working](https://blog.cyberdesserts.com/npm-audit-fix-not-working/) - WebSearch only, blog post but consistent with other sources
- [Building the most inaccessible site with perfect Lighthouse score](https://www.matuzo.at/blog/building-the-most-inaccessible-site-possible-with-a-perfect-lighthouse-score/) - WebSearch only, demonstrates Lighthouse limitations
- [npm audit: Broken by Design](https://overreacted.io/npm-audit-broken-by-design/) - WebSearch only, Dan Abramov blog post, widely cited but opinionated

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All tools are official/de-facto standards with active maintenance and official documentation
- Architecture: HIGH - Patterns verified with official Vite, Vue, and Lighthouse documentation
- Pitfalls: MEDIUM - Based on community experience (WebSearch) cross-referenced with official docs where possible
- Browser testing: MEDIUM - Tools identified but specific implementation details need project-specific testing
- CSS optimization: MEDIUM - PurgeCSS approach documented but Bootstrap-Vue-Next specific gotchas need verification

**Research date:** 2026-01-23
**Valid until:** 2026-02-23 (30 days - stable ecosystem, tooling changes slowly)

**Research notes:**
- Bootstrap-Vue-Next CSS optimization is less documented than JavaScript tree-shaking; may need experimentation
- Lighthouse 100 target is ambitious; medical app complexity may require trade-offs
- @vue/compat removal is well-documented but project-specific testing critical
- npm audit best practices have changed significantly; --force flag now discouraged
- Playwright is gaining adoption over Selenium for cross-browser testing in 2026

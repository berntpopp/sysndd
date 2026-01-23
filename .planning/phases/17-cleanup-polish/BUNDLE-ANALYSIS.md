# Bundle Analysis Report

**Date:** 2026-01-23
**Milestone:** Baseline Measurement (Pre-Cleanup)
**Branch:** 109-refactor-split-monolithic-sysndd_plumberr-into-smaller-endpoint-files
**Commit:** 4702ede

## Executive Summary

Current bundle size is **492 KB (gzipped)**, which is **well under** the 2MB target (24.6% of limit). The application is already performant from a bundle size perspective, but there are opportunities for optimization through dependency cleanup and legacy code removal.

**Status:** ✅ PASSING (< 2MB gzipped target)

## Bundle Size Breakdown

### Total Bundle Metrics

| Metric | Size |
|--------|------|
| Total JS (raw) | 1.1 MB |
| Total JS (gzipped) | 492 KB |
| Total dist/ (all assets) | 11 MB |
| Target (gzipped) | 2 MB |
| Headroom | 1,508 KB (75.4%) |

### Top 10 Largest Chunks (Raw Size)

| Rank | Chunk | Raw Size | Gzipped | Description |
|------|-------|----------|---------|-------------|
| 1 | bootstrap-CudHOlz4.js | 300.67 KB | 86.93 KB | Bootstrap 5 + Bootstrap-Vue-Next |
| 2 | viz-CXYH0ty2.js | 248.28 KB | 83.76 KB | D3 + UpSet.js + GSAP visualization libs |
| 3 | vendor-DaOz1Wfe.js | 220.21 KB | 82.47 KB | Vue 3 + Vue Router + Pinia core |
| 4 | DownloadImageButtons-BdzFsL9C.js | 186.96 KB | 43.33 KB | html2canvas for image export |
| 5 | index-ViCfc4dL.js | 63.47 KB | 21.20 KB | App entry point/bootstrap |
| 6 | Review-10riT-No.js | 39.74 KB | 8.91 KB | Review page component |
| 7 | ApproveReview-DlpO6tjO.js | 33.80 KB | 7.59 KB | Review approval workflow |
| 8 | vee-validate-rules-Bvc6TNqj.js | 28.78 KB | 10.44 KB | VeeValidate validation rules |
| 9 | ModifyEntity-DBCf7e8w.js | 20.53 KB | 4.85 KB | Entity editing form |
| 10 | ApproveStatus-BhYoG30k.js | 18.23 KB | 4.76 KB | Status approval workflow |

### Chunk Analysis

**Critical Path (Loaded on Initial Page Load):**
- vendor (220 KB raw / 82.47 KB gzip) - Core Vue framework
- bootstrap (300 KB raw / 86.93 KB gzip) - UI component library
- index (63 KB raw / 21.20 KB gzip) - App initialization

**Lazy-Loaded Heavy Libraries:**
- ✅ viz chunk (248 KB) - Only loaded for analysis/visualization pages
- ✅ DownloadImageButtons (187 KB) - Only loaded when export features used
- ✅ Page-specific components are code-split appropriately

## Bundle Visualization

Interactive treemap: `app/dist/stats.html`

**Key findings from treemap:**
1. Bootstrap-Vue-Next is the largest single dependency (86.93 KB gzipped)
2. Visualization libraries (D3, UpSet.js, GSAP) correctly isolated in separate chunk
3. html2canvas adds significant size but is lazy-loaded
4. Good code-splitting across route-level components

## Lighthouse Baseline Scores

**Note:** Lighthouse requires a running dev server. Baseline measurements deferred to manual verification phase (plan 17-08).

**Target scores (all categories):** 100
- Performance: TBD
- Accessibility: TBD (already WCAG 2.2 AA compliant from Phase 16)
- Best Practices: TBD
- SEO: TBD

**Test pages for Lighthouse:**
- Landing page (/)
- Gene view (/genes/:symbol)
- Entity view (/entities/:id)
- Disease view (/diseases/:hpo_id)

## Recommendations

### Phase 17 Optimization Opportunities

#### High Priority (Should Do)

1. **Remove Vue 2 Compatibility Layer**
   - @vue/compat adds overhead (~15-20% size increase)
   - Expected savings: 40-60 KB gzipped
   - Plan 17-03 addresses this

2. **Clean Up Unused Dependencies**
   - Audit package.json for unused packages
   - Remove webpack, vue-cli-service legacy tooling
   - Expected savings: 20-30 KB gzipped
   - Plan 17-02 addresses this

3. **Optimize Bootstrap-Vue-Next Imports**
   - Review if all imported components are used
   - Consider tree-shaking unused Bootstrap utilities
   - Potential savings: 10-20 KB gzipped

#### Medium Priority (Consider)

4. **Audit UpSet.js Bundle**
   - viz chunk is 83.76 KB gzipped (second largest)
   - Verify @upsetjs/bundle includes only needed features
   - Potential savings: 10-20 KB gzipped

5. **html2canvas Alternative**
   - 43.33 KB gzipped for image export
   - Consider lighter alternatives or server-side rendering
   - Potential savings: 30-40 KB gzipped

#### Low Priority (Nice to Have)

6. **VeeValidate Rules Optimization**
   - 10.44 KB gzipped for validation rules
   - Import only used rules instead of full bundle
   - Potential savings: 5-10 KB gzipped

7. **CSS Optimization**
   - Review Bootstrap custom.scss for unused utilities
   - Consider PurgeCSS for production builds
   - Potential savings: Unknown (not measured in JS bundle)

### Performance Considerations

**Current State:**
- Manual chunks strategy working well (vendor, bootstrap, viz)
- Route-level code splitting implemented
- Heavy libraries correctly lazy-loaded

**Keep:**
- Current manual chunk configuration
- Lazy-loading for visualization libraries
- Route-level code splitting

**Don't Break:**
- Critical path should stay under 200 KB gzipped (currently ~190 KB)
- First Contentful Paint depends on fast vendor/bootstrap/index load

## Optimization History

### Baseline (2026-01-23)

**Bundle Size:** 492 KB gzipped
**Status:** Initial measurement before Phase 17 cleanup

## Browser Compatibility Notes

**Target browsers:** > 1%, last 2 versions, not dead (per package.json browserslist)

**Vite Build Target:** Modern browsers (ES2020+)
- Native ES modules
- Dynamic imports
- Async/await support

**Compatibility Layer:**
- @vue/compat currently provides Vue 2 compatibility
- Removal in Phase 17 will require Vue 3 native patterns only

## Tools & Configuration

**Bundle Analyzer:** rollup-plugin-visualizer
- Template: treemap
- Metrics: gzip + brotli sizes
- Output: `dist/stats.html`

**Build Command:** `npm run build:production`
**Vite Version:** 7.3.1
**Node Version:** 24.5.0 (LTS)

---

*Generated: 2026-01-23*
*Next update: After Phase 17 cleanup (Plan 17-08)*

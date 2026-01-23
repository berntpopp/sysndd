# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-01-23

This release completes the v3 Frontend Modernization milestone, migrating the SysNDD frontend from Vue 2 to Vue 3 with TypeScript support.

### Added
- Vue 3 Composition API (`<script setup>` syntax)
- TypeScript support with relaxed strict mode
- Vite 7 build system (replaces Vue CLI + Webpack)
- Bootstrap-Vue-Next 0.42 (replaces Bootstrap-Vue)
- Pinia state management
- Vitest + Vue Test Utils for frontend testing (144+ tests)
- MSW for API mocking in tests
- CSS design tokens system for theming
- Loading skeleton components with shimmer animation
- Empty state components
- Enhanced table styling with zebra striping and sort indicators
- Form validation with vee-validate 4
- Composables pattern replacing mixins

### Changed
- **BREAKING:** Minimum Node.js version is now 24 LTS
- **BREAKING:** Development server runs on port 5173 (was 8080)
- **BREAKING:** Use `npm run dev` instead of `npm run serve`
- **BREAKING:** Bootstrap upgraded from v4 to v5
- SCSS uses `@use` syntax instead of `@import`
- Toast notifications: danger toasts require manual dismissal (medical safety)
- Environment variables use VITE_* prefix

### Removed
- **BREAKING:** @vue/compat compatibility layer
- **BREAKING:** global-components.js (components now imported explicitly)
- Vue CLI dependencies (@vue/cli-service, vue-cli-plugin-*)
- Webpack dependencies
- All Vue 2 mixins (migrated to composables)
- Bootstrap-Vue (replaced by Bootstrap-Vue-Next)

### Fixed
- Bundle size optimized to 520 KB gzipped (well under 2MB target)
- ESM compatibility issues with Node.js 18+
- TypeScript compilation errors

### Security
- npm audit vulnerabilities fixed
- Removed deprecated packages
- Updated axios to 1.13.2 (security fixes)

## Migration Guide

### For Developers

1. **Node.js:** Upgrade to Node 24 LTS or later
2. **Install:** Run `npm install` to update dependencies
3. **Development:** Use `npm run dev` (not `npm run serve`)
4. **Build:** Use `npm run build:production` for production builds
5. **Tests:** Run `npm run test:unit`

### Breaking Changes Details

**global-components.js removed:**
Components are no longer auto-registered globally. Import explicitly:

```vue
<!-- Before (implicit) -->
<template>
  <TablesGenes />
</template>

<!-- After (explicit) -->
<script setup lang="ts">
import TablesGenes from '@/components/tables/TablesGenes.vue';
</script>
<template>
  <TablesGenes />
</template>
```

**Bootstrap 4 to 5:**
Some class names changed. See [Bootstrap 5 Migration Guide](https://getbootstrap.com/docs/5.3/migration/).
- `ml-*` -> `ms-*` (margin-left -> margin-start)
- `mr-*` -> `me-*` (margin-right -> margin-end)
- `pl-*` -> `ps-*` (padding-left -> padding-start)
- `pr-*` -> `pe-*` (padding-right -> padding-end)

[Unreleased]: https://github.com/berntpopp/sysndd/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/berntpopp/sysndd/releases/tag/v1.0.0

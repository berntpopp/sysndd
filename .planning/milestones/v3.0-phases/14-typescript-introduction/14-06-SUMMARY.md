---
phase: 14-typescript-introduction
plan: 06
subsystem: dev-tooling
tags: [eslint, prettier, linting, typescript, code-quality]

requires:
  - 14-01 # TypeScript infrastructure
  - 14-03 # Constants conversion provides typed files to lint
  - 14-04 # Services conversion provides more TypeScript code
  - 14-05 # Router conversion provides more TypeScript code

provides:
  - ESLint 9 flat config with TypeScript support
  - Prettier 3 for code formatting
  - Integrated linting and formatting toolchain
  - Migration-ready rule configuration (warnings not errors)

affects:
  - All future TypeScript development (enforces code quality)
  - CI/CD pipelines (can add lint/format checks)
  - Pre-commit hooks (can auto-format on commit)
  - Component migration plans (14-07 onwards)

tech-stack:
  added:
    - eslint@9.39.2
    - typescript-eslint@8.53.1
    - eslint-plugin-vue@10.7.0
    - prettier@3.8.1
    - eslint-config-prettier@10.1.8
    - vue-eslint-parser@10.2.0
  removed:
    - eslint@6.8.0
    - babel-eslint@10.1.0
    - eslint-plugin-import@2.20.2
    - @vue/eslint-config-airbnb@5.0.2
    - @vue/cli-plugin-eslint@4.5.13
  patterns:
    - ESLint 9 flat config format
    - Migration strategy with warnings not errors
    - Prettier integration to avoid formatting conflicts

key-files:
  created:
    - app/eslint.config.js # ESLint 9 flat config with TypeScript and Vue
    - app/.prettierrc # Prettier configuration
    - app/.prettierignore # Prettier ignore patterns
  modified:
    - app/package.json # Updated scripts and dependencies
    - app/package-lock.json # Dependency lock file
  deleted:
    - app/.eslintrc.json # Old ESLint 6 configuration

decisions:
  - id: ESLINT9-FLAT-CONFIG
    choice: ESLint 9 flat config format
    rationale: Modern ESLint format, better TypeScript integration
    alternatives: [Keep ESLint 6 with .eslintrc]
    impact: Required for typescript-eslint 8.x compatibility

  - id: WARNINGS-NOT-ERRORS
    choice: Set TypeScript and Vue rules to 'warn' during migration
    rationale: Allow gradual improvement without blocking development
    alternatives: [Strict errors block commits]
    impact: Migration-friendly, enables incremental fixes

  - id: PRETTIER-INTEGRATION
    choice: Use eslint-config-prettier to disable conflicting rules
    rationale: Single source of formatting truth via Prettier
    alternatives: [ESLint-only formatting]
    impact: Avoids ESLint/Prettier conflicts

  - id: LEGACY-PEER-DEPS
    choice: Use --legacy-peer-deps for npm installs
    rationale: Vue CLI plugins have peer dependency conflicts
    alternatives: [Upgrade all Vue CLI plugins]
    impact: Consistent with previous Vue 3 migration decisions

duration: 171 seconds
completed: 2026-01-23
---

# Phase 14 Plan 06: ESLint and Prettier Setup Summary

**One-liner:** ESLint 9 flat config with TypeScript, Vue, and Prettier integration for modern code quality enforcement

## What Was Built

Installed and configured ESLint 9 with TypeScript support and Prettier 3 to modernize the linting infrastructure. The setup uses ESLint 9's flat config format with typescript-eslint for TypeScript rules, eslint-plugin-vue for Vue 3 support, and Prettier for consistent code formatting.

**Key capabilities:**
- TypeScript linting via typescript-eslint@8.53.1
- Vue 3 SFC linting via eslint-plugin-vue@10.7.0
- Code formatting via Prettier 3.8.1
- ESLint/Prettier integration via eslint-config-prettier
- Migration-friendly warnings instead of blocking errors

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Install ESLint 9 and TypeScript support | a9ff7f8 | package.json, package-lock.json |
| 2 | Create ESLint 9 flat config | 8d726ea | eslint.config.js, .eslintrc.json (deleted) |
| 3 | Configure Prettier and verify linting | f0eb618 | .prettierrc, .prettierignore, package.json |

## Implementation Details

### Task 1: Package Installation

**Removed old ESLint 6 stack:**
- eslint@6.8.0, babel-eslint@10.1.0
- eslint-plugin-vue@6.2.2, eslint-plugin-import@2.20.2
- @vue/eslint-config-airbnb@5.0.2
- @vue/cli-plugin-eslint@4.5.13

**Installed modern ESLint 9 stack:**
- eslint@9.39.2 (flat config support)
- typescript-eslint@8.53.1 (TypeScript linting)
- eslint-plugin-vue@10.7.0 (Vue 3 support)
- @eslint/js@9.39.2 (recommended configs)
- globals@17.1.0 (global variable definitions)

**Installed Prettier and integration:**
- prettier@3.8.1 (code formatting)
- eslint-config-prettier@10.1.8 (disables conflicting ESLint rules)

**Updated npm scripts:**
- `npm run lint` → `eslint . --ext .vue,.js,.ts,.tsx`
- `npm run lint:fix` → auto-fixes linting issues
- `npm run format` → Prettier write
- `npm run format:check` → Prettier check only

### Task 2: ESLint 9 Flat Config

Created `app/eslint.config.js` using ESLint 9's flat config format:

**Configuration layers:**
1. **Global ignores:** dist, node_modules, public, coverage, config files
2. **Base JavaScript:** @eslint/js recommended config
3. **TypeScript:** typescript-eslint recommended rules
4. **Vue 3:** eslint-plugin-vue recommended rules
5. **Prettier integration:** eslint-config-prettier to disable conflicts

**Migration strategy - rules set to 'warn':**
- `@typescript-eslint/no-explicit-any: warn` (allows gradual type strengthening)
- `@typescript-eslint/no-unused-vars: warn` (non-blocking during migration)
- `vue/multi-word-component-names: warn` (legacy components allowed)
- `vue/no-v-html: warn` (security review deferred)

**Preserved relaxed rules:**
- `no-console: off` (development debugging allowed)
- `vue/no-setup-props-destructure: off` (Composition API pattern)

**TypeScript-specific config:**
- Parser: typescript-eslint/parser
- Project reference: ./tsconfig.json
- Extra file extensions: .vue

### Task 3: Prettier Configuration

Created `.prettierrc` with Vue/TypeScript best practices:
```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100,
  "vueIndentScriptAndStyle": false,
  "endOfLine": "lf"
}
```

Created `.prettierignore` to skip generated files:
- dist/, node_modules/, public/, coverage/
- *.min.js, *.min.css

**Verification results:**
- `npm run lint` executes without fatal errors
- Shows warnings for existing code (expected for migration mode)
- `npm run format:check` identifies files needing formatting
- ESLint 9.39.2 confirmed via `npx eslint --version`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added vue-eslint-parser dependency**
- **Found during:** Task 3 - ESLint execution
- **Issue:** eslint-plugin-vue@10.7.0 requires vue-eslint-parser but doesn't list it as a direct dependency
- **Fix:** Installed vue-eslint-parser@10.2.0 via npm
- **Files modified:** package.json, package-lock.json
- **Commit:** Included in f0eb618
- **Rationale:** Required for ESLint to parse .vue files; blocks linting without it

## Technical Notes

### ESLint 9 Flat Config Format

The new flat config format (eslint.config.js) uses ES module exports instead of JSON:

**Old format (.eslintrc.json):**
```json
{
  "extends": ["plugin:vue/recommended"],
  "rules": { "no-console": "off" }
}
```

**New format (eslint.config.js):**
```javascript
export default [
  pluginVue.configs['flat/recommended'],
  { rules: { 'no-console': 'off' } }
];
```

**Benefits:**
- JavaScript configuration allows dynamic rule generation
- Better TypeScript integration via typescript-eslint
- Simplified config composition (array of config objects)
- Improved performance (native Node.js module loading)

### Migration Strategy

**Warnings vs Errors:**
- All TypeScript and Vue rules set to 'warn' during migration
- Allows incremental fixing without blocking commits
- Enables CI/CD integration without breaking builds
- Errors only for critical issues (e.g., reserved component names)

**Prettier Integration:**
- eslint-config-prettier disables all formatting-related ESLint rules
- Prettier handles all formatting concerns
- ESLint handles code quality concerns only
- Avoids "fix conflicts" between tools

### Node.js Module Warning

ESLint emits a performance warning:
```
[MODULE_TYPELESS_PACKAGE_JSON] Warning: Module type of
file:///home/bernt-popp/development/sysndd/app/eslint.config.js?mtime=...
is not specified and it doesn't parse as CommonJS.
```

**Not critical:** Warning recommends adding `"type": "module"` to package.json but this can be deferred since Vue CLI expects CommonJS format. Future plan can add module type when fully migrating to Vite-only builds.

## Testing Performed

**ESLint verification:**
```bash
cd app && npx eslint src/main.ts src/stores/ui.ts --max-warnings=100
# Result: Runs successfully with warnings, no fatal errors
```

**Prettier verification:**
```bash
cd app && npx prettier --check "src/types/*.ts"
# Result: Identifies formatting issues correctly
```

**Full lint command:**
```bash
cd app && npm run lint
# Result: Scans all .vue/.js/.ts/.tsx files, reports warnings
```

**Format check command:**
```bash
cd app && npm run format:check
# Result: Identifies all files needing formatting
```

## Success Criteria Met

- [x] ESLint 9.39.2 installed
- [x] typescript-eslint 8.53.1 installed
- [x] Prettier 3.8.1 installed
- [x] eslint.config.js created with flat config format
- [x] .prettierrc created with Vue/TypeScript settings
- [x] .prettierignore created
- [x] Old .eslintrc.json removed
- [x] npm run lint executes without fatal errors
- [x] npm run format:check executes successfully
- [x] Rules set to 'warn' for migration period

## Next Phase Readiness

**Ready for:**
- **14-07:** Component migration (linting will catch TypeScript issues)
- **14-08:** Composable migration (format enforcement available)
- **CI/CD integration:** Add `npm run lint` and `npm run format:check` to pipelines
- **Pre-commit hooks:** Can add husky + lint-staged for auto-formatting

**Blockers:** None

**Concerns:**
- Many existing warnings from legacy code (expected during migration)
- Module type warning from ESLint (cosmetic performance issue)
- Some components use reserved names (Footer) or invalid v-slot syntax

**Recommendations:**
- Incrementally fix warnings in batches (not blocking)
- Consider adding .eslintignore for particularly problematic files during migration
- Add lint/format checks to CI/CD after stabilization period
- Document exceptions for medical app patterns (e.g., manual close on error toasts)

## Architectural Impact

**Code Quality Toolchain:**
- Established modern linting infrastructure for TypeScript
- Unified code formatting via Prettier
- Foundation for automated code quality checks

**Development Workflow:**
- Developers can run `npm run lint` to check code quality
- Developers can run `npm run lint:fix` to auto-fix issues
- Developers can run `npm run format` to auto-format code
- IDE integration works with ESLint 9 flat config (VSCode, WebStorm)

**Future Integration Points:**
- CI/CD: Add lint and format checks to prevent regressions
- Pre-commit hooks: Auto-format and lint before commit
- Editor integration: Real-time linting and formatting feedback
- Component migration: Linting catches TypeScript issues during conversion

## Documentation Updates Needed

- [ ] Add linting guidelines to CONTRIBUTING.md
- [ ] Document ESLint exceptions and why they exist
- [ ] Add Prettier configuration rationale to docs
- [ ] Update CI/CD setup guide with lint/format steps

## Related Issues

- Supports #109 (Plumber refactor) by providing code quality tooling
- Foundation for future testing infrastructure
- Enables gradual TypeScript strictness increases

---

*Generated: 2026-01-23 | Duration: 171 seconds | Status: Complete*

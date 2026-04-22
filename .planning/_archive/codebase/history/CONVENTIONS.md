# Coding Conventions

**Analysis Date:** 2026-01-20

## Naming Patterns

**Files:**
- Vue components: PascalCase, single-file components (`.vue`) - e.g., `AnalyseGeneClusters.vue`, `TablePaginationControls.vue`
- JavaScript utilities and classes: camelCase or lowercase with hyphens - e.g., `tableMethodsMixin.js`, `submissionEntity.js`
- R scripts: snake_case with descriptive names - e.g., `entity_endpoints.R`, `helper-functions.R`, `admin_endpoints.R`
- Constants files: descriptive snake_case - e.g., `role_constants.js`, `url_constants.js`, `init_obj_constants.js`

**Functions:**
- JavaScript/Vue: camelCase - e.g., `handleSortByOrDescChange()`, `makeToast()`, `loadData()`
- R: snake_case - e.g., `generate_sort_expressions()`, `generate_filter_expressions()`, `nest_gene_tibble()`
- Plumber endpoints: use camelCase for handler names in R files but endpoints use `#* @get /path` format
- Private functions typically prefixed with underscore (rarely used, methods are public by default)

**Variables:**
- JavaScript/Vue: camelCase - e.g., `totalRows`, `currentPage`, `sortDesc`, `loading`
- R: snake_case - e.g., `page_size`, `filter_exprs`, `sort_exprs`, `entity_id`
- Vue component data: camelCase - e.g., `selectedCluster`, `itemsCluster`, `tableType`, `perPage`
- Boolean variables: often prefixed with `is_` or `has_` - e.g., `is_primary`, `is_active`, `loading`

**Types:**
- Vue component names: PascalCase - e.g., `SysNDD`, `AnalyseGeneClusters`, `GenericTable`
- CSS classes: kebab-case - e.g., `content-style`, `svg-container`, `stats-number`
- Bootstrap Vue components: hyphenated - e.g., `b-container`, `b-row`, `b-card`, `b-form-group`

## Code Style

**Formatting:**
- Vue: 2-space indentation (configured in Vue CLI defaults)
- JavaScript: 2-space indentation, configured via ESLint
- R: 2-space indentation (per Google R Style Guide and tidyverse conventions in `.lintr`)
- Line length limit: 100 characters for R (`line_length_linter = line_length_linter(100L)` in `api/.lintr`)

**Linting:**
- **Frontend (JavaScript/Vue):** ESLint with @vue/airbnb configuration (`app/.eslintrc.json`)
  - Extends: `plugin:vue/recommended`, `eslint:recommended`, `plugin:vue/essential`, `@vue/airbnb`
  - Notable disabled rules: `camelcase`, `max-len`, `no-param-reassign`, `no-underscore-dangle`, `no-shadow`, `no-console`

- **Backend (R):** lintr with custom `.lintr` configuration (`api/.lintr`)
  - Line length limit: 100 characters
  - Disabled linters: `object_length_linter`, `object_name_linter`, `object_usage_linter`, `unused_import_linter`, `namespace_linter`, `todo_comment_linter`, `multiple_dots_linter`
  - Exclusions: `_old`, `data/`, `logs/`, `results/`
  - Functions subdirectory has more lenient rules (`api/functions/.lintr`)

## Import Organization

**JavaScript/Vue Order:**
1. External libraries and npm packages (e.g., `import Vue from 'vue'`, `import * as d3 from 'd3'`)
2. Framework imports (e.g., `import VueMeta from 'vue-meta'`, `import { createPinia, PiniaVuePlugin } from 'pinia'`)
3. Internal custom JS (e.g., `import './assets/js/functions'`)
4. Components and utilities (e.g., `import toastMixin from '@/assets/js/mixins/toastMixin'`)
5. Styles (e.g., `import '@riophae/vue-treeselect/dist/vue-treeselect.css'`)

**Path Aliases:**
- `@/` resolves to `src/` directory in Vue application
- Used extensively: `@/assets/js/`, `@/components/`, `@/views/`, `@/assets/js/mixins/`

**R Import Pattern:**
- Uses `library()` or `require()` at script top
- No explicit module imports; functions loaded via `source()` or file mounting in Plumber
- Each endpoint file mounts to specific Plumber router at application startup

## Error Handling

**Patterns:**

**JavaScript/Vue:**
- Try-catch blocks with `makeToast()` for user notification
- Example:
  ```javascript
  try {
    // operation
  } catch (e) {
    this.makeToast(e, 'Error', 'danger');
  }
  ```
- Error messages displayed via Bootstrap Vue toast notifications with variants: `success`, `danger`, `warning`, `info`
- Console logging allowed for service worker and debug contexts (`eslint-disable no-console`)

**R:**
- `tryCatch()` with explicit error, warning, and finally handlers
- Example:
  ```r
  tryCatch({
    # operation
    list(status = "Success", message = "...")
  }, error = function(e) {
    res$status <- 500
    list(error = "...", details = e$message)
  }, finally = {
    dbDisconnect(sysndd_db)
  })
  ```
- Database transactions use `dbBegin()`, `dbCommit()`, `dbRollback()` pattern
- HTTP status codes set on `res` object (e.g., `res$status <- 500`)

## Logging

**Framework:** No centralized logging framework; uses:
- R: `library(logger)` available but minimal usage observed
- JavaScript: `console.log()`, `console.error()` primarily in service worker registration
- Service worker logs: debug messages for caching status updates

**Patterns:**
- Conditional logging in development contexts
- Service worker registration logs cache lifecycle: registration, content caching, new content available
- R functions may include `cat()` for console output in test/development scripts
- No structured logging with timestamps or log levels observed in main code

## Comments

**When to Comment:**
- File headers: Document file purpose and location - e.g., `# api/endpoints/entity_endpoints.R`
- Section dividers: Visual separation with `## ---...---##` for major sections
- Complex logic: Explain non-obvious calculations or transformations
- Roxygen documentation: Comprehensive for exported R functions (using `#'`)

**JSDoc/TSDoc:**
- Heavy use in Vue components for method documentation
- Example:
  ```javascript
  /**
   * Handles changes in sorting order or direction.
   * @description Detailed explanation
   * @param {type} name - Parameter description
   * @returns {type} Return value description
   */
  ```
- File overviews: `@fileoverview` comment block at top of utility files
- Used in mixins and utility modules for parameter documentation
- R functions use Roxygen2 format with `@param`, `@return`, `@examples`, `@export` tags

**Header Comments:**
- R files start with comment block showing file purpose and location
- Vue files sometimes include `<!-- comment -->` showing file path
- JavaScript files include `@fileoverview` JSDoc blocks

## Function Design

**Size:**
- Vue methods: Typically 10-50 lines, using composition with computed properties and mixins for reusability
- R endpoint functions: 30-100+ lines as they contain database queries and data transformation
- Helper functions in R: 20-80 lines, focused on specific transformations

**Parameters:**
- JavaScript: Use destructuring for objects with multiple parameters
- R: Named parameters with defaults - e.g., `function(sort = "entity_id", filter = "", fields = "")`
- Vue: Methods receive implicit `this` context; computed properties return reactive values
- Plumber endpoints: Receive `req`, `res`, and query parameters

**Return Values:**
- JavaScript: Implicit returns in arrow functions; methods often return `undefined` or trigger side effects
- Vue: Computed properties MUST return values; methods may return nothing (trigger UI updates)
- R: Explicit `return()` statements with structured lists for API responses
- API responses use consistent structure: `list(status="...", data=..., meta=..., links=...)`

## Module Design

**Exports:**

**JavaScript/ES Modules:**
- Single default export per file for components, utilities, mixins
- Example: `export default { methods: {...}, data() {...} }`
- Class exports: `export default class Entity { ... }`

**R:**
- Roxygen2 `@export` tag indicates exported functions
- Functions without `@export` are private/internal
- Plumber endpoints directly accessible via HTTP (no explicit export)

**Barrel Files:**
- Vue components imported individually: `import GenericTable from '@/components/small/GenericTable.vue'`
- No centralized barrel/index files observed
- Constants files export default objects with organized sub-keys
- Example: `export default { ALLOWED_ROLES: [...], ALLOWENCE_NAVIGATION: [...] }`

**Mixin Pattern:**
- Heavy use of Vue mixins for shared functionality across components
- Located in `src/assets/js/mixins/` with descriptive names
- Mixins provide: `methods`, `computed`, `data()` functions
- Examples: `toastMixin.js`, `tableMethodsMixin.js`, `colorAndSymbolsMixin.js`, `urlParsingMixin.js`
- Components mix in multiple mixins: `mixins: [toastMixin, colorAndSymbolsMixin]`

**Component Structure (Vue Single File):**
```vue
<template>
  <!-- Template code -->
</template>

<script>
import { Components, Mixins }
export default {
  name: 'ComponentName',
  components: { Child1, Child2 },
  mixins: [mixin1, mixin2],
  data() { return {...} },
  computed: {...},
  watch: {...},
  created() {...},
  methods: {...},
}
</script>

<style lang="scss" scoped>
  /* Scoped styles */
</style>
```

---

*Convention analysis: 2026-01-20*

# Code Quality Report - 2026-01-30

## Executive Summary

A systematic code quality audit was performed on the SysNDD repository, running typecheck, lint, and format checks for both frontend (Vue/TypeScript) and API (R/Plumber) components.

### Final Status (After Remediation)

| Component | Check | Before | After |
|-----------|-------|--------|-------|
| Frontend | TypeScript Type-Check | ✅ Pass | ✅ Pass |
| Frontend | ESLint Lint | ⚠️ 1 warning + 4 errors | ✅ Pass |
| Frontend | Prettier Format | ❌ 196 files | ✅ Pass |
| API | R Lintr | ❌ 46 issues | ⚠️ 50 issues (stylistic) |

**Frontend: ALL CHECKS PASSING ✅**

**API: 50 remaining stylistic issues** (indentation differences between styler/lintr, pipe operator preference, line length)

---

## Changes Made

### Frontend Fixes

#### 1. Prettier Formatting (191 files formatted)
```bash
npm run format
```
- **191 files** automatically formatted
- All formatting issues resolved

#### 2. ESLint Module Warning Fix
**File:** `app/package.json`

Added `"type": "module"` to resolve `MODULE_TYPELESS_PACKAGE_JSON` warning.

#### 3. Vue Filter False Positives Fix
**Files:**
- `src/views/admin/ManageAnnotations.vue`
- `src/views/admin/ManageBackups.vue`

**Issue:** ESLint's `vue/no-deprecated-filter` rule incorrectly flagged TypeScript union type syntax (`'primary' | 'success' | 'danger'`) as deprecated Vue filters.

**Solution:** Updated `src/composables/useAsyncJob.ts` to properly type `progressVariant` as `ProgressVariant` type instead of `string`, eliminating the need for inline type assertions in templates.

```typescript
// Added new type
export type ProgressVariant = 'primary' | 'success' | 'danger';

// Updated interface
progressVariant: ComputedRef<ProgressVariant>;

// Updated computed
const progressVariant = computed<ProgressVariant>(() => { ... });
```

### API Fixes

#### 4. R Code Styling (22 files styled)
```bash
source ~/miniforge3/etc/profile.d/conda.sh
conda activate sysndd-dev
RENV_ACTIVATE_PROJECT=FALSE Rscript -e "styler::style_file(...)"
```
- **22 files** automatically styled
- Reduced many indentation issues

#### Remaining API Issues (50 total)

These are **stylistic differences** between `styler` and `lintr` defaults:

| Issue Type | Count | Resolution |
|------------|-------|------------|
| Indentation (styler vs lintr style) | ~25 | Configure `.lintr` or accept |
| Pipe operator (`\|>` vs `%>%`) | 17 | Configure `.lintr` if using native pipe |
| Line length >120 chars | 6 | Manual line breaking |
| Quote style (single vs double) | 2 | Manual or styler config |

**Recommendation:** Consider updating `api/.lintr` to align with modern R practices (native pipe) or accept minor stylistic differences.

---

## Verification Commands

### Frontend (All Passing ✅)
```bash
cd app
npm run type-check    # ✅ Pass
npm run lint          # ✅ Pass
npm run format:check  # ✅ Pass
```

### API
```bash
source ~/miniforge3/etc/profile.d/conda.sh
conda activate sysndd-dev
cd /path/to/sysndd
RENV_ACTIVATE_PROJECT=FALSE make lint-api  # ⚠️ 50 stylistic issues
```

---

## Conda Environment Setup

A conda environment `sysndd-dev` was created with R and linting tools:

```bash
# Create environment
source ~/miniforge3/etc/profile.d/conda.sh
conda create -n sysndd-dev r-base r-lintr r-styler r-testthat -c conda-forge -y

# Activate
conda activate sysndd-dev

# Run API lint (bypassing renv)
RENV_ACTIVATE_PROJECT=FALSE Rscript scripts/lint-check.R
```

---

## Files Modified

### Frontend
| File | Change |
|------|--------|
| `app/package.json` | Added `"type": "module"` |
| `app/src/composables/useAsyncJob.ts` | Added `ProgressVariant` type |
| `app/src/views/admin/ManageAnnotations.vue` | Removed inline type assertions |
| `app/src/views/admin/ManageBackups.vue` | Removed inline type assertions |
| **191 files** | Prettier formatting |

### API
| Files | Change |
|-------|--------|
| **22 R files** | styler formatting |

---

## Remaining Work (Optional)

### Option A: Accept Current State
The API has 50 stylistic issues that don't affect functionality. These can be accepted as-is.

### Option B: Configure .lintr
Update `api/.lintr` to match project preferences:

```yaml
linters: linters_with_defaults(
  line_length_linter(120),
  indentation_linter = NULL,  # Disable if using different style
  pipe_call_linter = NULL     # Allow native pipe |>
)
```

### Option C: Manual Fixes
Fix remaining issues manually:
1. Break long lines (>120 chars) - 6 occurrences
2. Standardize pipe operator choice
3. Adjust indentation in specific files

---

## Summary

| Metric | Before | After |
|--------|--------|-------|
| Frontend type errors | 0 | 0 |
| Frontend ESLint errors | 4 | 0 |
| Frontend ESLint warnings | 1 | 0 |
| Frontend Prettier issues | 196 files | 0 |
| API lint issues | 46 | 50* |

*API issues increased slightly due to styler introducing different indentation style than lintr expects. These are purely stylistic.

**Overall: Frontend is production-ready. API has minor stylistic issues only.**

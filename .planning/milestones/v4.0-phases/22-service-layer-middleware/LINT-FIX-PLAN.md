# Lint Fix Plan: SysNDD API

## Overview

**Total Issues:** 3,448 across 4 directories
**Strategy:** Parallel agent execution grouped by similar problem types

## Issue Breakdown

| Linter | Count | Priority | Strategy |
|--------|-------|----------|----------|
| `pipe_consistency_linter` | 1,770 | High | **Configure** - Keep `%>%` (see rationale) |
| `line_length_linter` | 622 | Medium | **Configure** to 120 chars + manual fixes |
| `indentation_linter` | 421 | Medium | **Auto-fix** with styler |
| `return_linter` | 165 | Low | **Configure** - Allow explicit returns |
| `object_usage_linter` | 130 | High | **Fix** - Add globalVariables() |
| `trailing_whitespace_linter` | 92 | Low | **Auto-fix** with styler |
| `commented_code_linter` | 67 | Medium | **Manual review** - Some are intentional |
| Minor issues | 66 | Low | **Auto-fix** with styler |

## Strategic Decisions

### 1. Pipe Consistency (1,770 issues) - CONFIGURE

**Decision:** Keep magrittr `%>%` pipe, configure lintr to accept it.

**Rationale:**
- Codebase uses `%>%` consistently throughout
- Magrittr pipe has features native pipe lacks (`%<>%`, `%$%`, `%T>%`)
- Mass replacement risks introducing bugs (native `|>` has subtle differences)
- R 4.1+ required for native pipe, reduces compatibility
- [Tidyverse changed default](https://lintr.r-lib.org/news/) but magrittr is still valid

**Action:** Add to `.lintr`:
```r
pipe_consistency_linter = pipe_consistency_linter(pipe = "%>%")
```

### 2. Line Length (622 issues) - CONFIGURE + PARTIAL FIX

**Decision:** Increase limit to 120 characters, fix remaining manually.

**Rationale:**
- 80 chars is [historical "Hollerith limit"](https://lintr.r-lib.org/reference/line_length_linter.html)
- Modern screens easily display 120 chars
- Many lines are URLs, SQL queries, or long function signatures
- [Google R Style Guide](http://adv-r.had.co.nz/Style.html) suggests 80, but pragmatism wins

**Action:** Add to `.lintr`:
```r
line_length_linter = line_length_linter(120L)
```

### 3. Return Linter (165 issues) - CONFIGURE

**Decision:** Allow explicit returns (Google style) rather than enforce implicit (Tidyverse style).

**Rationale:**
- [Tidyverse prefers implicit](https://lintr.r-lib.org/reference/return_linter.html), [Google prefers explicit](https://forum.posit.co/t/r-style-guide-explicit-return-or-not/40025)
- Explicit returns improve readability for complex functions
- Early returns already require `return()` anyway
- Consistency matters more than convention

**Action:** Add to `.lintr`:
```r
return_linter = NULL
```

### 4. Object Usage (130 issues) - FIX

**Decision:** Fix properly using `utils::globalVariables()` and `.data` pronoun.

**Rationale:**
- These are [legitimate warnings about NSE](https://www.r-bloggers.com/2019/08/no-visible-binding-for-global-variable/)
- Suppressing masks real bugs
- Proper fix improves R CMD check compliance

**Fix approach:**
1. Create `R/globals.R` with `utils::globalVariables()` for dplyr columns
2. Use `rlang::.data$column` for explicit column references where appropriate

## Plumber Compatibility

**Important:** The codebase uses [Plumber API annotations](https://www.rplumber.io/articles/annotations.html) (`#*` comments) for endpoint documentation.

**Styler Safety:** The [styler package recognizes Plumber DSL](https://styler.r-lib.org/articles/styler.html) and preserves `#*` annotations automatically. No special configuration needed.

**Verification:** After each wave, run API health check:
```bash
curl -s http://localhost:7778/health/ | jq '.status'
# Expected: "healthy"
```

## Execution Plan

### Wave 1: Configuration (Immediate - eliminates 2,557 issues)

**Single agent task:** Create `.lintr` configuration file

```yaml
linters: linters_with_defaults(
  pipe_consistency_linter = pipe_consistency_linter(pipe = "%>%"),
  line_length_linter = line_length_linter(120L),
  return_linter = NULL,
  object_name_linter = NULL,  # Allow SCREAMING_SNAKE_CASE for constants
  commented_code_linter = NULL  # Too many false positives
)
```

**Expected reduction:** 1,770 + 165 + 67 + 2 = **2,004 issues eliminated**

### Wave 2: Auto-fix with styler (Parallel - 4 agents)

Use `styler::style_dir()` to auto-fix:
- Indentation (421)
- Trailing whitespace (92)
- Infix spaces (26)
- Trailing blank lines (5)
- Brace issues (3)
- Comma spacing (3)

**Agent 1:** `api/endpoints/` (largest directory)
**Agent 2:** `api/functions/` (largest directory)
**Agent 3:** `api/core/`
**Agent 4:** `api/services/`

**Expected reduction:** ~550 issues

### Wave 3: Object Usage Fixes (Parallel - 2 agents)

**Agent 1:** Create `api/globals.R` with all NSE variables
- Extract all dplyr column references
- Add `utils::globalVariables(c("column1", "column2", ...))`

**Agent 2:** Fix function-level issues
- Add `# nolint: object_usage_linter.` for false positives
- Fix actual undefined variable bugs

**Expected reduction:** 130 issues

### Wave 4: Line Length Manual Fixes (Parallel - 4 agents)

After 120-char config, remaining long lines need manual breaking.

**Agent 1:** `api/endpoints/` - Break function signatures, SQL queries
**Agent 2:** `api/functions/` - Break function signatures, SQL queries
**Agent 3:** `api/core/` - Break long strings
**Agent 4:** `api/services/` - Break long strings

**Expected reduction:** Remaining ~100 lines over 120 chars

### Wave 5: Verification

Single agent to:
1. Run full lint check
2. Verify issue count < 50
3. Run test suite to ensure no regressions
4. Commit all changes

## File Changes Summary

| File | Action |
|------|--------|
| `api/.lintr` | CREATE - Configuration |
| `api/globals.R` | CREATE - Global variables |
| `api/endpoints/*.R` | MODIFY - Styling + line breaks |
| `api/functions/*.R` | MODIFY - Styling + line breaks |
| `api/core/*.R` | MODIFY - Styling + line breaks |
| `api/services/*.R` | MODIFY - Styling + line breaks |

## Success Criteria

- [ ] Lint issues reduced from 3,448 to < 50
- [ ] All tests still pass
- [ ] No functional changes to API behavior
- [ ] Consistent code style across codebase

## Sources

- [lintr Pipe Consistency Linter](https://lintr.r-lib.org/reference/pipe_consistency_linter.html)
- [lintr Line Length Linter](https://lintr.r-lib.org/reference/line_length_linter.html)
- [lintr Return Linter](https://lintr.r-lib.org/reference/return_linter.html)
- [Tidyverse Style Guide](http://adv-r.had.co.nz/Style.html)
- [No Visible Binding Fix](https://www.r-bloggers.com/2019/08/no-visible-binding-for-global-variable/)
- [Using lintr](https://cran.r-project.org/web/packages/lintr/vignettes/lintr.html)
- [lintr Changelog](https://lintr.r-lib.org/news/)

# Phase 4: Makefile Automation - Research

**Researched:** 2026-01-21
**Domain:** GNU Make automation for polyglot R/Node.js project
**Confidence:** HIGH

## Summary

Makefile automation for polyglot projects (R + Node.js) follows well-established patterns with GNU Make serving as a universal task runner. The key approach is wrapping language-specific toolchains (renv, npm, Rscript) behind consistent `make <target>` commands. This research covers modern Makefile best practices including self-documenting help targets, prerequisite checking, error handling, and ANSI color output for status reporting.

**Primary recommendation:** Use the Davis-Hansson "Your Makefiles are wrong" preamble as the foundation, implement self-documenting help targets with awk-based parsing, check prerequisites before execution, and provide colorized status messages with explicit success/failure indicators.

The standard approach for polyglot projects is one Makefile at the repository root with flat hyphenated target names (test-api, lint-app, install-api) that wrap language-specific commands. Fail-fast is the default Make behavior; users run `make -k` when they want to see all failures.

**Key insight:** Modern Makefiles benefit significantly from bash strict mode (`.SHELLFLAGS := -eu -o pipefail -c`), `.DELETE_ON_ERROR` for cleanup, and `.ONESHELL` for multi-line recipes, combined with `MAKEFLAGS` to warn on undefined variables and disable built-in rules.

## Standard Stack

The established tools for Makefile automation in polyglot projects:

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| GNU Make | 4.0+ | Build automation and task runner | Universal, no dependencies, works on all Unix-like systems |
| Bash | 4.0+ | Shell for recipe execution | Portable, powerful, ubiquitous on Linux/Mac/WSL2 |
| grep/awk/sed | Standard Unix | Text processing for help target | Built-in utilities, no additional dependencies |

### Supporting
| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| command -v | Built-in | Tool detection | Prerequisite checks (more portable than which) |
| docker info | Docker CLI | Docker daemon detection | Before docker-compose operations |
| tput colors | ncurses | Terminal capability detection | Fallback when ANSI codes don't work |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Make | Taskfile (task) | Task requires Go installation, not as universal |
| Make | npm scripts | Only works for Node.js projects, not polyglot |
| Make | just | Requires Rust installation, newer/less established |

**Installation:**
```bash
# Already installed on Linux/Mac/WSL2
# Verify availability
command -v make
command -v bash
```

## Architecture Patterns

### Recommended Project Structure
```
.
├── Makefile                    # Root-level automation
├── .env.example               # Environment variable template
├── api/
│   ├── scripts/
│   │   ├── lint-check.R      # Wrapped by make lint-api
│   │   ├── style-code.R      # Wrapped by make format-api
│   │   └── pre-commit-check.R
│   └── tests/
│       └── testthat/         # Wrapped by make test-api
├── app/
│   ├── package.json          # npm scripts wrapped by make
│   └── src/
└── docker-compose.dev.yml    # Wrapped by make dev
```

### Pattern 1: Self-Documenting Help Target
**What:** Parse `##` comments next to targets to generate help output
**When to use:** Every Makefile (makes targets discoverable)
**Example:**
```makefile
# Source: https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
```

**Explanation:**
- `grep -E` finds targets with `##` comments
- `sort` alphabetizes (remove for file order)
- `awk` splits on `:.*?##` and formats with printf
- `\033[36m` is cyan color code, `\033[0m` resets
- `%-30s` left-aligns target name in 30-char column

### Pattern 2: Prerequisite Checking with command -v
**What:** Verify required tools exist before executing recipes
**When to use:** Targets that depend on external tools (R, npm, docker)
**Example:**
```makefile
# Source: https://how.wtf/check-if-a-program-exists-from-a-makefile.html
REQUIRED_BINS := R npm docker
$(foreach bin,$(REQUIRED_BINS),\
    $(if $(shell command -v $(bin) 2> /dev/null),,$(error Please install `$(bin)`)))
```

**Alternative per-target approach:**
```makefile
.PHONY: install-api
install-api: ## Install R dependencies with renv
	@command -v R > /dev/null || (echo "ERROR: R is not installed. Install from https://www.r-project.org/" && exit 1)
	@cd api && R -e "renv::restore()"
```

**Why command -v over which:**
- More portable (POSIX compliant)
- Works with shell built-ins
- Doesn't print anything if command doesn't exist

### Pattern 3: Davis-Hansson Preamble (Best Practices)
**What:** Comprehensive Makefile configuration for safe, predictable execution
**When to use:** Every new Makefile
**Example:**
```makefile
# Source: https://tech.davis-hansson.com/p/make/
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
```

**Explanation:**
- `SHELL := bash` - Explicit shell (don't rely on system default)
- `.ONESHELL:` - Run entire recipe in single shell (allows multi-line bash)
- `.SHELLFLAGS := -eu -o pipefail -c` - Bash strict mode (exit on error, undefined vars, pipe failures)
- `.DELETE_ON_ERROR:` - Remove target file if recipe fails (prevents stale artifacts)
- `--warn-undefined-variables` - Catch `$(TYPO)` mistakes
- `--no-builtin-rules` - Disable implicit rules (performance + predictability)

### Pattern 4: Colorized Status Messages
**What:** ANSI escape codes for colored terminal output
**When to use:** Status messages, step announcements, success/failure indicators
**Example:**
```makefile
# Source: https://eli.thegreenplace.net/2013/12/18/makefile-functions-and-color-output
# ANSI color codes
GREEN := \033[0;32m
RED := \033[0;31m
CYAN := \033[0;36m
YELLOW := \033[0;33m
RESET := \033[0m

.PHONY: test-api
test-api: ## Run R API tests
	@echo "$(CYAN)==> Running API tests...$(RESET)"
	@cd api && Rscript -e "testthat::test_dir('tests/testthat')" && \
		echo "$(GREEN)✓ test-api complete$(RESET)" || \
		(echo "$(RED)✗ test-api failed$(RESET)" && exit 1)
```

**Standard ANSI codes:**
- `\033[0;31m` - Red (errors)
- `\033[0;32m` - Green (success)
- `\033[0;33m` - Yellow (warnings)
- `\033[0;36m` - Cyan (info/target names)
- `\033[0m` - Reset to default

### Pattern 5: Docker Health Checking
**What:** Verify Docker daemon is running and containers are healthy
**When to use:** Before docker-compose operations
**Example:**
```makefile
# Source: https://www.strangebuzz.com/en/snippets/testing-if-a-docker-container-is-healthy-in-a-makefile
.PHONY: check-docker
check-docker:
	@docker info > /dev/null 2>&1 || (echo "$(RED)ERROR: Docker is not running.$(RESET)" && \
		echo "Start Docker Desktop and try again." && exit 1)

.PHONY: dev
dev: check-docker ## Start development database containers
	@echo "$(CYAN)==> Starting development databases...$(RESET)"
	@docker compose -f docker-compose.dev.yml up -d
	@echo "$(GREEN)✓ dev complete$(RESET)"
```

### Pattern 6: PHONY Target Declaration
**What:** Mark non-file-producing targets as .PHONY
**When to use:** All targets that don't create files (almost all automation targets)
**Example:**
```makefile
# Source: https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
.PHONY: help install install-api install-app dev test test-api test-app lint lint-api lint-app format format-api format-app pre-commit clean

# Benefits:
# 1. Prevents conflicts if a file named "test" exists
# 2. Performance improvement (skips implicit rule search)
# 3. Explicit intent - this is a command, not a file
```

### Pattern 7: Flat Hyphenated Target Names
**What:** Use action-component naming (test-api, lint-app, install-api)
**When to use:** Polyglot projects with multiple components
**Example:**
```makefile
# Source: https://docs.cloudposse.com/best-practices/developer/makefile/
.PHONY: install-api install-app lint-api lint-app test-api test-app

install-api: ## Install R dependencies with renv::restore()
	@cd api && R -e "renv::restore()"

install-app: ## Install frontend dependencies with npm install
	@cd app && npm install

# Don't create combined shortcuts:
# lint: lint-api lint-app  # NO - requires explicit component
```

**Rationale:**
- Clear what's being operated on
- No ambiguity in polyglot projects
- Forces conscious choice of scope
- GNU Make compatible (no special characters)

### Anti-Patterns to Avoid

- **Tabs vs Spaces:** GNU Make REQUIRES tabs before recipe commands. Using spaces causes "missing separator" errors. (Note: Can use `.RECIPEPREFIX = >` to change delimiter, but adds complexity)

- **Combined shortcuts:** Don't create `test: test-api test-app` - requires explicit component selection per project requirements

- **Silent failures with -:** Don't prefix commands with `-` to ignore errors unless truly optional (e.g., `clean` target removing non-existent files)

- **Undefined variables:** `$(VARNAME)` expands to empty string if undefined. Use `$(MAKEFLAGS) += --warn-undefined-variables` to catch

- **Not using .PHONY:** Forgetting `.PHONY` causes conflicts if files with same name exist (e.g., file named "test" breaks `make test`)

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Self-documenting help | Custom grep/awk script variations | Standard awk pattern: `awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'` | Battle-tested, handles edge cases, consistent |
| Command detection | `which` command | `command -v` with `2> /dev/null` | More portable (POSIX), handles built-ins, safer |
| Multi-line bash scripts | Multiple recipe lines | `.ONESHELL:` special target | Allows proper bash scripting with loops, conditionals |
| Error cleanup | Manual `rm` after failures | `.DELETE_ON_ERROR:` special target | Automatic, can't forget, prevents stale artifacts |
| Color output wrappers | Wrapper scripts | ANSI escape codes directly in Makefile | No dependencies, portable, simple |
| Docker health checks | Sleep timers | `docker inspect --format "{{.State.Health.Status}}"` | Reliable, fast, deterministic |

**Key insight:** GNU Make has decades of collective wisdom. Don't reinvent - use established patterns like Davis-Hansson preamble, standard self-documenting help, and ANSI color codes.

## Common Pitfalls

### Pitfall 1: Tab vs Space in Recipes
**What goes wrong:** Recipe commands must be prefixed with TAB character, not spaces. Using spaces causes "Makefile:X: *** missing separator. Stop."
**Why it happens:** Historical GNU Make design decision - recipes are tab-delimited
**How to avoid:**
- Configure editor to preserve tabs in Makefiles
- Use `.editorconfig` with `[Makefile] indent_style = tab`
- Alternative: Use `.RECIPEPREFIX = >` to change delimiter (requires Make 4.0+)
**Warning signs:** "missing separator" error on recipe lines

### Pitfall 2: Command Not Found with $(shell command -v)
**What goes wrong:** `$(shell command -v nvcc)` can fail with "command: Command not found" in some shells
**Why it happens:** `command` is a shell built-in, not universally available in all shell contexts
**How to avoid:**
```makefile
# Redirect stderr to /dev/null to suppress errors
NVCC := $(shell command -v nvcc 2> /dev/null)
```
**Warning signs:** Build fails with "command: Command not found" even though Make is working

### Pitfall 3: Docker Not Running Silent Failure
**What goes wrong:** Docker commands hang or fail cryptically if daemon isn't running
**Why it happens:** Docker CLI doesn't always provide clear error messages
**How to avoid:**
```makefile
check-docker:
	@docker info > /dev/null 2>&1 || \
		(echo "ERROR: Docker is not running. Start Docker Desktop and try again." && exit 1)

# Use as prerequisite
dev: check-docker
	@docker compose -f docker-compose.dev.yml up -d
```
**Warning signs:** `docker compose` commands hang indefinitely

### Pitfall 4: SHELL Variable Not Exported to Recipes
**What goes wrong:** Setting `SHELL=/bin/bash` in Makefile doesn't export to environment for recipe commands
**Why it happens:** GNU Make explicitly doesn't export SHELL variable (by design)
**How to avoid:** This is actually correct behavior - `SHELL` controls which shell runs recipes, not what $SHELL is inside recipes. If you need bash specifically for a recipe, use shebang or explicit bash command.
**Warning signs:** Scripts fail because they expect bash but get sh

### Pitfall 5: Forgetting .PHONY for Command Targets
**What goes wrong:** If file named "test" exists, `make test` won't run because Make thinks target is up-to-date
**Why it happens:** Make is file-based by default - checks if target file needs rebuilding
**How to avoid:**
```makefile
.PHONY: test test-api test-app install dev lint clean

# Declare all non-file-producing targets as .PHONY
```
**Warning signs:** Target stops running after file with same name is created

### Pitfall 6: Multi-line Bash Scripts Without .ONESHELL
**What goes wrong:** Each line runs in separate shell, so variables and cd don't persist
```makefile
# BROKEN - cd has no effect on next line
test-api:
	cd api
	R -e "testthat::test_dir('tests/testthat')"
```
**Why it happens:** Default Make behavior - new shell per line
**How to avoid:**
```makefile
# Option 1: Use .ONESHELL (recommended)
.ONESHELL:
test-api:
	cd api
	R -e "testthat::test_dir('tests/testthat')"

# Option 2: Chain with && (works without .ONESHELL)
test-api:
	cd api && R -e "testthat::test_dir('tests/testthat')"
```
**Warning signs:** Commands fail because working directory or variables aren't what you expect

### Pitfall 7: renv::restore() Interactive Prompts
**What goes wrong:** `renv::restore()` may prompt for user input in CI/CD or automated contexts
**Why it happens:** renv asks to confirm package installation by default
**How to avoid:**
```makefile
install-api:
	@cd api && R -e "renv::restore(prompt = FALSE)"
```
**Warning signs:** Make hangs waiting for input that never comes

### Pitfall 8: Incorrect ANSI Color Code Syntax
**What goes wrong:** Color codes don't work or appear as literal text
**Why it happens:** Wrong escape sequence or missing reset
**How to avoid:**
```makefile
# Use \033 (octal) or \e or \x1b
GREEN := \033[0;32m
RESET := \033[0m

# Always reset after colored text
@echo "$(GREEN)Success$(RESET)"

# Not: echo "\033[0;32mSuccess\033[0m" (double escaping)
```
**Warning signs:** Seeing literal `\033[0;32m` in output instead of colors

## Code Examples

Verified patterns from official sources:

### Complete Minimal Makefile for Polyglot Project
```makefile
# Source: Synthesized from https://tech.davis-hansson.com/p/make/ and
#         https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# ANSI color codes
GREEN := \033[0;32m
RED := \033[0;31m
CYAN := \033[0;36m
RESET := \033[0m

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'

.PHONY: install-api
install-api: ## Install R dependencies with renv::restore()
	@echo "$(CYAN)==> Installing R dependencies...$(RESET)"
	@command -v R > /dev/null || (echo "$(RED)ERROR: R not installed$(RESET)" && exit 1)
	@cd api && R -e "renv::restore(prompt = FALSE)"
	@echo "$(GREEN)✓ install-api complete$(RESET)"

.PHONY: install-app
install-app: ## Install frontend dependencies with npm install
	@echo "$(CYAN)==> Installing frontend dependencies...$(RESET)"
	@command -v npm > /dev/null || (echo "$(RED)ERROR: npm not installed$(RESET)" && exit 1)
	@cd app && npm install
	@echo "$(GREEN)✓ install-app complete$(RESET)"

.PHONY: test-api
test-api: ## Run R API tests
	@echo "$(CYAN)==> Running API tests...$(RESET)"
	@cd api && Rscript -e "testthat::test_dir('tests/testthat')" && \
		echo "$(GREEN)✓ test-api complete$(RESET)" || \
		(echo "$(RED)✗ test-api failed$(RESET)" && exit 1)

.PHONY: lint-api
lint-api: ## Check R code with lintr
	@echo "$(CYAN)==> Linting R code...$(RESET)"
	@cd api && Rscript scripts/lint-check.R && \
		echo "$(GREEN)✓ lint-api complete$(RESET)" || \
		(echo "$(RED)✗ lint-api failed$(RESET)" && exit 1)

.PHONY: check-docker
check-docker:
	@docker info > /dev/null 2>&1 || (echo "$(RED)ERROR: Docker not running$(RESET)" && exit 1)

.PHONY: dev
dev: check-docker ## Start development database containers
	@echo "$(CYAN)==> Starting development databases...$(RESET)"
	@docker compose -f docker-compose.dev.yml up -d
	@echo "$(GREEN)✓ Databases started on ports 7654 (dev) and 7655 (test)$(RESET)"
	@echo "$(CYAN)Start API: cd api && Rscript start_sysndd_api.R$(RESET)"
	@echo "$(CYAN)Start frontend: cd app && npm run serve$(RESET)"
```

### Prerequisite Checking with Informative Errors
```makefile
# Source: https://how.wtf/check-if-a-program-exists-from-a-makefile.html
.PHONY: install-api
install-api:
	@command -v R > /dev/null 2>&1 || \
		(echo "$(RED)ERROR: R is not installed$(RESET)" && \
		 echo "Install R: https://www.r-project.org/" && \
		 exit 1)
	@command -v Rscript > /dev/null 2>&1 || \
		(echo "$(RED)ERROR: Rscript not found$(RESET)" && \
		 exit 1)
	@cd api && R -e "renv::restore(prompt = FALSE)"
```

### Grouped Help Output by Section
```makefile
# Source: Modified from https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
.PHONY: help
help:
	@echo "SysNDD Development Commands"
	@echo ""
	@echo "Development:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(install|dev|api|frontend):' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "Testing:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^test' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "Linting:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^(lint|format)' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
	@echo ""
	@echo "Docker:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | grep -E '^docker' | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(CYAN)%-20s$(RESET) %s\n", $$1, $$2}'
```

### Pre-commit Target Chaining
```makefile
# Source: Project requirements
.PHONY: pre-commit
pre-commit: ## Run all quality checks before committing
	@echo "$(CYAN)==> Running pre-commit checks...$(RESET)"
	@$(MAKE) lint-api
	@$(MAKE) lint-app
	@$(MAKE) test-api
	@echo "$(GREEN)✓ All pre-commit checks passed$(RESET)"
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Tabs required | `.RECIPEPREFIX = >` to use `>` instead | GNU Make 4.0 (2013) | Optional - adds complexity, rarely used |
| Individual targets | Grouped targets with `&:` | GNU Make 4.3 (2020) | Useful for multi-output rules (not needed for this project) |
| Manual help target | Self-documenting with `##` comments | ~2016 (marmelab blog) | Industry standard now |
| Simple SHELL setting | Davis-Hansson preamble with strict mode | 2019 | Best practice for new Makefiles |
| Taskfile, Just | Make remains dominant | Ongoing | Make still most portable despite alternatives |

**Deprecated/outdated:**
- `.SUFFIXES:` - rarely needed with modern Make and `.PHONY` usage
- `which` command - replaced by `command -v` for portability
- Implicit rules - disable with `--no-builtin-rules` for predictability
- Platform-specific Make variants (pmake, bmake) - GNU Make 4.0+ is universal

## Open Questions

Things that couldn't be fully resolved:

1. **private keyword for SHELL variable**
   - What we know: GNU Make supports `private` keyword for target-specific variables to prevent export
   - What's unclear: The project requirements mention using `private` keyword for SHELL variable, but SHELL is already non-exported by Make's design. The use case for `private SHELL :=` is unclear.
   - Recommendation: Use standard `SHELL := bash` - it already doesn't export. Only use `private` if there's a specific export prevention need in target-specific contexts.

2. **Test target scope without test infrastructure**
   - What we know: Phase depends on Phase 2 (test infrastructure) which may not be complete
   - What's unclear: Exact test command structure until Phase 2 is done
   - Recommendation: Plan test-api target with placeholder `Rscript -e "testthat::test_dir('tests/testthat')"` - adjust when Phase 2 completes

3. **app test command**
   - What we know: Frontend has `npm run lint` but test command not found in package.json
   - What's unclear: Does frontend have unit tests? What's the test command?
   - Recommendation: Verify package.json scripts; if no tests exist, document test-app as "not yet implemented"

## Sources

### Primary (HIGH confidence)
- [GNU Make Manual - Errors](https://www.gnu.org/software/make/manual/html_node/Errors.html) - Error handling patterns
- [GNU Make Manual - Choosing the Shell](https://www.gnu.org/software/make/manual/html_node/Choosing-the-Shell.html) - SHELL variable behavior
- [Auto-documented Makefile (Marmelab)](https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html) - Self-documenting help pattern
- [Your Makefiles are wrong (Davis-Hansson)](https://tech.davis-hansson.com/p/make/) - Comprehensive best practices preamble
- [GNU Make Manual - Phony Targets](https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html) - .PHONY usage
- [GNU Make Manual - Special Targets](https://www.gnu.org/software/make/manual/html_node/Special-Targets.html) - .DELETE_ON_ERROR, .ONESHELL

### Secondary (MEDIUM confidence)
- [Check if a program exists from a Makefile](https://how.wtf/check-if-a-program-exists-from-a-makefile.html) - Command detection patterns
- [Testing if Docker container is healthy](https://www.strangebuzz.com/en/snippets/testing-if-a-docker-container-is-healthy-in-a-makefile) - Docker health checks
- [Makefile functions and color output](https://eli.thegreenplace.net/2013/12/18/makefile-functions-and-color-output) - ANSI color codes
- [Most Makefiles Should .DELETE_ON_ERROR](https://innolitics.com/articles/make-delete-on-error/) - Best practices
- [Makefile for Node.js developers](https://zentered.co/articles/makefile-for-node-js-developers/) - Node.js patterns
- [renv Introduction](https://rstudio.github.io/renv/articles/renv.html) - renv::restore() usage

### Tertiary (LOW confidence)
- WebSearch results about polyglot Makefiles - General patterns verified with primary sources
- Community discussions on Hacker News - Provided context but not authoritative

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - GNU Make is universal, patterns are established
- Architecture: HIGH - Self-documenting help, Davis-Hansson preamble, PHONY targets are industry standard
- Pitfalls: HIGH - All documented in GNU Make manual or established best practices articles
- R integration: MEDIUM - renv patterns verified, but project-specific test commands pending Phase 2
- Node.js integration: HIGH - npm scripts wrapping is straightforward, well-documented

**Research date:** 2026-01-21
**Valid until:** 60 days (Make is stable; best practices evolve slowly)

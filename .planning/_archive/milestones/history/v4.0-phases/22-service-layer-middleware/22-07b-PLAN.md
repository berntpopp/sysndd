---
phase: 22-service-layer-middleware
plan: 07b
type: execute
wave: 3
depends_on: ["22-01", "22-03", "22-04", "22-05"]
files_modified:
  - api/endpoints/re_review_endpoints.R
  - api/endpoints/ontology_endpoints.R
  - api/endpoints/statistics_endpoints.R
  - api/endpoints/logging_endpoints.R
  - api/endpoints/jobs_endpoints.R
autonomous: true

must_haves:
  truths:
    - "re_review_endpoints.R uses require_role consistently"
    - "ontology_endpoints.R uses require_role(Administrator) for admin endpoints"
    - "statistics_endpoints.R uses require_role(Administrator) for all protected endpoints"
    - "logging_endpoints.R uses require_role(Administrator)"
    - "jobs_endpoints.R uses require_role(Administrator) for ontology_update"
    - "All Administrator-only endpoints use require_role(Administrator)"
  artifacts:
    - path: "api/endpoints/re_review_endpoints.R"
      provides: "Refactored re_review endpoints"
      contains: "require_role"
    - path: "api/endpoints/ontology_endpoints.R"
      provides: "Refactored ontology endpoints"
      contains: "require_role"
    - path: "api/endpoints/statistics_endpoints.R"
      provides: "Refactored statistics endpoints"
      contains: "require_role"
  key_links:
    - from: "api/endpoints/re_review_endpoints.R"
      to: "api/core/middleware.R"
      via: "Uses require_role for authorization"
      pattern: "require_role"
    - from: "api/endpoints/statistics_endpoints.R"
      to: "api/core/middleware.R"
      via: "Uses require_role for Administrator checks"
      pattern: "require_role.*Administrator"
---

<objective>
Refactor admin and specialized endpoints to use middleware.

Purpose: Complete the endpoint migration for administrative operations (re_review, ontology, statistics, logging, jobs). These endpoints have various role requirements but follow the same refactoring pattern as core data endpoints.

Output: All admin/specialized endpoints using consistent require_role pattern.
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/22-service-layer-middleware/22-01-SUMMARY.md
@.planning/phases/22-service-layer-middleware/22-07-SUMMARY.md
@api/core/middleware.R
</context>

<tasks>

<task type="auto">
  <name>Task 1: Refactor re_review_endpoints.R</name>
  <files>api/endpoints/re_review_endpoints.R</files>
  <action>
Most complex file with ~15 role checks. Replace each with require_role:

**Reviewer-level endpoints (lines 27, 85, 141):**
```r
# Before
if (!req$user_role %in% c("Administrator", "Curator", "Reviewer")) {
  res$status <- 403
  return(list(error = "Not authorized."))
}

# After
require_role(req, res, "Reviewer")
```

**Curator-level endpoints (lines 327, 328):**
Some endpoints have complex logic allowing different roles for different operations. Simplify where possible:
```r
require_role(req, res, "Curator")
```

**Administrator-level endpoints (lines 435, 520, 523, 578, 584, 636):**
```r
require_role(req, res, "Administrator")
```

**Note:** For endpoints with conditional role requirements (e.g., "Curators can edit their own, Admins can edit all"), keep the logic but use require_role for the minimum role:
```r
require_role(req, res, "Curator")  # At least Curator needed
if (req$user_role != "Administrator" && item$creator_id != req$user_id) {
  # Additional check for non-admins
}
```
  </action>
  <verify>
- `grep -c "require_role" api/endpoints/re_review_endpoints.R` shows 10+ usages
- `grep -c "req\$user_role !=" api/endpoints/re_review_endpoints.R` significantly reduced
- No syntax errors
  </verify>
  <done>
- re_review_endpoints.R refactored with require_role
- Complex role logic simplified where possible
  </done>
</task>

<task type="auto">
  <name>Task 2: Refactor ontology and statistics endpoints</name>
  <files>api/endpoints/ontology_endpoints.R, api/endpoints/statistics_endpoints.R</files>
  <action>
**ontology_endpoints.R:**
- Line 100: `require_role(req, res, "Administrator")`
- Line 138: `require_role(req, res, "Administrator")`

**statistics_endpoints.R:**
Replace all Administrator checks (lines 219, 267, 328, 369):
```r
# Before
if (is.null(req$user_role) || req$user_role != "Administrator") {
  res$status <- 403
  return(list(error = "Not authorized."))
}

# After
require_role(req, res, "Administrator")
```

These endpoints are simpler - all protected operations require Administrator role.
  </action>
  <verify>
- `grep -c "require_role" api/endpoints/ontology_endpoints.R` shows 2 usages
- `grep -c "require_role" api/endpoints/statistics_endpoints.R` shows 4 usages
- `grep -c "req\$user_role !=" api/endpoints/ontology_endpoints.R` shows 0
- `grep -c "req\$user_role !=" api/endpoints/statistics_endpoints.R` shows 0
- No syntax errors
  </verify>
  <done>
- ontology_endpoints.R uses require_role
- statistics_endpoints.R uses require_role
  </done>
</task>

<task type="auto">
  <name>Task 3: Refactor logging and jobs endpoints</name>
  <files>api/endpoints/logging_endpoints.R, api/endpoints/jobs_endpoints.R</files>
  <action>
**logging_endpoints.R:**
- Lines 50-51: `require_role(req, res, "Administrator")`

All logging endpoints are Administrator-only.

**jobs_endpoints.R:**
- Line 250: `require_role(req, res, "Administrator")` (for ontology_update)

Most jobs endpoints are public (clustering, phenotype_clustering). Only ontology_update requires Administrator.
  </action>
  <verify>
- `grep -c "require_role" api/endpoints/logging_endpoints.R` shows usage
- `grep -c "require_role" api/endpoints/jobs_endpoints.R` shows 1 usage
- No syntax errors
  </verify>
  <done>
- logging_endpoints.R uses require_role
- jobs_endpoints.R uses require_role for admin endpoint
  </done>
</task>

</tasks>

<verification>
- [ ] re_review_endpoints.R uses require_role (10+ usages)
- [ ] ontology_endpoints.R uses require_role (2 usages)
- [ ] statistics_endpoints.R uses require_role (4 usages)
- [ ] logging_endpoints.R uses require_role
- [ ] jobs_endpoints.R uses require_role for ontology_update
- [ ] Old `req$user_role !=` pattern count significantly reduced across all files
- [ ] No syntax errors in any refactored file
</verification>

<success_criteria>
- All admin/specialized endpoints use consistent require_role pattern
- Duplicated authorization code eliminated
- Total role check patterns reduced by >80% across Phase 22
- API behavior unchanged
</success_criteria>

<output>
After completion, create `.planning/phases/22-service-layer-middleware/22-07b-SUMMARY.md`
</output>

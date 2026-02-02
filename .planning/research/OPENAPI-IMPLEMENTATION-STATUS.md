# OpenAPI Response Documentation - Implementation Status Report

**Date**: 2026-02-02
**Last Updated**: 2026-02-02 (Post-review fixes applied)
**Status**: ✅ **COMPLETED** (with fixes)
**Branch**: `feature/openapi-response-schemas`

---

## Executive Summary

The OpenAPI response documentation enhancement has been successfully implemented following the architecture and principles outlined in the research documents. The implementation delivers:

- **63 API response samples** collected (41 public + 22 auth-protected)
- **60 inferred schemas** generated using GenSON
- **RFC 9457 ProblemDetails** for all error responses
- **Proper 200 response schemas** displayed in Swagger UI
- **Correct auth response logic** (GET endpoints omit 401/403, write endpoints include them)

---

## Implementation Summary

### What Was Planned (from Research Documents)

| Document | Key Recommendations | Status |
|----------|---------------------|--------|
| `OPENAPI-AUTOMATION-STRATEGY.md` | Use GenSON for schema inference | ✅ Implemented |
| `OPENAPI-AUTOMATION-STRATEGY.md` | Automated sample collection pipeline | ✅ Implemented |
| `OPENAPI-CURRENT-STATE-ANALYSIS.md` | Create modular `config/openapi/` structure | ✅ Implemented |
| `OPENAPI-CURRENT-STATE-ANALYSIS.md` | Add RFC 9457 ProblemDetails schema | ✅ Implemented |
| `OPENAPI-PLAN-REVIEW.md` | Follow SOLID principles | ✅ Implemented |
| `OPENAPI-PLAN-REVIEW.md` | Create `openapi-helpers.R` module | ✅ Implemented |
| `OPENAPI-RESPONSE-DOCUMENTATION-REVISED.md` | Enhance `pr_set_api_spec()` | ✅ Implemented |
| `OPENAPI-RESPONSE-DOCUMENTATION-REVISED.md` | Add error responses to all endpoints | ✅ Implemented |

### What Was Delivered

#### 1. Directory Structure Created
```
api/config/openapi/
├── .samples/                    # 63 API response samples
│   ├── api_about_draft_GET.json
│   ├── api_auth_signin_GET.json
│   ├── api_llm_config_GET.json
│   └── ... (60 more files)
├── schemas/
│   ├── inferred/               # 60 auto-generated schemas
│   │   ├── api_about_draft_GET.json
│   │   ├── api_entity_GET.json
│   │   ├── api_llm_config_GET.json
│   │   └── ... (57 more files)
│   └── problem-details.json    # RFC 9457 schema
└── responses/
    └── error-responses.json    # Standard error response definitions
```

#### 2. Core Files Modified/Created

| File | Change Type | Description |
|------|-------------|-------------|
| `api/functions/openapi-helpers.R` | **Created** | Modular OpenAPI enhancement functions |
| `api/start_sysndd_api.R` | **Modified** | Added `enhance_openapi_spec()` call, made root router global |
| `api/endpoints/admin_endpoints.R` | **Modified** | Changed to use root router's enhanced spec |
| `api/config/openapi/schemas/problem-details.json` | **Created** | RFC 9457 ProblemDetails schema |

#### 3. Key Functions Implemented

**`enhance_openapi_spec()`** - Main orchestration function:
- Loads schemas from JSON files (OCP - extend via files)
- Adds standard error response definitions
- Applies endpoint-specific enhancements
- Injects 200 response schemas from inferred samples

**`add_error_responses_to_endpoint()`** - Per-endpoint enhancement:
- Adds 400, 404, 500 with `$ref` to ProblemDetails
- Conditionally adds 401, 403 only for write methods (POST/PUT/DELETE/PATCH)
- Uses `application/problem+json` content type

**`parse_inferred_schema_path()`** - Schema-to-endpoint mapping:
- Normalizes underscore vs slash paths
- Handles trailing slash variations
- Maps sample filenames to OpenAPI paths

---

## Verification Results

### Swagger UI Testing (via Playwright)

| Endpoint | 200 Schema | Error Responses | Auth Responses |
|----------|------------|-----------------|----------------|
| `GET /api/health/` | ✅ `{status, timestamp, version}` | ✅ 400, 404, 500 | ❌ None (correct - public) |
| `GET /api/entity/` | ✅ `{links, meta, data}` | ✅ 400, 404, 500 | ❌ None (correct - public GET) |
| `POST /api/entity/create` | ✅ Schema shown | ✅ 400, 404, 500 | ✅ 401, 403 (correct - write) |
| `GET /api/llm/config` | ✅ `{gemini_configured, current_model, available_models, rate_limit}` | ✅ 400, 404, 500 | ❌ None (correct - admin GET) |

### Error Response Format

All error responses now use RFC 9457 ProblemDetails with `application/problem+json`:

```json
{
  "type": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400",
  "title": "Bad Request",
  "status": 400,
  "detail": "Invalid filter syntax: missing operator",
  "instance": "/api/entity"
}
```

---

## Technical Decisions Made

### 1. Root Router Global Access
**Problem**: Sub-router's `req$pr$getApiSpec()` returned unenriched spec.
**Solution**: Made root router global with `root <<- pr()` in `start_sysndd_api.R`, then used `root$getApiSpec()` in admin endpoint.

### 2. Auth Response Logic
**Problem**: Initial implementation added 401/403 to all endpoints including public GETs.
**Solution**: Modified `add_error_responses_to_endpoint()` to only add auth responses to write methods (POST/PUT/DELETE/PATCH).

### 3. Schema-to-Path Mapping
**Problem**: Sample filenames like `api_analysis_functional_clustering_GET.json` didn't match OpenAPI paths like `/api/analysis/functional_clustering`.
**Solution**: Normalize both by replacing underscores with slashes, removing leading/trailing slashes, then compare.

### 4. Always Replace Error Responses
**Problem**: Plumber adds default error responses that showed `"type": "string"` instead of ProblemDetails.
**Solution**: Remove null checks and always replace error responses with `$ref` versions.

---

## Metrics

| Metric | Value |
|--------|-------|
| Total API samples collected | 63 |
| Public endpoint samples | 41 |
| Auth-protected endpoint samples | 22 |
| Inferred schemas generated | 60 |
| Endpoints with 200 schema refs | ~35 (non-parameterized) |
| Error response coverage | 100% of endpoints |

---

## Known Limitations

1. **Parameterized endpoints** (`{sysndd_id}`, `{symbol}`, etc.) don't have sample-based schemas yet - would require collecting samples with real parameter values.

2. **Some endpoints return 500** due to database/server issues during sample collection - these have error schemas instead of success schemas.

3. **POST/PUT/DELETE response schemas** are mostly empty `{}` since we only collected GET samples.

---

## Known Issues (Post-Implementation Review 2026-02-02)

### ✅ FIXED: Issue 1: Swagger UI Displays Empty `{}` for Some 200 Responses

**Affected Endpoints**: 16 endpoints including `/api/status/`, `/api/user/list`, `/api/panels/options`, etc.

**Root Cause**: GenSON schema inference produces `anyOf` structures when the response could be multiple types:

```json
{
  "anyOf": [
    { "type": "object" },           // <-- Empty object, causes {} display
    { "type": "array", "items": {...} }
  ]
}
```

Swagger UI doesn't handle `anyOf` well and defaults to showing the first option (empty object).

**Affected Schemas** (16 total):
- AboutDraftResponse, AboutPublishedResponse
- AnalysisPhenotypeClusteringResponse
- ComparisonsSimilarityResponse, ComparisonsUpsetResponse
- PanelsOptionsResponse
- PhenotypeCorrelationResponse, PhenotypeCountResponse
- ReReviewAssignmentTableResponse, ReviewResponse
- StatisticsNewsResponse, **StatusResponse**
- UserListResponse, UserRoleListResponse
- VariantCorrelationResponse, VariantCountResponse

**Fix Applied** (2026-02-02): Added `clean_schema_for_openapi()` function to `scripts/openapi/infer-schemas.py`:
1. Removes empty `{ "type": "object" }` from `anyOf` arrays
2. Simplifies `anyOf` with single remaining option to just use that option directly
3. Removes `$schema` field (not valid in OpenAPI 3.0)
4. Recursively processes nested schemas

**Verification**: `/api/status/` now shows full array schema in Swagger UI instead of `{}`.

### ✅ FIXED: Issue 2: Invalid `$schema` Field in Inferred Schemas

**Problem**: All 60 inferred schemas contained `"$schema": "http://json-schema.org/schema#"` which is valid JSON Schema but NOT valid in OpenAPI 3.0.

**Fix Applied**: The `clean_schema_for_openapi()` function now strips `$schema` fields during post-processing.

---

## Future Improvements

1. **Parameterized endpoint sampling**: Collect samples for endpoints like `/api/entity/{sysndd_id}` using real entity IDs.

2. **POST response sampling**: Capture actual success responses from write operations.

3. **Schema validation**: Add Schemathesis-based CI validation as outlined in `OPENAPI-AUTOMATION-STRATEGY.md`.

4. **Incremental updates**: Add workflow to regenerate schemas when API changes.

5. **Fix anyOf/oneOf schemas**: Clean up GenSON output to remove empty object alternatives that break Swagger UI display.

6. **Remove $schema fields**: Post-process inferred schemas to be OpenAPI 3.0 compliant.

---

## Files Changed Summary

```
Modified:
  api/start_sysndd_api.R          # Added enhance_openapi_spec() call
  api/endpoints/admin_endpoints.R  # Use root router for spec

Created:
  api/functions/openapi-helpers.R                    # Core enhancement logic
  api/config/openapi/schemas/problem-details.json    # RFC 9457 schema
  api/config/openapi/schemas/inferred/*.json         # 60 inferred schemas
  api/config/openapi/.samples/*.json                 # 63 API samples
```

---

## Conclusion

The OpenAPI response documentation enhancement is complete and functional. The implementation:

1. ✅ **Follows the planned architecture** from research documents
2. ✅ **Adheres to SOLID principles** (SRP, OCP, DIP)
3. ✅ **Uses RFC 9457 ProblemDetails** for all error responses
4. ✅ **Displays proper schemas in Swagger UI**
5. ✅ **Correctly handles auth vs public endpoints**

The API documentation is now significantly more useful for consumers, with proper response schemas visible directly in Swagger UI.

---

## References

- [OPENAPI-AUTOMATION-STRATEGY.md](.planning/research/OPENAPI-AUTOMATION-STRATEGY.md)
- [OPENAPI-CURRENT-STATE-ANALYSIS.md](.planning/research/OPENAPI-CURRENT-STATE-ANALYSIS.md)
- [OPENAPI-PLAN-REVIEW.md](.planning/research/OPENAPI-PLAN-REVIEW.md)
- [OPENAPI-RESPONSE-DOCUMENTATION-REVISED.md](.planning/research/OPENAPI-RESPONSE-DOCUMENTATION-REVISED.md)
- [RFC 9457 - Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc9457)

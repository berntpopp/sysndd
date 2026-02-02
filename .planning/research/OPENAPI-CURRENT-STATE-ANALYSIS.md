# OpenAPI Current State Analysis

**Date**: 2026-02-02
**Purpose**: Document existing `api_spec.json` implementation and identify improvements

---

## Executive Summary

The SysNDD API has an existing mechanism for injecting OpenAPI examples via `api_spec.json`, but it's severely limited in scope. The current implementation only handles request body examples for endpoints with `create_json` parameters, leaving response documentation completely unaddressed.

---

## Current Implementation Analysis

### 1. File: `api/config/api_spec.json`

**Structure**:
```json
{
  "/api/entity/create": {
    "post": {
      "requestBody": {
        "content": {
          "application/json": {
            "schema": {
              "properties": {
                "create_json": {
                  "example": { /* detailed example object */ }
                }
              }
            }
          }
        }
      }
    }
  }
}
```

**Current Coverage**:
- Only 1 endpoint documented: `/api/entity/create`
- Only request body examples (no response schemas)
- Deeply nested structure targeting specific `create_json` property

### 2. Function: `update_api_spec_examples()` in `api/functions/config-functions.R`

```r
update_api_spec_examples <- function(spec, api_spec_json) {
  for (path in names(api_spec_json)) {
    if (is.null(spec$paths[[path]])) next
    for (method in names(api_spec_json[[path]])) {
      if (is.null(spec$paths[[path]][[method]])) next
      if (is.null(api_spec_json[[path]][[method]]$requestBody$content$`application/json`$schema$properties$create_json$example)) next
      spec$paths[[path]][[method]]$requestBody$content$`application/json`$schema$properties$create_json$example <-
        api_spec_json[[path]][[method]]$requestBody$content$`application/json`$schema$properties$create_json$example
    }
  }
  return(spec)
}
```

**Limitations**:
1. **Hard-coded path**: Only targets `requestBody → content → application/json → schema → properties → create_json → example`
2. **No response handling**: Cannot inject response schemas or examples
3. **Single property**: Only works for `create_json` parameter name
4. **No schema merging**: Cannot add new schemas to `components/schemas`

### 3. Swagger UI Observations (Live Inspection)

**POST /api/entity/create**:
- Request body example: **Working** - shows full `create_json` structure
- Response 200: Shows `"{}"` - **No schema**
- Response 500: Shows `"\"string\""` - **Generic placeholder**
- Response default: Shows `"{}"` - **No schema**
- **Missing**: 400, 401, 403, 404 error responses

**GET /api/entity/**:
- Parameters: Well documented with defaults
- Response 200: "A cursor pagination object with links, meta and data" - **No schema, shows `"{}"`**
- Response 500: Shows `"\"string\""` - **Generic placeholder**
- **Missing**: Pagination schema structure

---

## Gap Analysis

| Aspect | Current State | Desired State |
|--------|---------------|---------------|
| Request examples | 1 endpoint | All POST endpoints |
| Response schemas | None | All endpoints |
| Error responses | Only 200, 500, default | 400, 401, 403, 404, 500 |
| Error format | No schema | RFC 9457 ProblemDetails |
| Pagination schema | None | CursorPaginationResponse |
| Entity schemas | None | EntityObject, EntityList |
| Schema reuse | N/A | `$ref` components |

---

## Recommended Improvements

### Phase 1: Extend `update_api_spec_examples()` → `enhance_openapi_spec()`

Create a more flexible function that can handle multiple enhancement types:

```r
#' Enhance OpenAPI Specification
#'
#' Flexible function to enhance Plumber-generated OpenAPI spec with:
#' - Component schemas (ProblemDetails, Pagination, Entities)
#' - Response definitions
#' - Request body examples
#'
#' @param spec Plumber-generated OpenAPI spec
#' @param enhancements List of enhancement files to merge
#' @return Enhanced specification
enhance_openapi_spec <- function(spec, enhancements_dir = "config/openapi") {
  # 1. Load and merge component schemas
  schemas <- load_json_files(file.path(enhancements_dir, "schemas"))
  spec$components$schemas <- merge_lists(spec$components$schemas, schemas)

  # 2. Load and merge response definitions
  responses <- load_json_files(file.path(enhancements_dir, "responses"))
  spec$components$responses <- merge_lists(spec$components$responses, responses)

  # 3. Load and apply endpoint-specific enhancements
  endpoints <- load_json_files(file.path(enhancements_dir, "endpoints"))
  spec <- apply_endpoint_enhancements(spec, endpoints)

  spec
}
```

### Phase 2: Create Modular Schema Files

**Directory Structure**:
```
api/config/openapi/
├── schemas/
│   ├── problem-details.json     # RFC 9457 error schema
│   ├── pagination.json          # Cursor pagination wrapper
│   ├── entity.json              # Entity response schemas
│   └── job-status.json          # Async job schemas
├── responses/
│   ├── error-responses.json     # Standard 400, 401, 403, 404, 500
│   └── success-responses.json   # Common success patterns
└── endpoints/
    ├── entity-endpoints.json    # Entity-specific enhancements
    └── gene-endpoints.json      # Gene-specific enhancements
```

### Phase 3: Schema Content Examples

**`schemas/problem-details.json`**:
```json
{
  "ProblemDetails": {
    "type": "object",
    "description": "RFC 9457 Problem Details for HTTP APIs",
    "required": ["type", "title", "status"],
    "properties": {
      "type": {
        "type": "string",
        "format": "uri-reference",
        "description": "URI reference identifying the problem type",
        "example": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400"
      },
      "title": {
        "type": "string",
        "description": "Short, human-readable summary",
        "example": "Bad Request"
      },
      "status": {
        "type": "integer",
        "description": "HTTP status code",
        "example": 400
      },
      "detail": {
        "type": "string",
        "description": "Human-readable explanation specific to this occurrence"
      },
      "instance": {
        "type": "string",
        "format": "uri-reference",
        "description": "URI reference identifying the specific occurrence"
      }
    }
  }
}
```

**`schemas/pagination.json`**:
```json
{
  "CursorPaginationMeta": {
    "type": "object",
    "properties": {
      "total_count": { "type": "integer", "example": 3679 },
      "page_size": { "type": "integer", "example": 10 },
      "execution_time": { "type": "number", "example": 0.234 }
    }
  },
  "CursorPaginationLinks": {
    "type": "object",
    "properties": {
      "self": { "type": "string", "example": "/api/entity?page_after=0&page_size=10" },
      "next": { "type": "string", "example": "/api/entity?page_after=10&page_size=10" },
      "prev": { "type": "string", "nullable": true }
    }
  },
  "CursorPaginationResponse": {
    "type": "object",
    "properties": {
      "links": { "$ref": "#/components/schemas/CursorPaginationLinks" },
      "meta": { "$ref": "#/components/schemas/CursorPaginationMeta" },
      "data": { "type": "array", "items": {} }
    }
  }
}
```

**`responses/error-responses.json`**:
```json
{
  "BadRequest": {
    "description": "Bad Request - Invalid input parameters",
    "content": {
      "application/problem+json": {
        "schema": { "$ref": "#/components/schemas/ProblemDetails" },
        "example": {
          "type": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400",
          "title": "Bad Request",
          "status": 400,
          "detail": "Invalid filter syntax: missing operator",
          "instance": "/api/entity"
        }
      }
    }
  },
  "Unauthorized": {
    "description": "Unauthorized - Authentication required",
    "content": {
      "application/problem+json": {
        "schema": { "$ref": "#/components/schemas/ProblemDetails" },
        "example": {
          "type": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/401",
          "title": "Unauthorized",
          "status": 401,
          "detail": "Authorization header missing. Please provide a Bearer token.",
          "instance": "/api/llm/regenerate"
        }
      }
    }
  },
  "Forbidden": {
    "description": "Forbidden - Insufficient permissions",
    "content": {
      "application/problem+json": {
        "schema": { "$ref": "#/components/schemas/ProblemDetails" }
      }
    }
  },
  "NotFound": {
    "description": "Not Found - Resource does not exist",
    "content": {
      "application/problem+json": {
        "schema": { "$ref": "#/components/schemas/ProblemDetails" }
      }
    }
  },
  "InternalServerError": {
    "description": "Internal Server Error - Unexpected error",
    "content": {
      "application/problem+json": {
        "schema": { "$ref": "#/components/schemas/ProblemDetails" }
      }
    }
  }
}
```

---

## Implementation Roadmap

### Step 1: Create Infrastructure (Low Effort)
1. Create `api/config/openapi/` directory structure
2. Create `api/functions/openapi-helpers.R` with flexible enhancement functions
3. Migrate existing `api_spec.json` content to new structure

### Step 2: Add Core Schemas (Low Effort)
1. Create `problem-details.json` (RFC 9457)
2. Create `pagination.json` (cursor pagination)
3. Create `error-responses.json` (standard errors)

### Step 3: Update Startup (Low Effort)
1. Modify `start_sysndd_api.R` to use new `enhance_openapi_spec()`
2. Remove old `update_api_spec_examples()` call
3. Test with Swagger UI

### Step 4: Add Entity Schemas (Medium Effort)
1. Document entity response structure
2. Add to GET endpoints
3. Add to POST endpoints

### Step 5: Extend to All Endpoints (Higher Effort)
1. Gene, Review, Publication endpoints
2. Job status responses
3. Authentication responses

---

## Backward Compatibility

The new system should:
1. **Preserve existing request body examples** - migrate from `api_spec.json`
2. **Not break Swagger UI** - only add new information
3. **Be incremental** - can add schemas one endpoint at a time

---

## Testing Strategy

1. **Unit tests**: Verify schema loading and merging functions
2. **Integration tests**: Verify OpenAPI spec structure after enhancement
3. **Validation tests**: Compare actual API responses against defined schemas
4. **Visual tests**: Swagger UI displays schemas correctly

---

## Conclusion

The existing `api_spec.json` mechanism is a good starting point but needs significant expansion:

1. **Current**: Single-purpose function for one property type
2. **Needed**: Flexible system for schemas, responses, and examples
3. **Approach**: Modular JSON files + generic loading functions
4. **Benefit**: DRY, extensible, maintainable documentation

The recommended approach aligns with the SOLID principles outlined in the plan review and provides a scalable foundation for complete API documentation.

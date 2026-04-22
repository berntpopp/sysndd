# OpenAPI Response Documentation Enhancement Plan (Revised)

**Version**: 2.0
**Date**: 2026-02-02
**Status**: Ready for Implementation
**Branch**: `feature/openapi-response-documentation`

---

## Executive Summary

This revised plan addresses the gaps in OpenAPI response documentation for the SysNDD Plumber API while adhering to DRY, KISS, SOLID principles and avoiding anti-patterns identified in the review.

**Key Changes from Original Plan**:
1. Modular file-based architecture instead of inline code
2. Generic enhancement function instead of hard-coded paths
3. Incremental approach building on existing `api_spec.json` pattern
4. Clear separation of concerns (SRP)
5. Extension via configuration, not code modification (OCP)

---

## Schema Discovery Approach

All schemas in this plan are derived from **actual implementation**, not invented:

| Schema | Discovery Method | Source |
|--------|------------------|--------|
| `ProblemDetails` | API query + code review | `api/start_sysndd_api.R` error handlers, verified via `curl /api/llm/regenerate` |
| `CursorPaginationLinks` | Code review | `api/functions/helper-functions.R:860-865` |
| `CursorPaginationMeta` | Code review + API query | `api/functions/helper-functions.R:868-889`, verified via `curl /api/entity/` |
| `FieldSpecification` | API query | `curl /api/entity/?page_size=1 | jq '.meta.fspec[0]'` |
| `EntityObject` | API query | `curl /api/entity/?page_size=1 | jq '.data[0]'` |
| `GeneObject` | API query | `curl /api/gene/?page_size=1 | jq '.data[0]'` |

**Methodology**:
1. Query live API to get real response structure
2. Review R code to understand all possible fields and types
3. Extract enum values from actual data and code
4. Validate examples against actual responses

---

## Architecture Overview

### Current State
```
api/
├── config/
│   └── api_spec.json          # Only request body examples, 1 endpoint
├── functions/
│   └── config-functions.R     # Hard-coded update_api_spec_examples()
└── start_sysndd_api.R         # 800+ lines, handles everything
```

### Target State
```
api/
├── config/
│   ├── api_spec.json          # DEPRECATED - migrate to new structure
│   └── openapi/
│       ├── schemas/
│       │   ├── problem-details.json
│       │   ├── pagination.json
│       │   └── entity.json
│       ├── responses/
│       │   └── error-responses.json
│       └── endpoints/
│           └── entity-create.json    # Migrated from api_spec.json
├── functions/
│   ├── config-functions.R     # Keep for backward compat
│   └── openapi-helpers.R      # NEW: Generic enhancement functions
└── start_sysndd_api.R         # Simplified: calls enhance_openapi_spec()
```

---

## Implementation Plan

### Phase 1: Infrastructure Setup

#### Task 1.1: Create Directory Structure
```bash
mkdir -p api/config/openapi/{schemas,responses,endpoints}
```

#### Task 1.2: Create `api/functions/openapi-helpers.R`

```r
# api/functions/openapi-helpers.R
#
# OpenAPI specification enhancement utilities.
# Follows Single Responsibility Principle - only handles OpenAPI enhancement.
# Follows Open/Closed Principle - extend via JSON files, not code changes.

#' Load JSON Files from Directory
#'
#' Loads all JSON files from a directory and merges them into a single list.
#'
#' @param dir_path Path to directory containing JSON files
#' @return Named list of merged JSON contents
#' @keywords internal
load_openapi_json_files <- function(dir_path) {
  if (!dir.exists(dir_path)) {
    return(list())
  }

  json_files <- list.files(dir_path, pattern = "\\.json$", full.names = TRUE)
  result <- list()

  for (file in json_files) {
    tryCatch({
      content <- jsonlite::fromJSON(file, simplifyVector = FALSE)
      result <- c(result, content)
    }, error = function(e) {
      warning(sprintf("Failed to load OpenAPI JSON file %s: %s", file, e$message))
    })
  }

  result
}

#' Merge Lists Recursively
#'
#' Merges two lists, with second list taking precedence for conflicts.
#'
#' @param base Base list
#' @param overlay List to merge on top
#' @return Merged list
#' @keywords internal
merge_openapi_lists <- function(base, overlay) {
  if (is.null(base)) return(overlay)
  if (is.null(overlay)) return(base)

  for (name in names(overlay)) {
    if (name %in% names(base) && is.list(base[[name]]) && is.list(overlay[[name]])) {
      base[[name]] <- merge_openapi_lists(base[[name]], overlay[[name]])
    } else {
      base[[name]] <- overlay[[name]]
    }
  }

  base
}

#' Create Standard Error Response
#'
#' Factory function for RFC 9457 compliant error responses.
#' Follows DRY - single definition used for all error codes.
#'
#' @param description Human-readable description
#' @return OpenAPI response object with $ref to ProblemDetails
#' @keywords internal
create_error_response <- function(description) {
  list(
    description = description,
    content = list(
      "application/problem+json" = list(
        schema = list(`$ref` = "#/components/schemas/ProblemDetails")
      )
    )
  )
}

#' Get Standard Error Responses
#'
#' Returns pre-defined error response definitions for common HTTP status codes.
#' These are added to components/responses for $ref usage.
#'
#' @return Named list of error response definitions
#' @export
get_standard_error_responses <- function() {
  list(
    "BadRequest" = create_error_response("Bad Request - Invalid input parameters"),
    "Unauthorized" = create_error_response("Unauthorized - Authentication required"),
    "Forbidden" = create_error_response("Forbidden - Insufficient permissions"),
    "NotFound" = create_error_response("Not Found - Resource does not exist"),
    "InternalServerError" = create_error_response("Internal Server Error - Unexpected error")
  )
}

#' Add Error Responses to Endpoint
#'
#' Adds standard error responses to an endpoint if not already present.
#' Only adds responses that are relevant (doesn't add 401 to public endpoints).
#'
#' @param endpoint_spec The endpoint specification object
#' @param include_auth Whether to include 401/403 responses (default TRUE)
#' @return Modified endpoint specification
#' @keywords internal
add_error_responses_to_endpoint <- function(endpoint_spec, include_auth = TRUE) {
  if (is.null(endpoint_spec$responses)) {
    endpoint_spec$responses <- list()
  }

  # Always add these
  if (is.null(endpoint_spec$responses[["400"]])) {
    endpoint_spec$responses[["400"]] <- list(`$ref` = "#/components/responses/BadRequest")
  }
  if (is.null(endpoint_spec$responses[["500"]])) {
    endpoint_spec$responses[["500"]] <- list(`$ref` = "#/components/responses/InternalServerError")
  }


  # Auth-related responses (skip for public endpoints like /health)
  if (include_auth) {
    if (is.null(endpoint_spec$responses[["401"]])) {
      endpoint_spec$responses[["401"]] <- list(`$ref` = "#/components/responses/Unauthorized")
    }
    if (is.null(endpoint_spec$responses[["403"]])) {
      endpoint_spec$responses[["403"]] <- list(`$ref` = "#/components/responses/Forbidden")
    }
  }

  # Add 404 for endpoints with path parameters
  if (is.null(endpoint_spec$responses[["404"]])) {
    endpoint_spec$responses[["404"]] <- list(`$ref` = "#/components/responses/NotFound")
  }

  endpoint_spec
}

#' Enhance OpenAPI Specification
#'
#' Main function to enhance Plumber-generated OpenAPI spec with:
#' - Component schemas from JSON files
#' - Standard error response definitions
#' - Endpoint-specific enhancements
#'
#' Follows Open/Closed Principle: extend via config files, not code changes.
#'
#' @param spec The OpenAPI specification object from Plumber
#' @param config_dir Base directory for OpenAPI config files (default: "config/openapi")
#' @param add_error_responses Whether to add standard error responses to all endpoints
#' @param public_paths Vector of path prefixes that don't require auth (e.g., "/api/health")
#' @return Enhanced specification object
#' @export
enhance_openapi_spec <- function(spec,
                                  config_dir = "config/openapi",
                                  add_error_responses = TRUE,
                                  public_paths = c("/api/health", "/api/version", "/api/about")) {

 # 1. Load and merge component schemas
 schemas_dir <- file.path(config_dir, "schemas")
 schemas <- load_openapi_json_files(schemas_dir)
 if (length(schemas) > 0) {
   if (is.null(spec$components$schemas)) {
     spec$components$schemas <- list()
   }
   spec$components$schemas <- merge_openapi_lists(spec$components$schemas, schemas)
 }

 # 2. Add standard error response definitions to components
 if (add_error_responses) {
   if (is.null(spec$components$responses)) {
     spec$components$responses <- list()
   }
   spec$components$responses <- merge_openapi_lists(
     spec$components$responses,
     get_standard_error_responses()
   )
 }

 # 3. Load and merge custom response definitions
 responses_dir <- file.path(config_dir, "responses")
 responses <- load_openapi_json_files(responses_dir)
 if (length(responses) > 0) {
   spec$components$responses <- merge_openapi_lists(spec$components$responses, responses)
 }

 # 4. Load and apply endpoint-specific enhancements
 endpoints_dir <- file.path(config_dir, "endpoints")
 endpoints <- load_openapi_json_files(endpoints_dir)
 for (path in names(endpoints)) {
   if (!is.null(spec$paths[[path]])) {
     spec$paths[[path]] <- merge_openapi_lists(spec$paths[[path]], endpoints[[path]])
   }
 }

 # 5. Add error responses to all endpoints
 if (add_error_responses) {
   for (path in names(spec$paths)) {
     for (method in names(spec$paths[[path]])) {
       if (!method %in% c("parameters", "servers", "summary", "description")) {
         is_public <- any(sapply(public_paths, function(p) startsWith(path, p)))
         spec$paths[[path]][[method]] <- add_error_responses_to_endpoint(
           spec$paths[[path]][[method]],
           include_auth = !is_public
         )
       }
     }
   }
 }

 spec
}
```

---

### Phase 2: Core Schema Files

#### Task 2.1: Create `api/config/openapi/schemas/problem-details.json`

```json
{
  "ProblemDetails": {
    "type": "object",
    "description": "RFC 9457 Problem Details for HTTP APIs. Used for all error responses.",
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
        "description": "Short, human-readable summary of the problem",
        "example": "Bad Request"
      },
      "status": {
        "type": "integer",
        "description": "HTTP status code",
        "example": 400
      },
      "detail": {
        "type": "string",
        "description": "Human-readable explanation specific to this occurrence",
        "example": "Missing required parameter: entity_id"
      },
      "instance": {
        "type": "string",
        "format": "uri-reference",
        "description": "URI reference identifying the specific occurrence",
        "example": "/api/entity/123"
      }
    },
    "example": {
      "type": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400",
      "title": "Bad Request",
      "status": 400,
      "detail": "Invalid filter syntax: missing operator",
      "instance": "/api/entity"
    }
  }
}
```

#### Task 2.2: Create `api/config/openapi/schemas/pagination.json`

**Source**: Derived from `api/functions/helper-functions.R:generate_cursor_pag_inf()` (lines 771-895) and live API query.

```json
{
  "CursorPaginationLinks": {
    "type": "object",
    "description": "Navigation links for cursor-based pagination",
    "properties": {
      "prev": {
        "type": "string",
        "description": "URL of the previous page ('null' string if first page)",
        "example": "null"
      },
      "self": {
        "type": "string",
        "description": "URL of the current page",
        "example": "http://localhost:7777?sort=entity_id&page_after=0&page_size=10"
      },
      "next": {
        "type": "string",
        "description": "URL of the next page ('null' string if last page)",
        "example": "http://localhost:7777?sort=entity_id&page_after=10&page_size=10"
      },
      "last": {
        "type": "string",
        "description": "URL of the last page",
        "example": "http://localhost:7777?sort=entity_id&page_after=4604&page_size=10"
      }
    }
  },
  "CursorPaginationMeta": {
    "type": "object",
    "description": "Metadata for paginated responses (from generate_cursor_pag_inf)",
    "properties": {
      "perPage": {
        "type": "integer",
        "description": "Number of records per page",
        "example": 10
      },
      "currentPage": {
        "type": "integer",
        "description": "Current page number (1-indexed)",
        "example": 1
      },
      "totalPages": {
        "type": "integer",
        "description": "Total number of pages",
        "example": 420
      },
      "prevItemID": {
        "type": "string",
        "description": "Cursor ID of previous page start ('null' if first page)",
        "example": "null"
      },
      "currentItemID": {
        "type": "integer",
        "description": "Cursor ID of current page start",
        "example": 0
      },
      "nextItemID": {
        "type": "integer",
        "description": "Cursor ID of next page start",
        "example": 10
      },
      "lastItemID": {
        "type": "integer",
        "description": "Cursor ID of last page start",
        "example": 4604
      },
      "totalItems": {
        "type": "integer",
        "description": "Total number of records matching the query",
        "example": 4200
      },
      "sort": {
        "type": "string",
        "description": "Sort column applied",
        "example": "entity_id"
      },
      "filter": {
        "type": "string",
        "description": "Filter string applied",
        "example": ""
      },
      "fields": {
        "type": "string",
        "description": "Fields selection applied",
        "example": ""
      },
      "fspec": {
        "type": "array",
        "description": "Field specifications for UI rendering",
        "items": {
          "$ref": "#/components/schemas/FieldSpecification"
        }
      },
      "executionTime": {
        "type": "string",
        "description": "Query execution time",
        "example": "0.18 secs"
      }
    }
  },
  "FieldSpecification": {
    "type": "object",
    "description": "Field specification for UI table rendering",
    "properties": {
      "key": { "type": "string", "example": "entity_id" },
      "label": { "type": "string", "example": "Entity id" },
      "sortable": { "type": "boolean", "example": true },
      "sortDirection": { "type": "string", "enum": ["asc", "desc"], "example": "asc" },
      "filterable": { "type": "boolean", "example": true },
      "selectable": { "type": "boolean", "example": false },
      "multi_selectable": { "type": "boolean", "example": false },
      "selectOptions": {
        "type": "array",
        "items": { "type": "string" },
        "example": ["Definitive", "Limited", "Moderate"]
      },
      "count": { "type": "integer", "example": 4200 },
      "count_filtered": { "type": "integer", "example": 4200 },
      "class": { "type": "string", "example": "text-left" }
    }
  },
  "CursorPaginationResponse": {
    "type": "object",
    "description": "Standard cursor pagination wrapper for list endpoints",
    "properties": {
      "links": {
        "$ref": "#/components/schemas/CursorPaginationLinks"
      },
      "meta": {
        "$ref": "#/components/schemas/CursorPaginationMeta"
      },
      "data": {
        "type": "array",
        "description": "Array of result objects",
        "items": {}
      }
    }
  }
}
```

#### Task 2.3: Create `api/config/openapi/schemas/entity.json`

**Source**: Derived from live API query `GET /api/entity/?page_size=1`.

```json
{
  "EntityObject": {
    "type": "object",
    "description": "Entity object representing a gene-disease relationship",
    "properties": {
      "entity_id": {
        "type": "integer",
        "description": "Unique entity identifier",
        "example": 2
      },
      "hgnc_id": {
        "type": "string",
        "description": "HGNC gene identifier",
        "example": "HGNC:60"
      },
      "symbol": {
        "type": "string",
        "description": "Gene symbol",
        "example": "ABCC9"
      },
      "disease_ontology_id_version": {
        "type": "string",
        "description": "Disease ontology ID with version",
        "example": "OMIM:608569"
      },
      "disease_ontology_name": {
        "type": "string",
        "description": "Human-readable disease name",
        "example": "Cardiomyopathy, dilated, 1O"
      },
      "hpo_mode_of_inheritance_term": {
        "type": "string",
        "description": "HPO term for inheritance mode",
        "example": "HP:0000006"
      },
      "hpo_mode_of_inheritance_term_name": {
        "type": "string",
        "description": "Human-readable inheritance mode",
        "enum": [
          "Autosomal dominant inheritance",
          "Autosomal recessive inheritance",
          "Mitochondrial inheritance",
          "Somatic mutation",
          "X-linked dominant inheritance",
          "X-linked other inheritance",
          "X-linked recessive inheritance"
        ],
        "example": "Autosomal dominant inheritance"
      },
      "inheritance_filter": {
        "type": "string",
        "description": "Simplified inheritance for filtering",
        "example": "Autosomal dominant"
      },
      "ndd_phenotype": {
        "type": "integer",
        "description": "NDD phenotype flag (0 or 1)",
        "enum": [0, 1],
        "example": 0
      },
      "ndd_phenotype_word": {
        "type": "string",
        "description": "NDD phenotype as Yes/No",
        "enum": ["Yes", "No"],
        "example": "No"
      },
      "entry_date": {
        "type": "string",
        "format": "date",
        "description": "Date entity was entered",
        "example": "2012-02-20"
      },
      "category": {
        "type": "string",
        "description": "Evidence category",
        "enum": ["Definitive", "Moderate", "Limited", "Refuted", "not applicable"],
        "example": "not applicable"
      },
      "category_id": {
        "type": "integer",
        "description": "Category identifier",
        "example": 5
      }
    }
  },
  "GeneObject": {
    "type": "object",
    "description": "Gene object with associated entities",
    "properties": {
      "hgnc_id": {
        "type": "string",
        "description": "HGNC gene identifier",
        "example": "HGNC:60"
      },
      "symbol": {
        "type": "string",
        "description": "Gene symbol",
        "example": "ABCC9"
      },
      "entities_count": {
        "type": "integer",
        "description": "Number of associated entities",
        "example": 2
      },
      "entities": {
        "type": "array",
        "description": "List of entity IDs",
        "items": { "type": "integer" },
        "example": [1, 2]
      }
    }
  }
}
```

#### Task 2.4: Create `api/config/openapi/responses/error-responses.json`

**Note**: These are optional enhanced examples. The core error responses are defined programmatically in `openapi-helpers.R:get_standard_error_responses()`.

```json
{
  "BadRequestExample": {
    "description": "Bad Request - Example with context",
    "content": {
      "application/problem+json": {
        "schema": {
          "$ref": "#/components/schemas/ProblemDetails"
        },
        "examples": {
          "invalidFilter": {
            "summary": "Invalid filter syntax",
            "value": {
              "type": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400",
              "title": "Bad Request",
              "status": 400,
              "detail": "Invalid filter syntax: 'symbol eq' - missing value after operator",
              "instance": "/api/entity"
            }
          },
          "missingParameter": {
            "summary": "Missing required parameter",
            "value": {
              "type": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400",
              "title": "Bad Request",
              "status": 400,
              "detail": "Missing required parameter: entity_id",
              "instance": "/api/entity/create"
            }
          }
        }
      }
    }
  },
  "UnauthorizedExample": {
    "description": "Unauthorized - Authentication required",
    "content": {
      "application/problem+json": {
        "schema": {
          "$ref": "#/components/schemas/ProblemDetails"
        },
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
  "NotFoundExample": {
    "description": "Not Found - Resource does not exist",
    "content": {
      "application/problem+json": {
        "schema": {
          "$ref": "#/components/schemas/ProblemDetails"
        },
        "example": {
          "type": "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404",
          "title": "Not Found",
          "status": 404,
          "detail": "Entity with ID 'SysNDD:9999' not found",
          "instance": "/api/entity/SysNDD:9999"
        }
      }
    }
  }
}
```

---

### Phase 3: Migrate Existing Content

#### Task 3.1: Create `api/config/openapi/endpoints/entity-create.json`

Migrate content from existing `api_spec.json`:

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
                  "example": {
                    "entity": {
                      "hgnc_id": "HGNC:1511",
                      "disease_ontology_id_version": "MONDO:0002254",
                      "hpo_mode_of_inheritance_term": "HP:0000007",
                      "ndd_phenotype": 1
                    },
                    "review": {
                      "synopsis": "Synopsis: Short summary for this disease entity.",
                      "literature": {
                        "additional_references": [],
                        "gene_review": []
                      },
                      "phenotypes": [
                        {"phenotype_id": "HP:0001249", "modifier_id": "1"},
                        {"phenotype_id": "HP:0000478", "modifier_id": "1"},
                        {"phenotype_id": "HP:0000077", "modifier_id": "1"}
                      ],
                      "variation_ontology": {
                        "vario_id": "VariO:0001",
                        "modifier_id": "1"
                      },
                      "comment": ""
                    },
                    "status": {
                      "category_id": 1,
                      "comment": "",
                      "problematic": 0
                    }
                  }
                }
              }
            }
          }
        }
      },
      "responses": {
        "200": {
          "description": "Entity created successfully",
          "content": {
            "application/json": {
              "schema": {
                "type": "object",
                "properties": {
                  "status": {"type": "string", "example": "success"},
                  "message": {"type": "string", "example": "Entity created successfully"},
                  "entity_id": {"type": "integer", "example": 3680}
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

---

### Phase 4: Update Startup Code

#### Task 4.1: Modify `api/start_sysndd_api.R`

**Before** (current):
```r
source("functions/config-functions.R")
# ... later ...
pr_set_api_spec(function(spec) {
  version_info <- fromJSON("version_spec.json")
  spec$info$title <- version_info$title
  spec$info$description <- version_info$description
  spec$info$version <- version_info$version

  if (!is.null(version_info$contact)) {
    spec$info$contact <- version_info$contact
  }
  if (!is.null(version_info$license)) {
    spec$info$license <- version_info$license
  }

  spec$components$securitySchemes$bearerAuth$type <- "http"
  spec$components$securitySchemes$bearerAuth$scheme <- "bearer"
  spec$components$securitySchemes$bearerAuth$bearerFormat <- "JWT"
  spec$security[[1]]$bearerAuth <- ""

  # Insert example requests from your api_spec.json (optional)
  spec <- update_api_spec_examples(spec, api_spec)
  spec
})
```

**After** (new):
```r
source("functions/config-functions.R")
source("functions/openapi-helpers.R")  # NEW
# ... later ...
pr_set_api_spec(function(spec) {
  # Version info from JSON (unchanged)
  version_info <- fromJSON("version_spec.json")
  spec$info$title <- version_info$title
  spec$info$description <- version_info$description
  spec$info$version <- version_info$version

  if (!is.null(version_info$contact)) {
    spec$info$contact <- version_info$contact
  }
  if (!is.null(version_info$license)) {
    spec$info$license <- version_info$license
  }

  # Security schemes (unchanged)
  spec$components$securitySchemes$bearerAuth$type <- "http"
  spec$components$securitySchemes$bearerAuth$scheme <- "bearer"
  spec$components$securitySchemes$bearerAuth$bearerFormat <- "JWT"
  spec$security[[1]]$bearerAuth <- ""

  # NEW: Enhance with modular schemas, responses, and examples
  spec <- enhance_openapi_spec(spec, config_dir = "config/openapi")

  spec
})
```

**Note**: Remove the `update_api_spec_examples(spec, api_spec)` call and the `api_spec` variable loading once migration is complete.

---

### Phase 5: Testing

#### Task 5.1: Create `api/tests/testthat/test-openapi-helpers.R`

```r
# tests/testthat/test-openapi-helpers.R

test_that("load_openapi_json_files loads and merges JSON files", {
  # Create temp directory with test files
 temp_dir <- tempdir()
  schemas_dir <- file.path(temp_dir, "test_schemas")
  dir.create(schemas_dir, showWarnings = FALSE)

  # Write test schema
  writeLines(
    '{"TestSchema": {"type": "object"}}',
    file.path(schemas_dir, "test.json")
  )

  result <- load_openapi_json_files(schemas_dir)

  expect_true("TestSchema" %in% names(result))
  expect_equal(result$TestSchema$type, "object")

  # Cleanup
  unlink(schemas_dir, recursive = TRUE)
})

test_that("merge_openapi_lists merges nested structures correctly", {
  base <- list(a = list(b = 1, c = 2))
  overlay <- list(a = list(c = 3, d = 4))

  result <- merge_openapi_lists(base, overlay)

  expect_equal(result$a$b, 1)  # Preserved from base
 expect_equal(result$a$c, 3)  # Overwritten by overlay
  expect_equal(result$a$d, 4)  # Added from overlay
})

test_that("create_error_response creates valid RFC 9457 reference", {
  response <- create_error_response("Test error")

  expect_equal(response$description, "Test error")
  expect_true("application/problem+json" %in% names(response$content))
  expect_equal(
    response$content$`application/problem+json`$schema$`$ref`,
    "#/components/schemas/ProblemDetails"
  )
})

test_that("enhance_openapi_spec adds schemas and responses", {
  skip_if_not(dir.exists("config/openapi"), "OpenAPI config not found")

  # Minimal spec
  spec <- list(
    openapi = "3.0.0",
    paths = list(
      "/api/test" = list(
        get = list(
          responses = list("200" = list(description = "OK"))
        )
      )
    ),
    components = list()
  )

  result <- enhance_openapi_spec(spec)

  # Check schemas were added
  expect_true("ProblemDetails" %in% names(result$components$schemas))

  # Check responses were added
  expect_true("BadRequest" %in% names(result$components$responses))

  # Check error responses added to endpoint
  expect_true("400" %in% names(result$paths$`/api/test`$get$responses))
  expect_true("500" %in% names(result$paths$`/api/test`$get$responses))
})
```

#### Task 5.2: Create Integration Test

```r
# tests/testthat/test-integration-openapi.R

test_that("OpenAPI spec validates against actual API responses", {
  skip_if_not(exists("test_db_available") && test_db_available, "Database not available")

  # Get an actual error response
  response <- httr::POST(
    "http://localhost:7777/api/llm/regenerate",
    httr::content_type_json(),
    body = "{}"
  )

  expect_equal(httr::status_code(response), 401)
  expect_equal(httr::headers(response)$`content-type`, "application/problem+json")

  body <- httr::content(response, as = "parsed")

  # Verify RFC 9457 structure
  expect_true(all(c("type", "title", "status") %in% names(body)))
  expect_equal(body$status, 401)
  expect_match(body$type, "^https://")
})
```

---

## Implementation Checklist

### Phase 1: Infrastructure
- [ ] Create `api/config/openapi/` directory structure
- [ ] Create `api/functions/openapi-helpers.R`
- [ ] Add unit tests for helper functions

### Phase 2: Core Schemas
- [ ] Create `schemas/problem-details.json` (RFC 9457)
- [ ] Create `schemas/pagination.json` (from `generate_cursor_pag_inf()`)
- [ ] Create `schemas/entity.json` (from API query)
- [ ] Create `responses/error-responses.json` (optional examples)

### Phase 3: Migration
- [ ] Create `endpoints/entity-create.json` from `api_spec.json`
- [ ] Verify request body example still works
- [ ] Mark `api_spec.json` as deprecated

### Phase 4: Integration
- [ ] Update `start_sysndd_api.R` to use `enhance_openapi_spec()`
- [ ] Test with Swagger UI
- [ ] Verify error responses show ProblemDetails schema

### Phase 5: Cleanup
- [ ] Remove old `api_spec.json` and `update_api_spec_examples()` call
- [ ] Run full test suite
- [ ] Update API documentation

---

## Verification Criteria

### Swagger UI Should Show:
1. **Schemas section** with:
   - `ProblemDetails` schema with all RFC 9457 fields
   - `CursorPaginationResponse` schema
   - `CursorPaginationMeta` and `CursorPaginationLinks`

2. **Each endpoint** with:
   - 400, 401, 403, 404, 500 error responses (as applicable)
   - Error responses referencing `ProblemDetails` schema
   - `application/problem+json` content type for errors

3. **POST /api/entity/create**:
   - Request body example (migrated from api_spec.json)
   - Success response schema
   - All error responses

### API Behavior:
- No changes to runtime behavior (already RFC 9457 compliant)
- All existing tests pass
- New tests for helper functions pass

---

## Rollback Plan

If issues arise:
1. Revert `start_sysndd_api.R` changes
2. Remove `source("functions/openapi-helpers.R")` line
3. Restore `update_api_spec_examples(spec, api_spec)` call
4. Config files can remain (no effect without helper)

---

## References

- [OpenAPI Best Practices](https://learn.openapis.org/best-practices.html)
- [OpenAPI Components](https://www.speakeasy.com/openapi/components)
- [Plumber pr_set_api_spec](https://www.rplumber.io/reference/pr_set_api_spec.html)
- [RFC 9457 - Problem Details](https://datatracker.ietf.org/doc/html/rfc9457)
- [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)

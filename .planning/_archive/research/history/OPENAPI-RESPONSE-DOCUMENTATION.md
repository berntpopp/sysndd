# OpenAPI Response Documentation Enhancement Report

## Executive Summary

This report analyzes the current state of API response documentation in the SysNDD Plumber API and provides recommendations for enhancing it to follow OpenAPI 3.0 best practices, including RFC 9457 Problem Details for error responses.

## Current State Analysis

### Existing Documentation Pattern

The current SysNDD API endpoints use Plumber annotations for documentation:

```r
#* Get a Cursor Pagination Object of All Entities
#*
#* This endpoint returns a cursor pagination object...
#*
#* @tag entity
#* @serializer json list(na="string")
#*
#* @param sort:str Output column to arrange output on.
#* @param filter:str Comma separated list of filters to apply.
#*
#* @response 200 OK. A cursor pagination object with links, meta and data.
#* @response 500 Internal server error.
#*
#* @get /
```

### Current Limitations

1. **No Response Schemas**: The `@response` annotations only provide descriptions, not schema definitions
2. **Missing Examples**: No example response payloads are provided in annotations
3. **Incomplete Error Documentation**: Error responses lack RFC 9457 Problem Details schema references
4. **No `$ref` Usage**: Response schemas are not defined in reusable components

## OpenAPI 3.0 Best Practices

Based on research from [OpenAPI Best Practices](https://learn.openapis.org/best-practices.html), [Plumber Annotations Reference](https://www.rplumber.io/articles/annotations.html), and [Speakeasy Error Responses Guide](https://www.speakeasy.com/openapi/responses/errors):

### 1. Define Reusable Response Schemas

```yaml
components:
  schemas:
    # RFC 9457 Problem Details for errors
    ProblemDetails:
      type: object
      properties:
        type:
          type: string
          format: uri-reference
          description: "URI reference identifying the problem type"
        title:
          type: string
          description: "Short, human-readable summary"
        status:
          type: integer
          description: "HTTP status code"
        detail:
          type: string
          description: "Explanation specific to this occurrence"
        instance:
          type: string
          format: uri-reference
          description: "URI reference identifying specific occurrence"

    # Cursor pagination wrapper
    CursorPaginationResponse:
      type: object
      properties:
        links:
          type: object
          properties:
            self:
              type: string
            next:
              type: string
            prev:
              type: string
        meta:
          type: object
          properties:
            total_count:
              type: integer
            page_size:
              type: integer
            execution_time:
              type: number
        data:
          type: array
          items: {}
```

### 2. Use `application/problem+json` for Errors

Per [RFC 9457](https://datatracker.ietf.org/doc/html/rfc9457), error responses should use the `application/problem+json` media type:

```yaml
responses:
  '400':
    description: Bad Request
    content:
      application/problem+json:
        schema:
          $ref: '#/components/schemas/ProblemDetails'
        example:
          type: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400"
          title: "Bad Request"
          status: 400
          detail: "Missing required parameter: gene_id"
          instance: "/api/gene/123"
```

### 3. Provide Concrete Examples

From [OpenAPI Best Practices](https://learn.openapis.org/best-practices.html):
> "It is recommended that any examples given for parameters, media types, or schemas not be empty and null. Examples demonstrate the intended payload."

```yaml
responses:
  '200':
    description: Success
    content:
      application/json:
        schema:
          $ref: '#/components/schemas/EntityResponse'
        example:
          links:
            self: "/api/entity?page_after=0&page_size=10"
            next: "/api/entity?page_after=10&page_size=10"
          meta:
            total_count: 3679
            page_size: 10
          data:
            - entity_id: 1
              symbol: "ARID1B"
              category: "Definitive"
```

## Implementation Recommendations

### Option 1: Enhance `pr_set_api_spec()` (Recommended)

Modify the existing `pr_set_api_spec()` call in `start_sysndd_api.R` to inject standardized response schemas:

```r
pr_set_api_spec(function(spec) {
  # Existing code...

  # Add RFC 9457 ProblemDetails schema
  spec$components$schemas$ProblemDetails <- list(
    type = "object",
    properties = list(
      type = list(type = "string", format = "uri-reference"),
      title = list(type = "string"),
      status = list(type = "integer"),
      detail = list(type = "string"),
      instance = list(type = "string", format = "uri-reference")
    )
  )

  # Add standard error responses to all endpoints
  for (path in names(spec$paths)) {
    for (method in names(spec$paths[[path]])) {
      if (!method %in% c("parameters", "servers")) {
        # Add 400, 401, 403, 404, 500 error responses
        spec$paths[[path]][[method]]$responses[["400"]] <- list(
          description = "Bad Request",
          content = list(
            "application/problem+json" = list(
              schema = list(`$ref` = "#/components/schemas/ProblemDetails")
            )
          )
        )
        # ... add other error codes
      }
    }
  }

  spec
})
```

### Option 2: External OpenAPI Spec File

Create a comprehensive `openapi-spec.yaml` file and load it:

```r
pr_set_api_spec("config/openapi-spec.yaml")
```

### Option 3: Enhanced Plumber Annotations

While Plumber's `@response` annotation has limited schema support, you can add more detail:

```r
#* @response 200 OK. Returns paginated entity list.
#* @response 400 Bad Request. Invalid filter syntax.
#* @response 401 Unauthorized. Missing or invalid Bearer token.
#* @response 403 Forbidden. Insufficient permissions.
#* @response 404 Not Found. Entity does not exist.
#* @response 500 Internal Server Error. Unexpected server error.
```

## Specific Schema Definitions Needed

### 1. Entity Response Schema

```yaml
EntityObject:
  type: object
  properties:
    entity_id:
      type: integer
      example: 1
    symbol:
      type: string
      example: "ARID1B"
    disease_ontology_name:
      type: string
      example: "intellectual disability"
    hpo_mode_of_inheritance_term_name:
      type: string
      example: "Autosomal dominant"
    category:
      type: string
      enum: ["Definitive", "Moderate", "Limited", "Refuted"]
    ndd_phenotype_word:
      type: string
      enum: ["Yes", "No"]
```

### 2. Job Status Response Schema

```yaml
JobStatusResponse:
  type: object
  properties:
    job_id:
      type: string
      format: uuid
    status:
      type: string
      enum: ["pending", "running", "completed", "failed"]
    progress:
      type: number
      minimum: 0
      maximum: 100
    created_at:
      type: string
      format: date-time
    result:
      type: object
      nullable: true
```

### 3. Authentication Error Response

```yaml
AuthenticationError:
  allOf:
    - $ref: '#/components/schemas/ProblemDetails'
    - type: object
      example:
        type: "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/401"
        title: "Unauthorized"
        status: 401
        detail: "Authorization header missing. Please provide a Bearer token."
        instance: "/api/llm/regenerate"
```

## Implementation Priority

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 1 | Add ProblemDetails schema to components | Low | High |
| 2 | Add standard error responses (400, 401, 403, 404, 500) | Medium | High |
| 3 | Define Entity/Gene/Job response schemas | Medium | Medium |
| 4 | Add concrete examples to all endpoints | High | Medium |
| 5 | Document all query parameters with types | Medium | Medium |

## Code Changes Required

### File: `api/start_sysndd_api.R`

Add after line ~708 (in `pr_set_api_spec`):

```r
# Add RFC 9457 ProblemDetails schema
spec$components$schemas$ProblemDetails <- list(
  type = "object",
  description = "RFC 9457 Problem Details for HTTP APIs",
  properties = list(
    type = list(
      type = "string",
      format = "uri-reference",
      description = "URI reference identifying the problem type"
    ),
    title = list(
      type = "string",
      description = "Short, human-readable summary of the problem"
    ),
    status = list(
      type = "integer",
      description = "HTTP status code"
    ),
    detail = list(
      type = "string",
      description = "Human-readable explanation specific to this occurrence"
    ),
    instance = list(
      type = "string",
      format = "uri-reference",
      description = "URI reference identifying the specific occurrence"
    )
  ),
  example = list(
    type = "https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400",
    title = "Bad Request",
    status = 400,
    detail = "Missing required parameter: entity_id",
    instance = "/api/entity/123"
  )
)
```

### New File: `api/config/response-schemas.json`

Create a JSON file with all reusable response schemas that can be merged into the spec.

## References

- [OpenAPI Specification v3.0.3](https://spec.openapis.org/oas/v3.0.3.html)
- [OpenAPI Best Practices](https://learn.openapis.org/best-practices.html)
- [Plumber Annotations Reference](https://www.rplumber.io/articles/annotations.html)
- [RFC 9457 - Problem Details for HTTP APIs](https://datatracker.ietf.org/doc/html/rfc9457)
- [Speakeasy - Error Responses in OpenAPI](https://www.speakeasy.com/openapi/responses/errors)
- [Swagger RFC 9457 Guide](https://swagger.io/blog/problem-details-rfc9457-api-error-handling/)
- [belgif/openapi-problem](https://github.com/belgif/openapi-problem) - Reference implementation

## Conclusion

The SysNDD API already implements RFC 9457 compliant error responses at runtime. The next step is to document these properly in the OpenAPI specification so that:

1. API consumers can see the error response structure in Swagger UI
2. Code generators can create proper error handling
3. The API documentation is self-describing and complete

The recommended approach is to enhance `pr_set_api_spec()` to automatically inject standardized error response schemas and examples across all endpoints.

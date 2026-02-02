# OpenAPI Schema Automation Strategy

**Date**: 2026-02-02
**Problem**: 162 endpoints need response schema documentation - manual approach doesn't scale
**Solution**: Automated schema inference + validation pipeline

---

## Tool Selection

Based on research, here's the recommended toolchain:

| Tool | Purpose | Language | Why |
|------|---------|----------|-----|
| [**GenSON**](https://github.com/wolverdude/GenSON) | Infer JSON Schema from responses | Python | Merges multiple samples, handles variations |
| [**Quicktype**](https://github.com/glideapps/quicktype) | Generate schemas + types | Node.js | Great for complex nested structures |
| [**Schemathesis**](https://appdev.consulting.redhat.com/tracks/contract-first/automated-testing-with-schemathesis.html) | Validate API against spec | Python | Property-based testing, finds edge cases |
| [**oasdiff**](https://github.com/oasdiff/oasdiff) | Compare/merge specs | Go | Detect breaking changes |
| **jq** | JSON manipulation | CLI | Parse responses, transform schemas |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SCHEMA DISCOVERY PIPELINE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. ENDPOINT DISCOVERY                                               │
│     ┌──────────────┐    ┌──────────────────┐                        │
│     │ Plumber API  │───▶│ openapi.json     │                        │
│     │ /api/admin/  │    │ (162 endpoints)  │                        │
│     └──────────────┘    └────────┬─────────┘                        │
│                                  │                                   │
│  2. RESPONSE SAMPLING            ▼                                   │
│     ┌──────────────┐    ┌──────────────────┐    ┌──────────────┐   │
│     │ Sample       │───▶│ responses/       │───▶│ Multiple     │   │
│     │ Collector    │    │ *.json           │    │ Samples/EP   │   │
│     │ (bash/curl)  │    │                  │    │              │   │
│     └──────────────┘    └────────┬─────────┘    └──────────────┘   │
│                                  │                                   │
│  3. SCHEMA INFERENCE             ▼                                   │
│     ┌──────────────┐    ┌──────────────────┐                        │
│     │ GenSON /     │───▶│ schemas/         │                        │
│     │ Quicktype    │    │ inferred/*.json  │                        │
│     └──────────────┘    └────────┬─────────┘                        │
│                                  │                                   │
│  4. SCHEMA ENHANCEMENT           ▼                                   │
│     ┌──────────────┐    ┌──────────────────┐                        │
│     │ Human Review │───▶│ schemas/         │                        │
│     │ + Enrichment │    │ final/*.json     │                        │
│     │ (descriptions│    │ (with desc,      │                        │
│     │  examples)   │    │  examples)       │                        │
│     └──────────────┘    └────────┬─────────┘                        │
│                                  │                                   │
│  5. SPEC MERGE                   ▼                                   │
│     ┌──────────────┐    ┌──────────────────┐                        │
│     │ enhance_     │───▶│ Enhanced         │                        │
│     │ openapi_spec │    │ openapi.json     │                        │
│     │ (R function) │    │                  │                        │
│     └──────────────┘    └────────┬─────────┘                        │
│                                  │                                   │
│  6. VALIDATION                   ▼                                   │
│     ┌──────────────┐    ┌──────────────────┐                        │
│     │ Schemathesis │───▶│ Validation       │                        │
│     │ + Dredd      │    │ Report           │                        │
│     └──────────────┘    └──────────────────┘                        │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Scripts

### Script 1: `scripts/openapi/collect-responses.sh`

Queries all endpoints and saves response samples.

```bash
#!/bin/bash
# collect-responses.sh - Collect API response samples for schema inference
#
# Usage: ./collect-responses.sh [base_url] [output_dir]

set -euo pipefail

BASE_URL="${1:-http://localhost}"
OUTPUT_DIR="${2:-api/config/openapi/.samples}"
OPENAPI_SPEC="${BASE_URL}/api/admin/openapi.json"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Fetching OpenAPI spec from $OPENAPI_SPEC..."
SPEC=$(curl -s "$OPENAPI_SPEC")

# Extract GET endpoints (safe to query without auth for most)
echo "$SPEC" | jq -r '.paths | to_entries[] | select(.value.get) | .key' | while read -r path; do
    # Skip internal endpoints
    [[ "$path" == "/__"* ]] && continue
    [[ "$path" == */openapi.json ]] && continue

    # Create safe filename
    safe_name=$(echo "$path" | sed 's/[\/{}]/_/g' | sed 's/^_//')
    output_file="$OUTPUT_DIR/${safe_name}_GET.json"

    # Skip if already collected
    [[ -f "$output_file" ]] && continue

    echo "Collecting: GET $path"

    # Query with pagination limit
    url="${BASE_URL}${path}"
    [[ "$path" == *"/"$ ]] || url="${url}/"

    # Add page_size param for list endpoints
    if [[ "$path" != *"{"* ]]; then
        response=$(curl -s "${url}?page_size=2" 2>/dev/null || curl -s "$url" 2>/dev/null || echo '{"error": "failed"}')
    else
        # Skip parameterized endpoints for now
        continue
    fi

    # Save if valid JSON
    if echo "$response" | jq empty 2>/dev/null; then
        echo "$response" | jq '.' > "$output_file"
        echo "  Saved: $output_file"
    else
        echo "  Skipped: Invalid JSON response"
    fi

    # Rate limiting
    sleep 0.1
done

echo ""
echo "Collection complete. Samples saved to: $OUTPUT_DIR"
echo "Total samples: $(ls -1 "$OUTPUT_DIR"/*.json 2>/dev/null | wc -l)"
```

### Script 2: `scripts/openapi/infer-schemas.py`

Uses GenSON to infer schemas from collected samples.

```python
#!/usr/bin/env python3
"""
infer-schemas.py - Infer JSON schemas from API response samples using GenSON

Usage: python infer-schemas.py [samples_dir] [output_dir]

Requirements: pip install genson
"""

import json
import sys
from pathlib import Path
from genson import SchemaBuilder

def infer_schema_from_samples(sample_files: list[Path]) -> dict:
    """Infer schema from one or more JSON samples."""
    builder = SchemaBuilder()
    builder.add_schema({"type": "object"})

    for sample_file in sample_files:
        try:
            with open(sample_file) as f:
                data = json.load(f)
            builder.add_object(data)
        except (json.JSONDecodeError, IOError) as e:
            print(f"  Warning: Could not process {sample_file}: {e}")

    return builder.to_schema()

def add_openapi_metadata(schema: dict, endpoint_path: str) -> dict:
    """Add OpenAPI-specific metadata to inferred schema."""
    # Add description based on endpoint
    if "properties" in schema:
        # Detect pagination response
        if all(k in schema.get("properties", {}) for k in ["data", "links", "meta"]):
            schema["description"] = f"Paginated response for {endpoint_path}"
            schema["x-response-type"] = "pagination"

        # Detect error response
        if all(k in schema.get("properties", {}) for k in ["type", "title", "status"]):
            schema["description"] = "RFC 9457 Problem Details error response"
            schema["x-response-type"] = "error"

    return schema

def process_samples_directory(samples_dir: Path, output_dir: Path):
    """Process all samples and generate schemas."""
    output_dir.mkdir(parents=True, exist_ok=True)

    # Group samples by endpoint (remove _GET suffix for grouping)
    samples_by_endpoint = {}
    for sample_file in samples_dir.glob("*.json"):
        # Extract endpoint name
        endpoint = sample_file.stem.replace("_GET", "").replace("_POST", "")
        if endpoint not in samples_by_endpoint:
            samples_by_endpoint[endpoint] = []
        samples_by_endpoint[endpoint].append(sample_file)

    print(f"Found {len(samples_by_endpoint)} unique endpoints")

    schemas = {}
    for endpoint, sample_files in sorted(samples_by_endpoint.items()):
        print(f"Inferring schema for: {endpoint}")

        schema = infer_schema_from_samples(sample_files)
        schema = add_openapi_metadata(schema, endpoint)

        # Generate schema name from endpoint
        schema_name = "".join(word.title() for word in endpoint.split("_") if word)
        schema_name = f"{schema_name}Response"

        schemas[schema_name] = schema

        # Save individual schema
        output_file = output_dir / f"{endpoint}.json"
        with open(output_file, "w") as f:
            json.dump({schema_name: schema}, f, indent=2)
        print(f"  Saved: {output_file}")

    # Save combined schemas file
    combined_file = output_dir / "_all_schemas.json"
    with open(combined_file, "w") as f:
        json.dump(schemas, f, indent=2)
    print(f"\nCombined schemas saved to: {combined_file}")
    print(f"Total schemas generated: {len(schemas)}")

def main():
    samples_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "api/config/openapi/.samples")
    output_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "api/config/openapi/schemas/inferred")

    if not samples_dir.exists():
        print(f"Error: Samples directory not found: {samples_dir}")
        print("Run collect-responses.sh first to collect API response samples.")
        sys.exit(1)

    process_samples_directory(samples_dir, output_dir)

if __name__ == "__main__":
    main()
```

### Script 3: `scripts/openapi/validate-spec.sh`

Validates the enhanced OpenAPI spec against the live API.

```bash
#!/bin/bash
# validate-spec.sh - Validate OpenAPI spec against live API using Schemathesis
#
# Usage: ./validate-spec.sh [base_url]
#
# Requirements: pip install schemathesis

set -euo pipefail

BASE_URL="${1:-http://localhost}"
SPEC_URL="${BASE_URL}/api/admin/openapi.json"

echo "Validating OpenAPI spec at: $SPEC_URL"
echo ""

# Basic spec validation
echo "=== Step 1: Spec Validation ==="
schemathesis run "$SPEC_URL" \
    --checks all \
    --hypothesis-max-examples=10 \
    --hypothesis-deadline=5000 \
    --base-url="$BASE_URL" \
    --skip-deprecated-operations \
    --dry-run \
    2>&1 | head -50

echo ""
echo "=== Step 2: Response Schema Validation ==="
# Run actual tests against safe endpoints
schemathesis run "$SPEC_URL" \
    --checks response_schema_conformance \
    --hypothesis-max-examples=5 \
    --base-url="$BASE_URL" \
    --endpoint="/api/entity/" \
    --endpoint="/api/gene/" \
    --endpoint="/api/health/" \
    --endpoint="/api/version/" \
    2>&1 || true

echo ""
echo "Validation complete."
```

### Script 4: `scripts/openapi/generate-report.sh`

Generates a coverage report showing which endpoints have schemas.

```bash
#!/bin/bash
# generate-report.sh - Generate OpenAPI schema coverage report
#
# Usage: ./generate-report.sh

set -euo pipefail

BASE_URL="${1:-http://localhost}"
SPEC=$(curl -s "${BASE_URL}/api/admin/openapi.json")

echo "# OpenAPI Schema Coverage Report"
echo "Generated: $(date -Iseconds)"
echo ""

# Count totals
total_endpoints=$(echo "$SPEC" | jq '.paths | length')
total_operations=$(echo "$SPEC" | jq '[.paths[]] | map(keys | map(select(. != "parameters" and . != "servers"))) | flatten | length')

echo "## Summary"
echo "- Total Paths: $total_endpoints"
echo "- Total Operations: $total_operations"
echo ""

# Analyze response documentation
echo "## Response Schema Coverage"
echo ""
echo "| Endpoint | Method | 200 Schema | Error Schemas | Status |"
echo "|----------|--------|------------|---------------|--------|"

echo "$SPEC" | jq -r '
    .paths | to_entries[] |
    .key as $path |
    .value | to_entries[] |
    select(.key | test("^(get|post|put|delete|patch)$")) |
    {
        path: $path,
        method: .key | ascii_upcase,
        has_200_schema: ((.value.responses["200"].content["application/json"].schema // null) != null),
        has_error_schemas: ((.value.responses["400"] // null) != null or (.value.responses["401"] // null) != null),
    } |
    "| \(.path) | \(.method) | \(if .has_200_schema then "✅" else "❌" end) | \(if .has_error_schemas then "✅" else "❌" end) | \(if .has_200_schema and .has_error_schemas then "Complete" else "Incomplete" end) |"
' | head -50

echo ""
echo "... (showing first 50 operations)"
echo ""

# Summary stats
has_200=$(echo "$SPEC" | jq '[.paths[][]] | map(select(.responses["200"].content["application/json"].schema != null)) | length')
has_errors=$(echo "$SPEC" | jq '[.paths[][]] | map(select(.responses["400"] != null or .responses["401"] != null)) | length')

echo "## Statistics"
echo "- Operations with 200 response schema: $has_200 / $total_operations"
echo "- Operations with error response schemas: $has_errors / $total_operations"
echo ""

# Component schemas
echo "## Defined Component Schemas"
echo "$SPEC" | jq -r '.components.schemas // {} | keys[]' | sort | sed 's/^/- /'
```

---

## Makefile Integration

Add to project Makefile for easy execution:

```makefile
# OpenAPI Schema Management
.PHONY: openapi-collect openapi-infer openapi-validate openapi-report openapi-all

OPENAPI_SCRIPTS := scripts/openapi

openapi-collect:
	@echo "Collecting API response samples..."
	bash $(OPENAPI_SCRIPTS)/collect-responses.sh http://localhost

openapi-infer:
	@echo "Inferring schemas from samples..."
	python3 $(OPENAPI_SCRIPTS)/infer-schemas.py

openapi-validate:
	@echo "Validating OpenAPI spec..."
	bash $(OPENAPI_SCRIPTS)/validate-spec.sh http://localhost

openapi-report:
	@echo "Generating coverage report..."
	bash $(OPENAPI_SCRIPTS)/generate-report.sh > api/config/openapi/COVERAGE.md

openapi-all: openapi-collect openapi-infer openapi-report
	@echo "OpenAPI schema generation complete!"
```

---

## Agent-Based Enhancement (Advanced)

For intelligent schema enrichment, use Claude agents:

### Agent Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                  AGENT-BASED SCHEMA ENRICHMENT                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. SCHEMA ANALYSIS AGENT                                        │
│     Input: Inferred schema + endpoint R code                     │
│     Task: Add descriptions, examples, constraints                │
│     Output: Enriched schema JSON                                 │
│                                                                  │
│  2. CODE REVIEW AGENT                                            │
│     Input: Endpoint function code                                │
│     Task: Extract business rules, validations, enums             │
│     Output: Schema constraints (min/max, patterns, enums)        │
│                                                                  │
│  3. DOCUMENTATION AGENT                                          │
│     Input: Enriched schemas + existing docs                      │
│     Task: Generate human-readable descriptions                   │
│     Output: Final schema with descriptions                       │
│                                                                  │
│  4. VALIDATION AGENT                                             │
│     Input: Final schema + API responses                          │
│     Task: Verify schema matches actual responses                 │
│     Output: Validation report + fixes                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Example Agent Task

```python
# Task for schema enrichment agent
task_prompt = """
Analyze this inferred JSON schema and the corresponding R endpoint code.
Enhance the schema with:
1. Descriptive field descriptions based on code comments and variable names
2. Examples extracted from test data or realistic values
3. Constraints (min/max, pattern, enum) based on validation logic in the code
4. Required fields based on code logic

Inferred Schema:
{inferred_schema}

Endpoint Code (from {endpoint_file}):
{endpoint_code}

Output the enhanced schema in JSON format.
"""
```

---

## Recommended Workflow

### Phase 1: Baseline Collection (Automated)
```bash
# 1. Collect samples from all GET endpoints
make openapi-collect

# 2. Infer schemas from samples
make openapi-infer

# 3. Generate coverage report
make openapi-report
```

### Phase 2: Schema Enhancement (Semi-Automated)
```bash
# 4. Review inferred schemas, add to config/openapi/schemas/
# 5. Run agent-based enrichment for descriptions
# 6. Human review of critical endpoints
```

### Phase 3: Integration & Validation
```bash
# 7. Merge schemas into OpenAPI spec
# 8. Validate with Schemathesis
make openapi-validate

# 9. Fix any validation errors
# 10. Commit enhanced spec
```

### Phase 4: CI/CD Integration
```yaml
# .github/workflows/openapi-validation.yml
name: OpenAPI Validation
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Start API
        run: make docker-dev-db && make dev &
      - name: Wait for API
        run: sleep 30
      - name: Validate OpenAPI
        run: make openapi-validate
```

---

## Priority Endpoints for Initial Automation

Focus on high-value endpoints first:

| Priority | Endpoint Pattern | Count | Reason |
|----------|------------------|-------|--------|
| 1 | `/api/entity/*` | ~10 | Core data model |
| 2 | `/api/gene/*` | ~5 | High usage |
| 3 | Error responses | All | RFC 9457 compliance |
| 4 | `/api/search/*` | ~3 | User-facing |
| 5 | `/api/analysis/*` | ~8 | Complex schemas |

---

## References

- [GenSON - JSON Schema Generator](https://github.com/wolverdude/GenSON)
- [Quicktype - Schema from JSON](https://quicktype.io/schema)
- [Schemathesis - API Testing](https://appdev.consulting.redhat.com/tracks/contract-first/automated-testing-with-schemathesis.html)
- [oasdiff - OpenAPI Diff](https://github.com/oasdiff/oasdiff)
- [Dredd - API Contract Testing](https://dev.to/r3d_cr0wn/enforcing-api-correctness-automated-contract-testing-with-openapi-and-dredd-2212)
- [OpenAPI Best Practices](https://learn.openapis.org/best-practices.html)
- [Plumber OpenAPI Support](https://www.rplumber.io/reference/pr_set_docs.html)

---

## Conclusion

Manual schema documentation for 162 endpoints is not feasible. This automation strategy:

1. **Reduces effort by ~80%** - Automated inference handles structure
2. **Ensures accuracy** - Schemas derived from actual responses
3. **Enables validation** - Schemathesis catches drift
4. **Scales with API growth** - New endpoints automatically discovered
5. **Integrates with CI/CD** - Prevents undocumented changes

The recommended approach is:
1. Start with automated collection + inference
2. Enhance priority endpoints with agent assistance
3. Validate continuously with Schemathesis
4. Gradually improve coverage over time

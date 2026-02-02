# OpenAPI Schema Automation Tools

Scripts for collecting API response samples and inferring JSON schemas for OpenAPI documentation.

## Overview

These tools automate the process of enhancing OpenAPI response documentation by:

1. **Collecting** real API response samples from running endpoints
2. **Inferring** JSON schemas from those samples using GenSON
3. **Generating** coverage reports to track documentation progress

## Prerequisites

- **curl** - HTTP requests
- **jq** - JSON processing
- **Python 3.6+** - For schema inference
- **genson** - Python library for JSON schema inference

```bash
# Install Python dependency
pip install genson
```

## Scripts

### collect-responses.sh

Collects API response samples sequentially from all GET endpoints.

**Usage:**
```bash
./scripts/openapi/collect-responses.sh [base_url] [output_dir]
```

**Arguments:**
| Argument | Default | Description |
|----------|---------|-------------|
| `base_url` | `http://localhost` | API base URL |
| `output_dir` | `api/config/openapi/.samples` | Where to save JSON samples |

**Example:**
```bash
# Collect from local development server
./scripts/openapi/collect-responses.sh

# Collect from production
./scripts/openapi/collect-responses.sh https://sysndd.dbmr.unibe.ch
```

**Behavior:**
- Fetches OpenAPI spec to discover endpoints
- Skips internal endpoints (`/__*`, `openapi.json`)
- Skips parameterized endpoints (`{id}`, `{symbol}`)
- Skips already-collected samples (incremental)
- Uses `page_size=2` for list endpoints to reduce response size
- Handles trailing slash redirects automatically

---

### parallel-collect.sh

Faster parallel collection using `xargs` for large APIs.

**Usage:**
```bash
./scripts/openapi/parallel-collect.sh [base_url] [output_dir] [parallelism]
```

**Arguments:**
| Argument | Default | Description |
|----------|---------|-------------|
| `base_url` | `http://localhost` | API base URL |
| `output_dir` | `api/config/openapi/.samples` | Where to save JSON samples |
| `parallelism` | `10` | Number of concurrent requests |

**Example:**
```bash
# Fast collection with 20 parallel requests
./scripts/openapi/parallel-collect.sh http://localhost api/config/openapi/.samples 20
```

**Behavior:**
- Same filtering as `collect-responses.sh`
- Skips files >50 bytes (valid cached responses)
- 10-second timeout per request
- Prints OK/SKIP status for each endpoint

---

### infer-schemas.py

Infers JSON schemas from collected response samples using GenSON.

**Usage:**
```bash
python scripts/openapi/infer-schemas.py [samples_dir] [output_dir]
```

**Arguments:**
| Argument | Default | Description |
|----------|---------|-------------|
| `samples_dir` | `api/config/openapi/.samples` | Directory with JSON samples |
| `output_dir` | `api/config/openapi/schemas/inferred` | Where to save inferred schemas |

**Example:**
```bash
# Infer schemas from collected samples
python scripts/openapi/infer-schemas.py
```

**Output:**
- Individual schema files: `{endpoint}_GET.json`
- Combined schemas: `_all_inferred_schemas.json`
- Schema names in PascalCase: `api_health_GET` → `HealthResponse`

**Response Type Detection:**
| Type | Detection Criteria |
|------|-------------------|
| `pagination` | Has `data`, `links`, `meta` properties |
| `error` | Has `type`, `title`, `status` (RFC 9457) |
| `message` | Has `message` with ≤2 properties |
| `array` | Root type is array |
| `object` | Default for other objects |

---

### generate-report.sh

Generates a Markdown coverage report for OpenAPI documentation.

**Usage:**
```bash
./scripts/openapi/generate-report.sh [base_url] > COVERAGE.md
```

**Arguments:**
| Argument | Default | Description |
|----------|---------|-------------|
| `base_url` | `http://localhost` | API base URL |

**Example:**
```bash
# Generate report and save
./scripts/openapi/generate-report.sh > api/config/openapi/COVERAGE.md

# View report in terminal
./scripts/openapi/generate-report.sh | less
```

**Report Contents:**
- Summary counts (paths, GET, POST operations)
- Schema coverage percentages
- List of defined component schemas
- Endpoints missing response schemas

---

## Complete Workflow

Run the full pipeline to update OpenAPI schemas:

```bash
# 1. Ensure API is running
docker compose up -d

# 2. Collect response samples (parallel for speed)
./scripts/openapi/parallel-collect.sh http://localhost

# 3. Infer schemas from samples
python scripts/openapi/infer-schemas.py

# 4. Generate coverage report
./scripts/openapi/generate-report.sh > api/config/openapi/COVERAGE.md

# 5. Restart API to load new schemas
docker compose restart api
```

## Output Files

After running the pipeline:

```
api/config/openapi/
├── .samples/                    # Raw API response samples
│   ├── api_health_GET.json
│   ├── api_entity_GET.json
│   └── ...
├── schemas/
│   ├── inferred/               # Auto-generated schemas
│   │   ├── api_health_GET.json
│   │   ├── _all_inferred_schemas.json
│   │   └── ...
│   └── problem-details.json    # RFC 9457 error schema
└── COVERAGE.md                 # Coverage report
```

## Integration with API

The inferred schemas are loaded by `api/functions/openapi-helpers.R`:

1. `enhance_openapi_spec()` loads schemas from `config/openapi/schemas/`
2. Schemas are injected into the OpenAPI spec at startup
3. Swagger UI displays response schemas for each endpoint

## Notes

- **Incremental updates**: Scripts skip already-collected samples
- **Parameterized endpoints**: Must be collected manually with real IDs
- **Auth-protected endpoints**: Require authentication headers (not automated)
- **Large responses**: Some endpoints return large datasets; samples are truncated with `page_size=2`

#!/bin/bash
# generate-report.sh - Generate OpenAPI schema coverage report
#
# Usage: ./generate-report.sh [base_url]

set -euo pipefail

BASE_URL="${1:-http://localhost}"
SPEC=$(curl -s "${BASE_URL}/api/admin/openapi.json")

echo "# OpenAPI Schema Coverage Report"
echo ""
echo "**Generated**: $(date -Iseconds)"
echo "**API Base**: $BASE_URL"
echo ""

# Count totals
total_paths=$(echo "$SPEC" | jq '.paths | length')
total_get=$(echo "$SPEC" | jq '[.paths[] | select(.get)] | length')
total_post=$(echo "$SPEC" | jq '[.paths[] | select(.post)] | length')

echo "## Summary"
echo ""
echo "| Metric | Count |"
echo "|--------|-------|"
echo "| Total Paths | $total_paths |"
echo "| GET Operations | $total_get |"
echo "| POST Operations | $total_post |"
echo ""

# Count schema coverage
has_200_schema=$(echo "$SPEC" | jq '[.paths[][].responses["200"] // empty | select(.content["application/json"].schema != null)] | length')
has_error_schema=$(echo "$SPEC" | jq '[.paths[][] | select(.responses["400"] != null or .responses["401"] != null)] | length')

echo "## Current Coverage"
echo ""
echo "| Type | Covered | Total | Percentage |"
echo "|------|---------|-------|------------|"
echo "| 200 Response Schemas | $has_200_schema | $((total_get + total_post)) | $((has_200_schema * 100 / (total_get + total_post)))% |"
echo "| Error Response Schemas | $has_error_schema | $((total_get + total_post)) | $((has_error_schema * 100 / (total_get + total_post)))% |"
echo ""

# List component schemas
echo "## Defined Component Schemas"
echo ""
schemas=$(echo "$SPEC" | jq -r '.components.schemas // {} | keys[]' 2>/dev/null | sort)
if [[ -n "$schemas" ]]; then
    echo "$schemas" | while read -r schema; do
        echo "- \`$schema\`"
    done
else
    echo "_No component schemas defined yet_"
fi
echo ""

# List endpoints missing schemas
echo "## Endpoints Missing Response Schemas (Top 30)"
echo ""
echo "| Path | Method | Issue |"
echo "|------|--------|-------|"

echo "$SPEC" | jq -r '
    .paths | to_entries[] |
    .key as $path |
    .value | to_entries[] |
    select(.key | test("^(get|post)$")) |
    select(.value.responses["200"].content["application/json"].schema == null) |
    "| `\($path)` | \(.key | ascii_upcase) | No 200 schema |"
' | head -30

echo ""
echo "_Showing top 30 of $(echo "$SPEC" | jq '[.paths | to_entries[] | .value | to_entries[] | select(.key | test("^(get|post)$")) | select(.value.responses["200"].content["application/json"].schema == null)] | length') endpoints missing schemas_"

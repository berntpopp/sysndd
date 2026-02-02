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

# Get total endpoint count
TOTAL=$(echo "$SPEC" | jq -r '.paths | to_entries[] | select(.value.get) | .key' | grep -v "^/__" | wc -l)
echo "Found $TOTAL GET endpoints to sample"
echo ""

COUNT=0
SKIPPED=0
COLLECTED=0

# Extract GET endpoints (safe to query without auth for most)
echo "$SPEC" | jq -r '.paths | to_entries[] | select(.value.get) | .key' | while read -r path; do
    COUNT=$((COUNT + 1))

    # Skip internal endpoints
    [[ "$path" == "/__"* ]] && { SKIPPED=$((SKIPPED + 1)); continue; }
    [[ "$path" == */openapi.json ]] && { SKIPPED=$((SKIPPED + 1)); continue; }

    # Create safe filename
    safe_name=$(echo "$path" | sed 's/[\/{}]/_/g' | sed 's/^_//' | sed 's/_$//')
    output_file="$OUTPUT_DIR/${safe_name}_GET.json"

    # Skip if already collected (for incremental runs)
    if [[ -f "$output_file" ]]; then
        echo "[$COUNT/$TOTAL] Skip (cached): $path"
        continue
    fi

    # Skip parameterized endpoints (need specific IDs)
    if [[ "$path" == *"{"* ]]; then
        echo "[$COUNT/$TOTAL] Skip (parameterized): $path"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "[$COUNT/$TOTAL] Collecting: GET $path"

    # Build URL - handle trailing slash requirement
    url="${BASE_URL}${path}"

    # Try with page_size param for list endpoints, fall back to plain request
    response=$(curl -s "${url}?page_size=2" 2>/dev/null || curl -s "$url" 2>/dev/null || echo '{"_error": "request_failed"}')

    # Handle redirect message
    if echo "$response" | jq -e '.message | test("Redirect")' >/dev/null 2>&1; then
        # Try with trailing slash
        response=$(curl -s "${url}/?page_size=2" 2>/dev/null || echo '{"_error": "redirect_failed"}')
    fi

    # Save if valid JSON and not an error
    if echo "$response" | jq -e 'has("_error") | not' >/dev/null 2>&1; then
        echo "$response" | jq '.' > "$output_file"
        COLLECTED=$((COLLECTED + 1))
    else
        echo "  Warning: Failed to collect $path"
    fi

    # Minimal rate limiting
    sleep 0.05
done

echo ""
echo "Collection complete!"
echo "Samples directory: $OUTPUT_DIR"
echo "Total samples: $(ls -1 "$OUTPUT_DIR"/*.json 2>/dev/null | wc -l)"

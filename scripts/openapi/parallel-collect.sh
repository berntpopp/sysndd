#!/bin/bash
# parallel-collect.sh - Collect API responses in parallel using xargs
#
# Usage: ./parallel-collect.sh [base_url] [output_dir] [parallelism]

set -euo pipefail

BASE_URL="${1:-http://localhost}"
OUTPUT_DIR="${2:-api/config/openapi/.samples}"
PARALLEL="${3:-10}"
OPENAPI_SPEC="${BASE_URL}/api/admin/openapi.json"

mkdir -p "$OUTPUT_DIR"

echo "Fetching endpoint list..."
ENDPOINTS=$(curl -s "$OPENAPI_SPEC" | jq -r '
    .paths | to_entries[] |
    select(.value.get) |
    .key |
    select(startswith("/__") | not) |
    select(contains("{") | not) |
    select(endswith("openapi.json") | not)
')

TOTAL=$(echo "$ENDPOINTS" | wc -l)
echo "Found $TOTAL endpoints to collect"
echo "Running with parallelism: $PARALLEL"
echo ""

# Create a function for parallel execution
collect_endpoint() {
    local path="$1"
    local base_url="$2"
    local output_dir="$3"

    # Create safe filename
    safe_name=$(echo "$path" | sed 's/[\/{}]/_/g' | sed 's/^_//' | sed 's/_$//')
    output_file="$output_dir/${safe_name}_GET.json"

    # Skip if exists and is valid
    if [[ -f "$output_file" ]]; then
        size=$(wc -c < "$output_file")
        # Skip only if file is larger than 50 bytes (not a 404 error)
        if [[ $size -gt 50 ]]; then
            return 0
        fi
    fi

    # Build URL - the key is to try different formats
    url="${base_url}${path}"

    # Try multiple URL formats:
    # 1. Without trailing slash, with page_size
    # 2. With trailing slash (for endpoints that require it)
    # 3. Plain URL
    response=""

    # If path ends with /, it likely needs the trailing slash
    if [[ "$path" == */ ]]; then
        response=$(curl -s --max-time 10 "${url}?page_size=2" 2>/dev/null)
    else
        # Try without trailing slash first
        response=$(curl -s --max-time 10 "${url}?page_size=2" 2>/dev/null)

        # If we get a redirect message, try with trailing slash
        if echo "$response" | grep -q "Redirect" 2>/dev/null; then
            response=$(curl -s --max-time 10 "${url}/?page_size=2" 2>/dev/null)
        fi

        # If still empty or error, try plain URL
        if [[ -z "$response" ]] || echo "$response" | grep -q '"error"' 2>/dev/null; then
            response=$(curl -s --max-time 10 "$url" 2>/dev/null)
        fi
    fi

    # Check if we got valid content (not an error)
    if [[ -n "$response" ]] && ! echo "$response" | grep -q '"error".*404' 2>/dev/null; then
        if echo "$response" | jq -e 'type' >/dev/null 2>&1; then
            echo "$response" | jq '.' > "$output_file"
            echo "OK: $path"
            return 0
        fi
    fi

    echo "SKIP: $path (404 or invalid)"
}

export -f collect_endpoint

# Run in parallel
echo "$ENDPOINTS" | xargs -P "$PARALLEL" -I {} bash -c "collect_endpoint '{}' '$BASE_URL' '$OUTPUT_DIR'"

echo ""
echo "Collection complete!"
echo "Total samples: $(ls -1 "$OUTPUT_DIR"/*.json 2>/dev/null | wc -l)"
echo "Valid samples (>50 bytes): $(find "$OUTPUT_DIR" -name "*.json" -size +50c | wc -l)"

#!/usr/bin/env python3
"""
infer-schemas.py - Infer JSON schemas from API response samples using GenSON

Usage: python infer-schemas.py [samples_dir] [output_dir]

Requirements: pip install genson
"""

import json
import sys
import re
from pathlib import Path
from collections import defaultdict

try:
    from genson import SchemaBuilder
except ImportError:
    print("Error: genson not installed. Run: pip install genson")
    sys.exit(1)


def infer_schema_from_samples(sample_files: list) -> dict:
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


def clean_schema_for_openapi(schema: dict) -> dict:
    """
    Clean up GenSON-generated schema for OpenAPI 3.0 compatibility.

    Fixes:
    1. Removes $schema field (not valid in OpenAPI 3.0)
    2. Cleans up anyOf arrays by removing empty { "type": "object" } options
    3. Simplifies anyOf with single remaining option to use that option directly
    4. Recursively processes nested schemas
    """
    if not isinstance(schema, dict):
        return schema

    # Remove $schema field (not valid in OpenAPI 3.0)
    if "$schema" in schema:
        del schema["$schema"]

    # Clean up anyOf arrays
    if "anyOf" in schema and isinstance(schema["anyOf"], list):
        # Filter out empty object types like { "type": "object" } with no properties
        cleaned_options = []
        for option in schema["anyOf"]:
            # Skip empty object schemas (just { "type": "object" } with no properties)
            if (isinstance(option, dict) and
                option.get("type") == "object" and
                "properties" not in option and
                "additionalProperties" not in option and
                len(option) == 1):
                continue
            cleaned_options.append(option)

        if len(cleaned_options) == 0:
            # All options were empty, keep a basic object type
            schema["type"] = "object"
            del schema["anyOf"]
        elif len(cleaned_options) == 1:
            # Only one option left, replace anyOf with that option
            single_option = cleaned_options[0]
            del schema["anyOf"]
            # Merge the single option into the schema
            for key, value in single_option.items():
                if key not in schema:  # Don't overwrite existing fields like description
                    schema[key] = value
        else:
            schema["anyOf"] = cleaned_options

    # Recursively clean nested schemas
    if "properties" in schema and isinstance(schema["properties"], dict):
        for prop_name, prop_schema in schema["properties"].items():
            schema["properties"][prop_name] = clean_schema_for_openapi(prop_schema)

    if "items" in schema:
        if isinstance(schema["items"], dict):
            schema["items"] = clean_schema_for_openapi(schema["items"])
        elif isinstance(schema["items"], list):
            schema["items"] = [clean_schema_for_openapi(item) for item in schema["items"]]

    if "additionalProperties" in schema and isinstance(schema["additionalProperties"], dict):
        schema["additionalProperties"] = clean_schema_for_openapi(schema["additionalProperties"])

    # Clean anyOf/oneOf/allOf recursively
    for keyword in ["anyOf", "oneOf", "allOf"]:
        if keyword in schema and isinstance(schema[keyword], list):
            schema[keyword] = [clean_schema_for_openapi(opt) for opt in schema[keyword]]

    return schema


def detect_response_type(schema: dict) -> str:
    """Detect the type of response based on schema structure."""
    props = schema.get("properties", {})

    # Pagination response
    if all(k in props for k in ["data", "links", "meta"]):
        return "pagination"

    # Error response (RFC 9457)
    if all(k in props for k in ["type", "title", "status"]):
        return "error"

    # Simple message
    if "message" in props and len(props) <= 2:
        return "message"

    # Array response
    if schema.get("type") == "array":
        return "array"

    return "object"


def endpoint_to_schema_name(endpoint: str) -> str:
    """Convert endpoint path to PascalCase schema name."""
    # Remove api prefix and clean up
    clean = endpoint.replace("api_", "").replace("_GET", "").replace("_POST", "")
    # Split and capitalize
    parts = [p for p in clean.split("_") if p]
    name = "".join(word.capitalize() for word in parts)
    return f"{name}Response"


def add_openapi_metadata(schema: dict, endpoint_path: str, response_type: str) -> dict:
    """Add OpenAPI-specific metadata to inferred schema."""

    type_descriptions = {
        "pagination": f"Paginated list response with cursor navigation",
        "error": "RFC 9457 Problem Details error response",
        "message": "Simple message response",
        "array": "Array response",
        "object": "Object response"
    }

    schema["description"] = type_descriptions.get(response_type, "API response")
    schema["x-inferred-from"] = endpoint_path
    schema["x-response-type"] = response_type

    return schema


def enhance_pagination_schema(schema: dict) -> dict:
    """Add detailed descriptions to pagination schema fields."""
    props = schema.get("properties", {})

    if "links" in props:
        props["links"]["description"] = "Navigation links for cursor-based pagination"
    if "meta" in props:
        props["meta"]["description"] = "Pagination metadata including counts and field specifications"
    if "data" in props:
        props["data"]["description"] = "Array of result objects"

    return schema


def process_samples_directory(samples_dir: Path, output_dir: Path):
    """Process all samples and generate schemas."""
    output_dir.mkdir(parents=True, exist_ok=True)

    # Find all sample files
    sample_files = list(samples_dir.glob("*.json"))
    if not sample_files:
        print(f"No sample files found in {samples_dir}")
        return

    print(f"Found {len(sample_files)} sample files")
    print("")

    # Group samples by endpoint pattern
    samples_by_endpoint = defaultdict(list)
    for sample_file in sample_files:
        endpoint = sample_file.stem
        samples_by_endpoint[endpoint].append(sample_file)

    print(f"Processing {len(samples_by_endpoint)} unique endpoints...")
    print("")

    all_schemas = {}
    response_types = defaultdict(int)

    for endpoint, files in sorted(samples_by_endpoint.items()):
        print(f"Inferring: {endpoint}")

        # Infer schema
        schema = infer_schema_from_samples(files)

        # Clean up for OpenAPI 3.0 compatibility (remove $schema, fix anyOf, etc.)
        schema = clean_schema_for_openapi(schema)

        # Detect response type
        response_type = detect_response_type(schema)
        response_types[response_type] += 1

        # Add metadata
        schema = add_openapi_metadata(schema, endpoint, response_type)

        # Enhance pagination schemas
        if response_type == "pagination":
            schema = enhance_pagination_schema(schema)

        # Generate schema name
        schema_name = endpoint_to_schema_name(endpoint)

        all_schemas[schema_name] = schema

        # Save individual schema file
        output_file = output_dir / f"{endpoint}.json"
        with open(output_file, "w") as f:
            json.dump({schema_name: schema}, f, indent=2)

        print(f"  -> {schema_name} ({response_type})")

    # Save combined schemas
    combined_file = output_dir / "_all_inferred_schemas.json"
    with open(combined_file, "w") as f:
        json.dump(all_schemas, f, indent=2)

    # Print summary
    print("")
    print("=" * 50)
    print("SCHEMA INFERENCE COMPLETE")
    print("=" * 50)
    print(f"Total schemas: {len(all_schemas)}")
    print(f"Output directory: {output_dir}")
    print("")
    print("Response types detected:")
    for rtype, count in sorted(response_types.items(), key=lambda x: -x[1]):
        print(f"  {rtype}: {count}")
    print("")
    print(f"Combined schemas: {combined_file}")


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

// app/src/api/entity-variation-wire.ts
//
// Wire-shape normalization for the #608 variation-ontology provenance payloads.
//
// WHY THIS MODULE EXISTS
// ----------------------
// The API is R/Plumber. Its JSON serializer does NOT auto-unbox length-1
// vectors, so every scalar built with `list(...)` in R arrives on the wire as a
// LENGTH-1 ARRAY. For the three provenance routes that means the real payload of
// `GET /api/entity/<id>/variation` is:
//
//   "provenance": { "state": ["active_unconfirmed"], "max_strength": [1],
//                   "sources": [ { "source_type": ["external_database"],
//                                  "source_key":  ["clinvar"],
//                                  "strength":    [1],
//                                  "summary":     ["2 ClinVar records, max 1 star"] } ] }
//
// while `app/src/api/entity.ts` declares `state: string`, `strength: number |
// null` and so on. Left unnormalized, the typed client asserts primitives and
// hands back arrays — TypeScript then actively lies to every consumer.
//
// THE BUG THAT PROVES IT MATTERS
// -----------------------------
// Most consumers survived the mismatch by accident, because JS coerces a
// length-1 array to its element (`Number([1])` -> 1, `String(["x"])` -> "x").
// A STRICT EQUALITY test does not coerce: `partitionVariationZones()` compared
// `provenance?.state === 'active_unconfirmed'` against `["active_unconfirmed"]`,
// which is `false`, so every machine-derived unconfirmed term was misfiled as
// Confirmed and the "Needs confirmation" zone rendered empty — the deliberate
// review step the whole feature exists to force was invisible (fixed locally in
// commit 6a0ee9ec, then fixed AT THE SOURCE here). Unit tests could not catch it
// because their fixtures used plain unboxed strings.
//
// DO NOT REMOVE THIS AS REDUNDANT. The two downstream consumers
// (`views/pages/components/variationProvenance.ts`,
// `views/curate/composables/useVariationProvenanceZones.ts`) still unwrap
// defensively; because the helper below is idempotent, their unwrapping simply
// becomes a no-op. That belt-and-braces is intentional, not a reason to drop
// either side.
//
// SCOPE — WHAT IS DELIBERATELY NOT NORMALIZED
// -------------------------------------------
//  * `evidence_json` is typed `unknown` on purpose. Its inner shape is a
//    cross-repo contract (the import manifests are produced elsewhere) that the
//    UI probes through alias lists, and the API parses it with
//    `simplifyVector = FALSE`, so nested values are double-wrapped
//    (`matched` arrives as `[["OMIM:615032"]]`). Normalizing it could silently
//    change what the evidence dialog finds. It is passed through UNTOUCHED.
//  * `sources` / `evidence` are genuine JSON arrays that are sometimes length 1,
//    so unwrapping is applied field-by-field to keys the API contract documents
//    as scalars — NEVER blanket-recursively.
//  * The `GET .../variation` row's own columns (`entity_id`, `vario_id`,
//    `vario_name`, `modifier_id`) are data-frame columns, which jsonlite
//    serializes row-wise as real scalars; only the `provenance` list-column
//    needs unboxing.
//
// NULL IS LOAD-BEARING
// --------------------
//  * `provenance: null` means CURATOR-AUTHORED. That absence IS the contract, so
//    `null` stays `null` and a missing `provenance` key stays missing.
//  * `strength` / `max_strength` `null` means NOT RECORDED and must never become
//    `0`, which would assert "we checked, it scored zero".

import type { EntityVariationRow, VariationEvidenceResponse, VariationSuggestion } from './entity';

/**
 * Unwrap Plumber's length-1 array around a value the API contract declares
 * SCALAR.
 *
 * A length-1 array yields its single element; anything else (a longer array, an
 * empty array, an object, a primitive, `null`, `undefined`) passes through
 * UNCHANGED. Applied to a contractually-scalar field it is therefore
 * IDEMPOTENT — which is what lets the downstream consumers keep their own
 * defensive unwrapping as a harmless no-op.
 *
 * Only ever call this on a documented scalar field. It must not be used on
 * `sources` / `evidence` / `evidence_json`, whose length-1 case is genuine data.
 */
export function unwrapWireScalar(value: unknown): unknown {
  if (Array.isArray(value) && value.length === 1) {
    return value[0];
  }
  return value;
}

/** Narrow to a plain object (arrays and `null` excluded). */
function isWireRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Unwrap the listed scalar keys of `target`, in place.
 *
 * Keys that are ABSENT are left absent (`key in target` guard) — writing
 * `undefined` would turn "the API did not send this" into "the API sent
 * nothing", which for `provenance` is a different, meaningful statement.
 */
function unwrapScalarKeys(target: Record<string, unknown>, keys: readonly string[]): void {
  for (const key of keys) {
    if (key in target) {
      target[key] = unwrapWireScalar(target[key]);
    }
  }
}

/** Unwrap the listed scalar keys of every object inside `target[listKey]`. */
function unwrapNestedListScalars(
  target: Record<string, unknown>,
  listKey: string,
  keys: readonly string[]
): void {
  const list = target[listKey];
  if (!Array.isArray(list)) {
    return;
  }
  for (const item of list) {
    if (isWireRecord(item)) {
      unwrapScalarKeys(item, keys);
    }
  }
}

/** Scalars of the compact `provenance` block on the hot variation read. */
const PROVENANCE_SCALAR_KEYS = ['state', 'max_strength'] as const;

/** Scalars of one `provenance.sources[]` entry. */
const PROVENANCE_SOURCE_SCALAR_KEYS = ['source_type', 'source_key', 'strength', 'summary'] as const;

/** Scalars of one full `evidence[]` record. `evidence_json` is NOT listed. */
const EVIDENCE_RECORD_SCALAR_KEYS = [
  'source_type',
  'source_key',
  'batch_id',
  'source_version',
  'evidence_summary',
  'evidence_strength',
] as const;

/** Top-level scalars of the `list()`-built evidence response. */
const EVIDENCE_RESPONSE_SCALAR_KEYS = ['entity_id', 'vario_id', 'modifier_id', 'state'] as const;

/** Top-level scalars of one `list()`-built suggestion. */
const SUGGESTION_SCALAR_KEYS = [
  'entity_id',
  'vario_id',
  'vario_name',
  'modifier_id',
  'state',
  'max_strength',
] as const;

/**
 * Normalize the `provenance` block of one variation row, in place.
 *
 * `null` (curator-authored) and a missing key are both left exactly as they
 * arrived.
 */
function normalizeProvenanceBlock(row: Record<string, unknown>): void {
  const provenance = row.provenance;
  if (!isWireRecord(provenance)) {
    return;
  }
  unwrapScalarKeys(provenance, PROVENANCE_SCALAR_KEYS);
  unwrapNestedListScalars(provenance, 'sources', PROVENANCE_SOURCE_SCALAR_KEYS);
}

/**
 * Normalize `GET /api/entity/<id>/variation`.
 *
 * Mutates the freshly-deserialized axios payload in place (nothing else holds a
 * reference to it yet) and returns it, so extra columns the view may add stay
 * untouched and no key is invented.
 */
export function normalizeVariationRows(rows: EntityVariationRow[]): EntityVariationRow[] {
  if (!Array.isArray(rows)) {
    return rows;
  }
  for (const row of rows) {
    if (isWireRecord(row)) {
      normalizeProvenanceBlock(row);
    }
  }
  return rows;
}

/** Normalize `GET /api/entity/<id>/variation/<vario_id>/<modifier_id>/evidence`. */
export function normalizeVariationEvidenceResponse(
  response: VariationEvidenceResponse
): VariationEvidenceResponse {
  if (!isWireRecord(response)) {
    return response;
  }
  unwrapScalarKeys(response, EVIDENCE_RESPONSE_SCALAR_KEYS);
  unwrapNestedListScalars(response, 'evidence', EVIDENCE_RECORD_SCALAR_KEYS);
  return response;
}

/** Normalize `GET /api/entity/<id>/variation/suggestions`. */
export function normalizeVariationSuggestions(
  suggestions: VariationSuggestion[]
): VariationSuggestion[] {
  if (!Array.isArray(suggestions)) {
    return suggestions;
  }
  for (const suggestion of suggestions) {
    if (isWireRecord(suggestion)) {
      unwrapScalarKeys(suggestion, SUGGESTION_SCALAR_KEYS);
      unwrapNestedListScalars(suggestion, 'evidence', EVIDENCE_RECORD_SCALAR_KEYS);
    }
  }
  return suggestions;
}

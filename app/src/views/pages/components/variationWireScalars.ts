// app/src/views/pages/components/variationWireScalars.ts
//
// Dependency-free wire-shape primitives shared by the variation-provenance
// modules (#608, #612).
//
// These live in their own module so `variationProvenance.ts` (the compact
// provenance block) and `variationEvidenceRecords.ts` (the shape-dispatched
// evidence records) can both use them without importing each other — the
// provenance module imports the records module, so the records module must not
// import back.
//
// WIRE SHAPE
// ----------
// The routes serialize with `jsonlite::toJSON(..., na = "string",
// null = "null")` and plumber does NOT auto-unbox, so every scalar nested
// inside a list-built payload arrives as a LENGTH-1 ARRAY
// (`"state":["active_unconfirmed"]`, `"strength":[1]`, `"negated":[false]`).
// A NULL becomes JSON `null` — not `[null]`, not `{}`, not `"NA"`.
//
// TWO RULES THIS MODULE ENFORCES
//   1. NEVER SYNTHESISE. A field that is absent is omitted; a placeholder that
//      implies data is exactly the fabrication this feature exists to prevent.
//   2. A value that is NOT RECORDED is `null`, never a plausible-looking zero
//      and never a coerced string.

/** Highest value the 0-4 comparability / review-star scale can take. */
export const STRENGTH_SCALE_MAX = 4;

/**
 * Unwrap plumber's length-1 array around a value that is contractually scalar.
 *
 * Only ever call this on a field documented as a scalar. Length-1 arrays that
 * are genuinely arrays (`sources`, `evidence`, `records`, `matched`) must not
 * pass through — that is why this is never applied recursively.
 */
export function unwrapScalar(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.length === 1 ? value[0] : undefined;
  }
  return value;
}

/** Trimmed text, or `null` for absent/blank. */
export function asText(value: unknown): string | null {
  const raw = unwrapScalar(value);
  if (raw === null || raw === undefined) return null;
  const text = String(raw).trim();
  return text === '' ? null : text;
}

/**
 * A recorded 0-4 strength, or `null` for "not recorded".
 *
 * Anything non-finite or out of range is treated as not recorded rather than
 * being clamped into a plausible-looking score.
 */
export function asStrength(value: unknown): number | null {
  const raw = unwrapScalar(value);
  if (raw === null || raw === undefined || raw === '') return null;
  const n = Number(raw);
  if (!Number.isFinite(n) || !Number.isInteger(n) || n < 0 || n > STRENGTH_SCALE_MAX) return null;
  return n;
}

/**
 * A recorded boolean, or `null` for "not recorded".
 *
 * `negated` on a synopsis evidence record is the only field in the whole
 * payload whose FALSE value is meaningful — a negated match is evidence
 * AGAINST the term, which is why the importer scores it 1 instead of 3. It
 * arrives as `[false]`, which `asText()` would render as the string `"false"`,
 * and a truthiness test would then read it as "negated". Anything that is not a
 * real boolean or the exact string `"true"`/`"false"` is NOT RECORDED — never
 * silently "not negated".
 */
export function asBoolean(value: unknown): boolean | null {
  const raw = unwrapScalar(value);
  if (typeof raw === 'boolean') return raw;
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  return null;
}

/** Narrow to a plain object (never an array, never null). */
export function isWireRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

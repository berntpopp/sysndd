// utils/apiUtils.ts

/**
 * API response utilities for defensive data handling
 *
 * Provides safe array coercion and positive number clamping
 * to prevent crashes from unexpected API response shapes.
 */

/**
 * Safely coerce API response data to an array.
 * Returns [] for null, undefined, non-array values.
 *
 * @param data - API response data (unknown type)
 * @returns Array of type T, or empty array if data is invalid
 *
 * @example
 * safeArray([1, 2, 3])          // Returns [1, 2, 3]
 * safeArray(null)               // Returns []
 * safeArray(undefined)          // Returns []
 * safeArray({ error: 'fail' })  // Returns []
 */
export function safeArray<T>(data: unknown): T[] {
  return Array.isArray(data) ? data : [];
}

/**
 * Clamp a number to be non-negative. Returns 0 for NaN/null/undefined.
 *
 * @param n - Number to clamp (may be null or undefined)
 * @returns Non-negative number (0 if input is invalid)
 *
 * @example
 * clampPositive(5)        // Returns 5
 * clampPositive(-3)       // Returns 0
 * clampPositive(null)     // Returns 0
 * clampPositive(undefined) // Returns 0
 */
export function clampPositive(n: number | null | undefined): number {
  return Math.max(0, n ?? 0);
}

/**
 * Unwrap an R/Plumber scalar value that may be wrapped in an array.
 *
 * R/Plumber serializes scalar values as single-element JSON arrays
 * (e.g., `42` becomes `[42]`). This helper safely extracts the scalar.
 *
 * @param val - Value from API response (may be T, T[], null, or undefined)
 * @param fallback - Default value if val is null/undefined (default: undefined)
 * @returns The unwrapped scalar value, or fallback
 *
 * @example
 * unwrapScalar([42])        // Returns 42
 * unwrapScalar(42)          // Returns 42
 * unwrapScalar(null, 0)     // Returns 0
 * unwrapScalar(undefined)   // Returns undefined
 */
export function unwrapScalar<T>(val: T | T[] | null | undefined, fallback?: T): T | undefined {
  if (val === null || val === undefined) return fallback;
  return Array.isArray(val) ? (val[0] ?? fallback) : val;
}

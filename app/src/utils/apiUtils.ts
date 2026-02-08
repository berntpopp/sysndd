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

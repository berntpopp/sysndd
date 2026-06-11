// utils/selectOptions.ts

/**
 * Select-option normalization shared by table/analysis components.
 *
 * Replacement for the old treeselect normalizer: accepts heterogeneous
 * option shapes ({ id, label }, { value, text }, or primitives) and
 * returns the { value, text } shape BFormSelect expects.
 */

export interface NormalizedSelectOption {
  value: unknown;
  text: unknown;
}

/**
 * Normalize options for BFormSelect.
 *
 * @param options - Raw options array (objects or primitives); non-arrays yield []
 * @returns Options in { value, text } shape
 */
export function normalizeSelectOptions(options: unknown): NormalizedSelectOption[] {
  if (!options || !Array.isArray(options)) return [];
  return options.map((opt) => {
    if (typeof opt === 'object' && opt !== null) {
      const o = opt as { id?: unknown; value?: unknown; label?: unknown; text?: unknown };
      return { value: o.id || o.value, text: o.label || o.text || o.id };
    }
    return { value: opt, text: opt };
  });
}

// composables/useWildcardSearch.ts

/**
 * @fileoverview Composable for wildcard pattern matching in gene searches
 *
 * Converts biologist-friendly wildcard patterns to JavaScript regular expressions.
 * Supports two wildcard characters:
 * - * (asterisk): matches any number of characters (including zero)
 * - ? (question mark): matches exactly one character
 *
 * This matches the mental model biologists have from file system wildcards
 * and common bioinformatics tools.
 *
 * @example
 * ```typescript
 * import { useWildcardSearch } from '@/composables';
 *
 * const { pattern, matches, filterGenes, matchCount } = useWildcardSearch();
 *
 * // Set search pattern
 * pattern.value = 'PKD*';
 *
 * // Check single gene
 * matches('PKD1');   // true
 * matches('PKD2');   // true
 * matches('APKD');   // false (doesn't start with PKD)
 *
 * // Filter gene list
 * const genes = [
 *   { symbol: 'PKD1' },
 *   { symbol: 'PKD2' },
 *   { symbol: 'BRCA1' },
 * ];
 * filterGenes(genes); // [{ symbol: 'PKD1' }, { symbol: 'PKD2' }]
 *
 * // Single character wildcard
 * pattern.value = 'BRCA?';
 * matches('BRCA1'); // true
 * matches('BRCA2'); // true
 * matches('BRCA12'); // false (only one char after BRCA)
 * ```
 */

import { ref, computed, type Ref, type ComputedRef } from 'vue';

/**
 * Gene object with symbol property (minimum interface for filtering)
 */
export interface GeneWithSymbol {
  symbol: string;
  [key: string]: unknown;
}

/**
 * Cytoscape node interface for type-safe filtering
 */
export interface CytoscapeNodeLike {
  data: (key: string) => string;
}

/**
 * Return type for the useWildcardSearch composable
 */
export interface WildcardSearchReturn {
  /** The search pattern (user input) */
  pattern: Ref<string>;
  /** Compiled regex from pattern (null if pattern is empty or invalid) */
  regex: ComputedRef<RegExp | null>;
  /** Test if a gene symbol matches the pattern */
  matches: (geneSymbol: string) => boolean;
  /** Filter an array of genes by the pattern */
  filterGenes: <T extends GeneWithSymbol>(genes: T[]) => T[];
  /** Filter function for Cytoscape.js nodes */
  cytoscapeFilter: ComputedRef<(node: CytoscapeNodeLike) => boolean>;
  /** Count of matches in a given gene list (for UI display) */
  countMatches: (genes: GeneWithSymbol[]) => number;
  /** Whether the pattern is valid (non-empty and compilable) */
  isValid: ComputedRef<boolean>;
  /** Clear the search pattern */
  clear: () => void;
}

/**
 * Converts a wildcard pattern to a JavaScript RegExp
 *
 * @param pattern - Wildcard pattern with * and ? wildcards
 * @returns RegExp or null if pattern is empty or invalid
 */
function wildcardToRegex(pattern: string): RegExp | null {
  if (!pattern || pattern.trim() === '') {
    return null;
  }

  try {
    // Escape special regex characters EXCEPT * and ?
    // These are the only special chars we want users to use
    const escaped = pattern
      .replace(/[.+^${}()|[\]\\]/g, '\\$&')
      .replace(/\*/g, '.*') // * -> match any characters (zero or more)
      .replace(/\?/g, '.'); // ? -> match exactly one character

    // Anchor the pattern for full match, case-insensitive
    return new RegExp(`^${escaped}$`, 'i');
  } catch {
    // Invalid regex (shouldn't happen with our escaping, but be safe)
    return null;
  }
}

/**
 * Composable for wildcard pattern matching in gene searches
 *
 * Provides reactive wildcard search functionality with pattern-to-regex
 * conversion, match testing, and array filtering.
 *
 * @param initialPattern - Optional initial search pattern
 * @returns Wildcard search utilities
 */
export function useWildcardSearch(initialPattern = ''): WildcardSearchReturn {
  /**
   * The search pattern (user input)
   */
  const pattern = ref(initialPattern);

  /**
   * Compiled regex from pattern
   * Automatically recomputes when pattern changes
   */
  const regex = computed<RegExp | null>(() => wildcardToRegex(pattern.value));

  /**
   * Whether the pattern is valid (non-empty and compilable)
   */
  const isValid = computed<boolean>(() => regex.value !== null);

  /**
   * Test if a single gene symbol matches the pattern
   *
   * @param geneSymbol - Gene symbol to test
   * @returns true if matches (or if no pattern), false otherwise
   */
  const matches = (geneSymbol: string): boolean => {
    // No pattern = match all (inclusive by default)
    if (!regex.value) {
      return true;
    }
    return regex.value.test(geneSymbol);
  };

  /**
   * Filter an array of genes by the pattern
   * Preserves the full gene object type
   *
   * @param genes - Array of gene objects with symbol property
   * @returns Filtered array containing only matching genes
   */
  const filterGenes = <T extends GeneWithSymbol>(genes: T[]): T[] => {
    // No pattern = return all
    if (!regex.value) {
      return genes;
    }
    return genes.filter((gene) => regex.value!.test(gene.symbol));
  };

  /**
   * Filter function for Cytoscape.js nodes
   * Returns a function that can be used with cy.filter()
   *
   * Note: Uses function approach instead of selector string to avoid
   * injection vulnerabilities (see RESEARCH.md pitfall #2)
   */
  const cytoscapeFilter = computed<(node: CytoscapeNodeLike) => boolean>(() => {
    if (!regex.value) {
      // No pattern = match all nodes
      return () => true;
    }

    const re = regex.value;
    return (node: CytoscapeNodeLike) => {
      const symbol = node.data('symbol');
      return symbol ? re.test(symbol) : false;
    };
  });

  /**
   * Count matches in a gene list
   * Useful for displaying "X matches" in UI
   *
   * @param genes - Array of genes to count matches in
   * @returns Number of matching genes
   */
  const countMatches = (genes: GeneWithSymbol[]): number => {
    if (!regex.value) {
      return genes.length; // No pattern = all match
    }
    return genes.filter((gene) => regex.value!.test(gene.symbol)).length;
  };

  /**
   * Clear the search pattern
   */
  const clear = (): void => {
    pattern.value = '';
  };

  return {
    pattern,
    regex,
    matches,
    filterGenes,
    cytoscapeFilter,
    countMatches,
    isValid,
    clear,
  };
}

export default useWildcardSearch;

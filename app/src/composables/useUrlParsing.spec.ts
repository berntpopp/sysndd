// useUrlParsing.spec.ts
/**
 * Tests for useUrlParsing composable
 *
 * Pattern: Pure function composable testing
 * This composable returns pure functions with clear input/output contracts.
 * Good candidate for comprehensive testing with edge cases.
 *
 * Key learning:
 * - Pure functions can be tested directly without Vue context
 * - Test each function with normal cases, edge cases, and error cases
 * - Functions are deterministic: same input always produces same output
 */

import { describe, it, expect } from 'vitest';
import useUrlParsing from './useUrlParsing';

describe('useUrlParsing', () => {
  describe('filterObjToStr', () => {
    it('converts filter object to URL string', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        symbol: { content: 'BRCA1', operator: 'equals', join_char: null },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toBe('equals(symbol,BRCA1)');
    });

    it('handles multiple filters', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        symbol: { content: 'BRCA1', operator: 'equals', join_char: null },
        category: { content: '1', operator: 'equals', join_char: null },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toContain('equals(symbol,BRCA1)');
      expect(result).toContain('equals(category,1)');
      expect(result.split('),').length).toBe(2); // Two filter expressions
    });

    it('filters out null content', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        symbol: { content: null, operator: 'equals', join_char: null },
        category: { content: '1', operator: 'equals', join_char: null },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toBe('equals(category,1)');
      expect(result).not.toContain('symbol');
    });

    it('filters out empty string content', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        symbol: { content: '', operator: 'equals', join_char: null },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toBe('');
    });

    it('filters out "null" string content', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        symbol: { content: 'null', operator: 'equals', join_char: null },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toBe('');
    });

    it('handles array content with any operator', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        categories: { content: ['1', '2', '3'], operator: 'any', join_char: ',' },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toBe('any(categories,1,2,3)');
    });

    it('filters out empty array content', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        categories: { content: [], operator: 'any', join_char: ',' },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toBe('');
    });

    it('handles contains operator', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        hgnc_id: { content: '1234', operator: 'contains', join_char: null },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toBe('contains(hgnc_id,1234)');
    });

    it('returns empty string for empty filter object', () => {
      const { filterObjToStr } = useUrlParsing();

      const result = filterObjToStr({});
      expect(result).toBe('');
    });

    it('handles mixed valid and invalid filters', () => {
      const { filterObjToStr } = useUrlParsing();

      const filterObj = {
        symbol: { content: 'BRCA1', operator: 'equals', join_char: null },
        empty: { content: '', operator: 'equals', join_char: null },
        categories: { content: ['1', '2'], operator: 'any', join_char: ',' },
        nullValue: { content: null, operator: 'equals', join_char: null },
      };

      const result = filterObjToStr(filterObj);
      expect(result).toContain('equals(symbol,BRCA1)');
      expect(result).toContain('any(categories,1,2)');
      expect(result).not.toContain('empty');
      expect(result).not.toContain('nullValue');
    });
  });

  describe('filterStrToObj', () => {
    it('parses filter string to object', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        symbol: { content: null, operator: 'equals', join_char: null },
      };

      const result = filterStrToObj('equals(symbol,BRCA1)', standard);
      expect(result.symbol.content).toBe('BRCA1');
      expect(result.symbol.operator).toBe('equals');
    });

    it('returns standard object for null input', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        symbol: { content: null, operator: 'equals', join_char: null },
      };

      const result = filterStrToObj(null, standard);
      expect(result).toEqual(standard);
    });

    it('returns standard object for empty string', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        symbol: { content: null, operator: 'equals', join_char: null },
      };

      const result = filterStrToObj('', standard);
      expect(result).toEqual(standard);
    });

    it('returns standard object for "null" string', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        symbol: { content: null, operator: 'equals', join_char: null },
      };

      const result = filterStrToObj('null', standard);
      expect(result).toEqual(standard);
    });

    it('handles any operator with multiple values', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        categories: { content: null, operator: 'any', join_char: ',' },
      };

      const result = filterStrToObj('any(categories,1,2,3)', standard);
      expect(result.categories.content).toEqual(['1', '2', '3']);
      expect(result.categories.operator).toBe('any');
      expect(result.categories.join_char).toBe(',');
    });

    it('handles all operator with multiple values', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        categories: { content: null, operator: 'all', join_char: ',' },
      };

      const result = filterStrToObj('all(categories,1,2,3)', standard);
      expect(result.categories.content).toEqual(['1', '2', '3']);
      expect(result.categories.operator).toBe('all');
      expect(result.categories.join_char).toBe(',');
    });

    it('parses multiple filters from string', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        symbol: { content: null, operator: 'equals', join_char: null },
        category: { content: null, operator: 'equals', join_char: null },
      };

      const result = filterStrToObj('equals(symbol,BRCA1),equals(category,1)', standard);
      expect(result.symbol.content).toBe('BRCA1');
      expect(result.category.content).toBe('1');
    });

    it('preserves unmatched standard keys', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        symbol: { content: null, operator: 'equals', join_char: null },
        category: { content: 'default', operator: 'equals', join_char: null },
      };

      const result = filterStrToObj('equals(symbol,BRCA1)', standard);
      expect(result.symbol.content).toBe('BRCA1');
      expect(result.category.content).toBe('default');
    });

    it('handles contains operator', () => {
      const { filterStrToObj } = useUrlParsing();

      const standard = {
        hgnc_id: { content: null, operator: 'contains', join_char: null },
      };

      const result = filterStrToObj('contains(hgnc_id,1234)', standard);
      expect(result.hgnc_id.content).toBe('1234');
      expect(result.hgnc_id.operator).toBe('contains');
    });
  });

  describe('sortStringToVariables', () => {
    it('parses ascending sort string', () => {
      const { sortStringToVariables } = useUrlParsing();

      const result = sortStringToVariables('+entity_id');

      expect(result.sortBy).toEqual([{ key: 'entity_id', order: 'asc' }]);
      expect(result.sortDesc).toBe(false);
      expect(result.sortColumn).toBe('entity_id');
    });

    it('parses descending sort string', () => {
      const { sortStringToVariables } = useUrlParsing();

      const result = sortStringToVariables('-symbol');

      expect(result.sortBy).toEqual([{ key: 'symbol', order: 'desc' }]);
      expect(result.sortDesc).toBe(true);
      expect(result.sortColumn).toBe('symbol');
    });

    it('handles string with leading spaces', () => {
      const { sortStringToVariables } = useUrlParsing();

      const result = sortStringToVariables('  +entity_id');

      expect(result.sortColumn).toBe('entity_id');
      expect(result.sortDesc).toBe(false);
    });

    it('handles string with trailing spaces', () => {
      const { sortStringToVariables } = useUrlParsing();

      const result = sortStringToVariables('+entity_id  ');

      expect(result.sortColumn).toBe('entity_id');
    });

    it('handles string without sign (defaults to ascending)', () => {
      const { sortStringToVariables } = useUrlParsing();

      const result = sortStringToVariables('entity_id');

      expect(result.sortDesc).toBe(false);
      expect(result.sortColumn).toBe('entity_id');
      expect(result.sortBy).toEqual([{ key: 'entity_id', order: 'asc' }]);
    });

    it('handles different column names', () => {
      const { sortStringToVariables } = useUrlParsing();

      const columns = ['hgnc_id', 'disease_ontology_name', 'category', 'ndd_phenotype_word'];

      columns.forEach((col) => {
        const result = sortStringToVariables(`+${col}`);
        expect(result.sortColumn).toBe(col);
        expect(result.sortBy[0].key).toBe(col);
      });
    });

    it('provides Bootstrap-Vue-Next compatible sortBy format', () => {
      const { sortStringToVariables } = useUrlParsing();

      const result = sortStringToVariables('-symbol');

      // Bootstrap-Vue-Next expects array of { key, order }
      expect(Array.isArray(result.sortBy)).toBe(true);
      expect(result.sortBy).toHaveLength(1);
      expect(result.sortBy[0]).toHaveProperty('key', 'symbol');
      expect(result.sortBy[0]).toHaveProperty('order', 'desc');
    });

    it('provides legacy sortDesc for backward compatibility', () => {
      const { sortStringToVariables } = useUrlParsing();

      const ascResult = sortStringToVariables('+entity_id');
      const descResult = sortStringToVariables('-entity_id');

      expect(ascResult.sortDesc).toBe(false);
      expect(descResult.sortDesc).toBe(true);
    });
  });

  describe('round-trip conversions', () => {
    it('filterObjToStr and filterStrToObj are inverse operations', () => {
      const { filterObjToStr, filterStrToObj } = useUrlParsing();

      const original = {
        symbol: { content: 'BRCA1', operator: 'equals', join_char: null },
        category: { content: '1', operator: 'equals', join_char: null },
      };

      const str = filterObjToStr(original);
      const standard = {
        symbol: { content: null, operator: 'equals', join_char: null },
        category: { content: null, operator: 'equals', join_char: null },
      };

      const result = filterStrToObj(str, standard);

      expect(result.symbol.content).toBe('BRCA1');
      expect(result.category.content).toBe('1');
    });

    it('preserves array content through round-trip', () => {
      const { filterObjToStr, filterStrToObj } = useUrlParsing();

      const original = {
        categories: { content: ['1', '2', '3'], operator: 'any', join_char: ',' },
      };

      const str = filterObjToStr(original);
      const standard = {
        categories: { content: null, operator: 'any', join_char: ',' },
      };

      const result = filterStrToObj(str, standard);

      expect(result.categories.content).toEqual(['1', '2', '3']);
    });
  });
});

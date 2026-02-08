// utils/__tests__/apiUtils.spec.ts

import { describe, it, expect } from 'vitest';
import { safeArray, clampPositive } from '../apiUtils';

describe('apiUtils', () => {
  describe('safeArray', () => {
    it('returns array unchanged', () => {
      expect(safeArray([1, 2, 3])).toEqual([1, 2, 3]);
    });

    it('returns [] for null', () => {
      expect(safeArray(null)).toEqual([]);
    });

    it('returns [] for undefined', () => {
      expect(safeArray(undefined)).toEqual([]);
    });

    it('returns [] for object', () => {
      expect(safeArray({ error: 'fail' })).toEqual([]);
    });

    it('returns [] for string', () => {
      expect(safeArray('not an array')).toEqual([]);
    });

    it('returns [] for number', () => {
      expect(safeArray(42)).toEqual([]);
    });

    it('preserves empty array', () => {
      expect(safeArray([])).toEqual([]);
    });

    it('preserves complex object arrays', () => {
      const data = [{ id: 1, name: 'test' }];
      expect(safeArray(data)).toEqual(data);
    });
  });

  describe('clampPositive', () => {
    it('returns positive values unchanged', () => {
      expect(clampPositive(5)).toBe(5);
    });

    it('returns zero unchanged', () => {
      expect(clampPositive(0)).toBe(0);
    });

    it('clamps negative to zero', () => {
      expect(clampPositive(-3)).toBe(0);
    });

    it('returns 0 for null', () => {
      expect(clampPositive(null)).toBe(0);
    });

    it('returns 0 for undefined', () => {
      expect(clampPositive(undefined)).toBe(0);
    });

    it('handles large positive numbers', () => {
      expect(clampPositive(1000000)).toBe(1000000);
    });

    it('handles large negative numbers', () => {
      expect(clampPositive(-1000000)).toBe(0);
    });

    it('handles decimal numbers', () => {
      expect(clampPositive(3.14)).toBe(3.14);
      expect(clampPositive(-2.5)).toBe(0);
    });
  });
});

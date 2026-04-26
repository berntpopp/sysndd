import { describe, expect, test } from 'vitest';
import * as mod from '../useStatusForm';

describe('useStatusForm — public API contract (pin)', () => {
  test('default export or named export exists', () => {
    const factory = (mod as any).default ?? (mod as any).useStatusForm;
    expect(typeof factory).toBe('function');
  });

  test('returned shape has the documented surface', () => {
    const factory = (mod as any).default ?? (mod as any).useStatusForm;
    const inst = factory();
    for (const key of [
      'formData',
      'loading',
      'loadStatusByEntity',
      'submitForm',
      'resetForm',
      'hasChanges',
    ]) {
      expect(inst).toHaveProperty(key);
    }
  });
});

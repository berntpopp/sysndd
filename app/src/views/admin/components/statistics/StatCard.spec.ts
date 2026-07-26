import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const source = readFileSync(
  resolve(process.cwd(), 'src/views/admin/components/statistics/StatCard.vue'),
  'utf8'
);

describe('StatCard visual contract', () => {
  it('uses the shared surface hierarchy without a decorative side accent', () => {
    expect(source).not.toMatch(/border-(?:left|right)\s*:/);
    expect(source).toContain('border: 1px solid var(--border-subtle);');
    expect(source).toContain('background: var(--surface-raised);');
  });
});

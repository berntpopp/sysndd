import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';

const source = readFileSync(resolve(process.cwd(), 'src/views/pages/SearchView.vue'), 'utf8');

describe('SearchView visual contract', () => {
  it('does not animate relevance width', () => {
    expect(source).not.toMatch(/transition\s*:\s*width\b/);
  });
});

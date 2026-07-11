import { describe, expect, it, vi, beforeEach } from 'vitest';

// Deferred-promise mock so we can force out-of-order resolution deterministically.
const fetchSearchInfo = vi.fn();
vi.mock('@/assets/js/services/apiService', () => ({
  default: { fetchSearchInfo: (...args: unknown[]) => fetchSearchInfo(...args) },
}));

import { useSearchSuggestions } from './useSearchSuggestions';

function deferred<T>() {
  let resolve!: (v: T) => void;
  const promise = new Promise<T>((res) => { resolve = res; });
  return { promise, resolve };
}

describe('useSearchSuggestions request ownership (#535 P2-3)', () => {
  beforeEach(() => fetchSearchInfo.mockReset());

  it('ignores an out-of-order stale response (type "a" then "ab", "a" resolves last)', async () => {
    const dA = deferred<[Record<string, Array<{ link: string }>>]>();
    const dAB = deferred<[Record<string, Array<{ link: string }>>]>();
    fetchSearchInfo.mockReturnValueOnce(dA.promise).mockReturnValueOnce(dAB.promise);

    const s = useSearchSuggestions();

    s.query.value = 'a';
    const pA = s.fetchSuggestions();
    s.query.value = 'ab';
    const pAB = s.fetchSuggestions();

    dAB.resolve([{ AB: [{ link: '/ab' }] }]);
    await pAB;
    dA.resolve([{ A: [{ link: '/a' }] }]); // stale, resolves last
    await pA;

    expect(s.suggestions.value.map((x) => x.label)).toEqual(['AB']);
  });

  it('a response arriving after clearSuggestions() does not repopulate', async () => {
    const dA = deferred<[Record<string, Array<{ link: string }>>]>();
    fetchSearchInfo.mockReturnValueOnce(dA.promise);

    const s = useSearchSuggestions();
    s.query.value = 'a';
    const pA = s.fetchSuggestions();
    s.clearSuggestions(); // user cleared while the request is in flight
    dA.resolve([{ A: [{ link: '/a' }] }]);
    await pA;

    expect(s.suggestions.value).toEqual([]);
  });
});

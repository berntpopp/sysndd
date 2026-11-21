import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import useFormDraft from './useFormDraft';

describe('useFormDraft scheduleSave', () => {
  beforeEach(() => {
    vi.useFakeTimers();
    localStorage.clear();
  });
  afterEach(() => vi.useRealTimers());

  // CUR-20: "Saving..." showed for the whole 2 s debounce after every keystroke.
  it('does not report saving while it only waits for the debounce', () => {
    const draft = useFormDraft<{ a: number }>('spec-form');
    draft.scheduleSave({ a: 1 });
    expect(draft.isSaving.value).toBe(false);
    expect(draft.hasDraft.value).toBe(false);

    vi.advanceTimersByTime(2000);
    expect(draft.hasDraft.value).toBe(true);
    expect(draft.isSaving.value).toBe(false);
  });
});

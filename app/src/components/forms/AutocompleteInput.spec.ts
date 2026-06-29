import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mount } from '@vue/test-utils';
import AutocompleteInput from './AutocompleteInput.vue';

/**
 * Reconciliation notes vs. the brief's original mountOpen:
 *
 * 1. inputId: 'test-input' — required prop; the brief omitted it.
 *
 * 2. global.stubs.teleport: true — the no-results <div> lives inside
 *    <Teleport to="body">, so without this stub its content is teleported to
 *    document.body and wrapper.text() cannot see it.
 *
 * 3. vi.useFakeTimers() + vi.runAllTimersAsync() — onFocus() only opens the
 *    dropdown when results.length > 0. With results=[] the only path that sets
 *    showDropdown=true is onInput() → debounce timeout → openDropdown(). Fake
 *    timers let the test flush that debounce synchronously; runAllTimersAsync
 *    also drains the nextTick promise inside openDropdown.
 */
function mountOpen(props: Record<string, unknown> = {}) {
  return mount(AutocompleteInput, {
    props: {
      label: 'Disease',
      results: [],
      loading: false,
      minChars: 2,
      inputId: 'test-input',
      ...props,
    },
    global: {
      stubs: {
        teleport: true,
      },
    },
  });
}

describe('AutocompleteInput noResultsMessage', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('shows the default copy when no override is given', async () => {
    const wrapper = mountOpen();
    const input = wrapper.find('input');
    await input.setValue('zzz');
    await vi.runAllTimersAsync();
    expect(wrapper.text()).toContain('No results found');
  });

  it('shows a custom noResultsMessage when provided', async () => {
    const wrapper = mountOpen({ noResultsMessage: 'term pending refresh' });
    const input = wrapper.find('input');
    await input.setValue('999999');
    await vi.runAllTimersAsync();
    expect(wrapper.text()).toContain('term pending refresh');
  });
});

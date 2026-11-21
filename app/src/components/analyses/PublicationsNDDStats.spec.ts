import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import PublicationsNDDStats from './PublicationsNDDStats.vue';

vi.mock('@/composables/useToast', () => ({ default: () => ({ makeToast: vi.fn() }) }));
vi.mock('@/api/statistics', () => ({
  getPublicationStats: vi.fn().mockResolvedValue({
    publication_date_aggregated: [
      { Publication_date: '2024-01-01', count: 300 },
      { Publication_date: '2025-01-01', count: 4390 },
    ],
    journal_counts: [{ Journal: 'American journal of human genetics', count: 42 }],
    last_name_counts: [],
    keyword_counts: [],
  }),
}));
vi.mock('@/api/publication', () => ({
  listPublications: vi.fn().mockResolvedValue({
    data: [{ publication_id: 'PMID:1', Publication_date: '2025-11-05' }],
  }),
}));

describe('PublicationsNDDStats', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(new Date('2026-03-01T12:00:00Z'));
  });
  afterEach(() => vi.useRealTimers());

  async function mountStats() {
    const wrapper = mount(PublicationsNDDStats, { attachTo: document.body });
    await flushPromises();
    return wrapper;
  }

  it('shows the latest year with data instead of an empty current-year (YTD) card', async () => {
    const wrapper = await mountStats();
    const text = wrapper.text();
    expect(text).not.toContain('2026 (YTD)');
    expect(text).toContain('Publications 2025');
    expect(text).toContain('4,390');
    expect(text).toContain('4,690');
    wrapper.unmount();
  });

  it('prints the newest publication date in long form', async () => {
    const wrapper = await mountStats();
    expect(wrapper.text()).toContain('November 5, 2025');
    expect(wrapper.text()).not.toContain('2025-11-05');
    wrapper.unmount();
  });

  it('uses no headings inside the stat cards and names every control', async () => {
    const wrapper = await mountStats();
    expect(wrapper.findAll('.metrics-card h4, .metrics-card h6')).toHaveLength(0);
    for (const control of wrapper.findAll('select, input')) {
      expect(control.attributes('aria-label')).toBeTruthy();
    }
    wrapper.unmount();
  });
});

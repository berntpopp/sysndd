import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import EntityFreshnessPills from './EntityFreshnessPills.vue';

describe('EntityFreshnessPills', () => {
  it('renders entry and last-updated dates trimmed to the date part', () => {
    const wrapper = mount(EntityFreshnessPills, {
      props: { entryDate: '2014-03-04 00:00:00', lastUpdate: '2026-02-10 12:29:49' },
    });

    const entry = wrapper.get('[data-testid="entity-entry-date"]');
    expect(entry.text()).toBe('Entered 2014-03-04');

    const updated = wrapper.get('[data-testid="entity-last-update"]');
    expect(updated.text()).toBe('Last updated 2026-02-10');
    // The time component is dropped.
    expect(wrapper.text()).not.toContain('12:29:49');
  });

  it('omits a pill when its date is missing', () => {
    const wrapper = mount(EntityFreshnessPills, {
      props: { entryDate: '2020-01-01', lastUpdate: null },
    });

    expect(wrapper.find('[data-testid="entity-entry-date"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="entity-last-update"]').exists()).toBe(false);
  });

  it('renders nothing when both dates are absent', () => {
    const wrapper = mount(EntityFreshnessPills, { props: {} });
    expect(wrapper.find('[data-testid="entity-entry-date"]').exists()).toBe(false);
    expect(wrapper.find('[data-testid="entity-last-update"]').exists()).toBe(false);
  });
});

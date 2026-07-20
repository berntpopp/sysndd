import { mount, flushPromises } from '@vue/test-utils';
import { describe, it, expect, vi } from 'vitest';
import EvidenceTierMappingHelp from './EvidenceTierMappingHelp.vue';

// DISTINCTIVE content so the test proves the component renders the API payload,
// not hard-coded copy (no-drift requirement of #586).
const DISTINCT_DEF = 'ZZDISTINCT tier definition from server';
const DISTINCT_NOTE = 'ZZDISTINCT server note about Red';
vi.mock('@/api/comparisons', () => ({
  getComparisonsCrosswalk: vi.fn(() =>
    Promise.resolve({
      mapping_version: '2026-07-19.583-panelapp-ordinal',
      tiers: [{ tier: 'Limited', definition: DISTINCT_DEF }],
      sources: [],
      non_tier_fillers: [],
      notes: [DISTINCT_NOTE],
    })
  ),
}));

// Behaviorful stubs: InlineHelpBadge is a real focusable button that forwards
// click; BPopover renders its default slot so content is assertable.
const stubs = {
  InlineHelpBadge: {
    template:
      '<button type="button" :aria-label="ariaLabel" v-bind="$attrs" @click="$emit(\'click\')"><slot/></button>',
    props: ['ariaLabel', 'id'],
  },
  BPopover: { template: '<div class="popover"><slot name="title"/><slot/></div>' },
};

describe('EvidenceTierMappingHelp', () => {
  it('exposes an accessible help affordance with no navigational href on the badge', () => {
    const w = mount(EvidenceTierMappingHelp, { global: { stubs } });
    const badge = w.get('button');
    expect(badge.attributes('aria-label')).toMatch(/evidence-tier/i);
    expect(badge.attributes('href')).toBeUndefined();
    expect(badge.attributes('aria-haspopup')).toBe('dialog');
  });
  it('RENDERS the API-sourced tier definition, note, version and crosswalk link (no drift)', async () => {
    const w = mount(EvidenceTierMappingHelp, { global: { stubs } });
    await flushPromises();
    expect(w.text()).toContain(DISTINCT_DEF); // proves tiers come from the API
    expect(w.text()).toContain(DISTINCT_NOTE); // proves notes come from the API
    expect(w.text()).toContain('2026-07-19.583-panelapp-ordinal');
    const link = w.get('a.crosswalk-link');
    expect(link.attributes('href')).toContain('/comparisons/crosswalk');
    expect(link.attributes('rel')).toContain('noopener');
  });
  it('is keyboard operable: activate opens, Escape closes and restores focus', async () => {
    const w = mount(EvidenceTierMappingHelp, { global: { stubs }, attachTo: document.body });
    await flushPromises();
    const badge = w.get('button');
    await badge.trigger('click');
    expect((w.vm as unknown as { open: boolean }).open).toBe(true);
    await w.get('[role="dialog"]').trigger('keydown.esc');
    expect((w.vm as unknown as { open: boolean }).open).toBe(false);
    expect(document.activeElement).toBe(badge.element); // focus restored to trigger
    w.unmount();
  });
  it('shows a neutral unavailable message and NO tier text on fetch failure', async () => {
    const mod = await import('@/api/comparisons');
    (mod.getComparisonsCrosswalk as unknown as { mockRejectedValueOnce: (e: Error) => void }).mockRejectedValueOnce(
      new Error('down')
    );
    const w = mount(EvidenceTierMappingHelp, { global: { stubs } });
    await flushPromises();
    expect(w.text()).toMatch(/unavailable/i);
    expect(w.text()).not.toMatch(/Refuted|Limited|Moderate|Definitive/);
  });
});

// HgncAnnotationsCard.spec.ts
//
// Pins the idle-message copy on the HGNC update card. The previous copy
// claimed the job "may take hours on first run", which became stale after
// the bulk gnomAD TSV path replaced the per-gene API approach. The new copy
// reflects realistic timing (typically a few minutes) and lists what gets
// enriched.

import { describe, it, expect } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import HgncAnnotationsCard from './HgncAnnotationsCard.vue';

const idleJob = {
  isLoading: { value: false },
} as never;

// shallowMount stubs JobProgressDisplay so we can read the idle-message
// prop without mounting the full child (which expects a richer job shape).
function mountCard() {
  return shallowMount(HgncAnnotationsCard, {
    props: {
      hgncJob: idleJob,
      lastUpdated: null,
    },
    global: {
      stubs: {
        AdminOperationPanel: {
          template: '<section><slot /><slot name="actions" /></section>',
        },
      },
    },
  });
}

describe('HgncAnnotationsCard idle copy', () => {
  it('does not claim "may take hours"', () => {
    const wrapper = mountCard();
    const stub = wrapper.findComponent({ name: 'JobProgressDisplay' });
    expect(stub.exists()).toBe(true);
    expect(stub.props('idleMessage') as string | undefined).not.toMatch(/may take hours/i);
  });

  it('mentions gnomAD constraints and a realistic timing in the idle message', () => {
    const wrapper = mountCard();
    const stub = wrapper.findComponent({ name: 'JobProgressDisplay' });
    const msg = (stub.props('idleMessage') as string | undefined) ?? '';
    expect(msg).toMatch(/gnomAD constraints/i);
    expect(msg).toMatch(/Typically a few minutes/i);
  });
});

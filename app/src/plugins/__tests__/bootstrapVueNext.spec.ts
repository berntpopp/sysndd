import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import { BFormCheckbox, createBootstrap } from 'bootstrap-vue-next';

import { bootstrapVueNextOptions } from '../bootstrapVueNext';

/**
 * bootstrap-vue-next 0.46.0 changed `BFormCheckbox`'s `uncheckedValue` default
 * from `false` to `null`. SysNDD feeds checkbox values straight into typed API
 * payloads (`direct_approval`, `clear_old`, `problematic`), so the historical
 * `false` is restored globally. These tests fail if that restoration is dropped
 * or if a future release moves the default again.
 */
describe('bootstrapVueNextOptions', () => {
  it('pins BFormCheckbox.uncheckedValue to false', () => {
    expect(bootstrapVueNextOptions.components?.BFormCheckbox?.uncheckedValue).toBe(false);
  });

  it('makes an unchecked BFormCheckbox emit false, not null', async () => {
    const wrapper = mount(BFormCheckbox, {
      props: { modelValue: true },
      global: { plugins: [createBootstrap(bootstrapVueNextOptions)] },
    });

    await wrapper.find('input').setValue(false);

    expect(wrapper.emitted('update:modelValue')).toEqual([[false]]);
  });
});

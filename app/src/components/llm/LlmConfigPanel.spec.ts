import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import LlmConfigPanel from './LlmConfigPanel.vue';
import type { LlmConfig } from '@/types/llm';

const config: LlmConfig = {
  gemini_configured: false,
  current_model: 'gemini-3.5-flash',
  source: 'default',
  default_model: 'gemini-3.5-flash',
  valid: true,
  operator_allowed: false,
  warning: null,
  available_models: [
    {
      model_id: 'gemini-3.5-flash',
      display_name: 'Gemini 3.5 Flash',
      description: 'Current fast text model',
      rpm_limit: 1000,
      rpd_limit: null,
      recommended_for: 'Default summaries',
    },
    {
      model_id: 'gemini-3.1-flash-lite',
      display_name: 'Gemini 3.1 Flash-Lite',
      description: 'Cost-efficient model',
      rpm_limit: 2000,
      rpd_limit: null,
      recommended_for: 'High-volume summaries',
    },
  ],
  rate_limit: {
    capacity: 10,
    fill_time_s: 60,
    backoff_base: 2,
    max_retries: 3,
  },
};

function mountPanel(overrides: Partial<LlmConfig> = {}) {
  return mount(LlmConfigPanel, {
    props: {
      config: { ...config, ...overrides },
      loading: false,
    },
    global: {
      stubs: {
        BCard: { template: '<section><slot name="header" /><slot /></section>' },
        BAlert: { template: '<div role="alert"><slot /></div>' },
        BForm: { template: '<form><slot /></form>' },
        BFormGroup: { template: '<label><slot /></label>' },
        BFormSelect: {
          name: 'BFormSelect',
          props: ['modelValue', 'options', 'disabled'],
          emits: ['update:modelValue', 'change'],
          template:
            '<select id="model-select" :disabled="disabled" @change="$emit(\'change\')"><option v-for="option in options" :key="option.value" :value="option.value">{{ option.text }}</option></select>',
        },
        BFormText: { template: '<p><slot /></p>' },
        BFormInput: {
          props: ['modelValue', 'type', 'disabled', 'size'],
          template: '<input :value="modelValue" :type="type" :disabled="disabled" />',
        },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
      },
    },
  });
}

describe('LlmConfigPanel', () => {
  it('shows current model options while Gemini is unconfigured', () => {
    const wrapper = mountPanel();

    expect(wrapper.text()).toContain('Gemini API not configured');
    expect(wrapper.text()).toContain('Gemini 3.5 Flash');
    expect(wrapper.text()).toContain('Gemini 3.1 Flash-Lite');
    expect(wrapper.get('#model-select').attributes('disabled')).toBeDefined();
  });

  it('does not emit model updates while Gemini is unconfigured', async () => {
    const wrapper = mountPanel();

    await wrapper.get('#model-select').trigger('change');

    expect(wrapper.emitted('update-model')).toBeUndefined();
  });

  it('emits model updates when Gemini is configured', async () => {
    const wrapper = mountPanel({ gemini_configured: true });

    await wrapper.get('#model-select').trigger('change');

    expect(wrapper.emitted('update-model')).toEqual([['gemini-3.5-flash']]);
  });

  it('shows an invalid current model warning', () => {
    const wrapper = mountPanel({
      gemini_configured: true,
      current_model: 'gemini-3-pro-preview',
      valid: false,
      warning: 'Gemini model gemini-3-pro-preview is shut down and is not allowed.',
    });

    expect(wrapper.text()).toContain('Current Gemini model is invalid');
    expect(wrapper.text()).toContain('shut down');
  });

  it('shows an operator allowlist warning', () => {
    const wrapper = mountPanel({
      gemini_configured: true,
      current_model: 'gemini-new-release',
      valid: true,
      operator_allowed: true,
      warning: 'Gemini model gemini-new-release is allowed by operator override.',
    });

    expect(wrapper.text()).toContain('Operator-allowlisted Gemini model');
    expect(wrapper.text()).toContain('operator override');
  });
});

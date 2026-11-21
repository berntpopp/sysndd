import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import FormWizard from './FormWizard.vue';
import type { WizardStep } from '@/composables/useEntityForm';

const base = {
  steps: ['core', 'evidence'] as WizardStep[],
  stepLabels: { core: 'Core', evidence: 'Evidence' } as Record<WizardStep, string>,
  currentStepIndex: 0,
  isFormValid: false,
};

describe('FormWizard', () => {
  // CUR-21: Next was disabled with no reason given.
  it('says what is missing while Next is disabled, and links it to the button', () => {
    const wrapper = mount(FormWizard, {
      props: {
        ...base,
        isCurrentStepValid: false,
        blockedReasons: ['Gene is required', 'Disease is required'],
      },
    });
    const hint = wrapper.get('#wizard-blocked-hint');
    expect(hint.text()).toBe('Gene is required · Disease is required');
    const next = wrapper.findAll('button').find((b) => b.text().startsWith('Next'));
    expect(next?.attributes('aria-describedby')).toBe('wizard-blocked-hint');
  });

  it('shows no hint once the step is valid', () => {
    const wrapper = mount(FormWizard, {
      props: { ...base, isCurrentStepValid: true, blockedReasons: [] as string[] },
    });
    expect(wrapper.find('#wizard-blocked-hint').exists()).toBe(false);
  });
});

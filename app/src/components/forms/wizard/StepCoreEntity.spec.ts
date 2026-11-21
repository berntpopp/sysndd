// StepCoreEntity.spec.ts
/**
 * The NDD Phenotype field must not look answered before the curator chooses:
 * a null value shows neither Yes nor No selected, and choosing No is one click.
 */
import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import StepCoreEntity from './StepCoreEntity.vue';
import useEntityForm from '@/composables/useEntityForm';

function mountStep() {
  const form = useEntityForm();
  const wrapper = mount(StepCoreEntity, {
    props: { inheritanceOptions: [] },
    global: {
      provide: {
        formData: form.formData,
        getFieldError: form.getFieldError,
        getFieldState: form.getFieldState,
        touchField: form.touchField,
      },
      stubs: { AutocompleteInput: true },
    },
  });
  return { form, wrapper };
}

describe('StepCoreEntity NDD Phenotype', () => {
  it('shows no choice while the value is null', () => {
    const { wrapper } = mountStep();
    const radios = wrapper.findAll<HTMLInputElement>('input[type="radio"]');
    expect(radios).toHaveLength(2);
    expect(radios.some((r) => r.element.checked)).toBe(false);
  });

  it('sets false with one click on No and passes validation', async () => {
    const { form, wrapper } = mountStep();
    form.touchField('nddPhenotype');
    expect(form.getFieldError('nddPhenotype')).not.toBeNull();

    const no = wrapper
      .findAll('input[type="radio"]')
      .find((r) => r.attributes('value') === 'false');
    await no!.setValue(true);

    expect(form.formData.nddPhenotype).toBe(false);
    expect(form.getFieldError('nddPhenotype')).toBeNull();
  });
});

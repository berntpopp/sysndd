// InlineEntityWorkflow.spec.ts
/** Deactivation can only be submitted once the curator ticks the confirmation. */
import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import { BButton, BForm, BFormCheckbox, BOverlay, BSpinner } from 'bootstrap-vue-next';
import InlineEntityWorkflow from './InlineEntityWorkflow.vue';

function mountDeactivate(deactivateCheck: boolean) {
  return mount(InlineEntityWorkflow, {
    props: {
      workflow: 'deactivate',
      loading: false,
      submitting: null,
      ontologyDisplay: '',
      ontologyInput: null,
      ontologySearchResults: [],
      ontologySearchLoading: false,
      deactivateCheck,
      replaceCheck: false,
      replaceDisplay: '',
      replaceEntityInput: null,
      replaceSearchResults: [],
      replaceSearchLoading: false,
      review: {},
      selectPhenotype: [],
      selectVariation: [],
      selectAdditionalReferences: [],
      selectGeneReviews: [],
      phenotypeOptions: [],
      variationOptions: [],
      statusOptions: null,
      statusOptionsLoading: false,
      formData: {},
    },
    global: {
      components: { BButton, BForm, BFormCheckbox, BOverlay, BSpinner },
      stubs: { AutocompleteInput: true, TreeMultiSelect: true },
    },
  });
}

describe('InlineEntityWorkflow deactivate', () => {
  it('disables Submit until the confirmation is checked', () => {
    const submit = (check: boolean) =>
      mountDeactivate(check).find('button[type="submit"]').attributes('disabled');
    expect(submit(false)).toBeDefined();
    expect(submit(true)).toBeUndefined();
  });
});

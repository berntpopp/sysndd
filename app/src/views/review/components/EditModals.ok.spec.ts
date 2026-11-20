import { describe, expect, it, vi } from 'vitest';
import { shallowMount } from '@vue/test-utils';
import ReviewEditModal from './ReviewEditModal.vue';
import StatusEditModal from './StatusEditModal.vue';

// B13: BModal hides on @ok unless prevented; the parent hides it after a successful save.
describe.each([ReviewEditModal, StatusEditModal])('$name @ok', (component) => {
  it('prevents the default hide and re-emits ok', async () => {
    const wrapper = shallowMount(component, {
      props: {
        modalDescriptor: { id: 'm' },
        formData: {},
        reviewInfo: {},
        entityInfo: { disease_ontology_id_version: 'OMIM:1' },
      },
      global: { stubs: { BModal: { name: 'BModal', template: '<div />', emits: ['ok'] } } },
    });
    const event = { preventDefault: vi.fn() };
    wrapper.findComponent({ name: 'BModal' }).vm.$emit('ok', event);
    expect(event.preventDefault).toHaveBeenCalledOnce();
    expect(wrapper.emitted('ok')).toHaveLength(1);
  });
});

// Reactivate panel (#711): confirmation before the POST, and the API's 409
// reason is shown to the curator instead of a generic failure.
import { flushPromises, mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import ReactivateEntityPanel from './ReactivateEntityPanel.vue';

const ConfirmStub = {
  props: ['modelValue'],
  emits: ['confirm'],
  template: '<button v-if="modelValue" class="confirm-stub" @click="$emit(\'confirm\')" />',
};

function mountPanel() {
  return mount(ReactivateEntityPanel, {
    global: { stubs: { ConfirmActionModal: ConfirmStub } },
  });
}

describe('ReactivateEntityPanel', () => {
  it('asks for confirmation, then POSTs the entity id', async () => {
    let body: unknown = null;
    server.use(
      http.post('/api/entity/reactivate', async ({ request }) => {
        body = await request.json();
        return HttpResponse.json({ status: 200, message: 'OK. Entity reactivated.' });
      })
    );
    const wrapper = mountPanel();
    await wrapper.find('#reactivate-entity-id').setValue('123');
    await wrapper.find('form').trigger('submit');
    expect(body).toBeNull();

    await wrapper.find('.confirm-stub').trigger('click');
    await flushPromises();
    expect(body).toEqual({ reactivate_json: { entity: { entity_id: 123 } } });
    expect(wrapper.text()).toContain('sysndd:123 has been reactivated');
  });

  it('shows why the API refused the reactivation', async () => {
    server.use(
      http.post('/api/entity/reactivate', () =>
        HttpResponse.json(
          { error: 'Entity cannot be reactivated: active entity sysndd:99 already covers it.' },
          { status: 409 }
        )
      )
    );
    const wrapper = mountPanel();
    await wrapper.find('#reactivate-entity-id').setValue('42');
    await wrapper.find('form').trigger('submit');
    await wrapper.find('.confirm-stub').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('active entity sysndd:99 already covers it');
  });
});

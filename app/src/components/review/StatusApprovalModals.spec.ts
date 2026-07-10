// components/review/StatusApprovalModals.spec.ts
/**
 * Wave 2 Task 5 (#346) — unit contract for the modal blocks extracted out of
 * `ApprovalTableView.vue`. Pins:
 *   - prop forwarding into each of the four modals (Approve / Dismiss /
 *     EditStatus / ApproveAll), including the `EditStatusModal` child,
 *   - emit forwarding (`@ok` -> `*-ok`, `hide` -> `edit-hide`,
 *     `update:statusInfo`, `update:approveAllSelected`),
 *   - the `showModal`/`hideModal` exposed surface, which resolves the
 *     dynamic `:ref="<id>"` bound on each modal (mirrors the bridge
 *     `EditStatusModal.vue` already uses for its own inner `BModal`).
 *
 * BootstrapVueNext components are not globally registered in the test
 * environment, so `BModal`/`BBadge`/`BFormCheckbox` are stubbed with
 * lightweight fakes that preserve the imperative `show()`/`hide()` contract
 * (mirroring `ApproveStatus.spec.ts`'s `BModal` stub) and the props/emits
 * this component actually depends on.
 */

import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import { defineComponent, nextTick } from 'vue';
import StatusApprovalModals from './StatusApprovalModals.vue';
import type { StatusInfoShape, EntityInfoShape, StatusOption } from './EditStatusModal.vue';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------
// `BModal` stub mirrors the imperative `show()`/`hide()` contract the real
// bootstrap-vue-next component exposes, and renders a `data-visible` flag so
// tests can assert which modal instance was toggled by id.
const BModalStub = defineComponent({
  name: 'BModal',
  props: ['id'],
  emits: ['ok'],
  data() {
    return { visible: false };
  },
  methods: {
    show() {
      this.visible = true;
    },
    hide() {
      this.visible = false;
    },
  },
  template:
    '<div :data-modal-id="id" :data-visible="visible ? \'true\' : \'false\'">' +
    '<slot name="title" /><slot /></div>',
});

const EditStatusModalStub = defineComponent({
  name: 'EditStatusModal',
  props: ['modalId', 'loading', 'statusInfo', 'entityInfo', 'statusOptions', 'userIcon'],
  emits: ['ok', 'hide', 'update:statusInfo'],
  data() {
    return { visible: false };
  },
  methods: {
    show() {
      this.visible = true;
    },
    hide() {
      this.visible = false;
    },
  },
  template:
    '<div data-testid="edit-status-modal-stub" :data-modal-id="modalId" ' +
    ':data-visible="visible ? \'true\' : \'false\'" :data-loading="String(loading)" />',
});

const BBadgeStub = { template: '<span><slot /></span>' };
const BFormCheckboxStub = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<label>' +
    '<input type="checkbox" :checked="modelValue" ' +
    '@change="$emit(\'update:modelValue\', $event.target.checked)" />' +
    '<slot /></label>',
};

const globalStubs = {
  BModal: BModalStub,
  EditStatusModal: EditStatusModalStub,
  BBadge: BBadgeStub,
  BFormCheckbox: BFormCheckboxStub,
};

const baseStatusInfo: StatusInfoShape = {
  category_id: 1,
  comment: null,
  problematic: false,
  status_id: 201,
  entity_id: 501,
  status_user_name: 'alice_admin',
  status_user_role: 'Administrator',
  status_date: '2026-05-01',
  status_approved: 0,
};

const baseEntityInfo: EntityInfoShape = {
  entity_id: 501,
  symbol: 'TEST1',
  hgnc_id: 'HGNC:12345',
  disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
  disease_ontology_name: 'Test Disease',
  hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
  hpo_mode_of_inheritance_term: 'HP:0000006',
};

const baseStatusOptions: StatusOption[] = [{ id: 1, label: 'Definitive' }];

function mountModals(props: Record<string, unknown> = {}) {
  return mount(StatusApprovalModals, {
    props: {
      approveTitle: 'sysndd:501',
      dismissTitle: 'sysndd:501',
      approveHasDuplicates: false,
      loadingEdit: false,
      statusInfo: baseStatusInfo,
      entityInfo: baseEntityInfo,
      statusOptions: baseStatusOptions,
      approveAllSelected: false,
      totalRows: 7,
      userIcon: { Administrator: 'person-fill' },
      ...props,
    },
    global: { stubs: globalStubs },
  });
}

describe('StatusApprovalModals', () => {
  it('renders the approve-modal title/duplicate copy and emits approve-ok on confirm', async () => {
    const wrapper = mountModals({ approveTitle: 'sysndd:777', approveHasDuplicates: true });

    expect(wrapper.text()).toContain('sysndd:777');
    expect(wrapper.text()).toContain('Other pending statuses for this entity');

    const approveModal = wrapper
      .findAllComponents(BModalStub)
      .find((c) => c.props('id') === 'approve-modal')!;
    await approveModal.vm.$emit('ok');
    expect(wrapper.emitted('approve-ok')).toHaveLength(1);
  });

  it('renders the dismiss-modal title and emits dismiss-ok on confirm', async () => {
    const wrapper = mountModals({ dismissTitle: 'sysndd:888' });

    expect(wrapper.text()).toContain('sysndd:888');

    const dismissModal = wrapper
      .findAllComponents(BModalStub)
      .find((c) => c.props('id') === 'dismiss-modal')!;
    await dismissModal.vm.$emit('ok');
    expect(wrapper.emitted('dismiss-ok')).toHaveLength(1);
  });

  it('does not render the duplicate notice when approveHasDuplicates is false', () => {
    const wrapper = mountModals({ approveHasDuplicates: false });
    expect(wrapper.text()).not.toContain('Other pending statuses for this entity');
  });

  it('forwards edit-status props to EditStatusModal and re-emits ok/hide/update:statusInfo', async () => {
    const wrapper = mountModals({ loadingEdit: true });

    const editStub = wrapper.findComponent(EditStatusModalStub);
    expect(editStub.exists()).toBe(true);
    expect(editStub.props('loading')).toBe(true);
    expect(editStub.props('statusInfo')).toEqual(baseStatusInfo);
    expect(editStub.props('entityInfo')).toEqual(baseEntityInfo);
    expect(editStub.props('statusOptions')).toEqual(baseStatusOptions);
    expect(editStub.props('userIcon')).toEqual({ Administrator: 'person-fill' });
    expect(editStub.props('modalId')).toBe('status-modal');

    await editStub.vm.$emit('ok');
    expect(wrapper.emitted('edit-ok')).toHaveLength(1);

    await editStub.vm.$emit('hide', 'esc');
    expect(wrapper.emitted('edit-hide')?.[0]).toEqual(['esc']);

    const nextInfo: StatusInfoShape = { ...baseStatusInfo, comment: 'updated' };
    await editStub.vm.$emit('update:statusInfo', nextInfo);
    expect(wrapper.emitted('update:statusInfo')?.[0]).toEqual([nextInfo]);
  });

  it('renders the total-rows count and forwards the approve-all switch/confirm', async () => {
    const wrapper = mountModals({ totalRows: 42, approveAllSelected: false });

    expect(wrapper.text()).toContain('42');

    const checkbox = wrapper.find('input[type="checkbox"]');
    await checkbox.setValue(true);
    expect(wrapper.emitted('update:approveAllSelected')?.[0]).toEqual([true]);

    const approveAllModal = wrapper
      .findAllComponents(BModalStub)
      .find((c) => c.props('id') === 'approveAllModal')!;
    await approveAllModal.vm.$emit('ok');
    expect(wrapper.emitted('approve-all-ok')).toHaveLength(1);
  });

  it('routes showModal/hideModal to the correct modal instance by id', async () => {
    const wrapper = mountModals();
    await nextTick();

    const approveEl = () => wrapper.get('[data-modal-id="approve-modal"]');
    const dismissEl = () => wrapper.get('[data-modal-id="dismiss-modal"]');
    const editEl = () => wrapper.get('[data-testid="edit-status-modal-stub"]');

    expect(approveEl().attributes('data-visible')).toBe('false');
    expect(dismissEl().attributes('data-visible')).toBe('false');

    (wrapper.vm as unknown as { showModal: (id: string) => void }).showModal('approve-modal');
    await nextTick();
    expect(approveEl().attributes('data-visible')).toBe('true');
    // Only the targeted modal toggles — proves showModal resolves by id,
    // not by "show every modal".
    expect(dismissEl().attributes('data-visible')).toBe('false');

    (wrapper.vm as unknown as { hideModal: (id: string) => void }).hideModal('approve-modal');
    await nextTick();
    expect(approveEl().attributes('data-visible')).toBe('false');

    (wrapper.vm as unknown as { showModal: (id: string) => void }).showModal('status-modal');
    await nextTick();
    expect(editEl().attributes('data-visible')).toBe('true');
  });

  it('showModal on an unknown id is a no-op (no throw)', () => {
    const wrapper = mountModals();
    expect(() =>
      (wrapper.vm as unknown as { showModal: (id: string) => void }).showModal('nope')
    ).not.toThrow();
  });
});

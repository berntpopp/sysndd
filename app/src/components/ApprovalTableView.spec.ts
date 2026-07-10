// components/ApprovalTableView.spec.ts
/**
 * Wave 2 Task 5 (#346) — container-level contract for `ApprovalTableView.vue`
 * after the four status-approval modals were extracted into
 * `@/components/review/StatusApprovalModals.vue`. Pins the behavior that
 * refactor must preserve:
 *   - parent-supplied `items` sync into the table composable (`items-synced`),
 *   - `totalRows`/`currentPage` reset when `ReviewTable` reports a `filtered`
 *     projection,
 *   - the `busy` prop mirrored into `ReviewTable`'s `is-busy` prop,
 *   - status-approval props/emits still forwarded through unchanged to the
 *     new `StatusApprovalModals` child, and `showModal`/`hideModal` still
 *     resolve (now one hop further, via a template ref to that child),
 *   - the table/cell/row/mobile slots this component owns are still wired.
 *
 * `ReviewTable` and `StatusApprovalModals` are stubbed for the container
 * tests (isolating this component's own wiring); a second `describe` block
 * uses a slot-forwarding `ReviewTable` fake plus lightweight badge/button
 * stubs to prove the cell/row-expansion/mobile-rows templates still render.
 */

import { describe, expect, it, vi } from 'vitest';
import { mount, type VueWrapper } from '@vue/test-utils';
import { defineComponent, nextTick } from 'vue';
import ApprovalTableView, { type StatusRowLike } from './ApprovalTableView.vue';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------
const baseProps = {
  items: [] as StatusRowLike[],
  loading: false,
  busy: false,
  approveTitle: '',
  dismissTitle: '',
  approveHasDuplicates: false,
  loadingEdit: false,
  statusInfo: {},
  entityInfo: {},
  statusOptions: [],
  approveAllSelected: false,
  userIcon: {},
  userStyle: {},
  stoplightsStyle: {},
};

interface ApprovalTableViewVm {
  totalRows: number;
  currentPage: number;
  filteredItems: StatusRowLike[];
  showModal: (id: string) => void;
  hideModal: (id: string) => void;
}
const vm = (wrapper: VueWrapper): ApprovalTableViewVm => wrapper.vm as unknown as ApprovalTableViewVm;

// ---------------------------------------------------------------------------
// Container-level stubs — no slot forwarding, just prop/emit capture.
// `ReviewTable` mirrors its real immediate `filtered` emit-on-mount so
// `totalRows` reflects the synced items without every test having to fire it
// manually (matching `ReviewTable.vue`'s own `watch(..., {immediate:true})`).
// ---------------------------------------------------------------------------
const ReviewTableStub = defineComponent({
  name: 'ReviewTable',
  props: [
    'title',
    'totalRowsLabel',
    'approveAllTitle',
    'approveAllAriaLabel',
    'items',
    'fields',
    'totalRows',
    'currentPage',
    'perPage',
    'pageOptions',
    'sortBy',
    'filterText',
    'categoryFilter',
    'userFilter',
    'dateStart',
    'dateEnd',
    'categoryOptions',
    'userOptions',
    'legendItems',
    'isBusy',
    'loading',
  ],
  emits: [
    'approve-all',
    'refresh',
    'update:currentPage',
    'update:perPage',
    'update:sortBy',
    'update:filterText',
    'update:categoryFilter',
    'update:userFilter',
    'update:dateStart',
    'update:dateEnd',
    'filtered',
  ],
  mounted() {
    this.$emit('filtered', this.items);
  },
  template: '<div data-testid="review-table-stub" />',
});

function statusApprovalModalsStub() {
  const showModalSpy = vi.fn();
  const hideModalSpy = vi.fn();
  const StatusApprovalModalsStub = {
    name: 'StatusApprovalModals',
    props: [
      'approveTitle',
      'dismissTitle',
      'approveHasDuplicates',
      'loadingEdit',
      'statusInfo',
      'entityInfo',
      'statusOptions',
      'approveAllSelected',
      'totalRows',
      'userIcon',
      'approveModalId',
      'dismissModalId',
      'editModalId',
      'approveAllModalId',
    ],
    emits: [
      'approve-ok',
      'dismiss-ok',
      'edit-ok',
      'edit-hide',
      'approve-all-ok',
      'update:approveAllSelected',
      'update:statusInfo',
    ],
    methods: { showModal: showModalSpy, hideModal: hideModalSpy },
    template: '<div data-testid="status-approval-modals-stub" />',
  };
  return { StatusApprovalModalsStub, showModalSpy, hideModalSpy };
}

function mountView(props: Record<string, unknown> = {}) {
  const { StatusApprovalModalsStub, showModalSpy, hideModalSpy } = statusApprovalModalsStub();
  const wrapper = mount(ApprovalTableView, {
    props: { ...baseProps, ...props },
    global: {
      stubs: { ReviewTable: ReviewTableStub, StatusApprovalModals: StatusApprovalModalsStub },
    },
  });
  return { wrapper, showModalSpy, hideModalSpy };
}

// ---------------------------------------------------------------------------
// Container state
// ---------------------------------------------------------------------------
describe('ApprovalTableView — container state', () => {
  it('syncs parent-supplied items into the table composable and emits items-synced', () => {
    const rows: StatusRowLike[] = [{ status_id: 1 }, { status_id: 2 }];
    const { wrapper } = mountView({ items: rows });

    expect(wrapper.emitted('items-synced')?.[0]).toEqual([rows]);
    expect(vm(wrapper).filteredItems).toEqual(rows);
  });

  it('resets totalRows and currentPage when ReviewTable reports a filtered projection', async () => {
    const rows: StatusRowLike[] = [{ status_id: 1 }, { status_id: 2 }, { status_id: 3 }];
    const { wrapper } = mountView({ items: rows });
    expect(vm(wrapper).totalRows).toBe(3);

    const reviewTable = wrapper.findComponent({ name: 'ReviewTable' });
    // Bump currentPage away from 1 first, so the reset is observable.
    await reviewTable.vm.$emit('update:currentPage', 3);
    expect(vm(wrapper).currentPage).toBe(3);

    await reviewTable.vm.$emit('filtered', [{ status_id: 2 }]);
    expect(vm(wrapper).totalRows).toBe(1);
    expect(vm(wrapper).currentPage).toBe(1);
  });

  it('mirrors the busy prop into ReviewTable is-busy, reactively', async () => {
    const { wrapper } = mountView({ busy: false });
    expect(wrapper.findComponent({ name: 'ReviewTable' }).props('isBusy')).toBe(false);

    await wrapper.setProps({ busy: true });
    expect(wrapper.findComponent({ name: 'ReviewTable' }).props('isBusy')).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Modal forwarding — the Wave 2 Task 5 boundary itself.
// ---------------------------------------------------------------------------
describe('ApprovalTableView — StatusApprovalModals forwarding', () => {
  it('forwards status-approval props unchanged to StatusApprovalModals', async () => {
    const { wrapper } = mountView({
      items: [{ status_id: 1 }, { status_id: 2 }],
      approveTitle: 'sysndd:501',
      dismissTitle: 'sysndd:502',
      approveHasDuplicates: true,
      loadingEdit: true,
      statusInfo: { status_id: 9 },
      entityInfo: { entity_id: 9 },
      statusOptions: [{ id: 1, label: 'Definitive' }],
      approveAllSelected: true,
      userIcon: { Administrator: 'person-fill' },
      approveModalId: 'custom-approve',
      dismissModalId: 'custom-dismiss',
      editModalId: 'custom-edit',
      approveAllModalId: 'custom-approve-all',
    });

    // `totalRows` starts at 0 (both ReviewTable's and StatusApprovalModals'
    // vnodes are built in the same initial render pass, before
    // `ReviewTableStub`'s `mounted()` hook fires the `filtered` event that
    // sets it) and only reaches this sibling once the resulting reactive
    // update flushes — unlike the exposed `totalRows` ref read directly
    // (see the "container state" describe block), which is always current.
    await nextTick();

    const modals = wrapper.findComponent({ name: 'StatusApprovalModals' });
    expect(modals.props('approveTitle')).toBe('sysndd:501');
    expect(modals.props('dismissTitle')).toBe('sysndd:502');
    expect(modals.props('approveHasDuplicates')).toBe(true);
    expect(modals.props('loadingEdit')).toBe(true);
    expect(modals.props('statusInfo')).toEqual({ status_id: 9 });
    expect(modals.props('entityInfo')).toEqual({ entity_id: 9 });
    expect(modals.props('statusOptions')).toEqual([{ id: 1, label: 'Definitive' }]);
    expect(modals.props('approveAllSelected')).toBe(true);
    expect(modals.props('userIcon')).toEqual({ Administrator: 'person-fill' });
    expect(modals.props('approveModalId')).toBe('custom-approve');
    expect(modals.props('dismissModalId')).toBe('custom-dismiss');
    expect(modals.props('editModalId')).toBe('custom-edit');
    expect(modals.props('approveAllModalId')).toBe('custom-approve-all');
    expect(modals.props('totalRows')).toBe(2);
  });

  it('re-emits StatusApprovalModals events unchanged', async () => {
    const { wrapper } = mountView();
    const modals = wrapper.findComponent({ name: 'StatusApprovalModals' });

    await modals.vm.$emit('approve-ok');
    expect(wrapper.emitted('approve-ok')).toHaveLength(1);
    await modals.vm.$emit('dismiss-ok');
    expect(wrapper.emitted('dismiss-ok')).toHaveLength(1);
    await modals.vm.$emit('edit-ok');
    expect(wrapper.emitted('edit-ok')).toHaveLength(1);
    await modals.vm.$emit('edit-hide', 'esc');
    expect(wrapper.emitted('edit-hide')?.[0]).toEqual(['esc']);
    await modals.vm.$emit('approve-all-ok');
    expect(wrapper.emitted('approve-all-ok')).toHaveLength(1);
    await modals.vm.$emit('update:approveAllSelected', true);
    expect(wrapper.emitted('update:approveAllSelected')?.[0]).toEqual([true]);
    const nextInfo = { status_id: 5 };
    await modals.vm.$emit('update:statusInfo', nextInfo);
    expect(wrapper.emitted('update:statusInfo')?.[0]).toEqual([nextInfo]);
  });

  it('delegates showModal/hideModal to the StatusApprovalModals child by id', () => {
    const { wrapper, showModalSpy, hideModalSpy } = mountView();

    vm(wrapper).showModal('approve-modal');
    expect(showModalSpy).toHaveBeenCalledWith('approve-modal');

    vm(wrapper).hideModal('dismiss-modal');
    expect(hideModalSpy).toHaveBeenCalledWith('dismiss-modal');
  });
});

// ---------------------------------------------------------------------------
// Table/cell/row/mobile slots — proves the refactor did not disturb the
// templates this component still owns (only the modal blocks moved out).
// ---------------------------------------------------------------------------
const SlotForwardingReviewTableStub = {
  name: 'ReviewTable',
  props: ['items'],
  template: `
    <div data-testid="review-table-stub">
      <slot name="cell(entity_id)" :item="items[0]" :index="0" />
      <slot name="cell(symbol)" :item="items[0]" :index="0" />
      <slot name="cell(disease_ontology_name)" :item="items[0]" :index="0" />
      <slot name="cell(hpo_mode_of_inheritance_term_name)" :item="items[0]" :index="0" />
      <slot name="cell(category)" :item="items[0]" :index="0" />
      <slot name="cell(problematic)" :item="items[0]" :index="0" />
      <slot name="cell(comment)" :item="items[0]" :index="0" />
      <slot name="cell(status_date)" :item="items[0]" :index="0" />
      <slot name="cell(status_user_name)" :item="items[0]" :index="0" />
      <slot
        name="cell(actions)"
        :item="items[0]"
        :index="0"
        :expansion-showing="false"
        :toggle-expansion="() => {}"
      />
      <slot name="row-expansion" :item="items[0]" :toggle-expansion="() => {}" />
      <slot name="mobile-rows" :items="items" />
    </div>
  `,
};

function mountViewWithSlots(item: StatusRowLike, props: Record<string, unknown> = {}) {
  const { StatusApprovalModalsStub } = statusApprovalModalsStub();
  return mount(ApprovalTableView, {
    props: { ...baseProps, items: [item], ...props },
    global: {
      directives: { 'b-tooltip': {} },
      stubs: {
        ReviewTable: SlotForwardingReviewTableStub,
        StatusApprovalModals: StatusApprovalModalsStub,
        EntityBadge: { props: ['entityId'], template: '<span>sysndd:{{ entityId }}</span>' },
        GeneBadge: { props: ['symbol'], template: '<span>{{ symbol }}</span>' },
        DiseaseBadge: { props: ['name'], template: '<span>{{ name }}</span>' },
        InheritanceBadge: { props: ['fullName'], template: '<span>{{ fullName }}</span>' },
        CategoryIcon: { props: ['category'], template: '<span>{{ category }}</span>' },
        BButton: { template: '<button v-bind="$attrs"><slot /></button>' },
        BBadge: { template: '<span><slot /></span>' },
        BCard: { template: '<div><slot name="header" /><slot /></div>' },
        BPopover: { template: '<div><slot name="title" /><slot /></div>' },
        ApprovalMobileRows: {
          props: ['items', 'userField', 'roleField', 'dateField'],
          emits: ['edit', 'approve', 'dismiss'],
          template: `
            <div data-testid="mobile-rows-stub">
              <span v-for="row in items" :key="row.status_id">{{ row.entity_id }}</span>
            </div>
          `,
        },
      },
    },
  });
}

const sampleItem: StatusRowLike = {
  status_id: 201,
  entity_id: 501,
  status_date: '2026-05-01 12:00:00',
  status_user_name: 'alice_admin',
  status_user_role: 'Administrator',
  category: 'Definitive',
  symbol: 'TEST1',
  hgnc_id: 'HGNC:12345',
  disease_ontology_id_version: 'MONDO:0000123_2025-01-01',
  disease_ontology_name: 'Test Disease',
  hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
  hpo_mode_of_inheritance_term: 'HP:0000006',
  comment: 'Needs review',
  problematic: 0,
  is_active: true,
  duplicate: 'no',
  review_change: false,
};

describe('ApprovalTableView — table/cell/row/mobile slots', () => {
  it('renders status-specific cell content and row-expansion details', () => {
    const wrapper = mountViewWithSlots(sampleItem, {
      userStyle: { Administrator: 'primary' },
      userIcon: { Administrator: 'person-fill' },
      stoplightsStyle: { Definitive: 'success' },
    });

    expect(wrapper.text()).toContain('sysndd:501');
    expect(wrapper.text()).toContain('TEST1');
    expect(wrapper.text()).toContain('Test Disease');
    expect(wrapper.text()).toContain('Autosomal dominant inheritance');
    expect(wrapper.text()).toContain('Needs review');
    expect(wrapper.text()).toContain('alice_admin');
    expect(wrapper.text()).toContain('Definitive');
  });

  it('emits row action events from the actions cell', async () => {
    const wrapper = mountViewWithSlots(sampleItem);

    await wrapper.get('[aria-label="Edit status for entity 501"]').trigger('click');
    expect(wrapper.emitted('edit-status')?.[0]).toEqual([sampleItem]);

    await wrapper.get('[aria-label="Approve status for entity 501"]').trigger('click');
    expect(wrapper.emitted('approve-status')?.[0]).toEqual([sampleItem]);

    await wrapper.get('[aria-label="Dismiss status for entity 501"]').trigger('click');
    expect(wrapper.emitted('dismiss-status')?.[0]).toEqual([sampleItem]);
  });

  it('forwards items into the mobile-rows slot', () => {
    const wrapper = mountViewWithSlots(sampleItem);
    const mobileRows = wrapper.get('[data-testid="mobile-rows-stub"]');
    expect(mobileRows.text()).toContain('501');
  });
});

import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import ReReviewAssignmentMobileRows from './ReReviewAssignmentMobileRows.vue';

const assignedRow = {
  user_id: 4,
  user_name: 'curator_one',
  re_review_batch: 12,
  re_review_review_saved: 3,
  re_review_status_saved: 2,
  re_review_submitted: 1,
  re_review_approved: 8,
  entity_count: 14,
};

const unassignedRow = {
  ...assignedRow,
  user_id: null,
  user_name: null,
  re_review_batch: 13,
};

describe('ReReviewAssignmentMobileRows', () => {
  it('shows assigned batch context and only reassignment actions', async () => {
    const wrapper = mount(ReReviewAssignmentMobileRows, {
      props: { items: [assignedRow] },
    });

    expect(wrapper.text()).toContain('Batch #12');
    expect(wrapper.text()).toContain('curator_one');
    expect(wrapper.text()).toContain('Assigned');
    expect(wrapper.text()).toContain('14 entities');
    expect(wrapper.text()).toContain('8 approved');

    expect(wrapper.find('[aria-label="Recalculate batch 12"]').exists()).toBe(false);
    await wrapper.get('[aria-label="Reassign batch 12"]').trigger('click');
    await wrapper.get('[aria-label="Unassign batch 12"]').trigger('click');

    expect(wrapper.emitted('open-reassign')?.[0]).toEqual([assignedRow]);
    expect(wrapper.emitted('unassign')?.[0]).toEqual([12]);
  });

  it('shows an unassigned status and only the recalculate action', async () => {
    const wrapper = mount(ReReviewAssignmentMobileRows, {
      props: { items: [unassignedRow] },
    });

    expect(wrapper.text()).toContain('Batch #13');
    expect(wrapper.text()).toContain('Unassigned');
    expect(wrapper.find('[aria-label="Reassign batch 13"]').exists()).toBe(false);
    expect(wrapper.find('[aria-label="Unassign batch 13"]').exists()).toBe(false);

    await wrapper.get('[aria-label="Recalculate batch 13"]').trigger('click');
    expect(wrapper.emitted('open-recalculate')?.[0]).toEqual([unassignedRow]);
  });
});

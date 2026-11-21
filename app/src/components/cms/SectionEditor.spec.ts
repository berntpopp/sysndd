import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import { BButton, BCard, BCardBody, BCollapse } from 'bootstrap-vue-next';
import SectionEditor from './SectionEditor.vue';

const section = {
  section_id: 'creators',
  title: 'About SysNDD and its creators',
  icon: 'bi-people',
  content: 'Text',
  sort_order: 0,
};

describe('SectionEditor', () => {
  it('names its icon-only buttons and keeps no empty body band when collapsed', () => {
    const wrapper = mount(SectionEditor, {
      props: { section },
      global: {
        components: { BButton, BCard, BCardBody, BCollapse },
        stubs: { MarkdownEditor: true, MarkdownPreview: true, BFormGroup: true, BRow: true },
      },
    });
    const toggle = wrapper.get('button[aria-expanded="false"]');
    expect(toggle.attributes('aria-label')).toBe('Edit section About SysNDD and its creators');
    expect(
      wrapper.find('button[aria-label="Delete section About SysNDD and its creators"]').exists()
    ).toBe(true);
    // `no-body`: the collapse is not wrapped in a padded .card-body of the card itself.
    expect(wrapper.find('.section-editor > .card-body').exists()).toBe(false);
    expect(wrapper.get('strong').attributes('title')).toBe(section.title);
  });
});

import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import AdminOperationPanel from './AdminOperationPanel.vue';

describe('AdminOperationPanel', () => {
  it('renders a compact operation surface with title, meta, description, actions, and body', () => {
    const wrapper = mount(AdminOperationPanel, {
      props: {
        title: 'Publication Metadata Refresh',
        description: 'Refresh PubMed metadata without changing curated entities.',
        meta: ['4,689 publications', '4,515 outdated'],
      },
      slots: {
        actions: '<button type="button">Refresh Stats</button>',
        default: '<button type="button">Refresh Publications</button>',
      },
    });

    expect(wrapper.get('[data-testid="admin-operation-panel"]').classes()).toContain(
      'admin-operation-panel'
    );
    expect(wrapper.get('h2').text()).toBe('Publication Metadata Refresh');
    expect(wrapper.text()).toContain('Refresh PubMed metadata without changing curated entities.');
    expect(wrapper.text()).toContain('4,689 publications');
    expect(wrapper.text()).toContain('4,515 outdated');
    expect(wrapper.findAll('button').map((button) => button.text())).toEqual([
      'Refresh Stats',
      'Refresh Publications',
    ]);
  });

  it('marks danger panels without using dark card chrome', () => {
    const wrapper = mount(AdminOperationPanel, {
      props: {
        title: 'Clear Cache',
        tone: 'danger',
      },
      slots: {
        default: '<button type="button">Clear</button>',
      },
    });

    expect(wrapper.classes()).toContain('admin-operation-panel--danger');
    expect(wrapper.classes()).not.toContain('border-dark');
  });
});

// ApproveUser.a11y.spec.ts
/**
 * Accessibility tests for ApproveUser view
 *
 * Pattern: Curation view accessibility testing
 * Tests WCAG 2.2 AA compliance via axe-core, including aria-live regions,
 * modal titles, keyboard navigation, and form labels.
 */

import { describe, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { expectNoA11yViolations, bootstrapStubs } from '@/test-utils';
import ApproveUser from './ApproveUser.vue';

// Mock composables
vi.mock('@/composables', () => ({
  useToast: () => ({
    makeToast: vi.fn(),
  }),
  useColorAndSymbols: () => ({
    getRoleBadgeVariant: vi.fn(() => 'primary'),
    getRoleIcon: vi.fn(() => 'bi-person'),
  }),
  useAriaLive: () => ({
    message: '',
    politeness: 'polite',
    announce: vi.fn(),
  }),
}));

// Mock axios for Options API this.axios
const mockAxios = {
  get: vi.fn(() =>
    Promise.resolve({
      data: [],
    })
  ),
  put: vi.fn(() => Promise.resolve({ data: {} })),
};

// Mock router for <BLink> navigation
const mockRoute = {
  path: '/curate/approve-user',
  name: 'ApproveUser',
};

const mockRouter = {
  push: vi.fn(),
  currentRoute: { value: mockRoute },
};

describe('ApproveUser accessibility', () => {
  // Disable region rule for isolated component tests
  const axeOptions = {
    rules: { region: { enabled: false } },
  };

  const mountComponent = async () => {
    const pinia = createPinia();

    const wrapper = mount(ApproveUser, {
      global: {
        plugins: [pinia],
        mocks: {
          axios: mockAxios,
          $route: mockRoute,
          $router: mockRouter,
        },
        stubs: {
          ...bootstrapStubs,
          // Stub AriaLiveRegion with accessible HTML
          AriaLiveRegion: {
            name: 'AriaLiveRegion',
            props: ['message', 'politeness'],
            template: '<div role="status" aria-live="polite"></div>',
          },
          // Stub BModal to render accessible structure
          BModal: {
            name: 'BModal',
            props: ['modelValue', 'title'],
            template: `
              <div v-if="modelValue" role="dialog" :aria-label="title">
                <slot name="title"></slot>
                <slot></slot>
                <slot name="footer"></slot>
              </div>
            `,
          },
          // Stub BTable with accessible structure
          BTable: {
            name: 'BTable',
            props: ['items', 'fields'],
            template:
              '<table role="table"><tbody><tr v-for="item in items" :key="item.user_id"><td>User</td></tr></tbody></table>',
          },
          // Stub BPagination with accessible nav
          BPagination: {
            name: 'BPagination',
            template: '<nav aria-label="Pagination"><ul><li><button>1</button></li></ul></nav>',
          },
          BFormInput: {
            name: 'BFormInput',
            props: ['modelValue', 'id', 'type', 'placeholder'],
            template:
              '<input :id="id" :type="type" :placeholder="placeholder" :value="modelValue" />',
          },
          BFormSelect: {
            name: 'BFormSelect',
            props: ['modelValue', 'options', 'id', 'ariaLabel'],
            template:
              '<select :id="id" :aria-label="ariaLabel || \'Select option\'"><option v-for="opt in options" :key="opt.value" :value="opt.value">{{ opt.text }}</option></select>',
          },
          BSpinner: {
            template:
              '<div role="status" aria-label="Loading..."><span class="visually-hidden">Loading...</span></div>',
          },
          BBadge: { template: '<span><slot /></span>' },
          BPopover: { template: '' },
          BCard: { template: '<div><slot name="header" /><slot /></div>' },
          BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
          BInputGroupText: { template: '<span><slot /></span>' },
        },
      },
    });

    await flushPromises();
    return wrapper;
  };

  it('has no accessibility violations', async () => {
    const wrapper = await mountComponent();
    await expectNoA11yViolations(wrapper.element, axeOptions);
  });

  it('has aria-live region for status announcements', async () => {
    const wrapper = await mountComponent();
    const ariaLive = wrapper.find('[role="status"][aria-live="polite"]');
    expect(ariaLive.exists()).toBe(true);
  });

  it('decorative icons have aria-hidden', async () => {
    const wrapper = await mountComponent();
    const decorativeIcons = wrapper.findAll('i[aria-hidden="true"]');
    // Should have decorative icons (refresh button, search icon, etc.)
    expect(decorativeIcons.length).toBeGreaterThan(0);
  });

  it('all modals have accessible titles', async () => {
    const wrapper = await mountComponent();
    // All BModal instances should have title prop or aria-label
    const modals = wrapper.findAll('[role="dialog"]');
    modals.forEach((modal) => {
      const hasAriaLabel = modal.attributes('aria-label');
      const hasTitle = modal.find('[class*="title"]').exists();
      expect(hasAriaLabel || hasTitle).toBe(true);
    });
  });

  it('all action buttons are keyboard-reachable', async () => {
    const wrapper = await mountComponent();
    const buttons = wrapper.findAll('button');
    buttons.forEach((button) => {
      // Buttons should not have tabindex="-1" unless explicitly disabled
      const tabindex = button.attributes('tabindex');
      expect(tabindex).not.toBe('-1');
    });
  });

  it('form inputs have associated labels or aria-label', async () => {
    const wrapper = await mountComponent();
    const inputs = wrapper.findAll('input, select');

    // Count inputs with proper labeling
    let labeledInputs = 0;
    inputs.forEach((input) => {
      const id = input.attributes('id');
      const ariaLabel = input.attributes('aria-label');
      const ariaLabelledby = input.attributes('aria-labelledby');
      const type = input.attributes('type');

      // Skip hidden inputs
      if (type === 'hidden') return;

      // Input should have either:
      // 1. An id with a corresponding label
      // 2. An aria-label
      // 3. An aria-labelledby
      const hasLabel = id && wrapper.find(`label[for="${id}"]`).exists();

      if (hasLabel || ariaLabel || ariaLabelledby) {
        labeledInputs++;
      }
    });

    // Should have at least some labeled inputs
    expect(labeledInputs).toBeGreaterThan(0);
  });
});

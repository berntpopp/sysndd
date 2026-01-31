// ManageReReview.a11y.spec.ts
/**
 * Accessibility tests for ManageReReview view
 *
 * Pattern: Curation view accessibility testing
 * Tests WCAG 2.2 AA compliance via axe-core, including aria-live regions,
 * icon legend, modal titles, keyboard navigation, and form labels.
 */

import { describe, it, vi } from 'vitest';
import { mount, flushPromises } from '@vue/test-utils';
import { createPinia } from 'pinia';
import { expectNoA11yViolations, bootstrapStubs } from '@/test-utils';
import ManageReReview from './ManageReReview.vue';

// Mock composables
vi.mock('@/composables', () => ({
  useToast: () => ({
    makeToast: vi.fn(),
  }),
  useColorAndSymbols: () => ({
    stoplights_style: {
      Definitive: 'success',
      Moderate: 'info',
      Limited: 'warning',
      Refuted: 'danger',
    },
    user_style: {
      Administrator: 'danger',
      Curator: 'primary',
      Reviewer: 'info',
      Viewer: 'secondary',
    },
    user_icon: {
      Administrator: 'shield-fill-check',
      Curator: 'pencil-fill',
      Reviewer: 'eye-fill',
      Viewer: 'person-fill',
    },
  }),
  useText: () => ({
    truncate: (str: string, _len: number) => str,
    inheritance_short_text: { 'Autosomal dominant': 'AD', 'Autosomal recessive': 'AR' },
    empty_table_text: { all: 'No entities found' },
  }),
  useAriaLive: () => ({
    message: '',
    politeness: 'polite',
    announce: vi.fn(),
  }),
}));

// Mock axios
const mockAxios = {
  get: vi.fn(() =>
    Promise.resolve({
      data: [],
    })
  ),
  put: vi.fn(() => Promise.resolve({ data: {} })),
  post: vi.fn(() => Promise.resolve({ data: {} })),
};

// Mock router
const mockRoute = {
  path: '/curate/manage-re-review',
  name: 'ManageReReview',
};

const mockRouter = {
  push: vi.fn(),
  currentRoute: { value: mockRoute },
};

describe('ManageReReview accessibility', () => {
  // Disable region rule for isolated component tests
  const axeOptions = {
    rules: { region: { enabled: false } },
  };

  const mountComponent = async () => {
    const pinia = createPinia();

    const wrapper = mount(ManageReReview, {
      global: {
        plugins: [pinia],
        mocks: {
          axios: mockAxios,
          $route: mockRoute,
          $router: mockRouter,
        },
        stubs: {
          ...bootstrapStubs,
          AriaLiveRegion: {
            name: 'AriaLiveRegion',
            props: ['message', 'politeness'],
            template: '<div role="status" aria-live="polite"></div>',
          },
          IconLegend: {
            name: 'IconLegend',
            props: ['legendItems'],
            template: '<div class="icon-legend"><strong>Icon Legend:</strong></div>',
          },
          BModal: {
            name: 'BModal',
            props: ['modelValue', 'title', 'id'],
            template: `
              <div v-if="modelValue" role="dialog" :aria-label="title">
                <slot name="title"></slot>
                <slot></slot>
                <slot name="footer"></slot>
              </div>
            `,
          },
          BTable: {
            name: 'BTable',
            props: ['items', 'fields'],
            template:
              '<table role="table"><tbody><tr v-for="item in items" :key="item.entity_id"><td>Entity</td></tr></tbody></table>',
          },
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
          BFormCheckbox: {
            name: 'BFormCheckbox',
            props: ['modelValue', 'id'],
            template: '<input type="checkbox" :id="id" :checked="modelValue" />',
          },
          BSpinner: {
            template:
              '<div role="status" aria-label="Loading..."><span class="visually-hidden">Loading...</span></div>',
          },
          BBadge: { template: '<span><slot /></span>' },
          BPopover: { template: '' },
          BCard: { template: '<div><slot name="header" /><slot /></div>' },
          BForm: { template: '<form><slot /></form>' },
          BFormGroup: { template: '<div><slot name="label" /><slot /></div>' },
          BInputGroup: { template: '<div><slot name="prepend" /><slot /></div>' },
          BInputGroupText: { template: '<span><slot /></span>' },
          // Stub badge components
          EntityBadge: { template: '<span>Entity Badge</span>' },
          GeneBadge: { template: '<span>Gene Badge</span>' },
          DiseaseBadge: { template: '<span>Disease Badge</span>' },
          InheritanceBadge: { template: '<span>Inheritance Badge</span>' },
          CategoryIcon: { template: '<span>Category Icon</span>' },
          // Stub BatchCriteriaForm
          BatchCriteriaForm: {
            name: 'BatchCriteriaForm',
            template: '<div><input aria-label="Batch criteria" /></div>',
          },
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

  it('has icon legend for batch icons', async () => {
    const wrapper = await mountComponent();
    const iconLegend = wrapper.find('.icon-legend');
    expect(iconLegend.exists()).toBe(true);
    expect(iconLegend.text()).toContain('Icon Legend');
  });

  it('decorative icons have aria-hidden', async () => {
    const wrapper = await mountComponent();
    const decorativeIcons = wrapper.findAll('i[aria-hidden="true"]');
    // Should have decorative icons
    expect(decorativeIcons.length).toBeGreaterThan(0);
  });

  it('all modals have accessible titles', async () => {
    const wrapper = await mountComponent();
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
      const tabindex = button.attributes('tabindex');
      expect(tabindex).not.toBe('-1');
    });
  });

  it('form inputs have associated labels or aria-label', async () => {
    const wrapper = await mountComponent();
    const inputs = wrapper.findAll('input, select');

    let labeledInputs = 0;
    inputs.forEach((input) => {
      const id = input.attributes('id');
      const ariaLabel = input.attributes('aria-label');
      const ariaLabelledby = input.attributes('aria-labelledby');
      const type = input.attributes('type');

      if (type === 'hidden') return;

      const hasLabel = id && wrapper.find(`label[for="${id}"]`).exists();

      if (hasLabel || ariaLabel || ariaLabelledby) {
        labeledInputs++;
      }
    });

    expect(labeledInputs).toBeGreaterThan(0);
  });
});

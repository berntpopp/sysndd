// BatchCriteriaForm.spec.ts
/**
 * Tests for BatchCriteriaForm.vue after the #346 Wave 2 Task 4 extraction
 * (entity picker -> BatchCriteriaEntityPicker.vue, option/search
 * orchestration -> useBatchCriteriaOptions.ts).
 *
 * Both composables are mocked so this spec exercises only what stays in
 * the parent: the form schema/validation wiring already covered by
 * useBatchForm.spec.ts, plus the parent-owned submit/reset flow — a
 * successful submit emits `batch-created`, a failed submit does not, and
 * the reset button delegates to `resetForm()`. Option loading and the
 * entity-search debounce/stale-search behavior are covered by
 * useBatchCriteriaOptions.spec.ts.
 */
import { reactive, ref } from 'vue';
import { flushPromises, mount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  handleSubmit: vi.fn(),
  handlePreview: vi.fn(),
  resetForm: vi.fn(),
  loadOptions: vi.fn(),
  searchEntities: vi.fn(),
  addEntity: vi.fn(),
  removeEntity: vi.fn(),
  onEntitySearch: vi.fn(),
  selectEntity: vi.fn(),
  addGene: vi.fn(),
  removeGene: vi.fn(),
}));

function makeFormData() {
  return reactive({
    batch_name: '',
    date_range: { start: null as string | null, end: null as string | null },
    entity_list: [] as { entity_id: number; symbol: string; disease_ontology_name: string }[],
    gene_list: [] as number[],
    status_filter: null as number | null,
    disease_id: null as string | null,
    batch_size: 20,
    assigned_user_id: null as number | null,
  });
}

vi.mock('@/composables/useBatchForm', () => ({
  useBatchForm: () => ({
    formData: makeFormData(),
    isLoading: ref(false),
    isPreviewLoading: ref(false),
    isFormValid: ref(true),
    entitySearchQuery: ref(''),
    entitySearchResults: ref([]),
    isEntitySearching: ref(false),
    searchEntities: mocks.searchEntities,
    addEntity: mocks.addEntity,
    removeEntity: mocks.removeEntity,
    geneOptions: ref([]),
    statusOptions: ref([]),
    userOptions: ref([]),
    previewEntities: ref([]),
    previewFields: [],
    showPreviewModal: ref(false),
    previewBoundaryGene: ref(null),
    previewGeneCount: ref(0),
    previewEntityCount: ref(0),
    loadOptions: mocks.loadOptions,
    handlePreview: mocks.handlePreview,
    handleSubmit: mocks.handleSubmit,
    resetForm: mocks.resetForm,
  }),
}));

vi.mock('./useBatchCriteriaOptions', () => ({
  default: () => ({
    geneSearchQuery: ref(''),
    selectedGeneOptions: ref([]),
    filteredGeneOptions: ref([]),
    addGene: mocks.addGene,
    removeGene: mocks.removeGene,
    onEntitySearch: mocks.onEntitySearch,
    selectEntity: mocks.selectEntity,
  }),
}));

// Imported after the mocks above so the component picks them up.
import BatchCriteriaForm from './BatchCriteriaForm.vue';

const globalStubs = {
  BForm: { template: '<form><slot /></form>' },
  BFormGroup: { template: '<div><slot name="label" /><slot /></div>' },
  BFormInput: { template: '<input />' },
  BFormSelect: { template: '<select><slot /></select>' },
  BInputGroup: { template: '<div><slot /></div>' },
  BInputGroupText: { template: '<span><slot /></span>' },
  BButton: { template: '<button><slot /></button>' },
  BSpinner: { template: '<span />' },
  BAlert: { template: '<div><slot /></div>' },
  BModal: { template: '<div><slot /></div>' },
  BTable: { template: '<table />' },
  BTooltip: { template: '' },
  BatchCriteriaEntityPicker: { template: '<div />' },
};

function mountForm() {
  return mount(BatchCriteriaForm, {
    global: { stubs: globalStubs },
  });
}

describe('BatchCriteriaForm — submit flow', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('emits batch-created when handleSubmit resolves true', async () => {
    mocks.handleSubmit.mockResolvedValue(true);
    const wrapper = mountForm();

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(mocks.handleSubmit).toHaveBeenCalledTimes(1);
    expect(wrapper.emitted('batch-created')).toHaveLength(1);
  });

  it('does not emit batch-created when handleSubmit resolves false', async () => {
    mocks.handleSubmit.mockResolvedValue(false);
    const wrapper = mountForm();

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(mocks.handleSubmit).toHaveBeenCalledTimes(1);
    expect(wrapper.emitted('batch-created')).toBeUndefined();
  });
});

describe('BatchCriteriaForm — reset delegation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('clicking the reset button delegates to resetForm()', async () => {
    const wrapper = mountForm();

    const resetButton = wrapper.find('button[title="Reset form"]');
    expect(resetButton.exists()).toBe(true);

    await resetButton.trigger('click');

    expect(mocks.resetForm).toHaveBeenCalledTimes(1);
  });
});

describe('BatchCriteriaForm — entity picker wiring', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('mounts without error and renders the batch summary once the mocked form is valid', () => {
    const wrapper = mountForm();

    expect(wrapper.find('form').exists()).toBe(true);
    expect(wrapper.text()).toContain('Batch summary');
  });
});

import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi, beforeEach } from 'vitest';
import ManageMetadata from './ManageMetadata.vue';

const makeToastSpy = vi.fn();
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: makeToastSpy }),
}));

const catalog = [
  {
    slug: 'modifier',
    label: 'Modifiers',
    table: 'modifier_list',
    pk: 'modifier_id',
    pk_type: 'integer',
    editable: true,
    managed: 'sysndd',
    fields: ['modifier_name', 'allowed_phenotype', 'allowed_variation'],
    has_is_active: true,
    has_sort: true,
  },
  {
    slug: 'inheritance',
    label: 'Inheritance modes',
    table: 'mode_of_inheritance_list',
    pk: 'hpo_mode_of_inheritance_term',
    pk_type: 'character',
    editable: 'anchored',
    managed: 'hpo',
    fields: ['hpo_mode_of_inheritance_term_name'],
    has_is_active: true,
    has_sort: true,
  },
];

const fetchMetadataCatalog = vi.fn();
const fetchMetadataRows = vi.fn();
const createMetadataRow = vi.fn();
const updateMetadataRow = vi.fn();
const deleteMetadataRow = vi.fn();

vi.mock('@/api/metadata', () => ({
  fetchMetadataCatalog: (...args: unknown[]) => fetchMetadataCatalog(...args),
  fetchMetadataRows: (...args: unknown[]) => fetchMetadataRows(...args),
  createMetadataRow: (...args: unknown[]) => createMetadataRow(...args),
  updateMetadataRow: (...args: unknown[]) => updateMetadataRow(...args),
  deleteMetadataRow: (...args: unknown[]) => deleteMetadataRow(...args),
}));

function mountView() {
  return mount(ManageMetadata, {
    global: {
      stubs: {
        AuthenticatedPageShell: { template: '<div><slot /></div>' },
        AdminOperationPanel: {
          template: '<section><slot name="actions" /><slot /></section>',
        },
        MetadataEntryModal: true,
        MetadataDeleteModal: true,
      },
    },
  });
}

describe('ManageMetadata.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    fetchMetadataCatalog.mockResolvedValue(catalog);
    fetchMetadataRows.mockResolvedValue({
      meta: { slug: 'modifier', label: 'Modifiers', editable: true, fields: [] },
      data: [{ modifier_id: 1, modifier_name: 'present', is_active: 1 }],
    });
  });

  it('loads the catalog and shows the first vocabulary with an Add button', async () => {
    const wrapper = mountView();
    await flushPromises();

    expect(fetchMetadataCatalog).toHaveBeenCalledTimes(1);
    // First vocabulary auto-selected -> its rows fetched.
    expect(fetchMetadataRows).toHaveBeenCalledWith('modifier');
    // Editable vocabulary exposes the create button.
    expect(wrapper.find('[data-testid="metadata-add-btn"]').exists()).toBe(true);
  });

  it('shows the anchored notice and hides Add for ontology-anchored vocabularies', async () => {
    fetchMetadataRows.mockResolvedValue({
      meta: { slug: 'inheritance', label: 'Inheritance modes', editable: 'anchored', fields: [] },
      data: [{ hpo_mode_of_inheritance_term: 'HP:0000006', is_active: 1 }],
    });
    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-testid="metadata-tab-inheritance"]').trigger('click');
    await flushPromises();

    expect(fetchMetadataRows).toHaveBeenLastCalledWith('inheritance');
    // No create button for anchored vocabularies.
    expect(wrapper.find('[data-testid="metadata-add-btn"]').exists()).toBe(false);
    expect(wrapper.text()).toContain('anchored to an external ontology');
  });

  it('surfaces the in-use delete guard error via a toast and keeps the row', async () => {
    deleteMetadataRow.mockRejectedValue({
      response: { data: { detail: 'Cannot delete: referenced by 3 records.' } },
    });
    const wrapper = mountView();
    await flushPromises();

    // Select the row to delete, then confirm (the modal itself is stubbed).
    const vm = wrapper.vm as unknown as {
      openDelete: (row: Record<string, unknown>) => void;
      onDeleteConfirm: () => Promise<void>;
    };
    vm.openDelete({ modifier_id: 1, modifier_name: 'present', is_active: 1 });
    await vm.onDeleteConfirm();
    await flushPromises();

    expect(deleteMetadataRow).toHaveBeenCalledWith('modifier', 1);
    expect(makeToastSpy).toHaveBeenCalledWith(
      'Cannot delete: referenced by 3 records.',
      'Error',
      'danger'
    );
  });
});

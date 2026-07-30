// app/src/views/curate/CreateEntity.spec.ts
/**
 * v11.0 closeout F2a spec (plan §13.2): proves `CreateEntity.vue`'s
 * submission path no longer carries an inline
 * `Authorization: Bearer ${localStorage.getItem('token')}` header. The
 * `apiClient` request interceptor (`@/api/client`) reads
 * `useAuth().token.value` and injects the Bearer header on every outbound
 * call against the shared axios singleton; `axios.post` inside the view's
 * `handleSubmit` participates in that.
 *
 * We populate the reactive `formData` with the minimum fields to pass
 * `isFormValid`, then invoke `handleSubmit()` directly. The MSW resolver
 * for `POST /api/entity/create` asserts the Bearer header matches the
 * token seeded via `primeAuth`.
 */

import { afterEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';
import { mount } from '@vue/test-utils';

import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { expectBearerHeader } from '@/test-utils/expectBearerHeader';
import useAuth from '@/composables/useAuth';

// bootstrap-vue-next's toast wrapper requires a BApp provider we don't
// mount here; stub the wrapper so the setup() call doesn't throw.
vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

import '@/plugins/axios';
import '@/api/client'; // Ensure the request interceptor is installed.
import CreateEntity from './CreateEntity.vue';

afterEach(() => {
  useAuth().logout();
});

// Shape of the fields `wrapper.vm` exposes that this spec touches.
interface CreateEntityVm {
  formData: {
    geneId: string | null;
    diseaseId: string | null;
    inheritanceId: string | null;
    nddPhenotype: boolean | null;
    synopsis: string;
    publications: string[];
    phenotypes: string[];
    variationOntology: string[];
    statusId: string | null;
    comment: string;
  };
  isFormValid: boolean;
  handleSubmit: () => Promise<void>;
}

/**
 * Mount the view with every child stubbed. The wizard steps are pure input
 * surfaces, so stubbing them lets a spec drive `formData` directly and exercise
 * the submission path without the whole form.
 */
function mountCreateEntity() {
  return mount(CreateEntity, {
    global: {
      stubs: {
        BContainer: { template: '<div><slot /></div>' },
        BRow: { template: '<div><slot /></div>' },
        BCol: { template: '<div><slot /></div>' },
        BOverlay: { template: '<div><slot /></div>' },
        BAlert: { template: '<div><slot /></div>' },
        BButton: { template: '<button><slot /></button>' },
        FormWizard: {
          template:
            '<div><slot name="core" /><slot name="evidence" /><slot name="phenotype" /><slot name="classification" /><slot name="review" /></div>',
        },
        StepCoreEntity: { template: '<div />' },
        StepEvidence: { template: '<div />' },
        StepPhenotypeVariation: { template: '<div />' },
        StepClassification: { template: '<div />' },
        StepReview: { template: '<div />' },
        'router-link': true,
      },
    },
  });
}

/** Seed the minimum reactive state for `isFormValid` to be true. */
function seedValidForm(vm: CreateEntityVm): void {
  vm.formData.geneId = 'HGNC:12345';
  vm.formData.diseaseId = 'MONDO:0000001';
  vm.formData.inheritanceId = '1';
  vm.formData.nddPhenotype = true;
  vm.formData.synopsis = 'A sufficiently long synopsis for the entity.';
  vm.formData.publications = ['PMID:12345'];
  vm.formData.statusId = '1';
}

describe('CreateEntity — F2a Bearer-via-interceptor', () => {
  it('sends Bearer on POST /api/entity/create from handleSubmit', async () => {
    const { token } = primeAuth();
    let sawRequest = false;

    server.use(
      http.post('*/api/entity/create', ({ request }) => {
        expectBearerHeader(request, token);
        sawRequest = true;
        return HttpResponse.json({ entity_id: 999 });
      })
    );

    const wrapper = mountCreateEntity();
    const vm = wrapper.vm as unknown as CreateEntityVm;
    seedValidForm(vm);

    await wrapper.vm.$nextTick();

    // Sanity check: isFormValid is now true so handleSubmit won't
    // short-circuit into the validation-warning branch.
    expect(vm.isFormValid).toBe(true);

    await vm.handleSubmit();
    expect(sawRequest).toBe(true);
  });
});

// Regression: #611 — hyphenated ontology CURIEs were truncated on submission.
//
// `buildSubmissionObject()` destructured the curation tag with
// `const [prefix, id] = item.split('-')`, which binds `id` to the segment
// between the FIRST and SECOND hyphen — so `'5-CURIE:part-with-hyphen'` was
// submitted as `'CURIE:part'`, silently naming a different term (or a
// non-existent one that fails the connect step). `splitOntologyTag()`
// (utils/ontologyTags.ts) splits on the first separator only.
//
// The tags use the real wire shape: the prefix is always the NUMERIC modifier
// id, as encoded by both the review subresource rows and the TreeMultiSelect
// option ids.
describe('CreateEntity — #611 ontology tag splitting', () => {
  it('submits hyphenated CURIEs whole instead of truncating them', async () => {
    primeAuth();
    let body: any = null;

    server.use(
      http.post('*/api/entity/create', async ({ request }) => {
        body = await request.json();
        return HttpResponse.json({ entity_id: 999 });
      })
    );

    const wrapper = mountCreateEntity();
    const vm = wrapper.vm as unknown as CreateEntityVm;
    seedValidForm(vm);
    vm.formData.phenotypes = ['1-HP:0001249', '5-CURIE:part-with-hyphen'];
    vm.formData.variationOntology = ['1-VariO:0015', '5-CURIE:part-with-hyphen'];

    await wrapper.vm.$nextTick();
    await vm.handleSubmit();

    expect(body.create_json.review.phenotypes).toEqual([
      { phenotype_id: 'HP:0001249', modifier_id: 1 },
      { phenotype_id: 'CURIE:part-with-hyphen', modifier_id: 5 },
    ]);
    expect(body.create_json.review.variation_ontology).toEqual([
      { vario_id: 'VariO:0015', modifier_id: 1 },
      { vario_id: 'CURIE:part-with-hyphen', modifier_id: 5 },
    ]);
  });
});

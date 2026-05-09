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

    const wrapper = mount(CreateEntity, {
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

    const vm = wrapper.vm as unknown as CreateEntityVm;

    // Seed the minimum reactive state for isFormValid to be true.
    vm.formData.geneId = 'HGNC:12345';
    vm.formData.diseaseId = 'MONDO:0000001';
    vm.formData.inheritanceId = '1';
    vm.formData.nddPhenotype = true;
    vm.formData.synopsis = 'A sufficiently long synopsis for the entity.';
    vm.formData.publications = ['PMID:12345'];
    vm.formData.statusId = '1';

    await wrapper.vm.$nextTick();

    // Sanity check: isFormValid is now true so handleSubmit won't
    // short-circuit into the validation-warning branch.
    expect(vm.isFormValid).toBe(true);

    await vm.handleSubmit();
    expect(sawRequest).toBe(true);
  });
});

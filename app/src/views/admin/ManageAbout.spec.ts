import { afterEach, describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import '@/api/client';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import ManageAbout from './ManageAbout.vue';

const stubs = {
  AuthenticatedPageShell: { template: '<main><slot /></main>' },
  AdminOperationPanel: { template: '<section><slot name="actions" /><slot /></section>' },
  BAlert: { template: '<div><slot /></div>' },
  BButton: { template: '<button><slot /></button>' },
  BCol: { template: '<div><slot /></div>' },
  BContainer: { template: '<div><slot /></div>' },
  BModal: { template: '<div><slot /></div>' },
  BRow: { template: '<div><slot /></div>' },
  BSpinner: { template: '<span />' },
  MarkdownPreview: { template: '<div />' },
  RouterLink: { template: '<a><slot /></a>' },
  SectionList: { template: '<div data-testid="section-list" />' },
};

const sampleSections = [
  {
    section_id: 'welcome',
    title: 'Welcome',
    icon: 'bi-info-circle',
    content: 'Existing content',
    sort_order: 0,
  },
];

describe('ManageAbout CMS load/autosave safety', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('does not replace a bare-array draft with defaults on unmount', async () => {
    primeAuth('about-admin-token');
    let savedBody: unknown = null;
    server.use(
      http.get('*/api/about/draft', () => HttpResponse.json(sampleSections)),
      http.put('*/api/about/draft', async ({ request }) => {
        savedBody = await request.json();
        return HttpResponse.json({ message: 'saved' });
      })
    );

    const wrapper = mount(ManageAbout, { global: { stubs } });
    await flushPromises();
    wrapper.unmount();
    await flushPromises();

    expect(savedBody).toEqual({ sections: sampleSections });
  });

  it('does not autosave default preview sections when the API returns an empty array', async () => {
    primeAuth('empty-about-admin-token');
    let putCount = 0;
    server.use(
      http.get('*/api/about/draft', () => HttpResponse.json([])),
      http.put('*/api/about/draft', () => {
        putCount += 1;
        return HttpResponse.json({ message: 'saved' });
      })
    );

    const wrapper = mount(ManageAbout, { global: { stubs } });
    await flushPromises();
    wrapper.unmount();
    await flushPromises();

    expect(putCount).toBe(0);
  });
});

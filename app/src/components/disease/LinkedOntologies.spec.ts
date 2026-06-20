import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import type { DiseaseMappingResponse } from '@/api/disease-mappings';
import LinkedOntologies from './LinkedOntologies.vue';

const mockData: DiseaseMappingResponse = {
  disease_ontology_id: 'OMIM:618524',
  disease_ontology_name: 'Test Disease',
  mondo_id: 'MONDO:0032745',
  release_version: '2026-05-05',
  status: 'current',
  mappings: {
    MONDO: [{ id: 'MONDO:0032745', label: null, predicate: 'exactMatch', source: 'sysndd_native' }],
    Orphanet: [{ id: 'Orphanet:530983', label: null, predicate: 'exactMatch', source: 'mondo_sssom' }],
    UMLS: [{ id: 'UMLS:C1234567', label: null, predicate: 'closeMatch', source: 'mondo_sssom' }],
  },
};

function mountComponent(props = {}) {
  return mount(LinkedOntologies, {
    props: { data: mockData, ...props },
    global: { stubs: { ResourceLink: false } },
  });
}

describe('LinkedOntologies', () => {
  it('renders MONDO and Orphanet as anchor links with correct hrefs', () => {
    const wrapper = mountComponent();
    const links = wrapper.findAll('a[target="_blank"]');
    const hrefs = links.map(l => l.attributes('href'));
    expect(hrefs.some(h => h?.includes('purl.obolibrary.org'))).toBe(true); // MONDO
    expect(hrefs.some(h => h?.includes('orpha.net'))).toBe(true); // Orphanet
  });

  it('renders UMLS as a non-link badge (no <a> for UMLS)', () => {
    const wrapper = mountComponent();
    const links = wrapper.findAll('a[target="_blank"]');
    const hrefs = links.map(l => l.attributes('href'));
    expect(hrefs.every(h => !h?.includes('UMLS'))).toBe(true);
    // UMLS entry still visible in text
    expect(wrapper.text()).toContain('UMLS:C1234567');
  });

  it('hides empty groups (no empty prefix rendered)', () => {
    const wrapper = mountComponent({ data: { ...mockData, mappings: { MONDO: [{ id: 'MONDO:0032745', label: null, predicate: null, source: 'sysndd_native' }] } } });
    expect(wrapper.text()).not.toContain('Orphanet');
    expect(wrapper.text()).not.toContain('UMLS');
  });

  it('shows "being prepared" note for status missing', () => {
    const wrapper = mountComponent({ data: { ...mockData, status: 'missing', mappings: {} } });
    expect(wrapper.text().toLowerCase()).toContain('being prepared');
  });
});

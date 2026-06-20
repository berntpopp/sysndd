import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import type { DiseaseMappingResponse } from '@/api/disease-mappings';
import { ontologyOutlink } from '@/assets/js/constants/ontology_links';
import LinkedOntologies from './LinkedOntologies.vue';

const mockData: DiseaseMappingResponse = {
  disease_ontology_id: 'OMIM:618524',
  disease_ontology_name: 'Test Disease',
  mondo_id: 'MONDO:0032745',
  release_version: '2026-05-05',
  status: 'current',
  mappings: {
    MONDO: [{ id: 'MONDO:0032745', label: null, predicate: 'exactMatch', source: 'sysndd_native' }],
    Orphanet: [
      { id: 'Orphanet:530983', label: null, predicate: 'exactMatch', source: 'mondo_sssom' },
    ],
    UMLS: [{ id: 'UMLS:C1234567', label: null, predicate: 'closeMatch', source: 'mondo_sssom' }],
  },
};

function mountComponent(props = {}) {
  return mount(LinkedOntologies, {
    props: { data: mockData, ...props },
  });
}

describe('LinkedOntologies', () => {
  it('renders MONDO and Orphanet as anchor links with correct hrefs', () => {
    const wrapper = mountComponent();
    const links = wrapper.findAll('a[target="_blank"]');
    const hrefs = links.map((l) => l.attributes('href'));
    // M-2: exact href assertions
    expect(hrefs).toContain(ontologyOutlink('MONDO', 'MONDO:0032745').url);
    expect(hrefs).toContain(ontologyOutlink('Orphanet', 'Orphanet:530983').url);
  });

  it('renders UMLS as a non-link badge (no <a> for UMLS)', () => {
    const wrapper = mountComponent();
    const links = wrapper.findAll('a[target="_blank"]');
    const hrefs = links.map((l) => l.attributes('href'));
    expect(hrefs.every((h) => !h?.includes('UMLS'))).toBe(true);
    // UMLS entry still visible in text
    expect(wrapper.text()).toContain('UMLS:C1234567');
  });

  it('hides empty groups (no empty prefix rendered)', () => {
    const wrapper = mountComponent({
      data: {
        ...mockData,
        mappings: {
          MONDO: [{ id: 'MONDO:0032745', label: null, predicate: null, source: 'sysndd_native' }],
        },
      },
    });
    expect(wrapper.text()).not.toContain('Orphanet');
    expect(wrapper.text()).not.toContain('UMLS');
  });

  it('shows "being prepared" note for status missing', () => {
    const wrapper = mountComponent({ data: { ...mockData, status: 'missing', mappings: {} } });
    expect(wrapper.text().toLowerCase()).toContain('being prepared');
  });

  // M-1: assert rel="noopener noreferrer" on external links
  it('sets rel="noopener noreferrer" on all external anchor links', () => {
    const wrapper = mountComponent();
    const links = wrapper.findAll('a[target="_blank"]');
    expect(links.length).toBeGreaterThan(0);
    for (const link of links) {
      const rel = link.attributes('rel') ?? '';
      expect(rel).toContain('noopener');
      expect(rel).toContain('noreferrer');
    }
  });

  // F-1: assert ResourceLink is rendered (composed, not a hand-rolled badge)
  it('renders ResourceLink components for each mapping entry', () => {
    const wrapper = mountComponent();
    // ResourceLink compact mode renders .resource-badge elements
    const badges = wrapper.findAll('.resource-badge');
    // 3 entries: MONDO, Orphanet, UMLS
    expect(badges.length).toBe(3);
  });

  // M-4: loading state
  it('renders loading state when loading=true', () => {
    const wrapper = mountComponent({ data: null, loading: true });
    expect(wrapper.find('.linked-ontologies__loading').exists()).toBe(true);
    expect(wrapper.find('.linked-ontologies__loading-text').text()).toContain('Loading');
  });

  // M-4: null data state
  it('renders nothing when data=null and loading=false', () => {
    const wrapper = mountComponent({ data: null, loading: false });
    expect(wrapper.find('.linked-ontologies__loading').exists()).toBe(false);
    expect(wrapper.find('.linked-ontologies__missing').exists()).toBe(false);
    expect(wrapper.findAll('.linked-ontologies__group').length).toBe(0);
  });
});

// ontology_links.spec.ts
//
// Issue #98 — VariO links must be built from a configurable base (not the dead
// aber-owl.net fragment URL) and must encode the stored `VariO:NNNN` id as an
// OBO PURL IRI the EBI OLS4 term browser understands.

import { describe, expect, it, vi, afterEach } from 'vitest';

const OLS4_BASE = 'https://www.ebi.ac.uk/ols4/ontologies/vario/classes?iri=';
const VARIO_0001_IRI = encodeURIComponent('http://purl.obolibrary.org/obo/VariO_0001');

describe('ontology_links — varioTermUrl', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.resetModules();
  });

  it('builds an EBI OLS4 term link with the OBO PURL IRI for a VariO:NNNN id', async () => {
    const { varioTermUrl, VARIO_BASE_URL } = await import('./ontology_links');

    // Default base is the verified OLS4 endpoint, not the old aber-owl.net URL.
    expect(VARIO_BASE_URL).toBe(OLS4_BASE);
    expect(VARIO_BASE_URL).not.toContain('aber-owl.net');

    const url = varioTermUrl('VariO:0001');
    expect(url).toBe(`${OLS4_BASE}${VARIO_0001_IRI}`);
    // Colon -> underscore in the OBO local id; full IRI is percent-encoded.
    expect(url).toContain('VariO_0001');
    expect(url).not.toContain('VariO:0001');
    expect(url.startsWith('https://')).toBe(true);
  });

  it('handles any VariO id consistently', async () => {
    const { varioTermUrl } = await import('./ontology_links');
    expect(varioTermUrl('VariO:0133')).toBe(
      `${OLS4_BASE}${encodeURIComponent('http://purl.obolibrary.org/obo/VariO_0133')}`
    );
  });

  it('returns an empty string for blank, null, or malformed ids', async () => {
    const { varioTermUrl } = await import('./ontology_links');
    expect(varioTermUrl('')).toBe('');
    expect(varioTermUrl(null)).toBe('');
    expect(varioTermUrl(undefined)).toBe('');
    expect(varioTermUrl('not an id')).toBe('');
    expect(varioTermUrl('VariO0001')).toBe('');
  });

  it('respects the VITE_VARIO_BASE_URL deploy-time override', async () => {
    vi.stubEnv('VITE_VARIO_BASE_URL', 'https://example.org/vario/term?iri=');
    vi.resetModules();
    const { varioTermUrl, VARIO_BASE_URL } = await import('./ontology_links');

    expect(VARIO_BASE_URL).toBe('https://example.org/vario/term?iri=');
    expect(varioTermUrl('VariO:0001')).toBe(`https://example.org/vario/term?iri=${VARIO_0001_IRI}`);
  });
});

import { ontologyOutlink } from '@/assets/js/constants/ontology_links';
describe('ontologyOutlink', () => {
  it('builds OMIM/MONDO/Orphanet/DOID urls', () => {
    expect(ontologyOutlink('OMIM','OMIM:618524').url).toBe('https://www.omim.org/entry/618524');
    expect(ontologyOutlink('MONDO','MONDO:0032745').url).toBe('http://purl.obolibrary.org/obo/MONDO_0032745');
    expect(ontologyOutlink('Orphanet','Orphanet:530983').url).toContain('orpha.net');
    expect(ontologyOutlink('DOID','DOID:0081234').url).toBe('https://disease-ontology.org/term/DOID:0081234');
  });
  it('returns null url for UMLS (no clean deep-link) and keeps the full CURIE label', () => {
    const out = ontologyOutlink('UMLS','UMLS:C1234567');
    expect(out.url).toBeNull();
    expect(out.label).toBe('UMLS:C1234567');
  });
});

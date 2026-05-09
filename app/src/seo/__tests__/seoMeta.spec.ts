import { describe, expect, it } from 'vitest';
import { buildEntitySeo, buildGeneSeo, escapeHtml } from '../seoMeta';
import type { EntitySeoPayload, GeneSeoPayload } from '../seoTypes';

describe('seoMeta', () => {
  it('builds CHD8 gene metadata with canonical URL and escaped visible content', () => {
    const payload: GeneSeoPayload = {
      symbol: 'CHD8',
      name: 'chromodomain helicase DNA binding protein 8',
      hgncId: 'HGNC:20153',
      ensemblGeneId: 'ENSG00000100888',
      entrezId: '57680',
      omimId: '610528',
      entityCount: 2,
      diseases: ['autism', 'CHD8-related neurodevelopmental disorder with overgrowth'],
      inheritanceModes: ['Autosomal dominant'],
      classifications: [{ label: 'Definitive', count: 1 }],
      nddStatuses: [{ label: 'NDD', count: 2 }],
      pmids: ['22495309', '24998929'],
      lastModified: '2026-05-09',
    };

    const result = buildGeneSeo(payload, 'https://sysndd.dbmr.unibe.ch');

    expect(result.title).toBe(
      'CHD8 Gene-Disease Associations in Neurodevelopmental Disorders | SysNDD'
    );
    expect(result.description).toContain('CHD8');
    expect(result.description).toContain('2 curated gene-disease associations');
    expect(result.canonicalUrl).toBe('https://sysndd.dbmr.unibe.ch/Genes/CHD8');
    expect(result.h1).toBe('CHD8 - chromodomain helicase DNA binding protein 8');
    expect(result.html).toContain('Autosomal dominant');
    expect(result.html).toContain('PMID:22495309');
    expect(result.jsonLd['@type']).toBe('WebPage');
  });

  it('builds entity metadata with gene, disease, inheritance, classification, and PMID facts', () => {
    const payload: EntitySeoPayload = {
      entityId: '123',
      symbol: 'CHD8',
      hgncId: 'HGNC:20153',
      diseaseName: 'autism',
      diseaseOntologyId: 'OMIM:209850',
      inheritanceName: 'Autosomal dominant',
      classification: 'Definitive',
      nddStatus: 'NDD',
      synopsis: 'Curated CHD8 association with autism and developmental delay.',
      hpoTerms: [{ id: 'HP:0000729', label: 'Autistic behavior' }],
      variationTerms: [{ id: 'VariO:0133', label: 'loss of function variant' }],
      pmids: ['22495309'],
      lastModified: '2026-05-09',
    };

    const result = buildEntitySeo(payload, 'https://sysndd.dbmr.unibe.ch');

    expect(result.title).toBe('Entity 123: CHD8, Autosomal dominant, autism | SysNDD');
    expect(result.description).toContain('Definitive');
    expect(result.canonicalUrl).toBe('https://sysndd.dbmr.unibe.ch/Entities/123');
    expect(result.h1).toBe('CHD8 - autism');
    expect(result.html).toContain('HP:0000729');
    expect(result.html).toContain('PMID:22495309');
  });

  it('escapes text used in generated HTML', () => {
    expect(escapeHtml('CHD8 <script>alert("x")</script>')).toBe(
      'CHD8 &lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;'
    );
  });
});

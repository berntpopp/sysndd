import { describe, expect, it } from 'vitest';
import { phenotypeCorrelationLink, variantCorrelationLink } from './correlogramLinks';

const SCOPE = 'contains(ndd_phenotype_word,Yes),any(category,Definitive)';

describe('correlogram drill-down links (#709)', () => {
  it('phenotype cell lists scoped entities with both terms present', () => {
    expect(phenotypeCorrelationLink('HP:0001250', 'HP:0000252')).toBe(
      `/Phenotypes?sort=entity_id&filter=${SCOPE},all(modifier_phenotype_id,1-HP:0001250,1-HP:0000252)&page_after=0&page_size=10`
    );
  });

  it('variant cell lists scoped entities carrying both terms', () => {
    expect(variantCorrelationLink('VariO:0015', 'VariO:0017')).toBe(
      `/Entities?sort=entity_id&filter=${SCOPE},all(vario_id,VariO:0015,VariO:0017)&page_after=0&page_size=10`
    );
  });

  it('diagonal cell names its single term once', () => {
    expect(phenotypeCorrelationLink('HP:0001250', 'HP:0001250')).toContain(
      'all(modifier_phenotype_id,1-HP:0001250)&'
    );
    expect(variantCorrelationLink('VariO:0015', 'VariO:0015')).toContain(
      'all(vario_id,VariO:0015)&'
    );
  });
});

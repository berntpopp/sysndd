import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import VariantPanel from './VariantPanel.vue';
import type { ClinVarVariant } from '@/types/external';

const variant: ClinVarVariant = {
  clinical_significance: 'Pathogenic',
  clinvar_variation_id: '123',
  gold_stars: 2,
  hgvsc: 'c.29G>A',
  hgvsp: 'p.Arg10His',
  in_gnomad: false,
  major_consequence: 'missense_variant',
  pos: 1000,
  review_status: 'criteria provided',
  variant_id: '1-1000-G-A',
};

describe('VariantPanel', () => {
  it('renders ClinVar variants as native list items with labelled checkboxes', () => {
    const wrapper = mount(VariantPanel, {
      props: { variants: [variant] },
      global: {
        stubs: {
          BButton: { template: '<button><slot /></button>' },
          VariantTooltip: { template: '<div />' },
        },
      },
    });

    expect(wrapper.get('ul[aria-label="ClinVar variants with protein positions"]')).toBeTruthy();
    expect(wrapper.findAll('ul > li')).toHaveLength(1);
    expect(wrapper.get('li label input').attributes('aria-label')).toContain('p.Arg10His');
  });
});

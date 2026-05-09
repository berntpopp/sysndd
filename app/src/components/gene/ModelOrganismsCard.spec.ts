import { describe, expect, it } from 'vitest';
import { mount } from '@vue/test-utils';
import ModelOrganismsCard from './ModelOrganismsCard.vue';
import type { MGIPhenotypeData, RGDPhenotypeData } from '@/types/external';

const bootstrapStubs = {
  BCard: { template: '<section><slot name="header" /><slot /></section>' },
  BButton: { template: '<a><slot /></a>' },
  BSpinner: { template: '<span />' },
  BPopover: {
    props: ['modelValue', 'target'],
    template:
      '<div class="popover-stub" :data-target="target" :data-model-value="String(modelValue)"><slot name="title" /><slot /></div>',
  },
};

const emptyMgiData: MGIPhenotypeData = {
  source: 'mgi',
  gene_symbol: 'NAA10',
  mgi_id: 'MGI:12345',
  mouse_symbol: 'Naa10',
  marker_name: null,
  phenotype_count: 0,
  phenotypes: [],
  mgi_url: 'https://www.informatics.jax.org/marker/MGI:12345',
};

const emptyRgdData: RGDPhenotypeData = {
  source: 'rgd',
  gene_symbol: 'NAA10',
  rgd_id: '12345',
  rat_symbol: 'Naa10',
  rat_name: null,
  phenotype_count: 0,
  phenotypes: [],
  rgd_url: 'https://rgd.mcw.edu/rgdweb/report/gene/main.html?id=12345',
};

function mountCard(props: {
  mgiLoading?: boolean;
  mgiError?: string | null;
  mgiData?: MGIPhenotypeData | null;
  rgdLoading?: boolean;
  rgdError?: string | null;
  rgdData?: RGDPhenotypeData | null;
}) {
  return mount(ModelOrganismsCard, {
    props: {
      geneSymbol: 'NAA10',
      mgiLoading: props.mgiLoading ?? false,
      mgiError: props.mgiError ?? null,
      mgiData: props.mgiData ?? null,
      rgdLoading: props.rgdLoading ?? false,
      rgdError: props.rgdError ?? null,
      rgdData: props.rgdData ?? null,
    },
    global: {
      stubs: bootstrapStubs,
      directives: {
        'b-tooltip': {},
      },
    },
  });
}

describe('ModelOrganismsCard', () => {
  it('renders the combined empty copy when both model organism sources return no phenotypes', () => {
    const wrapper = mountCard({
      mgiData: emptyMgiData,
      rgdData: emptyRgdData,
    });

    expect(wrapper.text()).toContain('No mouse or rat phenotype data returned for this gene.');
  });

  it('renders the combined empty copy when both model organism sources are empty null states', () => {
    const wrapper = mountCard({
      mgiData: null,
      rgdData: null,
    });

    expect(wrapper.text()).toContain('No mouse or rat phenotype data returned for this gene.');
  });

  it('starts the mouse phenotype badge accessible name with the visible badge text', () => {
    const mgiData: MGIPhenotypeData = {
      ...emptyMgiData,
      phenotype_count: 55,
      phenotypes: [{ phenotype_id: 'MP:0000001', term: 'abnormal phenotype' }],
    };

    const wrapper = mountCard({
      mgiData,
      rgdData: emptyRgdData,
    });

    const badge = wrapper.get('[aria-label^="55 mouse phenotypes"]');

    expect(badge.text()).toContain('55 mouse phenotypes');
    expect(badge.attributes('aria-label')).toBe('55 mouse phenotypes from MGI. Click to see all.');
  });

  it('renders zero mouse phenotypes as noninteractive text in mixed source states', () => {
    const rgdData: RGDPhenotypeData = {
      ...emptyRgdData,
      phenotype_count: 12,
      phenotypes: [{ term: 'abnormal phenotype' }],
    };

    const wrapper = mountCard({
      mgiData: emptyMgiData,
      rgdData,
    });

    expect(wrapper.text()).toContain('0 mouse phenotypes');
    expect(wrapper.find('[aria-label^="0 mouse phenotypes"][role="button"]').exists()).toBe(false);
    expect(wrapper.find('[aria-label^="0 mouse phenotypes"][tabindex="0"]').exists()).toBe(false);
  });

  it('opens the mouse phenotype popover on Space', async () => {
    const mgiData: MGIPhenotypeData = {
      ...emptyMgiData,
      phenotype_count: 55,
      phenotypes: [{ phenotype_id: 'MP:0000001', term: 'abnormal phenotype' }],
    };

    const wrapper = mountCard({
      mgiData,
      rgdData: emptyRgdData,
    });

    const badge = wrapper.get('[aria-label^="55 mouse phenotypes"]');

    expect(wrapper.get('[data-target="mgi-phenotypes-NAA10"]').attributes('data-model-value')).toBe(
      'false'
    );

    await badge.trigger('keydown', { key: ' ', code: 'Space' });

    expect(wrapper.get('[data-target="mgi-phenotypes-NAA10"]').attributes('data-model-value')).toBe(
      'true'
    );
  });

  it('starts the rat phenotype badge accessible name with the visible badge text', () => {
    const rgdData: RGDPhenotypeData = {
      ...emptyRgdData,
      phenotype_count: 12,
      phenotypes: [{ term: 'abnormal phenotype' }],
    };

    const wrapper = mountCard({
      mgiData: emptyMgiData,
      rgdData,
    });

    const badge = wrapper.get('[aria-label^="12 rat phenotypes"]');

    expect(badge.text()).toContain('12 rat phenotypes');
    expect(badge.attributes('aria-label')).toBe('12 rat phenotypes from RGD. Click to see all.');
  });

  it('opens the rat phenotype popover on Space', async () => {
    const rgdData: RGDPhenotypeData = {
      ...emptyRgdData,
      phenotype_count: 12,
      phenotypes: [{ term: 'abnormal phenotype' }],
    };

    const wrapper = mountCard({
      mgiData: emptyMgiData,
      rgdData,
    });

    const badge = wrapper.get('[aria-label^="12 rat phenotypes"]');

    expect(wrapper.get('[data-target="rgd-phenotypes-NAA10"]').attributes('data-model-value')).toBe(
      'false'
    );

    await badge.trigger('keydown', { key: ' ', code: 'Space' });

    expect(wrapper.get('[data-target="rgd-phenotypes-NAA10"]').attributes('data-model-value')).toBe(
      'true'
    );
  });

  it('uses high-contrast source badges for external model organism links', () => {
    const wrapper = mountCard({
      mgiData: emptyMgiData,
      rgdData: emptyRgdData,
    });

    const badges = wrapper.findAll('.model-org-source-badge');

    expect(badges).toHaveLength(2);
    badges.forEach((badge) => {
      expect(badge.classes()).not.toContain('bg-secondary');
    });
  });
});

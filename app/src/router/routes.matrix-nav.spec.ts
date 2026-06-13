/**
 * Issue #89 — discoverable navigation to the Curation matrix and Correlation
 * matrix analyses.
 *
 * These specs pin the navigation contract added for #89:
 *
 *   1. The public "Analyses" navbar dropdown exposes direct entries for the
 *      Curation matrix (`/CurationComparisons/Similarity`) and the Correlation
 *      matrix (`/PhenotypeFunctionalCorrelation`), so neither requires a user
 *      to first drill into a parent analysis page.
 *   2. The router resolves those paths to stable named routes, so cross-links
 *      can target route names rather than hardcoded URLs.
 *   3. The related-analysis cross-link tabs render on the Phenotype
 *      correlations shell and the Correlation matrix page and point at the
 *      named routes.
 */

import { mount, RouterLinkStub } from '@vue/test-utils';
import { createRouter, createMemoryHistory } from 'vue-router';
import { describe, expect, it, vi } from 'vitest';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

vi.mock('@/composables/useAuth', () => ({
  useAuth: () => ({
    isAuthenticated: { value: false },
    isExpired: { value: false },
    hasRole: () => false,
  }),
}));

import { routes } from './routes';
import { DROPDOWN_ITEMS_LEFT } from '@/assets/js/constants/main_nav_constants';
import PhenotypeCorrelations from '@/views/analyses/PhenotypeCorrelations.vue';
import PhenotypeFunctionalCorrelation from '@/views/analyses/PhenotypeFunctionalCorrelation.vue';

describe('Curation/Correlation matrix navigation (#89)', () => {
  it('adds direct Curation matrix and Correlation matrix entries to the Analyses dropdown', () => {
    const analyses = DROPDOWN_ITEMS_LEFT.find((d) => d.id === 'analyses_dropdown');
    expect(analyses).toBeDefined();

    const curationMatrix = analyses?.items.find((i) => i.text === 'Curation matrix');
    expect(curationMatrix?.path).toBe('/CurationComparisons/Similarity');

    const correlationMatrix = analyses?.items.find(
      (i) => i.text === 'Phenotype–function correlation'
    );
    expect(correlationMatrix?.path).toBe('/PhenotypeFunctionalCorrelation');
  });

  it('keeps the parent "Compare curations" and "Correlate phenotypes" entries', () => {
    const analyses = DROPDOWN_ITEMS_LEFT.find((d) => d.id === 'analyses_dropdown');
    const paths = analyses?.items.map((i) => i.path);
    expect(paths).toContain('/CurationComparisons');
    expect(paths).toContain('/PhenotypeCorrelations');
  });

  it('groups the curation matrix after its parent and keeps the phenotype–function correlation last', () => {
    const analyses = DROPDOWN_ITEMS_LEFT.find((d) => d.id === 'analyses_dropdown');
    const texts = analyses?.items.map((i) => i.text) ?? [];

    expect(texts.indexOf('Curation matrix')).toBe(texts.indexOf('Compare curations') + 1);
    // Phenotype–function correlation is a distinct analysis (functional vs phenotype
    // clusters), so it sits last in the Analyses menu rather than beside a parent.
    expect(texts.indexOf('Phenotype–function correlation')).toBe(texts.length - 1);
  });

  it('resolves the matrix paths to the matrix components via named routes', async () => {
    const router = createRouter({ history: createMemoryHistory(), routes });

    const similarity = router.resolve('/CurationComparisons/Similarity');
    expect(similarity.name).toBe('CurationComparisonsSimilarity');

    const correlation = router.resolve('/PhenotypeFunctionalCorrelation');
    expect(correlation.name).toBe('PhenotypeFunctionalCorrelation');

    // Named-route lookups used by the cross-link tabs must resolve.
    expect(router.resolve({ name: 'CurationComparisonsSimilarity' }).path).toBe(
      '/CurationComparisons/Similarity'
    );
    expect(router.resolve({ name: 'PhenotypeFunctionalCorrelation' }).path).toBe(
      '/PhenotypeFunctionalCorrelation'
    );
  });

  it('links from Phenotype correlations to the Correlation matrix named route', () => {
    const wrapper = mount(PhenotypeCorrelations, {
      global: {
        stubs: {
          RouterLink: RouterLinkStub,
          RouterView: { template: '<div data-testid="route-child">Child</div>' },
        },
      },
    });

    const links = wrapper.findAllComponents(RouterLinkStub);
    const matrixLink = links.find((l) => l.text().includes('Correlation matrix'));
    expect(matrixLink).toBeDefined();
    expect(matrixLink?.props('to')).toEqual({ name: 'PhenotypeFunctionalCorrelation' });
  });

  it('renders the Phenotype–function correlation page standalone (no cross-link tabs)', () => {
    // It is its own Analyses entry now, so it must NOT show tab links that
    // navigate away (the 'Phenotype correlogram' tab was misleading — clicking it
    // jumped to a different analysis).
    const wrapper = mount(PhenotypeFunctionalCorrelation, {
      global: {
        stubs: {
          RouterLink: RouterLinkStub,
          AnalysesPhenotypeFunctionalCorrelation: {
            template: '<div data-testid="pheno-func-child" />',
          },
        },
      },
    });

    const links = wrapper.findAllComponents(RouterLinkStub);
    expect(links.find((l) => l.text().includes('Phenotype correlogram'))).toBeUndefined();
    expect(wrapper.find('.analysis-tabs').exists()).toBe(false);
  });
});
